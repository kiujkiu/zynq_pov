$port = New-Object System.IO.Ports.SerialPort COM5,921600,None,8,one
$port.ReadTimeout = 5000
$port.Open()
Start-Sleep -Seconds 5
$data = ""
while($port.BytesToRead -gt 0) {
    $data += $port.ReadExisting()
}
Write-Host $data
$port.Close()
