#require -runas Administrator

Enable-PSRemoting

Start-DscConfiguration -path .\FolderPresent -Verbose -Wait

$job = Start-DscConfiguration -path .\FolderPresent -Verbose
$job
$job | Receive-Job

Get-DscConfiguration # note "ensure absent" after deleting folder

Test-DscConfiguration

Test-DscConfiguration -Detailed

Start-DscConfiguration -UseExisting