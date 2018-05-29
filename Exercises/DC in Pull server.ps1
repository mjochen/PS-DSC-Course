#region connect DC
$dc01 = New-PSSession -VMName "DC01" -Credential $credAdmin
Enter-PSSession $dc01
cd c:\Scripts
#endregion

#region compile configuration

# Configuration: copy-paste from "Exercises\Domain Controller local.ps1"
# Changes are indicated

configuration DomainController
{
    param(
        [Parameter()]$firstDomainAdmin,
        [Parameter()]$safeModePassword


    )
    Import-DscResource -Name WindowsFeature
    Import-DscResource -Module xComputerManagement
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xActiveDirectory
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xDHCPServer

    Node DC01 # was localhost
    {
        xComputer NewName
        {
            Name = "DC01"
 
        }

        WindowsFeature Domain-Services
        {
            Name = "AD-Domain-Services"
            Ensure = "Present"
        }

        WindowsFeature RSAT-ADDS
        {
            DependsOn = "[WindowsFeature]Domain-Services"
            Name = "RSAT-ADDS"
            Ensure = "Present"
        }

        WindowsFeature DNSinst
        {
            Name = "DNS"
            Ensure = "Present"
            IncludeAllSubFeature = $true 
        }

        WindowsFeature RSAT-DNS-Server
        {
            DependsOn = "[WindowsFeature]DNSinst"
            Name = "RSAT-DNS-Server"
            Ensure = "Present"
        }

        WindowsFeature MickeyMouse
        {
            Name = "DHCP"
            Ensure = "Present"
            IncludeAllSubFeature = $true 
        }

        WindowsFeature RSAT-DHCP
        {
            DependsOn = "[WindowsFeature]MickeyMouse"
            Name = "RSAT-DHCP"
            Ensure = "Present"
        }

        # IP settings
        # https://github.com/PowerShell/xNetworking/wiki
        xIPAddress NewIPv4Address
        {
            IPAddress      = '172.20.0.2/16'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPV4'
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = '127.0.0.1'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            Validate       = $true
        }

        xDefaultGatewayAddress SetDefaultGateway
        {
            Address        = '172.20.0.1'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
        }

        # Domain Install
        # https://foxdeploy.com/2015/04/03/part-iii-dsc-making-our-domain-controller/        
        xADDomain SetupDomain
        {
            DependsOn='[WindowsFeature]Domain-Services'
            DomainAdministratorCredential= $firstDomainAdmin
            DomainName= "local.cursusdom.tm"
            SafemodeAdministratorPassword= $safeModePassword
            DomainNetbiosName = "CD"
        }

        xDhcpServerScope Scope
        {
            DependsOn = '[WindowsFeature]MickeyMouse'
            Ensure = 'Present'
            IPStartRange = '172.20.1.0'
            IPEndRange = '172.20.1.255'
            Name = 'PowerShellScope'
            SubnetMask = '255.255.0.0'
            LeaseDuration = '00:08:00'
            State = 'Active'
            AddressFamily = 'IPv4'
        } 

        xDhcpServerOption Option
        {
            Ensure = 'Present'
            ScopeID='172.20.0.0'
            DnsDomain = 'local.cursusdom.tm'
            DnsServerIPAddress = '172.20.0.2'
            AddressFamily = 'IPv4'
            Router = '172.20.0.1'
        }

        xDhcpServerAuthorization autho
        {
            ensure='present'
        }
    }
}

$secpasswd = ConvertTo-SecureString 'R1234-56' -AsPlainText -Force
$SafeModePW = New-Object System.Management.Automation.PSCredential ('guest', $secpasswd)
$admin = New-Object System.Management.Automation.PSCredential ('CD\Admin', $secpasswd)

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'DC01' # was localhost
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

Remove-Item .\DomainController -recurse

DomainController -FirstDomainAdmin $admin -safeModePassword $SafeModePW -ConfigurationData $cd

#endregion

#region copy mof to pull server

Exit-PSSession

$ms01 = New-PSSession -VMName "MS01" -Credential $credAdmin

Copy-Item -FromSession $dc01 -Path c:\Scripts\DomainController -Destination  -recurse
Copy-Item -ToSession $ms01 -Path "$env:TEMP\DomainController" -Destination c:\Scripts\DomainController -recurse
Remove-Item "$env:TEMP\DomainController" -recurse

#endregion

#region connect server
Exit-PSSession
Enter-PSSession $ms01 
cd C:\scripts
#endregion

#region move mof to correct location
New-DscChecksum -ConfigurationPath .\DomainController -OutPath .\DomainController -Verbose -Force

Remove-Item -Path "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration\DC01.*" -Recurse -ErrorAction SilentlyContinue

Get-ChildItem .\DomainController -Filter DC01* | Copy-Item -Destination "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration" 

Get-ChildItem "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration" 
#endregion

#region Configure client

#still on the server: get the registration key and the certificate thumbprint

get-content "c:\Program Files\WindowsPowerShell\DscService\RegistrationKeys.txt"

$regKey = "1f53d697-1b18-4f14-980b-c5528743fcf6" # copy-paste from console

Exit-PSSession
Enter-PSSession $dc01

# copy-paste from "Examples\Pull Server Setup.ps1"

$regKey = "1f53d697-1b18-4f14-980b-c5528743fcf6"

[DSCLocalConfigurationManager()]
configuration Sample_MetaConfigurationToRegisterWithPullServer
{
    param
    (
        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey, #same as the one used to setup pull server in previous configuration

        [ValidateNotNullOrEmpty()]
        [string] $ServerName = 'localhost', #node name of the pull server, same as $NodeName used in previous configuration

        [ValidateNotNullOrEmpty()]
        [string] $ClientConfigName # name of the configuration this computer will be applying
    )

    Node localhost
    {
        Settings
        {
            RefreshMode        = 'Pull'
            RefreshFrequencyMins = 30
            ConfigurationMode = "ApplyAndAutocorrect";
            AllowModuleOverwrite  = $true;
            RebootNodeIfNeeded = $true;
            ConfigurationModeFrequencyMins = 60;
        }

        ConfigurationRepositoryWeb ThePullServer
        {
            ServerURL          = "http://$ServerName`:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey    = $RegistrationKey
            ConfigurationNames = @($ClientConfigName)
            AllowUnsecureConnection = $true
        }
        
        ReportServerWeb TheReportServer
        {
            ServerURL       = "http://$ServerName`:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey = $RegistrationKey
            AllowUnsecureConnection = $true
        }   

    }
}

Sample_MetaConfigurationToRegisterWithPullServer -RegistrationKey $regKey -ServerName "MS01.local.cursusdom.tm" -ClientConfigName "DC01"

Set-DscLocalConfigurationManager -Path .\Sample_MetaConfigurationToRegisterWithPullServer -Verbose

Update-DscConfiguration -verbose -wait

Get-DscConfiguration # output?

Test-DscConfiguration # true?

#endregion