# Windows Print Server Health Toolkit

A PowerShell toolkit for Windows print-server health review and guarded queue or spooler repair.

## Diagnostic script

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Print_Server_Health_Toolkit.ps1
```

The diagnostic script reports Print Spooler status, printers, drivers, ports, jobs and recent print events.

## Repair script

Preview a repair:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Print_Server_Repair_Toolkit.ps1 -RestartSpooler -DryRun
```

Examples:

```powershell
.\Windows_Print_Server_Repair_Toolkit.ps1 -RestartSpooler
.\Windows_Print_Server_Repair_Toolkit.ps1 -PrinterName 'Accounts Printer' -ClearJobs
.\Windows_Print_Server_Repair_Toolkit.ps1 -PrinterName 'Accounts Printer' -ResumeJobs
.\Windows_Print_Server_Repair_Toolkit.ps1 -ClearSpoolDirectory
```

## Repair behaviour

- Restarts the Print Spooler service.
- Cancels or resumes jobs only on an explicitly selected queue.
- Can back up and clear files from the spool directory while the Spooler is stopped.
- Captures printer, job, service and spool-file state before and after repair.
- Exports printer and selected-queue configuration evidence before changes.
- Supports `-DryRun`, confirmation prompts or `-Yes`, administrator checks, action logs and post-repair verification.

## Safety and exit codes

Clearing jobs or spool files is irreversible for the active queue, although spool files are copied into the run backup directory first. The tool does not add or remove printers, drivers or ports.

Exit codes: `0` success, `2` invalid arguments, `3` unsupported platform, `4` elevation required, `10` cancelled, `20` action failure and `30` verification failure.

## Validation note

The repair script was committed and statically reviewed, but it was not runtime-tested on a Windows print server.

## Author

Dewald Pretorius — L2 IT Support Engineer
