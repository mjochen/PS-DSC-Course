Get-DscLocalConfigurationManager

# new LCM configuration:
Configuration LCMConfiguration
{
    Node "localhost"
    {
        LocalConfigurationManager
        {

            ConfigurationMode = "ApplyAndAutoCorrect"
            ConfigurationModeFrequencyMins = 15
            RefreshMode = "PUSH"
        }
    }
}

# compile
LCMConfiguration

# apply
Set-DscLocalConfigurationManager -Path .\LCMConfiguration

# check (and check normal configuration)
Get-DscLocalConfigurationManager # changed and...
Get-DscConfiguration # normal configuration still applies