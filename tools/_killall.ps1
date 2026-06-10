Get-Process | Where-Object {$_.ProcessName -like '*xsdb*' -or $_.ProcessName -like '*hw_server*'} | Stop-Process -Force
Start-Sleep -Seconds 2
$remaining = Get-Process | Where-Object {$_.ProcessName -like '*xsdb*' -or $_.ProcessName -like '*hw_server*'}
if ($remaining) { Write-Host "STILL RUNNING:"; $remaining | ft Id,ProcessName } else { Write-Host "ALL DEAD" }
