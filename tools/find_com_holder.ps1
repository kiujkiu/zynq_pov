Get-Process | Where-Object { $_.ProcessName -match 'python|putty|minicom|tera|term' } |
  Select-Object Id, ProcessName, Path, StartTime |
  Format-Table -AutoSize
