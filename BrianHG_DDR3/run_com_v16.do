vlog -sv -work work {BrianHG_DDR3_FIFOs.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER_v16.sv}
vlog -sv -work work {BrianHG_DDR3_COMMANDER_v16_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 50ns 200ns
view signals
