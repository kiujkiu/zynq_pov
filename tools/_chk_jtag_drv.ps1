$dev = Get-PnpDevice | Where-Object { $_.InstanceId -eq 'USB\VID_0403&PID_6014\210251A08870' }
$dev | Format-List FriendlyName, Status, Class, InstanceId, Manufacturer, DriverProviderName
Write-Host "--- Driver details ---"
$dev | Get-PnpDeviceProperty -KeyName 'DEVPKEY_Device_DriverDesc','DEVPKEY_Device_DriverProvider','DEVPKEY_Device_DriverVersion','DEVPKEY_Device_DriverInfPath' -ErrorAction SilentlyContinue | Format-Table -AutoSize KeyName, Data
