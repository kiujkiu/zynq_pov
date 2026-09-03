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
phase { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 28
	offset_end 35
}
n_slots { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 36
	offset_end 43
}
axis_off_q8 { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 44
	offset_end 51
}
mirror_u { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 52
	offset_end 59
}
pf_cols { 
	dir I
	width 32
	depth 1
	mode ap_none
	offset 60
	offset_end 67
}
xor_out { 
	dir O
	width 64
	depth 1
	mode ap_vld
	offset 68
	offset_end 79
}
}
dict set axilite_register_dict control $port_control


