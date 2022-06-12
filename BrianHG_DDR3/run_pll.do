vlog -sv -work work {BrianHG_DDR3_PLL.sv}
vlog -sv -work work {BrianHG_DDR3_PLL_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 780ns 880ns
view signals
