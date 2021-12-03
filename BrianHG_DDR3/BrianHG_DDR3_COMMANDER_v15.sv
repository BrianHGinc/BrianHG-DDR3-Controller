// ********************************************************************************************************
//
// BrianHG_DDR3_COMMANDER_v15.sv multi-platform, 2:1/3:1/4:1 Vertically stack-able port with smart cache controller.
// Version 1.50, October 25, 2021.
//
// Written by Brian Guralnick.
//
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// Designed for Altera/Intel Quartus Cyclone V/10/MAX10 and others. (Unofficial Cyclone III & IV, may require overclocking.)
//              Lattice ECP5/LFE5U series. (*** Coming soon ***)
//              Xilinx Artix 7 series.     (*** Coming soon ***)
//
// Features:
//
// - Input and output ports identical to the BrianHG_DDR3_PHY_SEQ's interface with the optional USE_TOGGLE_CONTROLS
//
// - 1 to 16 Read/Write ports in, 1 port out with user set burst length limiter with read req vector/destination pointer.
// - Designed for high FMAX speed using the PORT_MLAYER_WIDTH with a total of up to 4 clocked layers pyramid stacked offering
//   maximum speed using 2 R/W ports branching out 4 times, or MUX all 16 ports in 1 layer offering fewer logic cells
//   at the cost of FMAX. 
//
// - 2 command input FIFO on each port.
// - 16 to 32 stacked read commands for DDR3 read data delay.
// - Separate cached read and write BL8 block.
// - Adjustable write data cache dump timeout.
//
//
//   ****************
//   *** Message: ***
//   ***********************************************************************************************************
//   *** This source code automatically generates warning and error messages in the FPGA compiler console    ***
//   *** during compilation and it will abort the compile if there are any invalid parameter settings with a ***
//   *** description/report on which parameter is invalid, the value you used and which values are allowed.  ***
//   *** This extra coding effort was done to save you debugging time.                                       ***
//   ***********************************************************************************************************
//
// ********************************************************************************************************

module BrianHG_DDR3_COMMANDER_v15 #(

parameter string     FPGA_VENDOR             = "Altera",         // (Only Altera for now) Use ALTERA, INTEL, LATTICE or XILINX.
parameter string     FPGA_FAMILY             = "MAX 10",         // With Altera, use Cyclone III, Cyclone IV, Cyclone V, MAX 10,....

// ****************  System clock generation and operation.
parameter int        CLK_KHZ_IN              = 50000,            // PLL source input clock frequency in KHz.
parameter int        CLK_IN_MULT             = 32,               // Multiply factor to generate the DDR MTPS speed divided by 2.
parameter int        CLK_IN_DIV              = 4,                // Divide factor.  When CLK_KHZ_IN is 25000,50000,75000,100000,125000,150000, use 2,4,6,8,10,12.

parameter string     INTERFACE_SPEED         = "Half",           // Either "Full", "Half", or "Quarter" speed for the user interface clock.
                                                                 // This will effect the controller's interface CMD_CLK output port frequency.
                                                                 // "Quarter" mode only provides effective speed when you do not use the BrianHG_DDR3_COMMANDER and
                                                                 // interface directly with the BrianHG_DDR3_PHY_SEQ.  Otherwise added wait states may be introduced.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_SIZE_GB            = 4,                // Use 0,1,2,4 or 8.  (0=512mb) Caution: Must be correct as ram chip size affects the tRFC REFRESH period.
parameter int        DDR3_WIDTH_DQ           = 16,               // Use 8 or 16.  The width of each DDR3 ram chip.

parameter int        DDR3_NUM_CHIPS          = 1,                // 1, 2, or 4 for the number of DDR3 RAM chips.

parameter int        DDR3_WIDTH_ADDR         = 15,               // Use for the number of bits to address each row.
parameter int        DDR3_WIDTH_BANK         = 3,                // Use for the number of bits to address each bank.
parameter int        DDR3_WIDTH_CAS          = 10,               // Use for the number of bits to address each column.

parameter int        DDR3_WIDTH_DM           = (DDR3_WIDTH_DQ*DDR3_NUM_CHIPS/8), // The width of the byte write data mask.

parameter string     BANK_ROW_ORDER          = "BANK_ROW_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.

parameter int        PORT_ADDR_SIZE          = (DDR3_WIDTH_ADDR + DDR3_WIDTH_BANK + DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)),

// ************************************************************************************************************************************
// ****************  BrianHG_DDR3_COMMANDER_2x1 configuration parameter settings.
parameter int        PORT_TOTAL              = 1,                // Set the total number of DDR3 controller write ports, 1 to 4 max.
parameter int        PORT_MLAYER_WIDTH [0:3] = '{2,2,2,2},       // Use 2 through 16.  This sets the width of each MUX join from the top PORT
                                                                 // inputs down to the final SEQ output.  2 offers the greatest possible FMAX while
                                                                 // making the first layer width = to PORT_TOTAL will minimize MUX layers to 1,
                                                                 // but with a large number of ports, FMAX may take a beating.
// ************************************************************************************************************************************
// PORT_MLAYER_WIDTH illustration
// ************************************************************************************************************************************
//  PORT_TOTAL = 16
//  PORT_MLAYER_WIDTH [0:3]  = {4,4,x,x}
//
// (PORT_MLAYER_WIDTH[0]=4)    (PORT_MLAYER_WIDTH[1]=4)     (PORT_MLAYER_WIDTH[2]=N/A) (not used)          (PORT_MLAYER_WIDTH[3]=N/A) (not used)
//                                                          These layers are not used since we already
//  PORT_xxxx[ 0] ----------\                               reached one single port to drive the DDR3 SEQ.
//  PORT_xxxx[ 1] -----------==== ML10_xxxx[0] --------\
//  PORT_xxxx[ 2] ----------/                           \
//  PORT_xxxx[ 3] ---------/                             \
//                                                        \
//  PORT_xxxx[ 4] ----------\                              \
//  PORT_xxxx[ 5] -----------==== ML10_xxxx[1] -------------==== SEQ_xxxx wires to DDR3_PHY controller.
//  PORT_xxxx[ 6] ----------/                              /
//  PORT_xxxx[ 7] ---------/                              /
//                                                       /
//  PORT_xxxx[ 8] ----------\                           /
//  PORT_xxxx[ 9] -----------==== ML10_xxxx[2] --------/
//  PORT_xxxx[10] ----------/                         /
//  PORT_xxxx[11] ---------/                         /
//                                                  /
//  PORT_xxxx[12] ----------\                      /
//  PORT_xxxx[13] -----------==== ML10_xxxx[3] ---/
//  PORT_xxxx[14] ----------/
//  PORT_xxxx[15] ---------/
//
//
//  PORT_TOTAL = 16
//  PORT_MLAYER_WIDTH [0:3]  = {3,3,3,x}
//  This will offer a better FMAX compared to {4,4,x,x}, but the final DDR3 SEQ command has 1 additional clock cycle pipe delay.
//
// (PORT_MLAYER_WIDTH[0]=3)    (PORT_MLAYER_WIDTH[1]=3)    (PORT_MLAYER_WIDTH[2]=3)                   (PORT_MLAYER_WIDTH[3]=N/A)
//                                                         It would make no difference if             (not used, we made it down to 1 port)
//                                                         this layer width was set to [2].
//  PORT_xxxx[ 0] ----------\
//  PORT_xxxx[ 1] -----------=== ML10_xxxx[0] -------\
//  PORT_xxxx[ 2] ----------/                         \
//                                                     \
//  PORT_xxxx[ 3] ----------\                           \
//  PORT_xxxx[ 4] -----------=== ML10_xxxx[1] -----------==== ML20_xxxx[0] ---\
//  PORT_xxxx[ 5] ----------/                           /                      \
//                                                     /                        \
//  PORT_xxxx[ 6] ----------\                         /                          \
//  PORT_xxxx[ 7] -----------=== ML10_xxxx[2] -------/                            \
//  PORT_xxxx[ 8] ----------/                                                      \
//                                                                                  \
//  PORT_xxxx[ 9] ----------\                                                        \
//  PORT_xxxx[10] -----------=== ML11_xxxx[0] -------\                                \
//  PORT_xxxx[11] ----------/                         \                                \
//                                                     \                                \
//  PORT_xxxx[12] ----------\                           \                                \
//  PORT_xxxx[13] -----------=== ML11_xxxx[1] -----------==== ML20_xxxx[1] ---------------====  SEQ_xxxx wires to DDR3_PHY controller.
//  PORT_xxxx[14] ----------/                           /                                /
//                                                     /                                /
//  PORT_xxxx[15] ----------\                         /                                /
//         0=[16] -----------=== ML11_xxxx[2] -------/                                /
//         0=[17] ----------/                                                        /
//                                                                                  /
//                                                                                 /
//                                                                                /
//                                                       0 = ML20_xxxx[2] -------/
//
// ************************************************************************************************************************************

parameter int        PORT_VECTOR_SIZE   = 8,                // Sets the width of each port's VECTOR input and output.

// ************************************************************************************************************************************
// ***** DO NOT CHANGE THE NEXT 4 PARAMETERS FOR THIS VERSION OF THE BrianHG_DDR3_COMMANDER.sv... *************************************
parameter int        READ_ID_SIZE       = 4,                                    // The number of bits available for the read ID.  This will limit the maximum possible read/write cache modules.
parameter int        DDR3_VECTOR_SIZE   = READ_ID_SIZE + 1,                     // Sets the width of the VECTOR for the DDR3_PHY_SEQ controller.  4 bits for 16 possible read ports.
parameter int        PORT_CACHE_BITS    = (8*DDR3_WIDTH_DM*8),                  // Note that this value must be a multiple of ' (8*DDR3_WIDTH_DQ*DDR3_NUM_CHIPS)* burst 8 '.
parameter int        CACHE_ADDR_WIDTH   = $clog2(PORT_CACHE_BITS/8),            // This is the number of LSB address bits which address all the available 8 bit bytes inside the cache word.
parameter int        PAGE_INDEX_BITS    = (DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)), // Sets the starting address bit where a new row & bank begins.
// ************************************************************************************************************************************

parameter bit        USE_TOGGLE_OUTPUTS = 1,    // Use 1 when this module is the first module whose outputs are directly connected
                                                // to the BrianHG_DDR3_PHY_SEQ.  Use 0 when this module drives another BrianHG_DDR3_COMMANDER_2x1
                                                // down the chain so long as it's parameter 'USE_TOGGLE_INPUT' is set to 0.
                                                // When 1, this module's SEQ_CMD_ENA_t output and SEQ_BUSY_t input are on toggle control mode
                                                // where each toggle of the 'SEQ_CMD_ENA_t' will represent a new command output and
                                                // whenever the 'SEQ_BUSY_t' input is not equal to the 'SEQ_CMD_ENA_t' output, the attached
                                                // module will be considered busy.

// PORT_'feature' = '{port# 0,1,2,3,4,5,,,} Sets the feature for each DDR3 ram controller interface port 0 to port 15.

parameter bit        PORT_TOGGLE_INPUT [0:15] = '{  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
                                                // When enabled, the associated port's 'CMD_busy' and 'CMD_ena' ports will operate in
                                                // toggle mode where each toggle of the 'CMD_ena' will represent a new command input
                                                // and the port is busy whenever the 'CMD_busy' output is not equal to the 'CMD_ena' input.
                                                // This is an advanced  feature used to communicate with the input channel when your source
                                                // control is operating at 2x this module's CMD_CLK frequency, or 1/2 CMD_CLK frequency
                                                // if you have disabled the port's PORT_W_CACHE_TOUT.

parameter bit [8:0]  PORT_R_DATA_WIDTH [0:15] = '{128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128},
parameter bit [8:0]  PORT_W_DATA_WIDTH [0:15] = '{128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128},
                                                // Use 8,16,32,64,128, or 256 bits, maximum = 'PORT_CACHE_BITS'
                                                // As a precaution, this will prune/ignore unused data bits and write masks bits, however,
                                                // all the data ports will still be 'PORT_CACHE_BITS' bits and the write masks will be 'PORT_CACHE_WMASK' bits.
                                                // (a 'PORT_CACHE_BITS' bit wide data bus has 32 individual mask-able bytes (8 bit words))
                                                // For ports sizes below 'PORT_CACHE_BITS', the data is stored and received in Big Endian.  

parameter bit [1:0]  PORT_PRIORITY     [0:15] = '{  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0},
                                                // Use 0 to 3.  If a port with a higher priority receives a request, even if another
                                                // port's request matches the current page, the higher priority port will take
                                                // president and force the ram controller to leave the current page.

parameter int        PORT_READ_STACK   [0:15] = '{ 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16},
                                                // Sets the size of the intermediate read command request stack.
                                                // 4 through 32, default = 16
                                                // The size of the number of read commands built up in advance while the read channel waits
                                                // for the DDR3_PHY_SEQ to return the read request data.
                                                // Multiple reads must be accumulated to allow an efficient continuous read burst.
                                                // IE: Use 16 level deep when running a small data port width like 16 or 32 so sequential read cache
                                                // hits continue through the command input allowing cache miss read req later-on in the req stream to be
                                                // immediately be sent to the DDR3_PHY_SEQ before the DDR3 even returns the first read req data.

parameter bit [8:0]  PORT_W_CACHE_TOUT [0:15] = '{256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256},
                                                // A timeout for the write cache to dump it's contents to ram.
                                                // 0   = immediate writes, or no write cache.
                                                // 256 = Wait up to 256 CMD_CLK clock cycles since the previous write req.
                                                //       to the same 'PORT_CACHE_BITS' bit block before writing to ram.  Write reqs outside
                                                //       the current 'PORT_CACHE_BITS' bit cache block clears the timer and forces an immediate write.

parameter bit        PORT_CACHE_SMART  [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},  
                                                // When enabled, if an existing read cache exists at the same write request address,
                                                // that read's cache will immediately be updated with the new write data.
                                                // This function may impact the FMAX for the system clock and increase LUT usage.
                                                // *** Disable when designing a memory read/write testing algorithm.

parameter bit        PORT_DREG_READ    [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},  
                                                // When enabled, an additional register is placed at the read data out to help improve FMAX.

parameter bit [8:0]  PORT_MAX_BURST    [0:15] = '{256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256},
                                                // 1 through 256, 0=No sequential burst priority.
                                                // Defines the maximum consecutive read or write burst commands from a single
                                                // port if another read/write port requests exists with the same priority level,
                                                // but their memory request exist in a different row.  * Every 1 counts for a BL8 burst.
                                                // This will prevent a single continuous stream port from hogging up all the ram access time.
                                                // IE: If set to 0, commander will seek if other read/write requests are ready before
                                                // continuing access to the same port DDR3 access.

parameter bit        SMART_BANK         = 0     // 1=ON, 0=OFF, With SMART_BANK enabled, the BrianHG_DDR3_COMMANDER will remember which
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
// ****************************************
// System clock and reset input
// ****************************************
input                 RST_IN,                     // Resets the controller and re-starts the DDR3 ram.
input                 CMD_CLK,                    // Must be the CMD_CLK     command clock frequency.

// ****************************************
// DDR3 commander interface.
// ****************************************
output logic                         CMD_busy            [0:PORT_TOTAL-1],  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.

input                                CMD_ena             [0:PORT_TOTAL-1],  // Send a command.
input                                CMD_write_ena       [0:PORT_TOTAL-1],  // Set high when you want to write data, low when you want to read data.

input        [PORT_ADDR_SIZE-1:0]    CMD_addr            [0:PORT_TOTAL-1],  // Command Address pointer.
input        [PORT_CACHE_BITS-1:0]   CMD_wdata           [0:PORT_TOTAL-1],  // During a 'CMD_write_req', this data will be written into the DDR3 at address 'CMD_addr'.
                                                                            // Each port's 'PORT_DATA_WIDTH' setting will prune the unused write data bits.
                                                                            // *** All channels of the 'CMD_wdata' will always be PORT_CACHE_BITS wide, however,
                                                                            // only the bottom 'PORT_W_DATA_WIDTH' bits will be active.

input        [PORT_CACHE_BITS/8-1:0] CMD_wmask           [0:PORT_TOTAL-1],  // Write enable byte mask for the individual bytes within the 256 bit data bus.
                                                                            // When low, the associated byte will not be written.
                                                                            // Each port's 'PORT_DATA_WIDTH' setting will prune the unused mask bits.
                                                                            // *** All channels of the 'CMD_wmask' will always be 'PORT_CACHE_BITS/8' wide, however,
                                                                            // only the bottom 'PORT_W_DATA_WIDTH/8' bits will be active.

input        [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_in  [0:PORT_TOTAL-1],  // The contents of the 'CMD_read_vector_in' during a read req will be sent to the
                                                                            // 'CMD_read_vector_out' in parallel with the 'CMD_read_data' during the 'CMD_read_ready' pulse.
                                                                            // *** All channels of the 'CMD_read_vector_in' will always be 'PORT_VECTOR_SIZE' wide,
                                                                            // it is up to the user to '0' the unused input bits on each individual channel.

output logic                         CMD_read_ready      [0:PORT_TOTAL-1],  // Goes high for 1 clock when the read command data is valid.
output logic [PORT_CACHE_BITS-1:0]   CMD_read_data       [0:PORT_TOTAL-1],  // Valid read data when 'CMD_read_ready' is high.
                                                                            // *** All channels of the 'CMD_read_data will' always be 'PORT_CACHE_BITS' wide, however,
                                                                            // only the bottom 'PORT_R_DATA_WIDTH' bits will be active.

output logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_out [0:PORT_TOTAL-1],  // Returns the 'CMD_read_vector_in' which was sampled during the 'CMD_read_req' in parallel
                                                                            // with the 'CMD_read_data'.  This allows for multiple post reads where the output
                                                                            // has a destination pointer.

input                                CMD_priority_boost  [0:PORT_TOTAL-1],  // Boosts the port's 'PORT_PRIORITY' parameter by a weight of 4 when set.

// ************************************************************
// *** Controls are received from the BrianHG_DDR3_PHY_SEQ. ***
// ************************************************************
input                                SEQ_CAL_PASS        ,    // Goes low after a reset, goes high if the read calibration passes.
input                                DDR3_READY          ,    // Goes low after a reset, goes high when the DDR3 is ready to go.

input                                SEQ_BUSY_t          ,    // (*** WARNING: THIS IS A TOGGLE INPUT when parameter 'USE_TOGGLE_OUTPUTS' is 1 ***) Commands will only be accepted when this output is equal to the SEQ_CMD_ENA_t toggle input.
input                                SEQ_RDATA_RDY_t     ,    // (*** WARNING: THIS IS A TOGGLE INPUT when parameter 'USE_TOGGLE_OUTPUTS' is 1 ***) This output will toggle from low to high or high to low once new read data is valid.
input        [PORT_CACHE_BITS-1:0]   SEQ_RDATA           ,    // 256 bit date read from ram, valid when SEQ_RDATA_RDY_t goes high.
input        [DDR3_VECTOR_SIZE-1:0]  SEQ_RDVEC_FROM_DDR3 ,    // A copy of the 'SEQ_RDVEC_FROM_DDR3' input during the read request.  Valid when SEQ_RDATA_RDY_t goes high.

// ******************************************************
// *** Controls are sent to the BrianHG_DDR3_PHY_SEQ. ***
// ******************************************************
output logic                         SEQ_CMD_ENA_t       ,  // (*** WARNING: THIS IS A TOGGLE CONTROL! when parameter 'USE_TOGGLE_OUTPUTS' is 1 *** ) Begin a read or write once this input toggles state from high to low, or low to high.
output logic                         SEQ_WRITE_ENA       ,  // When high, a 256 bit write will be done, when low, a 256 bit read will be done.
output logic [PORT_ADDR_SIZE-1:0]    SEQ_ADDR            ,  // Address of read and write.  Note that ADDR[4:0] are supposed to be hard wired to 0 or low, otherwise the bytes in the 256 bit word will be sorted incorrectly.
output logic [PORT_CACHE_BITS-1:0]   SEQ_WDATA           ,  // write data.
output logic [PORT_CACHE_BITS/8-1:0] SEQ_WMASK           ,  // write data mask.
output logic [DDR3_VECTOR_SIZE-1:0]  SEQ_RDVEC_TO_DDR3   ,  // Read destination vector input.
output logic                         SEQ_refresh_hold       // Prevent refresh.  Warning, if held too long, the SEQ_refresh_queue will max out.
);


// **********************************************
// ***  Unknown BANK_ROW_ORDER *****************
// **********************************************
generate
         if (BANK_ROW_ORDER!="ROW_BANK_COL" && BANK_ROW_ORDER!="BANK_ROW_COL") initial begin
$warning("**************************************************");
$warning("*** BrianHG_DDR3_COMMANDER_v15 PARAMETER ERROR ***");
$warning("**********************************************************************************************");
$warning("*** BrianHG_DDR3_COMMANDER_v15 parameter .BANK_ROW_ORDER(\"%s\") is not supported. ***",BANK_ROW_ORDER);
$warning("*** Only \"ROW_BANK_COL\" or \"BANK_ROW_COL\" are supported.                             ***");
$warning("**********************************************************************************************");
$error;
$stop;
end
endgenerate


// *********************************************************************
// ***  Bad PORT_TOTAL & PORT_MLAYER_WIDTH combination *****************
// *********************************************************************
generate
         if (PORT_TOTAL          <1 || PORT_TOTAL          >16 ||
             PORT_MLAYER_WIDTH[0]<2 || PORT_MLAYER_WIDTH[0]>16 ||
             PORT_MLAYER_WIDTH[1]<2 || PORT_MLAYER_WIDTH[1]>16 ||
             PORT_MLAYER_WIDTH[2]<2 || PORT_MLAYER_WIDTH[2]>16 ||
             PORT_MLAYER_WIDTH[3]<2 || PORT_MLAYER_WIDTH[3]>16     ) initial begin
$warning("**************************************************");
$warning("*** BrianHG_DDR3_COMMANDER_v15 PARAMETER ERROR ***");
$warning("*****************************************************************************************************");
$warning("*** BrianHG_DDR3_COMMANDER_v15 parameters .PORT_TOTAL(%d) and .PORT_MLAYER_WIDTH[%d,%d,%d,%d]     ***",6'(PORT_TOTAL),6'(PORT_MLAYER_WIDTH[0]),6'(PORT_MLAYER_WIDTH[1]),6'(PORT_MLAYER_WIDTH[2]),6'(PORT_MLAYER_WIDTH[3]) );
$warning("*** have an error.  The .PORT_TOTAL() can only be between 1 and 16 while the .PORT_MLAYER_WIDTH[] ***");
$warning("*** array can only have entry values between 2 and 16.                                            ***");
$warning("*****************************************************************************************************");
$error;
$stop;
end
endgenerate




// **** Generate a CMD_CLK synchronous local 'RESET' register.
(*preserve*) logic RESET;
always_ff @(posedge CMD_CLK) RESET <= RST_IN ;

// *******************************************************************************************************************
// Individual SEQ_xxx commands outs from each channel's DDR3_RW_CACHE module to be sent to the
// first layer of DDR3_MUX MXI_xxxx inputs.
// *******************************************************************************************************************
//
// First establish the number of DDR3_MUX's right after the inputs.
//
localparam int  ML0_first_width = (PORT_TOTAL > PORT_MLAYER_WIDTH[0]) ? PORT_MLAYER_WIDTH[0] : PORT_TOTAL ; // Set the first ML0's input width.
localparam int  ML0_total       = (PORT_TOTAL / ML0_first_width)              ;                             // Set the number of required ML0s.
localparam int  ML0_remainder   =  PORT_TOTAL - (ML0_first_width * ML0_total) ;                             // See if 1 additional smaller ML0 is required.
localparam int  ML0_extra       = (ML0_remainder==0) ? 0 : 1                  ;                             // Generate a flag signifying the extra ML0.
localparam int  ML0_tru_total   =  ML0_total + ML0_extra                      ;                             // Need to deal with the remainder gates.

logic                         ML0_BUSY            [0:PORT_TOTAL-1] ;
logic                         ML0_ENA             [0:PORT_TOTAL-1] ;
logic                         ML0_ENA_t           [0:PORT_TOTAL-1] ;
logic                         ML0_WRITE_ENA       [0:PORT_TOTAL-1] ;
logic [PORT_ADDR_SIZE-1:0]    ML0_ADDR            [0:PORT_TOTAL-1] ;
logic [PORT_CACHE_BITS-1:0]   ML0_WDATA           [0:PORT_TOTAL-1] ;
logic [PORT_CACHE_BITS/8-1:0] ML0_WMASK           [0:PORT_TOTAL-1] ;
logic [DDR3_VECTOR_SIZE-1:0]  ML0_RDVEC_TO_DDR3   [0:PORT_TOTAL-1] ;
logic                         ML0_page_hit        [0:PORT_TOTAL-1] ;
logic [1:0]                   ML0_priority        [0:PORT_TOTAL-1] ;
logic                         ML0_priority_boost  [0:PORT_TOTAL-1] ;
logic [8:0]                   ML0_max_burst       [0:PORT_TOTAL-1] ;
logic                         ML0_refresh_hold    [0:PORT_TOTAL-1] ;

genvar y;
generate
for (y=0 ; y<PORT_TOTAL; y++) begin : SML0 // Copy over source priority and max burst length parameters.
                                    assign ML0_priority        [y] = PORT_PRIORITY      [y] ;
                                    assign ML0_priority_boost  [y] = CMD_priority_boost [y] ;
                                    assign ML0_max_burst       [y] = PORT_MAX_BURST     [y] - 1'b1 ;
                                    assign ML0_refresh_hold    [y] = 0 ;
                                    end
endgenerate


// *******************************************************************************************************************
// First layer of DDR3_ML MXO_xxxx outputs to be sent to the
// next layer of DDR3_ML mux's MXI_xxxx inputs.
// *******************************************************************************************************************
//
// First establish the number of DDR3_MUX's right after the total number of ML0 module outputs.
//
localparam int  ML1_first_width = (ML0_tru_total > PORT_MLAYER_WIDTH[1]) ? PORT_MLAYER_WIDTH[1] : ML0_tru_total ; // Set the first ML1's input width.
localparam int  ML1_total       = (ML0_tru_total / ML1_first_width)              ;                            // Set the number of required ML1s.
localparam int  ML1_remainder   =  ML0_tru_total - (ML1_first_width * ML1_total) ;                            // See if 1 additional smaller ML1 is required.
localparam int  ML1_extra       = (ML1_remainder==0) ? 0 : 1                 ;                            // Generate a flag signifying the extra ML1.
localparam int  ML1_tru_total   =  ML1_total + ML1_extra                     ;                            // Need to deal with the remainder gates.

logic                         ML1_BUSY            [0:ML0_total+ML0_extra-1] ;
logic                         ML1_ENA             [0:ML0_total+ML0_extra-1] ;
logic                         ML1_ENA_t           [0:ML0_total+ML0_extra-1] ;
logic                         ML1_WRITE_ENA       [0:ML0_total+ML0_extra-1] ;
logic [PORT_ADDR_SIZE-1:0]    ML1_ADDR            [0:ML0_total+ML0_extra-1] ;
logic [PORT_CACHE_BITS-1:0]   ML1_WDATA           [0:ML0_total+ML0_extra-1] ;
logic [PORT_CACHE_BITS/8-1:0] ML1_WMASK           [0:ML0_total+ML0_extra-1] ;
logic [DDR3_VECTOR_SIZE-1:0]  ML1_RDVEC_TO_DDR3   [0:ML0_total+ML0_extra-1] ;
logic                         ML1_page_hit        [0:ML0_total+ML0_extra-1] ;
logic [1:0]                   ML1_priority        [0:ML0_total+ML0_extra-1] ;
logic                         ML1_priority_boost  [0:ML0_total+ML0_extra-1] ;
logic [8:0]                   ML1_max_burst       [0:ML0_total+ML0_extra-1] ;
logic                         ML1_refresh_hold    [0:ML0_total+ML0_extra-1] ;


// *******************************************************************************************************************
// Second layer of DDR3_ML MXO_xxxx outputs to be sent to the
// next layer of DDR3_ML mux's MXI_xxxx inputs.
// *******************************************************************************************************************
//
// First establish the number of DDR3_MUX's right after the total number of ML1 module outputs.
//
localparam int  ML2_first_width = (ML1_tru_total > PORT_MLAYER_WIDTH[2]) ? PORT_MLAYER_WIDTH[2] : ML1_tru_total ; // Set the first ML2's input width.
localparam int  ML2_total       = (ML1_tru_total / ML2_first_width)              ;                            // Set the number of required ML2s.
localparam int  ML2_remainder   =  ML1_tru_total - (ML2_first_width * ML2_total) ;                            // See if 1 additional smaller ML2 is required.
localparam int  ML2_extra       = (ML2_remainder==0) ? 0 : 1                 ;                            // Generate a flag signifying the extra ML2.
localparam int  ML2_tru_total   =  ML2_total + ML2_extra                     ;                            // Need to deal with the remainder gates.

logic                         ML2_BUSY            [0:ML1_total+ML1_extra-1] ;
logic                         ML2_ENA             [0:ML1_total+ML1_extra-1] ;
logic                         ML2_ENA_t           [0:ML1_total+ML1_extra-1] ;
logic                         ML2_WRITE_ENA       [0:ML1_total+ML1_extra-1] ;
logic [PORT_ADDR_SIZE-1:0]    ML2_ADDR            [0:ML1_total+ML1_extra-1] ;
logic [PORT_CACHE_BITS-1:0]   ML2_WDATA           [0:ML1_total+ML1_extra-1] ;
logic [PORT_CACHE_BITS/8-1:0] ML2_WMASK           [0:ML1_total+ML1_extra-1] ;
logic [DDR3_VECTOR_SIZE-1:0]  ML2_RDVEC_TO_DDR3   [0:ML1_total+ML1_extra-1] ;
logic                         ML2_page_hit        [0:ML1_total+ML1_extra-1] ;
logic [1:0]                   ML2_priority        [0:ML1_total+ML1_extra-1] ;
logic                         ML2_priority_boost  [0:ML1_total+ML1_extra-1] ;
logic [8:0]                   ML2_max_burst       [0:ML1_total+ML1_extra-1] ;
logic                         ML2_refresh_hold    [0:ML1_total+ML1_extra-1] ;


// *******************************************************************************************************************
// Third layer of DDR3_ML MXO_xxxx outputs to be sent to the
// next layer of DDR3_ML mux's MXI_xxxx inputs.
// *******************************************************************************************************************
//
// First establish the number of DDR3_MUX's right after the total number of ML2 module outputs.
//
localparam int  ML3_first_width = (ML2_tru_total > PORT_MLAYER_WIDTH[3]) ? PORT_MLAYER_WIDTH[3] : ML2_tru_total ; // Set the first ML3's input width.
localparam int  ML3_total       = (ML2_tru_total / ML3_first_width)              ;                            // Set the number of required ML3s.
localparam int  ML3_remainder   =  ML2_tru_total - (ML3_first_width * ML3_total) ;                            // See if 1 additional smaller ML3 is required.
localparam int  ML3_extra       = (ML3_remainder==0) ? 0 : 1                 ;                            // Generate a flag signifying the extra ML3.
localparam int  ML3_tru_total   =  ML3_total + ML3_extra                     ;                            // Need to deal with the remainder gates.

logic                         ML3_BUSY            [0:ML2_total+ML2_extra-1];
logic                         ML3_ENA             [0:ML2_total+ML2_extra-1];
logic                         ML3_ENA_t           [0:ML2_total+ML2_extra-1];
logic                         ML3_WRITE_ENA       [0:ML2_total+ML2_extra-1];
logic [PORT_ADDR_SIZE-1:0]    ML3_ADDR            [0:ML2_total+ML2_extra-1];
logic [PORT_CACHE_BITS-1:0]   ML3_WDATA           [0:ML2_total+ML2_extra-1];
logic [PORT_CACHE_BITS/8-1:0] ML3_WMASK           [0:ML2_total+ML2_extra-1];
logic [DDR3_VECTOR_SIZE-1:0]  ML3_RDVEC_TO_DDR3   [0:ML2_total+ML2_extra-1];
logic                         ML3_page_hit        [0:ML2_total+ML2_extra-1];
logic [1:0]                   ML3_priority        [0:ML2_total+ML2_extra-1];
logic                         ML3_priority_boost  [0:ML2_total+ML2_extra-1];
logic [8:0]                   ML3_max_burst       [0:ML2_total+ML2_extra-1];
logic                         ML3_refresh_hold    [0:ML2_total+ML2_extra-1];


// *******************************************************************************************************************
// Final DDR3_ML MXO_xxxx outputs to be sent to the DDR3_PHY
// *******************************************************************************************************************
logic                         ML4_BUSY            ;
logic                         ML4_ENA             ;
logic                         ML4_ENA_t           ;
logic                         ML4_WRITE_ENA       ;
logic [PORT_ADDR_SIZE-1:0]    ML4_ADDR            ;
logic [PORT_CACHE_BITS-1:0]   ML4_WDATA           ;
logic [PORT_CACHE_BITS/8-1:0] ML4_WMASK           ;
logic [DDR3_VECTOR_SIZE-1:0]  ML4_RDVEC_TO_DDR3   ;
//logic                         ML4_page_hit        ;
//logic [1:0]                   ML4_priority        ;
//logic                         ML4_priority_boost  ;
//logic [8:0]                   ML4_max_burst       ;
logic                         ML4_refresh_hold    ;


// *******************************************************************************************************************
// Dummy fourth layer of DDR3_ML MXO_xxxx outputs to be sent to the
// next layer of DDR3_ML mux's MXI_xxxx inputs.
// *******************************************************************************************************************
//
// First establish the number of DDR3_MUX's right after the total number of ML3 module outputs.
//
localparam int  ML4_first_width =  ML3_total + ML3_extra ;   // Set the first ML4's input width.
//
// If there are more than ONE ML3 layer MUXes, then the MUX tree cannot be constructed due to too many ports
// with not enough width of Y branches throughout the tree structure.  Report an error and stop the compile.
//
generate
         if (ML4_first_width!=1) initial begin
$warning("**************************************************");
$warning("*** BrianHG_DDR3_COMMANDER_v15 PARAMETER ERROR ***");
$warning("*****************************************************************************************************");
$warning("*** BrianHG_DDR3_COMMANDER_v15 parameters .PORT_TOTAL(%d) and .PORT_MLAYER_WIDTH[%d,%d,%d,%d]     ***",6'(PORT_TOTAL),6'(PORT_MLAYER_WIDTH[0]),6'(PORT_MLAYER_WIDTH[1]),6'(PORT_MLAYER_WIDTH[2]),6'(PORT_MLAYER_WIDTH[3]) );
$warning("*** generate a tree with more than one final ML3 layer MUXes.  The MUX tree cannot be constructed ***");
$warning("*** due to too many ports with not enough width of Y branches throughout the tree structure.      ***");
$warning("*****************************************************************************************************");
$error;
$stop;
end
endgenerate


// *******************************************************************************************************************
// ports and regs to convert toggle logic to enable logic.
// *******************************************************************************************************************
logic [PORT_TOTAL-1:0]        CMD_ena_e             ;
logic [PORT_TOTAL-1:0]        CMD_ena_td        = 0 ;
logic [PORT_TOTAL-1:0]        CMD_busy_e            ;
logic [PORT_TOTAL-1:0]        CMD_read_ready_e      ;
logic [PORT_TOTAL-1:0]        CMD_read_ready_td = 0 ;

// *******************************************************************************************************************
// Convert toggle logic to enable logic and vice versa for the CMD_ena in, CMD_busy out, and CMD_read_ready
// out based on parameter PORT_TOGGLE_INPUT.
// *******************************************************************************************************************
logic                         SEQ_RDATA_RDY_td                                       ; // Decoded SEQ_RDATA_RDY true logic from the SEQ_RDATA_RDY_t toggle logic.
always_ff @(posedge CMD_CLK)  SEQ_RDATA_RDY_td <= SEQ_RDATA_RDY_t                    ;

logic                         SEQ_CMD_ENA, SEQ_CMD_ENA_et ; 
wire                          SEQ_RDATA_RDY_e   = SEQ_RDATA_RDY_t ^ (SEQ_RDATA_RDY_td &&  USE_TOGGLE_OUTPUTS) ;
assign                        SEQ_CMD_ENA_t     = USE_TOGGLE_OUTPUTS ? SEQ_CMD_ENA_et : SEQ_CMD_ENA ;
wire                          SEQ_BUSY_e        = SEQ_BUSY_t      ^ (SEQ_CMD_ENA_et    &&  USE_TOGGLE_OUTPUTS) ;


genvar x;
generate
for (x=0 ; x<=(PORT_TOTAL-1) ; x=x+1) begin : RWC_t

      always_ff @(posedge CMD_CLK) begin
        if (RESET) begin
            CMD_ena_td       [x] <= 0 ;
            CMD_read_ready_td[x] <= 0 ;
        end else begin
                                   CMD_ena_td       [x] <=  CMD_ena          [x];
            if (CMD_read_ready_e)  CMD_read_ready_td[x] <= !CMD_read_ready_td[x];
        end // !reset
      end // always_ff

    assign CMD_ena_e     [x]  = CMD_ena         [x] ^ (CMD_ena_td       [x] && PORT_TOGGLE_INPUT[x]);
    assign CMD_read_ready[x]  = CMD_read_ready_e[x] ^ (CMD_read_ready_td[x] && PORT_TOGGLE_INPUT[x]);
    assign CMD_busy      [x]  = CMD_busy_e      [x] ^ (CMD_ena          [x] && PORT_TOGGLE_INPUT[x]); // In toggle mode, system is busy whenever CMD_ena in != CMD_busy out.

end // for x
endgenerate


// *******************************************************************************************************************
// *** Initiate DDR3_RW_CACHE module for each channel up to the PORT_TOTAL quantity,
// *** take in read/write commands, generate DDR3 RW req with ID inside DDR3 vector.
// *******************************************************************************************************************
generate
    for (x=0 ; x<=(PORT_TOTAL-1) ; x=x+1) begin : RWC
    DDR3_RW_CACHE #(
    .PORT_ADDR_SIZE      ( PORT_ADDR_SIZE          ),
    .PORT_CACHE_BITS     ( PORT_CACHE_BITS         ),
    .PAGE_INDEX_BITS     ( PAGE_INDEX_BITS         ),
    .PORT_VECTOR_SIZE    ( PORT_VECTOR_SIZE        ),
    .PORT_DREG_READ      ( PORT_DREG_READ      [x] ),
    .PORT_R_DATA_WIDTH   ( PORT_R_DATA_WIDTH   [x] ),
    .PORT_W_DATA_WIDTH   ( PORT_W_DATA_WIDTH   [x] ),
    .PORT_READ_STACK     ( PORT_READ_STACK     [x] ),
    .CMD_OUT_STACK       ( 3                       ), // 3/1 is the minimum required for quarter rate mode to burst properly.
    .STACK_SPARE_WORDS   ( 1                       ),
    .PORT_CACHE_SMART    ( PORT_CACHE_SMART    [x] ),
    .PORT_W_CACHE_TOUT   ( PORT_W_CACHE_TOUT   [x] ),
    .READ_ID_SIZE        ( READ_ID_SIZE            ), // Select the width in bits for the read ID stored in the DDR3 read vector in and out.
    .READ_ID             ( x                       )  // Select which ID which this module will send during a DDR3 read req and respond to during a DDR3 read ready.
    ) RWC (
    .RESET               ( RESET                   ),
    .CMD_CLK             ( CMD_CLK                 ),
    .CMD_busy            ( CMD_busy_e          [x] ),
    .CMD_ena             ( CMD_ena_e           [x] ),
    .CMD_write_ena       ( CMD_write_ena       [x] ),
    .CMD_addr            ( CMD_addr            [x] ),
    .CMD_wdata           ( CMD_wdata           [x] ),
    .CMD_wmask           ( CMD_wmask           [x] ),
    .CMD_read_vector_in  ( CMD_read_vector_in  [x] ),
    .CMD_read_ready      ( CMD_read_ready_e    [x] ),
    .CMD_read_data       ( CMD_read_data       [x] ),
    .CMD_read_vector_out ( CMD_read_vector_out [x] ),
// Output to DDR3.
    .SEQ_BUSY            ( ML0_BUSY            [x] ),
    .SEQ_CMD_READY       ( ML0_ENA             [x] ),
    .SEQ_CMD_READY_t     ( ML0_ENA_t           [x] ),
    .SEQ_WRITE_ENA       ( ML0_WRITE_ENA       [x] ),
    .SEQ_ADDR            ( ML0_ADDR            [x] ),
    .SEQ_WDATA           ( ML0_WDATA           [x] ),
    .SEQ_WMASK           ( ML0_WMASK           [x] ),
    .SEQ_RDVEC_TO_DDR3   ( ML0_RDVEC_TO_DDR3   [x] ),
    .SEQ_page_hit        ( ML0_page_hit        [x] ),
// Return from DDR3.
    .SEQ_RDATA_RDY       (  SEQ_RDATA_RDY_e        ),
    .SEQ_RDATA           (  SEQ_RDATA              ),
    .SEQ_RDVEC_FROM_DDR3 (  SEQ_RDVEC_FROM_DDR3    ) );
    end
endgenerate
// *******************************************************************************************************************


// *******************************************************************************************************************
// *******************************************************************************************************************
// Layer 0 MUX initiation
// *******************************************************************************************************************
// *******************************************************************************************************************
generate
    for (x=0 ; x<(ML0_total+ML0_extra) ; x=x+1) begin : MUXL0

localparam int a = x*ML0_first_width ;                                                       // set the beginning source channel number per mux input
localparam int b = x*ML0_first_width + ((x==ML0_total) ? ML0_extra : ML0_first_width ) - 1 ; // set the ending source channel number per mux input
localparam int c = x ;                                                                       // set the mux output channel number.

    // Disabling this bypass helps odd and 1 channel PORT_TOTAL achieve better throughput via adding a 2 stage dummy fifo to the command output.
    //if (a==b) begin  // Input channel width is only 1 channel wide meaning that a mux is not needed and we will hard wire the input to the output.
    //
    //    assign ML0_BUSY             [a] = ML1_BUSY            [c] ;
    //    assign ML1_ENA              [c] = ML0_ENA             [a] ;
    //    assign ML1_ENA_t            [c] = ML0_ENA_t           [a] ;
    //    assign ML1_WRITE_ENA        [c] = ML0_WRITE_ENA       [a] ;
    //    assign ML1_ADDR             [c] = ML0_ADDR            [a] ;
    //    assign ML1_WDATA            [c] = ML0_WDATA           [a] ;
    //    assign ML1_WMASK            [c] = ML0_WMASK           [a] ;
    //    assign ML1_RDVEC_TO_DDR3    [c] = ML0_RDVEC_TO_DDR3   [a] ;
    //    assign ML1_page_hit         [c] = ML0_page_hit        [a] ;
    //    assign ML1_priority         [c] = ML0_priority        [a] ;
    //    assign ML1_priority_boost   [c] = ML0_priority_boost  [a] ;
    //    assign ML1_max_burst        [c] = ML0_max_burst       [a] ;
    //    assign ML1_refresh_hold     [c] = ML0_refresh_hold    [a] ;
    //
    //end else begin
        DDR3_MUX #(
        
        .PORT_TOTAL           ( (b-a)+1          ),   // Select between the PORT_MLAYER_WIDTH[] and possible remainder size.
        .PORT_ADDR_SIZE       ( PORT_ADDR_SIZE   ),
        .PORT_CACHE_BITS      ( PORT_CACHE_BITS  ),
        .PORT_VECTOR_SIZE     ( DDR3_VECTOR_SIZE ),
        .DDR3_WIDTH_ADDR      ( DDR3_WIDTH_ADDR  ),
        .DDR3_WIDTH_BANK      ( DDR3_WIDTH_BANK  ),
        .CACHE_ADDR_WIDTH     ( CACHE_ADDR_WIDTH ),
        .PAGE_INDEX_BITS      ( PAGE_INDEX_BITS  ),
        .BANK_ROW_ORDER       ( BANK_ROW_ORDER   ),
        .SMART_BANK           ( SMART_BANK       )
        
        ) ML0 (
        
        .RESET                ( RESET            ),
        .CMD_CLK              ( CMD_CLK          ),
        
        // MUX multichannel inputs.
        .MXI_busy             ( ML0_BUSY            [a:b]), // This port is an output,
        .MXI_ena              ( ML0_ENA             [a:b]), // all the rest are inputs.
        .MXI_write_ena        ( ML0_WRITE_ENA       [a:b]),
        .MXI_addr             ( ML0_ADDR            [a:b]),
        .MXI_wdata            ( ML0_WDATA           [a:b]),
        .MXI_wmask            ( ML0_WMASK           [a:b]),
        .MXI_read_vector_in   ( ML0_RDVEC_TO_DDR3   [a:b]),
        .MXI_page_hit         ( ML0_page_hit        [a:b]),
        .MXI_priority         ( ML0_priority        [a:b]),
        .MXI_priority_boost   ( ML0_priority_boost  [a:b]),
        .MXI_max_burst        ( ML0_max_burst       [a:b]),
        .MXI_refresh_hold     ( ML0_refresh_hold    [a:b]),
        
        // MUXed Single channel output.
        .MXO_BUSY             ( ML1_BUSY             [c] ), // This port is an input,
        .MXO_ENA              ( ML1_ENA              [c] ), // all the rest are outputs.
        .MXO_ENA_t            ( ML1_ENA_t            [c] ), // all the rest are outputs.
        .MXO_WRITE_ENA        ( ML1_WRITE_ENA        [c] ),
        .MXO_ADDR             ( ML1_ADDR             [c] ),
        .MXO_WDATA            ( ML1_WDATA            [c] ),
        .MXO_WMASK            ( ML1_WMASK            [c] ),
        .MXO_RDVEC_TO_DDR3    ( ML1_RDVEC_TO_DDR3    [c] ),
        .MXO_page_hit         ( ML1_page_hit         [c] ),
        .MXO_priority         ( ML1_priority         [c] ),
        .MXO_priority_boost   ( ML1_priority_boost   [c] ),
        .MXO_max_burst        ( ML1_max_burst        [c] ),
        .MXO_refresh_hold     ( ML1_refresh_hold     [c] ) );
    //end

end
endgenerate

// *******************************************************************************************************************
// *******************************************************************************************************************
// Layer 1 MUX initiation
// *******************************************************************************************************************
// *******************************************************************************************************************
generate
    for (x=0 ; x<(ML1_total+ML1_extra) ; x=x+1) begin : MUXL1

localparam int a = x*ML1_first_width ;                                                       // set the beginning source channel number per mux input
localparam int b = x*ML1_first_width + ((x==ML1_total) ? ML1_extra : ML1_first_width ) - 1 ; // set the ending source channel number per mux input
localparam int c = x ;                                                                       // set the mux output channel number.

    if (a==b) begin  // Input channel width is only 1 channel wide meaning that a mux is not needed and we will hard wire the input to the output.
    
        assign ML1_BUSY             [a] = ML2_BUSY            [c] ;
        assign ML2_ENA              [c] = ML1_ENA             [a] ;
        assign ML2_ENA_t            [c] = ML1_ENA_t           [a] ;
        assign ML2_WRITE_ENA        [c] = ML1_WRITE_ENA       [a] ;
        assign ML2_ADDR             [c] = ML1_ADDR            [a] ;
        assign ML2_WDATA            [c] = ML1_WDATA           [a] ;
        assign ML2_WMASK            [c] = ML1_WMASK           [a] ;
        assign ML2_RDVEC_TO_DDR3    [c] = ML1_RDVEC_TO_DDR3   [a] ;
        assign ML2_page_hit         [c] = ML1_page_hit        [a] ;
        assign ML2_priority         [c] = ML1_priority        [a] ;
        assign ML2_priority_boost   [c] = ML1_priority_boost  [a] ;
        assign ML2_max_burst        [c] = ML1_max_burst       [a] ;
        assign ML2_refresh_hold     [c] = ML1_refresh_hold    [a] ;
    
    end else begin
        DDR3_MUX #(
        
        .PORT_TOTAL           ( (b-a)+1          ),   // Select between the PORT_MLAYER_WIDTH[] and possible remainder size.
        .PORT_ADDR_SIZE       ( PORT_ADDR_SIZE   ),
        .PORT_CACHE_BITS      ( PORT_CACHE_BITS  ),
        .PORT_VECTOR_SIZE     ( DDR3_VECTOR_SIZE ),
        .DDR3_WIDTH_ADDR      ( DDR3_WIDTH_ADDR  ),
        .DDR3_WIDTH_BANK      ( DDR3_WIDTH_BANK  ),
        .CACHE_ADDR_WIDTH     ( CACHE_ADDR_WIDTH ),
        .PAGE_INDEX_BITS      ( PAGE_INDEX_BITS  ),
        .BANK_ROW_ORDER       ( BANK_ROW_ORDER   ),
        .SMART_BANK           ( SMART_BANK       )
        
        ) ML0 (
        
        .RESET                ( RESET            ),
        .CMD_CLK              ( CMD_CLK          ),
        
        // MUX multichannel inputs.
        .MXI_busy             ( ML1_BUSY            [a:b]), // This port is an output,
        .MXI_ena              ( ML1_ENA             [a:b]), // all the rest are inputs.
        .MXI_write_ena        ( ML1_WRITE_ENA       [a:b]),
        .MXI_addr             ( ML1_ADDR            [a:b]),
        .MXI_wdata            ( ML1_WDATA           [a:b]),
        .MXI_wmask            ( ML1_WMASK           [a:b]),
        .MXI_read_vector_in   ( ML1_RDVEC_TO_DDR3   [a:b]),
        .MXI_page_hit         ( ML1_page_hit        [a:b]),
        .MXI_priority         ( ML1_priority        [a:b]),
        .MXI_priority_boost   ( ML1_priority_boost  [a:b]),
        .MXI_max_burst        ( ML1_max_burst       [a:b]),
        .MXI_refresh_hold     ( ML1_refresh_hold    [a:b]),
        
        // MUXed Single channel output.
        .MXO_BUSY             ( ML2_BUSY             [c] ), // This port is an input,
        .MXO_ENA              ( ML2_ENA              [c] ), // all the rest are outputs.
        .MXO_ENA_t            ( ML2_ENA_t            [c] ), // all the rest are outputs.
        .MXO_WRITE_ENA        ( ML2_WRITE_ENA        [c] ),
        .MXO_ADDR             ( ML2_ADDR             [c] ),
        .MXO_WDATA            ( ML2_WDATA            [c] ),
        .MXO_WMASK            ( ML2_WMASK            [c] ),
        .MXO_RDVEC_TO_DDR3    ( ML2_RDVEC_TO_DDR3    [c] ),
        .MXO_page_hit         ( ML2_page_hit         [c] ),
        .MXO_priority         ( ML2_priority         [c] ),
        .MXO_priority_boost   ( ML2_priority_boost   [c] ),
        .MXO_max_burst        ( ML2_max_burst        [c] ),
        .MXO_refresh_hold     ( ML2_refresh_hold     [c] ) );
    end

end
endgenerate

// *******************************************************************************************************************
// *******************************************************************************************************************
// Layer 2 MUX initiation
// *******************************************************************************************************************
// *******************************************************************************************************************
generate
    for (x=0 ; x<(ML2_total+ML2_extra) ; x=x+1) begin : MUXL2

localparam int a = x*ML2_first_width ;                                                       // set the beginning source channel number per mux input
localparam int b = x*ML2_first_width + ((x==ML2_total) ? ML2_extra : ML2_first_width ) - 1 ; // set the ending source channel number per mux input
localparam int c = x ;                                                                       // set the mux output channel number.

    if (a==b) begin  // Input channel width is only 1 channel wide meaning that a mux is not needed and we will hard wire the input to the output.
    
        assign ML2_BUSY             [a] = ML3_BUSY            [c] ;
        assign ML3_ENA              [c] = ML2_ENA             [a] ;
        assign ML3_ENA_t            [c] = ML2_ENA_t           [a] ;
        assign ML3_WRITE_ENA        [c] = ML2_WRITE_ENA       [a] ;
        assign ML3_ADDR             [c] = ML2_ADDR            [a] ;
        assign ML3_WDATA            [c] = ML2_WDATA           [a] ;
        assign ML3_WMASK            [c] = ML2_WMASK           [a] ;
        assign ML3_RDVEC_TO_DDR3    [c] = ML2_RDVEC_TO_DDR3   [a] ;
        assign ML3_page_hit         [c] = ML2_page_hit        [a] ;
        assign ML3_priority         [c] = ML2_priority        [a] ;
        assign ML3_priority_boost   [c] = ML2_priority_boost  [a] ;
        assign ML3_max_burst        [c] = ML2_max_burst       [a] ;
        assign ML3_refresh_hold     [c] = ML2_refresh_hold    [a] ;
    
    end else begin
        DDR3_MUX #(
        
        .PORT_TOTAL           ( (b-a)+1          ),   // Select between the PORT_MLAYER_WIDTH[] and possible remainder size.
        .PORT_ADDR_SIZE       ( PORT_ADDR_SIZE   ),
        .PORT_CACHE_BITS      ( PORT_CACHE_BITS  ),
        .PORT_VECTOR_SIZE     ( DDR3_VECTOR_SIZE ),
        .DDR3_WIDTH_ADDR      ( DDR3_WIDTH_ADDR  ),
        .DDR3_WIDTH_BANK      ( DDR3_WIDTH_BANK  ),
        .CACHE_ADDR_WIDTH     ( CACHE_ADDR_WIDTH ),
        .PAGE_INDEX_BITS      ( PAGE_INDEX_BITS  ),
        .BANK_ROW_ORDER       ( BANK_ROW_ORDER   ),
        .SMART_BANK           ( SMART_BANK       )
        
        ) ML0 (
        
        .RESET                ( RESET            ),
        .CMD_CLK              ( CMD_CLK          ),
        
        // MUX multichannel inputs.
        .MXI_busy             ( ML2_BUSY            [a:b]), // This port is an output,
        .MXI_ena              ( ML2_ENA             [a:b]), // all the rest are inputs.
        .MXI_write_ena        ( ML2_WRITE_ENA       [a:b]),
        .MXI_addr             ( ML2_ADDR            [a:b]),
        .MXI_wdata            ( ML2_WDATA           [a:b]),
        .MXI_wmask            ( ML2_WMASK           [a:b]),
        .MXI_read_vector_in   ( ML2_RDVEC_TO_DDR3   [a:b]),
        .MXI_page_hit         ( ML2_page_hit        [a:b]),
        .MXI_priority         ( ML2_priority        [a:b]),
        .MXI_priority_boost   ( ML2_priority_boost  [a:b]),
        .MXI_max_burst        ( ML2_max_burst       [a:b]),
        .MXI_refresh_hold     ( ML2_refresh_hold    [a:b]),
        
        // MUXed Single channel output.
        .MXO_BUSY             ( ML3_BUSY             [c] ), // This port is an input,
        .MXO_ENA              ( ML3_ENA              [c] ), // all the rest are outputs.
        .MXO_ENA_t            ( ML3_ENA_t            [c] ), // all the rest are outputs.
        .MXO_WRITE_ENA        ( ML3_WRITE_ENA        [c] ),
        .MXO_ADDR             ( ML3_ADDR             [c] ),
        .MXO_WDATA            ( ML3_WDATA            [c] ),
        .MXO_WMASK            ( ML3_WMASK            [c] ),
        .MXO_RDVEC_TO_DDR3    ( ML3_RDVEC_TO_DDR3    [c] ),
        .MXO_page_hit         ( ML3_page_hit         [c] ),
        .MXO_priority         ( ML3_priority         [c] ),
        .MXO_priority_boost   ( ML3_priority_boost   [c] ),
        .MXO_max_burst        ( ML3_max_burst        [c] ),
        .MXO_refresh_hold     ( ML3_refresh_hold     [c] ) );
    end

end
endgenerate

// *******************************************************************************************************************
// *******************************************************************************************************************
// Layer 3 MUX initiation
// *******************************************************************************************************************
// *******************************************************************************************************************
generate
    for (x=0 ; x<(ML3_total+ML3_extra) ; x=x+1) begin : MUXL3

localparam int a = x*ML3_first_width ;                                                       // set the beginning source channel number per mux input
localparam int b = x*ML3_first_width + ((x==ML3_total) ? ML3_extra : ML3_first_width ) - 1 ; // set the ending source channel number per mux input
localparam int c = x ;                                                                       // set the mux output channel number.

    if (a==b) begin  // Input channel width is only 1 channel wide meaning that a mux is not needed and we will hard wire the input to the output.
    
        assign ML3_BUSY             [a] = ML4_BUSY                ;
        assign ML4_ENA                  = ML3_ENA             [a] ;
        assign ML4_ENA_t                = ML3_ENA_t           [a] ;
        assign ML4_WRITE_ENA            = ML3_WRITE_ENA       [a] ;
        assign ML4_ADDR                 = ML3_ADDR            [a] ;
        assign ML4_WDATA                = ML3_WDATA           [a] ;
        assign ML4_WMASK                = ML3_WMASK           [a] ;
        assign ML4_RDVEC_TO_DDR3        = ML3_RDVEC_TO_DDR3   [a] ;
        //assign ML4_page_hit             = ML3_page_hit        [a] ;
        //assign ML4_priority             = ML3_priority        [a] ;
        //assign ML4_priority_boost       = ML3_priority_boost  [a] ;
        //assign ML4_max_burst            = ML3_max_burst       [a] ;
        assign ML4_refresh_hold         = ML3_refresh_hold    [a] ;
    
    end else begin
        DDR3_MUX #(
        
        .PORT_TOTAL           ( (b-a)+1          ),   // Select between the PORT_MLAYER_WIDTH[] and possible remainder size.
        .PORT_ADDR_SIZE       ( PORT_ADDR_SIZE   ),
        .PORT_CACHE_BITS      ( PORT_CACHE_BITS  ),
        .PORT_VECTOR_SIZE     ( DDR3_VECTOR_SIZE ),
        .DDR3_WIDTH_ADDR      ( DDR3_WIDTH_ADDR  ),
        .DDR3_WIDTH_BANK      ( DDR3_WIDTH_BANK  ),
        .CACHE_ADDR_WIDTH     ( CACHE_ADDR_WIDTH ),
        .PAGE_INDEX_BITS      ( PAGE_INDEX_BITS  ),
        .BANK_ROW_ORDER       ( BANK_ROW_ORDER   ),
        .SMART_BANK           ( SMART_BANK       )
        
        ) ML0 (
        
        .RESET                ( RESET            ),
        .CMD_CLK              ( CMD_CLK          ),
        
        // MUX multichannel inputs.
        .MXI_busy             ( ML3_BUSY            [a:b]), // This port is an output,
        .MXI_ena              ( ML3_ENA             [a:b]), // all the rest are inputs.
        .MXI_write_ena        ( ML3_WRITE_ENA       [a:b]),
        .MXI_addr             ( ML3_ADDR            [a:b]),
        .MXI_wdata            ( ML3_WDATA           [a:b]),
        .MXI_wmask            ( ML3_WMASK           [a:b]),
        .MXI_read_vector_in   ( ML3_RDVEC_TO_DDR3   [a:b]),
        .MXI_page_hit         ( ML3_page_hit        [a:b]),
        .MXI_priority         ( ML3_priority        [a:b]),
        .MXI_priority_boost   ( ML3_priority_boost  [a:b]),
        .MXI_max_burst        ( ML3_max_burst       [a:b]),
        .MXI_refresh_hold     ( ML3_refresh_hold    [a:b]),
        
        // MUXed Single channel output.
        .MXO_BUSY             ( ML4_BUSY                 ), // This port is an input,
        .MXO_ENA              ( ML4_ENA                  ), // all the rest are outputs.
        .MXO_ENA_t            ( ML4_ENA_t                ), // all the rest are outputs.
        .MXO_WRITE_ENA        ( ML4_WRITE_ENA            ),
        .MXO_ADDR             ( ML4_ADDR                 ),
        .MXO_WDATA            ( ML4_WDATA                ),
        .MXO_WMASK            ( ML4_WMASK                ),
        .MXO_RDVEC_TO_DDR3    ( ML4_RDVEC_TO_DDR3        ),
        .MXO_page_hit         (                          ),
        .MXO_priority         (                          ),
        .MXO_priority_boost   (                          ),
        .MXO_max_burst        (                          ),
        .MXO_refresh_hold     ( ML4_refresh_hold         ) );
    end

end
endgenerate

// transfer final MUX output to SEQ_xxxx output port.
assign ML4_BUSY          =  SEQ_BUSY_e            ;
assign SEQ_CMD_ENA       =  ML4_ENA               ;
assign SEQ_CMD_ENA_et    =  ML4_ENA_t             ;
assign SEQ_WRITE_ENA     =  ML4_WRITE_ENA         ;
assign SEQ_ADDR          =  ML4_ADDR              ;
assign SEQ_WDATA         =  ML4_WDATA             ;
assign SEQ_WMASK         =  ML4_WMASK             ;
assign SEQ_RDVEC_TO_DDR3 =  ML4_RDVEC_TO_DDR3     ;
assign SEQ_refresh_hold  =  ML4_refresh_hold      ;

endmodule










// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// *** DDR3_MUX module takes in a set number of ML_SEQ command channels with priority level.
// *** It will then select which one gets to be sent to the SEQ output.
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
module DDR3_MUX #(
parameter int        PORT_TOTAL         = 2,
parameter int        PORT_ADDR_SIZE     = 15,
parameter int        PORT_CACHE_BITS    = 128,
parameter int        PORT_VECTOR_SIZE   = 5,
parameter int        DDR3_WIDTH_ADDR    = 15,               // Use for the number of bits to address each row.
parameter int        DDR3_WIDTH_BANK    = 3,                // Use for the number of bits to address each bank.
parameter int        CACHE_ADDR_WIDTH   = 3,
parameter int        PAGE_INDEX_BITS    = 4,
parameter string     BANK_ROW_ORDER     = "BANK_ROW_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.
parameter bit        SMART_BANK         = 0
)(

input                                RESET   ,
input                                CMD_CLK ,

// ****************************************
// MUX command input channels
// ****************************************
output logic                         MXI_busy            [0:PORT_TOTAL-1],
input        [1:0]                   MXI_priority        [0:PORT_TOTAL-1], // Select the channel's priority.
input                                MXI_priority_boost  [0:PORT_TOTAL-1], // Boost the channel's priority.
input        [8:0]                   MXI_max_burst       [0:PORT_TOTAL-1], // Set the maximum sequential burst length.
input                                MXI_ena             [0:PORT_TOTAL-1],
input                                MXI_write_ena       [0:PORT_TOTAL-1],
input        [PORT_ADDR_SIZE-1:0]    MXI_addr            [0:PORT_TOTAL-1],
input        [PORT_CACHE_BITS-1:0]   MXI_wdata           [0:PORT_TOTAL-1],
input        [PORT_CACHE_BITS/8-1:0] MXI_wmask           [0:PORT_TOTAL-1],
input        [PORT_VECTOR_SIZE-1:0]  MXI_read_vector_in  [0:PORT_TOTAL-1],
input                                MXI_page_hit        [0:PORT_TOTAL-1],
input                                MXI_refresh_hold    [0:PORT_TOTAL-1],


// ****************************************
// MUX priority selected DDR3 command out.
// ****************************************
input                                MXO_BUSY             ,
output logic                         MXO_ENA            = 0,
output logic                         MXO_ENA_t          = 0,
output logic                         MXO_WRITE_ENA      = 0,
output logic [PORT_ADDR_SIZE-1:0]    MXO_ADDR           = 0,
output logic [PORT_CACHE_BITS-1:0]   MXO_WDATA          = 0,
output logic [PORT_CACHE_BITS/8-1:0] MXO_WMASK          = 0,
output logic [PORT_VECTOR_SIZE-1:0]  MXO_RDVEC_TO_DDR3  = 0,

// *****************************************************************
// ML#1 -> ML#2, used for bridging ML MUXes from 1 layer to the next
// *****************************************************************
output logic                         MXO_page_hit       = 0 , 
output logic [1:0]                   MXO_priority       = 0 , // When bridging MUX modules, these outputs feeds the next
output logic                         MXO_priority_boost = 0 , // MUX layer's modules MXI_priority*/max_burst inputs.
output logic [8:0]                   MXO_max_burst      = 0 ,
output logic                         MXO_refresh_hold   = 0
);

// These localparams set the bottom bit position in the entire address space where the BANK# and ROW# begins depending on the BANK_ROW_ORDER setting.
localparam int  BANK_BP = PORT_ADDR_SIZE - DDR3_WIDTH_BANK - (DDR3_WIDTH_ADDR*(BANK_ROW_ORDER=="ROW_BANK_COL")) ;
localparam int  ROW_BP  = PORT_ADDR_SIZE - DDR3_WIDTH_ADDR - (DDR3_WIDTH_BANK*(BANK_ROW_ORDER=="BANK_ROW_COL")) ;

// This register stores what each DDR3 BANK# is most likely activated with which ROW#
logic [DDR3_WIDTH_ADDR-1:0]   act_bank_row       [0:(1<<DDR3_WIDTH_BANK)-1] ; // Used to store which activated ROW# is in each BANK# to improve multiport
                                                                              // sequence selection order to eliminate precharge-activate command delays
                                                                              // whenever possible.

logic [3:0]            last_req_chan          = 0   ;
logic [PORT_TOTAL-1:0] last_req_chan_bit      = 0   ;
logic [PORT_TOTAL-1:0] page_hit               = 0   ;
logic [PORT_TOTAL-1:0] bank_hit               = 0   ;
logic [PORT_TOTAL-1:0] cmd_ready              = 0   ;
logic [PORT_TOTAL-1:0] boost                  = 0   ;
logic [PORT_TOTAL-1:0] boost_hit                    ;
logic [PORT_TOTAL-1:0] any_boost                    ;
logic [PORT_TOTAL-1:0] req_chan                     ;
logic [3:0]            cs                           ;
logic [3:0]            req_sel                      ;
logic                  req_ready                    ;
logic [8:0]            burst_limit            = 0   ;

always_comb begin
// **************************************************************************************************************************
// Combinational Read Request Flag Generation Logic: (1 of 3)
// Establish all the metrics of all the source read channel command input FIFOs.
// **************************************************************************************************************************
    for (int i=0 ; i<PORT_TOTAL ; i ++ ) begin
        // Copy the boost input channel to a 4 bit logic integer.
        boost[i]     = MXI_priority_boost[i] ;
        cmd_ready[i] = MXI_ena[i] ;

        // Make a flag which identifies if the next FIFO queued read command address is within the same DDR3 row as the previous DDR3's accessed address.
        // Used to raise the priority of the current read channel so that sequential reads bursts within the same row address get coalesced together.
        // The page hit flag is disabled if the burst limit has been reached.
        // Check within each BANK's stored row when SMART_BANK is set, otherwise just use the last DDR3's accessed ROW+BANK.
        if  (SMART_BANK) bank_hit[i] = ( act_bank_row[MXI_addr[i][BANK_BP+:DDR3_WIDTH_BANK]] == MXI_addr[i][ROW_BP+:DDR3_WIDTH_ADDR]) && last_req_chan_bit[i];
        else             bank_hit[i] = 0 ;

        // Assign the priority rank boost based on a compatible page/bank access.
        //page_hit[i] = (MXI_page_hit[i] || bank_hit[i]) && !burst_limit[8];
        page_hit[i] =  ((MXI_page_hit[i] && last_req_chan_bit[i]) || bank_hit[i]) ;

    end // for i

// **************************************************************************************************************************
// Combinational Read or Write Request Priority Selection Logic: (2 of 3)
// Priority select which active read or write channel goes next based on CMD_R/W_priority_boost[x] input,
// PORT_R/W_PRIORITY[x] parameter, previous port access, same page/bank hit, and previous DDR3 read/write access.
//
// Scan for the top priority DDR3 R/W req, scanning the previous R/W req channel last unless
// that channel is in a sequential burst within the same row or has a priority boost,
// secondly further prioritize coalescing all the reads/writes in a row within the same bank/page.
//
// Priority order scanned by int 'p':     MSB            ...............         LSB
//                                   (PRI_BOOST in)      (PORT_PRIORITY)     (PAGE_HIT)
//
// **************************************************************************************************************************

// Generate a flag which will show if any boosted request are available.
boost_hit      = (boost & cmd_ready);
any_boost      = (boost_hit !=0) ;                           // Make a flag which indicates that a boosted request exists.
req_chan       = (any_boost ? boost_hit:cmd_ready)  ;        // Filter select between boosted ports and no boosted ports.

// Scan inputs:    
    req_sel    = 0 ;
    req_ready  = 0 ;
    
        for (int p=7 ; p>=0 ; p-- ) begin                         // 'p' scans in order of highest priority to lowest.
        for (int i=1 ; i<17 ; i++ ) begin                     // 'i' scans channels 0-15.

        // round robin arbiter priority selection, ensure the previous accessed R/W channel of equal priority is considered last before
        // access is granted once again.
        cs = 4'(4'(i) + last_req_chan ) ;                     // RC_cs begins the scan at 'i' + the last read channel + 1

            if ( cs<PORT_TOTAL && !req_ready ) begin          // Only scan from the available read ports.

                // Add 1/2 to the read port's priority weight if the page_hit is true.
                if ( req_chan[cs] && ( {MXI_priority[cs],page_hit[cs]} == p[2:0] ) ) begin
                                                                            req_sel   = cs ;  // If there is a DDR3 read_req hit with port priority 'p', set that read channel
                                                                            req_ready = 1  ;  // and ignore the rest of the scan loop.
                                                                            end


            end

        end // for i
    end // for p

// **************************************************************************************************************************
// Combinational MXI_ack Logic: (3 of 3)
// Establish all the acknowledge for all the source read channel command input FIFOs.
// **************************************************************************************************************************
    for (int i=0 ; i<PORT_TOTAL ; i ++ ) begin
       MXI_busy[i] = (req_sel!=4'(i)) && req_ready || (MXO_BUSY && MXO_ENA)  ;
    end // for i

end // _comb

(*preserve*) logic RESET_l = 0 ;
always_ff @(posedge CMD_CLK) begin
RESET_l <= RESET ;

    if (RESET_l) begin

        if (SMART_BANK) for (int i=0 ; i<(1<<DDR3_WIDTH_BANK) ; i ++ ) act_bank_row[i] <= 0 ;

        MXO_ENA                <= 0  ;
        MXO_ENA_t              <= 0  ;
        MXO_WRITE_ENA          <= 0  ; // Select a read command.
        MXO_ADDR               <= 0  ;
        MXO_WDATA              <= 0  ;
        MXO_WMASK              <= 0  ;
        MXO_RDVEC_TO_DDR3      <= 0  ;

        MXO_page_hit           <= 0  ;
        MXO_priority           <= 0  ;
        MXO_priority_boost     <= 0  ;
        MXO_max_burst          <= 0  ;
        MXO_refresh_hold       <= 0  ;

        last_req_chan          <= 0  ;
        last_req_chan_bit      <= 0  ;
        burst_limit            <= 0  ;

    end else begin

        if (!(MXO_BUSY && MXO_ENA) && req_ready) begin

                    last_req_chan                               <=  req_sel ; // Latch the requested channel so that the round robin channel selection arbiter knows how to prioritize the next channel's access.

                    MXO_ADDR[CACHE_ADDR_WIDTH-1:0]              <=  0  ;                                                             // Send all 0 in the LSB of the address since the DDRQ_PHY_SEQ address points to 8 bit words no matter cache data bus width.
                    MXO_ADDR[PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] <=  MXI_addr           [req_sel][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] ; // Send the selected read channel address bits to the DDR3_PHY_SEQ.  This address points above the cache width.
                    MXO_WRITE_ENA                               <=  MXI_write_ena      [req_sel] ;
                    MXO_WDATA                                   <=  MXI_wdata          [req_sel] ;
                    MXO_WMASK                                   <=  MXI_wmask          [req_sel] ;
                    MXO_RDVEC_TO_DDR3                           <=  MXI_read_vector_in [req_sel] ;
                    MXO_ENA                                     <=  1                            ; // enable version of the DDR3 cmd out.
                    MXO_ENA_t                                   <= !MXO_ENA_t                    ; // enable version of the DDR3 cmd out.
                    
                    MXO_page_hit                                <=  MXI_page_hit       [req_sel] ; // May use 'page_hit[req_sel]' if it improves FMAX
                    MXO_priority                                <=  MXI_priority       [req_sel] ;
                    MXO_priority_boost                          <=  MXI_priority_boost [req_sel] ;
                    MXO_max_burst                               <=  MXI_max_burst      [req_sel] ;
                    MXO_refresh_hold                            <=  MXI_refresh_hold   [req_sel] ;

                    last_req_chan_bit                           <=  !burst_limit[8] << req_sel   ; // Set the last channel accessed in bit form when burst priority is still allowed.

                    // Store which BANK# will now be activated with which ROW address for smart page-hit port priority selection logic.
                    if (SMART_BANK) act_bank_row[MXI_addr[req_sel][BANK_BP+:DDR3_WIDTH_BANK]] <= MXI_addr[req_sel][ROW_BP+:DDR3_WIDTH_ADDR] ;

                    // Keep track of the maximum consecutive burst length counter to help the round robin channel selection arbiter choose the next channel.
                    if (req_sel != last_req_chan ) burst_limit  <= 9'(MXI_max_burst[req_sel]) ;    // If a different read channel is hit, reset the consecutive channel burst counter to it's new parameter limit.
                    else if (!burst_limit[8])      burst_limit  <= 9'(burst_limit -1) ;               // If the same channel is consecutively read, count down the burst_limit counter until is reaches -1, IE 256.

        end else if (!MXO_BUSY)                    MXO_ENA      <=  0                            ;  // disable the DDR3 cmd out when in enable version.

    end // !reset
end //_ff
endmodule







// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// *** DDR3_RW_CACHE module takes in read/write commands, stacks the read requests and passes
// *** only the necessary DDR3 read/write requests out returning the read req in order of when
// *** they were sent in with their vector.
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************
// **************************************************************************************************************************************************

module DDR3_RW_CACHE #(
parameter int        PORT_ADDR_SIZE     = 15,
parameter int        PORT_CACHE_BITS    = 128,
parameter int        PAGE_INDEX_BITS    = 4,
parameter int        PORT_VECTOR_SIZE   = 8,

parameter bit        PORT_DREG_READ     = 0,

parameter bit [8:0]  PORT_R_DATA_WIDTH  = 128,
parameter bit [8:0]  PORT_W_DATA_WIDTH  = 128,

parameter int        PORT_READ_STACK    = 16,                                 // The maximum number of posted reads allowed before the DDR3 returns the first read request.
parameter int        CMD_OUT_STACK      = 4,                                  // The maximum number of queued commands allowed between in and out.
parameter int        STACK_SPARE_WORDS  = 2,                                  // Additional spare words in the fifo after the CMD_busy flag goes high.

parameter bit        PORT_CACHE_SMART   = 1,
parameter bit [8:0]  PORT_W_CACHE_TOUT  = 256,

parameter int        READ_ID_SIZE       = 4,                                  // The number of bits available for the read ID.  This will limit the maximum possible read/write cache modules.
parameter int        READ_ID            = 0,                                  // The is this module's ID for when a read is requested and returned,
                                                                              // This value will be sent in the DDR3's read vector and monitored for read-ready command. 
parameter int        BYTE_INDEX_BITS    = $clog2(PORT_CACHE_BITS/8),          // Describes the number of address bits required to point to each 8 bit byte inside the PORT_CACHE_BITS.
parameter int        DDR3_VECTOR_SIZE   = READ_ID_SIZE + 1                    // byte index is there to set the read byte position and +1 is for the read ID position.
)(

input                                RESET               ,
input                                CMD_CLK             ,

// ****************************************
// DDR3_RW_CACHE command input
// ****************************************
output logic                         CMD_busy            ,
input                                CMD_ena             ,
input                                CMD_write_ena       ,
input        [PORT_ADDR_SIZE-1:0]    CMD_addr            ,
input        [PORT_CACHE_BITS-1:0]   CMD_wdata           ,
input        [PORT_CACHE_BITS/8-1:0] CMD_wmask           ,
input        [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_in  ,

// ****************************************
// DDR3_RW_CACHE command read-return
// ****************************************
output logic                         CMD_read_ready      ,
output logic [PORT_CACHE_BITS-1:0]   CMD_read_data       ,
output logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_out ,

// ****************************************
// DDR3_RW_CACHE DDR3 commands out
// ****************************************
input                                SEQ_BUSY            ,
(*preserve*) output logic                         SEQ_CMD_READY       ,
(*preserve*) output logic                         SEQ_CMD_READY_t     ,
(*preserve*) output logic                         SEQ_WRITE_ENA       ,
(*preserve*) output logic [PORT_ADDR_SIZE-1:0]    SEQ_ADDR            ,
(*preserve*) output logic [PORT_CACHE_BITS-1:0]   SEQ_WDATA           ,
(*preserve*) output logic [PORT_CACHE_BITS/8-1:0] SEQ_WMASK           ,
(*preserve*) output logic [DDR3_VECTOR_SIZE-1:0]  SEQ_RDVEC_TO_DDR3   ,
(*preserve*) output logic                         SEQ_page_hit        ,

// ****************************************
// DDR3_RW_CACHE DDR3 read-req in
// ****************************************
input                                SEQ_RDATA_RDY       ,
input        [PORT_CACHE_BITS-1:0]   SEQ_RDATA           ,
input        [DDR3_VECTOR_SIZE-1:0]  SEQ_RDVEC_FROM_DDR3 
);

// Make a local reset register.
(*preserve*) logic RESET_l = 0 ;
always_ff @(posedge CMD_CLK) RESET_l <= RESET ;

logic [PORT_CACHE_BITS-1:0]   enc_wdata          ; // Output from the DDR3_CMD_ENCODE_BYTE.
logic [PORT_CACHE_BITS/8-1:0] enc_wmask          ; // Output from the DDR3_CMD_ENCODE_BYTE.
logic                         cso_full           ; // Output from the CS - Command Stack FIFO.
logic                         cso_cmd_ready      ; // Output from the CS - Command Stack FIFO.
logic                         cso_write_ena      ; // Output from the CS - Command Stack FIFO.
logic [PORT_ADDR_SIZE-1:0]    cso_addr           ; // Output from the CS - Command Stack FIFO.
logic [PORT_CACHE_BITS-1:0]   cso_wdata          ; // Output from the CS - Command Stack FIFO.
logic [PORT_CACHE_BITS/8-1:0] cso_wmask          ; // Output from the CS - Command Stack FIFO.
logic [PORT_VECTOR_SIZE-1:0]  cso_read_vector_in ; // Output from the CS - Command Stack FIFO.


logic [PORT_ADDR_SIZE-1:0]    RC_addr      = 0 ;
logic [PORT_ADDR_SIZE-1:0]    WC_addr      = 0 ;
logic [PORT_CACHE_BITS-1:0]   WC_data      = 0 ;
logic [PORT_CACHE_BITS/8-1:0] WC_mask      = 0 ;
logic [PORT_CACHE_BITS-1:0]   RC_data      = 0 ;

logic [PORT_ADDR_SIZE-1:0]    rso_addr         ;
logic                         RC_stat      = 0 ;
logic                         RC_ready     = 0 ;
//logic                         RC_phl       = 0 ;
logic                         WC_ready     = 0 ;
logic                         WC_phl       = 0 ;
logic                         DDR3_rcmt    = 0 ;
logic [8:0]                   WC_tout      = 0 ;

logic [PORT_VECTOR_SIZE-1:0]  rso_vector_out   ;
logic                         RC_rcmt      = 0 ;
logic                         cso_rcmt         ;
logic                         rso_rcmt         ;
logic                         cso_rc_page_hit  ;
logic                         rs_rdy           ;
logic                         rs_full          ;
//logic                         RC_DDR3_req  = 0 ;

logic [PORT_CACHE_BITS-1:0]   RC_decb_data     ;


// ********************************************************************************************************
// *** Generate system flags
// ********************************************************************************************************
        // Make a flag which identifies when the source address remains within the same page.
wire    RC_page_hit   =   RC_addr[PORT_ADDR_SIZE-1:PAGE_INDEX_BITS] == CMD_addr[PORT_ADDR_SIZE-1:PAGE_INDEX_BITS] ;
wire    WC_page_hit   =   WC_addr[PORT_ADDR_SIZE-1:PAGE_INDEX_BITS] == cso_addr[PORT_ADDR_SIZE-1:PAGE_INDEX_BITS] ;

        // Make a flag which identifies if the next read req address is within the current read and write cache's address.
        // Used to bypass any unnecessary read requests to the DDR3.
wire    RC_cache_hit  = ( RC_addr[PORT_ADDR_SIZE-1:BYTE_INDEX_BITS] == CMD_addr[PORT_ADDR_SIZE-1:BYTE_INDEX_BITS] ) && RC_stat;
wire    WC_cache_hit  = ( WC_addr[PORT_ADDR_SIZE-1:BYTE_INDEX_BITS] == cso_addr[PORT_ADDR_SIZE-1:BYTE_INDEX_BITS] ) && WC_ready;

        // Generate the next Read Cache Miss Toggle if there isn't a cache hit.
wire    rcmt          =   RC_rcmt ^ !RC_cache_hit ;

        // Generate the DDR3 write request flag during the PORT_W_CACHE_TOUT timeout or a new write comes in generating a cache miss.
wire    WC_DDR3_req   = (( WC_ready && WC_tout[8] ) || ( WC_ready && !WC_cache_hit )) ;// && !(SEQ_BUSY && SEQ_CMD_READY);

        // Make a flag which tells us that the current read address data cache address matches the current write cache address.
wire    smart_hit     = ( WC_addr[PORT_ADDR_SIZE-1:BYTE_INDEX_BITS] == rso_addr[PORT_ADDR_SIZE-1:BYTE_INDEX_BITS] ) && WC_ready && PORT_CACHE_SMART ;

        // Generate the command port's CMD_busy flag.
        // It should be busy if either cmd stack FIFO is full, or there are both a simultaneous read and write waiting to take place.
assign  CMD_busy      = cso_full || rs_full ;
        // Render a protection from overfilling the input command FIFOS
logic                     cmd_busy_dly  = 0        ;
always @(posedge CMD_CLK) cmd_busy_dly <= CMD_busy ;
wire                      cmd_protect   = CMD_busy && cmd_busy_dly ; // Render a protection from overfilling the input command FIFOS

        // Generate wires which instruct the command stack to shift out.
//wire    rcs_shift     = cso_cmd_ready && !cso_write_ena && !rs_full && !WC_DDR3_req && !(SEQ_BUSY && SEQ_CMD_READY)  ;  // Generate the advance read command unless a last minute write is ready.
wire    rcs_shift     = cso_cmd_ready && !cso_write_ena && !WC_DDR3_req && !(SEQ_BUSY && SEQ_CMD_READY)  ;  // Generate the advance read command unless a last minute write is ready.
wire    wcs_shift     = cso_cmd_ready &&  cso_write_ena                 && !(SEQ_BUSY && SEQ_CMD_READY)  ;  // Generate the advance write command

        // Generate the DDR3 read request flag when there is a read cache miss.
wire    RC_DDR3_req   = rcs_shift ;

//wire    RC_DDR3_ack   = RC_DDR3_req && !(SEQ_BUSY && SEQ_CMD_READY) && !WC_DDR3_req ;
wire    WC_DDR3_ack   = WC_DDR3_req && !(SEQ_BUSY && SEQ_CMD_READY)                 ;

        // Generate a DDR3 read ready flag.
wire    DDR3_rd_ready = ( SEQ_RDATA_RDY && ( SEQ_RDVEC_FROM_DDR3[READ_ID_SIZE-1:0] == (READ_ID_SIZE)'(READ_ID) ) ) ;


//// ********************************************************************************************************
//// *** Assign the command output ***
//// ********************************************************************************************************
//assign SEQ_CMD_READY   =  ((WC_DDR3_req || RC_DDR3_req) && !SEQ_BUSY) ;
//assign SEQ_CMD_READY_t   =  SEQ_CMD_READY                             ; // **** TOGGLE cannot function properly at this stage.
//assign SEQ_WRITE_ENA     =  WC_DDR3_req                               ;
//assign SEQ_WDATA         =  WC_data                                   ;
//assign SEQ_WMASK         =  WC_mask                                   ;
//assign SEQ_ADDR          =  WC_DDR3_req ? WC_addr      : cso_addr     ;
//assign SEQ_page_hit      =  WC_DDR3_req ? WC_phl       : RC_page_hit  ;
//
//// Assign the DDR3 read vector output to this DDR3_RW_CACHE's READ_ID number and add the RC_rcmt which toggles during a read req with a cache miss, IE: The new read address request position ID.
//assign SEQ_RDVEC_TO_DDR3 = {rcmt,(READ_ID_SIZE)'(READ_ID)};

// ****************************************************************************************************************************
// Convert the selected command input write PORT_W_DATA_WIDTH to the DDR3's PORT_CACHE_BITS width.
// ****************************************************************************************************************************
DDR3_CMD_ENCODE_BYTE #(
         .input_width      ( PORT_W_DATA_WIDTH             ),    // Sets the width of the input data.
         .output_width     ( PORT_CACHE_BITS               )     // Sets the width of the output data.
) CMD_ENCB (
         .addr             ( CMD_addr[BYTE_INDEX_BITS-1:0] ),
         .data_in          ( CMD_wdata                     ),
         .mask_in          ( CMD_wmask                     ),
         .data_out         ( enc_wdata                     ),
         .mask_out         ( enc_wmask                     ));

// ****************************************************************************************************************************
// Generate a queue for read/write command requests.
// ****************************************************************************************************************************
localparam CMD_OS_BITS = 1 + PORT_ADDR_SIZE + PORT_CACHE_BITS + (PORT_CACHE_BITS/8) + 2;// + PORT_VECTOR_SIZE ;

        BHG_FIFO_shifter_FWFT #(
        .bits            ( CMD_OS_BITS                                                     ),  // The width of the FIFO's data_in and data_out ports.
        .words           ( CMD_OUT_STACK                                                   ),
        .spare_words     ( STACK_SPARE_WORDS                                               )   // The number of spare words before being truly full, IE the full flag goes high early

) CMD_CS (
         .clk            ( CMD_CLK                                                         ),
         .reset          ( RESET_l                                                         ),

         .shift_in       ( CMD_ena && !(RC_cache_hit && !CMD_write_ena) && !cmd_protect    ),
         .shift_out      ( (wcs_shift || rcs_shift)                                        ),
         .data_in        ( {CMD_write_ena,CMD_addr,enc_wdata,enc_wmask,rcmt    ,RC_page_hit}),//,CMD_read_vector_in} ),

         .data_ready     ( cso_cmd_ready                                                   ),
         .full           ( cso_full                                                        ),

         .data_out       ( {cso_write_ena,cso_addr,cso_wdata,cso_wmask,cso_rcmt,cso_rc_page_hit} ));//,cso_read_vector_in} ));


// ****************************************************************************************************************************
// Generate the read stack which queues all the reads requests in wait for the DDR3 to return the read data.
// ****************************************************************************************************************************
wire read_ready = rs_rdy && RC_ready && (rso_rcmt==DDR3_rcmt) ;

        BHG_FIFO_shifter_FWFT #(
        .bits            ( PORT_VECTOR_SIZE + 1 + PORT_ADDR_SIZE     ),  // The width of the FIFO's data_in and data_out ports.
        .words           ( PORT_READ_STACK                           ), 
        .spare_words     ( STACK_SPARE_WORDS                         )   // The number of spare words before being truly full, IE the full flag goes high early

) CMD_RS (
         .clk            ( CMD_CLK                                   ),
         .reset          ( RESET_l                                   ),

//         .shift_in       ( rcs_shift                                 ),  // read input channel from command stack
//         .data_in        ( {cso_read_vector_in,      rcmt, cso_addr} ),  // read input channel from command stack

         .shift_in       ( (CMD_ena && !CMD_write_ena) && !cmd_protect ),  // direct read input channel, 2 clock cycle lees
         .data_in        ( {CMD_read_vector_in,      rcmt, CMD_addr} ),  // direct read input channel, 2 clock cycle less

         .shift_out      ( read_ready                                ),
         .data_ready     ( rs_rdy                                    ),
         .full           ( rs_full                                   ),

         .data_out       ( {rso_vector_out,      rso_rcmt, rso_addr} ));


// ****************************************************************************************************************************
// Convert the DDR3's read data PORT_CACHE_BITS width to the selected PORT_R_DATA_WIDTH output width.
// ****************************************************************************************************************************
DDR3_CMD_DECODE_BYTE #(
         .input_width      ( PORT_CACHE_BITS               ),    // Sets the width of the input data.
         .output_width     ( PORT_R_DATA_WIDTH             )     // Sets the width of the output data.
) CMD_DECB (
         .addr             ( rso_addr[BYTE_INDEX_BITS-1:0] ),
         .data_in          ( RC_data                       ),
         .data_out         ( RC_decb_data                  ));


// ****************************************************************************************************************************
// Select between direct read output and a secondary DFF read output to help improve FMAX at the expense of additional regs.
// ****************************************************************************************************************************

generate if (PORT_DREG_READ==0) begin

        assign          CMD_read_ready           = read_ready     ;
        assign          CMD_read_data            = RC_decb_data   ;
        assign          CMD_read_vector_out      = rso_vector_out ;

end else begin
    always_ff @(posedge CMD_CLK) begin
        if (read_ready) begin
                        CMD_read_ready          <= 1              ;
                        CMD_read_data           <= RC_decb_data   ;
                        CMD_read_vector_out     <= rso_vector_out ;
                        end else CMD_read_ready <= 0              ;
    end
end
endgenerate


always_ff @(posedge CMD_CLK) begin

    if (RESET_l) begin

        RC_stat           <= 0 ;
        RC_ready          <= 0 ;
        WC_ready          <= 0 ;
        RC_rcmt           <= 0 ;
        DDR3_rcmt         <= 0 ;
        WC_phl            <= 0 ;
        //RC_phl            <= 0 ;

        SEQ_CMD_READY     <= 0 ;
        SEQ_CMD_READY_t   <= 0 ;
        SEQ_WRITE_ENA     <= 0 ;
        SEQ_WDATA         <= 0 ;
        SEQ_WMASK         <= 0 ;
        SEQ_ADDR          <= 0 ;
        SEQ_page_hit      <= 0 ;
        SEQ_RDVEC_TO_DDR3 <= 0 ;

    end else begin

// ********************************************************
// *** Write cache management
// *** Coalesce writes within the same PORT_CACHE_BITS
// *** address, send write request when a new address
// *** comes in, or the dump write cache timer runs out.
// ********************************************************
    if (wcs_shift) begin

         WC_ready <= 1 ;                           // State that the write cache has at least 1 filled word.
         WC_tout  <= 9'(PORT_W_CACHE_TOUT-1)  ;    // Set the cache timeout time, giving time to allow additional additional writes into the same address.
         WC_addr  <= cso_addr ;                    // Fill the write cache address.

         for (int z=0 ; z<(PORT_CACHE_BITS/8) ; z ++ ) begin                           // Transfer only the individual 8 bit chunks which were masked on.

                if (cso_wmask[z])   WC_data[z*8 +:8] <= cso_wdata[z*8 +:8] ;
                if (!WC_cache_hit)  WC_mask[z]       <= cso_wmask[z] ;                 // Clear and transfer only the active write enable mask bits as this is a new write.
                else                WC_mask[z]       <= cso_wmask[z] || WC_mask[z] ;   // In the case of separate multiple byte write to the same address before the cache timeout
                                                                                       // has been reached, enable those masked bits while retaining previous write enable masked bits.
         end // For z loop

    end 

    else begin

        if (!WC_tout[8] && !cso_cmd_ready) WC_tout  <= 9'(WC_tout - 1);  // Count down to negative 1, IE 256...
        if ( WC_DDR3_ack )                 WC_ready <= 0 ;               // Since there is no new write request and a DDR3 write has taken place, clear the cache write data ready flag.

    end

        if (wcs_shift)                     WC_phl   <= WC_page_hit        ;

// ********************************************************
// *** Read req management
// *** Generate a DDR3 read request only if the CMD
// *** read req does not match the current read cache.
// ********************************************************
//         if (rcs_shift) begin
         if ((CMD_ena && !CMD_write_ena)) begin
                              RC_stat     <= 1                  ; // Notify that the 'RC_addr' has a valid address.
                              RC_addr     <= CMD_addr           ; // Store a copy of the last read request address.
                              RC_rcmt     <= rcmt               ; // Latch the next generated Read Cache Miss Toggle if there isn't a cache hit.
                              //RC_phl      <= RC_page_hit        ;
                              //RC_DDR3_req <= 1                  ; // A read request is ready.
end //else if (RC_DDR3_ack)     RC_DDR3_req <= 0                  ; // Clear the read request.

// ********************************************************
// *** DDR3 read ready to read data cache management
// ********************************************************

        // Select between the DDR3 read data and the write data channel if there is a smart_hit cache hit. (IE Write cache address matched read address.)
        // If there is a smart cache hit, only use the individual 8 bit chunks which were masked ON/ENABLE in the write channel.
        // otherwise use the DDR3 read data when a valid DDR3 read comes in.
    for (int z=0 ; z<(PORT_CACHE_BITS/8) ; z ++ ) begin
        if ( DDR3_rd_ready || (smart_hit && WC_mask[z]) ) RC_data [z*8 +:8] <= (smart_hit && WC_mask[z]) ? WC_data[z*8 +:8] : SEQ_RDATA[z*8 +:8] ;
    end // For z

        // Transfer the rcmt flag and set the RC_ready when a DDR3 read comes in.
    if (DDR3_rd_ready) begin
        DDR3_rcmt         <= SEQ_RDVEC_FROM_DDR3[READ_ID_SIZE] ; // Retrieve the new read address position ID return, read cache miss toggle.
        RC_ready          <= 1                                 ; // Internally specify that the read data is now valid
    end

// ********************************************************************************************************
// *** Assign the command output ***
// ********************************************************************************************************

if (((WC_DDR3_req || RC_DDR3_req) && !(SEQ_BUSY && SEQ_CMD_READY))) begin

                                SEQ_CMD_READY     <=  1 ;
                                SEQ_CMD_READY_t   <=  !SEQ_CMD_READY_t                              ; 
                                SEQ_WRITE_ENA     <=  WC_DDR3_req                                   ;
                                SEQ_WDATA         <=  WC_data                                       ;
                                SEQ_WMASK         <=  WC_mask                                       ;
                                SEQ_ADDR          <=  WC_DDR3_req ? WC_addr      : cso_addr         ;
                                SEQ_page_hit      <=  WC_DDR3_req ? WC_phl       : cso_rc_page_hit  ;
                                SEQ_RDVEC_TO_DDR3 <= {cso_rcmt,(READ_ID_SIZE)'(READ_ID)}            ;

                    end else if (!SEQ_BUSY)   SEQ_CMD_READY     <=  0 ;

  end // !reset.
end // always
endmodule








//*************************************************************************************************************************************
//*************************************************************************************************************************************
//*************************************************************************************************************************************
// This module takes in the write data and mask of smaller or equal input PORT_W_DATA_WIDTH,
// then outputs the data to the correct position within the data bus with the PORT_CACHE_BITS width.
//*************************************************************************************************************************************
//*************************************************************************************************************************************
//*************************************************************************************************************************************
module DDR3_CMD_ENCODE_BYTE #(
//*************************************************************************************************************************************
parameter  int input_width  = 8,                      // Sets the width of the input data and byte mask data (mask size=/8).
parameter  int output_width = 128,                    // Sets the width of the output data and mask data (mask size=/8)
parameter  int index_width  = $clog2(output_width/8)  // Describes the number of address bits required to point to each word.
//*************************************************************************************************************************************
)(
input logic  [index_width-1:0]    addr,
input logic  [output_width-1:0]   data_in,            // Remember, even though only the 'input_width' LSBs are functional, the port still has the full width.
input logic  [output_width/8-1:0] mask_in,            // Upper unused bits will be ignored.

output logic [output_width-1:0]   data_out,
output logic [output_width/8-1:0] mask_out
);

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
//*************************************************************************************************************************************
//*************************************************************************************************************************************
// This module takes in the full PORT_CACHE_BITS width read data and outputs a smaller or equal data at the size of PORT_R_DATA_WIDTH.
//*************************************************************************************************************************************
//*************************************************************************************************************************************
//*************************************************************************************************************************************
module DDR3_CMD_DECODE_BYTE #(
//*************************************************************************************************************************************
parameter  int input_width  = 128,                   // Sets the width of the input data.
parameter  int output_width = 8,                     // Sets the width of the output data.
parameter  int index_width  = $clog2(input_width/8)  // Describes the number of address bits required to point to each word.
//*************************************************************************************************************************************
)(
input logic  [index_width-1:0]    addr,
input logic  [input_width-1:0]    data_in,

output logic [input_width-1:0]    data_out           // **** REMEMBER, the output bus is still the same full PORT_CACHE_BITS, it's just that the unused bits
                                                     //                will be set to 0.
);

logic        [index_width-1:0]    index_ptr ;        // The index pointer from the address.

always_comb begin

    // Retrieve the index position.
    // Filter out the least significant address bits when the output width is greater than 8 bits.
    index_ptr  = (index_width)'( (addr[index_width-1:0] ^ {index_width{1'b1}}) & ( {index_width{1'b1}} ^ (output_width/8-1) ) ) ; 

    // Select the data out word based on the index position
    data_out   = (data_in >> (index_ptr * 8)) & {output_width{1'b1}} ;

end // always comb
endmodule

