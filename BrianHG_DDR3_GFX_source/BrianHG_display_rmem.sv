// *****************************************************************
// Demo BHG Read DDR3 display raster memory address generator.
// IE: It reads ram to render a display using a given base memory address, bitmap width, 
//     with the pixel depth, width and height of the output, and the beginning top left corner X&Y
//     coordinates where to begin the framing of the output within the raster.
//
// Version 1.5, October 26, 2021.
//
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
module BrianHG_display_rmem #(
parameter int                       PORT_ADDR_SIZE      = 24 ,  // Must match PORT_ADDR_SIZE.
parameter int                       PORT_VECTOR_SIZE    = 12 ,  // Must match PORT_VECTOR_SIZE and be at least 10 for the video line pointer. 
parameter int                       PORT_R_DATA_WIDTH   = 128   // Must match PORT_R_DATA_WIDTH. 
)(

input  logic                        CMD_CLK           ,
input  logic                        reset             ,
                                                                
input  logic        [2:0]           DISP_pixel_bytes  ,         // 4=32 bit pixels, 2=16bit pixels, 1=8bit pixels.
input  logic        [31:0]          DISP_mem_addr     ,         // Beginning memory address of graphic bitmap pixel position 0x0.
input  logic        [15:0]          DISP_bitmap_width ,         // The bitmap width of the graphic in memory.
input  logic        [13:0]          DISP_xsize        ,         // The video output X resolution.
input  logic        [13:0]          DISP_ysize        ,         // The video output Y resolution.
input  logic        [13:0]          DISP_xpos         ,         // Horizontally shift the display output X pixel
input  logic        [13:0]          DISP_ypos         ,         // Vertically shift the display output Y position.
                                                                
input  logic                        read_busy_in      ,         // DDR3 ram read channel #1 was selected for reading the video ram.
output logic                        read_req_out      ,
output logic [PORT_ADDR_SIZE-1:0]   read_adr_out      ,
output logic [PORT_VECTOR_SIZE-1:0] read_line_mem_adr ,

input  logic                        VID_xena_in       ,         // Horizontal alignment.
input  logic                        VID_yena_in       ,         // Vertical alignment.
output logic [1:0]                  VID_xpos_out      ,         // Shift the beginning X position within the 4 pixel wide word.
output logic                        VID_ypos_out                // Output the display Y line buffer 1 or 2.
);

localparam   READ_WORD_SIZE   = PORT_R_DATA_WIDTH/8 ;     // Each read word may be 128 bits, but the DDR3_PHY_SEQ address operates in bytes regardless of port width. 
localparam   PIXEL_WORD_SHIFT = $clog2(READ_WORD_SIZE) ;  // Each pixel is 4 bytes, but the since we are addressing 128bits, we need a bit shift divide read count for calculating read word vs pixels.

logic                       VID_xena_in_dl,hs_reset ;
logic [1:0]                 pixel_byte_shift ;
logic [PORT_ADDR_SIZE-1:0]  disp_addr, mem_addr;
logic [11:0]                rast_y;
logic [11:0]                read_count;
logic [11:0]                lb_waddr;


always_comb begin

    // Find the new beginning of a new horizontal line.
    hs_reset = VID_xena_in && !VID_xena_in_dl;  // *********************** Make sure this trigger point is well after the 'VID_yena_in' is asserted,
                                                // otherwise vertical jumping may occur due to these sync signals coming from the video output clock domain.
                                                // Also make sure this trigger point is far enough outside the beginning of the picture display area for the
                                                // same reason as the line buffer 'Y' position bit 0 needs to be sent a few pixel clocks in advance so that the
                                                // beginning of the display line will not show a few pixels of the previous Y position line buffer.

    // Convert the pixel width input into a bit shift for addressing pixels.
    case (DISP_pixel_bytes) 
            2 : pixel_byte_shift = 1 ;
            4 : pixel_byte_shift = 2 ;
      default : pixel_byte_shift = 0 ;
    endcase

    read_line_mem_adr = PORT_VECTOR_SIZE'(lb_waddr) ;

end // always comb...

always_ff @(posedge CMD_CLK) begin 

if (reset) begin              // RST_OUT is clocked on the CMD_CLK source.

            VID_xpos_out       <= 0 ;
            VID_ypos_out       <= 0 ;
            read_req_out       <= 0 ;
            read_adr_out       <= 0 ;
            lb_waddr           <= 0 ;

            VID_xena_in_dl     <= 0 ;
            disp_addr          <= 0 ;
            mem_addr           <= 0 ;
            rast_y             <= 0 ;
            read_count         <= 0 ;

    end else begin

    VID_xena_in_dl <= VID_xena_in;

    disp_addr      <= ((DISP_bitmap_width * DISP_ypos + DISP_xpos) << pixel_byte_shift) ; // separate/break down the pointer math into 2 blocks.
    VID_ypos_out   <= !rast_y[0] ;                          // Select which half of the output line buffer is to be displayed.

        if (hs_reset) begin                                 // Run the following once during a H-Sync event.
            
                if (!VID_yena_in) begin                     // vertical reset period...
        
                rast_y            <= 0 ;
                read_req_out      <= 0 ;
                VID_xpos_out      <= DISP_xpos[1:0] ;       // Send the beginning pixel X coordinate within the 4 pixel word to shift the output display on a pixel/by/pixel basis. 
                mem_addr          <= PORT_ADDR_SIZE'(DISP_mem_addr + disp_addr) ;
        
                end else begin
                rast_y                 <= rast_y + 1'b1 ;
                read_req_out           <= 0 ;
                mem_addr               <= mem_addr + (DISP_bitmap_width<<pixel_byte_shift) ;
                read_adr_out           <= mem_addr ;
                lb_waddr               <= 12'((!rast_y[0])<<9) ;                  // Reset destination line buffer write address with line y[0] to select which half to write to. 
                read_count             <= 12'( DISP_xsize >> pixel_byte_shift ) ; // *** Note, we are reading 1 extra word in case the DISP_xpos horizontal display is between pixels 1 and 3 instead of 0.
                end



        end else begin // We aren't processing a H-sync event, send out read requests.

                if (!read_busy_in && !read_count[11]) begin     // When the read port isn't busy and the read count hasn't reached -1
                                                       read_req_out      <= 1 ;  // request a read.
                                                       read_count        <= read_count - 1'd1 ;               // decrease the read counter.
                end else                               read_req_out      <= 0 ;  // no read request.

                if (read_req_out ) begin                                     // only change these pointers after a 'read req' was sent out.
                     read_adr_out      <= PORT_ADDR_SIZE'(read_adr_out + READ_WORD_SIZE) ;   // increment the read address by the ready word size. 
                     lb_waddr          <= lb_waddr + 1'd1 ;                 // increment the destination line buffer memory X position pointer.
                end

        end // !hs_reset


    end // !reset
end // always cmd_clk

endmodule
