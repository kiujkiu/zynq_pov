$wrapper = 'C:\Xilinx\Vivado\2024.2\data\xicom\cable_drivers\nt64\install_drivers_wrapper.bat'
$wdir    = 'C:\Xilinx\Vivado\2024.2\data\xicom\cable_drivers\nt64'
$log     = 'C:\Users\kiujkiu\xinst.log'

Write-Host "Spawning elevated installer..."
Write-Host "  wrapper = $wrapper"
Write-Host "  log     = $log"

try {
    $p = Start-Process -FilePath 'cmd.exe' `
        -ArgumentList '/c', "`"$wrapper`" -log_filename `"$log`"" `
        -WorkingDirectory $wdir `
        -Verb RunAs -Wait -PassThru -ErrorAction Stop
    Write-Host "Installer exit code: $($p.ExitCode)"
} catch {
    Write-Host "Start-Process failed: $($_.Exception.Message)"
    exit 2
}

if (Test-Path $log) {
    Write-Host "`n=== Log tail ==="
    Get-Content $log -Tail 80
} else {
    Write-Host "Log not generated at $log"
}
