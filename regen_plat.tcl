puts "regen: starting"
set ws "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws"
set xsa_new "$ws/hello_plat/hw/02_hello_zynq.xsa"
# Vitis 2024.2 Unified: setws then importprojects (or use vitis Python cli)
setws $ws
puts "regen: ws = $ws"
catch {platform read "$ws/hello_plat/vitis-comp.json"} r1
puts "regen: platform read => $r1"
catch {platform active hello_plat} r2
puts "regen: active => $r2"
catch {platform config -updatehw $xsa_new} r3
puts "regen: updatehw => $r3"
catch {platform generate} r4
puts "regen: generate => $r4"
puts "regen: DONE"
exit
