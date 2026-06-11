Write-Host "=== Cypress/Xilinx Cable enum ==="
Get-PnpDevice | Where-Object {
    $_.InstanceId -like '*VID_04B4*' -or
    $_.InstanceId -like '*VID_03FD*' -or
    $_.InstanceId -like '*VID_03BA*' -or
    $_.FriendlyName -like '*Xilinx*' -or
    $_.FriendlyName -like '*Cypress*' -or
    $_.FriendlyName -like '*Platform Cable*' -or
    $_.FriendlyName -like '*USB Download*'
} | Format-Table -AutoSize FriendlyName, Status, Class, InstanceId

Write-Host "`n=== All USB devices with VID/PID ==="
Get-PnpDevice -Class USB | Format-Table -AutoSize FriendlyName, Status, InstanceId

Write-Host "`n=== libusb-bound devices ==="
Get-PnpDevice | Where-Object {
    $_.Class -eq 'libusbK USB Devices' -or
    $_.Class -eq 'libusb-win32 devices' -or
    $_.Class -eq 'WinUSB devices'
} | Format-Table -AutoSize FriendlyName, Status, Class, InstanceId
