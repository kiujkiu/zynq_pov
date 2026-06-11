$installer = "C:\Xilinx\Vivado\2024.2\data\xicom\cable_drivers\nt64\install_drivers_wrapper.bat"
$logFile = "C:\Users\kiujkiu\install_xilinx_cable.log"

Write-Host "Launching elevated installer: $installer"
Write-Host "Output log: $logFile"

$proc = Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c", "`"$installer`" -log_filename `"$logFile`"" `
    -WorkingDirectory "C:\Xilinx\Vivado\2024.2\data\xicom\cable_drivers\nt64" `
    -Verb RunAs -Wait -PassThru

Write-Host "Exit code: $($proc.ExitCode)"
if (Test-Path $logFile) {
    Write-Host "`n=== Log ==="
    Get-Content $logFile -Tail 40
}
