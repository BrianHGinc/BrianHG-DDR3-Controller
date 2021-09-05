// *********************************************************************
//
// BrianHG_DDR3_GEN_tCK.sv DDR3 - Clock times.
// Version 1.00, August 22, 2021.
//
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
// - Supply this module with these parameters:
//           DDR3_CLK               operating clock frequency in MHz,
//           DDR3_SPEED_GRADE      in MHz,
//           DDR3_MEM_SIZE         in GB,
//           DDR3_WIDTH_DQ         DDR3 Ram chip DQ buss width,
//           DDR3_ODT_RTT          ODT impedance,
//           DDR3_RZQ              Read Drive current,
//           DDR3_OPERATING_TEMP   in degrees Celsius,
//
//   And these dynamic inputs :
//           DDR3_dll_disable 
//           DDR3_dll_reset  
//           DDR3_write_leveling
//           DDR3_read_leveling
//
// - This module will return:
//   All tCK clock cycle values for the DDR3 ram chip,
//   Average refresh time in microseconds/10,
//   MR[0:3] settings for MR0, MR1, MR2, MR3.
//
//
// - *** TO BE DONE...
//       Automatically render a .sdc timing constraints file for the DQ/DQS timing to ensure timing closure.
//       (This means adding a 'board trace delay parameter input which would appropriately modify the .sdc values.)
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
// *********************************************************************

module BrianHG_DDR3_GEN_tCK #(

// *****************  DDR3 ram chip configuration settings
parameter int          DDR3_CK_MHZ        = 320,          // DDR3 CK clock speed in MHz.
parameter string       DDR3_SPEED_GRADE  = "-15E",       // Use 1066 / 187E, 1333 / -15E, 1600 / -125, 1866 / -107, or 2133 MHz / 093.
parameter bit  [7:0]   DDR3_SIZE_GB      = 1,            // Use 0,1,2,4 or 8.  (0=512mb) Caution: Must be correct as ram chip size affects the tRFC REFRESH period.
parameter bit  [7:0]   DDR3_WIDTH_DQ     = 16,           // Use 8 or 16.  The width of each DDR3 ram chip.
parameter bit  [7:0]   DDR3_ODT_RTT      = 120,          // use 120, 60, 40, 30, 20 Ohm. or 0 to disable ODT.  (On Die Termination during write operation.)
parameter bit  [7:0]   DDR3_RZQ          = 40,           // use 34 or 40 Ohm. (Output Drive Strength during read operation.)
parameter bit  [7:0]   DDR3_TEMP         = 85,           // use 85,95,105. (Peak operating temperature in degrees Celsius.)

// *****************  These parameters override the auto tCK generator and allow you to force a desired number of tCK clocks.
parameter bit  [5:0]   f_tAA =0,f_tRCD =0,f_tRP      =0,f_tRC    =0,f_tRAS     =0,f_tDLLK  =0,f_tRRD   =0,f_tFAW =0,f_tWR  =0,f_tWTR  =0,f_tRPT    =0,f_tCCD=0,
                       f_tDAL=0,f_tMRD =0,f_tMOD     =0,f_tMPRR  =0,f_tWRAP_DEN=0,f_ODTLon =0,f_ODTLoff=0,f_ODTH8=0,f_ODTH4=0,f_tWLMRD=0,f_tWLDQSEN=0,f_tCKE=0,
                       f_CL  =0,f_CWL  =0,f_WR       =0,f_tRTP   =0,
parameter bit  [10:0]  f_tRFC=0,f_tREFI=0,f_tZQinit  =0,f_tZQoper=0,f_tZQCS    =0,f_tXPR   =0 // tREFI is given in microseconds/10.  IE a value of 78 = 7.8 microseconds.
)(
input                  DDR3_dll_disable,                 // Manipulates the MR0 to disable the DLL.
input                  DDR3_dll_reset,                   // Manipulates the MR0 to reset the DLL.
input                  DDR3_write_leveling,              // Manipulates the MR1 output data to enter write leveling mode.
input                  DDR3_read_leveling,               // Manipulates the MR3 output data to enter read calibration test pattern mode.

// **************** Output logic
// The second slowest time is tRC, ACT to ACT, or ACT to REF which is 52ns, @1067MHz CK is 57 clocks, or, a 6 bit return value.
// The actual slowest time is tRFC, refresh to activate on a 8GB device at 350ns minimum, or 374 tCK, a 9 bit number.
// This 9 bit number slows down the sequencer by introducing a big timer, so, tRFC is constructed with additional NOPs by the COMMANDER.
//
output logic [5:0]     tAA  ,tRCD ,tRP   ,tRC    ,tRAS   ,tRRD ,tFAW  ,tWR     ,tWTR,tRPT,tCCD,tDAL,tMRD,
                       tMOD ,tMPRR,ODTLon,ODTLoff,ODTH8  ,ODTH4,tWLMRD,tWLDQSEN,CL  ,CWL ,WR  ,AL,  tCKE,tRTP,
output logic [10:0]    tDLLK,tRFC ,tREFI ,tZQinit,tZQoper,tZQCS,tXPR  , // tREFI is given in microseconds/10.  IE a value of 78 = 7.8 microseconds.
output logic [12:0]    MR [0:3]                                         // MR[0:3] go to the first 13 bit DDR3_A[12:0] while the [0,1,2,3]
                                                                        // numerically point to the bottom two DDR3_BA[1:0] bits.
);

localparam int tCK = 1000000 / DDR3_CK_MHZ ; // Calculate the number of Picoseconds the DDR3_CLK command clock is toggling at.


// *********************************************************************
// Filter out illegal parameter errors, halt compilation on error...
// *********************************************************************
generate
if ( DDR3_CK_MHZ  < 250  ||  DDR3_CK_MHZ  > 1067 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("**************************************************************************");
    $warning("*** BrianHG_DDR3 parameter .DDR3_CK_MHZ (%d) is outside the permitted ***",13'(DDR3_CK_MHZ ));
    $warning("*** range.  Only frequencies between 300 and 1067 are allowed.         ***");
    $warning("**************************************************************************");
    $error;
    $stop;
    end

if ( DDR3_SIZE_GB !=0  && DDR3_SIZE_GB !=1  && DDR3_SIZE_GB !=2  && DDR3_SIZE_GB !=4  && DDR3_SIZE_GB !=8 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("*****************************************************************");
    $warning("*** BrianHG_DDR3 parameter .DDR3_SIZE_GB(%d) is not known.   ***",8'(DDR3_SIZE_GB));
    $warning("*** Only 1 GB, 2 GB, 4 GB, 8 GB, or 0 for 512 MB are allowed. ***");
    $warning("*****************************************************************");
    $error;
    $stop;
    end

if ( DDR3_ODT_RTT !=0  && DDR3_ODT_RTT !=20  && DDR3_ODT_RTT !=30  && DDR3_ODT_RTT !=40  && DDR3_ODT_RTT !=60 && DDR3_ODT_RTT !=120 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("*******************************************************************");
    $warning("*** BrianHG_DDR3 parameter .DDR3_ODT_RTT(%d) is not supported. ***",8'(DDR3_ODT_RTT));
    $warning("*** Only 20,30,40,60,120 Ohm, or 0 for disable are allowed.     ***");
    $warning("*******************************************************************");
    $error;
    $stop;
    end

if ( DDR3_WIDTH_DQ !=8  && DDR3_WIDTH_DQ !=16 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("****************************************************************");
    $warning("*** BrianHG_DDR3 parameter .DDR3_WIDTH_DQ(%d) is not known. ***",8'(DDR3_WIDTH_DQ));
    $warning("*** Only 8 bit and 16 bit DDR3 ram chips are supported.      ***");
    $warning("****************************************************************");
    $error;
    $stop;
    end

if ( DDR3_RZQ !=34  && DDR3_RZQ !=40 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("***********************************************************");
    $warning("*** BrianHG_DDR3 parameter .DDR3_RZQ(%d) is not known. ***",8'(DDR3_RZQ));
    $warning("*** Only 34 Ohm or 40 Ohm are are supported.            ***");
    $warning("***********************************************************");
    $error;
    $stop;
    end

if ( DDR3_TEMP !=85  && DDR3_TEMP !=95 && DDR3_TEMP !=105 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("************************************************************");
    $warning("*** BrianHG_DDR3 parameter .DDR3_TEMP(%d) is not known. ***",8'(DDR3_TEMP));
    $warning("*** Only 85, 95, or 105 degrees Celsius are supported.   ***");
    $warning("************************************************************");
    $error;
    $stop;
    end

if ( f_WR !=0  && f_WR !=5  && f_WR !=6  && f_WR !=7  && f_WR !=8  && f_WR !=10  && f_WR !=12  && f_WR !=14  && f_WR !=16 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("************************************************************************");
    $warning("*** BrianHG_DDR3 parameter .f_WR(%d), Write Recovery is not allowed. ***",5'(f_WR));
    $warning("*** Only use 5,6,7,8,10,12,14,16, or use 0 for Automatic.            ***");
    $warning("************************************************************************");
    $error;
    $stop;
    end

if ( f_CL !=0  && (f_CL < 5 || f_CL > 14 )) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("*********************************************************************");
    $warning("*** BrianHG_DDR3 parameter .f_CL(%d), CAS Latency is not allowed. ***",5'(f_CL));
    $warning("*** Only use 5 thru 14, or use 0 for Automatic.                   ***");
    $warning("*********************************************************************");
    $error;
    $stop;
    end

if ( f_CWL !=0  && (f_CWL < 5 || f_CWL > 10 )) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("****************************************************************************");
    $warning("*** BrianHG_DDR3 parameter .f_CWL(%d), CAS Write Latency is not allowed. ***",5'(f_CWL));
    $warning("*** Only use 5 thru 10, or use 0 for Automatic.                          ***");
    $warning("****************************************************************************");
    $error;
    $stop;
    end
endgenerate

// Use 1066/-187, 1333/-15, 1600/-125, 1866/-107, or 2133 MHz / 093 x10 picoseconds.
localparam bit [2:0]  DDR3_SG = 3'((DDR3_SPEED_GRADE == "1066") * 1 +
                                   (DDR3_SPEED_GRADE == "-187E")* 1 +
                                   (DDR3_SPEED_GRADE == "1333") * 2 +
                                   (DDR3_SPEED_GRADE == "-15E") * 2 +
                                   (DDR3_SPEED_GRADE == "1600") * 3 +
                                   (DDR3_SPEED_GRADE == "-125") * 3 +
                                   (DDR3_SPEED_GRADE == "1866") * 4 +
                                   (DDR3_SPEED_GRADE == "-107") * 4 +
                                   (DDR3_SPEED_GRADE == "2133") * 5 +
                                   (DDR3_SPEED_GRADE == "-093") * 5) ;
generate
if ( DDR3_SG == 0 ) initial begin
    $warning("********************************************");
    $warning("*** BrianHG_DDR3_GEN_tCK PARAMETER ERROR ***");
    $warning("*******************************************************************************");
    $warning("*** BrianHG_DDR3 parameter .DDR3_SPEED_GRADE(%s) is not known.            ***",DDR3_SPEED_GRADE);
    $warning("*** Only 1066, 1333, 1600, 1866, 2133 MHz, or -187E, -15E, -125, -107, -093 ***");
    $warning("*** are allowed.  See Micron DDR3 data-sheets.                              ***");
    $warning("*******************************************************************************");
    $error;
    $stop;
    end
endgenerate


// Generate all the tCK outputs.
always_comb begin
//                                -187  -15   -125  -107  -093  *** Speed grade lookup table ***
localparam int  ctAA    [1:5] = '{    1,    1,    1,    1,    1}; // minimum tCK clock cycles
localparam int  ttAA    [1:5] = '{15000,15000,13750,13910,13090}; // minimum time in picoseconds
localparam int  ctRCD   [1:5] = '{    1,    1,    1,    1,    1}; // minimum tCK clock cycles
localparam int  ttRCD   [1:5] = '{15000,15000,13750,13910,13090}; // minimum time in picoseconds
localparam int  ctRP    [1:5] = '{    1,    1,    1,    1,    1}; // minimum tCK clock cycles
localparam int  ttRP    [1:5] = '{15000,15000,13750,13910,13090}; // minimum time in picoseconds
localparam int  ctRC    [1:5] = '{    1,    1,    1,    1,    1}; // minimum tCK clock cycles
localparam int  ttRC    [1:5] = '{52500,51000,48750,47910,46090}; // minimum time in picoseconds
localparam int  ctRAS   [1:5] = '{    1,    1,    1,    1,    1}; // minimum tCK clock cycles
localparam int  ttRAS   [1:5] = '{37500,36000,35000,34000,33000}; // minimum time in picoseconds
localparam int  ctWR    [1:5] = '{    1,    1,    1,    1,    1}; // minimum tCK clock cycles
localparam int  ttWR    [1:5] = '{15000,15000,15000,15000,15000}; // minimum time in picoseconds
localparam int  ctWTR   [1:5] = '{    4,    4,    4,    4,    4}; // minimum tCK clock cycles
localparam int  ttWTR   [1:5] = '{ 7500, 7500, 7500, 7500, 7500}; // minimum time in picoseconds
localparam int  ctRPT   [1:5] = '{    4,    4,    4,    4,    4}; // minimum tCK clock cycles
localparam int  ttRPT   [1:5] = '{ 7500, 7500, 7500, 7500, 7500}; // minimum time in picoseconds
localparam int  ctCCD   [1:5] = '{    4,    4,    4,    4,    4}; // minimum tCK clock cycles
localparam int  ttCCD   [1:5] = '{    1,    1,    1,    1,    1}; // minimum time in picoseconds
localparam int  ctMRD   [1:5] = '{    4,    4,    4,    4,    4}; // minimum tCK clock cycles
localparam int  ttMRD   [1:5] = '{    1,    1,    1,    1,    1}; // minimum time in picoseconds
localparam int  ctMOD   [1:5] = '{   12,   12,   12,   12,   12}; // minimum tCK clock cycles
localparam int  ttMOD   [1:5] = '{15000,15000,15000,15000,15000}; // minimum time in picoseconds
localparam int  ctMPRR  [1:5] = '{    1,    1,    1,    1,    1}; // minimum tCK clock cycles
localparam int  ttMPRR  [1:5] = '{    1,    1,    1,    1,    1}; // minimum time in picoseconds
localparam int  ctCKE   [1:5] = '{    3,    3,    3,    3,    3}; // minimum tCK clock cycles
localparam int  ttCKE   [1:5] = '{ 5630, 5000, 5000, 5000, 5000}; // minimum time in picoseconds
localparam int  ctRTP   [1:5] = '{    4,    4,    4,    4,    4}; // minimum tCK clock cycles
localparam int  ttRTP   [1:5] = '{ 7500, 7500, 7500, 7500, 7500}; // minimum time in picoseconds

localparam int  ctZQinit [1:5] = '{   512,   512,   512,   512,   512}; // minimum tCK clock cycles
localparam int  ttZQinit [1:5] = '{640000,640000,640000,640000,640000}; // minimum time in picoseconds
localparam int  ctZQoper [1:5] = '{   256,   256,   256,   256,   256}; // minimum tCK clock cycles
localparam int  ttZQoper [1:5] = '{320000,320000,320000,320000,320000}; // minimum time in picoseconds
localparam int  ctZQCS   [1:5] = '{    64,    64,    64,    64,    64}; // minimum tCK clock cycles
localparam int  ttZQCS   [1:5] = '{  8000,  8000,  8000,  8000,  8000}; // minimum time in picoseconds

localparam int  ctRRD   [1:5] = '{    4,    4,    4,    4,    4}; // minimum tCK clock cycles
localparam int  ttRRD   [1:5] = '{ 7500, 6000, 6000, 5000, 5000}; // minimum time in picoseconds for 8  bit DDR3 ram chips
localparam int  ttRRD16 [1:5] = '{10000, 7500, 7500, 6000, 6000}; // minimum time in picoseconds for 16 bit DDR3 ram chips

localparam int  ctFAW   [1:5] = '{    4,    4,    4,    4,    4}; // minimum tCK clock cycles
localparam int  ttFAW   [1:5] = '{37500,30000,30000,27000,25000}; // minimum time in picoseconds for 8  bit DDR3 ram chips
localparam int  ttFAW16 [1:5] = '{50000,45000,40000,35000,35000}; // minimum time in picoseconds for 16 bit DDR3 ram chips

localparam int  ctCL    [1:5] = '{    5,    5,    5,    5,    5}; // minimum tCK clock cycles
localparam int  ttCL    [1:5] = '{50000,45000,40000,35000,35000}; // minimum time in picoseconds

//                                512mb,    1gb,    2gb,    4gb,                 8gb   **** Refresh time for each size of DDR3 Ram.
localparam int  ttRFC   [0:8] = '{90000, 110000, 160000, 260000, 260000, 360000, 360000, 360000, 360000}; // minimum time in picoseconds

localparam int        cWR      [4:17] = '{5,5,6,7,8,10,10,12,12,14,14,16,16,16}; // This table fixes the select-able Write Recovery (WR) clock allowed in MR0[11:9].
localparam bit [4:0]  sel_WR          =  (15000/tCK)+0.5 ;                       // WR = Write recovery, a fixed 15000ps or more.

                                         //      9876543210
localparam bit [12:0] WR_tMR0  [5:16] = '{13'b0001000000000, //5,
                                          13'b0010000000000, //6,
                                          13'b0011000000000, //7,
                                          13'b0100000000000, //8,
                                          13'b0100000000000, //8,
                                          13'b0101000000000, //10,
                                          13'b0101000000000, //10,
                                          13'b0110000000000, //12,
                                          13'b0110000000000, //12,
                                          13'b0111000000000, //14,
                                          13'b0111000000000, //14,
                                          13'b0000000000000  //16
                                          };                 // This table renders the Write Recovery (WR) bits settings in MR0.
                                         //      9876543210
localparam bit [12:0] CL_tMR0  [5:14] = '{13'b0000000010000, //5,
                                          13'b0000000100000, //6,
                                          13'b0000000110000, //7,
                                          13'b0000001000000, //8,
                                          13'b0000001010000, //9,
                                          13'b0000001100000, //10,
                                          13'b0000001110000, //11,
                                          13'b0000000000100, //12,
                                          13'b0000000010100, //13,
                                          13'b0000000100100  //14,
                                          };                 // This table renders the CAS Latency (CL) bits settings in MR0.

                                         //      9876543210
localparam bit [12:0] CWL_tMR2 [5:10] = '{13'b0000000000000, //5,
                                          13'b0000000001000, //6,
                                          13'b0000000010000, //7,
                                          13'b0000000011000, //8,
                                          13'b0000000100000, //9,
                                          13'b0000000101000  //10,
                                          };                 // This table renders the CAS Write Latency (CWL) bits settings in MR2.

                                         //      9876543210
localparam bit [12:0] Rtt_tMR1 [0:5]  = '{13'b0000000000000, // Off,
                                          13'b0000000000100, // RZQ/4 (60 Ohm),
                                          13'b0000001000000, // RZQ/2 (120 Ohm),
                                          13'b0000001000100, // RZQ/6 (40 Ohm),
                                          13'b0001000000000, // RZQ/12 (20 Ohm),
                                          13'b0001000000100  // RZQ/8 (30 Ohm),
                                          };                 // This table renders the Terminator strength (Rtt) bits settings in MR1.

                                         //      9876543210
localparam bit [12:0] ODS_tMR1 [0:1]  = '{13'b0000000000000, // 40 Ohm Output Drive,
                                          13'b0000000000010  // 34 Ohm Output Drive,
                                          };                 // This table renders the Output Drive Strength (ODS) bits settings in MR1.

                                         //      9876543210
localparam bit [12:0] AL_tMR1  [0:2]  = '{13'b0000000000000, // Disabled (AL=0),
                                          13'b0000000001000, // AL=CL-1,
                                          13'b0000000010000  // AL=CL-2,
                                          };                 // This table renders the Additive Latency (AL) bits settings in MR1.

logic [2:0] sel_Rtt;

     if (DDR3_TEMP==85 ) tREFI = 78 ; // Average refresh period in microseconds/10 based on IC operating temperature.
else if (DDR3_TEMP==95 ) tREFI = 39 ; // Average refresh period in microseconds/10 based on IC operating temperature.
else if (DDR3_TEMP==105) tREFI = 19 ; // Average refresh period in microseconds/10 based on IC operating temperature.

if (f_tRFC!=0)  tRFC =f_tRFC;
else            tRFC =(ttRFC [DDR3_SIZE_GB] / tCK + 0.5) ; // Select the refresh command time based on the DDR3_SIZE_GB and the contents of the lookup table.

if (f_tXPR!=0)  tXPR =f_tXPR;
else            tXPR =((ttRFC [DDR3_SIZE_GB]+10000) / tCK + 0.5) ; // Select the time between CKE enable after reset and the first MRS command.

if (f_tAA !=0)  tAA  =f_tAA ;
else            tAA  = 6'((ctAA  [DDR3_SG]>(ttAA  [DDR3_SG] / tCK + 0.5)) ? ctAA  [DDR3_SG] : integer'(ttAA  [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tRCD!=0)  tRCD =f_tRCD;
else            tRCD = 6'((ctRCD [DDR3_SG]>(ttRCD [DDR3_SG] / tCK + 0.5)) ? ctRCD [DDR3_SG] : integer'(ttRCD [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tRP !=0)  tRP  =f_tRP ;
else            tRP  = 6'((ctRP  [DDR3_SG]>(ttRP  [DDR3_SG] / tCK + 0.5)) ? ctRP  [DDR3_SG] : integer'(ttRP  [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tRC !=0)  tRC  =f_tRC ;
else            tRC  = 6'((ctRC  [DDR3_SG]>(ttRC  [DDR3_SG] / tCK + 0.5)) ? ctRC  [DDR3_SG] : integer'(ttRC  [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tRAS!=0)  tRAS =f_tRAS;
else            tRAS = 6'((ctRAS [DDR3_SG]>(ttRAS [DDR3_SG] / tCK + 0.5)) ? ctRAS [DDR3_SG] : integer'(ttRAS [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tWR !=0)  tWR  =f_tWR ;
else            tWR  = 6'((ctWR  [DDR3_SG]>(ttWR  [DDR3_SG] / tCK + 0.5)) ? ctWR  [DDR3_SG] : integer'(ttWR  [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tWTR!=0)  tWTR =f_tWTR;
else            tWTR = 6'((ctWTR [DDR3_SG]>(ttWTR [DDR3_SG] / tCK + 0.5)) ? ctWTR [DDR3_SG] : integer'(ttWTR [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tRPT!=0)  tRPT =f_tRPT;
else            tRPT = 6'((ctRPT [DDR3_SG]>(ttRPT [DDR3_SG] / tCK + 0.5)) ? ctRPT [DDR3_SG] : integer'(ttRPT [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tCCD!=0)  tCCD =f_tCCD;
else            tCCD = 6'((ctCCD [DDR3_SG]>(ttCCD [DDR3_SG] / tCK + 0.5)) ? ctCCD [DDR3_SG] : integer'(ttCCD [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tMRD!=0)  tMRD =f_tMRD;
else            tMRD = 6'((ctMRD [DDR3_SG]>(ttMRD [DDR3_SG] / tCK + 0.5)) ? ctMRD [DDR3_SG] : integer'(ttMRD [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tMOD!=0)  tMOD =f_tMOD;
else            tMOD = 6'((ctMOD [DDR3_SG]>(ttMOD [DDR3_SG] / tCK + 0.5)) ? ctMOD [DDR3_SG] : integer'(ttMOD [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tMPRR!=0) tMPRR=f_tMPRR;
else            tMPRR= 6'((ctMPRR[DDR3_SG]>(ttMPRR[DDR3_SG] / tCK + 0.5)) ? ctMPRR[DDR3_SG] : integer'(ttMPRR[DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tCKE!=0)  tCKE =f_tCKE;
else            tCKE = 6'((ctCKE [DDR3_SG]>(ttCKE [DDR3_SG] / tCK + 0.5)) ? ctCKE [DDR3_SG] : integer'(ttCKE [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tRTP!=0)  tRTP =f_tRTP;
else            tRTP = 6'((ctRTP [DDR3_SG]>(ttRTP [DDR3_SG] / tCK + 0.5)) ? ctRTP [DDR3_SG] : integer'(ttRTP [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.

if (DDR3_WIDTH_DQ==16) begin // Select between 16bit DDR3 ram chips and 8bit DDR3 Ram chips.
    if (f_tRRD!=0) tRRD=f_tRRD;
    else           tRRD= 6'((ctRRD[DDR3_SG]>(ttRRD16[DDR3_SG] / tCK + 0.5)) ? ctRRD[DDR3_SG] : integer'(ttRRD16[DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
    if (f_tFAW!=0) tFAW=f_tFAW;
    else           tFAW= 6'((ctFAW[DDR3_SG]>(ttFAW16[DDR3_SG] / tCK + 0.5)) ? ctFAW[DDR3_SG] : integer'(ttFAW16[DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
end else begin
    if (f_tRRD!=0) tRRD=f_tRRD;
    else           tRRD=(ctRRD[DDR3_SG]>(ttRRD  [DDR3_SG] / tCK + 0.5)) ? ctRRD[DDR3_SG] : integer'(ttRRD  [DDR3_SG] / tCK + 0.5) ; // Select the higher between the minimum tCK vs time in ns.
    if (f_tFAW!=0) tFAW=f_tFAW;
    else           tFAW=(ctFAW[DDR3_SG]>(ttFAW  [DDR3_SG] / tCK + 0.5)) ? ctFAW[DDR3_SG] : integer'(ttFAW  [DDR3_SG] / tCK + 0.5) ; // Select the higher between the minimum tCK vs time in ns.
    end

if (f_ODTH8!=0)    ODTH8    = f_ODTH8; 
else               ODTH8    = 6;
if (f_ODTH4!=0)    ODTH4    = f_ODTH4;
else               ODTH4    = 4;

if (f_tZQinit!=0)  tZQinit =f_tZQinit;
else               tZQinit = 11'((ctZQinit [DDR3_SG]>(ttZQinit [DDR3_SG] / tCK + 0.5)) ? ctZQinit [DDR3_SG] : integer'(ttZQinit [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tZQoper!=0)  tZQoper =f_tZQoper;
else               tZQoper = 11'((ctZQoper [DDR3_SG]>(ttZQoper [DDR3_SG] / tCK + 0.5)) ? ctZQoper [DDR3_SG] : integer'(ttZQoper [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.
if (f_tZQCS  !=0)  tZQCS   =f_tZQCS  ;
else               tZQCS   = 11'((ctZQCS   [DDR3_SG]>(ttZQCS   [DDR3_SG] / tCK + 0.5)) ? ctZQCS   [DDR3_SG] : integer'(ttZQCS   [DDR3_SG] / tCK + 0.5)) ; // Select the higher between the minimum tCK vs time in ns.


if (f_tWLMRD!=0)   tWLMRD   = f_tWLMRD;
else               tWLMRD   = 40  ;
if (f_tWLDQSEN!=0) tWLDQSEN = f_tWLDQSEN;
else               tWLDQSEN = 25  ;
if (f_tDLLK!=0)    tDLLK    = f_tDLLK;
else               tDLLK    = 512 ;


if (f_CL!=0) CL = f_CL;
else begin
     if ( tCK >=3000              ) CL = 5  ;
else if ( tCK >=2500 && tCK <3000 ) CL = 6  ;
else if ( tCK >=1875 && tCK <2500 ) CL = 7  ;
else if ( tCK >=1500 && tCK <1875 ) CL = 9  ;
else if ( tCK >=1250 && tCK <1500 ) CL = 11 ;
else if ( tCK >=1070 && tCK <1250 ) CL = 13 ;
else                                CL = 14 ;
end

if (f_CWL!=0) CWL = f_CWL;
else begin
     if ( tCK >=3000              ) CWL = 5  ;
else if ( tCK >=2500 && tCK <3000 ) CWL = 5  ;
else if ( tCK >=1875 && tCK <2500 ) CWL = 6  ;
else if ( tCK >=1500 && tCK <1875 ) CWL = 7  ;
else if ( tCK >=1250 && tCK <1500 ) CWL = 8  ;
else if ( tCK >=1070 && tCK <1250 ) CWL = 9  ;
else                                CWL = 10 ;
end

AL = 0; // This DDR3 controller will space all the commands and manually issue the precharge.
        // For now, we wont use the additive latency.

if (f_WR!=0)  WR  = f_WR;
else          WR  = 6'(cWR[sel_WR]); // 15 picoseconds rounded to the table settings

tDAL    = WR + tRP; // *** Even though the data sheet has the formula "tDAL =WR + tRP/tCK(AVG)", tRP is not in picoseconds here.
                    // tRP has already been converted into clock cycles above, so you do not need to divide it by time.

ODTLon  = 6'(CWL + AL - 2) ;
ODTLoff = 6'(CWL + AL - 2) ;


// Render the 4 MRS addresses, MR0,MR1,MR2,MR3.

     if (DDR3_ODT_RTT==0  ) sel_Rtt = 0 ;
else if (DDR3_ODT_RTT==60 ) sel_Rtt = 1 ;
else if (DDR3_ODT_RTT==120) sel_Rtt = 2 ;
else if (DDR3_ODT_RTT==40 ) sel_Rtt = 3 ;
else if (DDR3_ODT_RTT==20 ) sel_Rtt = 4 ;
else if (DDR3_ODT_RTT==30 ) sel_Rtt = 5 ;

//DDR3_dll_disable     MR1[0]
//DDR3_dll_reset       MR0[8]
//DDR3_write_leveling  MR1[7]
//DDR3_read_leveling   MR3[2]

MR[0] = WR_tMR0  [WR]             | CL_tMR0  [CL]             | (DDR3_dll_reset<<8)    | 13'b1000000000000 ; // The 13'b1xxxx turns on the outputs.
MR[1] = Rtt_tMR1 [sel_Rtt]        | ODS_tMR1 [(DDR3_RZQ==34)] | AL_tMR1  [AL]          | (DDR3_dll_disable) | (DDR3_write_leveling<<7) ;
MR[2] = CWL_tMR2 [CWL]            | ((DDR3_TEMP!=85)<<7) ;
MR[3] = (DDR3_read_leveling<<2) ;

end // always_comb
endmodule
