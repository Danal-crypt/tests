@echo off
powershell.exe -Command "
    # Get SplunkForwarder service
    $serviceName = 'SplunkForwarder'
    $service = Get-WmiObject -Class Win32_Service -Filter 'Name=''$serviceName'''

    # Check for the account the service is running as
    $serviceRunningAs = if ($service.StartName -and $service.StartName -ne '') {
        $service.StartName
    } else {
        $service.Name
    }

    # Extract specific properties for the report
    $processId = $service.ProcessId
    $startMode = $service.StartMode
    $name = $service.Name
    $state = $service.State
    $status = $service.Status

    # Get the hostname of the machine
    $hostname = [Environment]::MachineName

    # Format output with specific properties and hostname
    $report = 'host=' + $hostname + ', ServiceRunningAs=' + $serviceRunningAs + ', ProcessId=' + $processId + ', StartMode=' + $startMode + ', Name=' + $name + ', State=' + $state + ', Status=' + $status

    # Output the report
    Write-Output $report
"
pause
