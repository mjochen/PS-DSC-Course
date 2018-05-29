#region connect to a computer that has all modules installed
# optional...
$dc01 = New-PSSession -VMName "DC01" -Credential $credAdmin
enter-pssession $dc01
cd c:\scripts
#endregion

#region Configuration

configuration Testlab
{
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [System.Management.Automation.PSCredential]$firstDomainAdmin,
        [Parameter(Mandatory=$True,Position=2)]$safeModePassword

    )

    Import-DscResource -Module xComputerManagement
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -Name WindowsFeature
    Import-DscResource -Module xComputerManagement
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xActiveDirectory
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xDHCPServer


    Node "172.20.0.2" # DC01
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

    Node "172.20.1.1" #MS01
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        xComputer NewName
        {
            Name = "MS01"
            DomainName = 'local.cursusdom.tm'
            Credential = $firstDomainAdmin 
         }

        File Directory
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            DestinationPath = "C:\Scripts"
        }

        Group AddDomUsersToLocalRDPUsers
        {
            GroupName='Remote Desktop Users'
            Ensure= 'Present'
            MembersToInclude= "CD\Domain Users"
            Credential = $firstDomainAdmin
        }
    }
}

#endregion

#region compile

$secpasswd = ConvertTo-SecureString 'R1234-56' -AsPlainText -Force
$SafeModePW = New-Object System.Management.Automation.PSCredential ('guest', $secpasswd)
$admin = New-Object System.Management.Automation.PSCredential ('CD\Admin', $secpasswd)

$cd = @{
    AllNodes = @(
        @{
            NodeName = '*'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
        @{
            NodeName = '172.20.1.1'
            RebootNodeIfNeeded = $true
        }
        @{
            NodeName = '172.20.0.2' # needed because otherwise the * doesn't apply to this node
        }
    )
}

Testlab -FirstDomainAdmin $admin -safeModePassword $SafeModePW -ConfigurationData $cd

#endregion

#region back to host
Exit-PSSession

Copy-Item -FromSession $dc01 -Path c:\Scripts\Testlab -Destination c:\Scripts\Testlab -recurse
# we only need the modules installed to compile the configurations, not to distribute them

#endregion

#region run

$pcs = "172.20.0.2","172.20.1.1"

$sessions = New-CimSession -ComputerName $pcs -Credential $credAdmin

Set-DscLocalConfigurationManager -Path .\TestLab -CimSession $sessions
# error for 172.20.0.2 is fine

Start-DscConfiguration -path .\TestLab -CimSession $sessions -Force -Wait -Verbose

Test-DscConfiguration -CimSession $sessions

#endregion