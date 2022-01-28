vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Window_DDR3_Reader.sv}
vlog -sv -work work {BrianHG_GFX_Window_DDR3_Reader_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 1050ns 1250ns
view signals
