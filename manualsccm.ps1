# Requires Administrator privileges to run successfully.

#region Set Execution Policy (Use with Caution)
Write-Host "Setting execution policy to Unrestricted..."
Set-ExecutionPolicy Unrestricted -Force
Write-Host "Execution policy set to Unrestricted."
#endregion

#region Delete Contents of C:\Windows\ccmcache
Write-Host "Deleting contents of C:\Windows\ccmcache..."
try {
    Get-ChildItem -Path C:\Windows\ccmcache -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction Stop
    Write-Host "Successfully deleted contents of C:\Windows\ccmcache."
}
catch {
    Write-Warning "Failed to delete contents of C:\Windows\ccmcache. Error: $($_.Exception.Message)"
}
#endregion

#region Delete Contents of C:\Windows\Temp
Write-Host "Deleting contents of C:\Windows\Temp..."
try {
    # It's safer to iterate and delete files/folders individually in case some are in use
    Get-ChildItem -Path C:\Windows\Temp -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not delete $($_.FullName). Error: $($_.Exception.Message)"
        }
    }
    Write-Host "Attempted to delete contents of C:\Windows\Temp. Some files might remain if in use."
}
catch {
    Write-Warning "An error occurred while trying to delete contents of C:\Windows\Temp. Error: $($_.Exception.Message)"
}
#endregion

#region Delete Contents of C:\Users\[WA acct]\AppData\Local\Temp
Write-Host "Deleting contents of C:\Users\<Current User>\AppData\Local\Temp..."
$currentUserTempPath = Join-Path ( [Environment]::GetFolderPath('LocalApplicationData') ) "Temp"

if (Test-Path $currentUserTempPath) {
    try {
        Get-ChildItem -Path $currentUserTempPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not delete $($_.FullName). Error: $($_.Exception.Message)"
            }
        }
        Write-Host "Attempted to delete contents of $currentUserTempPath. Some files might remain if in use."
    }
    catch {
        Write-Warning "An error occurred while trying to delete contents of $currentUserTempPath. Error: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "User temp path not found: $currentUserTempPath"
}
#endregion

#region Run cleanmgr.exe with pre-selected options
Write-Host "Running cleanmgr.exe to clean up system files..."
$cleanMgrConfigID = 65535 # This ID is often used for a comprehensive set of options.

# Run cleanmgr.exe with the saved configuration
try {
    Start-Process cleanmgr.exe -ArgumentList "/sagerun:$cleanMgrConfigID" -Wait
    Write-Host "cleanmgr.exe finished running."
}
catch {
    Write-Warning "Failed to run cleanmgr.exe. Error: $($_.Exception.Message)"
}
#endregion

#region Run all SCCM Actions
Write-Host "Initiating all SCCM client actions..."
$SMSClient = Get-WmiObject -Namespace 'root\ccm' -Class 'SMS_Client'

if ($SMSClient) {
    try {
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000001}') | Out-Null # Hardware Inventory Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000002}') | Out-Null # Software Inventory Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000003}') | Out-Null # Discovery Data Collection Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000004}') | Out-Null # Policy Retrieval & Evaluation Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000005}') | Out-Null # Application Deployment Evaluation Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000006}') | Out-Null # Software Updates Scan Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000007}') | Out-Null # Software Updates Deployment Evaluation Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000008}') | Out-Null # State Message Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000009}') | Out-Null # User Policy Retrieval & Evaluation Cycle
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000010}') | Out-Null # Endpoint Protection Health Evaluation
        $SMSClient.TriggerSchedule('{00000000-0000-0000-0000-000000000011}') | Out-Null # User Data Collection Cycle

        # For more SCCM actions, you can query available schedules:
        # Get-WmiObject -Namespace 'root\ccm\Policy\Machine\ActualConfig' -Class 'CCM_Scheduler_ScheduledActions' | Select-Object ScheduleID, Name

        Write-Host "All common SCCM client actions have been triggered."
    }
    catch {
        Write-Warning "Failed to trigger SCCM client actions. Error: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "SCCM Client WMI object not found. Is SCCM client installed?"
}
#endregion

Write-Host "Script execution completed."
