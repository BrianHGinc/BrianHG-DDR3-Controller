transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_DDR3_GEN_tCK.sv}
vsim -default_radix unsigned -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc"  BrianHG_DDR3_GEN_tCK

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

add  wave /BrianHG_DDR3_GEN_tCK/*

add  wave -binary {/BrianHG_DDR3_GEN_tCK/MR[0]}
add  wave -binary {/BrianHG_DDR3_GEN_tCK/MR[1]}
add  wave -binary {/BrianHG_DDR3_GEN_tCK/MR[2]}
add  wave -binary {/BrianHG_DDR3_GEN_tCK/MR[3]}

do run_tCK.do
