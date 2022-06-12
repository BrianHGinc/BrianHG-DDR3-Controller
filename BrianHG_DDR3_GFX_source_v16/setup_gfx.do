transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {ellipse_generator.sv}
vlog -sv -work work {BrianHG_draw_test_patterns.sv}
vlog -sv -work work {BrianHG_draw_test_patterns_tb.sv}
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc" BrianHG_draw_test_patterns_tb

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

#add  wave /BrianHG_draw_test_patterns_tb/*


add wave -divider     "RST/FUNC/CLK"
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/reset
add wave -binary      /BrianHG_draw_test_patterns_tb/switches
add wave -binary      /BrianHG_draw_test_patterns_tb/buttons
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/CLK
add wave -divider     "OUTPUT"
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/write_adr_out
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/write_busy_in
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/write_data_out
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/write_req_out 
add wave -divider     "INTERNAL-PW"
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/DUT_BHG_test_pat/pixel_cache_busy
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/DUT_BHG_test_pat/write_adr
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/DUT_BHG_test_pat/write_data
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/DUT_BHG_test_pat/write_req_cache 
add wave -divider     "GEO-COORD-PW"
add wave -hexadecimal /BrianHG_draw_test_patterns_tb/DUT_BHG_test_pat/elli* 

do run_gfx.do
