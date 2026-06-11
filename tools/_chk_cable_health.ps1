$id = 'USB\VID_0403&PID_6014\210251A08870'
Write-Host "=== USB descriptor + power state ==="
Get-PnpDeviceProperty -InstanceId $id -KeyName `
    'DEVPKEY_Device_BusNumber',`
    'DEVPKEY_Device_Address',`
    'DEVPKEY_Device_PowerState',`
    'DEVPKEY_Device_PowerData',`
    'DEVPKEY_Device_DevNodeStatus',`
    'DEVPKEY_Device_ProblemCode',`
    'DEVPKEY_Device_LocationInfo',`
    'DEVPKEY_Device_PDOName',`
    'DEVPKEY_Device_Manufacturer',`
    'DEVPKEY_Device_FriendlyName',`
    'DEVPKEY_Device_Class',`
    'DEVPKEY_Device_DriverDate',`
    'DEVPKEY_Device_DriverVersion',`
    'DEVPKEY_Device_DriverInfPath',`
    'DEVPKEY_Device_DriverProvider',`
    'DEVPKEY_Device_Service',`
    -ErrorAction SilentlyContinue | Format-Table -AutoSize KeyName, Data

Write-Host "`n=== Run hw_server with full protocol log ==="
$logFile = "$env:TEMP\hws_full.log"
if (Test-Path $logFile) { Remove-Item $logFile }
$hws = Start-Process 'C:\Xilinx\Vitis\2024.2\bin\unwrapped\win64.o\hw_server.exe' `
    -ArgumentList "-L$logFile", "-lprotocol,plugin,context,asyncreq" `
    -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 3

$xsdbScript = "$env:TEMP\_jp.tcl"
@'
connect
after 1500
puts "--- jtag targets ---"
jtag targets
puts "--- targets ---"
targets
exit 0
'@ | Out-File -Encoding ASCII $xsdbScript
& 'C:\Xilinx\Vitis\2024.2\bin\xsdb.bat' $xsdbScript 2>&1 | Out-String | Write-Host
Stop-Process -Id $hws.Id -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "`n=== hw_server log (last 60 lines) ==="
if (Test-Path $logFile) {
    Get-Content $logFile -Tail 60
} else {
    Write-Host "(no log written)"
}
