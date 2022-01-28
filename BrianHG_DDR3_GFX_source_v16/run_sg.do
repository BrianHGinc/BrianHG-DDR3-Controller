vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Sync_Gen_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 500ns 1000ns
view signals
