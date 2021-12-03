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

// mode define
`define VGA_640x480p60		0
`define MODE_720x480    	1	// 480p,  	27		MHZ	   VIC=3
`define MODE_1024x768		  2	// XGA,   	65		MHZ	 
`define MODE_1280x1024		3	// SXGA,  	108		MHZ
`define FHD_1920x1080p60	4	// 1080i, 	74.25	MHZ    VIC=5 
`define VESA_1600x1200p60 5   // VESA 	162 	MHZ	

`define COLOR_RGB444	    0

