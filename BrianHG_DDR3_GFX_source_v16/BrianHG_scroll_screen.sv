// *****************************************************************
// Demo BHG BrianHG_scroll_screen.
// IE: Scrolls the larger graphic source image on the smaller 1080p screen
//
// Version 0.5, June 28, 2021.
//
// Written by Brian Guralnick.
// For public use.
//
//
// Bit 0 = draw static,     Bit 1 = draw pattern
// Bit 0 = enable ellipses, Bit 1 = enable screen scrolling.
//
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
module BrianHG_scroll_screen #( 
parameter bit [7:0] speed_bits = 1,
parameter bit [7:0] min_speed  = 2
)(
input  logic                        CLK_IN            ,
input  logic                        CMD_CLK           ,
input  logic                        reset             ,
input  logic        [7:0]           rnd               ,

input  logic                        VID_xena_in       ,         // Horizontal alignment.
input  logic                        VID_yena_in       ,         // Vertical alignment.   Used for vertical timing the scrolling.


input  logic        [15:0]          DISP_bitmap_width ,         // The bitmap width of the graphic in memory.
input  logic        [15:0]          DISP_bitmap_height,         // The bitmap width of the graphic in memory.
input  logic        [13:0]          DISP_xsize        ,         // The video output X resolution.
input  logic        [13:0]          DISP_ysize        ,         // The video output Y resolution.

output logic signed [13:0]          out_xpos          ,         // Horizontally shift the display output X pixel
output logic signed [13:0]          out_ypos          ,         // Vertically shift the display output Y position.

input               [1:0]           buttons           ,         // 2 buttons on deca board.
input               [1:0]           switches                    // 2 switches on deca board.
);


logic              dir_x    ;
logic              dir_y    ;
logic signed [7:0] speed_x  ;
logic signed [7:0] speed_y  ;
logic              hs_reset ;
logic              VID_xena_in_dl,VID_yena_in_dl ;
logic        [1:0] buttons_l,switches_l ;

always_comb begin
    // Find the new beginning of a new horizontal line.
    hs_reset = VID_xena_in && !VID_xena_in_dl;  // *********************** Make sure this trigger point is well after the 'VID_yena_in' is asserted,
                                                // otherwise vertical jumping may occur due to these sync signals coming from the video output clock domain.
                                                // Also make sure this trigger point is far enough outside the beginning of the picture display area for the
                                                // same reason as the line buffer 'Y' position bit 0 needs to be sent a few pixel clocks in advance so that the
                                                // beginning of the display line will not show a few pixels of the previous Y position line buffer.

end

// **********************************************************************************
// cleanly latch buttons & switches inputs.
// **********************************************************************************
always_ff @(posedge CLK_IN) begin 
buttons_l  <= buttons  ;
switches_l <= switches ;
end

// **********************************************************************************
// Run scrolling
// **********************************************************************************
always_ff @(posedge CMD_CLK) begin 

if (reset) begin              // RST_OUT is clocked on the CMD_CLK source.

            out_xpos           <= 0 ;
            out_ypos           <= 0 ;

            dir_x              <= 0 ;
            dir_y              <= 0 ;

            speed_x            <= min_speed ;
            speed_y            <= min_speed ;

    end else begin

    VID_xena_in_dl <= VID_xena_in;

        if (hs_reset) begin                                 // Run the following once during a H-Sync event.
            
                VID_yena_in_dl <= VID_yena_in ;             // Generate a snapshot of the vertical enable once every HS.
            
                if (!VID_yena_in && VID_yena_in_dl ) begin  // One-shot vertical reset period, perform the scrolling function.


                    if ( !switches_l[1] ) begin       
        
                                     if ( (dir_x==0) && ((out_xpos+speed_x)>=(DISP_bitmap_width-DISP_xsize)) ) begin
                                                                                                dir_x   <= 1 ;
                                                                                                set_rdn_speed(1,1);
                            end else if ( (dir_x==1) && ((out_xpos-speed_x)<0                              ) ) begin
                                                                                                dir_x   <= 0 ;
                                                                                                set_rdn_speed(1,1);
                            end else if (  dir_x==0                                             )              out_xpos <= out_xpos + speed_x ;
                            else                                                                               out_xpos <= out_xpos - speed_x ;
        
        
                                     if ( (dir_y==0) && ((out_ypos+speed_y)>=(DISP_bitmap_height-DISP_ysize)) ) begin
                                                                                                dir_y   <= 1 ;
                                                                                                set_rdn_speed(1,1);
                            end else if ( (dir_y==1) && ((out_ypos-speed_y)<0                               ) ) begin
                                                                                                dir_y   <= 0 ;
                                                                                                set_rdn_speed(1,1);
                            end else if (  dir_y==0                                             )               out_ypos <= out_ypos + speed_y ;
                            else                                                                                out_ypos <= out_ypos - speed_y ;
        
                    end // switches...

                end // one shot vertical sync.

        end // hs_reset
    end // !reset
end // always cmd_clk



task set_rdn_speed(bit x, bit y);
begin
    if (x) speed_x <= min_speed + rnd[0+:speed_bits]  ;
    if (y) speed_y <= min_speed + rnd[speed_bits+:speed_bits]  ;
end
endtask

endmodule
