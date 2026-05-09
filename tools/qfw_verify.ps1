$port = New-Object System.IO.Ports.SerialPort COM4,921600,'None',8,'One'
$port.ReadTimeout = 200
try { $port.Open() } catch { Write-Output ("err open: " + $_.Exception.Message); exit 1 }
$buf = ""
Start-Process -FilePath cmd.exe -ArgumentList '/c "D:\Vitis\2024.2\bin\xsdb.bat D:\workspace\zynq_pov\tools\dl_qspi_verify.tcl"' -NoNewWindow -PassThru | Out-Null
$deadline = (Get-Date).AddSeconds(240)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 100
    if ($port.BytesToRead -gt 0) {
        $chunk = $port.ReadExisting()
        $buf += $chunk
        Write-Host -NoNewline $chunk
        if ($buf -match "MATCH BOOT.bin|MISMATCH|verify\] done") {
            break
        }
    }
}
$port.Close()
Write-Output "`n---END UART---"
