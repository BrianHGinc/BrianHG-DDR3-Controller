// *********************************************************************
//
// BrianHG_DDR3_DECA_test1 which test runs only the BrianHG_DDR3_PHY_SEQ DDR3 sequencer plus it's dependencies.
// Version 1.10, September 6, 2021.
// 400MHz build, Half rate controller interface speed.
//
// Written by Brian Guralnick.
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.

module BrianHG_DDR3_DECA_test1_top #(

parameter string     FPGA_VENDOR             = "Altera",         // (Only Altera for now) Use ALTERA, INTEL, LATTICE or XILINX.
parameter            FPGA_FAMILY             = "MAX 10",         // With Altera, use Cyclone III, Cyclone IV, Cyclone V, MAX 10,....
parameter bit        BHG_OPTIMIZE_SPEED      = 1,                // Use '1' for better FMAX performance, this will increase logic cell usage in the BrianHG_DDR3_PHY_SEQ module.
                                                                 // It is recommended that you use '1' when running slowest -8 Altera fabric FPGA above 300MHz or Altera -6 fabric above 350MHz.
parameter bit        BHG_EXTRA_SPEED         = 1,                // Use '1' for even better FMAX performance or when overclocking the core.  This will increase logic cell usage.

// ****************  System clock generation and operation.
parameter int        CLK_KHZ_IN              = 50000,            // PLL source input clock frequency in KHz.
parameter int        CLK_IN_MULT             = 32,               // Multiply factor to generate the DDR MTPS speed divided by 2.
parameter int        CLK_IN_DIV              = 4,                // Divide factor.  When CLK_KHZ_IN is 25000,50000,75000,100000,125000,150000, use 2,4,6,8,10,12.
parameter int        DDR_TRICK_MTPS_CAP      = 600,              // 0=off, Set a false PLL DDR data rate for the compiler to allow FPGA overclocking.  ***DO NOT USE.

parameter string     INTERFACE_SPEED         = "Half",           // Either "Full", "Half", or "Quarter" speed for the user interface clock.
                                                                 // This will effect the controller's interface CMD_CLK output port frequency.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_CK_MHZ             = ((CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV)/1000), // DDR3 CK clock speed in MHz.
parameter string     DDR3_SPEED_GRADE        = "-15E",           // Use 1066 / 187E, 1333 / -15E, 1600 / -125, 1866 / -107, or 2133 MHz / 093.
parameter int        DDR3_SIZE_GB            = 4,                // Use 0,1,2,4 or 8.  (0=512mb) Caution: Must be correct as ram chip size affects the tRFC REFRESH period.
parameter int        DDR3_WIDTH_DQ           = 16,               // Use 8 or 16.  The width of each DDR3 ram chip.

parameter int        DDR3_NUM_CHIPS          = 1,                // 1, 2, or 4 for the number of DDR3 RAM chips.
parameter int        DDR3_NUM_CK             = 1,                // Select the number of DDR3_CK & DDR3_CK# output pairs.
                                                                 // Optionally use 2 for 4 ram chips, if not 1 for each ram chip for best timing..
                                                                 // These are placed on a DDR DQ or DDR CK# IO output pins.

parameter int        DDR3_WIDTH_ADDR         = 15,               // Use for the number of bits to address each row.
parameter int        DDR3_WIDTH_BANK         = 3,                // Use for the number of bits to address each bank.
parameter int        DDR3_WIDTH_CAS          = 10,               // Use for the number of bits to address each column.

parameter int        DDR3_WIDTH_DM           = (DDR3_WIDTH_DQ*DDR3_NUM_CHIPS/8), // The width of the write data mask. (***Double when using multiple 4 bit DDR3 ram chips.)
parameter int        DDR3_WIDTH_DQS          = (DDR3_WIDTH_DQ*DDR3_NUM_CHIPS/8), // The number of DQS pairs.          (***Double when using multiple 4 bit DDR3 ram chips.)
parameter int        DDR3_RWDQ_BITS          = (DDR3_WIDTH_DQ*DDR3_NUM_CHIPS*8), // Must equal to total bus width across all DDR3 ram chips *8.

parameter int        DDR3_ODT_RTT            = 40,               // use 120, 60, 40, 30, 20 Ohm. or 0 to disable ODT.  (On Die Termination during write operation.)
parameter int        DDR3_RZQ                = 40,               // use 34 or 40 Ohm. (Output Drive Strength during read operation.)
parameter int        DDR3_TEMP               = 85,               // use 85,95,105. (Peak operating temperature in degrees Celsius.)

parameter int        DDR3_WDQ_PHASE          = 270,              // 270  Select the write and write DQS output clock phase relative to the DDR3_CK/CK#
parameter int        DDR3_RDQ_PHASE          = 0,                // 0    Select the read latch clock for the read data and DQS input relative to the DDR3_CK.

parameter bit [3:0]  DDR3_MAX_REF_QUEUE      = 8,                // Defines the size of the refresh queue where refreshes will have a higher priority than incoming SEQ_CMD_ENA_t command requests.
                                                                 // *** Do not go above 8, doing so may break the data sheet's maximum ACTIVATE-to-PRECHARGE command period as a
parameter bit [6:0]  IDLE_TIME_uSx10         = 2,                // Defines the time in 1/10uS until the command IDLE counter will allow low priority REFRESH cycles.
                                                                 // Use 10 for 1uS.  0=disable, 2 for a minimum effect, 127 maximum.

parameter bit        SKIP_PUP_TIMER          = 0,                // Skip timer during and after reset. ***ONLY use 1 for quick simulations.

parameter string     BANK_ROW_ORDER          = "ROW_BANK_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.

// ****************  DDR3 controller configuration parameter settings.
parameter int        PORT_VECTOR_SIZE        = 5,               // Set the width of the SEQ_RDATA_VECT_IN & SEQ_RDATA_VECT_OUT port, 1 through 64.
parameter int        PORT_ADDR_SIZE          = (DDR3_WIDTH_ADDR + DDR3_WIDTH_BANK + DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)),


parameter bit        USE_TOGGLE_CONTROLS     = 1                 // When 1, this setting makes the 'SEQ_CMD_ENA_t', 'SEQ_BUSY_t' and 'SEQ_RDATA_RDY_t' controls
                                                                 // activate each time their input/output toggles.  When the setting is 0, these controls
                                                                 // become active true/enable logic synchronous to the CMD_CLK.
)
(
// *****************************************************************************************************************
// ********** DECA Board's IOs.
// *****************************************************************************************************************

	//////////// CLOCK //////////
	input 		          		ADC_CLK_10,
	input 		          		MAX10_CLK1_50,
	input 		          		MAX10_CLK2_50,

	//////////// KEY //////////
	input 		     [1:0]     KEY,

	//////////// LED //////////
	output logic     [7:0]     LED,

	//////////// CapSense Button //////////
	inout 		          		CAP_SENSE_I2C_SCL,
	inout 		          		CAP_SENSE_I2C_SDA,

	//////////// Audio //////////
	inout 		          		AUDIO_BCLK,
	output		          		AUDIO_DIN_MFP1,
	input 		          		AUDIO_DOUT_MFP2,
	inout 		          		AUDIO_GPIO_MFP5,
	output		          		AUDIO_MCLK,
	input 		          		AUDIO_MISO_MFP4,
	inout 		          		AUDIO_RESET_n,
	output		          		AUDIO_SCL_SS_n,
	output		          		AUDIO_SCLK_MFP3,
	inout 		          		AUDIO_SDA_MOSI,
	output		          		AUDIO_SPI_SELECT,
	inout 		          		AUDIO_WCLK,

	//////////// Flash //////////
	inout 		     [3:0]		FLASH_DATA,
	output		          		FLASH_DCLK,
	output		          		FLASH_NCSO,
	output		          		FLASH_RESET_n,

	//////////// G-Sensor //////////
	output		          		G_SENSOR_CS_n,
	input 		          		G_SENSOR_INT1,
	input 		          		G_SENSOR_INT2,
	inout 		          		G_SENSOR_SCLK,
	inout 		          		G_SENSOR_SDI,
	inout 		          		G_SENSOR_SDO,

	//////////// HDMI-TX //////////
	inout 		          		HDMI_I2C_SCL,
	inout 		          		HDMI_I2C_SDA,
	inout 		     [3:0]		HDMI_I2S,
	inout 		          		HDMI_LRCLK,
	inout 		          		HDMI_MCLK,
	inout 		          		HDMI_SCLK,
	output		          		HDMI_TX_CLK,
	output		    [23:0]		HDMI_TX_D,
	output		          		HDMI_TX_DE,
	output		          		HDMI_TX_HS,
	input 		          		HDMI_TX_INT,
	output		          		HDMI_TX_VS,

	//////////// Light Sensor //////////
	output		          		LIGHT_I2C_SCL,
	inout 		          		LIGHT_I2C_SDA,
	inout 		          		LIGHT_INT,

	//////////// MIPI //////////
	output		          		MIPI_CORE_EN,
	output		          		MIPI_I2C_SCL,
	inout 		          		MIPI_I2C_SDA,
	input 		          		MIPI_LP_MC_n,
	input 		          		MIPI_LP_MC_p,
	input 		     [3:0]		MIPI_LP_MD_n,
	input 		     [3:0]		MIPI_LP_MD_p,
	input 		          		MIPI_MC_p,
	output		          		MIPI_MCLK,
	input 		     [3:0]		MIPI_MD_p,
	output		          		MIPI_RESET_n,
	output		          		MIPI_WP,

	//////////// Ethernet //////////
	input 		          		NET_COL,
	input 		          		NET_CRS,
	output		          		NET_MDC,
	inout 		          		NET_MDIO,
	output		          		NET_PCF_EN,
	output		          		NET_RESET_n,
	input 		          		NET_RX_CLK,
	input 		          		NET_RX_DV,
	input 		          		NET_RX_ER,
	input 		     [3:0]		NET_RXD,
	input 		          		NET_TX_CLK,
	output		          		NET_TX_EN,
	output		     [3:0]		NET_TXD,

	//////////// Power Monitor //////////
	input 		          		PMONITOR_ALERT,
	output		          		PMONITOR_I2C_SCL,
	inout 		          		PMONITOR_I2C_SDA,

	//////////// Humidity and Temperature Sensor //////////
	input 		          		RH_TEMP_DRDY_n,
	output		          		RH_TEMP_I2C_SCL,
	inout 		          		RH_TEMP_I2C_SDA,

	//////////// MicroSD Card //////////
	output		          		SD_CLK,
	inout 		          		SD_CMD,
	output		          		SD_CMD_DIR,
	output		          		SD_D0_DIR,
	inout 		          		SD_D123_DIR,
	inout 		     [3:0]		SD_DAT,
	input 		          		SD_FB_CLK,
	output		          		SD_SEL,

	//////////// SW //////////
	input 		     [1:0]		SW,

	//////////// Board Temperature Sensor //////////
	output		          		TEMP_CS_n,
	output		          		TEMP_SC,
	inout 		          		TEMP_SIO,

	//////////// USB //////////
	input 		          		USB_CLKIN,
	output		          		USB_CS,
	inout 		     [7:0]		USB_DATA,
	input 		          		USB_DIR,
	input 		          		USB_FAULT_n,
	input 		          		USB_NXT,
	output		          		USB_RESET_n,
	output		          		USB_STP,

	//////////// BBB Conector //////////
	input 		          		BBB_PWR_BUT,
	input 		          		BBB_SYS_RESET_n,
	inout 		    [43:0]		GPIO0_D,
	inout 		    [22:0]		GPIO1_D,


// *****************************************************************************************************************
// ********** Results from DDR3_PHY_SEQ, IO Names happen to match DECA Board's IO assignment pin names.
// *****************************************************************************************************************
output                       DDR3_RESET_n,  // DDR3 RESET# input pin.
output [DDR3_NUM_CK-1:0]     DDR3_CK_p,     // DDR3_CK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
output [DDR3_NUM_CK-1:0]     DDR3_CK_n,     // DDR3_CK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
                                            // ************************** port to generate the negative DDR3_CK# output.
                                            // ************************** Generate an additional DDR_CK_p pair for every DDR3 ram chip. 

output                       DDR3_CKE,      // DDR3 CKE

output                       DDR3_CS_n,     // DDR3 CS#
output                       DDR3_RAS_n,    // DDR3 RAS#
output                       DDR3_CAS_n,    // DDR3 CAS#
output                       DDR3_WE_n,     // DDR3 WE#
output                       DDR3_ODT,      // DDR3 ODT

output [DDR3_WIDTH_ADDR-1:0] DDR3_A,        // DDR3 multiplexed address input bus
output [DDR3_WIDTH_BANK-1:0] DDR3_BA,       // DDR3 Bank select

output [DDR3_WIDTH_DM-1:0]   DDR3_DM,       // DDR3 Write data mask. DDR3_DM[0] drives write DQ[7:0], DDR3_DM[1] drives write DQ[15:8]...
inout  [DDR3_WIDTH_DQ-1:0]   DDR3_DQ,       // DDR3 DQ data IO bus.
inout  [DDR3_WIDTH_DQS-1:0]  DDR3_DQS_p,     // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
inout  [DDR3_WIDTH_DQS-1:0]  DDR3_DQS_n     // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
                                            // ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
                                            // ****************** port to generate the negative DDR3_DQS# IO.
);


// *****************************************************
// ********* BrianHG_DDR3_PHY_SEQ logic / wires.
// *****************************************************
logic CLK_IN;
logic RESET,PLL_LOCKED,DDR3_CLK,DDR3_CLK_50,DDR3_CLK_25,DDR3_CLK_DQS,DDR3_CLK_RDQ,DDR3_CLK_WDQ,CMD_CLK;

logic                         SEQ_CMD_ENA_t;
logic                         SEQ_WRITE_ENA;
logic [PORT_ADDR_SIZE-1:0]    SEQ_ADDR;
logic [DDR3_RWDQ_BITS-1:0]    SEQ_WDATA,WDATA;
logic [DDR3_RWDQ_BITS/8-1:0]  SEQ_WMASK,WMASK;
logic [PORT_VECTOR_SIZE-1:0]  SEQ_RDATA_VECT_IN;  // Embed multiple read request returns into the SEQ_RDATA_VECT_IN.
logic                         SEQ_refresh_hold;

logic                         SEQ_BUSY_t;
logic                         SEQ_RDATA_RDY_t;
logic [DDR3_RWDQ_BITS-1:0]    SEQ_RDATA;
logic [PORT_VECTOR_SIZE-1:0]  SEQ_RDATA_VECT_OUT;
logic [3:0]                   SEQ_refresh_queue;

logic                         SEQ_CAL_PASS;
logic                         DDR3_READY;

// *****************************************************************
// ********* Assign BrianHG_DDR3_PHY_SEQ logic / wires to DECA IOs.
// *****************************************************************
localparam   RS232_MEM_ADR_SIZE = 24 ; // Maximum = 20, IE 15 seconds to transfer the entire 1 mgeabyte by RS232...

logic                          RS232_RST_OUT  ;
logic                          RS232_RXD      ;
logic                          RS232_TXD      ;
logic                          RS232_TXD_LED  ;
logic                          RS232_RXD_LED  ;
logic                          DB232_rreq              ;
logic                          DB232_rrdy,DB232_rrdy_t ; // The DB232_rrdy_t is for monitoring the toggle output.
logic                          DB232_wreq        ;
logic [RS232_MEM_ADR_SIZE-1:0] DB232_addr        ;
logic [7:0]                    DB232_wdat        ;
logic [7:0]                    DB232_rdat        ;
logic [7:0]                    DB232_tx0         ;
logic [7:0]                    DB232_tx1         ;
logic [7:0]                    DB232_tx2         ;
logic [7:0]                    DB232_tx3         ;
logic [7:0]                    DB232_rx0         ;
logic [7:0]                    DB232_rx1         ;
logic [7:0]                    DB232_rx2         ;
logic [7:0]                    DB232_rx3         ;

logic        DB232_rreq_t ;
logic        DB232_req ;

logic        phase_step,phase_updn;
logic        phase_done;
logic [7:0]  RDCAL_data ;
logic [15:0] cnt_read = 0 ;



assign CLK_IN = MAX10_CLK1_50 ;     // Assign the reference 50MHz pll.

assign GPIO0_D[1] = RS232_TXD ;     // Assign the RS232 debugger TXD output pin.
assign GPIO0_D[3] = 1'bz       ;    // Make this IO into a tri-state input.
assign RS232_RXD  = GPIO0_D[3] ;    // Assign the RS232 debugger RXD input pin.


assign SEQ_refresh_hold = 0 ;
logic        SEQ_RDATA_RDY_t_dly;


// ****************************************************************************************************************************
// Using the lower bits of the write address, convert a write byte to the 128bit bus with the correct byte mask write enable.
// ****************************************************************************************************************************
        DDR3_CMD_ENCODE_BYTE #(

         .addr_size        ( 5                    ),    // sets the width of the address input.
         .input_width      ( 8                    ),    // Sets the width of the input data.
         .output_width     ( DDR3_RWDQ_BITS       )     // Sets the width of the output data.

) DDR3_CMD_ENCODE_BYTE_inst (
         .addr             ( DB232_addr[4:0]      ),    // Take the byte write address and generate a positioned write data & mask output. 
         .data_in          ( DB232_wdat           ),
         .mask_in          ( 1'b1                 ),
         .data_out         ( WDATA                ),
         .mask_out         ( WMASK                ) );

// ****************************************************************************************************************************
// Take the 128bit read data and return the selected single byte using the lower address bits stored in the returned read vector
// ****************************************************************************************************************************
        DDR3_CMD_DECODE_BYTE #(

         .addr_size        ( 5                    ),    // sets the width of the address input.
         .input_width      ( DDR3_RWDQ_BITS       ),    // Sets the width of the input data.
         .output_width     ( 8                    )     // Sets the width of the output data.

) DDR3_CMD_DECODE_BYTE_inst (
         .addr             ( SEQ_RDATA_VECT_OUT[4:0] ),   // Use the read data vector as a pointer to which byte was selected in the read.
         .data_in          ( SEQ_RDATA               ),   // Take in the 128bit read data.
         .data_out         ( DB232_rdat              ) ); // Output the selected byte.

always_ff @(posedge DDR3_CLK_50) begin 

end

// ****************************************************************************************************************************
// Pass the RS232 debugger commands to and from the DDR3_PHY_SEQ module.
// ****************************************************************************************************************************
always_ff @(posedge DDR3_CLK_25) begin 
if (RESET) begin
        SEQ_CMD_ENA_t                  <= 0 ;
        SEQ_WRITE_ENA                  <= 0 ;
        SEQ_ADDR [3:0]                 <= 0 ;
        SEQ_ADDR [19:4]                <= 0 ;
        SEQ_ADDR [PORT_ADDR_SIZE-1:20] <= 0 ;
        SEQ_RDATA_VECT_IN              <= {PORT_VECTOR_SIZE{1'b0}} ;
        SEQ_RDATA_RDY_t_dly            <= SEQ_RDATA_RDY_t;
        cnt_read                       <= 0 ;
        DB232_req                      <= 0 ;

    end else begin


    if (DB232_rreq || DB232_wreq) begin                                    // Send out a RS232 request.
        SEQ_WRITE_ENA                                  <= DB232_wreq ;
        SEQ_ADDR [3:0]                                 <= 4'b0000 ; 
        SEQ_ADDR [RS232_MEM_ADR_SIZE-1:4]              <= DB232_addr[RS232_MEM_ADR_SIZE-1:4] ;
        SEQ_RDATA_VECT_IN                              <= DB232_addr[4:0] ; // When performing a read request, set which byte in the 128 bit result should be sent to the RS232 Debugger.
        SEQ_WDATA                                      <= WDATA;
        SEQ_WMASK                                      <= WMASK;

        DB232_req                                      <= !DB232_req ;
        end

        if (SEQ_BUSY_t==SEQ_CMD_ENA_t) SEQ_CMD_ENA_t   <= DB232_req  ; // When not busy, pass the DDR3 requests delayed by 1 clock improving meta-stability when crossing clock domains.

        SEQ_RDATA_RDY_t_dly  <= SEQ_RDATA_RDY_t ;
        DB232_rrdy_t         <= SEQ_RDATA_RDY_t_dly  ;
        DB232_rrdy           <= SEQ_RDATA_RDY_t_dly != DB232_rrdy_t ; // Delayed after 2 clocks, if a SEQ_RDATA_RDY_t came in, tell the RS232 debugger that the read byte came in.

        if (DB232_rrdy) cnt_read <= cnt_read + 1'b1 ;                // increment the read counter.

end // !reset

DB232_tx3[7:0] <= RDCAL_data[7:0] ; // Send out read calibration data.
DB232_tx1[7:0] <= cnt_read[7:0] ;
DB232_tx2[7:0] <= cnt_read[15:8]   ;

end // @CLK_IN


// Show LEDs and send them to one of the RD232 debugger display ports.
always_ff @(posedge DDR3_CLK_25) begin         // Make sure the signals driving LED's aren't route optimized for the LED's IO pin location.
    DB232_tx0[0]   <= RS232_TXD_LED ;     // RS232 Debugger TXD status LED
    DB232_tx0[1]   <= 1'b0 ;              // Turn off LED.
    DB232_tx0[2]   <= PLL_LOCKED   ;
    DB232_tx0[3]   <= SEQ_CAL_PASS ;              // Turn off LED.
    DB232_tx0[4]   <= DDR3_READY ;
    DB232_tx0[5]   <= 1'b0 ;
    DB232_tx0[6]   <= 1'b0 ;              // Turn off LED.
    DB232_tx0[7]   <= RS232_RXD_LED ;     // RS232 Debugger RXD status LED

    LED            <= 8'hff ^ RDCAL_data ^  8'((RS232_TXD_LED || RS232_RXD_LED)<<7); // Pass the calibration data to the LEDs.
end


// *********************************************************************************************
// This module generates the master reference clocks for the entire memory system.
// *********************************************************************************************
BrianHG_DDR3_PLL  #(.FPGA_VENDOR    (FPGA_VENDOR),    .INTERFACE_SPEED (INTERFACE_SPEED),  .DDR_TRICK_MTPS_CAP       (DDR_TRICK_MTPS_CAP),
                    .CLK_KHZ_IN     (CLK_KHZ_IN),     .CLK_IN_MULT     (CLK_IN_MULT),      .CLK_IN_DIV               (CLK_IN_DIV),
                    .DDR3_WDQ_PHASE (DDR3_WDQ_PHASE), .DDR3_RDQ_PHASE  (DDR3_RDQ_PHASE),   .FPGA_FAMILY              (FPGA_FAMILY)
) BHG_DDR3_PLL     (.RST_IN         (RS232_RST_OUT),  .RST_OUT         (RESET),            .CLK_IN    (CLK_IN),      .DDR3_CLK   (DDR3_CLK),
                    .DDR3_CLK_WDQ   (DDR3_CLK_WDQ),   .DDR3_CLK_RDQ    (DDR3_CLK_RDQ),     .CMD_CLK   (CMD_CLK),     .PLL_LOCKED (PLL_LOCKED),
                    .DDR3_CLK_50    (DDR3_CLK_50),    .DDR3_CLK_25     (DDR3_CLK_25),

                    .phase_step     ( phase_step ),   .phase_updn      ( phase_updn ),
                    .phase_sclk     ( DDR3_CLK_25 ),  .phase_done      ( phase_done ) );

// ******************************************************************************************************
// This module receives the commands from the multi-port ram controller and sequences the DDR3 IO pins.
// ******************************************************************************************************
BrianHG_DDR3_PHY_SEQ    #(.FPGA_VENDOR         (FPGA_VENDOR),         .FPGA_FAMILY         (FPGA_FAMILY),        .INTERFACE_SPEED    (INTERFACE_SPEED),
                          .BHG_OPTIMIZE_SPEED  (BHG_OPTIMIZE_SPEED),  .BHG_EXTRA_SPEED     (BHG_EXTRA_SPEED),
                          .CLK_KHZ_IN          (CLK_KHZ_IN),          .CLK_IN_MULT         (CLK_IN_MULT),        .CLK_IN_DIV         (CLK_IN_DIV),
                          
                          .DDR3_CK_MHZ         (DDR3_CK_MHZ),         .DDR3_SPEED_GRADE    (DDR3_SPEED_GRADE),   .DDR3_SIZE_GB       (DDR3_SIZE_GB),
                          .DDR3_WIDTH_DQ       (DDR3_WIDTH_DQ),       .DDR3_NUM_CHIPS      (DDR3_NUM_CHIPS),     .DDR3_NUM_CK        (DDR3_NUM_CK),
                          .DDR3_WIDTH_ADDR     (DDR3_WIDTH_ADDR),     .DDR3_WIDTH_BANK     (DDR3_WIDTH_BANK),    .DDR3_WIDTH_CAS     (DDR3_WIDTH_CAS),
                          .DDR3_WIDTH_DM       (DDR3_WIDTH_DM),       .DDR3_WIDTH_DQS      (DDR3_WIDTH_DQS),     .DDR3_ODT_RTT       (DDR3_ODT_RTT),
                          .DDR3_RZQ            (DDR3_RZQ),            .DDR3_TEMP           (DDR3_TEMP),          .DDR3_WDQ_PHASE     (DDR3_WDQ_PHASE), 
                          .DDR3_RDQ_PHASE      (DDR3_RDQ_PHASE),      .DDR3_MAX_REF_QUEUE  (DDR3_MAX_REF_QUEUE), .IDLE_TIME_uSx10    (IDLE_TIME_uSx10),
                          .SKIP_PUP_TIMER      (SKIP_PUP_TIMER),      .BANK_ROW_ORDER      (BANK_ROW_ORDER),

                          .PORT_VECTOR_SIZE    (PORT_VECTOR_SIZE),    .PORT_ADDR_SIZE      (PORT_ADDR_SIZE),     .USE_TOGGLE_CONTROLS (USE_TOGGLE_CONTROLS)

) BHG_DDR3_PHY_SEQ (      // *** DDR3_PHY_SEQ Clocks & Reset ***
                          .RST_IN        (RESET || DB232_rx3[7]),    .DDR_CLK       (DDR3_CLK),   .DDR_CLK_WDQ  (DDR3_CLK_WDQ), .DDR_CLK_RDQ (DDR3_CLK_RDQ),
                          .CLK_IN              (CLK_IN),                                          .DDR_CLK_50   (DDR3_CLK_50),  .DDR_CLK_25  (DDR3_CLK_25),

                          // *** DDR3 Ram Chip IO Pins ***           
                          .DDR3_RESET_n        (DDR3_RESET_n),       .DDR3_CK_p     (DDR3_CK_p),  .DDR3_CKE    (DDR3_CKE),     .DDR3_CS_n   (DDR3_CS_n),
                          .DDR3_RAS_n          (DDR3_RAS_n),         .DDR3_CAS_n    (DDR3_CAS_n), .DDR3_WE_n   (DDR3_WE_n),    .DDR3_ODT    (DDR3_ODT),
                          .DDR3_A              (DDR3_A),             .DDR3_BA       (DDR3_BA),    .DDR3_DM     (DDR3_DM),      .DDR3_DQ     (DDR3_DQ),
                          .DDR3_DQS_p          (DDR3_DQS_p),         .DDR3_DQS_n    (DDR3_DQS_n), .DDR3_CK_n   (DDR3_CK_n),

                          // *** Command port input ***              
                          .SEQ_CMD_ENA_t       (SEQ_CMD_ENA_t),      .SEQ_ADDR      (SEQ_ADDR),
                          .SEQ_WRITE_ENA       (SEQ_WRITE_ENA),      .SEQ_WDATA     (SEQ_WDATA),          .SEQ_WMASK          (SEQ_WMASK),
                          .SEQ_RDATA_VECT_IN   (SEQ_RDATA_VECT_IN),                                       .SEQ_refresh_hold   (SEQ_refresh_hold),

                          // *** Command port results ***                                                 
                          .SEQ_BUSY_t          (SEQ_BUSY_t),         .SEQ_RDATA_RDY_t (SEQ_RDATA_RDY_t),  .SEQ_RDATA          (SEQ_RDATA),
                          .SEQ_RDATA_VECT_OUT  (SEQ_RDATA_VECT_OUT),                                      .SEQ_refresh_queue  (SEQ_refresh_queue),

                          // *** Diagnostic flags ***                                                 
                          .SEQ_CAL_PASS        (SEQ_CAL_PASS),       .DDR3_READY    (DDR3_READY),

                          // *** PLL tuning controls ***
                          .phase_done          (phase_done),         .phase_step    (phase_step),         .phase_updn         (phase_updn),
                          .RDCAL_data          (RDCAL_data) );

// ***********************************************************************************************


// ******************************************************************************************************
// This module is a test RS232 bridge which uses BrianHG's RS232_Debugger.exe Windows app.
// ******************************************************************************************************
rs232_debugger #(.CLK_IN_HZ(CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV*250), .BAUD_RATE(921600), .ADDR_SIZE(RS232_MEM_ADR_SIZE), .READ_REQ_1CLK(1)
) rs232_debug (
.clk         ( DDR3_CLK_25   ),    // System clock.  Recommend at least 20MHz for the 921600 baud rate.
.cmd_rst     ( RS232_RST_OUT ),    // When sent by the PC RS232_Debugger utility this outputs a high signal for 8 clock cycles.
.rxd         ( RS232_RXD     ),    // Connect this to the RS232 RXD input pin.
.txd         ( RS232_TXD     ),    // Connect this to the RS232 TXD output pin.
.LED_txd     ( RS232_TXD_LED ),    // Optionally wire this to a LED it will go high whenever the RS232 TXD is active.
.LED_rxd     ( RS232_RXD_LED ),    // Optionally wire this to a LED it will go high whenever the RS232 RXD is active.
.host_rd_req ( DB232_rreq    ),    // This output will pulse high for 1 clock when a read request is taking place.
.host_rd_rdy ( DB232_rrdy    ),    // This input should be set high once the 'host_rdata[7:0]' input contains valid data.
.host_wr_ena ( DB232_wreq    ),    // This output will pulse high for 1 clock when a write request is taking place.
.host_addr   ( DB232_addr    ),    // This output contains the requested read and write address.
.host_wdata  ( DB232_wdat    ),    // This output contains the source RS232 8bit data to be written.
.host_rdata  ( DB232_rdat    ),    // This input receives the 8 bit ram data to be sent to the RS232.
.in0         ( DB232_tx0     ),
.in1         ( DB232_tx1     ),
.in2         ( DB232_tx2     ),
.in3         ( DB232_tx3     ),
.out0        ( DB232_rx0     ),
.out1        ( DB232_rx1     ),
.out2        ( DB232_rx2     ),
.out3        ( DB232_rx3     )  );



// ******************************************************************************************************
// This clears up the 'output port has no driver' warnings.
// ******************************************************************************************************

assign HDMI_TX_D        = 0 ;
assign NET_TXD          = 0 ;
assign AUDIO_DIN_MFP1   = 0 ;
assign AUDIO_MCLK       = 0 ;
assign AUDIO_SCL_SS_n   = 0 ;
assign AUDIO_SCLK_MFP3  = 0 ;
assign AUDIO_SPI_SELECT = 0 ;
assign FLASH_DCLK       = 0 ;
assign FLASH_NCSO       = 0 ;
assign FLASH_RESET_n    = 0 ;
assign G_SENSOR_CS_n    = 1 ;
assign HDMI_TX_CLK      = 0 ;
assign HDMI_TX_DE       = 0 ;
assign HDMI_TX_HS       = 0 ;
assign HDMI_TX_VS       = 0 ;
assign LIGHT_I2C_SCL    = 0 ;
assign MIPI_CORE_EN     = 0 ;
assign MIPI_I2C_SCL     = 0 ;
assign MIPI_MCLK        = 0 ;
assign MIPI_RESET_n     = 0 ;
assign MIPI_WP          = 0 ;
assign NET_MDC          = 0 ;
assign NET_PCF_EN       = 0 ;
assign NET_RESET_n      = 0 ;
assign NET_TX_EN        = 0 ;
assign PMONITOR_I2C_SCL = 0 ;
assign RH_TEMP_I2C_SCL  = 0 ;
assign SD_CLK           = 0 ;
assign SD_CMD_DIR       = 0 ;
assign SD_D0_DIR        = 0 ;
assign SD_SEL           = 0 ;
assign TEMP_CS_n        = 1 ;
assign TEMP_SC          = 0 ;
assign USB_CS           = 0 ;
assign USB_RESET_n      = 0 ;
assign USB_STP          = 0 ;


endmodule



//*************************************************************************************************************************************
// This module takes in the write data and mask of smaller or equal input PORT_W_DATA_WIDTH,
// then outputs the data to the correct position within the data bus with the PORT_CACHE_BITS width.
//*************************************************************************************************************************************
module DDR3_CMD_ENCODE_BYTE #(
//*************************************************************************************************************************************
parameter  int addr_size    = 20,           // sets the width of the address input.
parameter  int input_width  = 8,            // Sets the width of the input data and byte mask data (mask size=/8).
parameter  int output_width = 128           // Sets the width of the output data and mask data (mask size=/8)
//*************************************************************************************************************************************
)(
input logic  [addr_size-1:0]      addr,
input logic  [output_width-1:0]   data_in,  // Remember, even though only the 'input_width' LSBs are functional, the port still has the full width.
input logic  [output_width/8-1:0] mask_in,  // Upper unused bits will be ignored.

output logic [output_width-1:0]   data_out,
output logic [output_width/8-1:0] mask_out
);

localparam   index_width  = $clog2(output_width/8) ;    // Describes the number of address bits required to point to each word.

logic       [index_width-1:0]     index_ptr ;          // The index pointer from the address.

always_comb begin

    // Retrieve the index position.
    // Filter out the least significant address bits when the input width is greater than 8 bits.
    index_ptr  = (index_width)'( (addr[index_width-1:0] ^ {index_width{1'b1}}) & ( {index_width{1'b1}} ^ (input_width/8-1) ) ) ; 

    // Select the sole mask bits used when writing the data into the appropriate 8 bit segments of data_out.
    mask_out   = (output_width/8)'(mask_in[input_width/8-1:0]<<index_ptr) ;

    // Copy the smaller input width data across the larger output data bus.
    for (int i=0 ; i < output_width ; i+=input_width) data_out[i +: input_width] = data_in[0 +: input_width] ;

end // always comb

endmodule

//*************************************************************************************************************************************
// This module takes in the full PORT_CACHE_BITS width read data and outputs a smaller or equal data at the size of PORT_R_DATA_WIDTH.
//*************************************************************************************************************************************
module DDR3_CMD_DECODE_BYTE #(
//*************************************************************************************************************************************
parameter  int addr_size    = 20,           // sets the width of the address input.
parameter  int input_width  = 128,          // Sets the width of the input data.
parameter  int output_width = 8             // Sets the width of the output data.
//*************************************************************************************************************************************
)(
input logic  [addr_size-1:0]      addr,
input logic  [input_width-1:0]    data_in,

output logic [input_width-1:0]    data_out  // **** REMEMBER, the output bus is still the same full PORT_CACHE_BITS, it's just that the unused bits
                                            //                will be set to 0.
);

localparam   index_width  = $clog2(input_width/8) ;    // Describes the number of address bits required to point to each word.

logic       [index_width-1:0]     index_ptr ;          // The index pointer from the address.

always_comb begin

    // Retrieve the index position.
    // Filter out the least significant address bits when the output width is greater than 8 bits.
    index_ptr  = (index_width)'( (addr[index_width-1:0] ^ {index_width{1'b1}}) & ( {index_width{1'b1}} ^ (output_width/8-1) ) ) ; 

    // Select the data out word based on the index position
    data_out   = (data_in >> (index_ptr * 8)) & {output_width{1'b1}} ;

end // always comb
endmodule

