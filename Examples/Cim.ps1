#region Configuration, compile

configuration SimpleComputerRemote
{
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [System.Management.Automation.PSCredential]$DomainUser,
        [Parameter(Mandatory=$True,Position=2)]
        [String]$Computername
    )

    Import-DscResource -Module xComputerManagement
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    Node "172.20.1.1"
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        xComputer NewName
        {
            Name = $Computername
            DomainName = 'local.cursusdom.tm'
            Credential = $DomainUser 
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
            Credential = $DomainUser
        }
    }
}
 
$secpasswd = ConvertTo-SecureString 'R1234-56' -AsPlainText -Force
$admin = New-Object System.Management.Automation.PSCredential ('CD\Admin', $secpasswd)

$cd = @{
    AllNodes = @(
        @{
            NodeName = '172.20.1.1'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
            RebootNodeIfNeeded = $true
        }
    )
}

SimpleComputerRemote -DomainUser $admin -Computername "MS01" -ConfigurationData $cd
#endregion

#region apply

# if needed:
# Invoke-Command -VMName "MS01" -Credential $credAdmin -ScriptBlock { Install-Module -Name xComputerManagement }

$cimMS01 = New-CimSession -Credential $credAdmin -ComputerName "172.20.1.1" # ms01

Get-CimSession

Set-DscLocalConfigurationManager -Path .\SimpleComputerRemote -CimSession $cimMS01
Start-DscConfiguration -path .\SimpleComputerRemote -CimSession $cimMS01 -Force -Wait -Verbose

Get-DscConfiguration
Test-DscConfiguration -CimSession $cimMS01
#endregion