param([int]$seconds = 8)
$port = New-Object System.IO.Ports.SerialPort COM4,921600,'None',8,'One'
$port.ReadTimeout = 200
try { $port.Open() } catch { Write-Output ("err open: " + $_.Exception.Message); exit 1 }
$buf = ""
$deadline = (Get-Date).AddSeconds($seconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 50
    if ($port.BytesToRead -gt 0) { $buf += $port.ReadExisting() }
}
$port.Close()
Write-Output "---BEGIN UART---"
Write-Output $buf
Write-Output "---END UART---"
