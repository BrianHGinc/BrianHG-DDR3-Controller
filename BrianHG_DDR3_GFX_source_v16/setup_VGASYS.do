transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Video_Line_Buffer.sv}
vlog -sv -work work {BrianHG_GFX_Window_DDR3_Reader.sv}
vlog -sv -work work {BrianHG_GFX_Layer_mixer.sv}
vlog -sv -work work {BrianHG_GFX_VGA_Window_System.sv}
vlog -sv -work work {BrianHG_GFX_VGA_Window_System_tb.sv}
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc" BrianHG_GFX_VGA_Window_System_tb

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

# add wave /BrianHG_GFX_Window_DDR3_Reader_tb/*


add wave -divider     "Settings"

add wave -divider     "CLK/RST"
add wave -unsigned    BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/VIDEO_MODE
add wave -unsigned    BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CLK_DIVIDER
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/VID_RST
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/VID_CLK

add wave -divider     "DDR3 read req"
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CMD_busy
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CMD_ena
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CMD_addr
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CMD_read_vector_tx 

add wave -divider     "DDR3 read return"
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CMD_read_ready
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CMD_read_vector_rx
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/CMD_rdata

add wave -divider     "Win Geometry"

add wave -divider     "SyncGen-LB"
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/HS_sg
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/VS_sg
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/H_ena_sg
add wave -unsigned    BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/v_count_sg
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/VID_CLK


add wave -divider     "LBO-to-mixer"
add wave -hexadecimal {BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/lb_VENA[0]}
add wave -hexadecimal {BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/lb_CLK_PHASE_OUT[0]}
add wave -unsigned    {BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/lb_h_count_out[0]}
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/lb_RGBA
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/lb_WLENA

add wave -divider     "Mixed Video Out"
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/mix_CLK_PHASE_OUT
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/mix_RGBA
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/mix_VENA_out 

add wave -divider     "End"
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/PIXEL_CLK
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/RGBA
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/VENA_out
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/HS_out
add wave -hexadecimal BrianHG_GFX_VGA_Window_System_tb/DUT_VGASYS/VS_out 

do run_VGASYS.do
