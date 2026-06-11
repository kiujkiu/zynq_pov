Write-Host "=== FTDIBUS driver install date / oem31.inf ==="
$infPath = "$env:SystemRoot\INF\oem31.inf"
if (Test-Path $infPath) {
    Get-Item $infPath | Format-List Name, FullName, CreationTime, LastWriteTime
}
Write-Host "--- ftdibus.sys date ---"
Get-Item C:\Windows\System32\drivers\ftdibus.sys -ErrorAction SilentlyContinue | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        Version = $_.VersionInfo.FileVersion
        Modified = $_.LastWriteTime
        Created = $_.CreationTime
    }
} | Format-Table -AutoSize

Write-Host "`n=== FT232H exposes Channel A (JTAG) and B (UART)? ==="
Write-Host "Digilent 用 Channel A 做 JTAG. 如果只看到 USB Serial Converter 而没看到 'USB Serial Port (COMx)', 说明 VCP 没绑 Channel A = 正常 (Adept 接管)."
Get-PnpDevice | Where-Object { $_.InstanceId -like '*210251A08870*' -or ($_.InstanceId -like '*VID_0403&PID_6014*' -and $_.Status -eq 'OK') } | Format-Table -AutoSize Status, Class, FriendlyName, InstanceId
Write-Host "--- COM ports right now ---"
Get-PnpDevice -Class Ports | Format-Table -AutoSize Status, FriendlyName, InstanceId

Write-Host "`n=== Windows Update history (recent) ==="
try {
    $u = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
    $hist = $u.QueryHistory(0, 30)
    $hist | Where-Object { $_.Date -gt (Get-Date).AddDays(-10) } |
        Select-Object Date, Title, ResultCode | Format-Table -AutoSize
} catch {
    Write-Host "Windows Update history query failed: $($_.Exception.Message)"
}

Write-Host "`n=== Last boot time ==="
(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
