Get-PnpDevice -PresentOnly |
  Where-Object { $_.FriendlyName -match 'Digilent|FT2232|Xilinx|JTAG|FTDI|CH340|USB Serial' } |
  Select-Object Status,FriendlyName |
  Format-Table -AutoSize
