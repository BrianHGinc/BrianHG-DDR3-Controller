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
// Modded by BrianHG to have a 2 line dual port dual clock line buffer
// input plus a H&V synchronization outputs switched over to the CMD clock.
//

module BHG_vga_generator(                                    
  input              clk,                
  input              reset_n,                                                
  input       [11:0] h_total,           
  input       [11:0] h_sync,           
  input       [11:0] h_start,             
  input       [11:0] h_end,                                                    
  input       [11:0] v_total,           
  input       [11:0] v_sync,            
  input       [11:0] v_start,           
  input       [11:0] v_end, 
  input       [11:0] v_active_14, 
  input       [11:0] v_active_24, 
  input       [11:0] v_active_34, 
  output  reg	       vga_hs,             
  output  reg         vga_vs,           
  output  reg         vga_de,
  output  reg  [7:0]  vga_a,    // Alpha channel color
  output  reg  [7:0]  vga_r,
  output  reg  [7:0]  vga_g,
  output  reg  [7:0]  vga_b,

  input               CMD_CLK            ,  // Line buffer memory interface data input clock.
  input      [1:0]    CMD_xpos_in        ,  // Adjust the beginning horizontal X position in the line buffer memory at next H-Sync.
  input               CMD_ypos_in        ,  // Select which Y line buffer to show at the next H-Sync.  Either 0, or 1.
  output reg          CMD_xena_out       ,  // Equivalent to an H-Sync, high during active video & clocked the CMD_CLK.
  output reg          CMD_yena_out       ,  // Equivalent to an V-Sync, high during active video minus 1 line, & clocked the CMD_CLK.
  input               CMD_line_mem_wena  ,  // Write enable for the line buffer.
  input      [9:0]    CMD_line_mem_waddr ,  // Line buffer write address.
  input      [127:0]  CMD_line_mem_wdata    // Line buffer write data.
);

//=======================================================
//  Signal declarations
//=======================================================
reg			  [11:0]	h_count;
reg			  [10:0]	pixel_x;
reg			  [11:0]	v_count;
reg               h_act; 
//reg               h_act_d;
reg               v_act; 
reg               v_act_early;    // A flag beginning 1 line of video early for the display memory processor.
//reg               v_act_early_d;  // A flag beginning 1 line of video early for the display memory processor.
//reg               v_act_d; 
reg               pre_vga_de,pre_vga_de1,pre_vga_de2;
wire              h_max, hs_end, hr_start, hr_end;
wire              v_max, vs_end, vr_start, vr_end;
//reg               boarder;
//reg        [3:0]  color_mode;

wire [7:0]  wvga_a ;
wire [7:0]  wvga_r ;
wire [7:0]  wvga_g ;
wire [7:0]  wvga_b ;

reg               vr_start_early,vr_end_early,pixel_line;

//=======================================================
//  Structural coding
//=======================================================
assign h_max = h_count == h_total;
assign hs_end = h_count >= h_sync;
assign hr_start = h_count == h_start; 
assign hr_end = h_count == h_end;
assign v_max = v_count == v_total;
assign vs_end = v_count >= v_sync;
assign vr_start = v_count == v_start; 
assign vr_end = v_count == v_end;

assign vr_start_early = v_count == (v_start-1'b1); 
assign vr_end_early = v_count == (v_end-1'b1);


//horizontal control signals
always @ (posedge clk or negedge reset_n)
	if (!reset_n)
	begin
    //h_act_d   <=  1'b0;
		h_count		<=	12'b0;
		pixel_x   <=  8'b0;
		vga_hs		<=	1'b1;
		h_act	    <=	1'b0;
	end
	else
	begin

    pixel_line <= CMD_ypos_in       ;  // This selects the even or odd Y line position in the line buffer memory.
    //h_act_d    <=  h_act;

    if (h_max)
		  h_count	<= 12'b0;
		else
		  h_count	<= h_count + 12'b1;

    if (!hr_start)
		  pixel_x	<=	pixel_x + 11'b1;
		else begin
		  pixel_x	 <=  11'(CMD_xpos_in) ;  // This allows the horizontal pixel on each line to begin on 1 of the 4 pixels / 128bit line buffer.
        end

		if (hs_end && !h_max)
		  vga_hs	<=	1'b1;
		else
		  vga_hs	<= 1'b0;

		if (hr_start)
		  h_act	  <=	1'b1;
		else if (hr_end)
		  h_act	  <=	1'b0;
	end

//vertical control signals
always@(posedge clk or negedge reset_n)
	if(!reset_n)
	begin
		//v_act_d	       <=	1'b0;
		//v_act_early_d  <=	1'b0;
		v_count		   <=	12'b0;
		vga_vs	  	<=	1'b1;
		v_act	    <=	1'b0;
		//color_mode<=  4'b0;
	end
	else 
	begin		
		if (h_max)
		begin		  
  		//v_act_d	      <=	v_act;
  		//v_act_early_d <=	v_act_early;
		  
		  if (v_max)
		    v_count	<=	12'b0;
		  else
		    v_count	<=	v_count + 12'b1;

		  if (vs_end && !v_max)
		    vga_vs	<=	1'b1;
		  else
		    vga_vs	<=	1'b0;

  		if (vr_start)
	  	  v_act <=	1'b1;
		  else if (vr_end)
		    v_act <=	1'b0;

  		if (vr_start_early)
	  	  v_act_early <=	1'b1; // A flag beginning 1 line of video early for the display memory processor.
		  else if (vr_end)
		    v_act_early <=	1'b0;

	    end
    end

//pattern generator and display enable
always @(posedge clk or negedge reset_n)
begin
	if (!reset_n)
	begin
    vga_de <= 1'b0;
    pre_vga_de <= 1'b0;
    //boarder <= 1'b0;		
  end
	else
	begin
    vga_de      <= pre_vga_de1;
    pre_vga_de  <= pre_vga_de1;
    pre_vga_de1 <= pre_vga_de2;
    pre_vga_de2 <= v_act && h_act;
    
	 {vga_a,vga_b,vga_g,vga_r} <= {wvga_a,wvga_b,wvga_g,wvga_r} ; // latch stage for separation from core ram to IO pins.
	 
	end
end	

// **********************************************************
// Convert the synchronization signals from the video pixel
// clock to the CMD clock.
// **********************************************************
always @(posedge CMD_CLK ) begin
CMD_yena_out <= v_act_early ; // v_act_early...
CMD_xena_out <= vga_hs; //h_act ;
end

// Initiate the line buffer memory.

	altsyncram	Line_Buffer_DP_ram (
				.address_a            ( CMD_line_mem_waddr         ),
				.address_b            ( ({pixel_line,pixel_x[10:0]}) ^ 12'd3 ),  // Don't forget that Endian swap....
				.clock0               ( CMD_CLK                    ),
				.clock1               ( clk                        ),
				.data_a               ( CMD_line_mem_wdata         ),
				.wren_a               ( CMD_line_mem_wena          ),
				.q_b                  ( {wvga_a,wvga_b,wvga_g,wvga_r}  ),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b ({32{1'b1}}),
				.eccstatus (),
				.q_a (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		Line_Buffer_DP_ram.address_aclr_b = "NONE",
		Line_Buffer_DP_ram.address_reg_b = "CLOCK1",
		Line_Buffer_DP_ram.clock_enable_input_a = "BYPASS",
		Line_Buffer_DP_ram.clock_enable_input_b = "BYPASS",
		Line_Buffer_DP_ram.clock_enable_output_b = "BYPASS",
        Line_Buffer_DP_ram.init_file = "line_buf_init.mif",
        Line_Buffer_DP_ram.init_file_layout = "PORT_B",
		Line_Buffer_DP_ram.intended_device_family = "MAX 10",
		Line_Buffer_DP_ram.lpm_type = "altsyncram",
		Line_Buffer_DP_ram.numwords_a = 1024,
		Line_Buffer_DP_ram.numwords_b = 4096,
		Line_Buffer_DP_ram.operation_mode = "DUAL_PORT",
		Line_Buffer_DP_ram.outdata_aclr_b = "NONE",
		Line_Buffer_DP_ram.outdata_reg_b = "CLOCK1",
		Line_Buffer_DP_ram.power_up_uninitialized = "FALSE",
		Line_Buffer_DP_ram.widthad_a = 10,
		Line_Buffer_DP_ram.widthad_b = 12,
		Line_Buffer_DP_ram.width_a = 128,
		Line_Buffer_DP_ram.width_b = 32,
		Line_Buffer_DP_ram.width_byteena_a = 1;



endmodule

