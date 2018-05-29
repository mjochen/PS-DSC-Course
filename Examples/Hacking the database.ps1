#region connect to server
Enter-PSSession $ms01
#endregion

#region install the module
# https://www.powershellgallery.com/packages/ESENT/1.0.0.1
# someone wrote a module that allows you to inspect ESE-databases, and you can use it for free at your own risk

Install-Module -Name ESENT

Get-Command -Module ESENT
#endregion

#region open the database

$database = "$env:TEMP\Devices.edb"

# stop IIS-website to disable lock
Stop-Service W3SVC

Copy-Item -path 'C:\Program Files\WindowsPowerShell\DscService\Devices.edb' -Destination $database

Start-Service W3SVC

# open the file
$db = New-ESEDatabaseSession -Path $database -Force

Get-ESEDatabaseTableNames -Session $db.Session -DatabaseId $db.DatabaseId
$data = Get-ESEDatabaseTableData -Session $db.Session -DatabaseId $db.DatabaseId -TableName RegistrationData

$list = @()

foreach($row in $data.Rows)
{
    $list += $row | Select-Object NodeName, AgentID, IPAddress, LCMVersion
}

$list | Export-Csv registeredAgents.csv -Delimiter ";"

Close-ESEDatabase -Session $db.Session -DatabaseId $db.DatabaseId -Instance $db.Instance -Path $db.Path

Exit-PSSession

#endregion