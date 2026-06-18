# Windows Print Server Health Toolkit

A read-only PowerShell toolkit for Windows print server health review.

## Features

- Print service status
- Printer and driver inventory
- Print queue context
- Print-related event log summary
- CSV, JSON, and HTML reports

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Print_Server_Health_Toolkit.ps1
```

## Safety

Diagnostic-only. It reports print server context and does not change printers, drivers, ports, or queues.
