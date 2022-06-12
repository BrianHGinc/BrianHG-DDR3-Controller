vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Video_Line_Buffer.sv}
vlog -sv -work work {BrianHG_GFX_Video_Line_Buffer_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 8750ns 9115ns
view signals
