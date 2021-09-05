// --------------------------------------------------------------------
// Copyright (c) 2007 by Terasic Technologies Inc. 
// --------------------------------------------------------------------
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Terasic Technologies Inc
//                     356 Fu-Shin E. Rd Sec. 1. JhuBei City,
//                     HsinChu County, Taiwan
//                     302
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// --------------------------------------------------------------------
// 
// Modified by BrianHG for the all software DDR3 demo video ram controller.


`include "BHG_vpg.h"

module BHG_vpg(
	clk_50,
	reset_n,
	vpg_pclk_out,
	vpg_de,
	vpg_hs,
	vpg_vs,
	vpg_a,
	vpg_r,
	vpg_g,
	vpg_b,
    
    CMD_CLK,            // Line buffer memory interface data input clock.
    CMD_xpos_in,        // Adjust the beginning horizontal X position in the line buffer memory at next H-Sync.
    CMD_ypos_in,        // Select which Y line buffer to show at the next H-Sync.  Either 0, or 1.
    CMD_xena_out,       // Equivalent to an H-Sync, high during active video & clocked the CMD_CLK.
    CMD_yena_out,       // Equivalent to an V-Sync, high during active video minus 1 line, & clocked the CMD_CLK.
    CMD_line_mem_wena,  // Write enable for the line buffer.
    CMD_line_mem_waddr, // Line buffer write address.
    CMD_line_mem_wdata  // Line buffer write data.
);

// Line buffer notes:
// Output side -> 2048 pixels by 32 bit by 2 lines output = 16384 Kilobytes, or 131072 kilobits.
//
// Input side  -> 128 bits = 512 addresses x 2 lines = 1024 addresses.
//                           9 bits for every 4x32 bit pixels, and 1 bit for even or odd buffer line.
//



input	  		     clk_50;
input	  		     reset_n;
output			  vpg_pclk_out;
output			  vpg_de;
output			  vpg_hs;
output			  vpg_vs;
output	[7:0]   vpg_a;    // Alpha channel color
output	[7:0]   vpg_r;
output	[7:0]   vpg_g;
output	[7:0]   vpg_b;


input           CMD_CLK        ; // Line buffer memory interface data input clock.
input  [1:0]    CMD_xpos_in    ; // Adjust the beginning horizontal X position in the line buffer memory at next H-Sync.
input           CMD_ypos_in    ; // Select which Y line buffer to show at the next H-Sync.  Either 0, or 1.
output          CMD_xena_out   ; // Equivalent to an H-Sync, high during active video & clocked the CMD_CLK.
output          CMD_yena_out   ; // Equivalent to an V-Sync, high during active video minus 1 line, & clocked the CMD_CLK.
input           CMD_line_mem_wena  ; // Write enable for the line buffer.
input  [9:0]    CMD_line_mem_waddr ; // Line buffer write address.
input  [127:0]  CMD_line_mem_wdata ; // Line buffer write data.


//=======================================================
//  Signal declarations
//=======================================================
//============= assign timing constant  
wire  [11:0] h_total, h_sync, h_start, h_end; 
wire  [11:0] v_total, v_sync, v_start, v_end; 
wire  [11:0] v_active_14, v_active_24, v_active_34; 

//=======================================================
//  Sub-module
//=======================================================
//=============== PLL reconfigure
wire  vpg_pclk ;

pll_cv u_pll (
  .inclk0(clk_50),           
  .areset(!reset_n),              
  .c0(vpg_pclk) 
   );
assign vpg_pclk_out = vpg_pclk; //*************************************** problematic, to invert or not invert???
//=============== pattern generator according to vga timing
BHG_vga_generator u_vga_generator (                                    
  .clk(vpg_pclk),                
  .reset_n(reset_n),                                                
  .h_total(h_total),           
  .h_sync(h_sync),           
  .h_start(h_start),             
  .h_end(h_end),                                                    
  .v_total(v_total),           
  .v_sync(v_sync),            
  .v_start(v_start),           
  .v_end(v_end), 
  .v_active_14(v_active_14), 
  .v_active_24(v_active_24), 
  .v_active_34(v_active_34), 
  .vga_hs(vpg_hs),
  .vga_vs(vpg_vs),           
  .vga_de(vpg_de),
  .vga_a(vpg_a),
  .vga_r(vpg_r),
  .vga_g(vpg_g),
  .vga_b(vpg_b),

  .CMD_CLK            ( CMD_CLK        ),
  .CMD_xpos_in        ( CMD_xpos_in    ),
  .CMD_ypos_in        ( CMD_ypos_in    ),
  .CMD_xena_out       ( CMD_xena_out   ),
  .CMD_yena_out       ( CMD_yena_out   ),
  .CMD_line_mem_wena  ( CMD_line_mem_wena  ),
  .CMD_line_mem_waddr ( CMD_line_mem_waddr ),
  .CMD_line_mem_wdata ( CMD_line_mem_wdata )  );


//=======================================================
//  Structural coding
//=======================================================
//============= assign timing constant  
//h_total : total - 1
//h_sync : sync - 1
//h_start : sync + back porch - 1 - 2(delay)
//h_end : h_start + avtive
//v_total : total - 1
//v_sync : sync - 1
//v_start : sync + back porch - 1
//v_end : v_start + avtive
//v_active_14 : v_start + 1/4 avtive
//v_active_24 : v_start + 2/4 avtive
//v_active_34 : v_start + 3/4 avtive

//640x480@60 25.175 MHZ
//assign {h_total, h_sync, h_start, h_end} = {12'd799, 12'd95, 12'd141, 12'd781}; 
//assign {v_total, v_sync, v_start, v_end} = {12'd524, 12'd1, 12'd34, 12'd514}; 
//assign {v_active_14, v_active_24, v_active_34} = {12'd154, 12'd274, 12'd394};
	
		
//720x480@60 27MHZ (VIC=3, 480P)
//assign {h_total, h_sync, h_start, h_end} = {12'd857, 12'd61, 12'd119, 12'd839}; 
//assign {v_total, v_sync, v_start, v_end} = {12'd524, 12'd5, 12'd35, 12'd515}; 
//assign {v_active_14, v_active_24, v_active_34} = {12'd155, 12'd275, 12'd395};
			
//1024x768@60 65MHZ (XGA)
//assign {h_total, h_sync, h_start, h_end} = {12'd1343, 12'd135, 12'd293, 12'd1317}; 
//assign {v_total, v_sync, v_start, v_end} = {12'd805, 12'd5, 12'd34, 12'd802}; 
//assign {v_active_14, v_active_24, v_active_34} = {12'd226, 12'd418, 12'd610};

//1280x1024@60   108MHZ (SXGA)
//assign {h_total, h_sync, h_start, h_end} = {12'd1687, 12'd111, 12'd357, 12'd1637}; 
//assign {v_total, v_sync, v_start, v_end} = {12'd1065, 12'd2, 12'd40, 12'd1064}; 
//assign {v_active_14, v_active_24, v_active_34} = {12'd296, 12'd552, 12'd808};

//1920x1080p60 148.5MHZ 	
assign {h_total, h_sync, h_start, h_end} = {12'd2199, 12'd43, 12'd189, 12'd2109}; 
assign {v_total, v_sync, v_start, v_end} = {12'd1124, 12'd4, 12'd40, 12'd1120}; 
assign {v_active_14, v_active_24, v_active_34} = {12'd310, 12'd580, 12'd850};
		
//1600x1200p60 162MHZ (VESA)
//assign {h_total, h_sync, h_start, h_end} = {12'd2159, 12'd191, 12'd493, 12'd2093}; 
//assign {v_total, v_sync, v_start, v_end} = {12'd1249, 12'd2, 12'd48, 12'd1248}; 
//assign {v_active_14, v_active_24, v_active_34} = {12'd348, 12'd648, 12'd948};

endmodule 