#region install modules
# on CL4-win10
#require -runas Administrator

Install-Module -Name xComputerManagement

Get-DscResource

#endregion

#region create certificate
# on CL4-win10
#require -runas Administrator

$cert = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName 'DscEncryptionCert' -HashAlgorithm SHA256
# export the public key certificate
md c:\temp
$cert | Export-Certificate -FilePath "c:\temp\DscPublicKey.cer" -Force

Exit-PSSession

# on host
Copy-Item -FromSession $cl4 -Path "c:\temp\DscPublicKey.cer" -Destination "$env:temp\DscPublicKey.cer"

# Import to the my store
md "c:\Scripts\Public Keys"
Import-Certificate -FilePath "c:\Scripts\Public Keys\DscPublicKey.cer" -CertStoreLocation Cert:\LocalMachine\My

#endregion

#region configuration
# on host
# no changes from original script

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
# on host
 
$secpasswd = ConvertTo-SecureString 'R1234-56' -AsPlainText -Force
$admin = New-Object System.Management.Automation.PSCredential ('CD\Admin', $secpasswd)
# or use get-credential...

$cert = Get-ChildItem Cert:\LocalMachine\My | where-object Subject -eq "CN=DscEncryptionCert"
$cert.Thumbprint

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            # PSDscAllowPlainTextPassword = $true # Good riddens
            PSDscAllowDomainUser = $true
            Thumbprint = $cert.Thumbprint
            CertificateFile = "c:\Scripts\Public Keys\DscPublicKey.cer"
        }
    )
}

SimpleComputer -DomainUser $admin -Computername "CL4-WIN10" -ConfigurationData $cd


#endregion

#region apply start
# on host
# copy the configuration to the client

Copy-Item -ToSession $cl4 -Path .\SimpleComputer -Destination c:\temp\SimpleComputer -Recurse

# on cl4-win10
Enter-PSSession $cl4

cd c:\temp\simplecomputer
dir

cd c:\temp

Set-DscLocalConfigurationManager -Path .\SimpleComputer
Get-DscLocalConfigurationManager | Select-Object RebootNodeIfNeeded

#endregion

#region add thumbprint to LCM configuration

$cert = Get-ChildItem Cert:\LocalMachine\My | where-object Subject -eq "CN=DscEncryptionCert"
$cert.Thumbprint

Configuration LCMConfiguration
{
    Node "localhost"
    {
        LocalConfigurationManager
        {

            CertificateID = $cert.Thumbprint
            # RebootNodeIfNeeded = $true
        }
    }
}

# compile
LCMConfiguration

# apply
Set-DscLocalConfigurationManager -Path .\LCMConfiguration

# check (and check normal configuration)
Get-DscLocalConfigurationManager # changed and lost reboot if needed

#endregion

#region add thumbprint to original configuration

# back to the host
Exit-PSSession

# copy-paste of original configuration
# - Add parameter for thumbprint
# - Add configuration of thumbprint to LocalConfigurationManager

configuration SimpleComputer
{
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [System.Management.Automation.PSCredential]$DomainUser,
        [Parameter(Mandatory=$True,Position=2)]
        [String]$Computername
        # new!
        ,[Parameter(Mandatory=$True,Position=3)]
        [String]$secThumbprint
    )

    Import-DscResource -Module xComputerManagement
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            # new!
            CertificateID = $secThumbprint 
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

# compiling
# assuming all variables still exist, otherwise rerun region Compilation

SimpleComputer -DomainUser $admin -Computername "CL4-WIN10" -secThumbprint $cert.Thumbprint -ConfigurationData $cd

# Applying again...

Copy-Item -ToSession $cl4 -Path .\SimpleComputer -Destination c:\temp\SimpleComputer -Recurse -Force

# on cl4-win10
Enter-PSSession $cl4

cd c:\temp

Set-DscLocalConfigurationManager -Path .\SimpleComputer
Get-DscLocalConfigurationManager | Select-Object RebootNodeIfNeeded, CertificateID

#endregion

#region apply finish
#require -runas Administrator

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Start-DscConfiguration -path .\SimpleComputer -Force -Wait -verbose

#endregion