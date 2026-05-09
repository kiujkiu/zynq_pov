# 同时打开 UART, 然后 trigger dl_helloworld.tcl, 抓 boot banner.
$port = New-Object System.IO.Ports.SerialPort COM4,921600,'None',8,'One'
$port.ReadTimeout = 200
try { $port.Open() } catch { Write-Output ("err open: " + $_.Exception.Message); exit 1 }
$buf = ""
# 启动 dl
Start-Process -FilePath cmd.exe -ArgumentList '/c "D:\Vitis\2024.2\bin\xsdb.bat D:\workspace\zynq_pov\tools\dl_helloworld.tcl"' -NoNewWindow -PassThru | Out-Null
$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 50
    if ($port.BytesToRead -gt 0) {
        $buf += $port.ReadExisting()
    }
}
$port.Close()
Write-Output "---BEGIN UART---"
Write-Output $buf
Write-Output "---END UART---"
