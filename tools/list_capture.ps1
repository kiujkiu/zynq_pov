Get-PnpDevice -PresentOnly |
  Where-Object { $_.Class -in @('Camera','Image') -or
                  $_.FriendlyName -match 'Video|Capture|HDMI|UVC|C1' } |
  Select-Object Status, FriendlyName, Class, InstanceId | Format-List
