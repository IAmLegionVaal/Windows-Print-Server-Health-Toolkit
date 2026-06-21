[CmdletBinding()]
param(
    [switch]$RestartSpooler,
    [string]$PrinterName,
    [switch]$ClearJobs,
    [switch]$ResumeJobs,
    [switch]$ClearSpoolDirectory,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$OutputPath = (Join-Path $env:ProgramData 'WindowsPrintServerRepair')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:VerificationFailures = 0
$script:Actions = 0

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:OS -ne 'Windows_NT') { Write-Error 'This tool requires Windows.'; exit 3 }
if (-not ($RestartSpooler -or $ClearJobs -or $ResumeJobs -or $ClearSpoolDirectory)) { Write-Error 'Choose at least one repair action.'; exit 2 }
if (($ClearJobs -or $ResumeJobs) -and [string]::IsNullOrWhiteSpace($PrinterName)) { Write-Error '-PrinterName is required for job actions.'; exit 2 }
if (-not $DryRun -and -not (Test-Administrator)) { Write-Error 'Run from an elevated PowerShell session.'; exit 4 }
Import-Module PrintManagement -ErrorAction Stop
if ($PrinterName) { Get-Printer -Name $PrinterName -ErrorAction Stop | Out-Null }

$runPath = Join-Path $OutputPath (Get-Date -Format 'yyyyMMdd_HHmmss')
$backupPath = Join-Path $runPath 'backup'
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
$logPath = Join-Path $runPath 'repair.log'
$beforePath = Join-Path $runPath 'before.json'
$afterPath = Join-Path $runPath 'after.json'

function Write-Log([string]$Message) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Tee-Object -FilePath $logPath -Append
}

function Get-RepairState {
    $jobs = @()
    if ($PrinterName) { $jobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue | Select-Object ID,DocumentName,JobStatus,SubmittedTime,UserName) }
    [pscustomobject]@{
        Collected = Get-Date
        Spooler = Get-Service Spooler | Select-Object Name,Status,StartType
        Printer = if ($PrinterName) { Get-Printer -Name $PrinterName | Select-Object Name,ComputerName,DriverName,PortName,PrinterStatus,WorkOffline } else { $null }
        Jobs = $jobs
        SpoolFiles = @(Get-ChildItem (Join-Path $env:SystemRoot 'System32\spool\PRINTERS') -Force -ErrorAction SilentlyContinue | Select-Object Name,Length,LastWriteTime)
    }
}

function Invoke-RepairAction([string]$Description, [scriptblock]$Action) {
    $script:Actions++
    Write-Log "ACTION: $Description"
    if ($DryRun) { Write-Log "DRY-RUN: $Description"; return }
    try {
        $result = & $Action 2>&1
        if ($null -ne $result) { $result | Out-String | Add-Content -Path $logPath }
        Write-Log "SUCCESS: $Description"
    } catch {
        $script:Failures++
        Write-Log "FAILED: $Description - $($_.Exception.Message)"
    }
}

Get-RepairState | ConvertTo-Json -Depth 8 | Set-Content -Path $beforePath -Encoding UTF8
Get-Printer | Select-Object Name,DriverName,PortName,PrinterStatus,WorkOffline | Export-Clixml (Join-Path $backupPath 'printers.xml')
if ($PrinterName) {
    Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue | Export-Clixml (Join-Path $backupPath 'selected-printer-jobs.xml')
    Get-PrintConfiguration -PrinterName $PrinterName -ErrorAction SilentlyContinue | Export-Clixml (Join-Path $backupPath 'selected-printer-configuration.xml')
}

if (-not $DryRun -and -not $Yes) {
    if ((Read-Host 'Apply the selected print-server repairs? Type YES') -cne 'YES') { Write-Log 'Repair cancelled.'; exit 10 }
}

if ($RestartSpooler) {
    Invoke-RepairAction 'Restarting the Print Spooler service' { Restart-Service Spooler -Force; (Get-Service Spooler).WaitForStatus('Running',[TimeSpan]::FromSeconds(30)) }
}
if ($ClearJobs) {
    Invoke-RepairAction "Cancelling all jobs on $PrinterName" { Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue | Remove-PrintJob -Confirm:$false }
}
if ($ResumeJobs) {
    Invoke-RepairAction "Resuming paused jobs on $PrinterName" { Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue | Where-Object JobStatus -Match 'Paused' | Resume-PrintJob }
}
if ($ClearSpoolDirectory) {
    $spoolPath = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
    Invoke-RepairAction 'Backing up and clearing the spool directory' {
        Stop-Service Spooler -Force
        try {
            $files = @(Get-ChildItem $spoolPath -Force -ErrorAction SilentlyContinue)
            if ($files) { Copy-Item $files.FullName -Destination $backupPath -Force; Remove-Item $files.FullName -Force }
        } finally {
            Start-Service Spooler
        }
    }
}

if (-not $DryRun) { Start-Sleep -Seconds 2 }
$state = Get-RepairState
$state | ConvertTo-Json -Depth 8 | Set-Content -Path $afterPath -Encoding UTF8
if ($RestartSpooler -or $ClearSpoolDirectory) {
    if ((Get-Service Spooler).Status -ne 'Running') { $script:VerificationFailures++; Write-Log 'VERIFY FAILED: Spooler is not running.' }
}
if ($ClearJobs -and @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue).Count -gt 0) { $script:VerificationFailures++; Write-Log "VERIFY FAILED: Jobs remain on $PrinterName." }

if ($script:Failures -gt 0) { exit 20 }
if ($script:VerificationFailures -gt 0) { exit 30 }
Write-Log "Repair completed. Actions: $script:Actions"
exit 0
