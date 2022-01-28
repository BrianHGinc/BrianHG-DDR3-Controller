transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Sync_Gen_tb.sv}
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc" BrianHG_GFX_Sync_Gen_tb

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

# add wave /BrianHG_GFX_Sync_Gen_tb/*


add wave -divider     "Settings"
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_h_res 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_h_total 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_hs_front_porch 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_hs_size 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_hs_polarity 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_v_res 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_v_total 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_vs_front_porch 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_vs_size 
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VID_vs_polarity 

add wave -divider     "CLK/RST"
add wave -hexadecimal BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/reset
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/CLK_DIVIDE_IN
add wave -hexadecimal BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/CLK_IN

add wave -divider     "Output"
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/CLK_PHASE_OUT
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/h_count_out
add wave -hexadecimal BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/H_ena
add wave -hexadecimal BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/V_ena
add wave -hexadecimal BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/Video_ena
add wave -hexadecimal BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/HS_out
add wave -hexadecimal BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/VS_out
add wave -unsigned    BrianHG_GFX_Sync_Gen_tb/DUT_BHG_Sync_Gen/v_count_out


do run_sg.do
