transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_DDR3_FIFOs.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER_v15.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER_v15_tb.sv}

vsim -t 1ps -L work -voptargs="+acc"  BrianHG_DDR3_COMMANDER_v15_tb


restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

#add  wave /BrianHG_DDR3_COMMANDER_v15_tb/*

add wave -divider "Script File"
add wave -ascii       /BrianHG_DDR3_COMMANDER_v15_tb/TB_COMMAND_SCRIPT_FILE
add wave -decimal     /BrianHG_DDR3_COMMANDER_v15_tb/Script_LINE
add wave -ascii       /BrianHG_DDR3_COMMANDER_v15_tb/Script_CMD
add wave -divider     "RST/CLK_in"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/RST_IN
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/RESET
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/PLL_LOCKED
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_CLK

add wave -divider     "COMM IO"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_busy
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_ena
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_addr
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_write_ena
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_wdata
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_wmask
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_read_vector_in
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_read_ready
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_read_data
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/CMD_read_vector_out


add wave -divider     "COMM -> DDR3_PHY_SEQ"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_BUSY_t
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_CMD_ENA_t
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_WRITE_ENA
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_ADDR
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_WMASK
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_WDATA
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_RDATA_VECT_IN
 
add wave -divider     "DDR3_PHY_SEQ -> COMM"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_RDATA_RDY_t
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_RDATA
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_v15_tb/SEQ_RDATA_VECT_OUT

do run_com_v15.do
