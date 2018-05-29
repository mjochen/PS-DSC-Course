# https://docs.microsoft.com/en-us/powershell/dsc/pullserver#community-solutions-for-pull-services

#region connect server
$ms01 = New-PSSession -VMName "MS01" -Credential $credAdmin
Enter-PSSession $ms01 
cd C:\scripts
#endregion

#region install module

Install-Module xPSDesiredStateConfiguration 

$guid = New-Guid

#endregion

#region configure pull server

<# the example can be found...
$env:PSModulePath
Get-Content 'C:\Program Files\WindowsPowerShell\Modules\xPSDesiredStateConfiguration\8.2.0.0\Examples\Sample_xDscWebServiceRegistration.ps1'
#>

configuration Sample_xDscWebServiceRegistration
{
    param 
    (
        [string[]]$NodeName = 'localhost',
        [Parameter(HelpMessage='This should be a string with enough entropy (randomness) to protect the registration of clients to the pull server.  We will use new GUID by default.')]
        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey   # A guid that clients use to initiate conversation with pull server
    )

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

    Node $NodeName
    {
        WindowsFeature DSCServiceFeature
        {
            Ensure = "Present"
            Name   = "DSC-Service"            
        }

        WindowsFeature IISConsole {
            Ensure = "Present"
            Name   = "Web-Mgmt-Console"
        }

        xDscWebService PSDSCPullServer
        {
            Ensure                  = "Present"
            EndpointName            = "PSDSCPullServer"
            Port                    = 8080
            PhysicalPath            = "$env:SystemDrive\inetpub\PSDSCPullServer"
            CertificateThumbPrint   = "AllowUnencryptedTraffic"
            ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"            
            State                   = "Started"
            DependsOn               = "[WindowsFeature]DSCServiceFeature" 
            RegistrationKeyPath     = "$env:PROGRAMFILES\WindowsPowerShell\DscService"   
            AcceptSelfSignedCertificates = $true
            Enable32BitAppOnWin64   = $false
            UseSecurityBestPractices= $false
        }

        File RegistrationKeyFile
        {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
    }
}

# Sample use (please change values of parameters according to your scenario):
# $thumbprint = (New-SelfSignedCertificate -Subject "TestPullServer").Thumbprint
# $registrationkey = [guid]::NewGuid()
# Sample_xDscWebServiceRegistration -RegistrationKey $registrationkey -certificateThumbPrint $thumbprint

Sample_xDscWebServiceRegistration -RegistrationKey $guid

Start-DscConfiguration -Path .\Sample_xDscWebServiceRegistration -Wait -Force -Verbose

# Get RegistrationKey value

$regKey = get-content "c:\Program Files\WindowsPowerShell\DscService\RegistrationKeys.txt"
# save this value, and not just in the variable
# we'll be switching computers soon

# for example, here: 1f53d697-1b18-4f14-980b-c5528743fcf6

#endregion

#region connect client
Exit-PSSession
$administrator = Get-Credential Administrator
$fs01 = New-PSSession -VMName FS01 -Credential $administrator
Enter-PSSession $fs01
#endregion

#region Configure client

<# the example can be found...
$env:PSModulePath
Get-Content 'C:\Program Files\WindowsPowerShell\Modules\xPSDesiredStateConfiguration\8.2.0.0\Examples\Sample_xDscWebServiceRegistration.ps1'
#>

$regKey = "1f53d697-1b18-4f14-980b-c5528743fcf6"

Get-DscLocalConfigurationManager

[DSCLocalConfigurationManager()]
configuration Sample_MetaConfigurationToRegisterWithPullServer
{
    param
    (
        [ValidateNotNullOrEmpty()]
        [string] $NodeName = 'localhost',

        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey, #same as the one used to setup pull server in previous configuration

        [ValidateNotNullOrEmpty()]
        [string] $ServerName = 'localhost', #node name of the pull server, same as $NodeName used in previous configuration

        [ValidateNotNullOrEmpty()]
        [string] $ClientConfigName # name of the configuration this computer will be applying
    )

    Node $NodeName
    {
        Settings
        {
            RefreshMode        = 'Pull'
            RefreshFrequencyMins = 30
            RebootNodeIfNeeded = $true
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

Sample_MetaConfigurationToRegisterWithPullServer -RegistrationKey $regKey -ServerName "MS01.local.cursusdom.tm" -ClientConfigName "FS01"

Set-DscLocalConfigurationManager -Path .\Sample_MetaConfigurationToRegisterWithPullServer -Verbose

#endregion

#region connect server
Exit-PSSession
Enter-PSSession $ms01
#endregion

#region the client configuration

configuration FS01
{
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

    Node FS01
    {
        File Directory
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            DestinationPath = "C:\SharedFolder"
        }

    }
}

FS01

#endregion

#region save configurations for remote servers

#ModulePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
#ConfigurationPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration" 

# create configuration - FS01 pull conf.ps1

New-DscChecksum -ConfigurationPath .\FS01 -OutPath .\FS01 -Verbose -Force

Get-ChildItem .\FS01 -Filter FS01* | Copy-Item -Destination "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration" 

# Get-ChildItem "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration" 

#endregion

#region connect client
Exit-PSSession
Enter-PSSession $fs01
#endregion

#region test the configuration

Get-ChildItem c:\ # c:\SharedFolder?

Get-DscConfiguration # output?

Test-DscConfiguration # true?

#endregion