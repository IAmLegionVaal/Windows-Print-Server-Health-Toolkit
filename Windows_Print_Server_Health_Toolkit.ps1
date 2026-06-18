#requires -Version 5.1
<#
.SYNOPSIS
    Windows Print Server Health Toolkit.
.DESCRIPTION
    Read-only print service, printer, driver, and event reporter for support review.
#>
[CmdletBinding()]
param([string]$OutputPath,[int]$Hours=72)
$RunStamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Print_Server_Reports'}
New-Item -Path $OutputPath -ItemType Directory -Force|Out-Null
$svc=Get-Service Spooler -ErrorAction SilentlyContinue|Select-Object Name,DisplayName,Status,StartType
$printers=Get-Printer -ErrorAction SilentlyContinue|Select-Object Name,DriverName,PortName,Shared,Published,PrinterStatus
$drivers=Get-PrinterDriver -ErrorAction SilentlyContinue|Select-Object Name,Manufacturer,MajorVersion,DriverVersion
$ports=Get-PrinterPort -ErrorAction SilentlyContinue|Select-Object Name,PrinterHostAddress,PortNumber,Description
$jobs=Get-PrintJob -PrinterName * -ErrorAction SilentlyContinue|Select-Object PrinterName,Id,DocumentName,JobStatus,SubmittedTime
$start=(Get-Date).AddHours(-1*$Hours)
$events=Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Operational';StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue|Select-Object -First 200 TimeCreated,Id,ProviderName,LevelDisplayName,Message
$svc|Export-Csv (Join-Path $OutputPath "spooler_service_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$printers|Export-Csv (Join-Path $OutputPath "printers_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$drivers|Export-Csv (Join-Path $OutputPath "printer_drivers_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$ports|Export-Csv (Join-Path $OutputPath "printer_ports_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$jobs|Export-Csv (Join-Path $OutputPath "print_jobs_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$events|Export-Csv (Join-Path $OutputPath "print_events_$RunStamp.csv") -NoTypeInformation -Encoding UTF8
$html="<h1>Print Server Health - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Service</h2>$($svc|ConvertTo-Html -Fragment)<h2>Printers</h2>$($printers|ConvertTo-Html -Fragment)<h2>Recent Events</h2>$($events|Select-Object -First 50|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Print Server Health'|Set-Content (Join-Path $OutputPath "print_server_health_$RunStamp.html") -Encoding UTF8
$svc|Format-List
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
