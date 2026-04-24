Get-Process | Where-Object {
  $_.ProcessName -match 'java|vitis|hw_server|xvs|python|xilinx'
} | Select-Object Id, ProcessName, Path, StartTime | Format-Table -AutoSize
