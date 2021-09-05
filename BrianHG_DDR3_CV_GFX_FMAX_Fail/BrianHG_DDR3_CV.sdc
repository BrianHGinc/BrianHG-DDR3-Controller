#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "50.0 MHz" [get_ports CLK_IN_50]
create_clock -period "50.0 MHz" [get_ports CLK_IN_50_vid]

create_clock -period "1.0 MHz"  [get_nets {I2C_HDMI_Config:u_I2C_HDMI_Config|mI2C_CTRL_CLK}]


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
set tSU 0.500
#Specify the required tH
set tH  1.000

#Specify the required tCO
#Use -7.5 for -6 Altera FPGA
#Use -8.0 for -7 Altera FPGA
#Use -8.5 for -8 Altera FPGA
set tCO  -7.500

#Specify the required tCOm
#Use -3.5 for Cyclone V Altera FPGA
set tCOm -3.500


##**************************************************************
## Set Input Delay
##**************************************************************

set_input_delay  -clock [get_clocks {*DDR3_PLL5*[2].output_counter|divclk}]             -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[2].output_counter|divclk}]             -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[2].output_counter|divclk}] -clock_fall -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[2].output_counter|divclk}] -clock_fall -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]

set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -max $tSU  [get_ports {GPIO0_D[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -min $tH   [get_ports {GPIO0_D[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -max $tSU  [get_ports {KEY[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -min $tH   [get_ports {KEY[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -max $tSU  [get_ports {SW[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -min $tH   [get_ports {SW[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -max $tSU  [get_ports {HDMI_I2C_SDA}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -min $tH   [get_ports {HDMI_I2C_SDA}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -max $tSU  [get_ports {HDMI_TX_INT}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -min $tH   [get_ports {HDMI_TX_INT}]


##**************************************************************
## Set Output Delay
##**************************************************************

set_output_delay -clock [get_clocks {*DDR3_PLL5*[0].output_counter|divclk}] -max $tCO              [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*[0].output_counter|divclk}] -max $tCO  -clock_fall [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*[0].output_counter|divclk}] -min $tCOm             [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*[0].output_counter|divclk}] -min $tCOm -clock_fall [get_ports {DDR3*}] -add_delay

set_output_delay -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -max $tCO  [get_ports {GPIO0_D[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -min $tCOm [get_ports {GPIO0_D[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -max $tCO  [get_ports {LED[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -min $tCOm [get_ports {LED[*]}]

set_output_delay -clock CLK_IN_50_vid -max $tCO  [get_ports {HDMI*}]
set_output_delay -clock CLK_IN_50_vid -min $tCOm [get_ports {HDMI*}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

# Separate VGA output video pixel clock from the main system clock and CLK_In 50Mhz clock.
set_false_path -from [get_clocks {u_vpg|u_pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -to [get_clocks {CLK_IN_50_vid}]
set_false_path -from [get_clocks {u_vpg|u_pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -to [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}]
set_false_path -from [get_clocks {u_vpg|u_pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -to [get_clocks {*DDR3_PLL5*[3].output_counter|divclk}]
set_false_path -from [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -to [get_clocks {u_vpg|u_pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path -from [get_clocks {*DDR3_PLL5*[3].output_counter|divclk}] -to [get_clocks {u_vpg|u_pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]

# Separate the fake generated I2C clock output from the CLK_IN 50 MHz source.
set_false_path -from [get_clocks {CLK_IN_50}] -to [get_clocks {u_I2C_HDMI_Config|mI2C_CTRL_CLK|q}]
set_false_path -from [get_clocks {u_I2C_HDMI_Config|mI2C_CTRL_CLK|q}] -to [get_clocks {CLK_IN_50_vid}]

# Optional: Separate the reset and low frequency inputs on the CLK_IN 50Mhz from the core.
set_false_path -from [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}] -to [get_clocks {CLK_IN_50}]
set_false_path -from [get_clocks {CLK_IN_50}] -to [get_clocks {*DDR3_PLL5*[4].output_counter|divclk}]

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
