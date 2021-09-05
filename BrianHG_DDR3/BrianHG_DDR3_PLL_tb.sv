// *********************************************************************
//
// BrianHG_DDR3_PLL_tb.sv clock generator with DQS CLK phase
// control for write leveling, RQD 90 degree clock, and
// CMD_CLK system clock which can be configured to: 
//
// 'Half' rate, 'Quarter' rate, and 'Eighth' rate.
//
// Version 1.00, August 22, 2021
//
//
// Written by Brian Guralnick.
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *********************************************************************
//
//
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.

module BrianHG_DDR3_PLL_tb #(
// ***************** BrianHG_DDR3_PLL test parameters

parameter string     FPGA_VENDOR             = "Altera",       // Use ALTERA, INTEL, LATTICE or XILINX.
parameter string     FPGA_FAMILY             = "Cyclone V",    // (USE "SIM" for RTL simulation bypassing any HW dependent functions) With Altera, use Cyclone III, Cyclone IV, Cyclone V, MAX 10,....
parameter int        CLK_KHZ_IN              = 50000,          // PLL source input clock frequency in KHz.
parameter int        CLK_IN_MULT             = 32,             // Multiply factor to generate the DDR MTPS speed divided by 2.
parameter int        CLK_IN_DIV              = 4,              // Divide factor.  When CLK_KHZ_IN is 25000,50000,75000,100000,125000,150000, use 2,4,6,8,10,12.
                                                               
parameter int        DDR_TRICK_MTPS_CAP      = 0,              // 0=off, Set a false PLL DDR data rate for the compiler to allow FPGA overclocking.  ***DO NOT USE.
parameter string     INTERFACE_SPEED         = "Full",         // Either "Full", "Half", or "Quarter" speed for the user interface clock.
                                                               // This will effect the controller's interface CMD_CLK output port frequency.
                                                               // "Full" means that CMD_CLK = DDR3_CLK, "Half" means CMD_CLK is half speed of DDR3_CLK...

parameter int        DDR3_WDQ_PHASE          = 270,            // 270/90.  Select the write and write DQS output clock phase relative to the DDR3_CLK/
parameter int        DDR3_RDQ_PHASE          = 0               // Select the read latch clock for the read data and DQS input relative to the DDR3_CLK.
)
(
RST_IN,    // Reset input
RST_OUT,
CLK_IN,
DDR3_CLK,
DDR3_CLK_WDQ,
DDR3_CLK_RDQ,
DDR3_CLK_50,
DDR3_CLK_25,
CMD_CLK,
PLL_LOCKED,
phase_step,
phase_updn,
phase_sclk,
phase_done
);

input  logic RST_IN,CLK_IN;
output logic RST_OUT,DDR3_CLK,DDR3_CLK_WDQ,DDR3_CLK_RDQ,DDR3_CLK_50,DDR3_CLK_25,CMD_CLK,PLL_LOCKED;
input  logic phase_step,phase_updn,phase_sclk;
output logic phase_done;

localparam       period  = 500000000/CLK_KHZ_IN ;
localparam      STOP_uS  = 1000000 ;
localparam      endtime  = STOP_uS * 10;

// *********************************************************************************************
// This module generates the master reference clocks for the entire memory system.
// *********************************************************************************************
BrianHG_DDR3_PLL  #(.FPGA_VENDOR    (FPGA_VENDOR),    .INTERFACE_SPEED (INTERFACE_SPEED), .DDR_TRICK_MTPS_CAP       (DDR_TRICK_MTPS_CAP),
                    .FPGA_FAMILY    (FPGA_FAMILY),
                    .CLK_KHZ_IN     (CLK_KHZ_IN),     .CLK_IN_MULT     (CLK_IN_MULT),     .CLK_IN_DIV               (CLK_IN_DIV),
                    .DDR3_WDQ_PHASE (DDR3_WDQ_PHASE), .DDR3_RDQ_PHASE  (DDR3_RDQ_PHASE)
) DUT_DDR3_PLL (    .RST_IN         (RST_IN),         .RST_OUT         (RST_OUT),         .CLK_IN    (CLK_IN),      .DDR3_CLK    (DDR3_CLK),
                    .DDR3_CLK_WDQ   (DDR3_CLK_WDQ),   .DDR3_CLK_RDQ    (DDR3_CLK_RDQ),    .CMD_CLK   (CMD_CLK),     .PLL_LOCKED  (PLL_LOCKED),
                    .DDR3_CLK_50    (DDR3_CLK_50),    .DDR3_CLK_25     (DDR3_CLK_25),

                    .phase_step     ( phase_step ),   .phase_updn      ( phase_updn ),
                    .phase_sclk     ( phase_sclk ),   .phase_done      ( phase_done ) );

initial begin
phase_step = 1'b0 ;
phase_updn = 1'b0 ;
phase_sclk = 1'b0 ;

RST_IN = 1'b1 ; // Reset input
CLK_IN = 1'b0 ;
#(50000);
RST_IN = 1'b0 ; // Release reset at 50ns.


#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;
#(200000) phase_step = 1'b1 ;
#(200000) phase_step = 1'b0 ;


end


always #period                  phase_sclk = !phase_sclk; // create source clock oscillator
always #period                  CLK_IN = !CLK_IN; // create source clock oscillator
always @(PLL_LOCKED) #(endtime) $stop;            // Wait for PLL to start, then run the simulation until 1ms has been reached.

endmodule
