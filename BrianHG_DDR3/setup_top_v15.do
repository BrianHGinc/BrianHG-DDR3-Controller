transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {altera_gpio_lite.sv}
vlog -sv -work work {BrianHG_DDR3_GEN_tCK.sv}
vlog -sv -work work {BrianHG_DDR3_PLL.sv}
vlog -sv -work work {BrianHG_DDR3_FIFOs.sv}
vlog -sv -work work {BrianHG_DDR3_CMD_SEQUENCER.sv}
vlog -sv -work work {BrianHG_DDR3_IO_PORT_ALTERA.sv}
vlog -sv -work work {BrianHG_DDR3_PHY_SEQ.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER_v15.sv}
vlog -sv -work work {BrianHG_DDR3_CONTROLLER_v15_top.sv}
vlog -sv -work work {BrianHG_DDR3_CONTROLLER_v15_top_tb.sv}


# Make Cyclone IV E Megafunctions and PLL available.
#vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc"  BrianHG_DDR3_CONTROLLER_v15_top_tb

# Make MAX 10 Megafunctions and PLL available.
#vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L work -voptargs="+acc" BrianHG_DDR3_CONTROLLER_v15_top_tb

# Make Cyclone V Megafunctions and PLL available.
 vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L work -voptargs="+acc" BrianHG_DDR3_CONTROLLER_v15_top_tb


restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

#add  wave /BrianHG_DDR3_CONTROLLER_v15_top_tb/*

add wave -divider "Script File"
add wave -ascii       /BrianHG_DDR3_CONTROLLER_v15_top_tb/TB_COMMAND_SCRIPT_FILE
add wave -decimal     /BrianHG_DDR3_CONTROLLER_v15_top_tb/Script_LINE
add wave -ascii       /BrianHG_DDR3_CONTROLLER_v15_top_tb/Script_CMD
add wave -divider     "RST/CLK_in"
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/RST_IN
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/RST_OUT
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/PLL_LOCKED
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_CLK

add wave -divider     "COMM IO"
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_busy
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_ena
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_addr
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_write_ena
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_wdata
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_wmask
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_read_vector_in
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_read_ready
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_read_data
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/CMD_read_vector_out


add wave -divider     "COMM to DDR3_PHY"
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_CAL_PASS
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/DDR3_READY
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_BUSY_t
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_CMD_ENA_t
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_RDATA_VECT_IN
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_ADDR
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_WRITE_ENA 
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_WDATA
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_WMASK
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_RDATA_RDY_t
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_RDATA
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DUT_DDR3_CONTROLLER_v15_top/SEQ_RDATA_VECT_OUT

add wave -divider     "Write TAP port"
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/TAP_WRITE_ENA
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/TAP_ADDR
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/TAP_WDATA
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/TAP_WMASK

add wave -divider     "DDR3 SEQ RAM IO"
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_RESET_n
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_CKE
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_CMD
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_CK_p
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_CS_n
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_RAS_n
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_CAS_n
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_WE_n
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_ODT
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_A
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_BA
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_DQS_p 
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_DQ
add wave -hexadecimal /BrianHG_DDR3_CONTROLLER_v15_top_tb/DDR3_DM

do run_top_v15.do
