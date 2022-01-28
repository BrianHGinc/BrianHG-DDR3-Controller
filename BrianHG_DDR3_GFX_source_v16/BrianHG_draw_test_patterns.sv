// *****************************************************************
// Demo BHG Read DDR3 display picture pattern generator.
// IE: It draws graphic images into ram.
//
// Buttons 0 = Draw random colored snow.
// Buttons 1 = Use a counter to draw a colored pattern.
//
// Switch  0 = Enable/disable random ellipse drawing engine.
// Switch  1 = N/A. (*** Used in the separate screen scroll module ***)
//
// Version 1.5, October 25, 2021.
// Added an additional D-Reg FF to the output of the command FIFO to improve FMAX.
//
//
// Written by Brian Guralnick.
// For public use.
//
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
module BrianHG_draw_test_patterns #(
parameter int                              PORT_ADDR_SIZE      = 24,   // Must match PORT_ADDR_SIZE.
                                           PIXEL_WIDTH         = 32
)(
input                                      CLK_IN            ,
input                                      CMD_CLK           ,
input                                      reset             ,

input  logic        [2:0]                  DISP_pixel_bytes   ,         // 4=32 bit pixels, 2=16bit pixels, 1=8bit pixels.
input  logic        [31:0]                 DISP_mem_addr      ,         // Beginning memory address of graphic bitmap pixel position 0x0.
input  logic signed [15:0]                 DISP_bitmap_width  ,         // The bitmap width of the graphic in memory.
input  logic signed [15:0]                 DISP_bitmap_height ,         // The bitmap width of the graphic in memory.

input                                      write_busy_in      ,         // DDR3 ram read channel #1 was selected for reading the video ram.
output        logic                        write_req_out      ,
output logic        [PORT_ADDR_SIZE-1:0]   write_adr_out      ,
output logic        [31:0]                 write_data_out     ,
output logic        [3:0]                  write_mask_out     ,

input               [1:0]                  buttons            ,        // 2 buttons on deca board.
input               [1:0]                  switches           ,        // 2 switches on deca board.

output             [31:0]                  rnd_out                     // Send out random number for other uses.
);

//localparam   WRITE_WORD_SIZE   = PIXEL_WIDTH/8 ;           // Each write word width, which the write port should be set to.
//localparam   PIXEL_WORD_SHIFT = $clog2(WRITE_WORD_SIZE) ;  // Each pixel is 4 bytes, but the since we are addressing 128bits, we need a bit shift divide read count for calculating read word vs pixels.

logic [1:0]                 pixel_byte_shift ;
logic [PORT_ADDR_SIZE-1:0]  disp_addr, mem_addr ;
logic [1:0]                 buttons_l, switches_l ;

//logic [PORT_ADDR_SIZE-1:0] LAST_PIXEL_ADDR ;
//always_comb                LAST_PIXEL_ADDR = DISP_bitmap_width*DISP_bitmap_height*DISP_pixel_bytes;  // test random draw pixel area


logic [31:0] rnd_num;
rnd BHG_RND (.clk (CMD_CLK), .rst (reset), .ena (1'b1), .load(1'b0), .seed(32'h0), .out (rnd_num) );
assign rnd_out = rnd_num ;

logic [7:0]  prog_pc = 0 ;
logic [31:0] counter = 0 ;

logic [PORT_ADDR_SIZE-1:0] write_adr_out_i ;
logic [31:0]               write_data_out_i ;

assign write_mask_out = 4'b1111 ; // Always write enable all bits.


// **********************************************************************************
// Generate a write pixel cache port.
// **********************************************************************************
logic [PORT_ADDR_SIZE-1:0]   write_adr  ;
logic [31:0]                 write_data ;
logic read_req_cache,write_req_cache,pixel_cache_busy,pixel_cache_empty,pixel_cache_full;

    scfifo    write_pixel_cache (
                .clock        ( CMD_CLK                        ),
                .data         ( {write_adr    ,write_data    } ),
                .rdreq        ( read_req_cache                 ),
                .wrreq        ( write_req_cache                ),
                .almost_full  ( pixel_cache_busy               ),
                .empty        ( pixel_cache_empty              ),
                .full         ( pixel_cache_full               ),
                .q            ( {write_adr_out_i,write_data_out_i} ),
                .aclr         ( reset                          ),
                .almost_empty (),.eccstatus (),.sclr (),.usedw ());
    defparam
        write_pixel_cache.add_ram_output_register = "ON",
        write_pixel_cache.almost_full_value = 48,
        write_pixel_cache.intended_device_family = "MAX 10",
        write_pixel_cache.lpm_numwords = 64,
        write_pixel_cache.lpm_showahead = "ON",//"OFF",
        write_pixel_cache.lpm_type = "scfifo",
        write_pixel_cache.lpm_width = (PORT_ADDR_SIZE+PIXEL_WIDTH),
        write_pixel_cache.lpm_widthu = 6,
        write_pixel_cache.overflow_checking = "ON",
        write_pixel_cache.underflow_checking = "ON",
        write_pixel_cache.use_eab = "ON";

// **********************************************************************************
// Manage pixel write cache FIFO to DDR3 write port out.
// **********************************************************************************
// assign read_req_cache = (!pixel_cache_empty && !write_busy_in) ;
// assign write_req_out  = (!pixel_cache_empty && !write_busy_in) ;
// assign write_adr_out  = write_adr_out_i  ;
// assign write_data_out = write_data_out_i ;

logic  fifo_reg = 0 ;
assign read_req_cache = (!pixel_cache_empty && (!write_busy_in || !fifo_reg) ) ;
assign write_req_out  = fifo_reg && !write_busy_in ;

always_ff @(posedge CMD_CLK) begin 
    
    if (reset) begin
            fifo_reg       <= 0 ;
    end else begin

        if (read_req_cache) begin
                                                  fifo_reg       <= 1 ;
                                                  write_adr_out  <= write_adr_out_i  ;
                                                  write_data_out <= write_data_out_i ;
        end else begin
                              if (write_req_out)  fifo_reg       <= 0 ;
        end


  end // !reset
end // always
// **********************************************************************************


logic               [31:0] color=0,xycol1=0,xycol2=0,xycol3=0;
logic                      xyr1=0,xyr2=0,xyr3=0,pixel_in_pipe,sel_draw=0,draw_ena=0,rnd_sel=0;
logic signed        [13:0] x1=0,x2=0,x3=0,y1=0,y2=0,draw_x=0,draw_y=0;
logic [PORT_ADDR_SIZE-1:0] addr1=0;

// **********************************************************************************
// Ellipse generator.  *** Called, 'elli'.
// **********************************************************************************
localparam                     elli_bits     = 13 ; // The number of signed bits limiting the Elli's X&Y coordinates, remember, need that extra 1 since the controls are signed.
logic                          elli_ena      = 0 ;
logic                          elli_run      = 0 ;
logic          [1:0]           elli_quad     = 0 ;
logic                          elli_fill     = 0 ;
logic   signed [elli_bits-1:0] elli_xc       = 0 ;
logic   signed [elli_bits-1:0] elli_yc       = 0 ;
logic   signed [elli_bits-1:0] elli_xr       = 0 ;
logic   signed [elli_bits-1:0] elli_yr       = 0 ;

logic                          elli_busy         ;
logic   signed [elli_bits:0]   elli_xout         ; // ***** EXTRA bit needed for fills off screen bug.
logic   signed [elli_bits:0]   elli_yout         ;
logic                          elli_out_rdy      ;
logic                          elli_done         ;



logic           [6:0]          elli_count        ;
localparam                     elli_fill_ratio  = 5 ; // Number of non-filled ellipses VS a filled one when drawing random ellipses, max = 255.


ellipse_generator #(
.BITS_RES         (elli_bits         ),  // Coordinates IO port bits. 12 = -2048 to +2047
.BITS_RAD         (9                 ),  // Shrink the maximum possible radius to help FMAX.
.USE_ALTERA_IP    (1                 )   // Selects if Altera's LPM_MULT should be used VS a normal system verilog 'y <= a * b'
) elli_gen (                         
.clk              ( CMD_CLK          ),  // 125 MHz pixel clock
.reset            ( reset            ),  // asynchronous reset
.enable           ( elli_ena         ),  // logic enable
.run              ( elli_run         ),  // HIGH to draw / run the unit
.quadrant         ( elli_quad        ),  // specifies which quadrant of the ellipse to draw
.ellipse_filled   ( elli_fill        ),  // X-filling when drawing an ellipse.
.Xc               ( elli_xc          ),  // 12-bit X-coordinate for center of ellipse
.Yc               ( elli_yc          ),  // 12-bit Y-coordinate for center of ellipse
.Xr               ( elli_xr          ),  // 12-bit X-radius - Width of ellipse
.Yr               ( elli_yr          ),  // 12-bit Y-radius - height of ellipse
.ena_pause        ( pixel_cache_busy ),  // set HIGH to pause ELLIE while it is drawing
.busy             ( elli_busy        ),  // HIGH when line_generator is running
.X_coord          ( elli_xout        ),  // 12-bit X-coordinate for current pixel
.Y_coord          ( elli_yout        ),  // 12-bit Y-coordinate for current pixel
.pixel_data_rdy   ( elli_out_rdy     ),  // HIGH when coordinate outputs are valid
.ellipse_complete ( elli_done        )   // HIGH when ellipse is completed
);




// **********************************************************************************
// cleanly latch buttons & switches inputs.
// **********************************************************************************
always_ff @(posedge CMD_CLK) begin 
buttons_l  <= buttons  ;
switches_l <= switches ;
end

// **********************************************************************************
// Translate inputs.
// **********************************************************************************
always_comb begin

    // Convert the pixel width input into a bit shift for addressing pixels.
    case (DISP_pixel_bytes) 
            2 : pixel_byte_shift = 1 ;
            4 : pixel_byte_shift = 2 ;
      default : pixel_byte_shift = 0 ;
    endcase

end // always comb...


// **********************************************************************************
// Run drawing demo sequencer program.
// **********************************************************************************
always_ff @(posedge CMD_CLK) begin 

if (reset) begin              // RST_OUT is clocked on the CMD_CLK source.

        prog_pc         <= 0 ;
        counter         <= 0 ;
        
    end else begin


case (prog_pc)

    default : prog_pc<=prog_pc+1'b1;                  // If there is no matching program case#, just increment the program counter by default.

    0       : begin                                // Power-up/reset vector.

                counter         <= 0 ;
                elli_count      <= 0 ;
                sel_draw        <= 0 ; // Send draw_xy coordinates to the write pixel fifo.

                    case (buttons_l)
                    2'b11 :     prog_pc<=prog_pc+1'b1; // no button pressed, go to next program line
                    2'b01 :     prog_pc<=32;           // Static button pressed
                    2'b10 :     prog_pc<=32;           // Test pattern button pressed.
                    endcase
            end


    1       : begin                             // No button pressed
   
                sel_draw <= 1 ; // Send ELLI output to the write pixel fifo.

                if (switches_l[0] || buttons_l!=2'd3)  prog_pc  <= 0;  // Ellipses disabled, goto 0                                    
                else if (elli_busy) begin       // Elli was stuck doing something previously, allow it to clear out.
                                    elli_ena      <= 0 ;
                                    //elli_pause    <= 1 ;
                          end else  prog_pc       <= prog_pc+1'b1; // Elli is free, go onto the next program line
            end

    2       : begin                             // Elli is free, begin loading random numbers into it's specs.
    
                if (elli_count == elli_fill_ratio) begin   // Only draw 1 filled ellipse out of every 'elli_fill_ratio' parameter.
                                                    elli_fill  <= 1 ;
                                                    elli_count <= 0 ;
                end else begin
                                                    elli_fill  <= 0 ;
                                                    elli_count <= elli_count + 1'b1 ;
                end

                elli_xc       <= {1'd0,rnd_num[0 +:(elli_bits-1)]} ; // load positive random center coordinates
                elli_yc       <= {2'd0,rnd_num[16+:(elli_bits-2)]} ;
                prog_pc       <= prog_pc+1'b1;                          // next line in program.
            end

    3      : begin
                elli_xr       <= {4'd0,rnd_num[0 +:(elli_bits-4)]} ; // load positive random radius.
                elli_yr       <= {4'd0,rnd_num[16+:(elli_bits-4)]} ;
                prog_pc       <= prog_pc+1'b1;                          // next line in program.
            end
    4      : begin
                elli_quad     <= 0 ;                                 // set elli quadrant 0.
                color         <= rnd_num[31:0] ;                     // set random color.
                prog_pc       <= prog_pc+1'b1;                          // next line in program.
            end

    5      : begin  // draw elli.
                elli_ena      <= 1 ;
                elli_run      <= 1 ;
                prog_pc       <= prog_pc+1'b1;                          // next line in program.
            end

    6      : begin  // clear run command
                elli_run      <= 0 ;
                prog_pc       <= prog_pc+1'b1;                          // next line in program.
            end
    7      : begin
                if (!elli_busy && !pixel_in_pipe) prog_pc <= prog_pc+1'b1; // wait until elli is not busy an not drawing.
            end

    8      : begin
                if (elli_quad==3) prog_pc <= 1; // All 4 quadrants drawn, goto to the beginning of the elli random setup routine.
                else begin
                elli_quad <= elli_quad + 1'b1;    // increase the quadrant number.
                prog_pc   <= 5;                // goto PC=5, draw the next quadrant.
                end
            end


    31      : prog_pc<=0;  // Ellipses disabled, goto 0


    32      : begin
    
                draw_x  <= 0;
                draw_y  <= 0;
                rnd_sel <= buttons_l[0] ;
    
                    if (buttons_l==2'd3)  begin    // Buttons released, return to beginning of loop.
                                            prog_pc  <= 0 ;
                                            draw_ena <= 0 ;
                    end else                prog_pc  <= prog_pc+1'b1;                          // next line in program.
            end

    33      : begin // **** Generate static.
        
                        if (!pixel_cache_busy) begin
                
                            draw_ena             <= 1 ;
                            color[31:0]          <= rnd_sel ? ({counter[20:13],counter[16:1],8'h00}) : rnd_num[31:0] ;
                            counter              <= counter + 1 ;
                            
                            if (draw_x<(DISP_bitmap_width-1) ) draw_x <= draw_x + 1'b1;
                            else begin
                                                                   draw_x <= 0;
                                    if (draw_y<(DISP_bitmap_height-1)) draw_y <= draw_y + 1'b1;
                                    else begin
                                                                   draw_y  <= 0;
                                                                   prog_pc <= 32 ; // After drawing 1 full frame, got back and check the buttons again.
                                    end
                                 end
                        
                        end else begin
                
                            draw_ena        <= 0 ;
                            //ena_rnd         <= 0 ;
                
                        end
                end
    endcase
    

  end // !reset
end // always cmd_clk


// **********************************************************************************
// Convert X & Y output coordinates into a memory address.
// Step 1, Select source drawing data pipe, ELLI or other...
// Step 2, make sure the coordinates are inside the display area.
// Step 3, compute the base Y coordinate address offset
// Step 4, Add the X position coordinate.
// All these steps must sync & hold data to the 'elli_out_rdy' and 'pixel_cache_busy' flags.
// 
// **********************************************************************************

always_comb  pixel_in_pipe = xyr1 || xyr2 || xyr3 ; // make a status flag indicating that there are active pixels in the processing pipe. 
always_ff @(posedge CMD_CLK) begin 
if (reset) begin
    xyr1              <= 0 ;
    xyr2              <= 0 ;
    xyr3              <= 0 ;
    write_req_cache   <= 0 ;
end else begin

// Step 1, select between elli output and other graphics generators.
    xyr1   <= sel_draw ? elli_out_rdy : draw_ena ;
    x1     <= sel_draw ? elli_xout    : draw_x   ;
    y1     <= sel_draw ? elli_yout    : draw_y   ;
    xycol1 <= color        ;

// Step 2, make sure the coordinates are inside the display area.
    if (x1>=0 && x1<DISP_bitmap_width && y1>=0 && y1<=DISP_bitmap_height)  xyr2 <= xyr1 ; // If draw coordinates are inside the bitmap, allow the pixel ready through.
    else                                                                   xyr2 <= 0    ; // otherwise, strip out the
    x2     <= x1      ;
    y2     <= y1      ;
    xycol2 <= xycol1  ;

// Step 3, compute the base Y coordinate address offset
    xyr3   <= xyr2 ;
    addr1  <= PORT_ADDR_SIZE'(DISP_mem_addr + (y2*DISP_bitmap_width)) ;
    x3     <= x2      ;
    xycol3 <= xycol2  ;
    
// Step 4, Add the X position coordinate and output to pixel write fifo
    write_req_cache   <= xyr3 ;
    write_adr         <= (addr1 + x3) << pixel_byte_shift ;
    write_data        <= xycol3  ;

  end // !reset
end // always

endmodule


/*
// **********************************************************************************
// Renders a compressed video graphic from a 32 bit data source stream.
// **********************************************************************************
module vid_pattern_gen ( clk, cdat, datain, rdy, vena,hs,vs,videna,r,g,b ) ;

input           clk, cdat ;
input   [31:0]  datain ;

output  rdy,vena,hs,vs,videna;
reg     rdy,vena,hs,vs,videna;

output [7:0] r,g,b;
reg    [7:0] r,g,b;

reg          cdat_r;


always @ (posedge clk) begin

cdat_r <= cdat;
rdy    <= ~pixel_count[8];
vena   <= pixel_count[8];

if (cdat && ~cdat_r) begin
                    pixel_count[7:0] <= datain[7:0];
                    pixel_count[8]   <= 1;
                    
                    hs               <= (datain[31:24] == 255 && datain[15:8] == 255);
                    vs               <= (datain[31:24] == 255 && datain[23:16] == 255);
                    videna             <= ~(datain[31:24] == 255); 

                    b                <= datain[31:24];
                    g                <= datain[23:16];
                    r                <= datain[15:8];
                    end else begin
pixel_count[8:0] <= pixel_count[8:0] - pixel_count[8];

end // ! set data

end // always...
endmodule
*/











// **********************************************************************************
// Big, fat, deep 32 bit random number generator
// **********************************************************************************
//////////////////////////////////////////////////////////////////////
////                                                              ////
////  Random Number Generator                                     ////
////                                                              ////
////  This file is part of the SystemC RNG                        ////
////                                                              ////
////  Description:                                                ////
////                                                              ////
////  Implementation of random number generator                   ////
////                                                              ////
////  To Do:                                                      ////
////   - done                                                     ////
////                                                              ////
////  Author(s):                                                  ////
////      - Javier Castillo, javier.castillo@urjc.es              ////
////                                                              ////
////  This core is provided by Universidad Rey Juan Carlos        ////
////  [url]http://www.escet.urjc.es/~jmartine[/url]               ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from [url]http://www.opencores.org/lgpl.shtml[/url]          ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
//
//  ******** Warning **************
//
//  The original code from the link above was flawed and not written properly in verilog.
//  It did not generate anything close to random numbers, though the formula looked to
//  be correct.  I re-did the code as it seemed to be designed to operate and it appears
//  to generate a proper pseudo random distribution over hundreds of millions of iterations.
//
//  I left the original comment above as a consideration.
//
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
// ********************************************************************************************
module rnd ( clk, rst, ena, load, seed, out );

input             clk, rst, ena, load;
input      [31:0] seed ;
output reg [31:0] out ;

reg[36:0] CASR;
reg[42:0] LFSR;
always @(posedge clk) begin

   if ( rst ) begin

                    CASR  <= (37'h100000000); // Random starting point.
                    LFSR  <= (43'h100000000); // Random starting point.

   end else if (load) begin

                    CASR  <= 37'(seed) | 33'h100000000 ; // Load seed, protect from a seed of 0.
                    LFSR  <= 43'(seed) | 33'h100000000 ; // Load seed, protect from a seed of 0.

   end else if (ena) begin

                    CASR[36:0] <= ( {CASR[35:0],CASR[36]} ^ {CASR[0],CASR[36:1]} ^ CASR[27]<<27 ) ;
                    LFSR[42:0] <= ( {LFSR[41:0],LFSR[42]} ^ LFSR[42]<<41 ^ LFSR[42]<<20 ^ LFSR[42]<<1 ) ;

                    out [31:0] <= ( LFSR [31:0] ^ CASR[31:0] );

    end
end
endmodule

