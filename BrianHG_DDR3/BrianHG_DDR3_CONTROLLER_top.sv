// ********************************************************************************************************
//
// BrianHG_DDR3_CONTROLLER_top.sv Complete DDR3 controller system, with 16 read and 16 write ports.
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
// - Inhibit refresh input with a 'need-to-refresh' output.            (use at your own risk.)
//
// - Official Cyclone V/10/MAX10 DDR MTPS Performance: (Maximum DDR3 clock period + allowable long term
//   jitter is > 3.33333ns total, so in theory 600MHz should just do it if you truly need that frequency.)
//   Apparently Altera thinks so as their official software DDR3 controller is limited to 300MHz/600MTs.
//
//   Speed grade   -8          -7         -6
//              *too slow   606-640    606-640
//
// - Official Lattice ECP5/LFE5U series DDR MTPS Performance:
//   Speed grade   -6          -7         -8
//               606-624    606-700    606-800
//
// * Under-clocking of ram and/or overclocking your FPGA is done at your
//   own discretion and proper operation is not guaranteed.
//
// *** This controller was designed for one or two on board PCB soldered ram chips.
//     If you will be using a single ram module, it is up to you to perform
//     a full temperature sweep test for each vendor's module.
//
// - Includes these following sub-modules :
//   - BrianHG_DDR3_CONTROLLER_top.sv    -> The TOP entry to the complete project which wires the DDR3_COMMANDER to the DDR3_PHY_SEQ giving you access to all the read and write ports + access to the DDR3 IO pins.
//   - BrianHG_DDR3_COMMANDER.sv         -> Handles the multi-port read and write requests and cache, commands the BrianHG_DDR3_PHY_SEQ.sv sequencer.
//   - BrianHG_DDR3_CMD_SEQUENCER.sv     -> Takes in the read and write requests, generates a stream of DDR3 commands to execute the read and writes.
//   - BrianHG_DDR3_PHY_SEQ.sv           -> DDR3 PHY sequencer.          (If you want just a compact DDR3 controller, skip the DDR3_CONTROLLER_top & DDR3_COMMANDER and just use this module alone.)
//   - BrianHG_DDR3_PLL.sv               -> Generates the system clocks. (*** Currently Altera/Intel only ***)
//   - BrianHG_DDR3_GEN_tCK.sv           -> Generates all the tCK count clock cycles for the DDR3_PHY_SEQ so that the DDR3 clock cycle requirements are met.
//   - BrianHG_DDR3_FIFOs.sv             -> Serial shifting logic FIFOs.
//
// - Includes the following test-benches:
//   - BrianHG_DDR3_CONTROLLER_top_tb.sv -> Test the entire 'BrianHG_DDR3_CONTROLLER_top.sv' system with Mircon's DDR3 Verilog model.
//   - BrianHG_DDR3_COMMANDER_tb.sv      -> Test just the commander.  The 'DDR3_PHY_SEQ' is dummy simulated.  (*** This one will simulate on any vendor's ModelSim ***)
//   - BrianHG_DDR3_CMD_SEQUENCER_tb.sv  -> Test just the DDR3 command sequencer.                             (*** This one will simulate on any vendor's ModelSim ***)
//   - BrianHG_DDR3_PHY_SEQ_tb.sv        -> Test just the DDR3 PHY sequencer with Mircon's DDR3 Verilog model providing logged DDR3 command results with any access violations listed.
//   - BrianHG_DDR3_PLL_tb.sv            -> Test just the PLL module.
//
// - IO port vendor specific modules
//   - BrianHG_DDR3_IO_PORT_ALTERA.sv    -> Physical DDR IO pin driver specifically for Altera/Intel Cyclone III/IV/V and MAX10.
//   - BrianHG_DDR3_IO_PORT_LATTICE.sv   -> Physical DDR IO pin driver specifically for Lattice ECP5/LFE5U series. (*** Coming soon ***)
//   - BrianHG_DDR3_IO_PORT_XILINX.sv    -> Physical DDR IO pin driver specifically for Xilinx Artix 7 series.     (*** Coming soon ***)
//
// - Example SDC file
//   - BrianHG_DDR3_DECA.sdc             -> Example .sdc file used with the Arrow Deca FPGA development board.  It specifies timing constraints for the DDR3 IO pins
//                                          and the multicycle constraints between the different DDR3_CLK PLL clock phases and potential slower CMD_CLK domains.
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

module BrianHG_DDR3_CONTROLLER_top #(

parameter string     FPGA_VENDOR             = "Altera",         // (Only Altera for now) Use ALTERA, INTEL, LATTICE or XILINX.
parameter string     FPGA_FAMILY             = "MAX 10",         // With Altera, use Cyclone III, Cyclone IV, Cyclone V, MAX 10,....
parameter bit        BHG_OPTIMIZE_SPEED      = 1,                // Use '1' for better FMAX performance, this will increase logic cell usage in the BrianHG_DDR3_PHY_SEQ module.
                                                                 // It is recommended that you use '1' when running slowest -8 Altera fabric FPGA above 300MHz or Altera -6 fabric above 350MHz.
parameter bit        BHG_EXTRA_SPEED         = 1,                // Use '1' for even better FMAX performance or when overclocking the core.  This will increase logic cell usage.

// ****************  System clock generation and operation.
parameter int        CLK_KHZ_IN              = 50000,            // PLL source input clock frequency in KHz.
parameter int        CLK_IN_MULT             = 32,               // Multiply factor to generate the DDR MTPS speed divided by 2.
parameter int        CLK_IN_DIV              = 4,                // Divide factor.  When CLK_KHZ_IN is 25000,50000,75000,100000,125000,150000, use 2,4,6,8,10,12.
parameter int        DDR_TRICK_MTPS_CAP      = 0,                // 0=off, Set a false PLL DDR data rate for the compiler to allow FPGA overclocking.  ***DO NOT USE.
                                                                
parameter string     INTERFACE_SPEED         = "Full",           // Either "Full", "Half", or "Quarter" speed for the user interface clock.
                                                                 // This will effect the controller's interface CMD_CLK output port frequency.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_CK_MHZ              = ((CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV)/1000), // DDR3 CK clock speed in MHz.
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
                                                                 // *** Do not go above 8, doing so may break the data sheet's maximum ACTIVATE-to-PRECHARGE command period.
parameter bit [6:0]  IDLE_TIME_uSx10         = 2,               // Defines the time in 1/10uS until the command IDLE counter will allow low priority REFRESH cycles.
                                                                 // Use 10 for 1uS.  0=disable, 1 for a minimum effect, 127 maximum.

parameter bit        SKIP_PUP_TIMER          = 0,                // Skip timer during and after reset. ***ONLY use 1 for quick simulations.

parameter string     BANK_ROW_ORDER          = "ROW_BANK_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.

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
                                                            // 0=4 level deep.  1=8 level deep.
                                                            // The size of the number of read commands built up in advance while the read channel waits
                                                            // for the DDR3_PHY_SEQ to return the read request data.  (Stored in logic cells)
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
input                 CLK_IN,                     // External crystal clock which feeds the dedicated PLL for the DDR3.

// ****************************************
// DDR3 controller command clock and status
// ****************************************
output                DDR3_CLK,
output                DDR3_CLK_50,
output                DDR3_CLK_25,
output                CMD_CLK,                    // DDR3 controller interface clock.  May be used by your entire FPGA
output                RST_OUT,                    // Stays high for at least 100ns after the PLL lock has been achieved.


output                DDR3_READY,                 // Goes high after the DDR3 has been initialized and successfully setup.
output                SEQ_CAL_PASS,               // Goes high if the DDR3 read calibration passes.
output                PLL_LOCKED,                 // Goes when the PLL is locked.
output        [7:0]   RDCAL_data,                 // A record of the PLL valid tuning positions.

// ****************************************
// DDR3 Controller Interface.
// ****************************************
output                               CMD_R_busy          [0:PORT_R_TOTAL-1],  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.
output                               CMD_W_busy          [0:PORT_W_TOTAL-1],  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.

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

output                               CMD_read_ready      [0:PORT_R_TOTAL-1],  // Goes high for 1 clock when the read command data is valid.
output       [PORT_CACHE_BITS-1:0]   CMD_read_data       [0:PORT_R_TOTAL-1],  // Valid read data when 'CMD_read_ready' is high.
                                                                              // *** All channels of the 'CMD_read_data will' always be 'PORT_CACHE_BITS' wide, however,
                                                                              // only the bottom 'PORT_R_DATA_WIDTH' bits will be active.

output       [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_out [0:PORT_R_TOTAL-1],  // Returns the 'CMD_read_vector_in' which was sampled during the 'CMD_read_req' in parallel
                                                                              // with the 'CMD_read_data'.  This allows for multiple post reads where the output
                                                                              // has a destination pointer.
output       [PORT_ADDR_SIZE-1:0]    CMD_read_addr_out   [0:PORT_R_TOTAL-1],  // A return of the address which was sent in with the read request.


input                               CMD_R_priority_boost [0:PORT_R_TOTAL-1],  // Boosts the port's 'PORT_R_PRIORITY' parameter by a weight of 8 when set.
input                               CMD_W_priority_boost [0:PORT_W_TOTAL-1],  // Boosts the port's 'PORT_W_PRIORITY' parameter by a weight of 8 when set.

// ****************************************      
// DDR3 Memory IO port                           
// ****************************************      
output                             DDR3_RESET_n,  // DDR3 RESET# input pin.
output       [DDR3_NUM_CK-1:0]     DDR3_CK_p,    // DDR3_CLK ****************** YOU SHOULD SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
output       [DDR3_NUM_CK-1:0]     DDR3_CK_n,    // DDR3_CLK ****************** YOU SHOULD SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
                                                  // ************************** port to generate the negative DDR3_CLK# output.
                                                  // ************************** Generate an additional DDR_CK_p pair for every DDR3 ram chip. 

output                             DDR3_CKE,     // DDR3 CKE

output                             DDR3_CS_n,     // DDR3 CS#
output                             DDR3_RAS_n,    // DDR3 RAS#
output                             DDR3_CAS_n,    // DDR3 CAS#
output                             DDR3_WE_n,     // DDR3 WE#
output                             DDR3_ODT,      // DDR3 ODT

output       [DDR3_WIDTH_ADDR-1:0] DDR3_A,        // DDR3 multiplexed address input bus
output       [DDR3_WIDTH_BANK-1:0] DDR3_BA,       // DDR3 Bank select

inout        [DDR3_WIDTH_DM-1 :0]  DDR3_DM,       // DDR3 Write data mask. DDR3_DM[0] drives write DQ[7:0], DDR3_DM[1] drives write DQ[15:8]...
                                                  // ***on x8 devices, the TDQS is not used and should be connected to GND or an IO set to GND.

inout        [DDR3_WIDTH_DQ-1:0]   DDR3_DQ,       // DDR3 DQ data IO bus.
inout        [DDR3_WIDTH_DQS-1:0]  DDR3_DQS_p,    // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
inout        [DDR3_WIDTH_DQS-1:0]  DDR3_DQS_n,    // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
                                                  // ****************** YOU SHOULD SET THIS IO TO A DIFFERENTIAL LVDS dedicated DQS pins for
                                                  // ****************** proper parameter ' DDR3_RDQ_CLK_SEL = "DDR3_extDQS" ' support.

// ****************************************      
// Debug port...                        
// ****************************************      

input reset_phy, reset_cmd

);


// Internal wire logic.
logic                                        DDR3_CLK_WDQ,DDR3_CLK_RDQ;
logic                                        SEQ_CMD_ENA_t;
logic                                        SEQ_WRITE_ENA;
logic [PORT_ADDR_SIZE-1:0]                   SEQ_ADDR;
logic [PORT_CACHE_BITS-1:0]                  SEQ_WDATA;
logic [PORT_CACHE_BITS/8-1:0]                SEQ_WMASK;
logic [DDR3_VECTOR_SIZE-1:0]                 SEQ_RDATA_VECT_IN;  // Embed multiple read request returns into the SEQ_RDATA_VECT_IN.
logic                                        SEQ_refresh_hold;

logic                                        SEQ_BUSY_t;
logic                                        SEQ_RDATA_RDY_t;
logic [PORT_CACHE_BITS-1:0]                  SEQ_RDATA;
logic [DDR3_VECTOR_SIZE-1:0]                 SEQ_RDATA_VECT_OUT;
logic [4:0]                                  SEQ_refresh_queue;

logic        phase_done, phase_step, phase_updn;


// *********************************************************************************************
// This module generates the master reference clocks for the entire memory system.
// *********************************************************************************************
BrianHG_DDR3_PLL  #(.FPGA_VENDOR    (FPGA_VENDOR),    .INTERFACE_SPEED (INTERFACE_SPEED),  .DDR_TRICK_MTPS_CAP       (DDR_TRICK_MTPS_CAP),
                    .FPGA_FAMILY    (FPGA_FAMILY),
                    .CLK_KHZ_IN     (CLK_KHZ_IN),     .CLK_IN_MULT     (CLK_IN_MULT),      .CLK_IN_DIV               (CLK_IN_DIV),
                    .DDR3_WDQ_PHASE (DDR3_WDQ_PHASE), .DDR3_RDQ_PHASE  (DDR3_RDQ_PHASE)
) DDR3_PLL (        .RST_IN         (RST_IN),         .RST_OUT         (RST_OUT),          .CLK_IN    (CLK_IN),      .DDR3_CLK    (DDR3_CLK),
                    .DDR3_CLK_WDQ   (DDR3_CLK_WDQ),   .DDR3_CLK_RDQ    (DDR3_CLK_RDQ),     .CMD_CLK   (CMD_CLK),     .PLL_LOCKED (PLL_LOCKED),
                    .DDR3_CLK_50    (DDR3_CLK_50),    .DDR3_CLK_25     (DDR3_CLK_25),

                    .phase_step     ( phase_step ),   .phase_updn      ( phase_updn ),
                    .phase_sclk     ( DDR3_CLK_25 ),  .phase_done      ( phase_done ) );

// **********************************************************************************************************************
// This module is the smart cache multi-port controller which commands the BrianHG_DDR3_PHY_SEQ ram controller.
// **********************************************************************************************************************
BrianHG_DDR3_COMMANDER  #(.FPGA_VENDOR         (FPGA_VENDOR),         .FPGA_FAMILY         (FPGA_FAMILY),        .INTERFACE_SPEED     (INTERFACE_SPEED),
                          .CLK_KHZ_IN          (CLK_KHZ_IN),          .CLK_IN_MULT         (CLK_IN_MULT),        .CLK_IN_DIV          (CLK_IN_DIV),                      

                          .DDR3_SIZE_GB        (DDR3_SIZE_GB),        .DDR3_WIDTH_DQ       (DDR3_WIDTH_DQ),      .DDR3_NUM_CHIPS      (DDR3_NUM_CHIPS),
                          .DDR3_WIDTH_ADDR     (DDR3_WIDTH_ADDR),     .DDR3_WIDTH_BANK     (DDR3_WIDTH_BANK),    .DDR3_WIDTH_CAS      (DDR3_WIDTH_CAS),
                          .DDR3_WIDTH_DM       (DDR3_WIDTH_DM),       .BANK_ROW_ORDER      (BANK_ROW_ORDER),

                          .PORT_R_TOTAL        (PORT_R_TOTAL),        .PORT_W_TOTAL        (PORT_W_TOTAL),       .PORT_VECTOR_SIZE    (PORT_VECTOR_SIZE),
                          .PORT_R_DATA_WIDTH   (PORT_R_DATA_WIDTH),   .PORT_W_DATA_WIDTH   (PORT_W_DATA_WIDTH),
                          .PORT_R_PRIORITY     (PORT_R_PRIORITY),     .PORT_W_PRIORITY     (PORT_W_PRIORITY),    .PORT_R_CMD_STACK    (PORT_R_CMD_STACK),
                          .PORT_CACHE_SMART    (PORT_CACHE_SMART),    .PORT_W_CACHE_TOUT   (PORT_W_CACHE_TOUT),
                          .PORT_R_MAX_BURST    (PORT_R_MAX_BURST),    .PORT_W_MAX_BURST    (PORT_W_MAX_BURST),   .SMART_BANK          (SMART_BANK)
) DDR3_COMMANDER (
                          // *** Interface command port. ***
                          .RST_IN              (RST_OUT || reset_cmd),                          .CMD_CLK              (CMD_CLK             ),

                          // *** DDR3 Commander functions ***
                          .CMD_W_busy          (CMD_W_busy          ),                          .CMD_write_req        (CMD_write_req       ),
                          .CMD_waddr           (CMD_waddr           ),                          .CMD_wdata            (CMD_wdata           ),
                          .CMD_wmask           (CMD_wmask           ),                          .CMD_W_priority_boost (CMD_W_priority_boost),

                          .CMD_R_busy          (CMD_R_busy          ),                          .CMD_read_req         (CMD_read_req        ),
                          .CMD_raddr           (CMD_raddr           ),                          .CMD_read_vector_in   (CMD_read_vector_in  ),
                          .CMD_read_ready      (CMD_read_ready      ),                          .CMD_read_data        (CMD_read_data       ),
                          .CMD_read_vector_out (CMD_read_vector_out ),                          .CMD_read_addr_out    (CMD_read_addr_out   ),
                          .CMD_R_priority_boost(CMD_R_priority_boost),

                          // *** Controls which send commands to the BrianHG_DDR3_PHY_SEQ. ***
                          .SEQ_CMD_ENA_t       (SEQ_CMD_ENA_t),       .SEQ_WRITE_ENA       (SEQ_WRITE_ENA),      .SEQ_ADDR            (SEQ_ADDR),
                          .SEQ_WDATA           (SEQ_WDATA),           .SEQ_WMASK           (SEQ_WMASK),          .SEQ_RDVEC_TO_DDR3   (SEQ_RDATA_VECT_IN),
                          .SEQ_refresh_hold    (SEQ_refresh_hold),
  
                          // *** Results returned from the BrianHG_DDR3_PHY_SEQ. ***
                          .DDR3_READY          (DDR3_READY),          .SEQ_CAL_PASS        (SEQ_CAL_PASS),
                          .SEQ_BUSY_t          (SEQ_BUSY_t),          .SEQ_RDATA_RDY_t     (SEQ_RDATA_RDY_t),    .SEQ_RDATA           (SEQ_RDATA),
                          .SEQ_RDVEC_FROM_DDR3 (SEQ_RDATA_VECT_OUT) );

// ***********************************************************************************************

// ******************************************************************************************************
// This module receives the commands from the multi-port ram controller and sequences the DDR3 IO pins.
// ******************************************************************************************************
BrianHG_DDR3_PHY_SEQ    #(.FPGA_VENDOR         (FPGA_VENDOR),         .FPGA_FAMILY         (FPGA_FAMILY),        .INTERFACE_SPEED    (INTERFACE_SPEED),
                          .BHG_OPTIMIZE_SPEED  (BHG_OPTIMIZE_SPEED),  .BHG_EXTRA_SPEED     (BHG_EXTRA_SPEED),
                          .CLK_KHZ_IN          (CLK_KHZ_IN),          .CLK_IN_MULT         (CLK_IN_MULT),        .CLK_IN_DIV         (CLK_IN_DIV),
                          
                          .DDR3_CK_MHZ         (DDR3_CK_MHZ ),        .DDR3_SPEED_GRADE    (DDR3_SPEED_GRADE),   .DDR3_SIZE_GB       (DDR3_SIZE_GB),
                          .DDR3_WIDTH_DQ       (DDR3_WIDTH_DQ),       .DDR3_NUM_CHIPS      (DDR3_NUM_CHIPS),     .DDR3_NUM_CK        (DDR3_NUM_CK),
                          .DDR3_WIDTH_ADDR     (DDR3_WIDTH_ADDR),     .DDR3_WIDTH_BANK     (DDR3_WIDTH_BANK),    .DDR3_WIDTH_CAS     (DDR3_WIDTH_CAS),
                          .DDR3_WIDTH_DM       (DDR3_WIDTH_DM),       .DDR3_WIDTH_DQS      (DDR3_WIDTH_DQS),     .DDR3_ODT_RTT       (DDR3_ODT_RTT),
                          .DDR3_RZQ            (DDR3_RZQ),            .DDR3_TEMP           (DDR3_TEMP),          .DDR3_WDQ_PHASE     (DDR3_WDQ_PHASE), 
                          .DDR3_RDQ_PHASE      (DDR3_RDQ_PHASE),      .DDR3_MAX_REF_QUEUE  (DDR3_MAX_REF_QUEUE), .IDLE_TIME_uSx10    (IDLE_TIME_uSx10),
                          .SKIP_PUP_TIMER      (SKIP_PUP_TIMER),      .BANK_ROW_ORDER      (BANK_ROW_ORDER),

                          .PORT_VECTOR_SIZE    (DDR3_VECTOR_SIZE),    .PORT_ADDR_SIZE      (PORT_ADDR_SIZE)

) DDR3_PHY_SEQ (          // *** DDR3_PHY_SEQ Clocks & Reset ***
                          .RST_IN         (RST_OUT || reset_phy),     .DDR_CLK       (DDR3_CLK),   .DDR_CLK_WDQ  (DDR3_CLK_WDQ), .DDR_CLK_RDQ (DDR3_CLK_RDQ),
                          .CLK_IN              (CLK_IN),                                           .DDR_CLK_50   (DDR3_CLK_50),  .DDR_CLK_25  (DDR3_CLK_25),

                          // *** DDR3 Ram Chip IO Pins ***           
                          .DDR3_RESET_n        (DDR3_RESET_n),        .DDR3_CK_p     (DDR3_CK_p),   .DDR3_CKE     (DDR3_CKE),     .DDR3_CS_n   (DDR3_CS_n),
                          .DDR3_RAS_n          (DDR3_RAS_n),          .DDR3_CAS_n    (DDR3_CAS_n),  .DDR3_WE_n    (DDR3_WE_n),    .DDR3_ODT    (DDR3_ODT),
                          .DDR3_A              (DDR3_A),              .DDR3_BA       (DDR3_BA),     .DDR3_DM      (DDR3_DM),      .DDR3_DQ     (DDR3_DQ),
                          .DDR3_DQS_p          (DDR3_DQS_p),          .DDR3_DQS_n    (DDR3_DQS_n),  .DDR3_CK_n    (DDR3_CK_n),

                          // *** Command port input ***              
                          .CMD_CLK             (CMD_CLK),             .SEQ_CMD_ENA_t (SEQ_CMD_ENA_t),      .SEQ_WRITE_ENA      (SEQ_WRITE_ENA),
                          .SEQ_ADDR            (SEQ_ADDR),            .SEQ_WDATA     (SEQ_WDATA),          .SEQ_WMASK          (SEQ_WMASK),
                          .SEQ_RDATA_VECT_IN   (SEQ_RDATA_VECT_IN),                                        .SEQ_refresh_hold   (SEQ_refresh_hold),

                          // *** Command port results ***                                                 
                          .SEQ_BUSY_t          (SEQ_BUSY_t),          .SEQ_RDATA_RDY_t (SEQ_RDATA_RDY_t),  .SEQ_RDATA          (SEQ_RDATA),
                          .SEQ_RDATA_VECT_OUT  (SEQ_RDATA_VECT_OUT),                                       .SEQ_refresh_queue  (SEQ_refresh_queue),

                          // *** Diagnostic flags ***                                                 
                          .SEQ_CAL_PASS        (SEQ_CAL_PASS),        .DDR3_READY    (DDR3_READY),

                          // *** PLL tuning controls ***
                          .phase_done          (phase_done),          .phase_step    (phase_step),         .phase_updn         (phase_updn),
                          .RDCAL_data          (RDCAL_data) );

// ***********************************************************************************************


endmodule

