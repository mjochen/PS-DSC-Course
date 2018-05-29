# This file is a copy-paste of the example file. All the unnecessary bits have been cut

#region connect server
$ms01 = New-PSSession -VMName "MS01" -Credential $credAdmin
Enter-PSSession $ms01 
cd C:\scripts
#endregion

# install module and certificates

# configure pull server

# Configure client

#region the client configuration

# some stealing from example "SimpleComputer.ps1"

configuration FS01
{
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [System.Management.Automation.PSCredential]$DomainUser,
        [Parameter(Mandatory=$True,Position=2)]
        [String]$Computername
    )

    Import-DscResource -Module xComputerManagement -ModuleVersion 4.1.0.0
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

    Node FS01
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
        
        File Directory
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            DestinationPath = "C:\SharedFolder"
        }

        xComputer NewName
        {
            Name = $Computername
            DomainName = 'local.cursusdom.tm'
            Credential = $DomainUser 
        }

    }
}

$secpasswd = ConvertTo-SecureString 'R1234-56' -AsPlainText -Force
$admin = New-Object System.Management.Automation.PSCredential ('CD\Admin', $secpasswd)
# or use get-credential...

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'FS01'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

FS01 -DomainUser $admin -Computername "FS01" -ConfigurationData $cd
#note: no client certificate - plain text passwords!

#endregion

#region save module

$ModulePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"

# custom modules (x...) are located in
$baseModPath = "C:\Program Files\WindowsPowerShell\Modules"

# code below could be a function, or in a loop
# only has to be done once per module
# could be done in GUI (except for New-DscChecksum)

$moduleNeeded = "xComputerManagement"

# the name of the newest version of the module
$version = (Get-ChildItem (join-path $baseModPath $moduleNeeded) -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name

$filename = $moduleNeeded + "_" + $version + ".zip"

# move all files to temp folder
Copy-Item (Join-Path (Join-Path $baseModPath $moduleNeeded) $version) -Destination (Join-Path $env:TEMP $moduleNeeded) -Recurse

# zip temp folder and clear temp
Compress-Archive -Path (Join-Path $env:TEMP $moduleNeeded) -DestinationPath (Join-Path $env:TEMP $filename)
Remove-Item -Path (Join-Path $env:TEMP $moduleNeeded) -Recurse -Force

# move zip to right location and create checksum
Move-Item -path (Join-Path $env:TEMP $filename) -Destination $ModulePath -Force
New-DscChecksum -Path (Join-Path $ModulePath $filename) -OutPath $ModulePath -Verbose -Force

#endregion

#region save configurations for remote servers

# Same as before, but we have to do it again because we've changed the configuration

New-DscChecksum -ConfigurationPath .\FS01 -OutPath .\FS01 -Verbose -Force

Remove-Item -Path "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration\FS01.*" -Recurse -ErrorAction SilentlyContinue

Get-ChildItem .\FS01 -Filter FS01* | Copy-Item -Destination "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration" 

Get-ChildItem "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration" 

#endregion

# Starting from here: not really needed, only of you are the impatient kind

#region connect client
Exit-PSSession
$administrator = Get-Credential Administrator
$fs01 = New-PSSession -VMName FS01 -Credential $administrator
Enter-PSSession $fs01
#endregion

#region force pulling configuration

# https://docs.microsoft.com/en-us/powershell/wmf/5.0/dsc_updateconfig

Update-DscConfiguration -Verbose -wait

Get-DscConfiguration # output?

Test-DscConfiguration # true?

#endregion