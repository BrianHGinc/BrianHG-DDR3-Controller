#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "50.0 MHz" [get_ports CLK_IN_50]


#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty

#Specify the required tSU
set tSU 0.750
#Specify the required tH
set tH  1.250

#Specify the required tCO
#Use -7.5 for -6 Altera FPGA
#Use -8.0 for -7 Altera FPGA
#Use -8.5 for -8 Altera FPGA
set tCO  -7.500

#Specify the required tCOm
#Use -3.7 for -6 Cyclone V Altera FPGA
#Use -3.6 for -7 Cyclone V Altera FPGA
#Use -3.5 for -8 Cyclone V Altera FPGA
set tCOm -3.700


##**************************************************************
## Set Input Delay
##**************************************************************

set_input_delay  -clock [get_clocks {*DDR3_PLL5*counter[2]*}]             -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*counter[2]*}]             -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*counter[2]*}] -clock_fall -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*counter[2]*}] -clock_fall -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]

set_input_delay  -clock [get_clocks {*DDR3_PLL5*counter[4]*}] -max $tSU  [get_ports {GPIO0_D[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*counter[4]*}] -min $tH   [get_ports {GPIO0_D[*]}]


##**************************************************************
## Set Output Delay
##**************************************************************

set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[0]*}] -max $tCO              [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[0]*}] -max $tCO  -clock_fall [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[0]*}] -min $tCOm             [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[0]*}] -min $tCOm -clock_fall [get_ports {DDR3*}] -add_delay

set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[4]*}] -max $tCO  [get_ports {GPIO0_D[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[4]*}] -min $tCOm [get_ports {GPIO0_D[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[4]*}] -max $tCO  [get_ports {LED[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*counter[4]*}] -min $tCOm [get_ports {LED[*]}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

# Separate the CLK_IN paths from the core.
set_false_path -from [get_clocks {CLK_IN_50}] -to [get_clocks {*DDR3_PLL5*counter[4]*}]
set_false_path -from [get_clocks {*DDR3_PLL5*counter[4]*}] -to [get_clocks {CLK_IN_50}]

#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************
