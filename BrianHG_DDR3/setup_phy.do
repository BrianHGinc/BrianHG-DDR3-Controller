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
vlog -sv -work work {BrianHG_DDR3_PHY_SEQ_tb.sv}


# Make Cyclone IV E Megafunctions and PLL available.
#vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc"  BrianHG_DDR3_PHY_SEQ_tb

# Make MAX 10 Megafunctions and PLL available.
#vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L work -voptargs="+acc" BrianHG_DDR3_PHY_SEQ_tb

# Make Cyclone V Megafunctions and PLL available.
 vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L work -voptargs="+acc" BrianHG_DDR3_PHY_SEQ_tb



restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

#add  wave /BrianHG_DDR3_PHY_SEQ_tb/*

add wave -divider "Script File"
add wave -ascii       /BrianHG_DDR3_PHY_SEQ_tb/TB_COMMAND_SCRIPT_FILE
add wave -decimal     /BrianHG_DDR3_PHY_SEQ_tb/Script_LINE
add wave -ascii       /BrianHG_DDR3_PHY_SEQ_tb/Script_CMD
add wave -divider     "RST/CLK_in"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/RST_IN
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/CLK_IN
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/RESET
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/PLL_LOCKED
add wave -divider     "DDR3 SEQ CMD Input"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_BUSY_t
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/CMD_CLK
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_CMD_ENA_t
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_WRITE_ENA
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_ADDR
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_WMASK
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_WDATA
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_RDATA_VECT_IN
#add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/CMD_SEQ/BHG_FIFO/stat
add wave -divider     "DDR3 SEQ CMD Output"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_RDATA_RDY_t
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_RDATA
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_RDATA_VECT_OUT
add wave -divider     "DDR3 SEQ CMD Refresh"
#add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_refresh_hold
#add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_refresh_queue
add wave -divider     "DDR3 SEQ CMD Diagnostics"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/SEQ_CAL_PASS
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_READY
add wave -divider     "*** DUT_PHY_SEQ ***"
add wave -unsigned    /BrianHG_DDR3_PHY_SEQ_tb/WDT_COUNTER 
add wave -divider     "DDR3 CLK"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_CLK
add wave -divider     "DDR3 SEQ RAM IO"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_RESET_n
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_CKE
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_CMD
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_CK_p
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_CS_n
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_RAS_n
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_CAS_n
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_WE_n
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_ODT
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_A
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_BA
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_DQS_p 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_DQ
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DDR3_DM
add wave -divider     "DDR3_PHY Data Path"

add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/genblk6/BHG_DDR3_IO_PORT_ALTERA/RDQS_ph
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/genblk6/BHG_DDR3_IO_PORT_ALTERA/RDQS_pl
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/genblk6/BHG_DDR3_IO_PORT_ALTERA/RDQ_h
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/genblk6/BHG_DDR3_IO_PORT_ALTERA/RDQ_l
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/genblk6/BHG_DDR3_IO_PORT_ALTERA/RDATA_toggle
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/genblk6/BHG_DDR3_IO_PORT_ALTERA/RDATA
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/genblk6/BHG_DDR3_IO_PORT_ALTERA/RDATA_store

add wave -divider     "CMD Timer Out"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RX_BANK 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RX_CMD 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RX_RDY 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RX_ACK 

add wave -divider     "CMD Timer In"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/TX_BANKs
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/TX_TXBs
add wave -unsigned    /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/GTIMER 
add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/tcGTIMER 
add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/tcREFRESH 
add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/tcPRECHARGE 
add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/tcACTIVATE
add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/tcREAD 
add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/tcWRITE 

add wave -divider     "Init Calibration"
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/CMD_TX_ENAi 
add wave -unsigned    /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/init_pc 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/phase_done 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/phase_step 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/phase_updn
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RDCAL_clr 
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/READ_CAL_PAT_s
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RDCAL
add wave -binary      /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RDCAL_data
add wave -hexadecimal /BrianHG_DDR3_PHY_SEQ_tb/DUT_PHY_SEQ/RDCAL_pos


do run_phy.do
