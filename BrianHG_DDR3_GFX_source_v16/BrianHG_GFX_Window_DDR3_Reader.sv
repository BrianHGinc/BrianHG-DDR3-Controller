// *****************************************************************
// BrianHG_GFX_Window_DDR3_Reader display raster memory address generator.
// IE: It reads ram to render a display using a given base memory address, bitmap width, 
//     with the pixel depth, width and height of the output, and the beginning top left corner X&Y
//     coordinates where to begin the framing of the output within the raster.
//
// Version 1.6, October 26, 2021.
//
// Supports multiple windows / layers.
//
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
module BrianHG_GFX_Window_DDR3_Reader #(

parameter int        PORT_ADDR_SIZE         = 24 ,                     // Must match PORT_ADDR_SIZE.
parameter int        PORT_VECTOR_SIZE       = 12 ,                     // Must match PORT_VECTOR_SIZE and be at least large enough for the video line pointer + line buffer module ID.
parameter int        PORT_CACHE_BITS        = 128,                     // Must match PORT_R/W_DATA_WIDTH and be PORT_CACHE_BITS wide for optimum speed.
parameter            HC_BITS                = 16,                      // Width of horizontal counter.
parameter            VC_BITS                = 16,                      // Width of vertical counter.
parameter bit [3:0]  PDI_LAYERS             = 1,                       // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
parameter bit [3:0]  SDI_LAYERS             = 1,                       // Use 1,2,4, or 8 sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system.
parameter bit        ENABLE_TILE_MODE       = 1,                       // Enable tile mode for each PDI_LAYER.

parameter int        LBUF_BITS           = PORT_CACHE_BITS,            // The bit width of the CMD_line_buf_wdata
parameter int        LBUF_WORDS          = 256,                        // The total number of 'CMD_line_buf_wdata' words of memory.
                                                                       // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                                                       // Only use factors of 2, IE: 256/512/1024...
parameter bit [9:0]  MAX_BURST           = LBUF_WORDS/4/SDI_LAYERS,    // Generic maximum burst length.  IE: A burst will not be called unless this many free words exist inside the line buffer memory.
parameter bit [9:0]  MAX_BURST_1st       = (MAX_BURST/4),              // In a multi-window system, this defines the maximum read burst size per window after the H-reset period
                                                                       // allowing all the window buffers to gain a minimal amount of graphic data before running full length bursts.

// ******* Do not edit these ****
parameter bit [6:0]  LAYERS              = PDI_LAYERS * SDI_LAYERS   ,   // Total window layers in system
parameter int        CACHE_ADW           = $clog2(PORT_CACHE_BITS/8) ,   // This is the number of address bits for the number of bytes within a single cache block.
parameter int        LBUF_CACHE_ADW      = $clog2(LBUF_BITS/8)       ,   // This is the number of address bits for the number of bytes within a single cache block.
parameter int        LBUF_DADW           = $clog2(LBUF_BITS/32)      ,   // This is the number of address bits for the number of bytes within the 32bit display output.
parameter int        LBUF_ADW            = $clog2(LBUF_WORDS)        ,   // This is the number of address bits for the line buffer on the write side.
parameter int        LBUF_ADW_WIN        = $clog2(LBUF_WORDS/SDI_LAYERS) // This is the number of address bits for the line buffer per window layer.

)(
// *****************************************************************
// **** Window control inputs ****
// *****************************************************************
input                               CMD_RST                            , // CMD section reset.
input                               CMD_CLK                            , // System CMD RAM clock.
input                               CMD_DDR3_ready                     , // Enables display and DDR3 reading of data.

input                               CMD_win_enable         [0:LAYERS-1], // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB.
input        [2:0]                  CMD_win_bpp            [0:LAYERS-1], // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB.
input        [31:0]                 CMD_win_base_addr      [0:LAYERS-1], // The beginning memory address for the window.
input        [HC_BITS-1:0]          CMD_win_bitmap_width   [0:LAYERS-1], // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.
input        [HC_BITS-1:0]          CMD_win_bitmap_x_pos   [0:LAYERS-1], // The beginning X pixel position inside the bitmap in memory.
input        [VC_BITS-1:0]          CMD_win_bitmap_y_pos   [0:LAYERS-1], // The beginning Y line position inside the bitmap in memory.

input        [HC_BITS-1:0]          CMD_win_x_offset       [0:LAYERS-1], // The onscreen X position of the window.
input        [VC_BITS-1:0]          CMD_win_y_offset       [0:LAYERS-1], // The onscreen Y position of the window.
input        [HC_BITS-1:0]          CMD_win_x_size         [0:LAYERS-1], // The onscreen display width of the window.      *** Using 0 will disable the window.
input        [VC_BITS-1:0]          CMD_win_y_size         [0:LAYERS-1], // The onscreen display height of the window.     *** Using 0 will disable the window.

input        [3:0]                  CMD_win_scale_width    [0:LAYERS-1], // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
input        [3:0]                  CMD_win_scale_height   [0:LAYERS-1], // Pixel vertical zoom height.   For 1x,2x,3x thru 16x, use 0,1,2 thru 15.
input        [3:0]                  CMD_win_scale_h_begin  [0:LAYERS-1], // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
input        [3:0]                  CMD_win_scale_v_begin  [0:LAYERS-1], // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.

input                               CMD_win_tile_enable    [0:LAYERS-1], // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer
                                                                         //                               module's ENABLE_TILE_MODE parameter isn't turned on.

input        [2:0]                  CMD_win_tile_bpp       [0:LAYERS-1], // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
input        [15:0]                 CMD_win_tile_base      [0:LAYERS-1], // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
                                                                         // *** This is the address inside the line buffer tile/font blockram which always begins at 0, NOT the DDR3 TAP_xxx port write address.
input        [1:0]                  CMD_win_tile_width     [0:LAYERS-1], // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
input        [1:0]                  CMD_win_tile_height    [0:LAYERS-1], // Defines the height of the tile. 0,1,2,3 = 4,8,16,32

// *****************************************************************
// **** DDR3 Read channel control ****
// *****************************************************************
input                                  CMD_busy                 , // Only send out commands when DDR3 is not busy.
output logic                           CMD_ena              = 0 , // Transmit a DDR3 command.
output logic                           CMD_write_ena            , // Send a write data command. *** Not in use.
output logic [PORT_CACHE_BITS-1:0]     CMD_wdata                , // Write data.                *** Not in use.
output logic [PORT_CACHE_BITS/8-1:0]   CMD_wmask                , // Write mask.                *** Not in use.
output logic [PORT_ADDR_SIZE-1:0]      CMD_addr             = 0 , // DDR3 memory address in byte form.
output logic [PORT_VECTOR_SIZE-1:0]    CMD_read_vector_tx   = 0 , // Contains the destination line buffer address.  ***_tx to avoid confusion, IE: Send this port to the DDR3's read vector input.
output logic                           CMD_priority_boost       , // Boost the read command above everything else including DDR3 refresh. *** Not in use.

// *****************************************************************
// **** Line Buffer status synchronization inputs ****
// *****************************************************************
input                               lb_stat_hrst                       , // Strobes for 1 clock when the end of the display line has been reached.
input                               lb_stat_vena                       , // High during the active lines of the display frame.
input                               lb_stat_qinc           [0:LAYERS-1], // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.

// *****************************************************************
// **** Line buffer control outputs ****
// *****************************************************************
output logic                        CMD_vid_ena            [0:LAYERS-1], // Enable the video line. 
output logic [2:0]                  CMD_vid_bpp            [0:LAYERS-1], // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
output logic [HC_BITS-1:0]          CMD_vid_h_offset       [0:LAYERS-1], // The beginning display X coordinate for the video.
output logic [HC_BITS-1:0]          CMD_vid_h_width        [0:LAYERS-1], // The display width of the video.      0 = Disable video layer.
output logic [3:0]                  CMD_vid_pixel_width    [0:LAYERS-1], // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
output logic [3:0]                  CMD_vid_width_begin    [0:LAYERS-1], // Begin the display left shifted part-way into a zoomed pixel.
                                                                         // Used for smooth sub-pixel scrolling a window display past the left margin of the display.
output logic [6:0]                  CMD_vid_x_buf_begin    [0:LAYERS-1], // Within the line buffer, this defines the first pixel to be shown.
                                                                         // The first 4 bits define the tile's X coordinate.
output logic                        CMD_vid_tile_enable    [0:LAYERS-1], // Tile mode enable.
output logic [15:0]                 CMD_vid_tile_base      [0:LAYERS-1], // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
output logic [2:0]                  CMD_vid_tile_bpp       [0:LAYERS-1], // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
output logic [1:0]                  CMD_vid_tile_width     [0:LAYERS-1], // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
output logic [1:0]                  CMD_vid_tile_height    [0:LAYERS-1], // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
output logic [4:0]                  CMD_vid_tile_x_begin   [0:LAYERS-1], // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
output logic [4:0]                  CMD_vid_tile_y_begin   [0:LAYERS-1]  // When displaying a line with tile enabled, this coordinate defines the displayed tile's Y coordinate.


);

generate
if (PORT_VECTOR_SIZE < (LBUF_ADW+3) )  initial begin
$warning("*********************************************");
$warning("*** BrianHG_GFX_Window_DDR3_Reader ERROR. ***");
$warning("***********************************************************************************");
$warning("*** Your current parameter .PORT_VECTOR_SIZE(%d) is too small.  It needs       ***",6'(PORT_VECTOR_SIZE));
$warning("*** to be at least (%d) to support the set line buffer word size of            ***",6'(LBUF_ADW+3));
$warning("*** .LBUF_WORDS(%d) plus an additional 3 bits for the SDI_LAYERS addressing. ***",13'(LBUF_WORDS));
$warning("*** Don't forget that the BrianHG_DDR3_Controller's .PORT_VECTOR_SIZE also      ***");
$warning("*** needs to be set to the same size.                                           ***");
$warning("***********************************************************************************");
$error;
$stop;
end

if ( (SDI_LAYERS!=1) && (SDI_LAYERS!=2) && (SDI_LAYERS!=4) && (SDI_LAYERS!=8) )  initial begin
$warning("*********************************************");
$warning("*** BrianHG_GFX_Window_DDR3_Reader ERROR. ***");
$warning("***********************************************************");
$warning("*** Your current parameter .SDI_LAYERS(%d) is invalid. ***",6'(SDI_LAYERS));
$warning("*** It can only be 1, 2, 4, or 8.                       ***");
$warning("***********************************************************");
$error;
$stop;
end

if ( (PDI_LAYERS<1) || (PDI_LAYERS>8) )  initial begin
$warning("*********************************************");
$warning("*** BrianHG_GFX_Window_DDR3_Reader ERROR. ***");
$warning("***********************************************************");
$warning("*** Your current parameter .PDI_LAYERS(%d) is invalid. ***",6'(PDI_LAYERS));
$warning("*** It can only be anywhere from 1 through 8.           ***");
$warning("***********************************************************");
$error;
$stop;
end
endgenerate


// Default disable the unused DDR3 controls.
assign CMD_write_ena        = 0 ;
assign CMD_wdata            = 0 ;
assign CMD_wmask            = 0 ;
assign CMD_priority_boost   = 0 ;

// **********************************************************************************
// Localparam constants.
// **********************************************************************************

localparam bit [2:0]  bpp_conv   [0:7]  = '{0,1,2,3,4,5,4,5} ; // translate input to modes 
localparam bit [6:0]  bpp_trim   [0:7]  = '{ 7'b1111111   , 7'b0111111   , 7'b0011111   , 7'b0001111   , 7'b0000111   , 7'b0000011   , 7'b0000111   , 7'b0000011   } ;
localparam bit [4:0]  tile_irst  [0:3]  = '{3,7,15,31} ;       // define the tile width begin points
                                        //  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16x
localparam bit [2:0]  scale_sdiv [0:15] = '{0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 4 } ; // Used to approximate the read length on each line when an X scale is enabled.

localparam            HC_RDB            = $clog2(4096*32/PORT_CACHE_BITS) ; // Determine the upper address bit for a DDR3 burst read counter based on a maximum display of 4096 pixels at 32 bit.


logic [VC_BITS-1:0]   rast_vpos = 0 ;                             // Signifies the vertical display raster position
logic [6:0]           SEQ=0,SEQ_DL1=0,SEQ_DL2=0,SEQ_DL3=0,SEQ_DL4=0;
logic [5:0]           SEQb=0 ;                    // Counter for the sequential processor.
logic                 SEQ_runa = 0    ;          // 1 clock delayed h-rst.
logic                 SEQ_runb = 0    ;          // 1 clock delayed h-rst.

logic                            win_ena          [0:LAYERS-1] = '{default:'0} ; // The enable the window's display line.
logic        [3:0]               win_v_scale      [0:LAYERS-1] = '{default:'0} ; // The vertical pixel scale position.
logic        [HC_BITS-1:0]       win_x_pos        [0:LAYERS-1] = '{default:'0} ; // The horizontal X bitmap coordinate of the window's.
logic        [HC_RDB+1:0]        win_read_len     [0:LAYERS-1] = '{default:'0} ; // The number of DDR3 read requests required for one row in a window.
logic        [HC_RDB+1:0]        win_read_remain  [0:LAYERS-1] = '{default:'0} ; // The number of DDR3 read requests required for one row in a window.
logic        [HC_RDB+1:0]        win_read_remain_sum           = 0             ; // The number of DDR3 read requests required for one row in a window.
logic        [VC_BITS-1:0]       win_y_pos        [0:LAYERS-1] = '{default:'0} ; // The vertical Y bitmap coordinate of the window's.
logic        [VC_BITS-1:0]       win_height_cnt   [0:LAYERS-1] = '{default:'0} ; // The vertical Y bitmap coordinate of the window's.
logic        [4:0]               win_t_y_pos      [0:LAYERS-1] = '{default:'0} ; // The vertical Y pixel inside the tile/font in tile mode.
logic        [31:0]              win_read_addr    [0:LAYERS-1] = '{default:'0} ; // The window's DDR3 read address pointer.
logic        [LBUF_ADW_WIN-1:0]  lb_write_pos_WIN [0:LAYERS-1] = '{default:'0} ; // The destination line buffer's write position for each SDI window layer.
logic        [LBUF_ADW_WIN+1:0]  lb_free_space    [0:LAYERS-1] = '{default:'0} ; // The line buffer's current display's read position.
logic        [6:0]               lb_x_offset      [0:LAYERS-1] = '{default:'0} ; // The line buffer's first pixel to be shown.
logic        [LAYERS-1:0]        lb_read                       = 0             ; // A status flag for when a DDR3 read req has taken place.
logic        [LAYERS-1:0]        lb_ready                                      ; // A status flag for the available space in the read FIFO.
logic        [LAYERS-1:0]        read_required                                 ; // A status flag for when a DDR3 read req has taken place.
logic        [9:0]               burst_limiter                 = 0             ; // A countdown limit for a read sequential burst size.
logic                            first_round                   = 0             ; // Select between the high and low burst limit in multi-window systems.
logic                            burst_commit                  = 0             ; // Once a burst has begun, commit until the MAXBURST.

logic                 win_y_begin    [0:LAYERS-1] = '{default:'0} ; // The enable the window's display line.
logic                 win_y_end      [0:LAYERS-1] = '{default:'0} ; // The enable the window's display line.

localparam MB_MX = VC_BITS + HC_BITS + 5 ; // Unified 32bit multiplier adder unit's inputs.
logic [HC_BITS-1+5:0] ma=0;                // Unified 32bit multiplier adder unit's inputs.
logic   [VC_BITS-1:0] mb=0;                // Unified 32bit multiplier adder unit's inputs.
logic     [MB_MX-1:0] mx=0;                // Unified 32bit multiplier adder unit's inputs.
logic          [31:0] aa=0;                // Unified 32bit multiplier adder unit's inputs.
logic          [34:0] my=0;                // Unified 32bit multiplier adder unit's result.


logic          [20:0] win_read_adder    = 0 ;
logic          [31:0] win_read_addr_lat = 0 ;
logic          [6:0]  lb_x_offset_lat   = 0 ;

// *** Assign outputs
always_comb begin
  for (int i = 0 ; i < LAYERS ; i++ ) begin

    win_x_pos   [i] = (CMD_win_tile_enable[i] && ENABLE_TILE_MODE) ? ((CMD_win_bitmap_x_pos[i] >> 2) >> CMD_vid_tile_width[i]) : CMD_win_bitmap_x_pos[i] ; // Set the first read pixel byte.

    // Establish an absolute limit on the DDR3 read requests per line depending on the window width, scale setting and tile mode.
    // This prevents excessive reading when not needed.
    win_read_len[i] = (CMD_win_tile_enable[i] && ENABLE_TILE_MODE) ? (HC_RDB+1)'(CMD_win_x_size[i] >> (3'd5+LBUF_DADW-bpp_conv[CMD_win_bpp[i]]+scale_sdiv[CMD_win_scale_width[i]]+CMD_vid_tile_width[i]+2'd2)) :
                                                (HC_RDB+1)'(CMD_win_x_size[i] >> (3'd5+LBUF_DADW-bpp_conv[CMD_win_bpp[i]]+scale_sdiv[CMD_win_scale_width[i]]                           )) ;


    // Assign raster control outputs.
    CMD_vid_ena            [i] = win_ena                [i] ;
    CMD_vid_bpp            [i] = CMD_win_bpp            [i] ;
    CMD_vid_h_offset       [i] = CMD_win_x_offset       [i] ;
    CMD_vid_h_width        [i] = CMD_win_x_size         [i] ;
    CMD_vid_pixel_width    [i] = CMD_win_scale_width    [i] ;
    CMD_vid_width_begin    [i] = CMD_win_scale_h_begin  [i] ;
    CMD_vid_x_buf_begin    [i] = lb_x_offset            [i] ;

    // Assign tile control outputs.
    CMD_vid_tile_enable    [i] = CMD_win_tile_enable    [i] && ENABLE_TILE_MODE ;
    CMD_vid_tile_base      [i] = CMD_win_tile_base      [i] ;
    CMD_vid_tile_bpp       [i] = CMD_win_tile_bpp       [i] ;
    CMD_vid_tile_width     [i] = CMD_win_tile_width     [i] ;
    CMD_vid_tile_height    [i] = CMD_win_tile_height    [i] ;
    CMD_vid_tile_x_begin   [i] = (5)'(CMD_win_bitmap_x_pos[i] & tile_irst[CMD_vid_tile_width[i]])   ; // Set the horizontal indent into the first tile.
    CMD_vid_tile_y_begin   [i] = win_t_y_pos            [i] ;                                                         // Set the displayed vertical tile row.

    // Assign local status flags.
    win_y_begin[i]      = ( (CMD_win_y_offset[i] == rast_vpos)  && (CMD_win_y_size[i] != 0) && (CMD_win_x_size[i] != 0) ) ; // Define the top margin window beginning.
    win_y_end  [i]      =   (win_height_cnt  [i] == 1    )                                                                ; // Define the bottom margin window ending.

    // Line buffer stats
    lb_ready     [i]    = (!lb_free_space[i][LBUF_ADW_WIN+1]) || burst_commit          ; // Use the negative bit to determine if there is any available line buffer space left.
    read_required[i]    = win_ena[i] && (!win_read_remain[i][HC_RDB+1]) && lb_ready[i] ;


  end // for i
end // _comb

always_ff @(posedge CMD_CLK) begin

// **********************************************************************************
// *** Layer independent Functions.
// **********************************************************************************
    if (CMD_RST)  rast_vpos <= 0 ;
    else begin        
             if (!lb_stat_vena) rast_vpos         <= 0 ;
        else if ( lb_stat_hrst) rast_vpos         <= rast_vpos + 1'd1   ;
    end // !CMD_RST, Layer independent Functions.

// **********************************************************************************************************************************************
// *** Parallel Processing Functions for each layer.  IE: Keep track of every layer's vertical scale/window/tile coordinates during H-Sync.
// **********************************************************************************************************************************************
for (int i = 0 ; i < LAYERS ; i++ ) begin

    if (CMD_RST || !CMD_DDR3_ready || !CMD_win_enable[i]) begin

        win_ena        [i]  <= 0 ;
        win_v_scale    [i]  <= 0 ;
        win_y_pos      [i]  <= 0 ;
        win_t_y_pos    [i]  <= 0 ;
        win_read_addr  [i]  <= 0 ;
        lb_free_space  [i]  <=  {(LBUF_ADW_WIN+2){1'b1}} ; // Assign a -1, meaning buffer is not ready.
    
    end else begin


    if (lb_stat_hrst) begin

        if (!lb_stat_vena) begin

                lb_free_space   [i] <= {(LBUF_ADW_WIN+2){1'b1}}                                            ; // Assign a -1, meaning buffer is not ready.
                win_ena         [i] <= 0                                                                   ; // Disable window
                win_y_pos       [i] <= (CMD_win_tile_enable [i] && ENABLE_TILE_MODE) ? ((CMD_win_bitmap_y_pos[i] >> 2) >> CMD_win_tile_height[i]) : CMD_win_bitmap_y_pos[i] ; // Set raster position within window.
                win_height_cnt  [i] <= CMD_win_y_size       [i]                                            ; // Set the window's vertical output raster size counter.
                win_v_scale     [i] <= CMD_win_scale_height [i] - CMD_win_scale_v_begin[i]                 ; // Calculate the first top row when zoomed.
                win_t_y_pos     [i] <= (5)'(CMD_win_bitmap_y_pos[i] & tile_irst[CMD_win_tile_height[i]])   ; // Calculate the first top row inside a tile.
                //lb_x_offset     [i] <= (7)'(win_x_pos[i] & bpp_trim[CMD_win_bpp[i]]);

            end else begin

                // At the horizontal sync, reset the available free space for the read line buffer FIFO position
                // to a size just smaller than the MAX_BURST meaning that whenever the free space isn't negative,
                // even if it is at 0, we know that there is enough free headroom to perform a read burst of
                // MAX_BURST words without the chance of over flowing the true line buffer's available space.
                lb_free_space   [i] <= (LBUF_ADW_WIN+1)'((LBUF_WORDS/SDI_LAYERS) - MAX_BURST) ; 

                     if ( win_y_begin[i] ) win_ena[i] <= 1 ; // Disable window
                else if ( win_y_end  [i] ) win_ena[i] <= 0 ; // Enable window

                if (win_ena[i]) begin // When displaying a video line.

                                                    win_height_cnt [i] <= win_height_cnt [i] - 1'b1 ;                      // Count down the window height until the bottom row.
                            if (win_v_scale[i] !=0) win_v_scale    [i] <= win_v_scale    [i] - 1'b1 ;

                            else begin
                                    if ((win_t_y_pos[i] != tile_irst[CMD_win_tile_height[i]]) && CMD_win_tile_enable[i] && ENABLE_TILE_MODE) win_t_y_pos[i] <= win_t_y_pos[i] + 1'b1 ;
                                        else begin
                                                    win_t_y_pos    [i] <= 0 ;
                                                    win_y_pos      [i] <= win_y_pos           [i] + 1'b1 ; // Increment the raster Y position.
                                        end
                                                    win_v_scale    [i] <= CMD_win_scale_height[i] ;
                                end

                            end

            end

    end else begin // !lb_stat_hrst  --- We are now running during the middle of the video line buffer output

                     if ( lb_stat_qinc[i] && !lb_read[i]) lb_free_space[i] <= lb_free_space[i] + 3'd4 ; // increment the read buffer position status when we receive a pulse from the BrianHG_GFX_Video_Line_Buffer.sv module.
                else if ( lb_stat_qinc[i] &&  lb_read[i]) lb_free_space[i] <= lb_free_space[i] + 3'd3 ; // increment the read buffer position status less when we receive a pulse from the BrianHG_GFX_Video_Line_Buffer.sv module + a DDR3 read req is sent.
                else if (!lb_stat_qinc[i] &&  lb_read[i]) lb_free_space[i] <= lb_free_space[i] - 3'd1 ; // decrement the read buffer position a DDR3 read req is sent but there is no increment pulse coming from the BrianHG_GFX_Video_Line_Buffer.sv module.

    end // !lb_stat_hrst

  end // !CMD_RST||!CMD_DDR3_ready, Parallel Processing Functions for each layer.
end // for i, Parallel Processing Functions for each layer.

// ***************************************************************************************************************************************************************
// *** Sequential Processing Functions for each layer.  IE: After H-Sync, sequentially go through all enabled windows and when needed, send DDR3 read requests.
// *** Used to both coalesce the multiply required for each window's DDR3 read address Y position into a single HW DSP multiply & channel each active layer's
// *** read req into a single DDR3 read channel.
// *** Coalesce each line buffer free space availability into parameter's MAX_BURST chunks to make the best of the DDR3 access time slots.
// ***************************************************************************************************************************************************************

// *******************************************************************************************
    mx <=    (ma * mb) ; //  Unified multiply command to save on DSP block usage.
    my <= 35'((aa<<3) + mx) ;
// *******************************************************************************************

  if (CMD_RST || !CMD_DDR3_ready) begin

        CMD_ena     <= 0  ; // Disable any DDR3 command.
        SEQ         <= 96 ; // Begin the end/stop point of sequential window channel processing.
        SEQ_DL1     <= 0  ;
        SEQ_DL2     <= 0  ;
        SEQ_DL3     <= 0  ;
        SEQ_DL4     <= 0  ;
        SEQ_runa    <= 0  ;
        SEQ_runb    <= 0  ;
        SEQb        <= 0  ;

        //lb_read     <= 0 ;
        //first_round <= (LAYERS!=1) ; // Use the smaller maximum burst when there are more than 1 layer.
        
        //for (int i = 0 ; i < LAYERS ; i++ ) win_read_remain[i]  <= {(HC_RDB+2){1'b1}} ; // Assign a -1, meaning nothing to read.
        //for (int i = 0 ; i < LAYERS ; i++ ) lb_write_pos_WIN[i] <= 0 ;

  end else begin


case (SEQ)

    default : begin
                    if (SEQ==(LAYERS-1)) SEQ <= 7'd64 ;
                    else                 SEQ <= SEQ + 1'b1 ;
              end

    67 : begin // Delayer after position 64 to give time for the multiplier of SEQ_runa to finish it's pipeline delay.
              SEQ_runa <= 0          ;
              SEQ      <= 7'd96      ;
              SEQ_runb <= 1          ;
         end

    96 : begin
            if (lb_stat_hrst)                   SEQ_runb <= 0 ;
            if (lb_stat_hrst && lb_stat_vena) begin
                                                SEQ      <= 0 ;
                                                SEQ_runa <= 1 ;
                                                end
         end

endcase

        SEQ_DL1  <= SEQ ;
        SEQ_DL2  <= SEQ_DL1 ;
        SEQ_DL3  <= SEQ_DL2 ;
        SEQ_DL4  <= SEQ_DL3 ;

            if (SEQ_runa) begin

                ma                          <= ( (CMD_win_bitmap_width[6'(SEQ)]) << (bpp_conv[CMD_win_bpp[6'(SEQ)]]) ) ;
                mb                          <= win_y_pos[6'(SEQ)] ;
                aa                          <= CMD_win_base_addr[6'(SEQ_DL1)] ; // **** Selection pointer must be delayed due to the 'addition' taken place on the second clock.

                win_read_remain_sum         <= win_read_len[6'(SEQ)] + 1'b1;
                win_read_remain[6'(SEQ_DL1)]<= win_read_remain_sum         ;

                lb_write_pos_WIN[6'(SEQ)]   <= 0 ;

                win_read_adder              <= ((win_x_pos[6'(SEQ_DL2)] << bpp_conv[CMD_win_bpp[6'(SEQ_DL2)]])>>3) ;

                win_read_addr_lat           <= (my[34:3] + win_read_adder) & (32'hFFFFFFFF ^ {CACHE_ADW{1'b1}}) ;
                lb_x_offset_lat             <= (7)'( (win_x_pos[6'(SEQ_DL3)] + (my[3+:CACHE_ADW]<<3>>bpp_conv[CMD_win_bpp[6'(SEQ_DL3)]]) ) & bpp_trim[CMD_win_bpp[6'(SEQ_DL3)]] );

                win_read_addr[6'(SEQ_DL4)]  <=  win_read_addr_lat ;
                lb_x_offset  [6'(SEQ_DL4)]  <=  lb_x_offset_lat   ;

            end


    if (!SEQ_runb) begin // Run layer sequential read operations.
                                                     CMD_ena       <= 0 ; // !SEQa_done
                                                     lb_read       <= 0 ;
                                                     SEQb          <= 0 ;
                                                     burst_commit  <= 0 ;
                                                     first_round   <= (LAYERS!=1) ; // Use the smaller maximum burst when there are more than 1 layer.
                                                     burst_limiter <= (LAYERS!=1) ? (10)'(MAX_BURST_1st-1'b1) : (10)'(MAX_BURST-1'b1) ; // 
 
        end else begin 
 
// ********************************************************************************************************************************************************************
// *** When a read req is requires, or, we are locked into a committed burst so long as the required remaining pixel-words for the current line has not been reached.
// ********************************************************************************************************************************************************************
            if ((read_required[SEQb] && !burst_limiter[9]) ) begin //|| (burst_commit && !burst_limiter[9] && (!win_read_remain[SEQb][HC_RDB+1])) ) begin

                     if (!CMD_busy) begin                                                           // When DDR3 is ready
                     CMD_ena                <= 1 ;                                                  // Enable a read req
                     CMD_addr               <= (PORT_ADDR_SIZE)'(win_read_addr[SEQb]) ;             // Send read address.
                     CMD_read_vector_tx     <= (PORT_VECTOR_SIZE)'({SEQb,lb_write_pos_WIN[SEQb]}) ; // Send the line buffer's destination vector.

                     win_read_addr   [SEQb] <= win_read_addr   [SEQb] + (1'b1 << CACHE_ADW);        // Increment the window's read pointer for the next read req
                     lb_write_pos_WIN[SEQb] <= lb_write_pos_WIN[SEQb] + 1'b1 ;                      // Increment the line buffer's destination pointer.
                     lb_read         [SEQb] <= 1 ;                                                  // Signal the local 'lb_free_space' that a read req has taken place.
                     win_read_remain [SEQb] <= win_read_remain [SEQb] - 1'b1 ;                      // Decrement the required remaining pixel-words for the current line.
                     burst_limiter          <= burst_limiter - 1'b1 ;                               // Decrement the burst length limiter.
                     burst_commit           <= !burst_limiter[9]    ;                               // Once the first read begins, lock in the sequential burst until the limit has been reached.
                     end else begin  // CMD_BUSY
                     CMD_ena  <= 0 ;                                                                // DDR3 is not ready, halt the read req.
                     lb_read  <= 0 ;                                                                // Make sure that the 'lb_free_space' is not signaled that a read req has been accepted.
                     end

                end else begin  // No read required on window [SEQb].
                CMD_ena       <= 0 ;
                lb_read       <= 0 ;
                burst_commit  <= 0 ;
    
                        if (SEQb!=(LAYERS-1)) begin // Increment to the next window [SEQb].
                                                SEQb          <= SEQb + 1'b1 ; // Circular count
                                                burst_limiter <= first_round ? (10)'(MAX_BURST_1st-1'b1) : (10)'(MAX_BURST-1'b1) ;
                        end else begin
                                                SEQb          <= 0                     ; // Circular count
                                                first_round   <= 0                     ; // Switch to the normal maximum burst limit.
                                                burst_limiter <= (10)'(MAX_BURST-1'b1) ;
                        end
    
            end
            
    end 


  end // !CMD_RST||!CMD_DDR3_ready, Sequential Processing Functions for each layer.
end //@CMD_CLK

endmodule
