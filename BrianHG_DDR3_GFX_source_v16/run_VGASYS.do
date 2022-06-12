vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Video_Line_Buffer.sv}
vlog -sv -work work {BrianHG_GFX_Window_DDR3_Reader.sv}
vlog -sv -work work {BrianHG_GFX_Layer_mixer.sv}
vlog -sv -work work {BrianHG_GFX_VGA_Window_System.sv}
vlog -sv -work work {BrianHG_GFX_VGA_Window_System_tb.sv}

restart -force
run -all

wave cursor active
wave refresh
wave zoom range 17470ns 17610ns
view signals
