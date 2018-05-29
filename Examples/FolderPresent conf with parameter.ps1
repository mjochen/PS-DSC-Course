configuration FolderPresent
{
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [String]$FolderPath
    )
    
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

    Node localhost
    {
        File Directory
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            DestinationPath = $folderPath
        }
    }
}
 

FolderPresent -FolderPath "c:\tmp"