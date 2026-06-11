param([int]$Seconds = 35)
$port = New-Object System.IO.Ports.SerialPort COM5,921600,None,8,one
$port.ReadTimeout = 5000
$port.Open()
Start-Sleep -Seconds $Seconds
$data = ""
while($port.BytesToRead -gt 0) {
    $data += $port.ReadExisting()
}
Write-Host $data
$port.Close()
