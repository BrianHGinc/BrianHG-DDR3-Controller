transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_DDR3_PLL.sv}
vlog -sv -work work {BrianHG_DDR3_PLL_tb.sv}

# Make Cyclone IV E Megafunctions and PLL available.
#vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc"  BrianHG_DDR3_PLL_tb

# Make MAX 10 Megafunctions and PLL available.
#vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L fiftyfivenm_ver -L work -voptargs="+acc"    BrianHG_DDR3_PLL_tb

# Make Cyclone V Megafunctions and PLL available.
 vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L work -voptargs="+acc"  BrianHG_DDR3_PLL_tb

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

add  wave /BrianHG_DDR3_PLL_tb/*


do run_pll.do
