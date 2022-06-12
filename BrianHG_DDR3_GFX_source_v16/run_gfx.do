vlog -sv -work work {ellipse_generator.sv}
vlog -sv -work work {BrianHG_draw_test_patterns.sv}
vlog -sv -work work {BrianHG_draw_test_patterns_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 500ns 1000ns
view signals
