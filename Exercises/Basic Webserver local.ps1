#region create HTML file (manually)

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


#endregion

#region create configuration
Configuration WebsiteTest
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

        File WebsiteContent
        {
            Ensure = 'Present'
            SourcePath = 'c:\test\index.htm'
            DestinationPath = 'c:\inetpub\wwwroot'
        }
    }
}
#endregion

#region compile configuration 

WebsiteTest

#endregion

#region apply configuration 

Start-DscConfiguration .\WebsiteTest -wait -verbose -Force

#endregion

#region test configuration 

Test-DscConfiguration

Get-windowsfeature "Web-*"

#endregion