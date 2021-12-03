// *********************************************************************
// *********************************************************************
//
// BrianHG_DDR3_PHY_SEQ.sv DDR3-PHY and sequencer.
// Version 1.50, November 28, 2021.  (Half-rate timer version)
//               Added *preserve* and duplicate logic to minimize fanouts to help FMAX.
//
// Written by Brian Guralnick.
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// Designed for Altera/Intel Quartus Cyclone V/10/MAX10 and others. (Unofficial Cyclone III & IV, may require overclocking.)
//              Lattice ECP5/LFE5U series.
//              Xilinx Artix 7 series.
//
// Features:
//
// - ***NEW - Can operate in stand alone mode without the multi-port cache manager BrianHG_DDR3_COMMANDER.sv.
//            However, the read / write data ports are 256 bit and the 'SEQ_CMD_ENA_t' & 'SEQ_RDATA_RDY_t'
//            are TOGGLES while the controller is busy when 'SEQ_BUSY_t' out != 'SEQ_CMD_ENA_t' in.  It was done this
//            way to allow optional easy clock boundary crossing from low to high, or high to low frequency domains.
//
// - Receives reset & clocks from the BrianHG_DDR3_PLL.sv :
//   RST_IN, CLK_CK, CLK_DQS, CLK_RDQ.
//
// - Receives commands from BrianHG_DDR3_COMMANDER.sv :
//   SEQ_CMD_ENA_t(toggle), SEQ_WRITE_ENA, SEQ_ADDR, SEQ_WDATA, SEQ_WMASK, SEQ_RDATA_VECT_IN.
//   It returns :
//   SEQ_BUSY_t(toggle), SEQ_RDATA_RDY_t(toggle), SEQ_RDATA, SEQ_RDATA_VECT_OUT.
//
// - Command in bus recognizes Half rate, Quarter rate, or Eighth rate controller mode.
//
// - Has smart multiple open BANKS and individual selective closing and opening of said BANKS
//   with uninterrupted reads and writes across said BANKS.
//
// - Generates all the PHY DDR3 IO signals.
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
// *********************************************************************

// Altera Quartus Prim Specific synthesis options:


module BrianHG_DDR3_PHY_SEQ #(


parameter string     FPGA_VENDOR             = "Altera",         // (Only Altera for now) Use ALTERA, INTEL, LATTICE or XILINX.
parameter string     FPGA_FAMILY             = "MAX 10",         // With Altera, use Cyclone III, Cyclone IV, Cyclone V, MAX 10,....
parameter bit        BHG_OPTIMIZE_SPEED      = 1,                // Use '1' for better FMAX performance, this will add logic cell usage to the BrianHG_DDR3_PHY_SEQ module.
                                                                 // It is recommended that you use '1' when running slowest -8 Altera fabric FPGA above 300MHz or Altera -6 fabric above 350MHz.
parameter bit        BHG_EXTRA_SPEED         = 1,                // Use '1' for even better FMAX performance or when overclocking the core.  This will increase logic cell usage.

// ****************  System clock generation and operation.
parameter int        CLK_KHZ_IN              = 50000,            // PLL source input clock frequency in KHz.
parameter int        CLK_IN_MULT             = 32,               // Multiply factor to generate the DDR MTPS speed divided by 2.
parameter int        CLK_IN_DIV              = 4,                // Divide factor.  When CLK_KHZ_IN is 25000,50000,75000,100000,125000,150000, use 2,4,6,8,10,12.
parameter string     INTERFACE_SPEED         = "Half",           // Either "Full", "Half", or "Quarter" speed for the user interface clock.
                                                                 // This will effect the controller's interface CMD_CLK output port frequency.
                                                                 // "Quarter" mode only provides effective speed when you do not use the BrianHG_DDR3_COMMANDER and
                                                                 // interface directly with the BrianHG_DDR3_PHY_SEQ.  Otherwise added wait states may be introduced.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_CK_MHZ              = ((CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV)/1000), // DDR3 CK clock speed in MHz.
parameter string     DDR3_SPEED_GRADE        = "-15E",           // Use 1066 / 187E, 1333 / -15E, 1600 / -125, 1866 / -107, or 2133 MHz / 093.
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

parameter int        DDR3_ODT_RTT            = 120,              // use 120, 60, 40, 30, 20 Ohm. or 0 to disable ODT.  (On Die Termination during write operation.)
parameter int        DDR3_RZQ                = 40,               // use 34 or 40 Ohm. (Output Drive Strength during read operation.)
parameter int        DDR3_TEMP               = 85,               // use 85,95,105. (Peak operating temperature in degrees Celsius.)

parameter int        DDR3_WDQ_PHASE          = 270,              // 270, Select the write and write DQS output clock phase relative to the DDR3_CLK/CK#
parameter int        DDR3_RDQ_PHASE          = 0,                // 0,   Select the read latch clock for the read data and DQS input relative to the DDR3_CLK.

parameter bit [4:0]  DDR3_MAX_REF_QUEUE      = 8,                // Defines the size of the refresh queue where refreshes will have a higher priority than incoming SEQ_CMD_ENA_t command requests.
                                                                 // *** Do not go above 8, doing so may break the data sheet's maximum ACTIVATE-to-PRECHARGE command period.
parameter bit [7:0]  IDLE_TIME_uSx10         = 2,                // Defines the time in 1/10uS until the command IDLE counter will allow low priority REFRESH cycles.
                                                                 // Use 10 for 1uS.  0=disable, 1 for a minimum effect, 127 maximum.

parameter bit        SKIP_PUP_TIMER          = 0,                // Skip timer during and after reset. ***ONLY use 1 for quick simulations.

parameter string     BANK_ROW_ORDER          = "ROW_BANK_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.

// ****************  DDR3 controller configuration parameter settings.
parameter int        PORT_VECTOR_SIZE        = 8,                // Set the width of the SEQ_RDATA_VECT_IN & SEQ_RDATA_VECT_OUT port, 1 through 64.
parameter int        PORT_ADDR_SIZE          = (DDR3_WIDTH_ADDR + DDR3_WIDTH_BANK + DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)),

parameter bit        USE_TOGGLE_CONTROLS     = 1                 // When 1, this setting makes the 'SEQ_CMD_ENA_t', 'SEQ_BUSY_t' and 'SEQ_RDATA_RDY_t' controls
                                                                 // activate each time their input/output toggles.  When the setting is 0, these controls
                                                                 // become active true/enable logic synchronous to the CMD_CLK.
)(
// ****************************************
// Clock and reset input
// ****************************************
input                                RST_IN,                     // Resets the controller and re-starts the DDR3 ram.
input                                DDR_CLK,                    // This clock runs at the DDR3_CLK/DDR3_CLK# frequency.
input                                DDR_CLK_RDQ,                // This clock is used for reading the DQ bus and should have an adjustable phase either preset or adjusted during read leveling.
input                                DDR_CLK_WDQ,                // This clocks the DQ data out during writes and should have a precision 90 degree phase shift compared to the DDR_CLK input for normal operation..
input                                DDR_CLK_50,                 // This clock runs at the 1/2 DDR3_CLK/DDR3_CLK# frequency.
input                                DDR_CLK_25,                 // This clock runs at the 1/4 DDR3_CLK/DDR3_CLK# frequency.

// ****************************************                     
// Initialization program sequencer clock.                                              
// ****************************************                     
input                                CLK_IN,                     // This clock should be between 10 and 100 MHz, specified by parameter 'CLK_KHZ_IN' and for best FMAX, 
                                                                 // needs to be either specified as a false path or a multi-cycle setup of 2 compared to the DDR_CLK.
                                                                 // *** This clock is used for the power-up initialization sequencer.
// ****************************************                     
// Commands input                                               
// ****************************************                     
input                                CMD_CLK          ,
input                                SEQ_CMD_ENA_t    ,          // (*** WARNING: THIS IS A TOGGLE CONTROL! *** ) Begin a read or write once this input toggles state from high to low, or low to high.
input                                SEQ_WRITE_ENA    ,          // When high, a 256 bit write will be done, when low, a 256 bit read will be done.
input        [PORT_ADDR_SIZE-1:0]    SEQ_ADDR         ,          // Address of read and write.  Note that ADDR[4:0] are supposed to be hard wired to 0 or low, otherwise the bytes in the 256 bit word will be sorted incorrectly.
input        [DDR3_RWDQ_BITS-1:0]    SEQ_WDATA        ,          // write data.
input        [DDR3_RWDQ_BITS/8-1:0]  SEQ_WMASK        ,          // write data mask.
input        [PORT_VECTOR_SIZE-1:0]  SEQ_RDATA_VECT_IN,          // Read destination vector input.

input                                SEQ_refresh_hold ,          // Prevent refresh.  Warning, if held too long, the SEQ_refresh_queue will max out.

// ****************************************                     
// Results outputs                                                
// ****************************************                     
output logic                         SEQ_BUSY_t             ,    // Commands will only be accepted when this output is equal to the SEQ_CMD_ENA_t toggle input.
output logic                         SEQ_RDATA_RDY_t     = 0,    // (*** WARNING: THIS IS A TOGGLE OUTPUT! ***) This output will toggle from low to high or high to low once new read data is valid.
output logic [DDR3_RWDQ_BITS-1:0]    SEQ_RDATA           = 0,    // 256 bit date read from ram, valid when SEQ_RDATA_RDY_t goes high.
output logic [PORT_VECTOR_SIZE-1:0]  SEQ_RDATA_VECT_OUT  = 0,    // A copy of the 'SEQ_RDATA_VECT_IN' input during the read request.  Valid when SEQ_RDATA_RDY_t goes high.

output logic [4:0]                   SEQ_refresh_queue   = 0,    // This output tells you how many refresh commands are required.  Anything above 9 breaks the data-sheet 
                                                                 // maximum refresh-to-refresh time interval.
// ****************************************                     
// Diagnostic flags.                                                
// ****************************************                     
output logic                         SEQ_CAL_PASS        = 0,    // Goes low after a reset, goes high if the read calibration passes.
output logic                         DDR3_READY          = 0,    // Goes low after a reset, goes high when the DDR3 is ready to go.
// ****************************************
// DDR3 Memory IO port
// ****************************************
output                               DDR3_RESET_n,               // DDR3 RESET# input pin.
output       [DDR3_NUM_CK-1:0]       DDR3_CK_p,                  // DDR3_CLK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
output       [DDR3_NUM_CK-1:0]       DDR3_CK_n,                  // DDR3_CLK ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
                                                                 // ************************** port to generate the negative DDR3_CLK# output.
                                                                 // ************************** Generate an additional DDR_CK_p pair for every DDR3 ram chip. 
            
output                               DDR3_CKE,                   // DDR3 CKE
            
output                               DDR3_CS_n,                  // DDR3 CS#
output                               DDR3_RAS_n,                 // DDR3 RAS#
output                               DDR3_CAS_n,                 // DDR3 CAS#
output                               DDR3_WE_n,                  // DDR3 WE#
output                               DDR3_ODT,                   // DDR3 ODT
            
output       [DDR3_WIDTH_ADDR-1:0]   DDR3_A,                     // DDR3 multiplexed address input bus
output       [DDR3_WIDTH_BANK-1:0]   DDR3_BA,                    // DDR3 Bank select
            
inout        [DDR3_WIDTH_DM-1:0]     DDR3_DM,                    // DDR3 Write data mask. DDR3_DM[0] drives write DQ[7:0], DDR3_DM[1] drives write DQ[15:8]...
                                                                 // ***  on x8 devices, the TDQS is not used and should be connected to GND or an IO set to GND.
inout        [DDR3_WIDTH_DQ-1:0]     DDR3_DQ,                    // DDR3 DQ data IO bus.
            
inout        [DDR3_WIDTH_DQS-1:0]    DDR3_DQS_p,                 // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
inout        [DDR3_WIDTH_DQS-1:0]    DDR3_DQS_n,                 // DDR3 DQS ********* IOs. DQS[0] drives DQ[7:0], DQS[1] drives DQ[15:8], DQS[2] drives DQ[23:16]...
                                                                 // ****************** YOU MUST SET THIS IO TO A DIFFERENTIAL LVDS or LVDS_E_3R
                                                                 // ****************** port to generate the negative DDR3_DQS# IO.

// ****************************************
// PLL tuning port.
// ****************************************
input               phase_done,
output logic        phase_step, phase_updn,
output logic  [7:0] RDCAL_data
);

localparam DQ_WIDTH     = DDR3_WIDTH_DQ*DDR3_NUM_CHIPS;
localparam DQM_WIDTH    = DDR3_WIDTH_DQ/8*DDR3_NUM_CHIPS;
localparam VECTOR_CACHE = 4 ;                               // Defines the read vector MSB cache size.  IE 4=16 commands.

logic                        RESET_n      = 0 ;     // DDR3 RESET# input pin.
logic                        RESET_n_int  = 0 ;     // DDR3 RESET# input pin.
logic                        RESET_n_int2 = 0 ;     // DDR3 RESET# input pin.
logic                        CKE          = 0 ;     // DDR3 CKE
logic                        CKE_int      = 0 ;     // DDR3 CKE
logic                        CKE_int2     = 0 ;     // DDR3 CKE

logic                        CS_n    = 1 ;     // DDR3 CS#
logic                        RAS_n   = 1 ;     // DDR3 RAS#
logic                        CAS_n   = 1 ;     // DDR3 CAS#
logic                        WE_n    = 1 ;     // DDR3 WE#
logic                        ODT     = 0 ;
logic [DDR3_WIDTH_ADDR-1:0]  A       = 0 ;     // DDR3 multiplexed address input bus
logic [DDR3_WIDTH_BANK-1:0]  BA      = 0 ;     // DDR3 Bank select
logic                        WRITE   = 0 ;     // Helps improve FMAX when being sent to DDR3_PHY.
logic                        READ    = 0 ;     // Helps improve FMAX when being sent to DDR3_PHY.
logic [DDR3_RWDQ_BITS-1:0]   WDQ     = 0 ;
logic [DDR3_RWDQ_BITS/8-1:0] WDQM    = 0 ;

logic           DDR3_dll_disable     = 0 ;
logic           DDR3_dll_reset       = 0 ;
logic           DDR3_write_leveling  = 0 ;
logic           DDR3_read_leveling   = 0 ;

logic [5:0]     tAA  ,tRCD ,tRP   ,tRC    ,tRAS   ,tRRD ,tFAW  ,tWR     ,tWTR,tRPT,tCCD,tDAL,tMRD,
                tMOD ,tMPRR,ODTLon,ODTLoff,ODTH8  ,ODTH4,tWLMRD,tWLDQSEN,CL  ,CWL ,WR  ,AL  ,tCKE,tRTP;
logic [10:0]    tDLLK,tRFC ,tREFI ,tZQinit,tZQoper,tZQCS, tXPR; // tREFI is given in microseconds/10.  IE a value of 78 = 7.8 microseconds.
logic [12:0]    MRS [0:3];                                      // MRS[0:3] go to the first 13 bit DDR3_A[12:0] while the [0,1,2,3]
                                                                // numerically point to the bottom two DDR3_BA[1:0] bits.



logic           PHY_RDATA_t ,RDATA_store,RDATA_store_flag; // Output from phy read data.

logic [DDR3_RWDQ_BITS-1:0] PHY_RDATA    ; // Used to change clock domains.

(*preserve*) logic reset_latch,reset_latch2,reset_latch1;

// **********************************************
// ***  Unknown INTERFACE_SPEED *****************
// **********************************************
// Verify that the 'INTERFACE_SPEED' is equal to 'Half', 'Quarter', or 'Eighth'
generate
         if (INTERFACE_SPEED[0]!="F" && INTERFACE_SPEED[0]!="f" &&
             INTERFACE_SPEED[0]!="H" && INTERFACE_SPEED[0]!="h" &&
             INTERFACE_SPEED[0]!="Q" && INTERFACE_SPEED[0]!="q"     )  initial begin
$warning("********************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ PARAMETER ERROR ***");
$warning("************************************************************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ parameter .INTERFACE_SPEED(\"%s\") is not supported. ***",INTERFACE_SPEED);
$warning("*** Only \"Full\", \"Half\", and \"Quarter\" speeds are supported.                   ***");
$warning("************************************************************************************");
$error;
$stop;
end
endgenerate

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
// **********************************************
// ***  Unknown DDR3_WIDTH_CAS *****************
// **********************************************
generate
         if (DDR3_WIDTH_CAS!=10 && DDR3_WIDTH_CAS!=11) initial begin
$warning("********************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ PARAMETER ERROR ***");
$warning("****************************************************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ parameter .DDR3_WIDTH_CAS(%d) is not supported. ***",5'(DDR3_WIDTH_CAS));
$warning("*** Only 10 or 11 are supported.                                         ***");
$warning("****************************************************************************");
$error;
$stop;
end
endgenerate
// **********************************************
// ***  Unknown DDR3_WIDTH_ADDR *****************
// **********************************************
generate
         if (DDR3_WIDTH_ADDR<13 && DDR3_WIDTH_ADDR>17) initial begin
$warning("********************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ PARAMETER ERROR ***");
$warning("****************************************************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ parameter .DDR3_WIDTH_ADDR(%d) is not supported. ***",5'(DDR3_WIDTH_ADDR));
$warning("*** Only 13 through 17 are supported.                                         ***");
$warning("****************************************************************************");
$error;
$stop;
end
endgenerate
// **********************************************
// ***  Unknown DDR3_WIDTH_BANK *****************
// **********************************************
generate
         if (DDR3_WIDTH_BANK!=3) initial begin
$warning("********************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ PARAMETER ERROR ***");
$warning("*****************************************************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ parameter .DDR3_WIDTH_BANK(%d) is not supported. ***",5'(DDR3_WIDTH_BANK));
$warning("*** Only 3 is supported.                                                  ***");
$warning("*****************************************************************************");
$error;
$stop;
end
endgenerate


// ******************************************************************************************************************************************
// *** This module selects the timer DDR3_CLK count values and generates the MRS DDR3 Address values
// ******************************************************************************************************************************************
BrianHG_DDR3_GEN_tCK #(
// *****************  DDR3 ram chip configuration settings
    .DDR3_CK_MHZ       (DDR3_CK_MHZ      ),  .DDR3_SPEED_GRADE (DDR3_SPEED_GRADE),  .DDR3_SIZE_GB     (DDR3_SIZE_GB    ),  .DDR3_WIDTH_DQ    (DDR3_WIDTH_DQ   ),
    .DDR3_ODT_RTT     (DDR3_ODT_RTT    ),  .DDR3_RZQ         (DDR3_RZQ        ),  .DDR3_TEMP        (DDR3_TEMP       )
) BHG_DDR3_GEN_tCK (
// *** Dynamic switch inputs.
    .DDR3_dll_disable     (DDR3_dll_disable   ), .DDR3_dll_reset       (DDR3_dll_reset     ),
    .DDR3_write_leveling  (DDR3_write_leveling), .DDR3_read_leveling   (DDR3_read_leveling ),
// *** Fixed tCK value outputs.
.tAA      (tAA     ),.tRCD     (tRCD    ),.tRP      (tRP     ),.tRC      (tRC     ),.tRAS     (tRAS    ),.tRRD     (tRRD    ),.tFAW     (tFAW    ),
.tWR      (tWR     ),.tWTR     (tWTR    ),.tRPT     (tRPT    ),.tCCD     (tCCD    ),.tDAL     (tDAL    ),.tMRD     (tMRD    ),.tMOD     (tMOD    ),
.tMPRR    (tMPRR   ),.ODTLon   (ODTLon  ),.ODTLoff  (ODTLoff ),.ODTH8    (ODTH8   ),.ODTH4    (ODTH4   ),.tWLMRD   (tWLMRD  ),.tWLDQSEN (tWLDQSEN),
.CL       (CL      ),.CWL      (CWL     ),.WR       (WR      ),.AL       (AL      ),.tDLLK    (tDLLK   ),.tRFC     (tRFC    ),.tREFI    (tREFI   ),
.tZQinit  (tZQinit ),.tZQoper  (tZQoper ),.tZQCS    (tZQCS   ),.tXPR     (tXPR    ),.tCKE     (tCKE    ),.tRTP     (tRTP    ),
// *** Dynamic outputs based on input switches.
.MR       (MRS) // MRS DDR3 Address input settings.
);



generate
// ******************************************************************************************************************************************
// ***  ALTERA/INTEL DDR PHY PORT ***********************************************************************************************************
// ******************************************************************************************************************************************
if (FPGA_VENDOR[0] == "A" || FPGA_VENDOR[0] == "a" || FPGA_VENDOR[0] == "I" || FPGA_VENDOR[0] == "i") begin 

//`include "BrianHG_DDR3_IO_PORT_ALTERA.sv"
BrianHG_DDR3_IO_PORT_ALTERA #(
    .FPGA_VENDOR     ( FPGA_VENDOR      ),  .FPGA_FAMILY     ( FPGA_FAMILY      ),  .CLK_KHZ_IN      ( CLK_KHZ_IN         ),
    .CLK_IN_MULT     ( CLK_IN_MULT      ),  .CLK_IN_DIV      ( CLK_IN_DIV       ),  .CMD_ADD_DLY     ( BHG_OPTIMIZE_SPEED ), 
    .DDR3_WDQ_PHASE  ( DDR3_WDQ_PHASE   ),  .DDR3_RDQ_PHASE  ( DDR3_RDQ_PHASE   ),  .BHG_EXTRA_SPEED ( BHG_EXTRA_SPEED    ),
    .DDR3_WIDTH_DQ   ( DDR3_WIDTH_DQ    ),  .DDR3_NUM_CHIPS  ( DDR3_NUM_CHIPS   ),  .DDR3_NUM_CK     ( DDR3_NUM_CK        ),
    .DDR3_WIDTH_ADDR ( DDR3_WIDTH_ADDR  ),  .DDR3_WIDTH_BANK ( DDR3_WIDTH_BANK  ),  .DDR3_WIDTH_CAS  ( DDR3_WIDTH_CAS     ),
    .DDR3_WIDTH_DM   ( DDR3_WIDTH_DM    ),  .DDR3_WIDTH_DQS  ( DDR3_WIDTH_DQS   ),  .DDR3_RWDQ_BITS  ( DDR3_RWDQ_BITS     )
) BHG_DDR3_IO_PORT_ALTERA (
    .RST_IN          ( RST_IN        ),     .DDR_CLK     ( DDR_CLK     ),     .DDR_CLK_WDQ ( DDR_CLK_WDQ    ),     .DDR_CLK_RDQ  ( DDR_CLK_RDQ  ),
    .RESET_n         ( RESET_n       ),     .CKE         ( CKE         ),     .CS_n        ( CS_n           ),     .RAS_n        ( RAS_n        ),
    .CAS_n           ( CAS_n         ),     .WE_n        ( WE_n        ),     .A           ( A              ),     .BA           ( BA           ),
    .WRITE           ( WRITE         ),     .READ        ( READ        ),     .WDATA       ( WDQ            ),     .WMASK        ( WDQM         ),
    .RDATA_toggle    ( PHY_RDATA_t   ),     .RDATA_store ( RDATA_store ),     .RDATA       ( PHY_RDATA      ),
    .DDR3_RESET_n    ( DDR3_RESET_n  ),     .DDR3_CK_p   ( DDR3_CK_p   ),     .DDR3_CK_n   ( DDR3_CK_n      ),     .ODT          ( ODT          ),
    .DDR3_CKE        ( DDR3_CKE      ),     .DDR3_CS_n   ( DDR3_CS_n   ),     .DDR3_RAS_n  ( DDR3_RAS_n     ),     
    .DDR3_CAS_n      ( DDR3_CAS_n    ),     .DDR3_WE_n   ( DDR3_WE_n   ),     .DDR3_ODT    ( DDR3_ODT       ),     
    .DDR3_A          ( DDR3_A        ),     .DDR3_BA     ( DDR3_BA     ),     .DDR3_DM     ( DDR3_DM        ),
    .DDR3_DQ         ( DDR3_DQ       ),     .DDR3_DQS_p  ( DDR3_DQS_p  ),     .DDR3_DQS_n  ( DDR3_DQS_n     ),

    .ODTLon (ODTLon), .ODTLoff (ODTLoff), .CWL (CWL+AL), .CL (CL+AL)
    );

// ***********************************
// *** End Initiate Altera DDR PHY ***
// ***********************************

// ******************************************************************************************************************************************
// ***  LATTICE DDR PHY ****************************************************************************************************************
// ******************************************************************************************************************************************
// end else if (FPGA_VENDOR[0] == "L" || FPGA_VENDOR[0] == "l") begin 


// ************************************
// *** End Initiate Lattice DDR PHY ***
// ************************************
// ******************************************************************************************************************************************
// ***  Xilinx DDR PHY ********************************************************************************************************************
// ******************************************************************************************************************************************
// end else if (FPGA_VENDOR[0] == "X" || FPGA_VENDOR[0] == "x") begin 


// ***********************************
// *** End Initiate Xilinx DDR PHY ***
// ***********************************
end else initial begin
// ******************************************************************************************************************************************
// ***  Unknown FPGA Vendor **************************************************************************************************************
// ******************************************************************************************************************************************
$warning("********************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ PARAMETER ERROR ***");
$warning("********************************************************************************");
$warning("*** BrianHG_DDR3_PHY_SEQ parameter .FPGA_VENDOR(\"%s\") is not supported. ***",FPGA_VENDOR);
$warning("*** Only supported vendors \"Altera\" or \"Intel\".                              ***");
$warning("********************************************************************************");
$error;
$stop;
end
endgenerate


// These are the output DDR3 command functions generated by this module.
// DDR3 command out wiring order {CS#,RAS#,CAS#,WE#}.
localparam bit [3:0] CMD_MRS  = 0  ;
localparam bit [3:0] CMD_REF  = 1  ;
localparam bit [3:0] CMD_PRE  = 2  ;
localparam bit [3:0] CMD_ACT  = 3  ;
localparam bit [3:0] CMD_WRI  = 4  ;
localparam bit [3:0] CMD_REA  = 5  ;
localparam bit [3:0] CMD_ZQC  = 6  ;
localparam bit [3:0] CMD_NOP  = 15 ; // Device NOP + deselect.

localparam bit [2:0] TXB_MRS  = 0 ;
localparam bit [2:0] TXB_REF  = 1 ;
localparam bit [2:0] TXB_PRE  = 2 ;
localparam bit [2:0] TXB_ACT  = 3 ;
localparam bit [2:0] TXB_WRI  = 4 ;
localparam bit [2:0] TXB_REA  = 5 ;
localparam bit [2:0] TXB_ZQC  = 6 ;
localparam bit [2:0] TXB_NOP  = 7 ; // Device NOP + deselect.

// ************************************************************************************************************************************************
// SEQ Command input processor.
// This module initiation takes in the SEQ_xxx command input and compares the selected bank & address.
// ************************************************************************************************************************************************
logic [DDR3_WIDTH_ADDR-1:0]  SEQ_RAS = 0 ;     // CMD -> DDR3 SEQ RAS
logic [DDR3_WIDTH_BANK-1:0]  SEQ_BANK= 0 ;     // CMD -> DDR3 SEQ Bank select
logic [DDR3_WIDTH_CAS-1:0]   SEQ_CAS = 0 ;     // CMD -> DDR3 SEQ CAS

always_comb begin
    if (BANK_ROW_ORDER=="BANK_ROW_COL") {SEQ_BANK,SEQ_RAS ,SEQ_CAS} = SEQ_ADDR[PORT_ADDR_SIZE-1:(DDR3_WIDTH_DM-1)] ;
    else                                {SEQ_RAS ,SEQ_BANK,SEQ_CAS} = SEQ_ADDR[PORT_ADDR_SIZE-1:(DDR3_WIDTH_DM-1)] ;
end

logic                         CMD_READY        ;
logic [DDR3_WIDTH_BANK-1:0]   CMD_BANK         ;
logic [DDR3_WIDTH_ADDR-1:0]   CMD_A            ;
logic [DDR3_RWDQ_BITS-1:0]    CMD_WDATA        ,TX_WDATA;
logic [DDR3_RWDQ_BITS/8-1:0]  CMD_WMASK        ,TX_WMASK;
logic [PORT_VECTOR_SIZE-1:0]  CMD_RDATA_VECTOR ;



logic [3:0] CMD_OUT,RX_CMD=0;
logic [7:0] CMD_TXB=0;
logic [7:0] TX_TXBs,TX_TXBi=0,TX_TXBil=0,TX_TXBil2=0;
logic       CMD_TX_BUSY,CMD_TX_BUSYi=0,CMD_RX_READY,CMD_TX_ENAs,CMD_TX_ENAi=0,CMD_TX_ENAil=0,CMD_TX_ENAil2=0,DDR3_READYl=0,DDR3_READYl2=0;
logic       DDR3_TX_BUSY,DDR3_TX_BUSY_l=0;


logic [DDR3_WIDTH_BANK-1:0]  TX_BANK,TX_BANKs,TX_BANKi=0,TX_BANKil=0,TX_BANKil2=0,RX_BANK ;
logic [DDR3_WIDTH_ADDR-1:0]  TX_ADDR,TX_ADDRs,TX_ADDRi=0,TX_ADDRil=0,TX_ADDRil2=0,RX_ADDR ;
logic [DDR3_RWDQ_BITS-1:0]   TX_WDQ ,TX_WDQs                                     ,RX_WDQ  ;
logic [DDR3_RWDQ_BITS/8-1:0] TX_WDM                                              ,RX_WDM  ;


logic SEQ_BUSY,SEQ_CMD_ENA,SEQ_CMD_ENA_tdl,REF_REQ_t,REF_ACK,CMD_IDLE;
logic RX_RDY,CMD_TX_FULL;
logic SEQ_CAL_PASSl=0,SEQ_CAL_PASSl2=0;
logic READ_CAL_PAT_t,READ_CAL_PAT_v,READ_CAL_PAT_s=0;

// This logic helps transfer the read data & toggle for FMAX help.
logic PHY_RDATA_t_dly;
always @(posedge DDR_CLK_50) PHY_RDATA_t_dly <= PHY_RDATA_t ;


BrianHG_DDR3_CMD_SEQUENCER #(
.USE_TOGGLE_ENA      ( USE_TOGGLE_CONTROLS ),     // When enabled, the (IN_ENA/IN_BUSY) & (OUT_READ_READY) toggle state to define the next command.
.USE_TOGGLE_OUT      ( 0                   ),     // When enabled, the (OUT_READY) & (OUT_ACK) use toggle state to define the next command.
.DDR3_WIDTH_BANK     ( DDR3_WIDTH_BANK     ),     // Use for the number of bits to address each bank.
.DDR3_WIDTH_ROW      ( DDR3_WIDTH_ADDR     ),     // Use for the number of bits to address each row.
.DDR3_WIDTH_CAS      ( DDR3_WIDTH_CAS      ),     // Use for the number of bits to address each column.
.DDR3_RWDQ_BITS      ( DDR3_RWDQ_BITS      ),     // Must equal to total bus width across all DDR3 ram chips *8.
.PORT_VECTOR_SIZE    ( PORT_VECTOR_SIZE    ),     // Set the width of the SEQ_RDATA_VECT_IN & SEQ_RDATA_VECT_OUT port, 1 through 64.
.BHG_EXTRA_SPEED     ( BHG_EXTRA_SPEED     )      // 1 = force read vector FIFO in logic cells, 0 = Allow compiler to infer vector FIFO into ram-blocks.
) CMD_SEQ (
.reset               ( !SEQ_CAL_PASSl2    ),     // The vector output fails if this module isn't reset during DDR3 initialization.
.CLK                 ( DDR_CLK_50         ),
.IN_ENA              ( SEQ_CMD_ENA_t      ),     // May be a toggle based on parameter setting.
.IN_BUSY             ( SEQ_BUSY_t         ),     // Sent back to the main command inputs, may be a toggle based on parameter setting.
.IN_WENA             ( SEQ_WRITE_ENA      ),
.IN_BANK             ( SEQ_BANK           ),
.IN_RAS              ( SEQ_RAS            ),
.IN_CAS              ( SEQ_CAS            ),
.IN_WDATA            ( SEQ_WDATA          ),
.IN_WMASK            ( SEQ_WMASK          ),
.IN_RD_VECTOR        ( SEQ_RDATA_VECT_IN  ),

.OUT_ACK             ( !DDR3_TX_BUSY      ),     // Tells internal fifo to send another command to the sequencer
.OUT_READY           ( CMD_READY          ),
.OUT_CMD             ( CMD_OUT            ),     // DDR3 command out wiring order {CS#,RAS#,CAS#,WE#}.
.OUT_TXB             ( CMD_TXB            ),     // DDR3 command out command signal bit order {nop,zqc,rea,wri,act,pre,ref,mrs}.
.OUT_BANK            ( CMD_BANK           ),
.OUT_A               ( CMD_A              ),
.OUT_WDATA           ( CMD_WDATA          ),
.OUT_WMASK           ( CMD_WMASK          ),

.IN_READ_RDY_t       ( PHY_RDATA_t_dly    ),     // This input is always a toggle since it comes from the DDR3_RDQ clock domain.
.IN_READ_DATA        ( PHY_RDATA          ),
.OUT_READ_READY      ( SEQ_RDATA_RDY_t    ),
.OUT_READ_DATA       ( SEQ_RDATA          ),
.OUT_RD_VECTOR       ( SEQ_RDATA_VECT_OUT ),

.IN_REFRESH_t        ( REF_REQ_t          ),     // This input is always a toggle since it comes from the CLK_IN clock domain.
.OUT_REFRESH_ack     ( REF_ACK            ),     // This output is always a toggle since it is designed to feed logic in the CLK_IN clock domain.
.OUT_IDLE            ( CMD_IDLE           ),

.READ_CAL_PAT_t      ( READ_CAL_PAT_t     ),    // Toggles after every read once the READ_CAL_PAT_v data is valid.
.READ_CAL_PAT_v      ( READ_CAL_PAT_v     )     // Valid read cal pattern detected in read.
);

 
logic TX_RDY=0;

// Convert the 50MHz CLK_IN domain to the 300MHz DDR_CLK domain via a few steps.
always @(posedge DDR_CLK_50)  {TX_TXBil,TX_BANKil,TX_ADDRil} <= {TX_TXBi,TX_BANKi,TX_ADDRi};
always @(posedge DDR_CLK_50)  CMD_TX_ENAil                   <= CMD_TX_ENAi;
always @(posedge DDR_CLK_50)  DDR3_READYl                    <= DDR3_READY;
always @(posedge DDR_CLK_50)  {TX_TXBil2,TX_BANKil2,TX_ADDRil2} <= {TX_TXBil,TX_BANKil,TX_ADDRil};
always @(posedge DDR_CLK_50)  CMD_TX_ENAil2                   <= CMD_TX_ENAil;
always @(posedge DDR_CLK_50)  DDR3_READYl2                    <= DDR3_READYl;
always @(posedge DDR_CLK_50)  SEQ_CAL_PASSl  <= SEQ_CAL_PASS;
always @(posedge DDR_CLK_50)  SEQ_CAL_PASSl2 <= SEQ_CAL_PASSl;

// Select the command source, either the power-up initialization controls, or the main controller system
always_comb  TX_RDY                                       = DDR3_READYl2 ?  CMD_READY                                   : (CMD_TX_ENAil2 ^ CMD_TX_ENAil) ;
always_comb {TX_TXBs,TX_BANKs,TX_ADDRs,TX_WDATA,TX_WMASK} = DDR3_READYl2 ? {CMD_TXB,CMD_BANK,CMD_A,CMD_WDATA,CMD_WMASK} : {TX_TXBil2,TX_BANKil2,TX_ADDRil2,CMD_WDATA,CMD_WMASK} ;


// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
//
// The following section receives the 'RX_CMD[x]' input from the BrianHG_DDR3_CMD_SEQUENCER and waits for the chosen command's count down
// timer to finish before it sends the command.
//
// New to Ver.0.95, this section now operates at the DDR_CLK_50 speed and passes the command and timer's remainder bits through a FIFO to
// the DDR_CLK domain.
//
//
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************

localparam bit [1:0] SPEED_SHIFT = 2 ; // Denotes the size of the timer count steps in each timer before the remainder for each command is sent out.

localparam int               tcGMSB       = 10 ;                      // this is the MSB negative bit for the long length global 'GTIMER' command timer.
logic [tcGMSB:0]             tcGTIMER     = 0  ;                      // This one Large Timer is for the large time after a refresh an write leveling.
logic                        GTIMER       = 0  ;                      // Extra flip-flop stage latching 'tcGTIMER' msb, YES, this does help FMAX.
logic                        GTIMER_float = 0  ;                      // Used to calculate the remainder in the global timer when counting down by 4 each clock.
logic                        shift_timer      = 0 ;
logic                        CMD_shift_timer  = 0 ;
logic                        DDR3_shift_timer = 0 ;

localparam int                msbREF       = 30 -1 ;  //  Max 30  // this is the MSB negative bit for all the small tc*** command timers.
localparam int                msbPRE       = 34 -1 ;  //  Max 34  // this is the MSB negative bit for all the small tc*** command timers.
localparam int                msbACT       = 7  -1 ;  //  Max 7   // this is the MSB negative bit for all the small tc*** command timers.
localparam int                msbWRI       = 14 -1 ;  //  Max 14  // this is the MSB negative bit for all the small tc*** command timers.
localparam int                msbREA       = 22 -1 ;  //  Max 22  // this is the MSB negative bit for all the small tc*** command timers.

logic              [msbREF:0] tcREFRESH    = 0 ;                        // Max 30 Counts down until a REFRESH is permitted.
logic              [msbPRE:0] tcPRECHARGE  = 0 ;                        // Max 34 Counts down until a PRECHARGE is permitted.
logic              [msbACT:0] tcACTIVATE   = 0 ;                        // Max 7  Counts down until a ACTIVATE is permitted.
logic              [msbWRI:0] tcWRITE      = 0 ;                        // Max 14 Counts down until a WRITE command is permitted.
logic              [msbREA:0] tcREAD       = 0 ;                        // Max 22 Counts down until a READ command is permitted.


logic TX_CMD_tdl=0,TX_CMD_t=0,DDR3_TX_FIFO_FULL;
logic [3:0] TX_CMD ;

// **************************************************************************************
// Generate a busy flag based on command request in and it associated allowance timer.
// **************************************************************************************
always_comb begin
    DDR3_TX_BUSY =  (!GTIMER ||
                     (TX_TXBs[TXB_PRE] && tcPRECHARGE[SPEED_SHIFT]) ||   
                     (TX_TXBs[TXB_REF] && tcREFRESH  [SPEED_SHIFT]) ||   
                     (TX_TXBs[TXB_ACT] && tcACTIVATE [SPEED_SHIFT]) ||   
                     (TX_TXBs[TXB_REA] && tcREAD     [SPEED_SHIFT]) ||   
                     (TX_TXBs[TXB_WRI] && tcWRITE    [SPEED_SHIFT])    );
    end

always_ff @(posedge DDR_CLK_50) begin
DDR3_TX_BUSY_l <= DDR3_TX_BUSY;       // used for CLK_IN section.
reset_latch    <= RST_IN;
reset_latch2   <= reset_latch ;
if (reset_latch2) begin
        //TX_CMD   <= CMD_NOP   ;
        //TX_CMD_t <= !TX_CMD_t ;     // Toggle the command strobe.
        DDR3_TX_CMD(CMD_NOP);
end else begin

    // When ready, send out selected command to the PHY DDR IO pin driver.
    if (GTIMER && TX_RDY)   begin
                                 if (TX_TXBs[TXB_MRS]                             ) DDR3_TX_CMD(CMD_MRS);
                            else if (TX_TXBs[TXB_PRE] && !tcPRECHARGE[SPEED_SHIFT]) DDR3_TX_CMD(CMD_PRE);
                            else if (TX_TXBs[TXB_REF] && !tcREFRESH  [SPEED_SHIFT]) DDR3_TX_CMD(CMD_REF);
                            else if (TX_TXBs[TXB_ACT] && !tcACTIVATE [SPEED_SHIFT]) DDR3_TX_CMD(CMD_ACT);
                            else if (TX_TXBs[TXB_REA] && !tcREAD     [SPEED_SHIFT]) DDR3_TX_CMD(CMD_REA);
                            else if (TX_TXBs[TXB_WRI] && !tcWRITE    [SPEED_SHIFT]) DDR3_TX_CMD(CMD_WRI);
                            else if (TX_TXBs[TXB_ZQC]                             ) DDR3_TX_CMD(CMD_ZQC);
                            else                                                    DDR3_TX_CMD(CMD_NOP); // No command present but the ready flag was set.
                    end else    SET_TIMERS ( 0    , 0  , 0  , 0  , 0  , 0  ) ;   // Nothing to set, just decrement the timers.                                                    DDR3_TX_CMD(CMD_NOP); // No ready flag or GTIMER isn't ready.

  end // !reset
end // always

// ******************************************************************
// Transmit the selected command to the PHY DDR IO pin driver and
// set all the allowance timers for when each of their commands
// are next permitted.
// ******************************************************************
task DDR3_TX_CMD (bit [3:0] tx_cmd);
begin

    TX_CMD   <= tx_cmd; // Send out the command to the DDR3 command bus.
    TX_BANK  <= TX_BANKs  ;
    TX_ADDR  <= TX_ADDRs  ;
    TX_WDQ   <= TX_WDATA ;
    TX_WDM   <= TX_WMASK ;

    case (tx_cmd)                      // Set allowance timers, generate ODT and READ/WRITE flags based on tx_command.
    CMD_NOP :       begin
                    //          GTIMER,REFR,PRE ,ACTI,WRIT,READ      -> Set time until these commands are permitted.
                    SET_TIMERS ( 0    , 0  , 0  , 0  , 0  , 0  ) ;   // Nothing to set, just decrement the timers.
                    CMD_shift_timer <= 1'd0      ;                        // Nope should delay 4 clocks.
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end         
            
    CMD_MRS :       begin
                    //          GTIMER,REFR,PRE ,ACTI,WRIT,READ      -> Set time until these commands are permitted.
                    SET_TIMERS ( tMOD , 0  , 0  , 0  , 0  , 0  ) ;   // Set timers
                    CMD_shift_timer <= GTIMER_float ;
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end         
            
    CMD_PRE :       begin // PRECHARGE 1 bank.          
                    //          GTIMER,REFR,PRE ,ACTI,WRIT,READ      -> Set time until these commands are permitted.
                    SET_TIMERS ( tRP  , 0  , 0  , 0  , 0  , 0  ) ;   // Set timers
                    CMD_shift_timer <= GTIMER_float | (tcPRECHARGE[1]) ;
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end

    CMD_REF  :      begin // REFRESH.                               
                    //          GTIMER,REFR,PRE ,ACTI,WRIT,READ      -> Set time until these commands are permitted.
                    SET_TIMERS (tRFC  , 0  , 0  , 0  , 0  , 0  ) ;   // Set timers
                    CMD_shift_timer <= GTIMER_float | (tcREFRESH[1]) ;
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end

    CMD_ACT  :      begin // Activate a bank.  *** Note that tFAW will not be checked in this memory controller since new bank openings are always spaced far enough apart.
                    //          GTIMER,REFR,PRE ,ACTI,WRIT,READ      -> Set time until these commands are permitted.
                    SET_TIMERS ( 0    ,tRCD,tRAS,tRRD,tRCD,tRCD) ;   // Set timers
                    CMD_shift_timer <= GTIMER_float | (tcACTIVATE[1]) ;
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end

    CMD_WRI  :      begin // Write burst length 8
                    //          GTIMER       ,REFR         ,PRE          ,ACTI ,WRIT             ,READ             -> Set time until these commands are permitted.
                    SET_TIMERS ( 0           ,CWL+AL+4+tWR ,CWL+AL+4+tWR , 0   ,4                ,CWL+AL+4+tWTR) ; // Set timers
                    CMD_shift_timer <= GTIMER_float | (tcWRITE[1]) ;
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end

    CMD_REA  :      begin // Read burst length 8
                    //          GTIMER       ,REFR         ,PRE          ,ACTI ,WRIT             ,READ              -> Set time until these commands are permitted.
                    SET_TIMERS ( 0           ,tRTP+AL      ,tRTP+AL      , 0   ,CL+AL+6-(CWL+AL) ,4             ) ; // Set timers
                    CMD_shift_timer <= GTIMER_float | (tcREAD[1]) ;
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end

    CMD_ZQC  :      begin // ZQCL calibration.                               
                    //          GTIMER ,REFR   ,PRE    ,ACTI   ,WRIT   ,READ            -> Set time until these commands are permitted.
                    SET_TIMERS (tZQinit, 0     , 0     , 0     , 0     , 0     ) ;      // Set timers
                    CMD_shift_timer <= GTIMER_float ;
                    TX_CMD_t        <= !TX_CMD_t ;                   // Toggle the command strobe.
                    end
    endcase
end
endtask

// **********************************************************************
// Timer logic.  Each timer counts down until that command is permitted.
// Each command sent fills each timer with their minimum time.
// An input of 0 just means count down, any other number sets the timer.
// **********************************************************************
task SET_TIMERS (logic [tcGMSB:0] z, logic [5:0] a   ,b  ,c   ,d   ,e   );
//                             GTIMER,         REFR,PRE,ACTI,WRIT,READ -> Set time until these commands are permitted.
begin

    // Set the large 'GLOBAL' timer.  This timer is typically used for the REFRESH, ZQC and MRS tMOD delays as these delays prevent every other command
    // from being executed.

    if ( z== 0 && !tcGTIMER [tcGMSB]) tcGTIMER      <= tcGTIMER   - SPEED_SHIFT ; // A down counter which stops at -1.
    else if ( z!= 0 )                 tcGTIMER      <= z-3'd3                   ; // Must subtract 3 due to counting down to -1 and the 1 additional
    if ( z!= 0 )                      GTIMER        <= 0;                         // clock delay in this second latch stage 'GTIMER'
    else begin

                                      GTIMER        <= tcGTIMER[tcGMSB] || (tcGTIMER <= (SPEED_SHIFT-1)) ;  // Extra flip-flop stage, YES, this does help FMAX.
                                      GTIMER_float  <= tcGTIMER[tcGMSB] ? 1'd0 : 1'd1 ;           // 
    end

    // Small serial shift timers.  These right-shift timers are 'OR' filled with a selected width of ones when being set,
    // otherwise they shift out those ones every DDR3 CK cycle.  This allows the overlapping of transmitted 
    // commands, some with larger and smaller permitted times until the next timer's chosen command is permitted.  This was done
    // to prevent adding the logic of when setting a timer to see if the new setting is 'less than' the current count
    // position so it should not take place.  Such an 'IF' comparison on a normal counter running on slower Altera's Cyclone/Max 10
    // would have added difficulty achieving the desired > 300MHz performance.
    tcREFRESH   [msbREF:0]   <= (msbREF+1)'(tcREFRESH  [msbREF:SPEED_SHIFT] | (2**(a)-1)) ;
    tcPRECHARGE [msbPRE:0]   <= (msbPRE+1)'(tcPRECHARGE[msbPRE:SPEED_SHIFT] | (2**(b)-1)) ;
    tcACTIVATE  [msbACT:0]   <= (msbACT+1)'(tcACTIVATE [msbACT:SPEED_SHIFT] | (2**(c)-1)) ;
    tcWRITE     [msbWRI:0]   <= (msbWRI+1)'(tcWRITE    [msbWRI:SPEED_SHIFT] | (2**(d)-1)) ;
    tcREAD      [msbREA:0]   <= (msbREA+1)'(tcREAD     [msbREA:SPEED_SHIFT] | (2**(e)-1)) ;

end
endtask



// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
//
// DDR_CLK domain sequencer
//
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
localparam   fifo_bits = ( 1 + 4 + DDR3_WIDTH_BANK + DDR3_WIDTH_ADDR + DDR3_RWDQ_BITS + (DDR3_RWDQ_BITS/8) );

logic        RX_ACK ;

always @(posedge DDR_CLK)  TX_CMD_tdl        <= TX_CMD_t  ;

always_comb {DDR3_shift_timer,RX_CMD, RX_BANK, RX_ADDR, RX_WDQ, RX_WDM } = {CMD_shift_timer ,TX_CMD,TX_BANK,TX_ADDR,TX_WDQ,TX_WDM } ;
always_comb  RX_RDY = (TX_CMD_tdl != TX_CMD_t) ;

// These 2 lines below may help FMAX above 400MHz in place of the 2 lines above.

//always @(posedge DDR_CLK) {DDR3_shift_timer,RX_CMD, RX_BANK, RX_ADDR, RX_WDQ, RX_WDM } <= {CMD_shift_timer ,TX_CMD,TX_BANK,TX_ADDR,TX_WDQ,TX_WDM } ;
//always @(posedge DDR_CLK)  RX_RDY <= (TX_CMD_tdl != TX_CMD_t) ;

// ******************************************************************
// Transmit the selected command to the PHY DDR IO pin driver and
// set all the allowance timers for when each of their commands
// are next permitted.
// ******************************************************************
logic [5:0] ODT_GEN_REG = 0;
always_comb ODT = ODT_GEN_REG[0] ;

always @(posedge DDR_CLK) begin

    TX_ADDR_DAT();

    if ( shift_timer ) begin
                                                //TX_ADDR_DAT();
                                                DDR3_TX (RX_CMD) ;
                                                shift_timer <= 0 ;
    end else if (!RX_RDY)                     begin
                                                DDR3_TX (CMD_NOP) ;
                                                shift_timer <= 1'b0 ;
    end else if (!DDR3_shift_timer) begin
                                                //TX_ADDR_DAT();
                                                DDR3_TX (RX_CMD) ;
                                                shift_timer <= 0 ;
    end else begin
                                                DDR3_TX (CMD_NOP) ;
                                                shift_timer <= 1'b1 ;
    end

end

// ******************************
// Send commands to IO ports.
// ******************************
task DDR3_TX (bit [3:0] tx_cmd);
begin
{CS_n,RAS_n,CAS_n,WE_n} <= tx_cmd ;
    case (tx_cmd)
    default  :      GEN_ODT(0);               // Count down the ODT output.
    CMD_WRI  :      begin                     // Write burst length 8
                    WRITE  <= !WRITE ;
                    GEN_ODT(ODTH8);           // Set the ODT output length to be generated.
                    end
    CMD_REA  :      begin                     // Read burst length 8
                    READ   <= !READ ;
                    GEN_ODT(0);               // Count down the ODT output.
                    end
    endcase

end
endtask


// *******************************************************************************
// Transmit address and write data.
// *******************************************************************************
task TX_ADDR_DAT();
begin
    BA    <= RX_BANK ;
    A     <= RX_ADDR ;
    WDQ   <= RX_WDQ  ;
    WDQM  <= RX_WDM  ;
end
endtask

// *******************************************************************************
// Generate the ODT signal with the width of 'a', otherwise shift it's timer down.
// *******************************************************************************
task GEN_ODT( logic [3:0] a );
begin
    ODT_GEN_REG[5:0] <= {1'b0,ODT_GEN_REG[5:1]} | (6'(2**a-1)) ;
end
endtask



// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
//
// Refresh request generator.
//
//
// The 'REF_REQ_t' output request is a '_toggle' meaning it holds 1 state, then flips it's value and holds that state to request
// a single refresh.  It will flip again when it requires another refresh.
//
// The 'REF_ACK' input is also a toggle.  It toggles (IE: becomes equal to the 'REF_REQ_t' output) once every time a refresh has been executed.
//
// The 'CMD_IDLE' comes from the sequencer and it goes high if there is inactivity for 32 x DDR_CLK_50 consecutive clocks.
//
//
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************


localparam bit [7:0]  ns100_TIME        = 8'(CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV/40000) ; // The period for a counter which generates 100ns speed timer.  IE: 10MHz clock.
logic          [7:0]  ns100_TIMER       = 0 ;
logic         [13:0]  tcREFI            = 0 ;
logic          [7:0]  IDLE_TIMER        = 0 ;

logic                 REF_ACK_i,CMD_IDLE_i,REFRESH_low_pri,REFRESH_hi_pri,refresh_in_progress;

always_comb  REFRESH_low_pri     = (SEQ_refresh_queue !=0) ;                   // Perform a refresh when there are no SEQ_CMD_ENA_t requests.
always_comb  REFRESH_hi_pri      = (SEQ_refresh_queue >= DDR3_MAX_REF_QUEUE) ; // Perform a refresh on the next free DDR3 cycle.
always_comb  refresh_in_progress = REF_REQ_t != REF_ACK_i ;                    // This remains high until the refresh request has been executed by the sequencer.


always_ff @(posedge DDR_CLK_25) begin
if (RST_IN || !DDR3_READY) begin

    REF_REQ_t         <= 0 ;
    REF_ACK_i         <= 0 ;
    CMD_IDLE_i        <= 0 ;

    ns100_TIMER       <= 8'(ns100_TIME - 2) ;
    tcREFI            <= 14'(tREFI-2)       ;
    IDLE_TIMER        <= 8'(IDLE_TIME_uSx10-2);
    SEQ_refresh_queue <= 6 ;

end else begin

    // Convert and latch inputs from the DDR_CLK_50 clock domain to the local clock domain.
    REF_ACK_i         <= REF_ACK  ; 
    CMD_IDLE_i        <= CMD_IDLE ;


    if (!ns100_TIMER[7]) ns100_TIMER   <=  ns100_TIMER - 1'b1 ;      // Synthesize a continuous 10MHz timer.  (100ns period)
    else                 ns100_TIMER   <= 8'(ns100_TIME - 2)  ;      // ns100_TIMER[7] holds the 'tick' or increment of this clock.
                                                                     // **** We use '-2' since we are counting to '-1' instead of '0'.


    if (ns100_TIMER[7] && !tcREFI[13])  tcREFI <=  tcREFI -1'b1;     // This is the large countdown timer used for the maximum average periodic refresh timer.


    // Generate the idle timer to identify when low priority refreshes will be permitted.
         if (!CMD_IDLE_i)                       IDLE_TIMER <= 8'(IDLE_TIME_uSx10-1);
    else if (ns100_TIMER[7] && !IDLE_TIMER[7])  IDLE_TIMER <= IDLE_TIMER - 1'b1 ;


    if (tcREFI[13]) begin
                                                   tcREFI            <= 14'(tREFI-1) ;              // Set tcREFI timer to the Maximum average periodic refresh time.
                        if (SEQ_refresh_queue!=31) SEQ_refresh_queue <= SEQ_refresh_queue + 1'b1 ;  // saturation counter up to 31.
    end


    // Send out a refresh request.
    if ( ((REFRESH_low_pri && IDLE_TIMER[7]) || REFRESH_hi_pri) && !refresh_in_progress && !tcREFI[13]) begin      // The '!tcREFI[13]' makes sue the following will wait 1 clock
                                                                                                                   // after the SEQ_refresh_queue above has been incremented.

                                                                    REF_REQ_t         <= !REF_REQ_t ;              // Toggle the refresh output to send a refresh request.
                                                                    SEQ_refresh_queue <= SEQ_refresh_queue - 1'b1; // Remove 1 refresh from the refresh queue
                                                                    end

  end // !reset && DDR3_READY.
end // always


// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
//
// Power-up initialization and calibration sequencer.
//
// Operates on the slow 25-100MHz 'CLK_IN' clock which should be set in the .sdc file to either have a 'false' path between it's CLK_IN and the
// DDR3_CLK, or a multicycle setup time of 2 clocks + a hold time of 1, in both directions.  This will greatly help FMAX on slower FPGAs.
//
// All these measures are taken to give the FPGA compiler the best chance of achieving the best possible FMAX for the DDR3 command sequencer logic.
//
// All signals between this clock domain and the DDR3_CLK will be below 10MHz and will be held for 2 clocks with a command enable which will be
// delayed by 1 clock after all the command controls have been setup.  This is done to ensure meta-stability on the slowest routes.
//
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************

always_comb begin  // Always select these MRS presets.
DDR3_dll_disable     = 0 ;
DDR3_write_leveling  = 0 ;
DDR3_dll_reset       = 1 ;
end

localparam bit [7:0]  us_TIME       = 8'(CLK_KHZ_IN*CLK_IN_MULT/CLK_IN_DIV/4000)  ; // The period for a counter which generates 1us speed timer.  IE: 1MHz clock.
logic [7:0]           us_TIMER      = 0 ;                    // This is the counter which generates the slow timer.
logic [11:0]          init_pc       = 0 ;                    // The sequence program counter with 2048 lines.
logic                 high_speed    = 0 ;
logic                 CMD_TX_ENAint = 0 ;

logic [2:0]           RDCAL_pos     = 0, PLL_OFFSET ;        // Read calibration tuning position.
logic [11:0]          return1       = 0 ;                    // Sub routine return positions for sequencer program counter.
logic [7:0]           loop1         = 0 ;                    // Generic variables to count loops in sequencer.
logic                 RDCAL_bit=0,RDCAL=0,RDCAL_clr=0,READ_CAL_t=0,READ_CAL_tdl=0;
logic [7:0]           RDCAL_d       = 8'hFF ;                // Internal copy of the RDCAL_data.

logic DDR3_TX_BUSY_l2=0;
always_ff @(posedge DDR_CLK_25) DDR3_TX_BUSY_l2 <= DDR3_TX_BUSY_l; // Provide an additional clock domain boundary step to help FMAX.

always_ff @(posedge DDR_CLK_50) RESET_n_int2    <= RESET_n_int   ;
always_ff @(posedge DDR_CLK_50) CKE_int2        <= CKE_int       ;
always_ff @(posedge DDR_CLK)    RESET_n         <= RESET_n_int2  ;
always_ff @(posedge DDR_CLK)    CKE             <= CKE_int2      ;

always_ff @(posedge DDR_CLK_25) begin

// ***********************************************************************
// Monitor the transition of the read_calibration toggle activity flag,
// transfer the data and generate the activity status detector.
// ***********************************************************************
     READ_CAL_t   <= READ_CAL_PAT_t   ;                      // Transfer the toggle flag on the DDR_CK_50 domain to the local clock domain
     READ_CAL_tdl <= READ_CAL_t       ;                      // latch a delay of that toggle flag
     RDCAL        <= READ_CAL_PAT_v   ;                      // Transfer the cal valid detector data to from the DDR_CK_50 clock domain to the local clock domain

     if (RDCAL_clr)                   READ_CAL_PAT_s <= 0 ;  // Reset the read cal status flag if the clear is being sent,
else if (READ_CAL_t != READ_CAL_tdl)  READ_CAL_PAT_s <= 1 ;  // otherwise set the status flag if a read cal toggle is detected.


if (RST_IN) begin

    RESET_n_int         <= 0 ;
    CKE_int             <= 0 ;
    SEQ_CAL_PASS        <= 0 ;
    DDR3_READY          <= 0 ;
    DDR3_read_leveling  <= 0 ;

	 
    CMD_TX_ENAi         <= 0 ;
    CMD_TX_ENAint       <= 0 ;
    TX_TXBi             <= 0 ;
    TX_BANKi            <= 0 ;
    TX_ADDRi            <= 0 ;

    init_pc             <= 0 ;
    high_speed          <= 0 ;

    RDCAL_clr           <= 0 ;
    RDCAL_d             <= 8'hFF ;   // Preset the 16 bits of the read cal PLL tuning position test register
    RDCAL_data          <= 0     ;   // Preset the 16 bits of the read cal PLL tuning position test register
    RDCAL_pos           <= 3'd6  ;   // Store the starting PLL test position
    phase_step          <= 0 ;       // PLL tuning controls.
    phase_updn          <= 0 ;

end else begin

        CMD_TX_BUSYi        <= DDR3_TX_BUSY_l2 ;                   // A direct busy flag to wait for all commands to complete.
        CMD_TX_ENAi         <= CMD_TX_ENAint  ;                    // Delay the command execute out by 1 clock.

        // Synthesize a 1us or 100ns timer.
        if (!us_TIMER[7])     us_TIMER   <=  us_TIMER - 1'b1    ;  // Synthesize a continuous 1 microsecond timer.
        else if (!high_speed) us_TIMER   <= 8'(us_TIME - 2)     ;  // us_TIMER[7] holds the 'tick' or increment of this clock, unless 'high_speed' is enabled where where is will stay high.
        //else                  us_TIMER   <= 8'(ns100_TIME - 2)  ;  // **** We use '-2' since we are counting to '-1' instead of '0'.

// *************************************************************
// Power-up initialization and calibration program.
// *************************************************************
if ( us_TIMER[7] && !CMD_TX_BUSYi ) begin    // Every command in this sequencer is timed base on the us_TIMER, and it will only run while the DDR3's CMD_TX isn't busy.
    case (init_pc)

        default : init_pc <= init_pc + 1'b1 ;                             // Auto increment the program counter if there is no instruction 'case' number.

        0    : begin // Reset...
                                    RESET_n_int         <= 0 ;
                                    CKE_int             <= 0 ;
                                    SEQ_CAL_PASS        <= 0 ;
                                    DDR3_READY          <= 0 ;
                                    DDR3_read_leveling  <= 0 ;

                                    CMD_TX_ENAi         <= 0 ;
                                    CMD_TX_ENAint       <= 0 ;
                                    TX_TXBi             <= 0 ;
                                    TX_BANKi            <= 0 ;
                                    TX_ADDRi            <= 0 ;

                                    init_pc             <= 1 ;
                                    high_speed          <= 0 ;

                                    RDCAL_clr           <= 0 ;
                                    RDCAL_d             <= 8'hFF ;   // Preset the 16 bits of the read cal PLL tuning position test register
                                    RDCAL_data          <= 0     ;   // Preset the 16 bits of the read cal PLL tuning position test register
                                    RDCAL_pos           <= 3'd6  ;   // Store the starting PLL test position
                                    phase_step          <= 0 ;       // PLL tuning controls.
                                    phase_updn          <= 0 ;
               end

        1    : begin
                if (SKIP_PUP_TIMER) init_pc       <= 600 ;                // Skip 600us wait.
                else                init_pc       <= init_pc + 1'b1 ;     // Wait 600us
               end

        600  : begin
                                    RESET_n_int   <= 1 ;                  // Turn off reset.
                if (SKIP_PUP_TIMER) init_pc       <= 1195 ;               // Skip 600us wait.
                else                init_pc       <= init_pc + 1'b1 ;     // Wait 600us.
               end

        1195 : begin
                                    CKE_int       <= 1 ;                  // Turn on CKE.
                                    init_pc       <= init_pc + 1'b1 ;
               end

        1200 : begin
                                    high_speed    <= 1 ;                  // Last of the low speed 1MHz counter steps, now running at 50MHz.
                                    SET_mrs (2);                          // Prep MR2 command.
               end
        1204 :                      SET_mrs (3);                          // Prep MR3 command.
        1208 :                      SET_mrs (1);                          // Prep MR1 command.
        1212 :                      SET_mrs (0);                          // Prep MR0 command.
        1216 :                      RUN_ZQCL ();                          // Prep ZQCL command.

        1220 : begin
                                    DDR3_read_leveling  <= 1'b1;          // Change the MR3 read leveling feature to ENABLE
                                    RUN_NOP ();
               end

        1224 :                      SET_mrs (3);                          // Prep MR3 command.

        // ***********************************************************************
        // Read Cal test PLL tuning steps and store them in RDCAL_data[7:0]
        // Step 1, if the RDCAL_bit = 1, shift down until it becomes 0.
        // ***********************************************************************
        1225 : begin
                                    RDCAL_data  <= 1 ;                    // announce the program position to the debug port output.
                                    init_pc <= init_pc + 1'b1;
               end

        1226 :                      CALL_TEST_RDCAL ();                   // DDR3 read calibration command loop, store the result in RDCAL_data[RDCAL_pos]
        1227 : begin
               if (RDCAL_bit==0)    init_pc <= 1230;
               else                 init_pc <= init_pc + 1'b1;
               end
        1228 :                      CALL_SHIFT_PLL  (1, 0);               // Shift down by 1
        1229 :                      init_pc <= 1226;                      // Goto the read cal test again.

        // ***********************************************************************
        // Read Cal test PLL tuning steps and store them in RDCAL_data[7:0]
        // Step 2, shift tune up until the read cal becomes true.
        // ***********************************************************************
        1230 : begin
                                    RDCAL_data  <= 2 ;                    // announce the program position to the debug port output.
                                    init_pc <= init_pc + 1'b1;
               end

        1231 :                      CALL_TEST_RDCAL ();                   // DDR3 read calibration command loop, store the result in RDCAL_data[RDCAL_pos]
        1232 : begin
               if (RDCAL_bit==1)    init_pc <= 1235;
               else                 init_pc <= init_pc + 1'b1;
               end
        1233 :                      CALL_SHIFT_PLL  (1, 1);               // Shift up by 1
        1234 :                      init_pc <= 1231;                      // Goto the read cal test again.

        // ***********************************************************************
        // Read Cal test PLL tuning steps and store them in RDCAL_data[7:0]
        // Step 3, shift tune up recording the RDCAL_bit into RCAL_data
        // ***********************************************************************
        1235 : begin
                                    RDCAL_data  <= 3 ;                    // announce the program position to the debug port output.
                                    init_pc <= init_pc + 1'b1;
               end
        1236 :                      CALL_SHIFT_PLL  (1, 1);                // Shift up by 1.
        1237 :                      CALL_TEST_RDCAL ();                    // DDR3 read calibration command loop, store the result in RDCAL_data[RDCAL_pos]
        1238 : begin
                                    RDCAL_d[RDCAL_pos]    <= RDCAL_bit ;
                                    init_pc               <= init_pc + 1'b1; 
               end
        1239 : begin
                                    if (RDCAL_pos==0) init_pc      <= init_pc + 1'b1;     // Tested all 7 positions, break this loop.
                                    else begin
                                                      RDCAL_pos    <= RDCAL_pos - 1'b1 ;  // Subtract test position location pointer.
                                                      init_pc      <= 1236 ;              // Go back and test the next PLL tuning position.
                                         end
               end
        // ***********************************************************************************************
        // Based on the image in RDCAL_d[7:0], tune the PLL to the center of the valid data position
        // ***********************************************************************************************

        1240 : begin
                                    RDCAL_data    <= RDCAL_d ;              // Set the RCAL_data output to the read source.
                                    if (PLL_OFFSET==0) init_pc  <= 0 ;      // Unknown PLL image, reset...
                                    else               init_pc  <= init_pc + 1'b1 ;
               end
        1241 :                      CALL_SHIFT_PLL  (PLL_OFFSET, 0);        // Shift down the correct amount to land center in the optimum PLL tuning location.

        // *******************************************
        // Finish the power-up initialization.
        // *******************************************
        1244 : begin
                                    DDR3_read_leveling  <= 1'b0;          // Change the MR3 read leveling feature to Disable
                                    RUN_NOP ();
               end
        1248 :                      SET_mrs (3);                          // Prep MR3 command.


        1252 :                      RUN_NOP ();


        1256 : begin
                                    CMD_TX_ENAi   <= 0 ;                  // Clear the CMD_TX toggle.  This may execute another NOP, but it will prevent 
                                    init_pc       <= init_pc + 1'b1 ;     // a possible execution of an instruction when switching over to the main DDR3 controller.
               end
        1260 : begin
                                    SEQ_CAL_PASS  <= (RDCAL_d[6:0] != 0) ;  // Set the SEQ_CAL_PASS if more than 1 single bit was a 1.
                                    init_pc       <= init_pc + 1'b1 ;
               end

        1264 :                      DDR3_READY    <= 1 ;                  // Stop here, the system is ready to be used.

        // ***********************************************************************************************


// **********************************************************************************
// Read calibration sub-loop
// repeat multiple times to discover is a weak bit exists
// **********************************************************************************

        (1500+000): begin
                                            RDCAL_bit     <= 1 ;               // preset the read cal bit
                        if (SKIP_PUP_TIMER) loop1         <= 0     ;           // Set the number of read cals to be done to confirm a good PLL tuning.
                        else                loop1         <= 255   ;
                                            init_pc       <= init_pc + 1'b1 ;
                    end

        (1500+001):                         RUN_RDCAL_clr();                   // clear the read cal regs.
        (1500+002):                         RUN_READ_CAL ();                   // Run Read calibration command.

        // Wait for read result
        (1500+020): begin
                                            RDCAL_bit <= RDCAL_bit && RDCAL && READ_CAL_PAT_s ; // Make sure every read cal test in the loop passes.
    
                        if (loop1==0)       init_pc       <= return1 ;        // counter reached it's end, return from loop
                        else begin
                                            loop1         <= loop1 - 1'd1;    // decrement loop counter.
                                            init_pc       <= 12'(1500+001) ;     // perform another read cal
                                            end
                    end

// **********************************************************************************
// Step shift PLL tuning by loop1 steps.
// **********************************************************************************

        (1600+000): begin
                        if (loop1==0) begin
                                             init_pc    <= return1 ;              // loop at 0, so, just return.
                                             high_speed <= 1 ;                    // Return to 50Mhz.
                        end else begin
                                             loop1      <= loop1   - 1'b1 ;       // Decrement the loop counter.
                                             init_pc    <= init_pc + 1'b1 ;       // advance program counter.
                        if (!SKIP_PUP_TIMER) high_speed <= 0 ;                    // When running in the FPGA, run this section at 1MHz.
                       end
                    end
        (1600+001):     SHIFT_PLL (1);    // Yes, even though Altera's PLL tunes much faster, the resulting clock output isn't affected for a good 50 clocks.
        (1600+003):     SHIFT_PLL (0);    // This time is also necessary for the read-data logic to flush any garbage due to a glitch in the source clock.
                                          // This tuning delay even gets even longer if your PLL multiplication/division factors happen to generate odd fractions.
                                          // This is why for tuning, we need to wait >2us for stabilization just to play it safe.
        (1600+004):     init_pc <= 1600 ; // goto beginning of loop

        endcase
    end // if  timer_us[7] && !CMD_TX_BUSYi

// Functional clock frequencies with 50Mhz source, 250,300,350,400,450

  end // !reset
end // always...


// ****************************
// Calling sub routines
// ****************************
task CALL_SHIFT_PLL (bit [3:0] count, bit updn);
    begin
    loop1              <= count ;
    phase_updn         <= updn  ;
    return1            <= 12'(init_pc + 1) ;   // Set return program counter for sub routine to the next program line.
    init_pc            <= 1600  ;              // Call Read calibration sub-loop sub-routine.
    end
endtask

task SHIFT_PLL (bit step);
    begin
                    phase_step <= step ;
                    init_pc    <= init_pc + 1'b1 ;
    end
endtask

task CALL_TEST_RDCAL ();
    begin
    return1            <= 12'(init_pc + 1) ;   // Set return program counter for sub routine to the next program line.
    init_pc            <= 1500 ;               // Call Read calibration sub-loop sub-routine.
    end
endtask

// ****************************
// Transmit DDR3 commands
// ****************************
task SET_mrs (logic [1:0] mrs_num);
    begin
    TX_BANKi[DDR3_WIDTH_BANK-1:2] <= 0 ;
    TX_BANKi[1:0]                 <= mrs_num ;
    TX_ADDRi                      <= MRS[mrs_num];
    TX_TXBi                       <= 8'(1<<TXB_MRS);
    CMD_TX_ENAint                 <= !CMD_TX_ENAint ;
    init_pc                       <= init_pc + 1'b1 ;
    end
endtask

task RUN_ZQCL ();
    begin
    TX_BANKi[DDR3_WIDTH_BANK-1:2] <= 0 ;
    TX_BANKi[1:0]                 <= 0 ;
    TX_ADDRi                      <= 14'b10000000000 ; 
    TX_TXBi                       <= 8'(1<<TXB_ZQC);
    CMD_TX_ENAint                 <= !CMD_TX_ENAint ;
    init_pc                       <= init_pc + 1'b1 ;
    end
endtask

task RUN_READ_CAL ();
    begin
    RDCAL_clr                     <= 0 ; // must allow the read to take place.
    TX_BANKi[DDR3_WIDTH_BANK-1:2] <= 0 ;
    TX_BANKi[1:0]                 <= 0 ;
    TX_ADDRi                      <= 14'b1000000000000 ; 
    TX_TXBi                       <= 8'(1<<TXB_REA);
    CMD_TX_ENAint                 <= !CMD_TX_ENAint ;
    init_pc                       <= init_pc + 1'b1 ;
    end
endtask

task RUN_NOP ();
    begin
    TX_BANKi[DDR3_WIDTH_BANK-1:2] <= 0 ;
    TX_BANKi[1:0]                 <= 0 ;
    TX_ADDRi                      <= 0 ; 
    TX_TXBi                       <= 8'(1<<TXB_NOP);
    CMD_TX_ENAint                 <= !CMD_TX_ENAint ;
    init_pc                       <= init_pc + 1'b1 ;
    end
endtask

task RUN_RDCAL_clr ();
    begin
    RDCAL_clr                     <= 1 ;
    init_pc                       <= init_pc + 1'b1 ;
    end
endtask

// ****************************
// Tuning correction table
// ****************************

always_ff @(posedge DDR_CLK_25) begin
case (RDCAL_d)
    8'b10000000 : PLL_OFFSET <= 7  ;
    8'b11000000 : PLL_OFFSET <= 7  ;
    8'b11100000 : PLL_OFFSET <= 6  ;
    8'b11110000 : PLL_OFFSET <= 6  ;
    8'b11111000 : PLL_OFFSET <= 5  ;
    8'b11111100 : PLL_OFFSET <= 5  ;
    8'b11111110 : PLL_OFFSET <= 4  ;
    8'b11111111 : PLL_OFFSET <= 4  ;
    default     : PLL_OFFSET <= 0  ;
endcase
end

endmodule
