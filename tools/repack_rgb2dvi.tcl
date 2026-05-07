# repack_rgb2dvi.tcl — 让 Vivado 2024.2 自己重新打包 Digilent rgb2dvi IP
# 解决: master 分支 component.xml 的 IP-XACT 模板与 Vivado 2024.2 不兼容,
#       generate_target 时 model parameters (kGenerateSerialClk/kClkPrimitive 等)
#       的 VHDL 类型映射全部为空, 生成的 wrapper.vhd 是 "kGenerateSerialClk : ;".
#
# 用法:
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch -source repack_rgb2dvi.tcl -nojournal

set ip_dir "D:/workspace/zynq_pov/vivado-library/ip/rgb2dvi"
set comp_xml "$ip_dir/component.xml"

if {![file exists $comp_xml]} {
    puts "ERROR: component.xml not found at $comp_xml"
    exit 1
}

puts "=== Backup original component.xml ==="
file copy -force $comp_xml "$comp_xml.orig"

puts "=== Create in-memory project ==="
create_project -in_memory -part xc7z020clg484-2 -force tmp_repack

puts "=== Open IP for edit (this triggers re-parse of VHDL sources) ==="
# Vivado 会读 src/rgb2dvi.vhd 的 entity declaration, 自己推导 generic 类型
# 然后把它们写回 IP-XACT XML
ipx::edit_ip_in_project -upgrade true -name edit_rgb2dvi -directory [pwd]/tmp_edit $comp_xml

puts "=== Merge HDL changes (pulls fresh generic types from .vhd) ==="
ipx::merge_project_changes hdl_parameters [ipx::current_core]
ipx::merge_project_changes ports [ipx::current_core]

puts "=== Re-create XGUI + checksums + save ==="
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

puts "=== Close edit project ==="
close_project -delete

puts "=== Verify new component.xml has proper VHDL type mappings ==="
set fp [open $comp_xml r]
set xml [read $fp]
close $fp

# 简单 check: 看 modelParameter 的 spirit:dataType 是否还是空的
if {[regexp {<spirit:modelParameter[^>]*spirit:dataType=""[^>]*>} $xml]} {
    puts "WARN: 仍有 dataType=\"\" 的 modelParameter, 可能仍不兼容"
}
if {[regexp {kGenerateSerialClk.*\n.*spirit:dataType="boolean"} $xml]} {
    puts "OK: kGenerateSerialClk 找到 dataType=boolean"
}
puts "=== DONE ==="
