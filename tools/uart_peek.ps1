param(
    [string]$Port = "COM4",
    [int]$Baud = 921600,
    [int]$Seconds = 3
)
$p = New-Object System.IO.Ports.SerialPort $Port,$Baud,'None',8,'One'
$p.ReadTimeout = 1000
try {
    $p.Open()
    $deadline = (Get-Date).AddSeconds($Seconds)
    $buf = ""
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        if ($p.BytesToRead -gt 0) {
            $buf += $p.ReadExisting()
        }
    }
    Write-Output "---BEGIN UART (${Port} @ ${Baud})---"
    Write-Output $buf
    Write-Output "---END UART---"
    $p.Close()
} catch {
    Write-Output ("ERR: " + $_.Exception.Message)
}
