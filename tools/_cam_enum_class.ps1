Get-PnpDevice -Class Image,Camera -Status OK | Format-Table Status, FriendlyName, InstanceId -AutoSize
Write-Host "--- 4 1432 (cameras present via WMI) ---"
Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPClass -in 'Image','Camera','Media' -and $_.Status -eq 'OK' } | Format-Table Name, PNPClass, Status -AutoSize
