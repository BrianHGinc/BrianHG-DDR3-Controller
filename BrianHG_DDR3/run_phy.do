vlog -sv -work work {altera_gpio_lite.sv}
vlog -sv -work work {BrianHG_DDR3_GEN_tCK.sv}
vlog -sv -work work {BrianHG_DDR3_PLL.sv}
vlog -sv -work work {BrianHG_DDR3_FIFOs.sv}
vlog -sv -work work {BrianHG_DDR3_CMD_SEQUENCER.sv}
vlog -sv -work work {BrianHG_DDR3_IO_PORT_ALTERA.sv}
vlog -sv -work work {BrianHG_DDR3_PHY_SEQ.sv}
vlog -sv -work work {BrianHG_DDR3_PHY_SEQ_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 1390ns 1420ns
view signals


