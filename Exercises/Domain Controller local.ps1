#region configuration

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

    Node localhost
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

#endregion

#region compilation

#$admin = Get-Credential -UserName "DC\Admin" -message "Please provide pswd"
#$smp = Get-Credential -UserName "/" -message "Please provide safe mode password"

$secpasswd = ConvertTo-SecureString 'R1234-56' -AsPlainText -Force
$SafeModePW = New-Object System.Management.Automation.PSCredential ('guest', $secpasswd)
$admin = New-Object System.Management.Automation.PSCredential ('CD\Admin', $secpasswd)

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

DomainController -FirstDomainAdmin $admin -safeModePassword $SafeModePW -ConfigurationData $cd

#endregion

#region Apply

#require -runas Administrator

Install-Module -Name xActiveDirectory
Install-Module -Name xNetworking
Install-Module -Name xDHCPServer
Install-Module -Name xComputerManagement

Set-DscLocalConfigurationManager -path .\DomainController
Start-DscConfiguration -path .\DomainController -Force -Wait -Verbose

Get-DscConfiguration

Test-DscConfiguration

#endregion