# https://techstronghold.com/scripting/@rudolfvesely/how-to-remove-all-powershell-dsc-configuration-documents-mof-files/

Get-ChildItem -Path 'C:\Windows\System32\Configuration' -File -Force
Remove-DscConfigurationDocument -Stage Current, Pending, Previous -Verbose