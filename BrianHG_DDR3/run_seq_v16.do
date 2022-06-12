vlog -sv -work work {BrianHG_DDR3_PLL.sv}
vlog -sv -work work {BrianHG_DDR3_CMD_SEQUENCER_v16.sv}
vlog -sv -work work {BrianHG_DDR3_CMD_SEQUENCER_v16_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 50ns 110ns
view signals


