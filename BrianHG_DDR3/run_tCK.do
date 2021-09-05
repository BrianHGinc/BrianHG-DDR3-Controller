vlog -sv -work work {BrianHG_DDR3_GEN_tCK.sv}

restart -force
run 20 ns

wave cursor active
wave refresh
wave zoom range 0ns 100ns
view signals
