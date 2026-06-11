Write-Host "=== Parent (USB Serial Converter) ==="
$parent = Get-PnpDevice | Where-Object { $_.InstanceId -eq 'USB\VID_0403&PID_6014\210251A08870' }
$parent | Format-List FriendlyName, Status, Class, InstanceId, Service
$parent | Get-PnpDeviceProperty -KeyName 'DEVPKEY_Device_DriverDesc','DEVPKEY_Device_DriverProvider','DEVPKEY_Device_DriverVersion','DEVPKEY_Device_DriverInfPath','DEVPKEY_Device_Service','DEVPKEY_Device_Children' -ErrorAction SilentlyContinue | Format-Table -AutoSize KeyName, Data

Write-Host "`n=== Child interfaces (FT232H usually exposes COM + WinUSB) ==="
Get-PnpDevice | Where-Object { $_.InstanceId -like '*FTV4Y*' -or $_.InstanceId -like '*210251A08870*' -or $_.InstanceId -like '*VID_0403&PID_6014*' } | Format-Table -AutoSize Status, Class, InstanceId, FriendlyName

Write-Host "`n=== Installed Digilent / Xilinx OEM INF ==="
$oem = & pnputil.exe /enum-drivers 2>&1
$oem -split "`r?`n" | Select-String -Pattern 'digilent|xilinx|xpcwinusb|smartlynq|ftdibus' -SimpleMatch
