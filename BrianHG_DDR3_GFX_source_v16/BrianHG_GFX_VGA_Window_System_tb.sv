// *****************************************************************
// A BrianHG_GFX_VGA_Window_System_tb test-bench.
// v1.6, December 6, 2021
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.


module BrianHG_GFX_VGA_Window_System_tb #(

parameter string     ENDIAN                   = "Little",                 // Enter "Little" or "Big".  Used for selecting the Endian in tile mode when addressing 16k tiles.
parameter int        PORT_ADDR_SIZE           = 16 ,                      // Must match PORT_ADDR_SIZE.
parameter int        PORT_VECTOR_SIZE         = 12 ,                      // Must match PORT_VECTOR_SIZE and be at least large enough for the video line pointer + line buffer module ID.
parameter int        PORT_CACHE_BITS          = 128,                      // Must match PORT_R/W_DATA_WIDTH and be PORT_CACHE_BITS wide for optimum speed.
parameter bit [3:0]  PDI_LAYERS               = 2,                        // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
parameter bit [3:0]  SDI_LAYERS               = 2,                        // Use 1,2,4, or 8 sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system.

parameter bit        ENABLE_alpha_adj         = 1,                        // Use 0 to bypass the CMD_win_alpha_override logic.
parameter bit        ENABLE_SDI_layer_swap    = 1,                        // Use 0 to bypass the serial layer swapping logic
parameter bit        ENABLE_PDI_layer_swap    = 1,                        // Use 0 to bypass the parallel layer swapping logic

parameter int        LBUF_BITS                = PORT_CACHE_BITS,          // The bit width of the CMD_line_buf_wdata
parameter int        LBUF_WORDS               = 256,                      // The total number of 'CMD_line_buf_wdata' words of memory.
parameter bit [9:0]  MAX_BURST                = LBUF_WORDS/4/SDI_LAYERS,  // Generic maximum burst length.  IE: A burst will not be called unless this many free words exist inside the line buffer memory.
parameter bit [9:0]  MAX_BURST_1st            = (MAX_BURST/4),            // In a multi-window system, this defines the maximum read burst size per window after the H-reset period
parameter bit        ENABLE_TILE_MODE   [0:7] = '{1,0,0,0,0,0,0,0},       // Enable font/tile memory mode.  This is for all SDI_LAYERs within 1 array entry for each PDI_LAYERs.
parameter bit        SKIP_TILE_DELAY          = 0,                        // When set to 1 and font/tile is disabled, the pipeline delay of the 'tile' engine will be skipped saving logic cells
parameter bit [31:0] TILE_BASE_ADDR           = 32'h00002000,             // Tile memory base address.
parameter int        TILE_BITS                = PORT_CACHE_BITS,          // The bit width of the tile memory.  128bit X 256words = 256 character 8x16 font, 1 bit color. IE: 4kb.
parameter int        TILE_WORDS               = 1024,                     // The total number of tile memory words at 'TILE_BITS' width.
//parameter string     TILE_MIF_FILE            = "VGA_FONT_8x16_mono32.mif", //*******DAMN ALTERA STRING BUG!!!! // A PC-style 4 kilobyte default 8x16, 1 bit color font organized as 32bit words.
parameter bit        ENABLE_PALETTE     [0:7] = '{1,1,1,1,1,1,1,1},       // Enable a palette for 8/4/2/1 bit depth.  Heavily recommended when using 'TILE_MODE'.
parameter bit        SKIP_PALETTE_DELAY       = 0,                        // When set to 1 and palette is disabled, the resulting delay timing will be the same as the
parameter int        PAL_BITS                 = PORT_CACHE_BITS,          // Palette width.
parameter bit [31:0] PAL_BASE_ADDR            = 32'h00001000,             // Palette base address.
parameter int        PAL_WORDS                = (256/PORT_CACHE_BITS*32)*SDI_LAYERS, // The total number of palette memory words at 'PAL_BITS' width.
parameter int        PAL_ADR_SHIFT            = 0,                        // Use 0 for off.  If PAL_BITS is made 32 and PORT_CACHE_BITS is truly 128bits, then use 2.
//parameter string     PAL_MIF_FILE             = "VGA_PALETTE_RGBA32.mif", //*******DAMN ALTERA STRING BUG!!!! // An example default palette, stored as 32 bits Alpha-Blend,Blue,Green,Red.


// ******* Do not edit these ****
parameter            HC_BITS             = 16,             // Width of horizontal counter.
parameter            VC_BITS             = 16,             // Width of vertical counter.
parameter bit [6:0]  LAYERS              = PDI_LAYERS * SDI_LAYERS   ,   // Total window layers in system
parameter int        CACHE_ADW           = $clog2(PORT_CACHE_BITS/8) ,   // This is the number of address bits for the number of bytes within a single cache block.
parameter int        LBUF_CACHE_ADW      = $clog2(LBUF_BITS/8)       ,   // This is the number of address bits for the number of bytes within a single cache block.
parameter int        LBUF_DADW           = $clog2(LBUF_BITS/32)      ,   // This is the number of address bits for the number of bytes within the 32bit display output.
parameter int        LBUF_ADW            = $clog2(LBUF_WORDS)        ,   // This is the number of address bits for the line buffer on the write side.
parameter int        LBUF_ADW_WIN        = $clog2(LBUF_WORDS/SDI_LAYERS) // This is the number of address bits for the line buffer per window layer.
)(
output logic         CLK_IN             ,
output logic         reset              ,
output logic [2:0]   CLK_DIVIDER        ,         // Set a pixel clock divider, use 0 through 7 to divide the clock 1 through 8.
output logic [2:0]   VIDEO_MODE                   // Select video mode 0 through 15

);

logic VID_CLK_2x = 0 ;
wire  CMD_CLK    = CLK_IN;
wire  CMD_RST    = reset;
wire  VID_CLK    = CLK_IN;
wire  VID_RST    = reset;

logic               CMD_DDR3_ready ;
logic               CMD_win_enable         [0:LAYERS-1] ; // Enable window layer.
logic [2:0]         CMD_win_bpp            [0:LAYERS-1] ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
logic [31:0]        CMD_win_base_addr      [0:LAYERS-1] ; // The beginning memory address for the window.
logic [HC_BITS-1:0] CMD_win_bitmap_width   [0:LAYERS-1] ; // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.
logic [HC_BITS-1:0] CMD_win_bitmap_x_pos   [0:LAYERS-1] ; // The beginning X pixel position inside the bitmap in memory.
logic [VC_BITS-1:0] CMD_win_bitmap_y_pos   [0:LAYERS-1] ; // The beginning Y line position inside the bitmap in memory.
logic [HC_BITS-1:0] CMD_win_x_offset       [0:LAYERS-1] ; // The onscreen X position of the window.
logic [VC_BITS-1:0] CMD_win_y_offset       [0:LAYERS-1] ; // The onscreen Y position of the window.
logic [HC_BITS-1:0] CMD_win_x_size         [0:LAYERS-1] ; // The onscreen display width of the window.      *** Using 0 will disable the window.
logic [VC_BITS-1:0] CMD_win_y_size         [0:LAYERS-1] ; // The onscreen display height of the window.     *** Using 0 will disable the window.
logic [3:0]         CMD_win_scale_width    [0:LAYERS-1] ; // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
logic [3:0]         CMD_win_scale_height   [0:LAYERS-1] ; // Pixel vertical zoom height.   For 1x,2x,3x thru 16x, use 0,1,2 thru 15.
logic [3:0]         CMD_win_scale_h_begin  [0:LAYERS-1] ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
logic [3:0]         CMD_win_scale_v_begin  [0:LAYERS-1] ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
logic               CMD_win_tile_enable    [0:LAYERS-1] ; // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
logic [15:0]        CMD_win_tile_base      [0:LAYERS-1] ; // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
logic [2:0]         CMD_win_tile_bpp       [0:LAYERS-1] ; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
logic [1:0]         CMD_win_tile_width     [0:LAYERS-1] ; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
logic [1:0]         CMD_win_tile_height    [0:LAYERS-1] ; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
logic [23:0]        CMD_BGC_RGB                         ; // Bottom background color when every layer's pixel happens to be transparent. 
logic [7:0]         CMD_win_alpha_adj      [0:LAYERS-1] ; // When 0, the layer translucency will be determined by the graphic data.
logic [7:0]         CMD_SDI_layer_swap [0:PDI_LAYERS-1] ; // Re-position the SDI layer order of each PDI layer line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
logic [7:0]         CMD_PDI_layer_swap [0:SDI_LAYERS-1] ; // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 

logic                         CMD_busy            = 0 ; // Only send out commands when DDR3 is not busy.
logic                         CMD_read_ready      = 0 ;
logic [PORT_CACHE_BITS-1:0]   CMD_rdata           = 0 ;
logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_rx  = 0 ;
logic                         TAP_wena            = 0 ;
logic [PORT_ADDR_SIZE-1:0]    TAP_waddr           = 0 ;
logic [PORT_CACHE_BITS-1:0]   TAP_wdata           = 0 ;
logic [PORT_CACHE_BITS/8-1:0] TAP_wmask           = 0 ;


BrianHG_GFX_VGA_Window_System #(

.ENDIAN                ( ENDIAN                ),
.PORT_ADDR_SIZE        ( PORT_ADDR_SIZE        ),
.PORT_VECTOR_SIZE      ( PORT_VECTOR_SIZE      ),
.PORT_CACHE_BITS       ( PORT_CACHE_BITS       ),
.PDI_LAYERS            ( PDI_LAYERS            ),
.SDI_LAYERS            ( SDI_LAYERS            ),
.ENABLE_alpha_adj      ( ENABLE_alpha_adj      ), // Use 0 to bypass the CMD_win_alpha_override logic.
.ENABLE_SDI_layer_swap ( ENABLE_SDI_layer_swap ), // Use 0 to bypass the serial layer swapping logic
.ENABLE_PDI_layer_swap ( ENABLE_PDI_layer_swap ), // Use 0 to bypass the parallel layer swapping logic
.LBUF_BITS             ( LBUF_BITS             ),
.LBUF_WORDS            ( LBUF_WORDS            ),
.MAX_BURST             ( MAX_BURST             ),
.MAX_BURST_1st         ( MAX_BURST_1st         ),
.ENABLE_TILE_MODE      ( ENABLE_TILE_MODE      ),
.SKIP_TILE_DELAY       ( SKIP_TILE_DELAY       ),
.TILE_BASE_ADDR        ( TILE_BASE_ADDR        ),
.TILE_BITS             ( TILE_BITS             ),
.TILE_WORDS            ( TILE_WORDS            ),
//.TILE_MIF_FILE         ( TILE_MIF_FILE         ),  = "VGA_FONT_8x16_mono32.mif", //*******DAMN ALTERA STRING BUG!!!! 
.ENABLE_PALETTE        ( ENABLE_PALETTE        ),
.SKIP_PALETTE_DELAY    ( SKIP_PALETTE_DELAY    ),
.PAL_BITS              ( PAL_BITS              ),
.PAL_BASE_ADDR         ( PAL_BASE_ADDR         ),
.PAL_WORDS             ( PAL_WORDS             ),
.PAL_ADR_SHIFT         ( PAL_ADR_SHIFT         )
//.PAL_MIF_FILE          ( PAL_MIF_FILE          )   = "VGA_PALETTE_RGBA32.mif", //*******DAMN ALTERA STRING BUG!!!!

) DUT_VGASYS (

.CMD_RST                ( CMD_RST                ), // CMD section reset.
.CMD_CLK                ( CMD_CLK                ), // System CMD RAM clock.
.CMD_DDR3_ready         ( CMD_DDR3_ready         ), // Enables display and DDR3 reading of data.

.CMD_win_enable         ( CMD_win_enable         ), // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_win_bpp            ( CMD_win_bpp            ), // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_win_base_addr      ( CMD_win_base_addr      ), // The beginning memory address for the window.
.CMD_win_bitmap_width   ( CMD_win_bitmap_width   ), // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.
.CMD_win_bitmap_x_pos   ( CMD_win_bitmap_x_pos   ), // The beginning X pixel position inside the bitmap in memory.
.CMD_win_bitmap_y_pos   ( CMD_win_bitmap_y_pos   ), // The beginning Y line position inside the bitmap in memory.
.CMD_win_x_offset       ( CMD_win_x_offset       ), // The onscreen X position of the window.
.CMD_win_y_offset       ( CMD_win_y_offset       ), // The onscreen Y position of the window.
.CMD_win_x_size         ( CMD_win_x_size         ), // The onscreen display width of the window.      *** Using 0 will disable the window.
.CMD_win_y_size         ( CMD_win_y_size         ), // The onscreen display height of the window.     *** Using 0 will disable the window.
.CMD_win_scale_width    ( CMD_win_scale_width    ), // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
.CMD_win_scale_height   ( CMD_win_scale_height   ), // Pixel vertical zoom height.   For 1x,2x,3x thru 16x, use 0,1,2 thru 15.
.CMD_win_scale_h_begin  ( CMD_win_scale_h_begin  ), // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
.CMD_win_scale_v_begin  ( CMD_win_scale_v_begin  ), // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.

.CMD_win_tile_enable    ( CMD_win_tile_enable    ), // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
.CMD_win_tile_base      ( CMD_win_tile_base      ), // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
.CMD_win_tile_bpp       ( CMD_win_tile_bpp       ), // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_win_tile_width     ( CMD_win_tile_width     ), // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
.CMD_win_tile_height    ( CMD_win_tile_height    ), // Defines the height of the tile. 0,1,2,3 = 4,8,16,32

.CMD_BGC_RGB            ( CMD_BGC_RGB            ), // Bottom background color when every layer's pixel happens to be transparent. 
.CMD_win_alpha_adj      ( CMD_win_alpha_adj      ), // When 0, the layer translucency will be determined by the graphic data.
.CMD_SDI_layer_swap     ( CMD_SDI_layer_swap     ), // Re-position the SDI layer order each PDI layer line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
.CMD_PDI_layer_swap     ( CMD_PDI_layer_swap     ), // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 

.CMD_VID_hena           (                        ), // Horizontal Video Enable in the CMD_CLK domain.
.CMD_VID_vena           (                        ), // Vertical   Video Enable in the CMD_CLK domain.

.CMD_busy               ( CMD_busy               ), // Only send out commands when DDR3 is not busy.
.CMD_ena                (                        ), // Transmit a DDR3 command.
.CMD_write_ena          (                        ), // Send a write data command. *** Not in use.
.CMD_wdata              (                        ), // Write data.                *** Not in use.
.CMD_wmask              (                        ), // Write mask.                *** Not in use.
.CMD_addr               (                        ), // DDR3 memory address in byte form.
.CMD_read_vector_tx     (                        ), // Contains the destination line buffer address.  ***_tx to avoid confusion, IE: Send this port to the DDR3's read vector input.
.CMD_priority_boost     (                        ), // Boost the read command above everything else including DDR3 refresh. *** Not in use.
.CMD_read_ready         ( CMD_read_ready         ),
.CMD_rdata              ( CMD_rdata              ), 
.CMD_read_vector_rx     ( CMD_read_vector_rx     ), // Contains the destination line buffer address.  ***_rx to avoid confusion, IE: the DDR3's read vector results drives this port.
.TAP_wena               ( TAP_wena               ),
.TAP_waddr              ( TAP_waddr              ),
.TAP_wdata              ( TAP_wdata              ),
.TAP_wmask              ( TAP_wmask              ),

.VID_RST                ( VID_RST                ), // Video output pixel clock's reset.
.VID_CLK                ( VID_CLK                ), // Reference PLL clock.
.VID_CLK_2x             ( VID_CLK_2x             ), // Reference PLL clock.
.CLK_DIVIDER            ( CLK_DIVIDER            ), // Supports 0 through 7 to divide the clock from 1 through 8.
.VIDEO_MODE             ( VIDEO_MODE             ), // Supports 480p, 480px2, 480px4, 480px8, 720p, 720px2, 720p4x, 1280x1024, 1280x1024x2, 1080p, 1080px2.
.PIXEL_CLK              (                        ), // Pixel output clock.
.RGBA                   (                        ), // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend
.VENA_out               (                        ), // High during active video.
.HS_out                 (                        ), // Horizontal sync output.
.VS_out                 (                        )  // Vertical sync output.
);

localparam      CLK_MHZ_IN  = 100 ;
localparam      period      = 500000/CLK_MHZ_IN ;
localparam      STOP_uS     = 1000000 ;
localparam      endtime     = STOP_uS * 25;

initial begin
// A table of 16 possible VIDEO_MODEs (MN#).
// ------------------------------------------------------------------------------------------
// MN# = Mode xCLK_DIVIDER(-1) Required VID_CLK frequency.
// 0   = 480p      x1           27.00 MHz=60p or  54.00 MHz=120p or 108.00 MHz=240p
// 0   = 480p      x2           54.00 MHz=60p or 108.00 MHz=120p or 216.00 MHz=240p
// 0   = 480p      x4          108.00 MHz=60p or 216.00 MHz=120p
// 0   = 480p      x8          216.00 MHz=60p
// 1   = 720p      x1           74.25 MHz=60p or 148.50 MHz=120p or 297.00 MHz=240p
// 1   = 720p      x2          148.50 MHz=60p or 297.00 MHz=120p
// 1   = 720p      x4          297.00 MHz=60p
// 2   = 1440x960  x1          108.00 MHz=60p or 216.00 MHz=120p
// 2   = 1440x960  x2          216.00 MHz=60p
// 3   = 1280x1024 x1          108.00 MHz=60p or 216.00 MHz=120p
// 3   = 1280x1024 x2          216.00 MHz=60p
// 4   = 1080p     x1          148.50 MHz=60p or  74.25 MHz=30p
// 4   = 1080p     x2          297.00 MHz=60p or 148.50 MHz=30p
// 4   = 1080p     x4        too fast MHz=60p or 297.00 MHz=30p

CLK_DIVIDER         = SDI_LAYERS-1 ;
VIDEO_MODE          = 0 ;
CMD_busy            = 0 ;

// Initialize the metrics for drawing a video line.
for (int i=0 ; i<LAYERS ; i++) begin

    CMD_win_enable         [i] = 1            ; // Enable window layer.
    CMD_win_bpp            [i] = 5            ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB.
    CMD_win_base_addr      [i] = 32'h00000000 ; // The beginning memory address for the window.
    CMD_win_bitmap_width   [i] = 256          ; // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.
    CMD_win_bitmap_x_pos   [i] = 0            ; // The beginning X pixel position inside the bitmap in memory.
    CMD_win_bitmap_y_pos   [i] = 0            ; // The beginning Y line position inside the bitmap in memory.

    CMD_win_x_offset       [i] = 0            ; // The onscreen X position of the window.
    CMD_win_y_offset       [i] = 0            ; // The onscreen Y position of the window.
    CMD_win_x_size         [i] = 256          ; // The onscreen display width of the window.      *** Using 0 will disable the window.
    CMD_win_y_size         [i] = 32           ; // The onscreen display height of the window.     *** Using 0 will disable the window.

    CMD_win_scale_width    [i] = 0            ; // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15.  
    CMD_win_scale_height   [i] = 0            ; // Pixel vertical zoom height.   For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
    CMD_win_scale_h_begin  [i] = 0            ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
    CMD_win_scale_v_begin  [i] = 0            ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.


    CMD_win_tile_enable    [i] = 0            ; // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
    CMD_win_tile_base      [i] = 0            ; // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
    CMD_win_tile_bpp       [i] = 0            ; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
    CMD_win_tile_width     [i] = 1            ; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
    CMD_win_tile_height    [i] = 2            ; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32

    CMD_win_alpha_adj      [i] = 127            ; // When 0, the layer translucency will be determined by the graphic data.

end
    CMD_BGC_RGB                = 0            ; // Bottom background color.

for (int i=0 ; i<PDI_LAYERS ; i++) CMD_SDI_layer_swap[i] = 0 ; // Re-position the SDI layer order each PDI layer line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
for (int i=0 ; i<SDI_LAYERS ; i++) CMD_PDI_layer_swap[i] = 0 ; // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 


reset          = 1'b1 ; // Reset input
CLK_IN         = 1'b1 ;
VID_CLK_2x     = 1'b1 ;
CMD_DDR3_ready = 1'b0 ;

#(period); // Align to clock input.

// *****************************************************************
// Write palette test data.
// *****************************************************************
//#(period*2); TAP_waddr         = 16'h1000 ; TAP_wdata   = 128'h00000001000000090000000a0000000f ; TAP_wmask       = 16'hFFFF ; TAP_wena = 1 ; 
#(period*2); TAP_waddr         = 16'h0000 ; TAP_wdata   = 128'h00000000000000000000000000000000 ; TAP_wmask       = 0        ; TAP_wena = 0 ; 

// *****************************************************************
// Write Tile test data.
// *****************************************************************
//#(period*2); TAP_waddr         = 16'h2000 ; TAP_wdata   = 128'haaf00103070f1f3f7fff55103070f1f3 ; TAP_wmask       = 16'hFFFF ; TAP_wena = 1 ; 
//#(period*2); TAP_waddr         = 16'h2010 ; TAP_wdata   = 128'hf00f0000000000000000000000000000 ; TAP_wmask       = 16'hFFFF ; TAP_wena = 1 ; 
#(period*2); TAP_waddr         = 16'h0000 ; TAP_wdata   = 128'h00000000000000000000000000000000 ; TAP_wmask       = 0        ; TAP_wena = 0 ; 

// *****************************************************************
// Write line buffer test data.
// *****************************************************************
#(period*2); CMD_read_vector_rx = 12'h000 ; CMD_rdata   = 128'h000102030405060708090a0b0c0d0e0f ; CMD_read_ready  = 1 ; 
#(period*2); CMD_read_vector_rx = 12'h001 ; CMD_rdata   = 128'h88889999aaaabbbbccccddddeeeeffff ; CMD_read_ready  = 1 ; 
#(period*2); CMD_read_vector_rx = 12'h000 ; CMD_rdata   = 128'h00000000000000000000000000000000 ; CMD_read_ready  = 0 ; 

#(50000);
reset          = 1'b0 ; // Release reset at 50ns.
CMD_DDR3_ready = 1'b1 ;
end

always #(period/1)     CLK_IN     = !CLK_IN     ;  // create source clock oscillator
always #(period/2)     VID_CLK_2x = !VID_CLK_2x ;  // create source clock oscillator
always #(endtime)      $stop            ;  // Stop simulation from going on forever.


endmodule
