transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_DDR3_FIFOs.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER_tb.sv}

vsim -t 1ps -L work -voptargs="+acc"  BrianHG_DDR3_COMMANDER_tb


restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

#add  wave /BrianHG_DDR3_COMMANDER_tb/*

add wave -divider "Script File"
add wave -ascii       /BrianHG_DDR3_COMMANDER_tb/TB_COMMAND_SCRIPT_FILE
add wave -decimal     /BrianHG_DDR3_COMMANDER_tb/Script_LINE
add wave -ascii       /BrianHG_DDR3_COMMANDER_tb/Script_CMD
add wave -divider     "RST/CLK_in"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/RST_IN
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/RESET
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/PLL_LOCKED
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_CLK

add wave -divider     "COMM IO-READ"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_R_busy
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_read_req
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_raddr
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_read_vector_in
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_read_ready
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_read_data
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_read_vector_out
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_read_addr_out

add wave -divider     "COMM IO-WRITE"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_W_busy
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_write_req 
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_waddr
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_wdata
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/CMD_wmask

add wave -divider     "*** DUT_COMMANDER ***"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/RC_WC_cache_hit
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_RC_cache_hit 
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/SEQ_RDVEC_FROM_DDR3

add wave -divider     "Read Cache Port"
add wave -binary      /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/RC_ddr3_read_req
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/RC_cache_hit 
add wave -binary      /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/RC_page_hit
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/RC_ready

add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/read_req
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/read_req_ack
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/FIFO_raddr_req
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/FIFO_rvi_req
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/CMD_read_data
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/CMD_read_ready
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/CMD_read_vector_out 
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/read_req_sel
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/any_read_req
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/RC_burst_limit

add wave -divider     "Write Cache Port"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_cache_hit
add wave -binary      /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_page_hit 
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_ready
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_tout
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_waddr
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_wdata
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/WC_wmask
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/write_req
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/write_req_ack
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/write_req_sel 
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/any_write_req 

add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/FIFO_waddr
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/FIFO_wdata
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/FIFO_wmask 

add wave -divider     "COMM -> DDR3_PHY_SEQ"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_BUSY_t
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_CMD_ENA_t
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_WRITE_ENA
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_ADDR
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_WMASK
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_WDATA
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_RDATA_VECT_IN
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/DUT_COMMANDER/act_bank_row 
add wave -divider     "DDR3_PHY_SEQ -> COMM"
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_RDATA_RDY_t
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_RDATA
add wave -hexadecimal /BrianHG_DDR3_COMMANDER_tb/SEQ_RDATA_VECT_OUT

do run_com.do
