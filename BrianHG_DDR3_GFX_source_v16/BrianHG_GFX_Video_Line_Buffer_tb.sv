// *****************************************************************
// Generate a BrianHG_GFX_Video_Line_Buffer test-bench.
// v1.6, December 10, 2021
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.


module BrianHG_GFX_Video_Line_Buffer_tb #(
parameter           HC_BITS            = 16,             // Width of horizontal counter.
parameter           VC_BITS            = 16,             // Width of vertical counter.
parameter bit [2:0] SDI_LAYERS         = 1,              // Number of sequential display layers.
parameter bit       ENABLE_TILE_MODE   = 1,              // Enable the tile mode.
parameter bit       SKIP_TILE_DELAY    = 0,              // Skip horizontal compensation delay due to disabled tile mode features.
parameter bit       ENABLE_PALETTE     = 1,              // Enable output palette.
parameter bit       SKIP_PALETTE_DELAY = 0,              // Skip horizontal compensation delay due to disabled palette.
parameter string    ENDIAN             = "Little"        // Enter "Little" or "Big".  Used for selecting the Endian in tile mode when addressing 16k tiles.
)(
output logic                        CLK_IN             ,
output logic                        reset              ,
output logic [2:0]                  CLK_DIVIDE_IN      ,         // Set a pixel clock divider, use 0 through 7 to divide the CLK_IN 1 through 8.
output logic [HC_BITS-1:0]          VID_h_total        ,         // Total pixel clocks per line of video
output logic [HC_BITS-1:0]          VID_h_res          ,         // Total active display pixels per line of video
output logic [HC_BITS-1:0]          VID_hs_front_porch ,         // Front porch size before horizontal sync.
output logic [HC_BITS-1:0]          VID_hs_size        ,         // Width of horizontal sync.
output logic                        VID_hs_polarity    ,         // Use 0 for positive H-Sync, use 1 for negative sync.
output logic [VC_BITS-1:0]          VID_v_total        ,         // Total lines of video per frame
output logic [VC_BITS-1:0]          VID_v_res          ,         // Total active display lines of video per frame
output logic [VC_BITS-1:0]          VID_vs_front_porch ,         // Front porch size before vertical sync.
output logic [VC_BITS-1:0]          VID_vs_size        ,         // Width of vertical sync in lines of video.
output logic                        VID_vs_polarity    ,         // Use 0 for positive V-Sync, use 1 for negative sync.

output logic                        H_ena              ,         // Horizontal video enable.  High during the horizontal active pixel time.
output logic                        V_ena              ,         // Vertical video enable.    High during the vertical active pixel time.  Ready right at the
                                                                 // falling edge of H_ena to give notice to the display buffer to be filled in time for the new
                                                                 // upcoming active video line.
output logic                        Video_ena          ,         // High during active video pixels, IE: (H_ena && V_ena).  Required for many video encoders.

output logic                        HS_out             ,         // Horizontal sync output.
output logic                        VS_out             ,         // Vertical sync output.

output logic [2:0]                  CLK_PHASE_OUT      ,         // Pixel clock divider position.
output logic [HC_BITS-1:0]          h_count_out        ,         // output counter parallel with the H/V_ena.
output logic [VC_BITS-1:0]          v_count_out                  // Only use these 2 if you want to waste logic cells or view in a simulation.

);

localparam      CLK_MHZ_IN  = 100 ;
localparam      period      = 500000/CLK_MHZ_IN ;
localparam      STOP_uS     = 1000000 ;
localparam      endtime     = STOP_uS * 20;


logic        H_ena_r,V_ena_r,HS_r,VS_r;
logic [2:0]  CLK_PHASE_r;
logic [15:0] h_count_r,v_count_r;

logic         CMD_lbuf_wena   = 0 ;
logic [7:0]   CMD_lbuf_waddr  = 0 ;
logic [127:0] CMD_lbuf_wdata  = 0 ;
logic         TAP_wena        = 0 ;
logic [15:0]  TAP_waddr       = 0 ;
logic [127:0] TAP_wdata       = 0 ;
logic [15:0]  TAP_wmask       = 0 ;

logic         CMD_vid_ena             [0:SDI_LAYERS-1] ; // Enable video line. 
logic [2:0]   CMD_vid_bpp             [0:SDI_LAYERS-1] ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6. *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
logic [15:0]  CMD_vid_h_offset        [0:SDI_LAYERS-1] ; // The beginning display X coordinate for the video.
logic [15:0]  CMD_vid_h_width         [0:SDI_LAYERS-1] ; // The display width of the video.      0 = Disable video layer.
logic [3:0]   CMD_vid_pixel_width     [0:SDI_LAYERS-1] ; // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
logic [3:0]   CMD_vid_width_begin     [0:SDI_LAYERS-1] ; // Begin the display left shifted part-way into a zoomed pixel.
logic [6:0]   CMD_vid_x_buf_begin     [0:SDI_LAYERS-1] ; // Within the line buffer, this defines the first pixel to be shown.

logic         CMD_vid_tile_enable     [0:SDI_LAYERS-1] ; // Enable Tile Mode
logic [15:0]  CMD_vid_tile_base       [0:SDI_LAYERS-1] ; // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
                                                         // *** This is the address inside the line buffer tile/font blockram which always begins at 0, NOT the DDR3 TAP_xxx port write address.
logic [2:0]   CMD_vid_tile_bpp        [0:SDI_LAYERS-1] ; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6. *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
logic [1:0]   CMD_vid_tile_width      [0:SDI_LAYERS-1] ; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
logic [1:0]   CMD_vid_tile_height     [0:SDI_LAYERS-1] ; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
logic [4:0]   CMD_vid_tile_x_begin    [0:SDI_LAYERS-1] ; // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
logic [4:0]   CMD_vid_tile_y_begin    [0:SDI_LAYERS-1] ; // When displaying a line with tile enabled, this coordinate defines the Y location

logic         lb_stat_hrst                          ;
logic         lb_stat_vena                          ;
logic         lb_stat_qinc         [0:SDI_LAYERS-1] ;  // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.

logic [31:0]  RGBA  ;
logic         WLENA ;
logic         VENA  ;

BrianHG_GFX_Sync_Gen #(

) DUT_SG (

.CLK_IN             ( CLK_IN             ),
.reset              ( reset              ),
.CLK_DIVIDE_IN      ( CLK_DIVIDE_IN      ),
.VID_h_total        ( VID_h_total        ),
.VID_h_res          ( VID_h_res          ),
.VID_hs_front_porch ( VID_hs_front_porch ),
.VID_hs_size        ( VID_hs_size        ),
.VID_hs_polarity    ( VID_hs_polarity    ),
.VID_v_total        ( VID_v_total        ),
.VID_v_res          ( VID_v_res          ),
.VID_vs_front_porch ( VID_vs_front_porch ),
.VID_vs_size        ( VID_vs_size        ),
.VID_vs_polarity    ( VID_vs_polarity    ),
.H_ena              ( H_ena_r            ),
.V_ena              ( V_ena_r            ),
.Video_ena          ( Video_ena          ),
.HS_out             ( HS_r               ),
.VS_out             ( VS_r               ),
.CLK_PHASE_OUT      ( CLK_PHASE_r        ),
.h_count_out        ( h_count_r          ),
.v_count_out        ( v_count_r          ) );


BrianHG_GFX_Video_Line_Buffer #(

.ENDIAN              (ENDIAN),            // Enter "Little" or "Big".  Used for selecting the Endian in tile mode when addressing 16k tiles.
.PORT_ADDR_SIZE      (16),                // Number of address bits used for font/tile memory and palette access.
.PORT_CACHE_BITS     (128),               // The bit width of the CMD_line_buf_wdata.
.LB_MODULE_ID        (0),                 // When using multiple line buffer modules in parallel, up to 8 max, assign this module's ID from 0 through 7.
.SDI_LAYERS          (SDI_LAYERS),        // Serial Display Layers.  The number of layers multiplexed into this display line buffer.
                                          // Must be a factor of 2, IE: only use 1,2,4 or 8 as 'CLK_PHASE_IN' is only 3 bits.
                                          // Note that when you use multiple line buffer modules in parallel), each line buffer module
                                          // should use the same layer count to be compatible with the BrianHG_GFX_Window_DDR3_Reader.sv module.
 
.LBUF_BITS           (128),               // The bit width of the CMD_line_buf_wdata
.LBUF_WORDS          (256),               // The total number of 'CMD_line_buf_wdata' words of memory.
                                          // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                          // Only use factors of 2), IE: 256/512/1024...
 
.ENABLE_TILE_MODE    (ENABLE_TILE_MODE),  // Enable font/tile memory mode.  This is for all SDI_LAYERS.
.SKIP_TILE_DELAY     (SKIP_TILE_DELAY),   // When set to 1 and font/tile is disabled, the pipeline delay of the 'tile' engine will be skipped saving logic cells
                                          // However, if you are using multiple Video_Line_Buffer modules in parallel, some with and others without 'tiles'
                                          // enabled, the video outputs of each Video_Line_Buffer module will no longer be pixel accurate super-imposed on top of each other.

.TILE_BASE_ADDR      (32'h00002000),      // Tile memory base address.
.TILE_BITS           (128),               // The bit width of the tile memory.  128bit X 256words  (256 character 8x16 font), 1 bit color. IE: 4kb.
.TILE_WORDS          (1024),              // The total number of tile memory words at 'TILE_BITS' width.
                                          // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                          // Use a minimum of 256), maximum can go as far as the available FPGA memory.
                                          // Note that screen memory is 32 bits per tile.
                                          // Real-time software tile controls:
                                          // Each tile can be 4/8/16/32 pixels wide and tall.
                                          // Tile depth can be set to 1/2/4/8/16/32 bits per pixel.
                                          // Each 32bit screen character mem =
                                          // {8bit offset color), 8bit multiply color), 1bit v-flip), 1bit h-mirror), 14bit tile address}
                                          //  ---- For 2 thru 8 bit tiles/fonts ---- (multiply), then add rounding to 8 bits)
                                          //  Special for 1 bit tiles), the first byte is background and the next byte is foreground color.
                                          //  16/32 bit tile modes are true-color.
 
//.TILE_MIF_FILE ("VGA_FONT_8x16_mono32.mif"), *******DAMN ALTERA STRING BUG!!!!// A PC-style 4 kilobyte default 8x16), 1 bit color font organized as 32bit words.
 
 
                                          // Palette is bypassed when operating in true-color modes.
.ENABLE_PALETTE      (ENABLE_PALETTE),    // Enable a palette for 8/4/2/1 bit depth.  Heavily recommended when using 'TILE_MODE'.
.SKIP_PALETTE_DELAY  (SKIP_PALETTE_DELAY),// When set to 1 and palette is disabled, the resulting delay timing will be the same as the
                                          // 'SKIP_TILE_DELAY' parameter except for when with multiple ideo_Line_Buffer modules,
                                          // some have the palette feature enabled and others have it disabled.

.PAL_BITS            (128),               // Palette width.
.PAL_BASE_ADDR       (32'h00001000),      // Palette base address.
.PAL_WORDS           (256),               // The total number of palette memory words at 'PAL_BITS' width.
                                          // Having extra palette width allows for multiple palettes), each dedicated
                                          // to their own SDI_LAYER.  Otherwise), all the SDI_LAYERS will share
                                          // the same palette.
 
.PAL_ADR_SHIFT       (0)                  // Use 0 for off.  If PAL_BITS is made 32 and PORT_CACHE_BITS is truly 128bits), then use 2.
                                          // *** Optionally make each 32 bit palette entry skip a x^2 number of bytes
                                          // so that we can use a minimal single M9K block for a 32bit palette.
                                          // Use 0 is you just want to write 32 bit data to a direct address from 0 to 255.
                                          // *** This is a saving measure for those who want to use a single M9K block of ram
                                          // for the palette), yet still interface with the BrianHG_DDR3 'TAP_xxx' port which
                                          // may be 128 or 256 bits wide.  The goal is to make the minimal single 256x32 M9K blockram
                                          // and spread each write address to every 4th or 8th chunk of 128/256 bit 'TAP_xxx' address space.
 
//.PAL_MIF_FILE ("VGA_PALETTE_RGBA32.mif")  *******DAMN ALTERA STRING BUG!!!! // An example default palette), stored as 32 bits Alpha-Blend),Blue),Green),Red.

) DUT_LB (

// ***********************************************************************************
// ***** System memory clock interface, line buffer tile/palette write memory inputs.
// ***********************************************************************************
.CMD_RST              ( reset                    ), // CMD section reset.
.CMD_CLK              ( CLK_IN                   ), // System CMD RAM clock.
.CMD_LBID             ( 3'd0                     ), // Allow writing to this one line-buffer module based on it's selected matching parameter 'LB_MODULE_ID'.
.CMD_lbuf_wena        ( CMD_lbuf_wena            ), // Write enable for the line buffer.
.CMD_lbuf_waddr       ( CMD_lbuf_waddr           ), // Line buffer write address.
.CMD_lbuf_wdata       ( CMD_lbuf_wdata           ), // Line buffer write data.
.CMD_tile_wena        ( TAP_wena                 ), // Write enable for the tile memory buffer.
.CMD_tile_waddr       ( TAP_waddr                ), // Tile memory buffer write address.
.CMD_tile_wdata       ( TAP_wdata                ), // Tile memory buffer write data.
.CMD_tile_wmask       ( TAP_wmask                ), // Tile memory buffer write mask.
.CMD_pal_wena         ( TAP_wena                 ), // Write enable for the palette buffer.
.CMD_pal_waddr        ( TAP_waddr                ), // Palette buffer write address.
.CMD_pal_wdata        ( TAP_wdata                ), // Palette buffer write data.
.CMD_pal_wmask        ( TAP_wmask                ), // Palette buffer write mask.

// *******************************************************************************
// ***** Line drawing parameters received from BrianHG_GFX_Window_DDR3_Reader.sv
// ***** Use arrays for the quantity of SDI_LAYERS.
// *******************************************************************************
.CMD_vid_ena            ( CMD_vid_ena              ), // Enable video line. 
.CMD_vid_bpp            ( CMD_vid_bpp              ), // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
.CMD_vid_h_offset       ( CMD_vid_h_offset         ), // The beginning display X coordinate for the video.
.CMD_vid_h_width        ( CMD_vid_h_width          ), // The display width of the video.      0 = Disable video layer.
.CMD_vid_pixel_width    ( CMD_vid_pixel_width      ), // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
.CMD_vid_width_begin    ( CMD_vid_width_begin      ), // Begin the display left shifted part-way into a zoomed pixel.
                                                      // Used for smooth sub-pixel scrolling a window display past the left margin of the display.
.CMD_vid_x_buf_begin    ( CMD_vid_x_buf_begin      ), // Within the line buffer, this defines the first pixel to be shown.
                                                      // The first 4 bits define the tile's X coordinate.

.CMD_vid_tile_enable    ( CMD_vid_tile_enable      ), // Tile mode enable.
.CMD_vid_tile_base      ( CMD_vid_tile_base        ), // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
                                                      // *** This is the address inside the line buffer tile/font blockram which always begins at 0, NOT the DDR3 TAP_xxx port write address.
.CMD_vid_tile_bpp       ( CMD_vid_tile_bpp         ), // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
.CMD_vid_tile_width     ( CMD_vid_tile_width       ), // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
.CMD_vid_tile_height    ( CMD_vid_tile_height      ), // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
.CMD_vid_tile_x_begin   ( CMD_vid_tile_x_begin     ), // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
.CMD_vid_tile_y_begin   ( CMD_vid_tile_y_begin     ), // When displaying a line with tile enabled, this coordinate defines
                                                      // the displayed tile's Y coordinate.

// **********************************************************************
// **** Video clock domain and output timing from BrianHG_GFX_Sync_Gen.sv
// **********************************************************************
.VID_RST              ( reset                    ), // Video output pixel clock's reset.
.VID_CLK              ( CLK_IN                   ), // Video output pixel clock.

.VCLK_PHASE_IN        ( CLK_PHASE_r              ), // Used with sync gen is there are 
.hc_in                ( h_count_r                ), // horizontal pixel counter.
.H_ena_in             ( H_ena_r                  ), // Horizontal video enable.
.V_ena_in             ( V_ena_r                  ), // Vertical video enable.
.HS_in                ( HS_r                     ), // Horizontal sync output.
.VS_in                ( VS_r                     ), // Vertical sync output.

.VCLK_PHASE_OUT       ( CLK_PHASE_OUT            ), // Pixel clock divider position.
.hc_out               ( h_count_out              ), // horizontal pixel counter.
.H_ena_out            ( H_ena_out                ), // Horizontal video enable.
.V_ena_out            ( V_ena_out                ), // Vertical video enable.

.RGBA                 ( RGBA                     ), // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend
.WLENA                ( WLENA                    ), // Window Layer Active Out.

.VENA                 ( VENA                     ), // Active Video Out.
.HS_out               ( HS_out                   ), // Horizontal sync output.
.VS_out               ( VS_out                   ), // Vertical sync output.

// *************************************************************************************************************
// ***** Display Line buffer status to be sent back to BrianHG_GFX_Window_DDR3_Reader.sv, clocked on CMD_CLK.
// *************************************************************************************************************
.lb_stat_hrst         ( lb_stat_hrst             ), // Strobes for 1 clock when the end of the display line has been reached.
.lb_stat_vena         ( lb_stat_vena             ), // High during the active lines of the display frame.
.lb_stat_qinc         ( lb_stat_qinc             )  // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.
);



initial begin

// Setup sync generator to 480p.
CLK_DIVIDE_IN       = SDI_LAYERS-1 ;
VID_h_total         = 858          ; // = 48   ;
VID_h_res           = 720          ; // = 32   ;
VID_hs_front_porch  = 16           ; // = 2    ;
VID_hs_size         = 62           ; // = 6    ;
VID_hs_polarity     = 1            ; // = 1    ;
VID_v_total         = 525          ; // = 24   ;
VID_v_res           = 480          ; // = 12   ;
VID_vs_front_porch  = 6            ; // = 3    ;
VID_vs_size         = 6            ; // = 3    ;
VID_vs_polarity     = 1            ; // = 1    ;

// Do not write to the buffers.
CMD_lbuf_wena   = 0 ;
CMD_lbuf_waddr  = 0 ;
CMD_lbuf_wdata  = 0 ;
TAP_wena        = 0 ;
TAP_waddr       = 0 ;
TAP_wdata       = 0 ;
TAP_wmask       = 0 ;

// Initialize the metrics for drawing a video line.
for (int i=0 ; i<SDI_LAYERS ; i++) begin
CMD_vid_ena            [i] =  1        ; // Enable the video line.
CMD_vid_bpp            [i] =  3;//5        ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6. *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
CMD_vid_h_offset       [i] =  0        ; // The beginning display X coordinate for the video.
CMD_vid_h_width        [i] =  640      ; // The display width of the video.      0 = Disable video layer.
CMD_vid_pixel_width    [i] =  0        ; // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
CMD_vid_width_begin    [i] =  0        ; // Begin the display left shifted part-way into a zoomed pixel.
CMD_vid_x_buf_begin    [i] =  0        ; // Within the line buffer, this defines the first pixel to be shown.

CMD_vid_tile_enable    [i] =  1        ; // Tile mode enable.
CMD_vid_tile_base      [i] =  16'h0000 ; // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
CMD_vid_tile_bpp       [i] =  0        ; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6. *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
CMD_vid_tile_width     [i] =  1        ; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
CMD_vid_tile_height    [i] =  2        ; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
CMD_vid_tile_x_begin   [i] =  0        ; // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
CMD_vid_tile_y_begin   [i] =  0        ; // When displaying a line with tile enabled, this coordinate defines the Y location
end

reset  = 1'b1 ; // Reset input
CLK_IN = 1'b1 ;

#(period); // Align to clock input.

// *****************************************************************
// Write palette test data.
// *****************************************************************
#(period*2); TAP_waddr      = 16'h1000 ; TAP_wdata   = 128'h00000001000000090000000a0000000f ; TAP_wmask      = 16'hFFFF ; TAP_wena = 1 ; 
#(period*2); TAP_waddr      = 16'h0000 ; TAP_wdata   = 128'h00000000000000000000000000000000 ; TAP_wmask      = 0        ; TAP_wena = 0 ; 

// *****************************************************************
// Write Tile test data.
// *****************************************************************
#(period*2); TAP_waddr      = 16'h2000 ; TAP_wdata   = 128'haaf00103070f1f3f7fff55103070f1f3 ; TAP_wmask      = 16'hFFFF ; TAP_wena = 1 ; 
#(period*2); TAP_waddr      = 16'h2010 ; TAP_wdata   = 128'hf00f0000000000000000000000000000 ; TAP_wmask      = 16'hFFFF ; TAP_wena = 1 ; 
#(period*2); TAP_waddr      = 16'h0000 ; TAP_wdata   = 128'h00000000000000000000000000000000 ; TAP_wmask      = 0        ; TAP_wena = 0 ; 

// *****************************************************************
// Write line buffer test data.
// *****************************************************************
#(period*2); CMD_lbuf_waddr = 8'h00 ; CMD_lbuf_wdata = 128'h000102030405060708090a0b0c0d0e0f ; CMD_lbuf_wena  = 1 ; 
#(period*2); CMD_lbuf_waddr = 8'h01 ; CMD_lbuf_wdata = 128'h88889999aaaabbbbccccddddeeeeffff ; CMD_lbuf_wena  = 1 ; 
#(period*2); CMD_lbuf_waddr = 8'h00 ; CMD_lbuf_wdata = 128'h00000000000000000000000000000000 ; CMD_lbuf_wena  = 0 ; 

#(50000);
reset  = 1'b0 ; // Release reset after 50ns.
end

always #period         CLK_IN = !CLK_IN ;  // create source clock oscillator
always #(endtime)      $stop            ;  // Stop simulation from going on forever.
endmodule
