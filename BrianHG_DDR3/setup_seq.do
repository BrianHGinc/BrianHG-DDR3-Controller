transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_DDR3_FIFOs.sv}
vlog -sv -work work {BrianHG_DDR3_CMD_SEQUENCER.sv}
vlog -sv -work work {BrianHG_DDR3_CMD_SEQUENCER_tb.sv}

vsim -t 1ps -L work -voptargs="+acc"  BrianHG_DDR3_CMD_SEQUENCER_tb

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

#add  wave /BrianHG_DDR3_CMD_SEQUENCER_tb/*

add wave -divider "Script File"
add wave -ascii       /BrianHG_DDR3_CMD_SEQUENCER_tb/TB_COMMAND_SCRIPT_FILE
add wave -decimal     /BrianHG_DDR3_CMD_SEQUENCER_tb/Script_LINE
add wave -ascii       /BrianHG_DDR3_CMD_SEQUENCER_tb/Script_CMD
add wave -divider     "RST/CMD_CLK"
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/RST_IN
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/REF_REQ
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/REF_ACK
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IDLE
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_CLK
add wave -divider     "Command Input"
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_BUSY
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_ENA
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_WENA
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_BANK
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_RAS
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_CAS
add wave -unsigned    /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_WDATA
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_WMASK 
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/IN_VECTOR
add wave -divider     "Command Output"
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_ACK 
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_READY 
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_CMD 
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_NAME 
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_BANK
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_A
add wave -unsigned    /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_WDATA
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_WMASK
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/CMD_VECTOR
add wave -divider     "Internals"
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/DUT_CMD_SEQ/S4_busy
add wave -hexadecimal /BrianHG_DDR3_CMD_SEQUENCER_tb/DUT_CMD_SEQ/IN_REF_REQ

do run_seq.do
