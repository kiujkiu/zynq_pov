Get-PnpDevice -PresentOnly | Where-Object {
  $_.Class -in @('Camera','Image','Media') -or
  $_.FriendlyName -match 'Camera|Capture|Webcam|UVC|HDMI|Cam'
} | Select-Object Class,Status,FriendlyName | Format-Table -AutoSize
