// *********************************************************************
//
// BrianHG_DDR3_PHY_SEQ_tb DDR3 sequencer.
// Version 1.00, August 22, 2021.
//
//
// Written by Brian Guralnick.
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//*** DDR3 Verilog model from Micron Required for this test-bench.
//*** The required DDR3 SDRAM Verilog Model V1.74 available at:
//*** https://media-www.micron.com/-/media/client/global/documents/products/sim-model/dram/ddr3/ddr3-sdram-verilog-model.zip?rev=925a8a05204e4b5c9c1364302de60126
//*** From the 'DDR3 SDRAM Verilog Model.zip', only these 2 files are required in the main simulation test-bench source folder:
//*** ddr3.v
//*** 4096Mb_ddr3_parameters.vh
//************************************************************************************************************************************************************
// Tell Micron's DDR3 Verilog model which ram chip we expect to have connected to the test bench.
//************************************************************************************************************************************************************
`define den4096Mb
`define sg093
`define x16
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.

module BrianHG_DDR3_PHY_SEQ_tb #(

parameter string     FPGA_VENDOR             = "Altera",         // (Only Altera for now) Use ALTERA, INTEL, LATTICE or XILINX.
parameter string     FPGA_FAMILY             = "Cyclone IV E",   //"MAX 10",         // With Altera, use Cyclone III, Cyclone IV, Cyclone V, MAX 10,....
parameter bit        BHG_OPTIMIZE_SPEED      = 1,                // Use '1' for better FMAX performance, this will increase logic cell usage in the BrianHG_DDR3_PHY_SEQ module.
                                                                 // It is recommended that you use '1' when running slowest -8 Altera fabric FPGA above 300MHz or Altera -6 fabric above 350MHz.
parameter bit        BHG_EXTRA_SPEED         = 1,                // Use '1' for even better FMAX performance or when overclocking the core.  This will increase logic cell usage.

// ****************  System clock generation and operation.
parameter int        CLK_KHZ_IN              = 50000,            // PLL source input clock frequency in KHz.
parameter int        CLK_IN_MULT             = 32,               // Multiply factor to generate the DDR MTPS speed divided by 2.
parameter int        CLK_IN_DIV              = 4,                // Divide factor.  When CLK_KHZ_IN is 25000,50000,75000,100000,125000,150000, use 2,4,6,8,10,12.
parameter int        DDR_TRICK_MTPS_CAP      = 0,                // 0=off, Set a false PLL DDR data rate for the compiler to allow FPGA overclocking.  ***DO NOT USE.
                                                                
parameter string     INTERFACE_SPEED         = "Half",           // Either "Full", "Half", or "Quarter" speed for the user interface clock.
                                                                 // This will effect the controller's interface CMD_CLK output port frequency.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_CK_MHZ             = ((CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV)/1000), // DDR3 CK clock speed in MHz.
parameter string     DDR3_SPEED_GRADE        = "-093",           // Use 1066 / 187E, 1333 / -15E, 1600 / -125, 1866 / -107, or 2133 MHz / 093.
parameter int        DDR3_SIZE_GB            = 4,                // Use 0,1,2,4 or 8.  (0=512mb) Caution: Must be correct as ram chip size affects the tRFC REFRESH period.
parameter int        DDR3_WIDTH_DQ           = 16,               // Use 8 or 16.  The width of each DDR3 ram chip.

parameter int        DDR3_NUM_CHIPS          = 1,                // 1, 2, or 4 for the number of DDR3 RAM chips.
parameter int        DDR3_NUM_CK             = (DDR3_NUM_CHIPS), // Select the number of DDR3_CLK & DDR3_CLK# output pairs.  Add 1 for every DDR3 Ram chip.
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

parameter int        DDR3_WDQ_PHASE          = 270,              // 270/90  Select the write and write DQS output clock phase relative to the DDR3_CLK/CK#.
parameter int        DDR3_RDQ_PHASE          = 0,                // 0       Select the read latch clock for the read data and DQS input relative to the DDR3_CLK.  (This is auto-tuned during powerup).

parameter bit [4:0]  DDR3_MAX_REF_QUEUE      = 8,                // Defines the size of the refresh queue where refreshes will have a higher priority than incoming SEQ_CMD_ENA_t command requests.
                                                                 // *** Do not go above 8, doing so may break the data sheet's maximum ACTIVATE-to-PRECHARGE command period as a
parameter bit [6:0]  IDLE_TIME_uSx10         = 2,                // Defines the time in 1/10uS until the command IDLE counter will allow low priority REFRESH cycles.
                                                                 // Use 10 for 1uS.  0=disable, 1 for a minimum effect, 127 maximum.

parameter bit        SKIP_PUP_TIMER          = 1,//0,                // Skip timer during and after reset. ***ONLY use 1 for quick simulations.

parameter string     BANK_ROW_ORDER          = "ROW_BANK_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.

// ****************  DDR3 controller configuration parameter settings.
parameter int        PORT_VECTOR_SIZE        = 16,               // Set the width of the SEQ_RDATA_VECT_IN & SEQ_RDATA_VECT_OUT port, 1 through 64.
parameter int        PORT_ADDR_SIZE          = (DDR3_WIDTH_ADDR + DDR3_WIDTH_BANK + DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1))
)
(
RST_IN,    // Reset input 
RESET,
PLL_LOCKED,
CLK_IN,
DDR3_CLK,
DDR3_CLK_DQS,
DDR3_CLK_RDQ,
DDR3_CLK_50,
DDR3_CLK_25,
CMD_CLK,

// ********** Commands to DDR3_PHY_SEQ.

SEQ_CMD_ENA_t,
SEQ_WRITE_ENA,
SEQ_ADDR,
SEQ_WDATA,
SEQ_WMASK,
SEQ_RDATA_VECT_IN,
SEQ_refresh_hold,

SEQ_BUSY_t,
SEQ_RDATA_RDY_t,
SEQ_RDATA,
SEQ_RDATA_VECT_OUT,
SEQ_refresh_queue,

// ********** Diagnostic flags.
SEQ_CAL_PASS,
DDR3_READY,

// ********** Results from DDR3_PHY_SEQ.
DDR3_RESET_n,  // DDR3 RESET# input pin.
DDR3_CK_p,     // DDR3_CLK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
DDR3_CK_n,     // DDR3_CLK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
               // ************************** port to generate the negative DDR3_CLK# output.
               // ************************** Generate an additional DDR_CK_p pair for every DDR3 ram chip. 

DDR3_CKE,      // DDR3 CKE

DDR3_CS_n,     // DDR3 CS#
DDR3_RAS_n,    // DDR3 RAS#
DDR3_CAS_n,    // DDR3 CAS#
DDR3_WE_n,     // DDR3 WE#
DDR3_ODT,      // DDR3 ODT

DDR3_A,        // DDR3 multiplexed address input bus
DDR3_BA,       // DDR3 Bank select
DDR3_DM,       // DDR3 Write data mask. DDR3_DM[0] drives write DQ[7:0], DDR3_DM[1] drives write DQ[15:8]...
DDR3_DQ,       // DDR3 DQ data IO bus.
DDR3_DQS_p,    // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
DDR3_DQS_n,    // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
               // ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
               // ****************** port to generate the negative DDR3_DQS# IO.
               
DDR3_CMD       // Display the name of the DDR3 command.
);

string     TB_COMMAND_SCRIPT_FILE = "DDR3_PHY_script.txt";	 // Choose one of the following strings...
string                Script_CMD  = "*** POWER_UP ***" ; // Message line in waveform
logic [12:0]          Script_LINE = 0  ; // Message line in waveform

localparam string  DDR_CMD_NAME [0:15] = '{"MRS","REF","PRE","ACT","WRI","REA","ZQC","nop",
                                           "xop","xop","xop","xop","xop","xop","xop","NOP"};


input  logic RST_IN,CLK_IN;
output logic RESET,PLL_LOCKED,DDR3_CLK,DDR3_CLK_DQS,DDR3_CLK_50,DDR3_CLK_25,DDR3_CLK_RDQ,CMD_CLK;

input  logic                                        SEQ_CMD_ENA_t;
input  logic                                        SEQ_WRITE_ENA;
input  logic [PORT_ADDR_SIZE-1:0]                   SEQ_ADDR;
input  logic [DDR3_RWDQ_BITS-1:0]                   SEQ_WDATA;
input  logic [DDR3_RWDQ_BITS/8-1:0]                 SEQ_WMASK;
input  logic [PORT_VECTOR_SIZE-1:0]                 SEQ_RDATA_VECT_IN;  // Embed multiple read request returns into the SEQ_RDATA_VECT_IN.
input  logic                                        SEQ_refresh_hold;

output logic                                        SEQ_BUSY_t;
output logic                                        SEQ_RDATA_RDY_t;
output logic [DDR3_RWDQ_BITS-1:0]                   SEQ_RDATA;
output logic [PORT_VECTOR_SIZE-1:0]                 SEQ_RDATA_VECT_OUT;
output logic [4:0]                                  SEQ_refresh_queue;

output logic                                        SEQ_CAL_PASS;
output logic                                        DDR3_READY;
output string                                       DDR3_CMD = "xxx";

// ********** Results from DDR3_PHY_SEQ.
inout  logic                       DDR3_RESET_n;  // DDR3 RESET# input pin.
inout  logic [DDR3_NUM_CK-1:0]     DDR3_CK_p;     // DDR3_CLK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
inout  logic [DDR3_NUM_CK-1:0]     DDR3_CK_n;     // DDR3_CLK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
                                                  // ************************** port to generate the negative DDR3_CLK# output.
                                                  // ************************** Generate an additional DDR_CK_p pair for every DDR3 ram chip. 

inout  logic                       DDR3_CKE;      // DDR3 CKE

inout  logic                       DDR3_CS_n;     // DDR3 CS#
inout  logic                       DDR3_RAS_n;    // DDR3 RAS#
inout  logic                       DDR3_CAS_n;    // DDR3 CAS#
inout  logic                       DDR3_WE_n;     // DDR3 WE#
inout  logic                       DDR3_ODT;      // DDR3 ODT

inout  logic [DDR3_WIDTH_ADDR-1:0] DDR3_A;        // DDR3 multiplexed address input bus
inout  logic [DDR3_WIDTH_BANK-1:0] DDR3_BA;       // DDR3 Bank select
inout  logic [DDR3_WIDTH_DM-1  :0] DDR3_DM;       // DDR3 Write data mask. DDR3_DM[0] drives write DQ[7:0], DDR3_DM[1] drives write DQ[15:8]...
                                                  // ***on x8 devices, the TDQS is not used and should be connected to GND or an IO set to GND.

inout  logic [DDR3_WIDTH_DQ-1:0]   DDR3_DQ;       // DDR3 DQ data IO bus.
inout  logic [DDR3_WIDTH_DQS-1:0]  DDR3_DQS_p;    // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
inout  logic [DDR3_WIDTH_DQS-1:0]  DDR3_DQS_n;    // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
                                                  // ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
                                                  // ****************** port to generate the negative DDR3_DQS# IO.


localparam      period   = 500000000/CLK_KHZ_IN ;
localparam      STOP_uS  = 1000000 ;
localparam      endtime  = STOP_uS * 10;

logic        phase_done,phase_step,phase_updn; // PLL tuning controls.
logic  [7:0] RDCAL_data ;                      // A record of the PLL tuning results.

// *********************************************************************************************
// This module generates the master reference clocks for the entire memory system.
// *********************************************************************************************
BrianHG_DDR3_PLL  #(.FPGA_VENDOR    (FPGA_VENDOR),    .INTERFACE_SPEED (INTERFACE_SPEED),  .DDR_TRICK_MTPS_CAP       (DDR_TRICK_MTPS_CAP),
                    .FPGA_FAMILY    (FPGA_FAMILY),
                    .CLK_KHZ_IN     (CLK_KHZ_IN),     .CLK_IN_MULT     (CLK_IN_MULT),      .CLK_IN_DIV               (CLK_IN_DIV),
                    .DDR3_WDQ_PHASE (DDR3_WDQ_PHASE), .DDR3_RDQ_PHASE  (DDR3_RDQ_PHASE)
) DUT_DDR3_PLL (    .RST_IN         (RST_IN),         .RST_OUT         (RESET),            .CLK_IN    (CLK_IN),      .DDR3_CLK    (DDR3_CLK),
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

                          .PORT_VECTOR_SIZE    (PORT_VECTOR_SIZE),    .PORT_ADDR_SIZE      (PORT_ADDR_SIZE)

) DUT_PHY_SEQ (           // *** DDR3_PHY_SEQ Clocks & Reset ***
                          .RST_IN              (RESET),              .DDR_CLK       (DDR3_CLK),   .DDR_CLK_WDQ (DDR3_CLK_WDQ), .DDR_CLK_RDQ (DDR3_CLK_RDQ),
                          .CLK_IN              (CLK_IN),             .CMD_CLK       (CMD_CLK),    .DDR_CLK_50  (DDR3_CLK_50),  .DDR_CLK_25  (DDR3_CLK_25),

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


//************************************************************************************************************************************************************
//*** DDR3 Verilog model from Micron Required for this test-bench.
//************************************************************************************************************************************************************
`include "ddr3.v"
//************************************************************************************************************************************************************
//*** DDR3 Verilog model from Micron Required for this test-bench.
//*** The required DDR3 SDRAM Verilog Model V1.74 available at:
//*** https://media-www.micron.com/-/media/client/global/documents/products/sim-model/dram/ddr3/ddr3-sdram-verilog-model.zip?rev=925a8a05204e4b5c9c1364302de60126
//*** From the 'DDR3 SDRAM Verilog Model.zip', only these 2 files are required in the main simulation test-bench source folder:
//*** ddr3.v
//*** 4096Mb_ddr3_parameters.vh
//************************************************************************************************************************************************************
    // component instantiation
    ddr3 sdramddr3_0 (
        .rst_n      ( DDR3_RESET_n ),
        .ck         ( DDR3_CK_p[0] ),
        .ck_n       ( DDR3_CK_n[0] ),
        .cke        ( DDR3_CKE     ),
        .cs_n       ( DDR3_CS_n    ),
        .ras_n      ( DDR3_RAS_n   ),
        .cas_n      ( DDR3_CAS_n   ),
        .we_n       ( DDR3_WE_n    ),
        .dm_tdqs    ( DDR3_DM      ),
        .ba         ( DDR3_BA      ),
        .addr       ( DDR3_A       ),
        .dq         ( DDR3_DQ      ),
        .dqs        ( DDR3_DQS_p   ),
        .dqs_n      ( DDR3_DQS_n   ),
        .tdqs_n     (              ),
        .odt        ( DDR3_ODT     )
    );
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************

logic       [7:0] WDT_COUNTER;                                                       // Wait for 15 clocks or inactivity before forcing a simulation stop.
logic             WAIT_IDLE        = 0;                                              // When high, insert a idle wait before every command.
localparam int    WDT_RESET_TIME   = 255;                                            // Set the WDT timeout clock cycles.
localparam int    SYS_IDLE_TIME    = WDT_RESET_TIME-64;                              // Consider system idle after 12 clocks of inactivity.
localparam real   DDR3_CLK_MHZ_REAL = CLK_KHZ_IN * CLK_IN_MULT / CLK_IN_DIV / 1000 ;  // Generate the DDR3 CK clock frequency.
localparam real   DDR3_CK_pERIOD   = 1000 / DDR3_CLK_MHZ_REAL ;                       // Generate the DDR3 CK period in nanoseconds.

initial begin

WDT_COUNTER       = WDT_RESET_TIME  ; // Set the initial inactivity timer to maximum so that the code later-on wont immediately stop the simulation.
SEQ_CMD_ENA_t     = 0 ;
SEQ_WRITE_ENA     = 0 ;
SEQ_ADDR          = 0 ;
SEQ_WDATA         = 0 ;
SEQ_WMASK         = 0 ;
SEQ_RDATA_VECT_IN = 0 ;
SEQ_refresh_hold  = 0 ;


RST_IN = 1'b1 ; // Reset input
CLK_IN = 1'b0 ;
#(50000);
RST_IN = 1'b0 ; // Release reset at 50ns.

while (!DDR3_READY) @(negedge CMD_CLK);
execute_ascii_file(TB_COMMAND_SCRIPT_FILE);

end

always_comb                DDR3_CMD    =  DDR_CMD_NAME[{DDR3_CS_n,DDR3_RAS_n,DDR3_CAS_n,DDR3_WE_n}] ;          // Display the command name in the output waveform
always #period                  CLK_IN = !CLK_IN;                                                              // create source clock oscillator
always @(posedge CLK_IN)   WDT_COUNTER = ((SEQ_BUSY_t!=SEQ_CMD_ENA_t) || !DDR3_READY) ? WDT_RESET_TIME : (WDT_COUNTER-1'b1) ;   // Setup a simulation inactivity watchdog countdown timer.
always @(posedge CLK_IN) if (WDT_COUNTER==0) begin
                                             Script_CMD  = "*** WDT_STOP ***" ;
                                             $stop;                                           // Automatically stop the simulation if the inactivity timer reaches 0.
                                             end




// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// task execute_ascii_file(<"source ASCII file name">);
// 
// Opens the ASCII file and scans for the '@' symbol.
// After each '@' symbol, a string is read as a command function.
// Each function then goes through a 'case(command_in)' which then executes the appropriate function.
//
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************

task execute_ascii_file(string source_file_name);
 begin
    integer fin_pointer,fout_pointer,fin_running,r;
    string  command_in,message_string,destination_file_name,bmp_file_name;

    byte    unsigned    char        ;
    byte    unsigned    draw_color  ;
    integer unsigned    line_number ;

    line_number  = 1;
    fout_pointer = 0;

    fin_pointer= $fopen(source_file_name, "r");
    if (fin_pointer==0)
    begin
       $display("Could not open file '%s' for reading",source_file_name);
       $stop;     
    end

while (fin_pointer!=0 && ! $feof(fin_pointer)) begin // Continue processing until the end of the source file.

  char = 0;
  while (char != "@" && ! $feof(fin_pointer) && fin_pointer!=0 ) begin // scan for the @ character until end of source file.
  char = $fgetc(fin_pointer);
  if (char==0 || fin_pointer==0 )  $stop;                               // something went wrong
  if (char==10) line_number = line_number + 1;       // increment the internal source file line counter.
  end


if (! $feof(fin_pointer) ) begin  // if not end of source file retrieve command string

  r = $fscanf(fin_pointer,"%s",command_in); // Read in the command string after the @ character.
  if (fout_pointer!=0) $fwrite(fout_pointer,"Line#%d, ",13'(line_number)); // :pg the executed command line number.

  case (command_in) // select command string.

  "CMD"        : begin
                 tx_DDR3_cmd(fin_pointer, fout_pointer, line_number);
                 end

  "RESET"      : begin
                 Script_LINE = line_number;
                 Script_CMD  = command_in;
                 send_rst();                                          // pulses the reset signal for 1 clock.
                 if (fout_pointer!=0) $fwrite(fout_pointer,"Sending a reset to the BrianHG_DDR3_PHY_SEQ module.\n");
                 end

  "WAIT_SEQ_READY" : begin
                 Script_LINE = line_number;
                 Script_CMD  = command_in;
                 wait_rdy();                                          // pulses the reset signal for 1 clock.
                 if (fout_pointer!=0) $fwrite(fout_pointer,"Waiting for the BrianHG_DDR3_PHY_SEQ module to become ready.\n");
                 end

  "LOG_FILE"   : begin                                                  // begin logging the results.
                   if (fout_pointer==0) begin
                   r = $fscanf(fin_pointer,"%s",destination_file_name); // Read file name for the log file
                     fout_pointer= $fopen(destination_file_name,"w");   // Open that file name for writing.
                     if (fout_pointer==0) begin
                          $display("\nCould not open log file '%s' for writing.\n",destination_file_name);
                          $stop;
                     end else begin
                     $fwrite(fout_pointer,"Log file requested in '%s' at line#%d.\n\n",source_file_name,13'(line_number));
                     end
                   end else begin
                     $sformat(message_string,"\n*** Error in command script at line #%d.\n    You cannot open a LOG_FILE since the current log file '%s' is already running.\n    You must first '@END_LOG_FILE' if you wish to open a new log file.\n",13'(line_number),destination_file_name);
                     $display("%s",message_string);
                     $fclose(fin_pointer);
                     if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                     if (fout_pointer!=0) $fclose(fout_pointer);
                     $stop;
                   end
                 end

  "END_LOG_FILE" : if (fout_pointer!=0)begin                           // Stop logging the commands and close the current log file.
                       $sformat(message_string,"@%s command at line number %d.\n",command_in,13'(line_number));
                       $display("%s",message_string);
                       $fwrite(fout_pointer,"%s",message_string);
                       $fclose(fout_pointer);
                       fout_pointer = 0;
                   end

  "STOP"       :  begin // force a temporary stop.
                  $sformat(message_string,"@%s command at line number %d.\nType 'Run -All' to continue.",command_in,13'(line_number));
                  $display("%s",message_string);
                  if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                  $stop;
                  end

  "END"        :  begin // force seek to the end of the source file.

                 wait_idle();

                  $sformat(message_string,"@%s command at line number %d.\n",command_in,13'(line_number));
                  $display("%s",message_string);
                  $fclose(fin_pointer);
                  if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                  fin_pointer = 0;
                  end

  default      :  begin // Unknown command
                  $sformat(message_string,"Source ASCII file '%s' has an unknown command '@%s' at line number %d.\nProcessign stopped due to error.\n",source_file_name,command_in,13'(line_number));
                  $display("%s",message_string);
                  if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                  $stop;
                  end
  endcase

end // if !end of source file

end// while not eof


// Finished reading source file.  Close files and stop.
while ((WDT_COUNTER >= SYS_IDLE_TIME )) @(negedge CMD_CLK); // wait for busy to clear
Script_CMD  = "*** END of script file. ***" ;

$sformat(message_string,"\nEnd of command source ASCII file '%s'.\n%d lines processed.\n",source_file_name,13'(line_number));
$display("%s",message_string);
$fclose(fin_pointer);
if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
if (fout_pointer!=0) $fclose(fout_pointer);
fin_pointer  = 0;
fout_pointer = 0;
end
endtask





// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// task send_rst();
// 
// sends a reset.
//
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
task send_rst();
begin
@(negedge CLK_IN); 
RST_IN = 1;
@(negedge CLK_IN); 
@(negedge CLK_IN); 
@(negedge CLK_IN); 
@(negedge CLK_IN); 
RST_IN = 0;
@(negedge CLK_IN);

@(posedge CMD_CLK); // Re-sync to CMD_CLK.
@(negedge CMD_CLK);
end
endtask

// ***********************************************************************************************************
// task wait_rdy();
// Wait for DUT_GEOFF input buffer ready.
// ***********************************************************************************************************
task wait_rdy();
begin
  //while (SEQ_BUSY_t) @(negedge CMD_CLK); // wait for busy to clear
  while (SEQ_BUSY_t!=SEQ_CMD_ENA_t) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
end
endtask

// ***********************************************************************************************************
// task txcmd(integer dest,string msg,integer ln);
// ***********************************************************************************************************
task txcmd(integer dest,string msg,integer ln);
begin
    wait_rdy();

    Script_LINE = ln;
    Script_CMD  = msg;
    if (dest!=0) $fwrite(dest,"%s",msg);

    SEQ_CMD_ENA_t = !SEQ_CMD_ENA_t; // toggle style interface.
    //SEQ_CMD_ENA_t = 1;
    @(negedge CMD_CLK);
    //SEQ_CMD_ENA_t = 0;
end
endtask

// ***********************************************************************************************************
// task wait_idle();
// ***********************************************************************************************************
task wait_idle();
begin
Script_CMD = "Waiting for last command to finish.";
  while (WDT_COUNTER > SYS_IDLE_TIME) @(negedge CMD_CLK); // wait for busy to clear
  WDT_COUNTER          = WDT_RESET_TIME ; // Reset the watchdog timer.
end
endtask


// ***********************************************************************************************************
// task tx_DDR3_cmd(integer src, integer dest, integer ln);
// tx the DDR3 command.
// ***********************************************************************************************************
task tx_DDR3_cmd(integer src, integer dest, integer ln);
begin

   integer unsigned                         r,faddr,fvect;
   string                                   cmd,msg;
   logic unsigned  [PORT_ADDR_SIZE-1:0]     addr;
   logic unsigned  [DDR3_RWDQ_BITS-1:0]     WDATA;
   logic unsigned  [DDR3_RWDQ_BITS/8-1:0]   WMASK;
   logic unsigned  [PORT_VECTOR_SIZE-1:0]   VECT;  // Embed multiple read request returns into the SEQ_RDATA_VECT_IN.


  while (WAIT_IDLE && (WDT_COUNTER > SYS_IDLE_TIME)) @(negedge CMD_CLK); // wait for busy to clear

   r = $fscanf(src,"%s",cmd);                      // retrieve which shape to draw

case (cmd)

   "READ","read" : begin // READ
                wait_rdy();
 
                r = $fscanf(src,"%h%h",faddr,fvect); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Read  address (%h) to vector (%h).",faddr,fvect); // Create the log and waveform message.

                addr = (PORT_ADDR_SIZE)'(faddr) ;

                SEQ_WRITE_ENA       = 0;
                SEQ_ADDR            = addr;
                SEQ_WDATA           = 0;
                SEQ_WMASK           = 0;
                SEQ_RDATA_VECT_IN   = (PORT_VECTOR_SIZE)'(fvect);

                txcmd(dest,msg,ln); 
                end

   "WRITE","write" : begin // READ

                wait_rdy();
 
                r = $fscanf(src,"%h%b%h",faddr,SEQ_WMASK,SEQ_WDATA); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Write address (%h) with data (%h).",faddr,SEQ_WDATA); // Create the log and waveform message.

                addr = (PORT_ADDR_SIZE)'(faddr) ;

                SEQ_WRITE_ENA       = 1;
                SEQ_ADDR            = addr;
                SEQ_RDATA_VECT_IN   = 0;

                if (dest!=0)    begin
                                $sformat(msg,"%s\n                                      MASK -> (",msg);
                                for (int n=(DDR3_RWDQ_BITS/8-1) ; n>=0 ; n--) $sformat(msg,"%s%b%b",msg,SEQ_WMASK[n],SEQ_WMASK[n]);
                                $sformat(msg,"%s).",msg);
                                end
                txcmd(dest,msg,ln); 
                end

   "DELAY","delay" : begin // Delay in microseconds.
 
                wait_rdy();
                r = $fscanf(src,"%d",faddr); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Delaying for %d nanoseconds.",13'(faddr)); // Create the log and waveform message.
                Script_LINE = ln;
                Script_CMD  = msg;
                if (dest!=0) $fwrite(dest,"%s",msg);
                for (int n=0 ; n<=((faddr*1)/DDR3_CK_pERIOD); n++) begin
                                                        @(negedge DDR3_CLK);
                                                        WDT_COUNTER = WDT_RESET_TIME ;
                                                        end
                                                        @(negedge CMD_CLK);
                end

   default : begin
                wait_rdy();
                 while ((WDT_COUNTER > SYS_IDLE_TIME)) @(negedge CMD_CLK); // wait for busy to clear
                 
                  $sformat(msg,"Unknown CMD '%s' at line number %d.\nProcessign stopped due to error.\n",cmd,13'(ln));
                  $display("%s",msg);
                  while ((WDT_COUNTER >= 2 )) @(negedge CMD_CLK); // wait for busy to clear
                  if (dest!=0) $fwrite(dest,"%s",msg);
                  @(negedge CMD_CLK);
                  $stop;

                end


endcase

if (dest!=0) $fwrite(dest,"\n"); // Add a carriage return.

end
endtask

endmodule
