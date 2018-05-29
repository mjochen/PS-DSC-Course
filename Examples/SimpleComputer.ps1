#region install modules

#require -runas Administrator

Install-Module -Name xComputerManagement

Get-DscResource

#endregion

#region configuration

configuration SimpleComputer
{
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [System.Management.Automation.PSCredential]$DomainUser,
        [Parameter(Mandatory=$True,Position=2)]
        [String]$Computername
    )

    Import-DscResource -Module xComputerManagement
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }


        #computername
        xComputer NewName
        {
            Name = $Computername
            DomainName = 'local.cursusdom.tm'
            Credential = $DomainUser 
        }

        #folders present
        File Directory
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            DestinationPath = "C:\Scripts"
        }
        
        #Domain Users in RDP users
        Group AddDomUsersToLocalRDPUsers
        {
            GroupName='Remote Desktop Users'
            Ensure= 'Present'
            MembersToInclude= "CD\Domain Users"
            Credential = $DomainUser
        }
    }
}

#endregion

#region compilation
 
$secpasswd = ConvertTo-SecureString 'R1234-56' -AsPlainText -Force
$admin = New-Object System.Management.Automation.PSCredential ('CD\Admin', $secpasswd)
# or use get-credential...

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
        }
    )
}

SimpleComputer -DomainUser $admin -Computername "MS01" -ConfigurationData $cd


#endregion

#region apply meta.mof

Get-DscLocalConfigurationManager
Set-DscLocalConfigurationManager -Path .\SimpleComputer
Get-DscLocalConfigurationManager | Select-Object RebootNodeIfNeeded

#endregion

#region apply configuration

#require -runas Administrator

$job = Start-DscConfiguration -path .\SimpleComputer -Force -Wait

hostname
Restart-Computer


Get-DscConfiguration
Test-DscConfiguration

$job
$job | Receive-Job

Remove-Item .\MyFirstConfiguration -Recurse

Restart-Computer




#endregion