#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "10.0 MHz" [get_ports ADC_CLK_10]
create_clock -period "50.0 MHz" [get_ports MAX10_CLK1_50]
create_clock -period "50.0 MHz" [get_ports MAX10_CLK2_50]

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
set tSU 1.500
#Specify the required tH
set tH  2.000

#Specify the required tCO
#Use -7.5 for -6 Altera FPGA
#Use -8.0 for -7 Altera FPGA
#Use -8.5 for -8 Altera FPGA
set tCO  -7.500
#Specify the required tCOm
set tCOm -4.000


##**************************************************************
## Set Input Delay
##**************************************************************

set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}]             -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}]             -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}] -clock_fall -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}] -clock_fall -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]

set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {GPIO0_D[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {GPIO0_D[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {KEY[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {KEY[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {SW[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {SW[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {HDMI_I2C_SDA}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {HDMI_I2C_SDA}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {HDMI_TX_INT}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {HDMI_TX_INT}]

##**************************************************************
## Set Output Delay
##**************************************************************

set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -max $tCO              [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -max $tCO  -clock_fall [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -min $tCOm             [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -min $tCOm -clock_fall [get_ports {DDR3*}] -add_delay

set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tCO  [get_ports {GPIO0_D[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tCOm [get_ports {GPIO0_D[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tCO  [get_ports {LED[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tCOm [get_ports {LED[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tCO  [get_ports {HDMI*}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tCOm [get_ports {HDMI*}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

# Optional: Separate the reset and low frequency inputs on the CLK_IN 50Mhz from the core.
set_false_path -from [get_clocks {MAX10_CLK1_50}] -to [get_clocks {*DDR3_PLL5*clk[4]}]
set_false_path -from [get_clocks {*DDR3_PLL5*clk[4]}] -to [get_clocks {MAX10_CLK1_50}]


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
