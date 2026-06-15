# 重烧 LIVE 板子前先跑这个停 DMA (PL 已配置时用; 冷启动 PL 空别跑这个)
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
catch { mwr -force 0x40020000 0 }
after 300
puts "DMA stopped (CTRL=0)"
disconnect
