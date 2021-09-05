// ********************************************************************************************************
//
// BrianHG_DDR3_COMMANDER.sv multi-platform, multi-DMA-port (16 read and 16 write ports max) cache controller.
// Version 1.00, August 22, 2021.
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
// - Unified interface, controls and cross compatibility across all 3 FPGA vendors.
// - Free open source.
// - Source code has FULL documentation in code.
// - Super compact, low LUT/LE all SystemVerilog core.
// - Built in parameter configured PLL generator for each FPGA vendor.
//
// - Supports one/two 8bit DDR3 rams, or, one/two 16bit DDR3 rams.
//   DDR Width 8  16                      16  32
//
//
// - Half rate, Quarter rate, or Eighth rate controller mode. (IE: Running the DDR at 640mtps means
//                                                                 you can interface with the BrianHG_DDR3_PHY_SEQ
//                                                                 controller at 320MHz or 160MHz or 80MHz.)
//
// - Up to 16 user set priority encoded read and 16 write ports, each with a re-sizable
//   read req vector/destination pointer allowing easy expansion of the number of read ports
//   while the set read data vector is returned with the read data.  Allows easy automatic DMA memory transfer routines.
//   (Realistically, 8 to 16 ports with every cache feature enabled on every port unless you use 
//    Quarter/Eighth rate mode, or only enable the 'PORT_CACHE_SMART' parameter for the required ports.)
//
// - Each read/write port is 'DDR3 width * number of DDR3 * 8' bits where the first 5 bits in the
//   address select the word Endian for every byte (8 bits) on the data port.  Combined
//   with a byte mask write enable, this allows easy implementation of read and write port
//   sizes 8, 16, 32, 64, 128, or 256 bits. (Maximum = 'DDR3 width * number of DDR3 * 8').
//
// - Smart 'DDR3 width * number of DDR3 * 8' bit cache with:
//   - Configurable cache stale/cache dump timer.
//   - Open page policy so that ports with shared priority reading or writing to the same
//     page will first be executed before switching to a read or write on a new ram page.
//   - Configurable smart write req directly into existing read port data cache if the two memory address matches.
//
// - Asynchronous priority-boost control which allow you do dynamically force a
//   port with a low priority to be given the next available DDR3 memory access cycle,
//   even after an existing read or write req has already been entered into the queue.
//   (IE: A low priority streaming audio port's FIFO has just become almost empty, override the existing
//        queues of memory access reqs and make the next available ram cycle execute the priority-boosted port.)
//
// - 2 command input FIFO for each port.
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

module BrianHG_DDR3_COMMANDER #(

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
// ****************  BrianHG_DDR3_COMMANDER configuration parameter settings.
parameter int        PORT_R_TOTAL            = 16,               // Set the total number of DDR3 controller read ports, 1 to 16 max.
parameter int        PORT_W_TOTAL            = 16,               // Set the total number of DDR3 controller write ports, 1 to 16 max.
parameter int        PORT_VECTOR_SIZE        = 32,               // Sets the width of each port's VECTOR input and output.

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
                                                            // 0=8 level deep.  1=16 level deep.
                                                            // The size of the number of read commands built up in advance while the read channel waits
                                                            // for the DDR3_PHY_SEQ to return the read request data.
                                                            // Multiple reads must be accumulated to allow an efficient continuous read burst.
                                                            // IE: Use 8 level deep when running a small data port width like 8 or 16 so sequential read cache
                                                            // hits continue through the command input allowing cache miss read req later-on in the req stream to be
                                                            // immediately be sent to the DDR3_PHY_SEQ before the DDR3 even returns the first read req data.

parameter bit [8:0]  PORT_W_CACHE_TOUT    [0:15] = '{ 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64},
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
// ****************************************
// System clock and reset input
// ****************************************
input                 RST_IN,                     // Resets the controller and re-starts the DDR3 ram.
input                 CMD_CLK,                    // Must be the CMD_CLK     command clock frequency.

// ****************************************
// DDR3 commander interface.
// ****************************************
output logic                         CMD_R_busy          [0:PORT_R_TOTAL-1],  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.
output logic                         CMD_W_busy          [0:PORT_W_TOTAL-1],  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.

input                                CMD_write_req       [0:PORT_W_TOTAL-1],  // Write request for each port.

input        [PORT_ADDR_SIZE-1:0]    CMD_waddr           [0:PORT_W_TOTAL-1],  // Address pointer for each write memory port.
input        [PORT_CACHE_BITS-1:0]   CMD_wdata           [0:PORT_W_TOTAL-1],  // During a 'CMD_write_req', this data will be written into the DDR3 at address 'CMD_addr'.
                                                                              // Each port's 'PORT_DATA_WIDTH' setting will prune the unused write data bits.
                                                                              // *** All channels of the 'CMD_wdata' will always be PORT_CACHE_BITS wide, however,
                                                                              // only the bottom 'PORT_W_DATA_WIDTH' bits will be active.

input        [PORT_CACHE_BITS/8-1:0] CMD_wmask           [0:PORT_W_TOTAL-1],  // Write mask for the individual bytes within the 256 bit data bus.
                                                                              // When low, the associated byte will not be written.
                                                                              // Each port's 'PORT_DATA_WIDTH' setting will prune the unused mask bits.
                                                                              // *** All channels of the 'CMD_wmask' will always be 'PORT_CACHE_BITS/8' wide, however,
                                                                              // only the bottom 'PORT_W_DATA_WIDTH/8' bits will be active.

input        [PORT_ADDR_SIZE-1:0]    CMD_raddr           [0:PORT_R_TOTAL-1],  // Address pointer for each read memory port.
input                                CMD_read_req        [0:PORT_R_TOTAL-1],  // Performs a read request for each port.
input        [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_in  [0:PORT_R_TOTAL-1],  // The contents of the 'CMD_read_vector_in' during a 'CMD_read_req' will be sent to the
                                                                              // 'CMD_read_vector_out' in parallel with the 'CMD_read_data' during the 'CMD_read_ready' pulse.
                                                                              // *** All channels of the 'CMD_read_vector_in' will always be 'PORT_VECTOR_SIZE' wide,
                                                                              // it is up to the user to '0' the unused input bits on each individual channel.

output logic                         CMD_read_ready      [0:PORT_R_TOTAL-1],  // Goes high for 1 clock when the read command data is valid.
output logic [PORT_CACHE_BITS-1:0]   CMD_read_data       [0:PORT_R_TOTAL-1],  // Valid read data when 'CMD_read_ready' is high.
                                                                 // *** All channels of the 'CMD_read_data will' always be 'PORT_CACHE_BITS' wide, however,
                                                                 // only the bottom 'PORT_R_DATA_WIDTH' bits will be active.

output logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_out [0:PORT_R_TOTAL-1],  // Returns the 'CMD_read_vector_in' which was sampled during the 'CMD_read_req' in parallel
                                                                 // with the 'CMD_read_data'.  This allows for multiple post reads where the output
                                                                 // has a destination pointer.
output logic [PORT_ADDR_SIZE-1:0]    CMD_read_addr_out   [0:PORT_R_TOTAL-1],  // A return of the address which was sent in with the read request.


input                               CMD_R_priority_boost [0:PORT_R_TOTAL-1],  // Boosts the port's 'PORT_R_PRIORITY' parameter by a weight of 8 when set.
input                               CMD_W_priority_boost [0:PORT_W_TOTAL-1],  // Boosts the port's 'PORT_W_PRIORITY' parameter by a weight of 8 when set.

// ************************************************************
// *** Controls are received from the BrianHG_DDR3_PHY_SEQ. ***
// ************************************************************
input                                SEQ_CAL_PASS        ,    // Goes low after a reset, goes high if the read calibration passes.
input                                DDR3_READY          ,    // Goes low after a reset, goes high when the DDR3 is ready to go.

input                                SEQ_BUSY_t          ,    // Commands will only be accepted when this output is equal to the SEQ_CMD_ENA_t toggle input.
input                                SEQ_RDATA_RDY_t     ,    // (*** WARNING: THIS IS A TOGGLE OUTPUT! ***) This output will toggle from low to high or high to low once new read data is valid.
input        [PORT_CACHE_BITS-1:0]   SEQ_RDATA           ,    // 256 bit date read from ram, valid when SEQ_RDATA_RDY_t goes high.
input        [DDR3_VECTOR_SIZE-1:0]  SEQ_RDVEC_FROM_DDR3 ,    // A copy of the 'SEQ_RDVEC_FROM_DDR3' input during the read request.  Valid when SEQ_RDATA_RDY_t goes high.

// ******************************************************
// *** Controls are sent to the BrianHG_DDR3_PHY_SEQ. ***
// ******************************************************
(*preserve*) output logic                         SEQ_CMD_ENA_t      = 0,  // (*** WARNING: THIS IS A TOGGLE CONTROL! *** ) Begin a read or write once this input toggles state from high to low, or low to high.
(*preserve*) output logic                         SEQ_WRITE_ENA      = 0,  // When high, a 256 bit write will be done, when low, a 256 bit read will be done.
(*preserve*) output logic [PORT_ADDR_SIZE-1:0]    SEQ_ADDR           = 0,  // Address of read and write.  Note that ADDR[4:0] are supposed to be hard wired to 0 or low, otherwise the bytes in the 256 bit word will be sorted incorrectly.
(*preserve*) output logic [PORT_CACHE_BITS-1:0]   SEQ_WDATA          = 0,  // write data.
(*preserve*) output logic [PORT_CACHE_BITS/8-1:0] SEQ_WMASK          = 0,  // write data mask.
(*preserve*) output logic [DDR3_VECTOR_SIZE-1:0]  SEQ_RDVEC_TO_DDR3  = 0,  // Read destination vector input.
(*preserve*) output logic                         SEQ_refresh_hold   = 0   // Prevent refresh.  Warning, if held too long, the SEQ_refresh_queue will max out.
);

// **********************************************
// ***  Unknown BANK_ROW_ORDER *****************
// **********************************************
generate
         if (BANK_ROW_ORDER!="ROW_BANK_COL" && BANK_ROW_ORDER!="BANK_ROW_COL") initial begin
$warning("********************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ PARAMETER ERROR ***");
$warning("****************************************************************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ parameter .BANK_ROW_ORDER(\"%s\") is not supported. ***",BANK_ROW_ORDER);
$warning("*** Only \"ROW_BANK_COL\" or \"BANK_ROW_COL\" are supported.                             ***");
$warning("****************************************************************************************");
$error;
$stop;
end
endgenerate

// These localparams set the bottom bit position in the entire address space where the BANK# and ROW# begins depending on the BANK_ROW_ORDER setting.
localparam int  BANK_BP = PORT_ADDR_SIZE - DDR3_WIDTH_BANK - (DDR3_WIDTH_ADDR*(BANK_ROW_ORDER=="ROW_BANK_COL")) ;
localparam int  ROW_BP  = PORT_ADDR_SIZE - DDR3_WIDTH_ADDR - (DDR3_WIDTH_BANK*(BANK_ROW_ORDER=="BANK_ROW_COL")) ;

// This register stores what each DDR3 BANK# is most likely activated with which ROW#
logic [DDR3_WIDTH_ADDR-1:0]   act_bank_row       [0:(1<<DDR3_WIDTH_BANK)-1] ; // Used to store which activated ROW# is in each BANK# to improve multiport
                                                                              // sequence selection order to eliminate precharge-activate command delays
                                                                              // whenever possible.


logic [PORT_CACHE_BITS-1:0]   enc_wdata          [0:PORT_W_TOTAL-1];  // This logic passes the wdata between the input bit-width encoder and the input command FIFO.
logic [PORT_CACHE_BITS/8-1:0] enc_wmask          [0:PORT_W_TOTAL-1];  // This logic passes the wmask between the input bit-width encoder and the input command FIFO.

// These logic registers are the connections between the command FIFO output ports and the priority DDR3 command selection
logic                         read_req           [0:PORT_R_TOTAL-1];  // The data presented at the output of the read req command FIFO is ready and valid
logic                         read_req_ack       [0:PORT_R_TOTAL-1];  // Acknowledge the read command FIFO's data, advance or wait for the next command.
logic                         CMD_R_busy_fifo    [0:PORT_R_TOTAL-1];  // Read command FIFO's full flag.
logic [PORT_ADDR_SIZE-1:0]    FIFO_raddr_req     [0:PORT_R_TOTAL-1];  // CMD FIFO output read address pointer.
logic [PORT_VECTOR_SIZE-1:0]  FIFO_rvi_req       [0:PORT_R_TOTAL-1];  // CMD FIFO output read vector pointer.
logic [PORT_ADDR_SIZE-1:0]    FIFO_raddr_out     [0:PORT_R_TOTAL-1];  // Intermediate stage 2 CMD FIFO output read address pointer.
logic [PORT_VECTOR_SIZE-1:0]  FIFO_rvi_out       [0:PORT_R_TOTAL-1];  // Intermediate stage 2 CMD FIFO output read vector pointer.

logic                         write_req          [0:PORT_W_TOTAL-1];  // The data presented at the output of the read req command FIFO is ready and valid
logic                         write_req_ack      [0:PORT_W_TOTAL-1];  // Acknowledge the read command FIFO's data, advance or wait for the next command.
logic [PORT_ADDR_SIZE-1:0]    FIFO_waddr         [0:PORT_W_TOTAL-1];  // CMD FIFO output read address pointer.
logic [PORT_CACHE_BITS-1:0]   FIFO_wdata         [0:PORT_W_TOTAL-1];  // CMD FIFO output read address pointer.
logic [PORT_CACHE_BITS/8-1:0] FIFO_wmask         [0:PORT_W_TOTAL-1];  // CMD FIFO output read address pointer.

// These logic registers are the read and write cache controls.

logic [15:0]                  WC_ddr3_write_req = 0 ;                 // A logic word containing all the current required DDR3 write reqs.
//logic [PORT_W_TOTAL-1:0]      WC_ddr3_ack       ;                     // Acknowledge pulse from DDR3 controller when there is a write.
logic [8:0]                   WC_tout            [0:PORT_W_TOTAL-1];  // Write Cache 8 bit + sign timeout to a write req.
logic                         WC_ready           [0:PORT_W_TOTAL-1];  // Write Cache ready to write if WB_tout[8] is set.  This bit clears when a write is sent to the DDR3 Controller.
logic [PORT_ADDR_SIZE-1:0]    WC_waddr           [0:PORT_W_TOTAL-1];  // Write Cache write address.
logic [PORT_CACHE_BITS-1:0]   WC_wdata           [0:PORT_W_TOTAL-1];  // Write Cache write data.
logic [PORT_CACHE_BITS/8-1:0] WC_wmask           [0:PORT_W_TOTAL-1];  // Write Cache write data byte mask.

logic [8:0]                   WC_burst_limit    ;                     // A countdown timer for limiting consecutive bursts within 1 port.
logic                         WC_cache_hit       [0:PORT_W_TOTAL-1];  // Goes valid when the next write is within the same cache word.
logic [0:PORT_W_TOTAL-1]      WC_page_hit                          ;  // Goes valid when the next write is within the same DDR3 column, IE the same row,
                                                                      // use to adjust port sequence priority to sequentially coalesce / burst writes.

logic [15:0]                  RC_ddr3_read_req   = 0 ;                  // A logic word containing all the current required DDR3 read reqs.
logic [0:PORT_R_TOTAL-1]      read_cache_adr_req   ;                  // Intermediate read channel command FIFO holding a copy of the
logic [0:PORT_R_TOTAL-1]      read_cache_adr_ack   ;                  // read req after it has been sent to the DDR3_PHY_SEQ waiting
logic [0:PORT_R_TOTAL-1]      read_cache_adr_ready ;                  // for a response.
logic [0:PORT_R_TOTAL-1]      read_cache_adr_full  ;                  // 
logic [0:PORT_R_TOTAL-1]      RC_ddr3_busy         ;                  // Signifies a read is in progress.
logic                         RC_ready           [0:PORT_R_TOTAL-1];  // Read Cache address valid.
logic [PORT_ADDR_SIZE-1:0]    RC_raddr           [0:PORT_R_TOTAL-1];  // Read cache read address pointer.
logic [PORT_ADDR_SIZE-1:0]    RC_ddr3_raddr      [0:PORT_R_TOTAL-1];  // Read cache read address pointer.
logic                         RC_read_ready      [0:PORT_R_TOTAL-1];
logic [PORT_CACHE_BITS-1:0]   RC_read_data       [0:PORT_R_TOTAL-1];
logic [8:0]                   RC_burst_limit   ;                      // A countdown timer for limiting consecutive bursts within 1 port.
logic                         RC_cache_hit       [0:PORT_R_TOTAL-1];  // Goes valid when the next read is within the same cache word and the cache is valid.
logic                         RC_cache_ddr3_req  [0:PORT_R_TOTAL-1];  // Goes valid when the next read not yest ready, but the read command has been sent to the DDR3.
logic                         RC_WC_cache_hit    [0:PORT_R_TOTAL-1];  // Goes valid when the next DDR3 read return is within the same cache address as the current write cache word.
logic                         WC_RC_cache_hit    [0:PORT_R_TOTAL-1];  // Goes valid when the next write is within the same cache address of the current read cache.
logic [0:PORT_R_TOTAL-1]      RC_page_hit                          ;  // Goes valid when the next read is within the same DDR3 column, IE the same row,
                                                                      // use to adjust port sequence priority to sequentially coalesce / burst reads.

logic       last_req_write, any_write_req, any_read_req ;         // Single Regs / Flags.
logic [3:0] write_req_sel, read_req_sel,last_read_req_chan,last_write_req_chan; // Selection for which channel is next to read and write and which was last done
logic [3:0] RC_cs,WC_cs;

logic       RC_break,WC_break;
logic       DDR3_read_req, DDR3_write_req;                                      // Flags which identify that a DDR3 command will be required on the next clock.

logic       last_rdata_rdy  = 0  ;                                              // The DDR3_PHY_SEQ SEQ_RDATA_RDY_t output is a toggle, so we need to track it's change.
logic       SEQ_RDATA_RDY,SEQ_BUSY,SEQ_READY;                                   // TEMPOARY until the toggle system is changed to standard active logic.
logic [15:0] RC_boost=0,WC_boost=0,RC_boost_hit=0,WC_boost_hit=0,read_preq=0,write_preq=0;
logic        any_boost;

(*preserve*) logic reset_latch,reset_latch2;

// ****************************************************************************************************************************
// Generate all the required read data bus width conversion logic.
// ****************************************************************************************************************************
genvar x;
generate
    for (x=0 ; x<=(PORT_R_TOTAL-1) ; x=x+1) begin : DDR3_CMD_DECODE_BYTE_inst
        DDR3_CMD_DECODE_BYTE #(

         .addr_size        ( PORT_ADDR_SIZE       ),    // sets the width of the address input.
         .input_width      ( PORT_CACHE_BITS      ),    // Sets the width of the input data.
         .output_width     ( PORT_R_DATA_WIDTH[x] )     // Sets the width of the output data.

) DDR3_CMD_DECODE_BYTE_inst (
         .addr             ( FIFO_raddr_out[x]    ),
         .data_in          ( RC_read_data[x]      ),
         .data_out         ( CMD_read_data[x]     ) );
    end
endgenerate

// ****************************************************************************************************************************
// Generate all the required write data bus width conversion logic.
// ****************************************************************************************************************************
generate
    for (x=0 ; x<=(PORT_W_TOTAL-1) ; x=x+1) begin : DDR3_CMD_ENCODE_BYTE_inst
        DDR3_CMD_ENCODE_BYTE #(

         .addr_size        ( PORT_ADDR_SIZE       ),    // sets the width of the address input.
         .input_width      ( PORT_W_DATA_WIDTH[x] ),    // Sets the width of the input data.
         .output_width     ( PORT_CACHE_BITS      )     // Sets the width of the output data.

) DDR3_CMD_ENCODE_BYTE_inst (
         .addr             ( CMD_waddr[x]         ),
         .data_in          ( CMD_wdata[x]         ),
         .mask_in          ( CMD_wmask[x]         ),
         .data_out         ( enc_wdata[x]         ),
         .mask_out         ( enc_wmask[x]         ) );
    end
endgenerate

// ****************************************************************************************************************************
// Generate all the required primary Read Request input CMD FIFOs
// ****************************************************************************************************************************
generate
    for (x=0 ; x<=(PORT_R_TOTAL-1) ; x=x+1) begin : DDR3_CMD_FIFO_Rp_inst
        BHG_FIFO_shifter_FWFT #(
        .bits            ( PORT_ADDR_SIZE + PORT_VECTOR_SIZE ),                 // The width of the FIFO's data_in and data_out ports.
        .words           ( 3                                 ),
        .spare_words     ( 1                                 )                  // The number of spare words before being truly full.

) DDR3_CMD_FIFO_Rp_inst (
         .clk            ( CMD_CLK                               ),
         .reset          ( reset_latch                           ),

         .shift_in       ( CMD_read_req[x]                       ),
         .shift_out      ( read_req_ack[x]                       ),
         .data_in        ( {CMD_raddr[x], CMD_read_vector_in[x]} ),

         .data_ready     ( read_req[x]                           ),
         .full           ( CMD_R_busy_fifo[x]                    ),

         .data_out       ( {FIFO_raddr_req[x],FIFO_rvi_req[x]}   ));
    end
endgenerate
// ****************************************************************************************************************************
// Generate all the required intermediate secondary Read request stack delay FIFOs for DDR3 read request delay.
// ****************************************************************************************************************************
generate
    for (x=0 ; x<=(PORT_R_TOTAL-1) ; x=x+1) begin : DDR3_CMD_FIFO_Rs_inst
        BHG_FIFO_shifter_FWFT #(
        .bits              ( PORT_ADDR_SIZE + PORT_VECTOR_SIZE ),              // The width of the FIFO's data_in and data_out ports.
        .words             ( (PORT_R_CMD_STACK[x]+1)*8         ),              // Select 4 word or 8 word FIFO.
        .spare_words       ( 1                                 )                  // The number of spare words before being truly full.

) DDR3_CMD_FIFO_Rs_inst (
         .clk              ( CMD_CLK                               ),
         .reset            ( reset_latch                           ),

         .shift_in         ( read_cache_adr_req[x]                 ),
         .shift_out        ( read_cache_adr_ack[x]                 ),
         .data_in          ( {FIFO_raddr_req[x], FIFO_rvi_req[x]}  ),

         .data_ready       ( read_cache_adr_ready[x]               ),
         .full             ( read_cache_adr_full[x]                ),

         .data_out         ( {FIFO_raddr_out[x], FIFO_rvi_out[x]}  ));
         
         //assign read_cache_adr_full[x] = 0 ;
    end
endgenerate

// ****************************************************************************************************************************
// Generate all the required Write Request input CMD FIFOs
// ****************************************************************************************************************************
generate
    for (x=0 ; x<=(PORT_W_TOTAL-1) ; x=x+1) begin : DDR3_CMD_FIFO_W_in_inst
        BHG_FIFO_shifter_FWFT #(
        .bits            ( PORT_ADDR_SIZE + PORT_CACHE_BITS + (PORT_CACHE_BITS/8) ), // The width of the FIFO's data_in and data_out ports.
        .words           ( 3                                                      ),
        .spare_words     ( 1                                                      )  // The number of spare words before being truly full.

) DDR3_CMD_FIFO_W_in_inst (
         .clk            ( CMD_CLK                                     ),
         .reset          ( reset_latch                                 ),

         .shift_in       ( CMD_write_req[x]                            ),
         .shift_out      ( write_req_ack[x]                            ),
         .data_in        ( {CMD_waddr[x], enc_wdata[x], enc_wmask[x]}  ),

         .data_ready     ( write_req[x]                                ),
         .full           ( CMD_W_busy[x]                               ),

         .data_out       ( {FIFO_waddr[x],FIFO_wdata[x],FIFO_wmask[x]} ));
    end
endgenerate


// **************************************************************************************************************************
// Priority Encoder Logic: (Combinational logic)
// This section is a priority encoder to select which read or write to sent to the DDR3_PHY_SEQ next.
// It looks at the contents of the input Read and Write request FIFOs, checks what command has previously been sent
// to the DDR3_PHY_SEQ, and based on the status of the priority parameters and timeouts, it will set the appropriate
// flags for the next always_ff section to pass the next command to the DDR3_PHY_SEQ.
// **************************************************************************************************************************
always_comb begin
// **************************************************************************************************************************
// Combinational Read Request Flag Generation Logic: (1 of 6)
// Establish all the metrics of all the source read channel command input FIFOs.
// **************************************************************************************************************************
for (int i=0 ; i<PORT_R_TOTAL ; i ++ ) begin

    // Copy the boost input channel to a 16 bit logic integer.
    RC_boost[i] = CMD_R_priority_boost[i] ;

    // Make a flag which identifies if the next FIFO queued read command address is within the current read cache's address.
    // Used to bypass any unnecessary read requests to the DDR3.
    RC_cache_hit[i]      = ( RC_raddr     [i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] == FIFO_raddr_out[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] ) && RC_ready[i] ;

    // Make a flag which acknowledges when a read command has been submitted to the DDR3_PHY_SEQ.
    RC_cache_ddr3_req[i] = ( RC_ddr3_raddr[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] == FIFO_raddr_req[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] ) && RC_ddr3_busy[i];

    // Make a flag which identifies if the next FIFO queued read command address is within the same DDR3 row as the previous DDR3's accessed address.
    // Used to raise the priority of the current read channel so that sequential reads bursts within the same row address get coalesced together.
    // The page hit flag is disabled if the burst limit has been reached.
    // Check within each BANK's stored row when SMART_BANK is set, otherwise just use the last DDR3's accessed ROW+BANK.
    if ( SMART_BANK) RC_page_hit[i] = ( act_bank_row[FIFO_raddr_req[i][BANK_BP+:DDR3_WIDTH_BANK]] == FIFO_raddr_req[i][ROW_BP+:DDR3_WIDTH_ADDR]         ) && !RC_burst_limit[8];
    else             RC_page_hit[i] = ( SEQ_ADDR[PORT_ADDR_SIZE-1:CACHE_ROW_BASE]                 == FIFO_raddr_req[i][PORT_ADDR_SIZE-1:CACHE_ROW_BASE] ) && !RC_burst_limit[8];


    // Make a flag which identifies if the current read read req command address is within the current WRITE cache's address
    // so that the appropriate portions of the read data are taken from the write cache instead of the read cache data.  Only valid if the CACHE_SMART parameter is enabled.
    if (i<PORT_W_TOTAL)  RC_WC_cache_hit[i]   = ( WC_waddr[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] == RC_raddr[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] ) && WC_ready[i] && PORT_CACHE_SMART[i] ;
    else                 RC_WC_cache_hit[i]   = 0 ;

    // Make a flag which identifies if the current write command cache address is within the current DDR3 read data ready address.
    // Used to replace the DDR3 read data with the appropriate portions of the write cache data.  Only valid if the CACHE_SMART parameter is enabled.
    if (i<PORT_W_TOTAL)  WC_RC_cache_hit[i]   = ( SEQ_RDVEC_FROM_DDR3[PORT_ADDR_SIZE+3:CACHE_ADDR_WIDTH+4] == WC_waddr[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] ) && WC_ready[i] && PORT_CACHE_SMART[i] ;
    else                 WC_RC_cache_hit[i]   = 0 ;

    // Coalesces all the required DDR3 read requests into a single logic word, only if the second stage read command cache is not full.
    RC_ddr3_read_req[i]  = (read_req[i] && !RC_cache_ddr3_req[i] && !read_cache_adr_full[i] );

end // for i


// **************************************************************************************************************************
// Combinational Write Request Flag Generation Logic: (2 of 6)
// Establish all the metrics of all the source write channel command input FIFOs.
// **************************************************************************************************************************
for (int i=0 ; i<PORT_W_TOTAL ; i ++ ) begin  // This write cache management is identical for all the write req channels.

    // Copy the boost input channel to a 16 bit logic integer.
    WC_boost[i] = CMD_W_priority_boost[i] ;

    // Make a flag which identifies if the next FIFO queued write command address is within the current write cache's address.
    // Used to coalesce multiple writes within the cache space before an actual write requests is sent to the DDR3.
    WC_cache_hit[i]      = ( WC_waddr[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] == FIFO_waddr[i][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] );

    // Make a flag which identifies if the next FIFO queued command write address is within the same DDR3 row as the previous DDR3's accessed address.
    // Used to raise the priority of the current write channel so that sequential write bursts within the same row address get coalesced together.
    // The page hit flag is disabled if the burst limit has been reached.
    // Check within each BANK's stored row when SMART_BANK is set, otherwise just use the last DDR3's accessed ROW+BANK.
    if ( SMART_BANK) WC_page_hit[i] = ( act_bank_row[WC_waddr[i][BANK_BP+:DDR3_WIDTH_BANK]] == WC_waddr[i][ROW_BP+:DDR3_WIDTH_ADDR]           ) && !WC_burst_limit[8];
    else             WC_page_hit[i] = ( SEQ_ADDR[PORT_ADDR_SIZE-1:CACHE_ROW_BASE]           == FIFO_waddr[i][PORT_ADDR_SIZE-1:CACHE_ROW_BASE] ) && !WC_burst_limit[8];

    // Coalesces all the required DDR3 write requests into a single logic word.
    WC_ddr3_write_req[i] = WC_ready[i] && ( WC_tout[i][8] || (!WC_cache_hit[i] && write_req[i]) ) ;

end // for i


// **************************************************************************************************************************
// Combinational Read or Write Request Priority Selection Logic: (3 of 6)
// Priority select which active read or write channel goes next based on CMD_R/W_priority_boost[x] input,
// PORT_R/W_PRIORITY[x] parameter, previous port access, same page/bank hit, and previous DDR3 read/write access.
//
// Scan for the top priority DDR3 R/W req, scanning the previous R/W req channel last unless
// that channel is in a sequential burst within the same row or has a priority boost,
// secondly further prioritize coalescing all the reads/writes in a row within the same bank/page.
//
// Priority order scanned by int 'p':     MSB          .................................         LSB
//                                   (PRI_BOOST in)   (PORT_PRIORITY param)   (PAGE_HIT)    (COALESC reads<>writes)
//
// **************************************************************************************************************************
// Generate a flag which will show if any boosted request are available.
RC_boost_hit   = (RC_boost & RC_ddr3_read_req);
// Generate a flag which will show if any boosted request are available.
WC_boost_hit   = (WC_boost & WC_ddr3_write_req);

any_boost      = (WC_boost_hit !=0) || (RC_boost_hit !=0) ;             // Make a flag which indicates that a boosted request exists.
read_preq      = (any_boost ? RC_boost_hit:RC_ddr3_read_req)  ;         // Filter select between boosted ports and no boosted ports.
write_preq     = (any_boost ? WC_boost_hit:WC_ddr3_write_req) ;         // Filter select between boosted ports and no boosted ports.

any_read_req   = (read_preq  != 0) ;  // Go high if there are any DDR3 reads required.
any_write_req  = (write_preq != 0) ;  // Go high if there are any DDR3 writes required.

// Scan inputs:    

    read_req_sel = 0 ;
    RC_break     = 0 ;
    for (int p=15 ; p>=0 ; p-- ) begin                         // 'p' scans in order of highest priority to lowest.
        for (int i=1 ; i<17 ; i++ ) begin                      // 'i' scans channels 0-15.
    
        // round robin arbiter priority selection, ensure the previous accessed R/W channel of equal priority is considered last before
        // access is granted once again.
        RC_cs  = 4'(4'(i) + last_read_req_chan ) ;             // RC_cs begins the scan at 'i' + the last read channel + 1

            if ( RC_cs<PORT_R_TOTAL && !RC_break ) begin       // Only scan from the available read ports.

                // Add 1/2 to the read port's priority weight if the page_hit is true.
                if ( read_preq[RC_cs] && ( {PORT_R_PRIORITY[RC_cs],RC_page_hit[RC_cs]} == p[3:0] ) ) begin
                                                                            read_req_sel   = RC_cs;  // If there is a DDR3 read_req hit with port priority 'p', set that read channel
                                                                            RC_break       = 1 ;     // and ignore the rest of the scan loop.
                                                                            end
            end

        end // for i
    end // for p

    write_req_sel = 0 ;
    WC_break      = 0 ;
    for (int p=15 ; p>=0 ; p-- ) begin                         // 'p' scans in order of highest priority to lowest.
        for (int i=1 ; i<17 ; i++ ) begin                      // 'i' scans channels 0-15.

        // round robin arbiter priority selection, ensure the previous accessed R/W channel of equal priority is considered last before
        // access is granted once again.
        WC_cs  = 4'(4'(i) + last_write_req_chan) ;             // WC_cs begins the scan at 'i' + the last write channel + 1

            if ( WC_cs<PORT_W_TOTAL && !WC_break ) begin       // Only scan from the available write ports. 

                // Add 1/2 to the write port's priority weight if the page_hit is true.
                if ( write_preq[WC_cs] && ( {PORT_W_PRIORITY[WC_cs],WC_page_hit[WC_cs]} == p[3:0] ) ) begin
                                                                            write_req_sel    = WC_cs;  // If there is a DDR3 write_req hit with port priority 'p', set that write channel
                                                                            WC_break         = 1 ;     // and ignore the rest of the scan loop.
                                                                            end
            end

        end // for i
    end // for p



// **************************************************************************************************************************
// Combinational read and write selection for DDR3_PHY_SEQ: (4 of 6)
// Generate the DDR3 busy and ready flags.
// **************************************************************************************************************************
SEQ_RDATA_RDY = ( SEQ_RDATA_RDY_t != last_rdata_rdy );        // Decode the 'SEQ_RDATA_RDY' from the toggle version input.
SEQ_BUSY      = ( SEQ_BUSY_t      != SEQ_CMD_ENA_t  );        // Decode the 'SEQ_BUSY' from the toggle version input.
SEQ_READY     = ( DDR3_READY      && !SEQ_BUSY      ) ; // High when a command is allowed to be sent to the DDR3_PHY_SEQ.

    if (SEQ_READY)                                      begin  // Make sure the DDR3 sequencer is ready to accept a command.

                     if (any_read_req && any_write_req && (PORT_W_PRIORITY[write_req_sel] > PORT_R_PRIORITY[read_req_sel]) ) begin
                     // There is a read and write, but, the write port's priority is higher than the read's.
                                                        DDR3_read_req  = 0;
                                                        DDR3_write_req = 1;

            end else if (any_read_req && any_write_req && (PORT_W_PRIORITY[write_req_sel] < PORT_R_PRIORITY[read_req_sel]) ) begin
                     // There is a read and write, but, the read port's priority is higher than the write's.
                                                        DDR3_read_req  = 1;
                                                        DDR3_write_req = 0;

            end else if (any_read_req  && !(last_req_write && any_write_req) )  begin
            // If there is a read req while there currently isn't a write req && the last command was a write, and the port priorities are equal.
            // This coalesces a number of consecutive reads before allowing a write, or, coalesce a number of consecutive writes before allowing a read.
            // This minimizes the read-write (RL + tCCD + 2tCK - WL) delay or write-read (tWTR) delays.
                                                        DDR3_read_req  = 1;
                                                        DDR3_write_req = 0;

            end else if (any_write_req )                                    begin  // If there is no valid read condition and there is a write req.

                                                        DDR3_read_req  = 0;
                                                        DDR3_write_req = 1;

            end else                                                        begin  // No DDR3 access required.
        
                                                        DDR3_read_req  = 0;
                                                        DDR3_write_req = 0;
            end
        
    end else begin // DDR3_PHY_SEQ isn't ready for a command.

                                                        DDR3_read_req  = 0;
                                                        DDR3_write_req = 0;
    end


// **************************************************************************************************************************
// Combinational Write Request FIFO ack output and output data ready flags: (5 of 6)
// **************************************************************************************************************************

for (int i=0 ; i<PORT_W_TOTAL ; i ++ ) begin 

    // Advance the write FIFO if there is a FIFO write req to an empty cache or cache hit, but never
    // while an existing cache & the DDR3 write command output FIFO is not full.
    write_req_ack[i]     = ( write_req[i] && ( (!WC_ready[i] || WC_cache_hit[i]) || (DDR3_write_req && write_req_sel==4'(i) && WC_ready[i] ) ) );

end // for i


// **************************************************************************************************************************
// Combinational Read Request FIFO ack output and output data ready flags: (6 of 6)
// **************************************************************************************************************************
for (int i=0 ; i<PORT_R_TOTAL ; i ++ ) begin

    // Advance the read FIFO.  No advance should be allowed if the second stage read command cache is full.
    read_req_ack[i]       = (read_req[i] && !read_cache_adr_full[i]) && ( RC_cache_ddr3_req[i] || (SEQ_READY && DDR3_read_req && read_req_sel==4'(i)) ) ;
    read_cache_adr_req[i] = (read_req[i] && !read_cache_adr_full[i]) && ( RC_cache_ddr3_req[i] || (SEQ_READY && DDR3_read_req && read_req_sel==4'(i)) ) ;

    // Output a read ready pulse on the CMD/RC_read_ready[] port when DDR3_PHY read is done or a read cache hit occurs and advance the second stage FIFO.
    RC_read_ready[i]      = RC_cache_hit[i] && read_cache_adr_ready[i] ;
    read_cache_adr_ack[i] = RC_cache_hit[i] && read_cache_adr_ready[i] ;

end // for i

// **************************************************************************************************************************
// Pass through the read to the output.  This will soon go through the byte selector.
for (int i=0 ; i<PORT_R_TOTAL ; i ++ ) begin     // Temporary assign RC - read cache to the read output pins
    CMD_read_ready[i]      = RC_read_ready[i]  ; // Data ready pulse
    //CMD_read_data[i]       = RC_read_data[i]   ; // Full width data.  ********************  THIS WORD IS FED THROUGH THE BYTE DECODER.
    CMD_read_vector_out[i] = FIFO_rvi_out[i]   ; // Returned read vector.
    CMD_read_addr_out[i]   = FIFO_raddr_out[i] ; // Address sent with the read request.

    CMD_R_busy[i]          = CMD_R_busy_fifo[i] ;// || read_cache_adr_full[i] ;
end
// **************************************************************************************************************************


end // always_comb
// **************************************************************************************************************************
// Synchronous Logic:
// **************************************************************************************************************************
always_ff @(posedge CMD_CLK) begin

                    //SEQ_WDATA                                   <= WC_wdata[write_req_sel]  ;                                   // Send the write data.
                    //SEQ_WMASK                                   <= WC_wmask[write_req_sel]  ;                                   // Send the write byte mask.

                    //SEQ_RDVEC_TO_DDR3                           <= {FIFO_raddr_req[read_req_sel],4'(read_req_sel)} ; // Defines the destination of the source read data channel
                                                                                                                     // in the DDR3_PHY_SEQ's returned read vector which comes with the read data.

reset_latch  <= (RST_IN || !DDR3_READY);
reset_latch2 <= reset_latch ;
// **************************************************************************************************************************
// Reset Management:  (1 of 4)
// **************************************************************************************************************************
if (reset_latch2) begin  // Reset everything to a known state.

    for (int i=0 ; i<(1<<DDR3_WIDTH_BANK) ; i ++ ) act_bank_row[i] <= 0 ;

    for (int i=0 ; i<PORT_R_TOTAL ; i ++ ) begin
        RC_ready[i]            <= 0 ;
        RC_raddr[i]            <= 0 ;
        RC_read_data[i]        <= 0 ;
        RC_ddr3_raddr[i]       <= 0 ;
        end

    for (int i=0 ; i<PORT_W_TOTAL ; i ++ ) begin
        WC_ready[i]            <= 0  ;
        WC_waddr[i]            <= 0  ;
        WC_wdata[i]            <= 0  ;
        WC_wmask[i]            <= 0  ;
        WC_tout[i]             <= 9'(PORT_W_CACHE_TOUT[i]-1)  ;
//        WC_ddr3_ack[i]         <= 0 ;
        end

        last_rdata_rdy         <= last_rdata_rdy  ; // The DDR3_PHY_SEQ SEQ_RDATA_RDY_t output is a toggle, so we need to track it's change.
        last_req_write         <= 0  ; // state that we have performed a read.
        SEQ_CMD_ENA_t          <= 0  ; // Toggle the SEQ_CMD_ENA_t signifying a new command is present.  ***SEQ_CMD_ENA_t is a toggle.
        SEQ_WRITE_ENA          <= 0  ; // Select a read command.
        SEQ_ADDR               <= 0  ;
        SEQ_WDATA              <= 0  ;
        SEQ_WMASK              <= 0  ;
        SEQ_RDVEC_TO_DDR3      <= 0  ;
        SEQ_refresh_hold       <= 0  ;

        RC_ddr3_busy           <= 0 ;
        RC_burst_limit         <= 9'(PORT_R_MAX_BURST[0] - 1)  ;
        WC_burst_limit         <= 9'(PORT_W_MAX_BURST[0] - 1)  ;
        
        last_read_req_chan     <= 0 ;
        last_write_req_chan    <= 0 ;

end else begin


        if (SEQ_RDATA_RDY)  last_rdata_rdy <= SEQ_RDATA_RDY_t ; // Used to clear the transition detection of the toggle input 'SEQ_RDATA_RDY_t' from the DDR3_PHY_SEQ.

// **************************************************************************************************************************
// Write Cache Management:  (2 of 4)
// This section runs the write cache timer timeout.

// When the write cache is active and a new write comes in which is not inside the cache, allow a DDR3 write cycle when the DDR3 is ready simultaneously advancing
//      the next write contents into the write cache regardless of the WC_tout value.  *** Necessary to allow unbroken consecutive bursting when operating at 1/4x speed.
//
// Maintain WC_ready[i] accordingly.
//
// Every time a write req comes in, that port's timer will be reset to it's PORT_W_CACHE_TOUT.
// When there is no write req, that timeout is count down until it is equal to -1, meaning that block is ready to write.
// When a new write comes in at a block address not inside the current cache range, then the timer is forced to -1, meaning that the block is made ready to write
// immediately.  This either allows multiple writes into parts of the same cache block without sending and waiting for multiple write reqs to the DDR3_PHY_SEQ,
// or it automatically allows continuous immediate sequential writes to different addresses outside the current cache address.
// **************************************************************************************************************************
  for (int i=0 ; i<PORT_W_TOTAL ; i ++ ) begin  // This write cache management is identical for all the write req channels.

    if (write_req_ack[i]) begin

         WC_ready[i] <= 1 ;                              // State that the write cache has at least 1 filled word.
         WC_tout[i]  <= 9'(PORT_W_CACHE_TOUT[i]-1)  ;    // Set the cache timeout time, giving time to allow additional additional writes into the same address.
         WC_waddr[i] <= FIFO_waddr[i] ;                  // Fill the write cache address.

         for (int z=0 ; z<(PORT_CACHE_BITS/8) ; z ++ ) begin                                // Transfer only the individual 8 bit chunks which were masked on.

                if (FIFO_wmask[i][z]) WC_wdata[i][z*8 +:8] <= FIFO_wdata[i][z*8 +:8] ;
                if (!WC_cache_hit[i]) WC_wmask[i][z]       <= FIFO_wmask[i][z] ;                   // Clear and transfer only the active write enable mask bits as this is a new write.
                else                  WC_wmask[i][z]       <= FIFO_wmask[i][z] || WC_wmask[i][z] ; // In the case of separate multiple byte write to the same address before the cache timeout
                                                                                                   // has been reached, enable those masked bits while retaining previous write enable masked bits.
         end // For z loop

    end else begin
    
        if (!WC_tout[i][8])                            WC_tout[i]  <= 9'(WC_tout[i] - 1); // Count down to negative 1, IE 256...
        if (DDR3_write_req && (write_req_sel==4'(i)))  WC_ready[i] <= 0 ;               // Since there is no new write request and a DDR3 write has taken place, clear the cache write data ready flag.

    end

  end // For i loop

// **************************************************************************************************************************
// Read Data Ready Management:  (3 of 4)
// This section waits for the read results from the DDR3_PHY_SEQ.
// read data into the cache immediately.
// It will swap the read data with the write cache contents if the address match and the smart cache feature is enabled.
// **************************************************************************************************************************
for (int i=0 ; i<PORT_R_TOTAL ; i ++ ) begin

    if ( SEQ_RDATA_RDY && (SEQ_RDVEC_FROM_DDR3[3:0]==4'(i)) ) begin // A toggle in the rdata ready has been seen...

            for (int z=0 ; z<(PORT_CACHE_BITS/8) ; z ++ ) begin

                // Select between the DDR3 read data and the write data channel if there is a R-smart cache hit. 
                // If there is a smart cache hit, only use the individual 8 bit chunks which were masked on in the write channel.
                if (i<PORT_W_TOTAL) RC_read_data [i][z*8 +:8] <= (WC_RC_cache_hit[i] && WC_wmask[i][z]) ? WC_wdata[i][z*8 +:8] : SEQ_RDATA[z*8 +:8] ;
                else                RC_read_data [i][z*8 +:8] <= SEQ_RDATA[z*8 +:8] ;

            end // For z

                RC_raddr[i]               <= SEQ_RDVEC_FROM_DDR3[PORT_ADDR_SIZE+3:4] ;
                RC_ready[i]               <= 1                                       ; // Internally specify that the read data is now valid

    end else begin // No DDR3 read transaction.

            for (int z=0 ; z<(PORT_CACHE_BITS/8) ; z ++ ) begin

                // Update the current read data cache with the contents of the write data channel if there is a W-smart cache hit. 
                // If there is a smart cache hit, only use the individual 8 bit chunks which were masked on in the write channel.
                if (i<PORT_W_TOTAL) begin
                                    if (RC_WC_cache_hit[i] && WC_wmask[i][z]) RC_read_data [i][z*8 +:8] <=  WC_wdata[i][z*8 +:8] ;
                                    end

            end // For z
    end

end // For i...
// **************************************************************************************************************************
// **************************************************************************************************************************
// R/W DDR3_PHY_SEQ Command Out Transmitter:  (4 of 4)
// This section passes the priority selected requested read / write commands to the DDR3_PHY_SEQ.
// **************************************************************************************************************************
// **************************************************************************************************************************

                    if (DDR3_read_req) begin // Perform a read.

                    SEQ_ADDR[CACHE_ADDR_WIDTH-1:0]              <= 0  ;            // Send all 0 in the LSB of the address since the DDRQ_PHY_SEQ address points to 8 bit words no matter cache data bus width.
                    SEQ_ADDR[PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] <= FIFO_raddr_req[read_req_sel][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] ; // Send the selected read channel address bits to the DDR3_PHY_SEQ.  This address points above the cache width.
                    SEQ_WDATA                                   <= 0  ;
                    SEQ_WMASK                                   <= 0  ;

                    // Send the read vector data, combined with which channel the read data should end up going to, and
                    // the LSB address point used for addressing individual bytes within the multi-byte cache word.

                    SEQ_RDVEC_TO_DDR3                           <= {FIFO_raddr_req[read_req_sel],4'(read_req_sel)} ; // Defines the destination of the source read data channel
                                                                                                                     // in the DDR3_PHY_SEQ's returned read vector which comes with the read data.

                    SEQ_WRITE_ENA                               <= 0               ;  // Select a read command.
                    SEQ_CMD_ENA_t                               <= !SEQ_CMD_ENA_t  ;  // Toggle the SEQ_CMD_ENA_t signifying a new command is present.  ***SEQ_CMD_ENA_t is a toggle.
                    last_req_write                              <= 0               ;  // note that we have performed a read.

                    if (read_req_sel != last_read_req_chan ) RC_burst_limit <= 9'(PORT_R_MAX_BURST[read_req_sel] - 1) ; // If a different read channel is hit, reset the consecutive channel burst counter to it's new parameter limit.
                    else if (!RC_burst_limit[8])             RC_burst_limit <= 9'(RC_burst_limit -1) ;                  // If the same channel is consecutively read, count down the burst_limit counter until is reaches -1, IE 256.

                    last_read_req_chan                          <= read_req_sel    ; // note which channel was selected for a read.

                    // Store which BANK# will now be activated with which ROW address for smart page-hit port priority selection logic.
                    act_bank_row[FIFO_raddr_req[read_req_sel][BANK_BP+:DDR3_WIDTH_BANK]] <= FIFO_raddr_req[read_req_sel][ROW_BP+:DDR3_WIDTH_ADDR] ;

                    RC_ddr3_busy[read_req_sel]                  <= 1                    ;        // Signifies that the DDR3 read command has been received and we are waiting for a result.
                    RC_ddr3_raddr[read_req_sel]                 <= FIFO_raddr_req[read_req_sel]; // Tells which DDR3 command has been received.

                    //WC_ddr3_ack                                 <= (PORT_W_TOTAL)'(0) ;          // Clear every past acknowledge of a write command.

        end else if (DDR3_write_req ) begin // Perform a write

                    SEQ_ADDR[CACHE_ADDR_WIDTH-1:0]              <= 0  ;              // Send all 0 in the LSB of the address since the DDRQ_PHY_SEQ address points to 8 bit words no matter cache data bus width.
                    SEQ_ADDR[PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] <= WC_waddr[write_req_sel][PORT_ADDR_SIZE-1:CACHE_ADDR_WIDTH] ; // Send the selected write channel address bits to the DDR3_PHY_SEQ.  This address points above the cache width.
                    SEQ_WDATA                                   <= WC_wdata[write_req_sel]  ;                                   // Send the write data.
                    SEQ_WMASK                                   <= WC_wmask[write_req_sel]  ;                                   // Send the write byte mask.
                    SEQ_RDVEC_TO_DDR3                           <= 0  ;

                    SEQ_WRITE_ENA                               <= 1                ; // Select a write command.
                    SEQ_CMD_ENA_t                               <= !SEQ_CMD_ENA_t   ; // Toggle the SEQ_CMD_ENA_t signifying a new command is present.  ***SEQ_CMD_ENA_t is a toggle.
                    last_req_write                              <= 1                ; // note that we have performed a write.
                    
                    if (write_req_sel != last_write_req_chan ) WC_burst_limit <= 9'(PORT_W_MAX_BURST[write_req_sel] - 1) ; // If a different write channel is hit, reset the consecutive channel burst counter to it's new parameter limit.
                    else if (!WC_burst_limit[8])               WC_burst_limit <= 9'(WC_burst_limit -1) ;                   // If the same channel has consecutive writes, count down the burst_limit counter until is reaches -1, IE 256.
                    
                    last_write_req_chan                         <= write_req_sel    ; // note which channel was selected for a read.

                    // Store which BANK# will now be activated with which ROW address for smart page-hit port priority selection logic.
                    act_bank_row[WC_waddr[write_req_sel][BANK_BP+:DDR3_WIDTH_BANK]] <= WC_waddr[write_req_sel][ROW_BP+:DDR3_WIDTH_ADDR] ;

                    // Clean up the selected write channel cache status flags allowing new write data to be accepted.
                    //                                              WC_ddr3_ack                <= (PORT_W_TOTAL)'(1<<write_req_sel) ; // Set the 1 acknowledge of a write command.
                    //                                              WC_ready[write_req_sel]    <= 0 ; // Clear the write cache ready status flag of the selected write channel.
                    //for (int z=0 ; z<(PORT_CACHE_BITS/8) ; z ++ ) WC_wmask[write_req_sel][z] <= 0 ; // Clear all the active write masks of the selected write channel.

        end else begin
                 //WC_ddr3_ack      <= (PORT_W_TOTAL)'(0) ; // Clear every past acknowledge of a write command.
                 end

end // !(RST_IN)
end // @(posedge CMD_CLK)
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

