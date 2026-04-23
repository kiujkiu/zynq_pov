Get-Process python*,java*,vitis*,xsct*,tcf-agent*,rdi* -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "$($_.Name) $($_.Id)" ; Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1
Remove-Item -Force 'D:\workspace\zynq_pov\02_hello_zynq\vitis_ws\_ide\.wsdata\.lock' -ErrorAction SilentlyContinue
if (Test-Path 'D:\workspace\zynq_pov\02_hello_zynq\vitis_ws\_ide\.wsdata\.lock') { Write-Host "LOCK STILL EXISTS" } else { Write-Host "LOCK REMOVED" }
