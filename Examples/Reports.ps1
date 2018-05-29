#region connect to server
$ms01 = New-PSSession -VMName "MS01" -Credential $credAdmin
$dc01 = New-PSSession -VMName "DC01" -Credential $credAdmin
$fs01 = New-PSSession -VMName "FS01" -Credential $credAdmin

Enter-PSSession $ms01
cd c:\scripts
#endregion

#region the get-report function

# https://docs.microsoft.com/en-us/powershell/dsc/reportserver

function Get-Report
{
    param(
        $AgentId = "$((glcm).AgentId)",
        $serviceURL = "http://ms01.local.cursusdom.tm:8080/PSDSCPullServer.svc")

    $requestUri = "$serviceURL/Nodes(AgentId= '$AgentId')/Reports"
    $request = Invoke-WebRequest -Uri $requestUri  -ContentType "application/json;odata=minimalmetadata;streaming=true;charset=utf-8" `
               -UseBasicParsing -Headers @{Accept = "application/json";ProtocolVersion = "2.0"} `
               -ErrorAction SilentlyContinue -ErrorVariable ev
    $object = ConvertFrom-Json $request.content
    return $object.value
}
#endregion

#region gathering the agentID's

Exit-PSSession

$aidDC01 = Invoke-Command -session $dc01 -scriptblock { (Get-DscLocalConfigurationManager).AgentId }
$aidFS01 = Invoke-Command -session $fs01 -scriptblock { (Get-DscLocalConfigurationManager).AgentId }

# send the agentID's to ms01
Invoke-Command -session $ms01 -scriptblock { param($aid) $aidDC01 = $aid } -ArgumentList $aidDC01
Invoke-Command -session $ms01 -scriptblock { param($aid) $aidFS01 = $aid } -ArgumentList $aidFS01
#endregion

#region getting the reports
Enter-PSSession $ms01

$allReports = Get-Report -AgentId $aidFS01

$allReports | Get-Member -MemberType Properties

$allReports | Sort-Object StartTime -Descending | Select-Object -First 5 | FT OperationType, RefreshMode, Status

Exit-PSSession
#endregion