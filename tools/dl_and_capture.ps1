$port = New-Object System.IO.Ports.SerialPort COM5,921600,None,8,one
$port.ReadTimeout = 5000
$port.Open()
# Start xsdb dl in background while UART listens
$xsdb = Start-Process -FilePath "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat" `
    -ArgumentList "D:\workspace\zynq_pov\tools\dl_helloworld.tcl" `
    -NoNewWindow -PassThru -RedirectStandardOutput "D:\workspace\zynq_pov\tools\dl_out.log"
Start-Sleep -Seconds 12
$xsdb.WaitForExit(2000)
$data = ""
while($port.BytesToRead -gt 0) {
    $data += $port.ReadExisting()
    Start-Sleep -Milliseconds 50
}
Write-Host "=== UART CAPTURE ==="
Write-Host $data
$port.Close()
