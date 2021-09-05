vlog -sv -work work {BrianHG_DDR3_FIFOs.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 50ns 200ns
view signals
