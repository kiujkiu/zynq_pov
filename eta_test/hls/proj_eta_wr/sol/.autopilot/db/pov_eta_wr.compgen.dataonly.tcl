# This script segment is generated automatically by AutoPilot

set axilite_register_dict [dict create]
set port_control {
voxel { 
	dir I
	width 64
	depth 1
	mode ap_none
	offset 16
	offset_end 27
}
slot_base { 
	dir I
	width 64
	depth 1
	mode ap_none
	offset 28
	offset_end 39
}
phase { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 40
	offset_end 47
}
slot_start { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 48
	offset_end 55
}
n_slots { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 56
	offset_end 63
}
axis_off_q8 { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 64
	offset_end 71
}
mirror_u { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 72
	offset_end 79
}
}
dict set axilite_register_dict control $port_control


