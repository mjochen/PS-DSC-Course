#region connect FS01
$fs01 = New-PSSession -VMName "FS01" -Credential $credAdmin
Enter-PSSession $fs01
md c:\Scripts
cd c:\Scripts
#endregion

#region LCM

[DSCLocalConfigurationManager()]
configuration MixedPartialConfigurations
{
    Node localhost
    {
        Settings # from Examples\Pull server setup.ps1
        {
            # RefreshMode        = 'Pull' -> gone
            RefreshFrequencyMins = 30
            RebootNodeIfNeeded = $true
        }

        ConfigurationRepositoryWeb ThePullServer # from Examples\Pull server setup.ps1, but different
        {
            ServerURL          = "http://ms01.local.cursusdom.tm:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey    = "1f53d697-1b18-4f14-980b-c5528743fcf6"
            AllowUnsecureConnection = $true
            ConfigurationNames = @("FS01")
        }
        
        ReportServerWeb TheReportServer # from Examples\Pull server setup.ps1
        {
            ServerURL          = "http://ms01.local.cursusdom.tm:8080/PSDSCPullServer.svc" # notice it is https
            RegistrationKey    = "1f53d697-1b18-4f14-980b-c5528743fcf6"
            AllowUnsecureConnection = $true
        }   

        PartialConfiguration FS01 # new
        {
            Description         = 'Configuration for the Base OS'
            ConfigurationSource = '[ConfigurationRepositoryWeb]ThePullServer'
            RefreshMode         = 'Pull'
        }

        PartialConfiguration InstallIIS
        {
            Description                     = "InstallIIS"
            RefreshMode                     = 'Push'
        }

        PartialConfiguration IISFiles
        {
            Description                     = "InstallIIS"
            DependsOn                       = "[PartialConfiguration]InstallIIS"
            RefreshMode                     = 'Push'
        }
    }
}

MixedPartialConfigurations
Set-DscLocalConfigurationManager .\MixedPartialConfigurations -Verbose

#endregion

#region IIS configuration

# no changes to local configuration

#endregion

#region FS01 configuration on MS01

# still valid from Exercises\Pull server with modules.ps1

#endregion

#region test
Remove-Item c:\SharedFolder # is referenced in configuration from pull server

Update-DscConfiguration -Wait -verbose

Start-DscConfiguration -UseExisting -wait -Verbose

dir c:\

# if it's fun, keep on testing...
Remove-Item c:\SharedFolder
Remove-Item C:\inetpub\wwwroot\index.htm

Start-DscConfiguration -UseExisting -wait -Verbose

Get-Item C:\SharedFolder
Get-Item C:\inetpub\wwwroot\index.htm

# https://www.youtube.com/watch?v=4PaTWufUqqU

#endregion