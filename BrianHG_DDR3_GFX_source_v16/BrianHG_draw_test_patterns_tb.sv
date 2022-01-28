// *****************************************************************
// Demo BHG Read DDR3 display picture pattern generator test bench.
// IE: It draws graphic images into ram.
//
// Buttons 0 = Clear screen to a solid color.
// Buttons 1 = Draw random colored snow.
//
// Switch  0 = Enable/disable random ellipse drawing engine.
// Switch  1 = N/A.
//
// Version 0.5, June 27, 2021.
//
// **** Note that the FIFO & ROM in the test pattern generator
// and hardware multiplier in the ellipse generator means that
// this simulation requires Altera's Modelsim to function.
//
// Written by Brian Guralnick.
// For public use.
//
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.


module BrianHG_draw_test_patterns_tb #(
parameter int                       PORT_ADDR_SIZE      = 25,   // Must match PORT_ADDR_SIZE.
                                    PIXEL_WIDTH         = 32
)(
CLK                ,
reset              ,
DISP_pixel_bytes   ,         // 4=32 bit pixels, 2=16bit pixels, 1=8bit pixels.
DISP_mem_addr      ,         // Beginning memory address of graphic bitmap pixel position 0x0.
DISP_bitmap_width  ,         // The bitmap width of the graphic in memory.
DISP_bitmap_height ,         // The bitmap width of the graphic in memory.
write_busy_in      ,
write_req_out      ,
write_adr_out      ,
write_data_out     ,
buttons            ,         // 2 buttons on deca board.
switches                     // 2 switches on deca board.
);

//localparam   WRITE_WORD_SIZE   = PIXEL_WIDTH/8 ;           // Each write word width, which the write port should be set to.
//localparam   PIXEL_WORD_SHIFT = $clog2(WRITE_WORD_SIZE) ;  // Each pixel is 4 bytes, but the since we are addressing 128bits, we need a bit shift divide read count for calculating read word vs pixels.


input  logic                                CLK                = 0    ;
input  logic                                reset              = 0    ;
input  logic         [2:0]                  DISP_pixel_bytes   = 4    ;
input  logic         [31:0]                 DISP_mem_addr      = 0    ;
input  logic signed  [15:0]                 DISP_bitmap_width  = 2048 ;
input  logic signed  [15:0]                 DISP_bitmap_height = 1080 ;
input  logic                                write_busy_in      = 0    ;
output logic                                write_req_out      = 0    ;
output logic         [PORT_ADDR_SIZE-1:0]   write_adr_out      = 0    ;
output logic         [31:0]                 write_data_out     = 0    ;
input  logic         [1:0]                  buttons            = 0    ;
input  logic         [1:0]                  switches           = 0    ;


localparam      CLK_MHZ_IN  = 100 ;
localparam      period      = 500000/CLK_MHZ_IN ;
localparam      STOP_uS     = 1000000 ;
localparam      endtime     = STOP_uS * 1000;


 BrianHG_draw_test_patterns #(
.PORT_ADDR_SIZE     (PORT_ADDR_SIZE      ),
.PIXEL_WIDTH        (PIXEL_WIDTH         )
) DUT_BHG_test_pat (
.CLK_IN             ( CLK                ),
.CMD_CLK            ( CLK                ),
.reset              ( reset              ),
.DISP_pixel_bytes   ( DISP_pixel_bytes   ),         // 4=32 bit pixels, 2=16bit pixels, 1=8bit pixels.
.DISP_mem_addr      ( DISP_mem_addr      ),         // Beginning memory address of graphic bitmap pixel position 0x0.
.DISP_bitmap_width  ( DISP_bitmap_width  ),         // The bitmap width of the graphic in memory.
.DISP_bitmap_height ( DISP_bitmap_height ),         // The bitmap width of the graphic in memory.        
.write_busy_in      ( write_busy_in      ),         // DDR3 ram read channel #1 was selected for reading the video ram.
.write_req_out      ( write_req_out      ),
.write_adr_out      ( write_adr_out      ),
.write_data_out     ( write_data_out     ),
.write_mask_out     (                    ),
.buttons            ( buttons            ),        // 2 buttons on deca board.
.switches           ( switches           )         // 2 switches on deca board.
);


initial begin
DISP_pixel_bytes   = 4    ;
DISP_mem_addr      = 0    ;
DISP_bitmap_width  = 2048 ;
DISP_bitmap_height = 1080 ;
write_busy_in      = 0    ;
buttons            = 3    ; // Bit 0 = draw static,     Bit 1 = draw pattern
switches           = 0    ; // Bit 0 = enable ellipses, Bit 1 = enable screen scrolling.

reset  = 1'b1 ; // Reset input
CLK    = 1'b1 ;
#(50000);
reset  = 1'b0 ; // Release reset at 50ns.
end

always #period         CLK = !CLK ;  // create source clock oscillator
always #(endtime)      $stop      ;  // Stop simulation from going on forever.
endmodule
