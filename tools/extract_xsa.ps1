Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path 'D:\xsa_extract') { Remove-Item -Recurse -Force 'D:\xsa_extract' }
[IO.Compression.ZipFile]::ExtractToDirectory('D:\workspace\zynq_pov\02_hello_zynq\02_hello_zynq.xsa', 'D:\xsa_extract')
Get-ChildItem 'D:\xsa_extract' -Recurse -Filter ps7_init.c | Select-Object FullName
