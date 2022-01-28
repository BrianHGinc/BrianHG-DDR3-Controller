// ***************************************************************************************
// BrianHG_GFX_VGA_Window_System.sv Hardware Realtime Multi-Window Video Graphics Adapter
// Version 1.6, December 26, 2021.
//
// Supports multiple windows / layers.
// With SDI-Sequentially interleave display layers to save on FPGA resources at the expense of dividing the output pixel clock.
// and  PDI-Parallel stacked display layers which allow full pixel speed clocks, but uses multiple M9K blocks and multipliers
//      for layer mixing.
//
//
//
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
module BrianHG_GFX_VGA_Window_System #(

parameter string     ENDIAN                   = "Little",                 // Enter "Little" or "Big".  Used for selecting the Endian in tile mode when addressing 16k tiles.
parameter int        PORT_ADDR_SIZE           = 24 ,                      // Must match PORT_ADDR_SIZE.
parameter int        PORT_VECTOR_SIZE         = 12 ,                      // Must match PORT_VECTOR_SIZE and be at least large enough for the video line pointer + line buffer module ID.
parameter int        PORT_CACHE_BITS          = 128,                      // Must match PORT_R/W_DATA_WIDTH and be PORT_CACHE_BITS wide for optimum speed.
parameter bit [3:0]  PDI_LAYERS               = 1,                        // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
parameter bit [3:0]  SDI_LAYERS               = 1,                        // Use 1,2,4, or 8 sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system.

parameter bit        ENABLE_alpha_adj         = 1,                        // Use 0 to bypass the CMD_win_alpha_override logic.
parameter bit        ENABLE_SDI_layer_swap    = 1,                        // Use 0 to bypass the serial layer swapping logic
parameter bit        ENABLE_PDI_layer_swap    = 1,                        // Use 0 to bypass the parallel layer swapping logic


parameter int        LBUF_BITS                = PORT_CACHE_BITS,          // The bit width of the CMD_line_buf_wdata
parameter int        LBUF_WORDS               = 256,                      // The total number of 'CMD_line_buf_wdata' words of memory.
                                                                          // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                                                          // Only use factors of 2, IE: 256/512/1024...
parameter int        MAX_BURST                = LBUF_WORDS/4/SDI_LAYERS,  // Generic maximum burst length.  IE: A burst will not be called unless this many free words exist inside the line buffer memory.
parameter int        MAX_BURST_1st            = (MAX_BURST/4),            // In a multi-window system, this defines the maximum read burst size per window after the H-reset period
                                                                          // allowing all the window buffers to gain a minimal amount of graphic data before running full length bursts.



parameter bit        ENABLE_TILE_MODE   [0:7] = '{1,0,0,0,0,0,0,0},       // Enable font/tile memory mode.  This is for all SDI_LAYERs within 1 array entry for each PDI_LAYERs.
                                                                          // If only 1 line buffer module will have tiles enabled to allow coalescing of all the available font memory
                                                                          // into one huge chunk, use only the first line-buffer module as the base-address will increment based
                                                                          // on the PDI_LAYER position * tile length in bytes.

parameter bit        SKIP_TILE_DELAY          = 0,                        // When set to 1 and font/tile is disabled, the pipeline delay of the 'tile' engine will be skipped saving logic cells
                                                                          // However, if you are using multiple Video_Line_Buffer modules in parallel, some with and others without 'tiles'
                                                                          // enabled, the video outputs of each Video_Line_Buffer module will no longer be pixel accurate super-imposed on top of each other.


parameter bit [31:0] TILE_BASE_ADDR           = 32'h00002000,             // Tile memory base address.
parameter int        TILE_BITS                = PORT_CACHE_BITS,          // The bit width of the tile memory.  128bit X 256words = 256 character 8x16 font, 1 bit color. IE: 4kb.
parameter int        TILE_WORDS               = 1024,                     // The total number of tile memory words at 'TILE_BITS' width.
                                                                          // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                                                          // Use a minimum of 256, maximum can go as far as the available FPGA memory.
                                                                          // Note that screen memory is 32 bits per tile.
                                                                          // Real-time software tile controls:
                                                                          // Each tile can be 4/8/16/32 pixels wide and tall.
                                                                          // Tile depth can be set to 1/2/4/8/16/32 bits per pixel.
                                                                          // Each 32bit screen character mem =
                                                                          // {8bit offset color, 8bit multiply color, 1bit v-flip, 1bit h-mirror, 14bit tile address}
                                                                          //  ---- For 2 thru 8 bit tiles/fonts ---- (multiply, then add rounding to 8 bits)
                                                                          //  Special for 1 bit tiles, the first byte is background and the next byte is foreground color.
                                                                          //  16/32 bit tile modes are true-color.

//parameter string     TILE_MIF_FILE            = "VGA_FONT_8x16_mono32.mif", //*******DAMN ALTERA STRING BUG!!!! // A PC-style 4 kilobyte default 8x16, 1 bit color font organized as 32bit words.


                                                                          // Palette is bypassed when operating in true-color modes.
parameter bit        ENABLE_PALETTE     [0:7] = '{1,1,1,1,1,1,1,1},       // Enable a palette for 8/4/2/1 bit depth.  Heavily recommended when using 'TILE_MODE'.
                                                                          // This is for all SDI_LAYERs within 1 array entry for each PDI_LAYERs.
parameter bit        SKIP_PALETTE_DELAY       = 0,                        // When set to 1 and palette is disabled, the resulting delay timing will be the same as the
                                                                          // 'SKIP_TILE_DELAY' parameter except for when with multiple ideo_Line_Buffer modules,
                                                                          // some have the palette feature enabled and others have it disabled.
                                                                        
parameter int        PAL_BITS                 = PORT_CACHE_BITS,          // Palette width.
parameter bit [31:0] PAL_BASE_ADDR            = 32'h00001000,             // Palette base address.
parameter int        PAL_WORDS                = (256*32/PORT_CACHE_BITS)*SDI_LAYERS, // The total number of palette memory words at 'PAL_BITS' width.
                                                                          // Having extra palette width allows for multiple palettes, each dedicated
                                                                          // to their own SDI_LAYER.  Otherwise, all the SDI_LAYERS will share
                                                                          // the same palette.

parameter int        PAL_ADR_SHIFT            = 0,                        // Use 0 for off.  If PAL_BITS is made 32 and PORT_CACHE_BITS is truly 128bits, then use 2.
                                                                          // *** Optionally make each 32 bit palette entry skip a x^2 number of bytes
                                                                          // so that we can use a minimal single M9K block for a 32bit palette.
                                                                          // Use 0 is you just want to write 32 bit data to a direct address from 0 to 255.
                                                                          // *** This is a saving measure for those who want to use a single M9K block of ram
                                                                          // for the palette, yet still interface with the BrianHG_DDR3 'TAP_xxx' port which
                                                                          // may be 128 or 256 bits wide.  The goal is to make the minimal single 256x32 M9K blockram
                                                                          // and spread each write address to every 4th or 8th chunk of 128/256 bit 'TAP_xxx' address space.

//parameter string     PAL_MIF_FILE             = "VGA_PALETTE_RGBA32.mif", //*******DAMN ALTERA STRING BUG!!!! // An example default palette, stored as 32 bits Alpha-Blend,Blue,Green,Red.

parameter bit [1:0]  OPTIMIZE_TW_FMAX   = 1,                 // Adds a D-Latch buffer for writing to the tile memory when dealing with huge TILE mem sizes.
parameter bit [1:0]  OPTIMIZE_PW_FMAX   = 1,                 // Adds a D-Latch buffer for writing to the tile memory when dealing with huge palette mem sizes.

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
// *****************************************************************
// **** Window control inputs ****
// *****************************************************************
input                               CMD_RST                            , // CMD section reset.
input                               CMD_CLK                            , // System CMD RAM clock.
input                               CMD_DDR3_ready                     , // Enables display and DDR3 reading of data.

input                               CMD_win_enable         [0:LAYERS-1], // Enables window layer.
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


input       [23:0]                  CMD_BGC_RGB                        , // Bottom background color when every layer's pixel happens to be transparent. 
input        [7:0]                  CMD_win_alpha_adj      [0:LAYERS-1], // When 0, the layer translucency will be determined by the graphic data.
                                                                         // Any figure from +1 to +127 will progressive force all the graphics opaque.
                                                                         // Any figure from -1 to -128 will progressive force all the graphics transparent.

input        [7:0]                  CMD_SDI_layer_swap [0:PDI_LAYERS-1], // Re-position the SDI layer order of each PDI layer line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
input        [7:0]                  CMD_PDI_layer_swap [0:SDI_LAYERS-1], // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 

output logic                        CMD_VID_hena = 0                   , // Horizontal Video Enable in the CMD_CLK domain.
output logic                        CMD_VID_vena = 0                   , // Vertical   Video Enable in the CMD_CLK domain.

// *****************************************************************
// **** DDR3 Read channel control ****
// *****************************************************************
input                                  CMD_busy                 , // Only send out commands when DDR3 is not busy.
output                                 CMD_ena                  , // Transmit a DDR3 command.
output                                 CMD_write_ena            , // Send a write data command. *** Not in use.
output       [PORT_CACHE_BITS-1:0]     CMD_wdata                , // Write data.                *** Not in use.
output       [PORT_CACHE_BITS/8-1:0]   CMD_wmask                , // Write mask.                *** Not in use.
output       [PORT_ADDR_SIZE-1:0]      CMD_addr                 , // DDR3 memory address in byte form.
output       [PORT_VECTOR_SIZE-1:0]    CMD_read_vector_tx       , // Contains the destination line buffer address.  ***_tx to avoid confusion, IE: Send this port to the DDR3's read vector input.
output                                 CMD_priority_boost       , // Boost the read command above everything else including DDR3 refresh. *** Not in use.
// CMD_read channel results.
input                                  CMD_read_ready           ,
input        [PORT_CACHE_BITS-1:0]     CMD_rdata                , 
input        [PORT_VECTOR_SIZE-1:0]    CMD_read_vector_rx       , // Contains the destination line buffer address.  ***_rx to avoid confusion, IE: the DDR3's read vector results drives this port.

// *** Tap port access which will allow any BrianHG_DDR3 multiport connected peripheral to write directly to the palette and font/tile memory and read back the written values from the DDR3.
input                                  TAP_wena                 ,
input        [PORT_ADDR_SIZE-1:0]      TAP_waddr                ,
input        [PORT_CACHE_BITS-1:0]     TAP_wdata                ,
input        [PORT_CACHE_BITS/8-1:0]   TAP_wmask                ,


// **********************************************************************
// **** Video clock domain and output timing from BrianHG_GFX_Sync_Gen.sv
// **********************************************************************
input                               VID_RST                              , // Video output pixel clock's reset.
input                               VID_CLK                              , // Reference PLL clock.
input                               VID_CLK_2x                           , // Reference PLL clock.

input        [2:0]                  CLK_DIVIDER                          , // Supports 0 through 7 to divide the clock from 1 through 8.
                                                                           // Also cannot be higher than SDI_LAYERS and only SDI layers 0 through this number will be shown.

input        [2:0]                  VIDEO_MODE                           , // Supports 480p, 480px2, 480px4, 480px8, 720p, 720px2, 1280x1024, 1280x1024x2, 1080p, 1080px2.
                                                                           // x2,x4,x8 requires the PLL clock and divider to be set accordingly,
                                                                           // otherwise the scan rate will be divided by that factor.


(*useioff=1*) output logic          PIXEL_CLK                            , // Pixel output clock.
(*useioff=1*) output logic [31:0]   RGBA                                 , // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend
(*useioff=1*) output logic          VENA_out                             , // High during active video.
(*useioff=1*) output logic          HS_out                               , // Horizontal sync output.
(*useioff=1*) output logic          VS_out                                 // Vertical sync output.


);

generate
if (PORT_VECTOR_SIZE < (LBUF_ADW+3) )  initial begin
$warning("*********************************************");
$warning("*** BrianHG_GFX_VGA_Window_System ERROR.  ***");
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
$warning("*** BrianHG_GFX_VGA_Window_System ERROR.  ***");
$warning("***********************************************************");
$warning("*** Your current parameter .SDI_LAYERS(%d) is invalid. ***",6'(SDI_LAYERS));
$warning("*** It can only be 1, 2, 4, or 8.                       ***");
$warning("***********************************************************");
$error;
$stop;
end

if ( (PDI_LAYERS<1) || (PDI_LAYERS>8) )  initial begin
$warning("*********************************************");
$warning("*** BrianHG_GFX_VGA_Window_System ERROR.  ***");
$warning("***********************************************************");
$warning("*** Your current parameter .PDI_LAYERS(%d) is invalid. ***",6'(PDI_LAYERS));
$warning("*** It can only be anywhere from 1 through 8.           ***");
$warning("***********************************************************");
$error;
$stop;
end
endgenerate

logic [2:0]          CLK_PHASE_sg ;
logic [HC_BITS-1:0]  h_count_sg   ;
logic [VC_BITS-1:0]  v_count_sg   ;
logic                H_ena_sg     ;
logic                V_ena_sg     ;
logic                HS_sg        ;
logic                VS_sg        ;

logic                CMD_vid_ena             [0:LAYERS-1] ; // Enable video line. 
logic [2:0]          CMD_vid_bpp             [0:LAYERS-1] ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6. *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
logic [HC_BITS-1:0]  CMD_vid_h_offset        [0:LAYERS-1] ; // The beginning display X coordinate for the video.
logic [HC_BITS-1:0]  CMD_vid_h_width         [0:LAYERS-1] ; // The display width of the video.      0 = Disable video layer.
logic [3:0]          CMD_vid_pixel_width     [0:LAYERS-1] ; // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
logic [3:0]          CMD_vid_width_begin     [0:LAYERS-1] ; // Begin the display left shifted part-way into a zoomed pixel.
logic [6:0]          CMD_vid_x_buf_begin     [0:LAYERS-1] ; // Within the line buffer, this defines the first pixel to be shown.
logic                CMD_vid_tile_enable     [0:LAYERS-1] ; // Enable Tile Mode
logic [15:0]         CMD_vid_tile_base       [0:LAYERS-1] ; // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
logic [2:0]          CMD_vid_tile_bpp        [0:LAYERS-1] ; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6. *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
logic [1:0]          CMD_vid_tile_width      [0:LAYERS-1] ; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
logic [1:0]          CMD_vid_tile_height     [0:LAYERS-1] ; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
logic [4:0]          CMD_vid_tile_x_begin    [0:LAYERS-1] ; // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
logic [4:0]          CMD_vid_tile_y_begin    [0:LAYERS-1] ; // When displaying a line with tile enabled, this coordinate defines the Y location

logic                lb_stat_hrst        [0:PDI_LAYERS-1] ;
logic                lb_stat_vena        [0:PDI_LAYERS-1] ;
logic                lb_stat_qinc            [0:LAYERS-1] ;  // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.

logic [2:0]          lb_CLK_PHASE_OUT    [0:PDI_LAYERS-1] ;
logic [HC_BITS-1:0]  lb_h_count_out      [0:PDI_LAYERS-1] ;
logic                lb_H_ena_out        [0:PDI_LAYERS-1] ;
logic                lb_V_ena_out        [0:PDI_LAYERS-1] ;
logic [31:0]         lb_RGBA             [0:PDI_LAYERS-1] ;
logic                lb_WLENA            [0:PDI_LAYERS-1] ;
logic                lb_VENA             [0:PDI_LAYERS-1] ;
logic [7:0]          lb_alpha_adj        [0:PDI_LAYERS-1] ;
logic                lb_HS_out           [0:PDI_LAYERS-1] ;
logic                lb_VS_out           [0:PDI_LAYERS-1] ;

logic [2:0]          mix_CLK_PHASE_OUT   ;
logic [31:0]         mix_RGBA            ;
logic                mix_VENA_out        ;
logic                mix_HS_out          ;
logic                mix_VS_out          ;

// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ****** Generate the video sync **********
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************

// A table of 8 possible video modes (MN#).
// ------------------------------------------------------------------------------------------
// Optimized for 2 frequency groups, (27/54/108/216) and (74.25/148.5/297)
// to achieve all the main 16:9 standards except for 1280x1024.
// All modes target multiples of the standard 59.94Hz.
// ------------------------------------------------------------------------------------------
// MN# = Mode xCLK_DIVIDER(-1) Required VID_CLK frequency.
// ------------------------------------------------------------------------------------------
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
// ------------------------------------------------------------------------------------------
// Special modes / Spare slots...
// ------------------------------------------------------------------------------------------
// 5   = 
// 6   = 
// 7   = ***480p   x5          148.50 MHz=60p, x4=75Hz, x6=50hz. ***** Special non-standard 480p operating on the 148.5MHz clock.
//                                                               ***** If you want the 'OFFICIAL' standard 480p, then use mode
//                                                               ***** #0 with a source clock of 27/54/108/216 MHz & properly set divider.
//
//                                                            0     1     2     3     4     5     6     7
localparam bit [HC_BITS-1:0] VID_h_total        [0:7] = '{  858, 1650, 1716, 1688, 2200,  858,  858,  940} ;
localparam bit [HC_BITS-1:0] VID_h_res          [0:7] = '{  720, 1280, 1440, 1280, 1920,  720,  720,  720} ;
localparam bit [HC_BITS-1:0] VID_hs_front_porch [0:7] = '{   16,  110,   32,   48,   88,   16,   16,   18} ;
localparam bit [HC_BITS-1:0] VID_hs_size        [0:7] = '{   62,   40,  124,  112,   44,   62,   62,   68} ;
localparam bit               VID_hs_polarity    [0:7] = '{    1,    0,    1,    0,    0,    1,    1,    1} ;
localparam bit [VC_BITS-1:0] VID_v_total        [0:7] = '{  525,  750, 1050, 1067, 1125,  525,  525,  527} ;
localparam bit [VC_BITS-1:0] VID_v_res          [0:7] = '{  480,  720,  960, 1024, 1080,  480,  480,  480} ;
localparam bit [VC_BITS-1:0] VID_vs_front_porch [0:7] = '{    6,    5,    6,    2,    4,    6,    6,    6} ;
localparam bit [VC_BITS-1:0] VID_vs_size        [0:7] = '{    6,    5,    6,    3,    5,    6,    6,    6} ;
localparam bit               VID_vs_polarity    [0:7] = '{    1,    0,    1,    0,    0,    1,    1,    1} ;

BrianHG_GFX_Sync_Gen BHG_VGA_SG (

.CLK_IN             ( VID_CLK                         ),
.reset              ( VID_RST                         ),
.CLK_DIVIDE_IN      ( CLK_DIVIDER                     ),
.VID_h_total        ( VID_h_total        [VIDEO_MODE] ),
.VID_h_res          ( VID_h_res          [VIDEO_MODE] ),
.VID_hs_front_porch ( VID_hs_front_porch [VIDEO_MODE] ),
.VID_hs_size        ( VID_hs_size        [VIDEO_MODE] ),
.VID_hs_polarity    ( VID_hs_polarity    [VIDEO_MODE] ),
.VID_v_total        ( VID_v_total        [VIDEO_MODE] ),
.VID_v_res          ( VID_v_res          [VIDEO_MODE] ),
.VID_vs_front_porch ( VID_vs_front_porch [VIDEO_MODE] ),
.VID_vs_size        ( VID_vs_size        [VIDEO_MODE] ),
.VID_vs_polarity    ( VID_vs_polarity    [VIDEO_MODE] ),
.H_ena              ( H_ena_sg                        ),
.V_ena              ( V_ena_sg                        ),
.Video_ena          (                                 ),
.HS_out             ( HS_sg                           ),
.VS_out             ( VS_sg                           ),
.CLK_PHASE_OUT      ( CLK_PHASE_sg                    ),
.h_count_out        ( h_count_sg                      ),
.v_count_out        ( v_count_sg                      ) );


always_ff @(posedge CMD_CLK) CMD_VID_hena <= H_ena_sg;
always_ff @(posedge CMD_CLK) CMD_VID_vena <= V_ena_sg;


// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ****** Generate the Window DDR3 reader system. **********
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************

BrianHG_GFX_Window_DDR3_Reader #(

.PORT_ADDR_SIZE      ( PORT_ADDR_SIZE   ), // Must match PORT_ADDR_SIZE.
.PORT_VECTOR_SIZE    ( PORT_VECTOR_SIZE ), // Must match PORT_VECTOR_SIZE and be at least large enough for the video line pointer + line buffer module ID.
.PORT_CACHE_BITS     ( PORT_CACHE_BITS  ), // Must match PORT_R/W_DATA_WIDTH and be PORT_CACHE_BITS wide for optimum speed.
.ENABLE_TILE_MODE    ( 1'b1             ), // Keep on as this doesn't add LC usage here.
.HC_BITS             ( HC_BITS          ), // Width of horizontal counter.
.VC_BITS             ( VC_BITS          ), // Width of vertical counter.
.PDI_LAYERS          ( PDI_LAYERS       ), // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
.SDI_LAYERS          ( SDI_LAYERS       ), // Number of sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system. Only 1/2/4/8 are allowed.
.LBUF_BITS           ( LBUF_BITS        ), // The bit width of the CMD_line_buf_wdata
.LBUF_WORDS          ( LBUF_WORDS       ), // The total number of 'CMD_line_buf_wdata' words of memory.
.MAX_BURST_1st       ( MAX_BURST_1st    ), // In a multi-window system, this defines the maximum read burst size per window after the H-reset period
.MAX_BURST           ( MAX_BURST        )  // Generic maximum burst length.   

) BHG_BGA_WDR (

.CMD_RST                ( CMD_RST                ), // CMD section reset.
.CMD_CLK                ( CMD_CLK                ), // System CMD RAM clock.
.CMD_DDR3_ready         ( CMD_DDR3_ready         ), // Enables display and DDR3 reading of data.

.CMD_win_enable         ( CMD_win_enable         ), // Enables window layer. 
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

.CMD_busy               ( CMD_busy               ), // Only send out commands when DDR3 is not busy.
.CMD_ena                ( CMD_ena                ), // Transmit a DDR3 command.
.CMD_write_ena          ( CMD_write_ena          ), // Send a write data command. *** Not in use.
.CMD_wdata              ( CMD_wdata              ), // Write data.                *** Not in use.
.CMD_wmask              ( CMD_wmask              ), // Write mask.                *** Not in use.
.CMD_addr               ( CMD_addr               ), // DDR3 memory address in byte form.
.CMD_read_vector_tx     ( CMD_read_vector_tx     ), // Contains the destination line buffer address.  ***_tx to avoid confusion, IE: Send this port to the DDR3's read vector input.
.CMD_priority_boost     ( CMD_priority_boost     ), // Boost the read command above everything else including DDR3 refresh. *** Unused for now.

.lb_stat_hrst           ( lb_stat_hrst[0]        ), // Strobes for 1 clock when the end of the display line has been reached.
.lb_stat_vena           ( lb_stat_vena[0]        ), // High during the active lines of the display frame.
.lb_stat_qinc           ( lb_stat_qinc           ), // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.

.CMD_vid_ena            ( CMD_vid_ena            ), // Enable video line. 
.CMD_vid_bpp            ( CMD_vid_bpp            ), // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_vid_h_offset       ( CMD_vid_h_offset       ), // The beginning display X coordinate for the video.
.CMD_vid_h_width        ( CMD_vid_h_width        ), // The display width of the video.      0 = Disable video layer.
.CMD_vid_pixel_width    ( CMD_vid_pixel_width    ), // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
.CMD_vid_width_begin    ( CMD_vid_width_begin    ), // Begin the display left shifted part-way into a zoomed pixel.
.CMD_vid_x_buf_begin    ( CMD_vid_x_buf_begin    ), // Within the line buffer, this defines the first pixel to be shown.
.CMD_vid_tile_enable    ( CMD_vid_tile_enable    ), // Tile mode enable.
.CMD_vid_tile_base      ( CMD_vid_tile_base      ), // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
.CMD_vid_tile_bpp       ( CMD_vid_tile_bpp       ), // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_vid_tile_width     ( CMD_vid_tile_width     ), // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
.CMD_vid_tile_height    ( CMD_vid_tile_height    ), // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
.CMD_vid_tile_x_begin   ( CMD_vid_tile_x_begin   ), // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
.CMD_vid_tile_y_begin   ( CMD_vid_tile_y_begin   )  // When displaying a line with tile enabled, this coordinate defines the displayed tile's Y coordinate.
);

// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ****** Generate the Line buffer module, multiple modules in parallel if PDI_LAYERS is > 1. **********
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
genvar x;
generate
for (x=0 ; x<PDI_LAYERS ; x=x+1) begin : BHG_VGA_LB_inst

localparam int        xa      = x*SDI_LAYERS                                   ; // Define the first channel in the multi-window array.
localparam int        xb      = x*SDI_LAYERS+SDI_LAYERS-1                      ; // Define the last channel in the multi-window array.
localparam bit [31:0] xt_addr = TILE_BASE_ADDR + (x*(TILE_WORDS*TILE_BITS/8))  ; // Calculate the beginning tile/font base address for each individual banks of line buffers.
localparam bit [31:0] xp_addr = PAL_BASE_ADDR  + (x*(PAL_WORDS *PAL_BITS /8))  ; // Calculate the beginning palette   base address for each individual banks of line buffers.

BrianHG_GFX_Video_Line_Buffer #(

.ENDIAN              (ENDIAN),               // Enter "Little" or "Big".  Used for selecting the Endian in tile mode when addressing 16k tiles.
.PORT_ADDR_SIZE      (PORT_ADDR_SIZE),       // Number of address bits used for font/tile memory and palette access.
.PORT_CACHE_BITS     (PORT_CACHE_BITS),      // The bit width of the CMD_line_buf_wdata.
.LB_MODULE_ID        (x),                    // When using multiple line buffer modules in parallel, up to 8 max, assign this module's ID from 0 through 7.
.SDI_LAYERS          (SDI_LAYERS),           // Serial Display Layers.  The number of layers multiplexed into this display line buffer.
                                             // Must be a factor of 2, IE: only use 1,2,4 or 8 as 'CLK_PHASE_IN' is only 3 bits.
                                             // Note that when you use multiple line buffer modules in parallel), each line buffer module
                                             // should use the same layer count to be compatible with the BrianHG_GFX_Window_DDR3_Reader.sv module.
                                             
.LBUF_BITS           (LBUF_BITS),            // The bit width of the CMD_line_buf_wdata
.LBUF_WORDS          (LBUF_WORDS),           // The total number of 'CMD_line_buf_wdata' words of memory.
                                             // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                             // Only use factors of 2), IE: 256/512/1024...
 
.ENABLE_TILE_MODE    (ENABLE_TILE_MODE[x]),  // Enable font/tile memory mode.  This is for all SDI_LAYERS.
.SKIP_TILE_DELAY     (0),                    // When set to 1 and font/tile is disabled, the pipeline delay of the 'tile' engine will be skipped saving logic cells
                                             // However, if you are using multiple Video_Line_Buffer modules in parallel, some with and others without 'tiles'
                                             // enabled, the video outputs of each Video_Line_Buffer module will no longer be pixel accurate super-imposed on top of each other.

.TILE_BASE_ADDR      (xt_addr),              // Tile memory base address.
.TILE_BITS           (TILE_BITS),            // The bit width of the tile memory.  128bit X 256words  (256 character 8x16 font), 1 bit color. IE: 4kb.
.TILE_WORDS          (TILE_WORDS),           // The total number of tile memory words at 'TILE_BITS' width.
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
.ENABLE_PALETTE      (ENABLE_PALETTE[x]),    // Enable a palette for 8/4/2/1 bit depth.  Heavily recommended when using 'TILE_MODE'.
.SKIP_PALETTE_DELAY  (0),                    // When set to 1 and palette is disabled, the resulting delay timing will be the same as the
                                             // 'SKIP_TILE_DELAY' parameter except for when with multiple ideo_Line_Buffer modules,
                                             // some have the palette feature enabled and others have it disabled.
                                             
.PAL_BITS            (PAL_BITS),             // Palette width.
.PAL_BASE_ADDR       (xp_addr),              // Palette base address.
.PAL_WORDS           (PAL_WORDS),            // The total number of palette memory words at 'PAL_BITS' width.
                                             // Having extra palette width allows for multiple palettes), each dedicated
                                             // to their own SDI_LAYER.  Otherwise), all the SDI_LAYERS will share
                                             // the same palette.
                                             
.PAL_ADR_SHIFT       (0),                    // Use 0 for off.  If PAL_BITS is made 32 and PORT_CACHE_BITS is truly 128bits), then use 2.
                                             // *** Optionally make each 32 bit palette entry skip a x^2 number of bytes
                                             // so that we can use a minimal single M9K block for a 32bit palette.
                                             // Use 0 is you just want to write 32 bit data to a direct address from 0 to 255.
                                             // *** This is a saving measure for those who want to use a single M9K block of ram
                                             // for the palette), yet still interface with the BrianHG_DDR3 'TAP_xxx' port which
                                             // may be 128 or 256 bits wide.  The goal is to make the minimal single 256x32 M9K blockram
                                             // and spread each write address to every 4th or 8th chunk of 128/256 bit 'TAP_xxx' address space.
 
//.PAL_MIF_FILE ("VGA_PALETTE_RGBA32.mif")  *******DAMN ALTERA STRING BUG!!!! // An example default palette), stored as 32 bits Alpha-Blend),Blue),Green),Red.

.OPTIMIZE_TW_FMAX(OPTIMIZE_TW_FMAX),
.OPTIMIZE_PW_FMAX(OPTIMIZE_PW_FMAX)

) BHG_VGA_LB (

// ***********************************************************************************
// ***** System memory clock interface, line buffer tile/palette write memory inputs.
// ***********************************************************************************
.CMD_RST              ( CMD_RST                          ), // CMD section reset.
.CMD_CLK              ( CMD_CLK                          ), // System CMD RAM clock.
.CMD_lbuf_wena        ( CMD_read_ready                   ), // Write enable for the line buffer.
.CMD_lbuf_wdata       ( CMD_rdata                        ), // Line buffer write data.
.CMD_lbuf_waddr       ( CMD_read_vector_rx[LBUF_ADW-1:0] ), // Line buffer write address. ***_rx to avoid confusion, IE: the DDR3's read vector results drives this port.
.CMD_LBID             ( CMD_read_vector_rx[LBUF_ADW+:3]  ), // Allow writing to this one line-buffer module based on it's selected matching parameter 'LB_MODULE_ID'.

.CMD_tile_wena        ( TAP_wena                         ), // Write enable for the tile memory buffer.
.CMD_tile_waddr       ( TAP_waddr                        ), // Tile memory buffer write address.
.CMD_tile_wdata       ( TAP_wdata                        ), // Tile memory buffer write data.
.CMD_tile_wmask       ( TAP_wmask                        ), // Tile memory buffer write mask.
.CMD_pal_wena         ( TAP_wena                         ), // Write enable for the palette buffer.
.CMD_pal_waddr        ( TAP_waddr                        ), // Palette buffer write address.
.CMD_pal_wdata        ( TAP_wdata                        ), // Palette buffer write data.
.CMD_pal_wmask        ( TAP_wmask                        ), // Palette buffer write mask.

// *******************************************************************************
// ***** Line drawing parameters received from BrianHG_GFX_Window_DDR3_Reader.sv
// ***** Use arrays for the quantity of SDI_LAYERS.
// *******************************************************************************
.CMD_vid_ena            ( CMD_vid_ena            [xa:xb]  ), // Enable video line. 
.CMD_vid_bpp            ( CMD_vid_bpp            [xa:xb]  ), // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
.CMD_vid_h_offset       ( CMD_vid_h_offset       [xa:xb]  ), // The beginning display X coordinate for the video.
.CMD_vid_h_width        ( CMD_vid_h_width        [xa:xb]  ), // The display width of the video.      0 = Disable video layer.
.CMD_vid_pixel_width    ( CMD_vid_pixel_width    [xa:xb]  ), // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
.CMD_vid_width_begin    ( CMD_vid_width_begin    [xa:xb]  ), // Begin the display left shifted part-way into a zoomed pixel.
                                                             // Used for smooth sub-pixel scrolling a window display past the left margin of the display.
.CMD_vid_x_buf_begin    ( CMD_vid_x_buf_begin    [xa:xb]  ), // Within the line buffer, this defines the first pixel to be shown.
                                                             // The first 4 bits define the tile's X coordinate.

.CMD_vid_tile_enable    ( CMD_vid_tile_enable    [xa:xb]  ), // Tile mode enable.
.CMD_vid_tile_base      ( CMD_vid_tile_base      [xa:xb]  ), // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
.CMD_vid_tile_bpp       ( CMD_vid_tile_bpp       [xa:xb]  ), // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
.CMD_vid_tile_width     ( CMD_vid_tile_width     [xa:xb]  ), // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
.CMD_vid_tile_height    ( CMD_vid_tile_height    [xa:xb]  ), // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
.CMD_vid_tile_x_begin   ( CMD_vid_tile_x_begin   [xa:xb]  ), // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
.CMD_vid_tile_y_begin   ( CMD_vid_tile_y_begin   [xa:xb]  ), // When displaying a line with tile enabled, this coordinate defines
                                                             // the displayed tile's Y coordinate.

.CMD_win_alpha_adj      ( CMD_win_alpha_adj      [xa:xb]  ), // When 0, the layer translucency will be determined by the graphic data.

// **********************************************************************
// **** Video clock domain and output timing from BrianHG_GFX_Sync_Gen.sv
// **********************************************************************
.VID_RST              ( VID_RST                  ), // Video output pixel clock's reset.
.VID_CLK              ( VID_CLK                  ), // Video output pixel clock.

.VCLK_PHASE_IN        ( CLK_PHASE_sg             ), // Used with sync gen if there are 
.hc_in                ( h_count_sg               ), // horizontal pixel counter.
.H_ena_in             ( H_ena_sg                 ), // Horizontal video enable.
.V_ena_in             ( V_ena_sg                 ), // Vertical video enable.
.HS_in                ( HS_sg                    ), // Horizontal sync output.
.VS_in                ( VS_sg                    ), // Vertical sync output.

.VCLK_PHASE_OUT       ( lb_CLK_PHASE_OUT [x]     ), // Pixel clock divider position.
.hc_out               ( lb_h_count_out   [x]     ), // horizontal pixel counter.
.H_ena_out            ( lb_H_ena_out     [x]     ), // Horizontal video enable.
.V_ena_out            ( lb_V_ena_out     [x]     ), // Vertical video enable.
.RGBA                 ( lb_RGBA          [x]     ), // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend
.WLENA                ( lb_WLENA         [x]     ), // Window Layer Active Out.
.VENA                 ( lb_VENA          [x]     ), // Active Video Out.
.vid_alpha_adj        ( lb_alpha_adj     [x]     ), // SDI interleaved alpha adjust controls.
.HS_out               ( lb_HS_out        [x]     ), // Horizontal sync output.
.VS_out               ( lb_VS_out        [x]     ), // Vertical sync output.

// *************************************************************************************************************
// ***** Display Line buffer status to be sent back to BrianHG_GFX_Window_DDR3_Reader.sv, clocked on CMD_CLK.
// *************************************************************************************************************
.lb_stat_hrst         ( lb_stat_hrst     [x]     ), // Strobes for 1 clock when the end of the display line has been reached.
.lb_stat_vena         ( lb_stat_vena     [x]     ), // High during the active lines of the display frame.
.lb_stat_qinc         ( lb_stat_qinc     [xa:xb] )  // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.
);
end
endgenerate

// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ****** Mix all the layers into 1 single video output. *****************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************

BrianHG_GFX_Layer_mixer #(

.PDI_LAYERS            ( PDI_LAYERS                    ), // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
.SDI_LAYERS            ( SDI_LAYERS                    ), // Number of sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system. Only 1/2/4/8 are allowed.
.ENABLE_alpha_adj      ( ENABLE_alpha_adj              ), // Use 0 to bypass the CMD_win_alpha_override logic.
.ENABLE_SDI_layer_swap ( ENABLE_SDI_layer_swap         ), // Use 0 to bypass the serial layer swapping logic
.ENABLE_PDI_layer_swap ( ENABLE_PDI_layer_swap         )  // Use 0 to bypass the parallel layer swapping logic

) BHG_VGA_MIXER (

.CLK_DIVIDER           ( CLK_DIVIDER                   ), // Supports 0 through 7 to divide the clock from 1 through 8.
.CMD_BGC_RGB           ( CMD_BGC_RGB                   ), // Bottom background color when every layer's pixel happens to be transparent. 
.CMD_SDI_layer_swap    ( CMD_SDI_layer_swap            ), // Re-position the SDI layer order of each line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
.CMD_PDI_layer_swap    ( CMD_PDI_layer_swap            ), // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 

.VID_RST               ( VID_RST                       ), // Video output pixel clock's reset.
.VID_CLK               ( VID_CLK                       ), // Video output pixel clock.

.VCLK_PHASE_IN         ( lb_CLK_PHASE_OUT [0]          ), 
.H_ena_in              ( lb_H_ena_out     [0]          ),
.V_ena_in              ( lb_V_ena_out     [0]          ),
.VENA_in               ( lb_VENA          [0]          ),
.HS_in                 ( lb_HS_out        [0]          ),
.VS_in                 ( lb_VS_out        [0]          ),
.RGBA_in               ( lb_RGBA      [0:PDI_LAYERS-1] ),
.WLENA_in              ( lb_WLENA     [0:PDI_LAYERS-1] ),
.alpha_adj_in          ( lb_alpha_adj [0:PDI_LAYERS-1] ),

.VCLK_PHASE_OUT        ( mix_CLK_PHASE_OUT             ),
.H_ena_out             (                               ),
.V_ena_out             (                               ),
.VENA_out              ( mix_VENA_out                  ),
.HS_out                ( mix_HS_out                    ),
.VS_out                ( mix_VS_out                    ),
.RGBA_out              ( mix_RGBA                      ) );

// **********************************************************************************************************************************
// **********************************************************************************************************************************
// **********************************************************************************************************************************
// **********************************************************************************************************************************
// ****** Generate PSEUDO DDR video output port which uses the DDR PHY to generate a pixel clock for the video DAC. **********
// **********************************************************************************************************************************
// **********************************************************************************************************************************
// **********************************************************************************************************************************
// **********************************************************************************************************************************

// Render a divided clock output.
logic [31:0]         mix0_RGBA   ;
logic                mix0_WLENA  ;
logic                mix0_VENA   ;
logic                mix0_HS_out ;
logic                mix0_VS_out ;
logic [31:0]         mix1_RGBA   ;
logic                mix1_WLENA  ;
logic                mix1_VENA   ;
logic                mix1_HS_out ;
logic                mix1_VS_out ;
logic [31:0]         mix2_RGBA   ;
logic                mix2_WLENA  ;
logic                mix2_VENA   ;
logic                mix2_HS_out ;
logic                mix2_VS_out ;

logic vidtclk = 0, vtc0=0, vtc1=0, vtc2=0 ;

always_ff @(posedge VID_CLK) begin

if (mix_CLK_PHASE_OUT==0) begin
                                 vidtclk    <= !vidtclk ;

                                 mix2_RGBA[24+:8] <= mix_RGBA[24+:8];
                                 mix2_RGBA[16+:8] <= mix_RGBA[16+:8];
                                 mix2_RGBA[ 8+:8] <= mix_RGBA[ 8+:8];
                                 mix2_RGBA[ 0+:8] <= mix_RGBA[ 0+:8];

                                 mix2_VENA        <= mix_VENA_out ;
                                 mix2_HS_out      <= mix_HS_out   ;
                                 mix2_VS_out      <= mix_VS_out   ;

                                 end

end

always_ff @(posedge VID_CLK_2x) begin 
vtc0        <= vidtclk;
vtc1        <= vtc0;
vtc2        <= vtc1;
PIXEL_CLK   <= !vtc1 ^ vtc2 ; // Select between direct clock and divided clock.

mix1_RGBA   <= mix2_RGBA   ;
mix1_VENA   <= mix2_VENA   ;
mix1_HS_out <= mix2_HS_out ;
mix1_VS_out <= mix2_VS_out ;

mix0_RGBA   <= mix1_RGBA   ;
mix0_VENA   <= mix1_VENA   ;
mix0_HS_out <= mix1_HS_out ;
mix0_VS_out <= mix1_VS_out ;

RGBA        <= mix0_RGBA   ;
VENA_out    <= mix0_VENA   ;
HS_out      <= mix0_HS_out ;
VS_out      <= mix0_VS_out ;
end
endmodule
