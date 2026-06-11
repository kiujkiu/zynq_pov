$id = 'USB\VID_0403&PID_6014\210251A08870'
$dev = Get-PnpDevice -InstanceId $id

Write-Host "=== Parent ==="
$dev | Format-List FriendlyName, Status, Class, Service, InstanceId

Write-Host "`n=== Device Properties (driver INF) ==="
Get-PnpDeviceProperty -InstanceId $id | Where-Object {
    $_.KeyName -match 'DriverDesc|DriverProvider|DriverInfPath|DriverVersion|DriverDate|HardwareIds|Service|CompatibleIds|MatchingDeviceId|ContainerId|Children'
} | Format-Table -AutoSize KeyName, Data

Write-Host "`n=== Container siblings (same physical USB device) ==="
$container = (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_ContainerId').Data
Write-Host "Container ID: $container"
Get-PnpDevice | Where-Object {
    try {
        (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_ContainerId' -ErrorAction SilentlyContinue).Data -eq $container
    } catch { $false }
} | Format-Table -AutoSize Status, Class, FriendlyName, InstanceId

Write-Host "`n=== Compare: what Digilent driver SHOULD show ==="
Write-Host "Expected when Digilent driver bound: 'Digilent USB Device' under class 'libusbK USB Devices' or similar (NOT 'USB Serial Converter' under FTDIBUS class)"
Write-Host "Current: FTDIBUS service = FTDI generic VCP driver, Adept can talk via FTD2XX but Vivado 2024.2 hw_server may need libdjtg.dll path"
