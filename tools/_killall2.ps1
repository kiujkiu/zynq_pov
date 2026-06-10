for ($i=0; $i -lt 30; $i++) {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -like '*xsdb*' -or $_.ProcessName -like 'hw_server*'} | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
}
$r = Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -like '*xsdb*' -or $_.ProcessName -like 'hw_server*'}
if ($r) { Write-Host "STILL:"; $r | ft Id,ProcessName } else { Write-Host "CLEAN" }
