configuration FolderPresent
{
    # Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

    Node localhost
    {
        File Directory
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            DestinationPath = "C:\Scripts"
        }
    }
}
 

FolderPresent