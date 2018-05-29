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
        PartialConfiguration InstallIIS # new
        {
            Description                     = "Install IIS"
            RefreshMode                     = 'Push'
        }

        PartialConfiguration IISFiles # new
        {
            Description                     = "Place files for IIS"
            DependsOn                       = "[PartialConfiguration]InstallIIS"
            RefreshMode                     = 'Push'
        }
    }
}

MixedPartialConfigurations
Set-DscLocalConfigurationManager .\MixedPartialConfigurations -Verbose

#endregion

#region IIS configuration

# Lot's of copying from Exercises\Basic Webserver local.ps1

$filename = "c:\test\index.htm"

New-Item -ItemType File -Path $filename -force

Set-Content -Path $filename -Value "
<head>
<title>Basic Webserver</title>
</head>
<body>
<p>Hello World!</p>
</body>
"

Configuration InstallIIS
{
    # Import the module that contains the resources we're using.
    Import-DscResource -ModuleName PsDesiredStateConfiguration

    # The Node statement specifies which targets this configuration will be applied to.
    Node 'localhost'
    {
        WindowsFeature WebServer
        {
            Ensure = "Present"
            Name   = "Web-Server" # Get-WindowsFeature "Web-*"
        }

        WindowsFeature IIS6
        {
            Name = "Web-Mgmt-Compat"
            Ensure = "Present"
            IncludeAllSubFeature = $true
            DependsOn = "[WindowsFeature]WebServer"
        }
    }
}

Configuration IISFiles
{
    # Import the module that contains the resources we're using.
    Import-DscResource -ModuleName PsDesiredStateConfiguration

    # The Node statement specifies which targets this configuration will be applied to.
    Node 'localhost'
    {
        File WebsiteContent
        {
            Ensure = 'Present'
            SourcePath = 'c:\test\index.htm'
            DestinationPath = 'c:\inetpub\wwwroot'
        }
    }
}

#endregion

#region compile, publish and start configuration
InstallIIS
IISFiles

# do not start-dscconfiguration, but publish it
Publish-DSCConfiguration -Path .\InstallIIS
Publish-DSCConfiguration -Path .\IISFiles

# now you can start the configuration
Start-DscConfiguration -UseExisting -Wait -Verbose # will only do local configuration

Test-DscConfiguration # true

Remove-Item C:\inetpub\wwwroot\index.htm

Test-DscConfiguration # false

Start-DscConfiguration -UseExisting -Wait -Verbose # will only do local configuration

Test-DscConfiguration # true
#endregion