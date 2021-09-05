// *********************************************************************
//
// BrianHG_DDR3_CONTROLLER_top_tb.sv multi-platform, multi-DMA-port (16 read and 16 write ports max) complete
// test bench of entire memory system using Micron's DDR3 Verilog model to simulate actual connected memory.
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

module BrianHG_DDR3_CONTROLLER_top_tb #(

parameter string     FPGA_VENDOR             = "Altera",         // (Only Altera for now) Use ALTERA, INTEL, LATTICE or XILINX.
parameter string     FPGA_FAMILY             = "Cyclone IV E",   // With Altera, use Cyclone III, Cyclone IV, Cyclone V, MAX 10,....
parameter bit        BHG_OPTIMIZE_SPEED      = 0,                // Use '1' for better FMAX performance, this will increase logic cell usage in the BrianHG_DDR3_PHY_SEQ module.
                                                                 // It is recommended that you use '1' when running slowest -8 Altera fabric FPGA above 300MHz or Altera -6 fabric above 350MHz.
parameter bit        BHG_EXTRA_SPEED         = 0,                // Use '1' for even better FMAX performance or when overclocking the core.  This will increase logic cell usage.

// ****************  System clock generation and operation.
parameter int        CLK_KHZ_IN              = 50000,            // PLL source input clock frequency in KHz.
parameter int        CLK_IN_MULT             = 32,               // Multiply factor to generate the DDR MTPS speed divided by 2.
parameter int        CLK_IN_DIV              = 4,                // Divide factor.  When CLK_KHZ_IN is 25000,50000,75000,100000,125000,150000, use 2,4,6,8,10,12.
parameter int        DDR_TRICK_MTPS_CAP      = 0,                // 0=off, Set a false PLL DDR data rate for the compiler to allow FPGA overclocking.  ***DO NOT USE.
                                                                
parameter string     INTERFACE_SPEED         = "Half",           // Either "Full", "Half", or "Quarter" speed for the user interface clock.
                                                                 // This will effect the controller's interface CMD_CLK output port frequency.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_CK_MHZ             = ((CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV)/1000), // DDR3 CK clock speed in MHz.
parameter string     DDR3_SPEED_GRADE        = "-15E",           // Use 1066 / 187E, 1333 / -15E, 1600 / -125, 1866 / -107, or 2133 MHz / 093.
parameter int        DDR3_SIZE_GB            = 4,                // Use 0,1,2,4 or 8.  (0=512mb) Caution: Must be correct as ram chip size affects the tRFC REFRESH period.
parameter int        DDR3_WIDTH_DQ           = 16,               // Use 8 or 16.  The width of each DDR3 ram chip.

parameter int        DDR3_NUM_CHIPS          = 1,                // 1, 2, or 4 for the number of DDR3 RAM chips.
parameter int        DDR3_NUM_CK             = 1,                // Select the number of DDR3_CLK & DDR3_CLK# output pairs.
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

parameter int        DDR3_WDQ_PHASE          = 270,              // 270, Select the write and write DQS output clock phase relative to the DDR3_CLK/CK#
parameter int        DDR3_RDQ_PHASE          = 0,                // 0,   Select the read latch clock for the read data and DQS input relative to the DDR3_CLK.

parameter bit [4:0]  DDR3_MAX_REF_QUEUE      = 8,                // Defines the size of the refresh queue where refreshes will have a higher priority than incoming SEQ_CMD_ENA command requests.
                                                                 // *** Do not go above 8, doing so may break the data sheet's maximum ACTIVATE-to-PRECHARGE command period as a
parameter bit [6:0]  IDLE_TIME_uSx10         = 2,                // Defines the time in 1/10uS until the command IDLE counter will allow low priority REFRESH cycles.
                                                                 // Use 10 for 1uS.  0=disable, 1 for a minimum effect, 127 maximum.

parameter bit        SKIP_PUP_TIMER          = 1,                // Skip timer during and after reset. ***ONLY use 1 for quick simulations.

parameter string     BANK_ROW_ORDER          = "ROW_BANK_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.

parameter int        PORT_ADDR_SIZE          = (DDR3_WIDTH_ADDR + DDR3_WIDTH_BANK + DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)),

// ************************************************************************************************************************************
// ****************  BrianHG_DDR3_COMMANDER configuration parameter settings.
parameter int        PORT_R_TOTAL            = 1,                // Set the total number of DDR3 controller read ports, 1 to 16 max.
parameter int        PORT_W_TOTAL            = 1,                // Set the total number of DDR3 controller write ports, 1 to 16 max.
parameter int        PORT_VECTOR_SIZE        = 8,                // Sets the width of each port's VECTOR input and output.

// ************************************************************************************************************************************
// ***** DO NOT CHANGE THE NEXT 4 PARAMETERS FOR THIS VERSION OF THE BrianHG_DDR3_COMMANDER.sv... *************************************
parameter int        PORT_CACHE_BITS         = (8*DDR3_WIDTH_DM*8),                  // Note that this value must be a multiple of ' (8*DDR3_WIDTH_DQ*DDR3_NUM_CHIPS)* burst 8 '.
parameter int        CACHE_ADDR_WIDTH        = $clog2(PORT_CACHE_BITS/8),            // This is the number of LSB address bits which address all the available 8 bit bytes inside the cache word.
parameter int        DDR3_VECTOR_SIZE        = (PORT_ADDR_SIZE+4),                   // Sets the width of the VECTOR for the DDR3_PHY_SEQ controller.  4 bits for 16 possible read ports.
parameter int        CACHE_ROW_BASE          = (DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)), // Sets the starting address bit where a new row & bank begins.
// ************************************************************************************************************************************

// PORT_'feature' = '{array a,b,c,d,..} Sets the feature for each DDR3 ram controller interface port 0 to port 15.
parameter bit [8:0]  PORT_R_DATA_WIDTH    [0:15] = '{128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128}, 
parameter bit [8:0]  PORT_W_DATA_WIDTH    [0:15] = '{128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128}, 
                                                            // Use 8,16,32,64,128, or 256 bits, maximum = 'PORT_CACHE_BITS'
                                                            // As a precaution, this will prune/ignore unused data bits and write masks bits, however,
                                                            // all the data ports will still be 'PORT_CACHE_BITS' bits and the write masks will be 'PORT_CACHE_WMASK' bits.
                                                            // (a 'PORT_CACHE_BITS' bit wide data bus has 32 individual mask-able bytes (8 bit words))
                                                            // For ports sizes below 'PORT_CACHE_BITS', the data is stored and received in Big Endian.  

parameter bit [2:0]  PORT_R_PRIORITY      [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
parameter bit [2:0]  PORT_W_PRIORITY      [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
                                                            // Use 1 through 6 for normal operation.  Use 7 for above refresh priority.  Use 0 for bottom
                                                            // priority, only during free cycles once every other operation has been completed.
                                                            // Open row policy/smart row access only works between ports with identical
                                                            // priority.  If a port with a higher priority receives a request, even if another
                                                            // port's request matches the current page, the higher priority port will take
                                                            // president and force the ram controller to leave the current page.
                                                            // *(Only use 7 for small occasional access bursts which must take president above
                                                            //   all else, yet not consume memory access beyond the extended refresh requirements.)

parameter bit        PORT_R_CMD_STACK     [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
                                                            // Sets the size of the intermediate read command request stack.
                                                            // 0=4 level deep.  1=8 level deep.
                                                            // The size of the number of read commands built up in advance while the read channel waits
                                                            // for the DDR3_PHY_SEQ to return the read request data.  (Stored in logic cells)
                                                            // Multiple reads must be accumulated to allow an efficient continuous read burst.
                                                            // IE: Use 8 level deep when running a small data port width like 8 or 16 so sequential read cache
                                                            // hits continue through the command input allowing cache miss read req later-on in the req stream to be
                                                            // immediately be sent to the DDR3_PHY_SEQ before the DDR3 even returns the first read req data.

parameter bit [8:0]  PORT_W_CACHE_TOUT    [0:15] = '{ 8, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64},
                                                            // A timeout for the write cache to dump it's contents to ram.
                                                            // 0   = immediate writes, or no write cache.
                                                            // 255 = Wait up to 255 CMD_CLK clock cycles since the previous write req.
                                                            //       to the same 'PORT_CACHE_BITS' bit block before writing to ram.  Write reqs outside
                                                            //       the current 'PORT_CACHE_BITS' bit cache block clears the timer and forces an immediate write.

parameter bit        PORT_CACHE_SMART     [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
                                                            // When enabled, if an existing read cache exists at the same write request address,
                                                            // that read's cache will immediately be updated with the new write data.  (Only on the same port number...)
                                                            // This function may impact the FMAX for the system clock and increase LUT usage.
                                                            // *** Disable when designing a memory read/write testing algorithm.

parameter bit [8:0]  PORT_R_MAX_BURST     [0:15] = '{256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256},
parameter bit [8:0]  PORT_W_MAX_BURST     [0:15] = '{256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256},
                                                            // 1 through 256, 0=No sequential burst priority.
                                                            // Defines the maximum consecutive read or write burst commands from a single
                                                            // port if another read/write port requests exists with the same priority level,
                                                            // but their memory request exist in a different row.  * Every 1 counts for a BL8 burst.
                                                            // This will prevent a single continuous stream port from hogging up all the ram access time.
                                                            // IE: If set to 0, commander will seek if other read/write requests are ready before
                                                            // continuing access to the same port DDR3 access.

parameter bit        SMART_BANK                  = 1        // 1=ON, 0=OFF, With SMART_BANK enabled, the BrianHG_DDR3_COMMANDER will remember which
                                                            // ROW# has been activated in each DDR3 BANK# so that when prioritizing read and write
                                                            // ports of equal priority, multiple commands across multiple banks whose ROWs have
                                                            // matching existing activation will be prioritized/coalesced as if they were part of
                                                            // the sequential burst as PRECHARGE and ACTIVATE commands are not needed when bursting
                                                            // between active banks maintaining an unbroken read/write stream.
                                                            // (Of course the BrianHG_DDR3_PHY_SEQ is able to handle smart banking as well...)
                                                            // Note that enabling this feature uses additional logic cells and may impact FMAX.
                                                            // Disabling this feature will only coalesce commands in the current access ROW.
                                                            // Parameter 'BANK_ROW_ORDER' will define which address bits define the accessed BANK number.
)(
RST_IN, RST_OUT,
CLK_IN, DDR3_CLK, CMD_CLK, DDR3_CLK_50, DDR3_CLK_25,

// ********** Commands to DDR3_COMMANDER
CMD_W_busy,      CMD_write_req,  CMD_waddr,            CMD_wdata,           CMD_wmask,   CMD_W_priority_boost,
CMD_R_busy,      CMD_read_req,   CMD_raddr,            CMD_read_vector_in,
CMD_read_ready,  CMD_read_data,  CMD_read_vector_out,  CMD_read_addr_out,                CMD_R_priority_boost,

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

// ********** Diagnostic flags.
SEQ_CAL_PASS, DDR3_READY,PLL_LOCKED,DDR3_CMD );




// ********************************************************************************************
// Test bench IO logic.
// ********************************************************************************************
string     TB_COMMAND_SCRIPT_FILE = "DDR3_CONTROLLER_top_script.txt";	 // Choose one of the following strings...
string                Script_CMD  = "*** POWER_UP ***" ; // Message line in waveform
logic [12:0]          Script_LINE = 0  ; // Message line in waveform

localparam string  DDR_CMD_NAME [0:15] = '{"MRS","REF","PRE","ACT","WRI","REA","ZQC","nop",
                                           "xop","xop","xop","xop","xop","xop","xop","NOP"};


input  logic RST_IN,CLK_IN;
output logic RST_OUT,DDR3_CLK,CMD_CLK,DDR3_CLK_50,DDR3_CLK_25;

// ****************************************
// DDR3 Controller Interface.
// ****************************************
output logic                         CMD_R_busy          [0:PORT_R_TOTAL-1];  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.
output logic                         CMD_W_busy          [0:PORT_W_TOTAL-1];  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.


output logic                         CMD_write_req       [0:PORT_W_TOTAL-1];  // Write request for each port.

output logic [PORT_ADDR_SIZE-1:0]    CMD_waddr           [0:PORT_W_TOTAL-1];  // Address pointer for each write memory port.
output logic [PORT_CACHE_BITS-1:0]   CMD_wdata           [0:PORT_W_TOTAL-1];  // During a 'CMD_write_req', this data will be written into the DDR3 at address 'CMD_addr'.
                                                                              // Each port's 'PORT_DATA_WIDTH' setting will prune the unused write data bits.
output logic [PORT_CACHE_BITS/8-1:0] CMD_wmask           [0:PORT_W_TOTAL-1];  // Write mask for the individual bytes within the 256 bit data bus.
                                                                              // When low, the associated byte will not be written.
                                                                              // Each port's 'PORT_DATA_WIDTH' setting will prune the unused mask bits.


output logic [PORT_ADDR_SIZE-1:0]    CMD_raddr           [0:PORT_R_TOTAL-1];  // Address pointer for each read memory port.
output logic                         CMD_read_req        [0:PORT_R_TOTAL-1];  // Performs a read request for each port.
output logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_in  [0:PORT_R_TOTAL-1];  // The contents of the 'CMD_read_vector_in' during a 'CMD_read_req' will be sent to the
                                                                              // 'CMD_read_vector_out' in parallel with the 'CMD_read_data' during the 'CMD_read_ready' pulse.

output logic                         CMD_read_ready      [0:PORT_R_TOTAL-1];  // Goes high for 1 clock when the read command data is valid.
output logic [PORT_CACHE_BITS-1:0]   CMD_read_data       [0:PORT_R_TOTAL-1];  // Valid read data when 'CMD_read_ready' is high.
output logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_out [0:PORT_R_TOTAL-1];  // Returns the 'CMD_read_vector_in' which was sampled during the 'CMD_read_req' in parallel
                                                                              // with the 'CMD_read_data'.  This allows for multiple post reads where the output
                                                                              // has a destination pointer. 
output logic [PORT_ADDR_SIZE-1:0]    CMD_read_addr_out   [0:PORT_R_TOTAL-1];  // A return of the address which was sent in with the read request.


output logic                        CMD_R_priority_boost [0:PORT_R_TOTAL-1];  // Boosts the port's 'PORT_R_PRIORITY' parameter by a weight of 8 when set.
output logic                        CMD_W_priority_boost [0:PORT_W_TOTAL-1];  // Boosts the port's 'PORT_W_PRIORITY' parameter by a weight of 8 when set.


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


output logic                       SEQ_CAL_PASS;
output logic                       DDR3_READY;
output logic                       PLL_LOCKED;
output string                      DDR3_CMD = "xxx";



localparam      period   = 500000000/CLK_KHZ_IN ;
localparam      STOP_uS  = 1000000 ;
localparam      endtime  = STOP_uS * 10;


// **********************************************************************************************************************
// This module is the smart cache multi-port controller with the BrianHG_DDR3_PLL & BrianHG_DDR3_PHY_SEQ ram controller.
// **********************************************************************************************************************
BrianHG_DDR3_CONTROLLER_top #(.FPGA_VENDOR         (FPGA_VENDOR       ),   .FPGA_FAMILY        (FPGA_FAMILY       ),   .INTERFACE_SPEED  (INTERFACE_SPEED ),
                              .BHG_OPTIMIZE_SPEED  (BHG_OPTIMIZE_SPEED),   .BHG_EXTRA_SPEED    (BHG_EXTRA_SPEED   ),
                              .CLK_KHZ_IN          (CLK_KHZ_IN        ),   .CLK_IN_MULT        (CLK_IN_MULT       ),   .CLK_IN_DIV       (CLK_IN_DIV      ),

                              .DDR3_CK_MHZ         (DDR3_CK_MHZ       ),   .DDR3_SPEED_GRADE   (DDR3_SPEED_GRADE  ),   .DDR3_SIZE_GB     (DDR3_SIZE_GB    ),
                              .DDR3_WIDTH_DQ       (DDR3_WIDTH_DQ     ),   .DDR3_NUM_CHIPS     (DDR3_NUM_CHIPS    ),   .DDR3_NUM_CK      (DDR3_NUM_CK     ),
                              .DDR3_WIDTH_ADDR     (DDR3_WIDTH_ADDR   ),   .DDR3_WIDTH_BANK    (DDR3_WIDTH_BANK   ),   .DDR3_WIDTH_CAS   (DDR3_WIDTH_CAS  ),
                              .DDR3_WIDTH_DM       (DDR3_WIDTH_DM     ),   .DDR3_WIDTH_DQS     (DDR3_WIDTH_DQS    ),   .DDR3_ODT_RTT     (DDR3_ODT_RTT    ),
                              .DDR3_RZQ            (DDR3_RZQ          ),   .DDR3_TEMP          (DDR3_TEMP         ),   .DDR3_WDQ_PHASE   (DDR3_WDQ_PHASE  ), 
                              .DDR3_RDQ_PHASE      (DDR3_RDQ_PHASE    ),   .DDR3_MAX_REF_QUEUE (DDR3_MAX_REF_QUEUE),   .IDLE_TIME_uSx10  (IDLE_TIME_uSx10 ),
                              .SKIP_PUP_TIMER      (SKIP_PUP_TIMER    ),   .BANK_ROW_ORDER     (BANK_ROW_ORDER    ),

                              .PORT_ADDR_SIZE      (PORT_ADDR_SIZE    ),

                              .PORT_R_TOTAL        (PORT_R_TOTAL      ),   .PORT_W_TOTAL       (PORT_W_TOTAL      ),   .PORT_VECTOR_SIZE (PORT_VECTOR_SIZE ),
                              .PORT_R_DATA_WIDTH   (PORT_R_DATA_WIDTH ),   .PORT_W_DATA_WIDTH  (PORT_W_DATA_WIDTH ),
                              .PORT_R_PRIORITY     (PORT_R_PRIORITY   ),   .PORT_W_PRIORITY    (PORT_W_PRIORITY   ),   .PORT_R_CMD_STACK (PORT_R_CMD_STACK ),
                              .PORT_CACHE_SMART    (PORT_CACHE_SMART  ),   .PORT_W_CACHE_TOUT  (PORT_W_CACHE_TOUT ),
                              .PORT_R_MAX_BURST    (PORT_R_MAX_BURST  ),   .PORT_W_MAX_BURST   (PORT_W_MAX_BURST  ),   .SMART_BANK       (SMART_BANK       )

) DUT_DDR3_CONTROLLER_top (             

                              // *** Interface Reset, Clocks & Status. ***
                              .RST_IN               (RST_IN               ),                   .RST_OUT              (RST_OUT              ),
                              .CLK_IN               (CLK_IN               ),                   .CMD_CLK              (CMD_CLK              ),
                              .DDR3_READY           (DDR3_READY           ),                   .SEQ_CAL_PASS         (SEQ_CAL_PASS         ),
                              .PLL_LOCKED           (PLL_LOCKED           ),                   .DDR3_CLK             (DDR3_CLK             ),
                              .DDR3_CLK_50          (DDR3_CLK_50          ),                   .DDR3_CLK_25          (DDR3_CLK_25          ),

                              // *** DDR3 Controller Write functions ***
                              .CMD_W_busy           (CMD_W_busy           ),                   .CMD_write_req        (CMD_write_req        ),
                              .CMD_waddr            (CMD_waddr            ),                   .CMD_wdata            (CMD_wdata            ),
                              .CMD_wmask            (CMD_wmask            ),                   .CMD_W_priority_boost (CMD_W_priority_boost ),
                              
                              // *** DDR3 Controller Read functions ***
                              .CMD_R_busy           (CMD_R_busy           ),                   .CMD_read_req         (CMD_read_req         ),
                              .CMD_raddr            (CMD_raddr            ),                   .CMD_read_vector_in   (CMD_read_vector_in   ),
                              .CMD_read_ready       (CMD_read_ready       ),                   .CMD_read_data        (CMD_read_data        ),
                              .CMD_read_vector_out  (CMD_read_vector_out  ),                   .CMD_read_addr_out    (CMD_read_addr_out    ),
                              .CMD_R_priority_boost (CMD_R_priority_boost ),


                              // *** DDR3 Ram Chip IO Pins ***           
                              .DDR3_CK_p  (DDR3_CK_p  ),    .DDR3_CK_n  (DDR3_CK_n  ),     .DDR3_CKE     (DDR3_CKE     ),     .DDR3_CS_n (DDR3_CS_n ),
                              .DDR3_RAS_n (DDR3_RAS_n ),    .DDR3_CAS_n (DDR3_CAS_n ),     .DDR3_WE_n    (DDR3_WE_n    ),     .DDR3_ODT  (DDR3_ODT  ),
                              .DDR3_A     (DDR3_A     ),    .DDR3_BA    (DDR3_BA    ),     .DDR3_DM      (DDR3_DM      ),     .DDR3_DQ   (DDR3_DQ   ),
                              .DDR3_DQS_p (DDR3_DQS_p ),    .DDR3_DQS_n (DDR3_DQS_n ),     .DDR3_RESET_n (DDR3_RESET_n ),
                              
                              										
										// debug IO
										.RDCAL_data (  ),    .reset_phy (1'b0), .reset_cmd(1'b0)  );

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

logic       [7:0]            WDT_COUNTER;                                                       // Wait for 15 clocks or inactivity before forcing a simulation stop.
logic                        WAIT_IDLE        = 0;                                              // When high, insert a idle wait before every command.
localparam int               WDT_RESET_TIME   = 255;                                            // Set the WDT timeout clock cycles.
localparam int               SYS_IDLE_TIME    = WDT_RESET_TIME-64;                              // Consider system idle after 12 clocks of inactivity.
localparam real              DDR3_CK_MHZ_REAL = CLK_KHZ_IN * CLK_IN_MULT / CLK_IN_DIV / 1000 ;  // Generate the DDR3 CK clock frequency.
localparam real              DDR3_CK_pERIOD   = 1000 / DDR3_CK_MHZ_REAL ;                       // Generate the DDR3 CK period in nanoseconds.

logic                        MASTER_BUSY ;  // Single flag which goes high whenever anything happens or the system is in reset.

initial begin
WDT_COUNTER       = WDT_RESET_TIME  ; // Set the initial inactivity timer to maximum so that the code later-on wont immediately stop the simulation.

for (int i=0 ; i<PORT_R_TOTAL ; i++) begin
                                        CMD_read_req[i]          = 0 ; // Clear all the read requests.
                                        CMD_raddr[i]             = 0 ; // Clear all the read requests.
                                        CMD_read_vector_in[i]    = 0 ; // Clear all the read requests.
                                        CMD_R_priority_boost[i]  = 0 ; // Clear all the read requests.
                                     end
for (int i=0 ; i<PORT_W_TOTAL ; i++) begin
                                        CMD_write_req[i]         = 0 ; // Clear all the write requests.
                                        CMD_waddr[i]             = 0 ; // Clear all the write requests.
                                        CMD_wdata[i]             = 0 ; // Clear all the write requests.
                                        CMD_wmask[i]             = 0 ; // Clear all the write requests.
                                        CMD_W_priority_boost[i]  = 0 ; // Clear all the write requests.
                                     end



RST_IN = 1'b1 ; // Reset input
CLK_IN = 1'b0 ;
#(50000);
RST_IN = 1'b0 ; // Release reset at 50ns.

while (!PLL_LOCKED) @(negedge CMD_CLK);
execute_ascii_file(TB_COMMAND_SCRIPT_FILE);
end


// Generate a MASTER_BUSY flag which goes high anytime the DDR3_READY is not set or any read/write req transactions happen.
// Used for the simulation WDT inactivity stop function.
always_comb begin
    MASTER_BUSY = !DDR3_READY;
    for (int i=0 ; i<PORT_R_TOTAL ; i++) MASTER_BUSY = MASTER_BUSY || CMD_read_req[i] || CMD_read_ready[i] ;
    for (int i=0 ; i<PORT_W_TOTAL ; i++) MASTER_BUSY = MASTER_BUSY || CMD_write_req[i] ;
end

always_comb                DDR3_CMD    =  DDR_CMD_NAME[{DDR3_CS_n,DDR3_RAS_n,DDR3_CAS_n,DDR3_WE_n}] ;          // Display the command name in the output waveform
always #period                  CLK_IN = !CLK_IN;                                                // create source clock oscillator
always @(posedge CLK_IN)   WDT_COUNTER = (MASTER_BUSY) ? WDT_RESET_TIME : (WDT_COUNTER-1'b1) ;   // Setup a simulation inactivity watchdog countdown timer.
always @(posedge CLK_IN) if (WDT_COUNTER==0) begin
                                             Script_CMD  = "*** WDT_STOP ***" ;
                                             $stop;                                              // Automatically stop the simulation if the inactivity timer reaches 0.
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

wait_rdy();

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
  while (MASTER_BUSY || !DDR3_READY || RST_OUT) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
end
endtask

// ***********************************************************************************************************
// task tx_r_cmd(integer dest,string msg,integer ln);
// ***********************************************************************************************************
task tx_r_cmd(integer dest,string msg,integer ln, integer port);
begin

    while (CMD_R_busy[port]==1) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
    WDT_COUNTER          = WDT_RESET_TIME ; // Reset the watchdog timer.

    Script_LINE = ln;
    Script_CMD  = msg;
    if (dest!=0) $fwrite(dest,"%s",msg);
    CMD_read_req[port] = 1;
    @(negedge CMD_CLK);
    CMD_read_req[port] = 0;
end
endtask
// ***********************************************************************************************************
// task tx_w_cmd(integer dest,string msg,integer ln, integer port);
// ***********************************************************************************************************
task tx_w_cmd(integer dest,string msg,integer ln, integer port);
begin

    while (CMD_W_busy[port]==1) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
    WDT_COUNTER          = WDT_RESET_TIME ; // Reset the watchdog timer.

    Script_LINE = ln;
    Script_CMD  = msg;
    if (dest!=0) $fwrite(dest,"%s",msg);
    CMD_write_req[port] = 1;
    @(negedge CMD_CLK);
    CMD_write_req[port] = 0;
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

   integer unsigned                         r;//,faddr,fvect;
   string                                   cmd,msg;
   logic unsigned  [PORT_ADDR_SIZE-1:0]     addr,faddr;
   logic unsigned  [PORT_CACHE_BITS-1:0]    wdata;
   logic unsigned  [PORT_CACHE_BITS/8-1:0]  wmask;
   logic unsigned  [PORT_VECTOR_SIZE-1:0]   vect,fvect;  // Embed multiple read request returns into the SEQ_RDATA_VECT_IN.
   logic unsigned  [3:0]                    port;  // Which read and write port to be accessed...

  //while (WAIT_IDLE && (WDT_COUNTER > SYS_IDLE_TIME)) @(negedge CMD_CLK); // wait for busy to clear

   r = $fscanf(src,"%s",cmd);                      // retrieve which shape to draw

case (cmd)

   "READ","read" : begin // READ
                //wait_rdy();
 
                r = $fscanf(src,"%d%h%h",port,faddr,fvect); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Read on port %d at address (%h) to vector (%h).",port,faddr,fvect); // Create the log and waveform message.

                addr = (PORT_ADDR_SIZE)'(faddr) ;

                CMD_raddr[port]             = addr                      ;   // Setup read request pointers.
                CMD_read_vector_in[port]    = (PORT_VECTOR_SIZE)'(fvect);
                CMD_R_priority_boost[port]  = 0 ; 

                tx_r_cmd(dest,msg,ln,port); 
                end

   "WRITE","write" : begin // READ

                //wait_rdy();
 
                r = $fscanf(src,"%d%h%b%h",port,faddr,wmask,wdata); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Write on port %d at address (%h) with data (%h).",port,faddr,wdata); // Create the log and waveform message.

                addr = (PORT_ADDR_SIZE)'(faddr) ;

                CMD_waddr[port]             = addr ; // Setup write request pointers.
                CMD_wdata[port]             = wdata;
                CMD_wmask[port]             = wmask;
                CMD_W_priority_boost[port]  = 0;

                if (dest!=0)    begin
                                $sformat(msg,"%s\n                                         MASK -> (",msg);
                                for (int n=(PORT_CACHE_BITS/8-1) ; n>=0 ; n--) $sformat(msg,"%s%b%b",msg,wmask[n],wmask[n]);
                                $sformat(msg,"%s).",msg);
                                end
                tx_w_cmd(dest,msg,ln,port); 
                end

   "DELAY","delay" : begin // Delay in microseconds.
 
                //wait_rdy();
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
