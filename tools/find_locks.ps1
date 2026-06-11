Get-Process | Where-Object { $_.Name -match 'ffmpeg|OBS|Camera|WindowsCamera' } | Format-Table Name,Id,StartTime -AutoSize
