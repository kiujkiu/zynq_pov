Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match 'USB Serial|FTDI|Digilent|JTAG' } | ForEach-Object {
  $dev = $_
  $drv = Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverProvider' -ErrorAction SilentlyContinue
  $cls = Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverDesc' -ErrorAction SilentlyContinue
  $hwid = Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction SilentlyContinue
  Write-Host ""
  Write-Host "FriendlyName : $($dev.FriendlyName)"
  Write-Host "  Class      : $($dev.Class)"
  Write-Host "  InstanceId : $($dev.InstanceId)"
  Write-Host "  DriverDesc : $($cls.Data)"
  Write-Host "  Provider   : $($drv.Data)"
  Write-Host "  HardwareId : $($hwid.Data)"
}
