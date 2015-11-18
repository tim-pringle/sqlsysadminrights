$task = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2015-08-07T16:04:06.3548654</Date>
    <Author>mydomain\myusername</Author>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2015-08-07T16:03:33.9171182</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-file d:\addSysadmin.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
'@

$code = @'
function Invoke-SQLQuery

{
    [CmdletBinding()]
    [OutputType([psobject])]
    param
    (
        
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Query')] [string[]] $Query,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Database')] [string] $Database = 'master',
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Instance')] [string] $SQLServer
        )
    
       
    Process
    {         
            $ErrorAction = 'Stop' 
            $SqlConnection = New-Object  -TypeName System.Data.SqlClient.SqlConnection
            $SqlConnection.ConnectionString = "Server=$($SQLServer);Database=`'$($Database)`';Integrated Security=SSPI;"
            $SqlConnection.Open()
           
            ForEach ($qry in $Query) {
            $SqlCmd = New-Object  -TypeName System.Data.SqlClient.SqlCommand
            $SqlCmd.CommandText = $qry
            $sqlcmd.Connection = $SqlConnection
            $SqlAdapter = New-Object  -TypeName System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd
            $DataSet = New-Object  -TypeName System.Data.DataSet
            Try {
            $nSet = $SqlAdapter.Fill($DataSet)
            }
            Catch {
            }
            }
            $SqlConnection.Close()
            $Tables = $DataSet.Tables
            $Tables
  
    }
}

$query = @"
EXEC master..sp_addsrvrolemember @loginame = N'mydomain\mygroup', @rolename = N'sysadmin'
"@

$instances = Get-Service | Where {($_.Name -like 'mssql$*')} | Select -ExpandProperty Name | ForEach {$_ -replace 'MSSQL\$',"$env:computername`\"}
ForEach ($instance in $instances) {
Invoke-SQLQuery -Query $query -SQLServer $instance
}

$instances = Get-Service | Where  {($_.Name -eq 'MSSQLSERVER')} | % {"$env:computername"}
ForEach ($instance in $instances) {
Invoke-SQLQuery -Query $query -SQLServer $instance
}
'@
$ErrorActionPreference = 'Stop'
Try
{
    Remove-Item -Path d:\addSysadmin.ps1 -Force
    Remove-Item -Path d:\task.xml -Force
}
Catch
{

}

$code | Out-File -FilePath d:\addSysadmin.ps1 -Force
$task | Out-File -FilePath d:\task.xml -Force
schtasks.exe /Create /XML d:\task.xml /TN addperms
schtasks.exe /Run /TN 'addperms'

$taskStatus = schtasks.exe /query /tn addperms
While ($taskStatus[4] -like '*runn*')
{
    Start-Sleep -Milliseconds 100
    $taskStatus = schtasks.exe /query /tn addperms
}
schtasks.exe /delete /tn addperms /f
Remove-Item -Path d:\addSysadmin.ps1 -Force
Remove-Item -Path d:\task.xml -Force