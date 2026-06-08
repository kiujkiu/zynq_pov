Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match 'Digilent|JTAG|FTDI|FT2232|CH340|USB Serial' } | Format-Table -Property Class,FriendlyName,Status -AutoSize
