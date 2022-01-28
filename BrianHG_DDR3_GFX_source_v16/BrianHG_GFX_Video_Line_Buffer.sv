// *****************************************************************************************************
// BrianHG_GFX_Video_Line_Buffer.sv.
// IE: Generate a 1/2/4/8/16/32 bpp video line buffer with text-font/tile and palette capabilities.
//
// Version 1.6, December 9, 2021.
//
// Written by Brian Guralnick.
// For public use.
//
// Receives display layer quantity, color depth, position, horizontal scale, & memory writes into dual clock buffer.
// Inputs alignment and X-position from sync-gen.
// Outputs read buffer position on the CMD_CLK and outputs picture data on the VID_CLK, multiplexed if multiple display layers is enabled.
// Outputs parallel in time copy of syncs & CLK_PHASE_POS from sync-gen.
//
// Optional palette with it's own dual port write address.
// Optional font / tile memory display system.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************************************************


// *** Note: With parameters ENABLE_TILE_MODE=1 and ENABLE_PALETTE=1, the sync input to sync & picture output pipeline delay is 11 clocks.
// ***       The current tile    system's pipeline delay is 4 clocks.
// ***       The current palette system's pipeline delay is 3 clocks.
// ***       These delays must be included if their parameters ENABLE_T/P=0 and their SKIP_TILE_DELAY / SKIP_PALETTE_DELAY = 0
// ***       so that a multi-module based multi-layer system where some modules have their ENABLE_T/P=0 will still retain
// ***       a parallel timed output with reference to the sync input.

module BrianHG_GFX_Video_Line_Buffer #(

parameter string     ENDIAN             = "Little",          // Enter "Little" or "Big".  Used for selecting the Endian in tile mode when addressing 16k tiles.
parameter int        HC_BITS            = 16,                // Width of horizontal counter.
parameter int        PORT_ADDR_SIZE     = 32,                // Number of address bits used for font/tile memory and palette access.
parameter int        PORT_CACHE_BITS    = 128,               // The bit width of the CMD_line_buf_wdata.
parameter int        LB_MODULE_ID       = 0,                 // When using multiple line buffer modules in parallel, up to 8 max, assign this module's ID from 0 through 7.
parameter int        SDI_LAYERS         = 1,                 // Serial Display Layers.  The number of layers multiplexed into this display line buffer.
                                                             // Must be a factor of 2, IE: only use 1,2,4 or 8 as 'CLK_PHASE_IN' is only 3 bits.
                                                             // Note that when you use multiple line buffer modules in parallel, each line buffer module
                                                             // should use the same layer count to be compatible with the BrianHG_GFX_Window_DDR3_Reader.sv module.

parameter int        LBUF_BITS          = PORT_CACHE_BITS,   // The bit width of the CMD_line_buf_wdata
parameter int        LBUF_WORDS         = 256,               // The total number of 'CMD_line_buf_wdata' words of memory.
                                                             // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                                             // Only use factors of 2, IE: 256/512/1024...

parameter bit        ENABLE_TILE_MODE   = 0,                 // Enable font/tile memory mode.  This is for all SDI_LAYERS.
parameter bit        SKIP_TILE_DELAY    = 0,                 // When set to 1 and font/tile is disabled, the pipeline delay of the 'tile' engine will be skipped saving logic cells
                                                             // However, if you are using multiple Video_Line_Buffer modules in parallel, some with and others without 'tiles'
                                                             // enabled, the video outputs of each Video_Line_Buffer module will no longer be pixel accurate super-imposed on top of each other.

parameter bit [31:0] TILE_BASE_ADDR     = 32'h00002000,      // Tile memory base address.
parameter int        TILE_BITS          = PORT_CACHE_BITS,   // The bit width of the tile memory.  128bit X 256words = 256 character 8x16 font, 1 bit color. IE: 4kb.
parameter int        TILE_WORDS         = 1024,              // The total number of tile memory words at 'TILE_BITS' width.
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

//parameter string     TILE_MIF_FILE      = "VGA_FONT_8x16_mono32.mif", //*******DAMN ALTERA STRING BUG!!!! // A PC-style 4 kilobyte default 8x16, 1 bit color font organized as 32bit words.


                                                             // Palette is bypassed when operating in true-color modes.
parameter bit        ENABLE_PALETTE     = 0,                 // Enable a palette for 8/4/2/1 bit depth.  Heavily recommended when using 'TILE_MODE'.
parameter bit        SKIP_PALETTE_DELAY = 0,                 // When set to 1 and palette is disabled, the resulting delay timing will be the same as the
                                                             // 'SKIP_TILE_DELAY' parameter except for when with multiple ideo_Line_Buffer modules,
                                                             // some have the palette feature enabled and others have it disabled.

parameter int        PAL_BITS           = PORT_CACHE_BITS,   // Palette width.
parameter bit [31:0] PAL_BASE_ADDR      = 32'h00001000,      // Palette base address.
parameter int        PAL_WORDS          = (256/PORT_CACHE_BITS*32)*SDI_LAYERS,     // The total number of palette memory words at 'PAL_BITS' width.
                                                             // Having extra palette width allows for multiple palettes, each dedicated
                                                             // to their own SDI_LAYER.  Otherwise, all the SDI_LAYERS will share
                                                             // the same palette.

parameter int        PAL_ADR_SHIFT      = 0,                 // Use 0 for off.  If PAL_BITS is made 32 and PORT_CACHE_BITS is truly 128bits, then use 2.
                                                             // *** Optionally make each 32 bit palette entry skip a x^2 number of bytes
                                                             // so that we can use a minimal single M9K block for a 32bit palette.
                                                             // Use 0 is you just want to write 32 bit data to a direct address from 0 to 255.
                                                             // *** This is a saving measure for those who want to use a single M9K block of ram
                                                             // for the palette, yet still interface with the BrianHG_DDR3 'TAP_xxx' port which
                                                             // may be 128 or 256 bits wide.  The goal is to make the minimal single 256x32 M9K blockram
                                                             // and spread each write address to every 4th or 8th chunk of 128/256 bit 'TAP_xxx' address space.

//parameter string     PAL_MIF_FILE       = "VGA_PALETTE_RGBA32.mif", //*******DAMN ALTERA STRING BUG!!!! // An example default palette, stored as 32 bits Alpha-Blend,Blue,Green,Red.

parameter bit [1:0]  OPTIMIZE_TW_FMAX   = 1,                 // Adds a D-Latch buffer for writing to the tile memory when dealing with huge TILE mem sizes.
parameter bit [1:0]  OPTIMIZE_PW_FMAX   = 1,                 // Adds a D-Latch buffer for writing to the tile memory when dealing with huge palette mem sizes.

// Do not edit these values...
parameter int        CACHE_ADW          = $clog2(PORT_CACHE_BITS/8), // This is the number of address bits for the number of bytes within a single cache block.
parameter int        LBUF_CACHE_ADW     = $clog2(LBUF_BITS/8)      , // This is the number of address bits for the number of bytes within a single cache block.
parameter int        TILE_CACHE_ADW     = $clog2(TILE_BITS/8)      , // This is the number of address bits for the number of bytes within a single cache block.
parameter int        PAL_CACHE_ADW      = $clog2(PAL_BITS/8)       , // This is the number of address bits for the number of bytes within a single cache block.
parameter int        LBUF_ADW           = $clog2(LBUF_WORDS)       , // This is the number of address bits for the line buffer on the write side.
parameter int        PAL_ADW            = $clog2(PAL_WORDS)        , // This is the number of address bits for the palette ram on the write side.
parameter int        TILE_ADW           = $clog2(TILE_WORDS)         // This is the number of address bits for the tile/font ram on the write side.
)(

// ***********************************************************************************
// ***** System memory clock interface, line buffer tile/palette write memory inputs.
// ***********************************************************************************
input                               CMD_RST                              , // CMD section reset.
input                               CMD_CLK                              , // System CMD RAM clock.
input        [2:0]                  CMD_LBID                             , // Allow writing to this one line-buffer module based on it's selected matching parameter 'LB_MODULE_ID'.
input                               CMD_lbuf_wena                        , // Write enable for the line buffer.
input        [LBUF_ADW-1:0]         CMD_lbuf_waddr                       , // Line buffer write address.
input        [LBUF_BITS-1:0]        CMD_lbuf_wdata                       , // Line buffer write data.

input                               CMD_tile_wena                        , // Write enable for the tile memory buffer.
input        [PORT_ADDR_SIZE-1:0]   CMD_tile_waddr                       , // Tile memory buffer write address.
input        [TILE_BITS-1:0]        CMD_tile_wdata                       , // Tile memory buffer write data.
input        [TILE_BITS/8-1:0]      CMD_tile_wmask                       , // Tile memory buffer write mask.

input                               CMD_pal_wena                         , // Write enable for the palette buffer.
input        [PORT_ADDR_SIZE-1:0]   CMD_pal_waddr                        , // Palette buffer write address.
input        [PAL_BITS-1:0]         CMD_pal_wdata                        , // Palette buffer write data.
input        [PAL_BITS/8-1:0]       CMD_pal_wmask                        , // Palette buffer write mask.


// ******************************************************************************* override 
// ***** Line drawing parameters received from BrianHG_GFX_Window_DDR3_Reader.sv
// ***** Use arrays for the quantity of SDI_LAYERS.
// *******************************************************************************
input                               CMD_vid_ena            [0:SDI_LAYERS-1], // Enable the display line. 
input        [2:0]                  CMD_vid_bpp            [0:SDI_LAYERS-1], // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
input        [HC_BITS-1:0]          CMD_vid_h_offset       [0:SDI_LAYERS-1], // The beginning display X coordinate for the video.
input        [HC_BITS-1:0]          CMD_vid_h_width        [0:SDI_LAYERS-1], // The display width of the video.      0 = Disable video layer.
input        [3:0]                  CMD_vid_pixel_width    [0:SDI_LAYERS-1], // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
input        [3:0]                  CMD_vid_width_begin    [0:SDI_LAYERS-1], // Begin the display left shifted part-way into a zoomed pixel.
                                                                             // Used for smooth sub-pixel scrolling a window display past the left margin of the display.
input        [6:0]                  CMD_vid_x_buf_begin    [0:SDI_LAYERS-1], // Within the line buffer, this defines the first pixel to be shown.
                                                                             
input                               CMD_vid_tile_enable    [0:SDI_LAYERS-1], // Tile mode enable.
input        [15:0]                 CMD_vid_tile_base      [0:SDI_LAYERS-1], // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
                                                                             // *** This is the address inside the line buffer tile/font blockram which always begins at 0, NOT the DDR3 TAP_xxx port write address.
input        [2:0]                  CMD_vid_tile_bpp       [0:SDI_LAYERS-1], // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 BGR. 
input        [1:0]                  CMD_vid_tile_width     [0:SDI_LAYERS-1], // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
input        [1:0]                  CMD_vid_tile_height    [0:SDI_LAYERS-1], // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
input        [4:0]                  CMD_vid_tile_x_begin   [0:SDI_LAYERS-1], // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
input        [4:0]                  CMD_vid_tile_y_begin   [0:SDI_LAYERS-1], // When displaying a line with tile enabled, this coordinate defines
                                                                             // the displayed tile's Y coordinate.

input        [7:0]                  CMD_win_alpha_adj      [0:SDI_LAYERS-1], // When 0, the layer translucency will be determined by the graphic data.
                                                                             // Any figure from +1 to +127 will progressive force all the graphics opaque.
                                                                             // Any figure from -1 to -128 will progressive force all the graphics transparent.


// **********************************************************************
// **** Video clock domain and output timing from BrianHG_GFX_Sync_Gen.sv
// **********************************************************************
input                               VID_RST                              , // Video output pixel clock's reset.
input                               VID_CLK                              , // Video output pixel clock.

input        [2:0]                  VCLK_PHASE_IN                        , // Used with sync gen is there are 
input        [HC_BITS-1:0]          hc_in                                , // horizontal pixel counter.
input                               H_ena_in                             , // Horizontal video enable.
input                               V_ena_in                             , // Vertical video enable.
input                               HS_in                                , // Horizontal sync output.
input                               VS_in                                , // Vertical sync output.

output logic [2:0]                  VCLK_PHASE_OUT                       , // Pixel clock divider position.
output logic [HC_BITS-1:0]          hc_out                               , // horizontal pixel counter.
output logic                        H_ena_out                            , // Horizontal video enable.
output logic                        V_ena_out                            , // Vertical video enable.

output logic [31:0]                 RGBA                                 , // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend
output logic                        WLENA                                , // Window Layer Active Out.
output logic [7:0]                  vid_alpha_adj                        , // Sequential alpha adjust control.

output logic                        VENA                                 , // High during active video.
output logic                        HS_out                               , // Horizontal sync output.
output logic                        VS_out                               , // Vertical sync output.

// *************************************************************************************************************
// ***** Display Line buffer status to be sent back to BrianHG_GFX_Window_DDR3_Reader.sv, clocked on CMD_CLK.
// *************************************************************************************************************
output logic                        lb_stat_hrst                         , // Strobes for 1 clock when the end of the display line has been reached.
output logic                        lb_stat_vena                         , // High during the active lines of the display frame.
output logic                        lb_stat_qinc         [0:SDI_LAYERS-1]  // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.
);

generate
if ( (SDI_LAYERS!=1) && (SDI_LAYERS!=2) && (SDI_LAYERS!=4) && (SDI_LAYERS!=8) )  initial begin
$warning("********************************************");
$warning("*** BrianHG_GFX_Video_Line_Buffer ERROR. ***");
$warning("***********************************************************");
$warning("*** Your current parameter .SDI_LAYERS(%d) is invalid. ***",6'(SDI_LAYERS));
$warning("*** It can only be 1, 2, 4, or 8.                       ***");
$warning("***********************************************************");
$error;
$stop;
end
endgenerate


// **********************************************************************************
// Localparam constants.
// **********************************************************************************

localparam bit [2:0]  bpp_conv   [0:7] = '{0,1,2,3,4,5,4,5} ; // translate input to modes 
localparam bit [2:0]  bpp_rconv  [0:7] = '{5,4,3,2,1,0,1,0} ; // translate input to modes in reverse 
localparam bit [4:0]  tile_irst  [0:3] = '{3,7,15,31} ;       // define the tile width begin points

// Preset an 'AND' mask to only allow display of the active bits.
localparam bit [31:0] bpp_mask   [0:7] = '{32'h00000001,32'h00000003,32'h0000000F,32'h000000FF,32'h0000FFFF,32'hFFFFFFFF,32'h0000FFFF,32'hFFFFFFFF} ;
localparam bit [4:0]  bpp_endian [0:7] = '{ 5'b11111   , 5'b11110   , 5'b11100   , 5'b11000   , 5'b10000   , 5'b00000   , 5'b10000   , 5'b00000   } ;

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Typedef structures.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************

typedef struct packed {     // Generate a structure for the sync generator bus.
logic           [2:0] phase  ;
logic   [HC_BITS-1:0] h_cnt  ;
logic                 h_ena  ;
logic                 v_ena  ;
logic                 hs     ;
logic                 vs     ;
} sync_bus ;

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// STEP 1: Generate an adjustable horizontal delay from the Sync Generator
//         to adjust the global processing pipeline to match the output
//         delay timing when multiple parallel BrianHG_GFX_Video_Line_Buffer
//         modules are used in parallel where some may have the TILE and/or
//         PALETTE is disabled changing the total pipeline length of those
//         particular modules.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************

localparam  ADDED_LB_DATA_DLY   = ENABLE_TILE_MODE   ; // This adds a sequential register delay prior to feeding the tile's blockram read address in an effort to improve FMAX.
localparam  ADDED_TO_TILE_DLY   = 1                  ; // This adds a sequential register delay prior to feeding the tile's blockram read address in an effort to improve FMAX.
localparam  ADDED_TILE_ADDR_DLY = 1                  ; // This adds a sequential register delay prior to feeding the tile's blockram read address in an effort to improve FMAX.
localparam  ADDED_TILE_DATA_DLY = 1                  ; // This adds a sequential register delay after the tile's blockram read data in an effort to improve FMAX.


localparam  DISABLED_TILE_DLY    = (ENABLE_TILE_MODE || SKIP_TILE_DELAY   ) ? 0 : (6 +ADDED_TO_TILE_DLY + ADDED_TILE_ADDR_DLY + ADDED_TILE_DATA_DLY) ;
localparam  DISABLED_PALETTE_DLY = (ENABLE_PALETTE   || SKIP_PALETTE_DELAY) ? 0 : 1 ;


// Compute the added horizontal input delay when the TILE and/or PALETTE is disabled.
localparam             SG_IN_DLY           = DISABLED_TILE_DLY + DISABLED_PALETTE_DLY ;

sync_bus sync_in,si ;
assign   sync_in = '{VCLK_PHASE_IN,hc_in,H_ena_in,V_ena_in,HS_in,VS_in}; // Declare the sync_in bus structure.

logic [SDI_LAYERS-1:0] win_line_start_in, win_line_start ; // Generate a Window Line Start flag for each layer
always_comb for (int i = 0 ; i < SDI_LAYERS ; i++ ) win_line_start_in[i] = (CMD_vid_h_offset[i] == hc_in) && CMD_vid_ena[i] && (CMD_vid_h_width[i]!=0) ;

// Generate an adjustable delay for the source sync generator & Window Line Start flag.
BHG_delay_pipe #(.delay(SG_IN_DLY),.width($bits(sync_bus         ))) dl_s1 ( .clk(VID_CLK), .in(sync_in          ), .out(si            ) );
BHG_delay_pipe #(.delay(SG_IN_DLY),.width($bits(win_line_start_in))) dl_s2 ( .clk(VID_CLK), .in(win_line_start_in), .out(win_line_start) );

logic VID_RST_REG = 0 ;
always_ff @(posedge VID_CLK) VID_RST_REG <= VID_RST ; // Help FMAX in case VID_RST input came from a different clock domain.


// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// STEP 2: For each layer, generate the line buffer read position
//         progress for the BrianHG_GFX_Window_DDR3_Reader.sv,
//         clocked on CMD_CLK.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************

localparam   lb_toggle_bit     =  $clog2(LBUF_BITS/32)+5+2       ; // +5 means the line buffer status will increment once every LBUF_WORD address read, +2 means once every 4th addresses.
logic [23:0] lbuf_addr         [0:SDI_LAYERS-1]  = '{default:'0} ; // output address to the line buffer memory.
logic        lb_stat_qinc_dl0  [0:SDI_LAYERS-1]  = '{default:'0} ; 
logic        lb_stat_qinc_dl1  [0:SDI_LAYERS-1]  = '{default:'0} ; 
logic        lb_stat_hrst_dl0                    = 0 ;
logic        lb_stat_hrst_dl1                    = 0 ;

always_ff @(posedge CMD_CLK) begin

// *** Channel independent flags.
    if (CMD_RST) begin
        lb_stat_vena         <= 0 ;
        lb_stat_hrst         <= 0 ;
        lb_stat_hrst_dl0     <= 0 ;
        lb_stat_hrst_dl1     <= 0 ;
    end else begin
        lb_stat_hrst_dl0     <=  sync_in.h_ena                              ; // lb_hena[0]
        lb_stat_hrst_dl1     <=  lb_stat_hrst_dl0                           ;
        lb_stat_hrst         <= !lb_stat_hrst_dl0    && lb_stat_hrst_dl1    ; // Sanitized 1 clock delay single CMD_CLK horizontal reset pulse once a display line finishes.
        lb_stat_vena         <=  sync_in.v_ena                              ; // High during the lines of active video.
    end // !rst

// *** Channel dependent flags.
for (int i = 0 ; i < SDI_LAYERS ; i++ ) begin
    if (CMD_RST) begin
        lb_stat_qinc     [i] <= 0 ;
        lb_stat_qinc_dl0 [i] <= 0 ;
        lb_stat_qinc_dl1 [i] <= 0 ;
    end else begin
        lb_stat_qinc_dl0 [i] <=  lbuf_addr[i][lb_toggle_bit]                 ; // lbuf_addr[i][lb_toggle_bit] = buffered line buffer read address position, IE, once toggled means that this read address has already been sent.
        lb_stat_qinc_dl1 [i] <=   lb_stat_qinc_dl0 [i]                       ;
        lb_stat_qinc     [i] <=  (lb_stat_qinc_dl1 [i] != lb_stat_qinc_dl0 [i]) && lb_stat_hrst_dl0 ; // Sanitized output which will not accidentally trigger a read during the horizontal reset.
    end // !rst
end // for i


end // @clk




// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// STEP 3: For each layer, generate the:
//                         Enable/Disable video line,
//                         Zoom width and tile X coordinates,
//                         Read line buffer address,
//                         Sequencing through all SDI layers based on
//                         syncgen's VCLK_PHASE_IN,
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************




localparam          LBUF_WORDS_32     =  LBUF_WORDS * (LBUF_BITS/32) ;
localparam          LBUF_WORDS_32_adw =  $clog2(LBUF_WORDS_32)       ;
localparam          lb_ch_adw         =  $clog2(LBUF_WORDS_32 / SDI_LAYERS) ; // Set the upper address bit limit in the line buffer counter.

logic [31:0]        LBUF_READ, LBUF_READ_d ;
logic [31:0]        LBUF_data = 0 ;

logic [HC_BITS-1:0] win_width_cnt   [0:SDI_LAYERS-1]  = '{default:'0} ; // Countdown for window line width.
logic [3:0]         pixel_scale_cnt [0:SDI_LAYERS-1]  = '{default:'0} ; // Pixel width counter for horizontal scaling using formula 1+x/16
logic               win_line_ena    [0:SDI_LAYERS-1]  = '{default:'0} ; // 
logic [4:0]         tile_x_pos      [0:SDI_LAYERS-1]  = '{default:'0} ; // X position within a tile.


reg [4:0]  r_bpp_endian  = 0 ;
reg [4:0]  r_bpp_shift   = 0 ;
reg [2:0]  r_bpp_mask    = 0 ;

// **********************************************************************************
// Generate source sync delay channel
// **********************************************************************************
localparam int lbdl = 4 + ADDED_LB_DATA_DLY;
logic [2:0]          lb_phase [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic [HC_BITS-1:0]  lb_hc    [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic                lb_lena  [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic                lb_tena  [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic                lb_hena  [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic                lb_vena  [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic                lb_hs    [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic                lb_vs    [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic [23:0]         lb_raddr [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process
logic [4:0]          lb_txpos [0:lbdl]  = '{default:'0} ; // Pipe delay for the read line buffer process

always_ff @(posedge VID_CLK) begin
        lb_phase [0] <=  si.phase  ; // set input
        lb_hc    [0] <=  si.h_cnt          ; // set input
        lb_hena  [0] <=  si.h_ena       ; // set input
        lb_vena  [0] <=  si.v_ena       ; // set input
        lb_hs    [0] <=  si.hs          ; // set input
        lb_vs    [0] <=  si.vs          ; // set input
    for (int i=1 ; i <= lbdl ; i++ ) begin // Same address generator functions for all the layers.
        lb_phase [i] <=  lb_phase [i-1] ;
        lb_hc    [i] <=  lb_hc    [i-1] ;
        lb_hena  [i] <=  lb_hena  [i-1] ;
        lb_vena  [i] <=  lb_vena  [i-1] ;
        lb_hs    [i] <=  lb_hs    [i-1] ;
        lb_vs    [i] <=  lb_vs    [i-1] ;

        if (i>1) lb_raddr [i] <= lb_raddr [i-1] ;
        if (i>1) lb_txpos [i] <= lb_txpos [i-1] ;
        if (i>1) lb_tena  [i] <= lb_tena  [i-1] ;
        if (i>1) lb_lena  [i] <= lb_lena  [i-1] ;

     end
end

logic [2:0]  lb_bpp=0,lb_bpp_pre=0 ;// lb_bpp_tb is an extra buffer to aid in lb_bpp's high fanout destinations
logic [2:0]  lb_tbpp       = 0 ;
logic [2:0]  lb_t_width    = 0 ;
logic [2:0]  lb_t_height   = 0 ;
logic [4:0]  lb_t_y_begin  = 0 ;
logic [15:0] lb_t_base     = 0 ;

wire  VID_RST_logic = VID_RST_REG || !si.v_ena || !si.h_ena ; // render the horizontal reset logic

always_ff @(posedge VID_CLK) begin

    for (int i = 0 ; i < SDI_LAYERS ; i++ ) begin // Same address generator functions for all the layers.

        if (VID_RST_logic) begin

                lbuf_addr       [i][lb_ch_adw+4:0]  <= CMD_vid_x_buf_begin[i] << bpp_conv[CMD_vid_bpp[i]] ;
                lbuf_addr       [i][lb_ch_adw+5+:3] <= (3)'(i)                ; // Maximum 4 bits
                win_line_ena    [i]                 <= 0                      ; // Disable window
                win_width_cnt   [i]                 <= CMD_vid_h_width[i]     ;
                pixel_scale_cnt [i]                 <= CMD_vid_pixel_width[i]           - CMD_vid_width_begin[i]      ; // Calculate the beginning left-shift into a zoomed line.
                tile_x_pos      [i]                 <= CMD_vid_tile_x_begin[i]     ; // Calculate the beginning left-shift the middle of the first tile.

            end else if (si.phase==i) begin

                     if ( win_line_start[i]    ) win_line_ena[i] <= 1 ; // Disable window
                else if ( win_width_cnt [i]==1 ) win_line_ena[i] <= 0 ; // Enable window

                if ( win_line_ena[i]) begin // When displaying a video line.

                                                         win_width_cnt   [i] <= win_width_cnt[i] - 1'b1 ;                          // Count down the window width until the right edge.
                            if ( pixel_scale_cnt[i] !=0) pixel_scale_cnt [i] <= pixel_scale_cnt    [i] - 1'b1 ;

                            else begin
                                    if ((tile_x_pos[i] != tile_irst[CMD_vid_tile_width[i]] ) && CMD_vid_tile_enable[i] && ENABLE_TILE_MODE) tile_x_pos[i] <= tile_x_pos[i] + 1'b1 ;
                                        else begin
                                                lbuf_addr  [i][lb_ch_adw+4:0] <= (lb_ch_adw+5)'( lbuf_addr[i] + (1'b1 << bpp_conv[CMD_vid_bpp[i]]) ) ; // Add, trim bits to the read buffer position
                                                tile_x_pos [i]                <= 0 ;
                                        end
                                                pixel_scale_cnt[i]            <= CMD_vid_pixel_width[i] ;
                                end

                            end

            end // !VID_RST && (si.phase==0)

    end // for i

// Delay the key regs which need to come out in parallel with the read data
    lb_raddr[1] <= lbuf_addr [lb_phase[0]];
    lb_txpos[1] <= tile_x_pos[lb_phase[0]];
    lb_lena[1]  <= win_line_ena[lb_phase[0]] && (lb_phase[0]<SDI_LAYERS) ; // Make sure to mute out video pixel when the lb_phase is outside the available SDI layers
    lb_tena[1]  <= CMD_vid_tile_enable[lb_phase[0]] && ENABLE_TILE_MODE  ;

// Convert different bpp read data into the RGBA 32 bit output 
r_bpp_endian  <= bpp_endian[CMD_vid_bpp[lb_phase[lbdl-3]]] ; // FMAX optimizations.
r_bpp_shift   <= ( lb_raddr[lbdl-2][4:0] ^ r_bpp_endian )  ; // FMAX optimizations.
r_bpp_mask    <= CMD_vid_bpp[lb_phase[lbdl-2]]             ; // FMAX optimizations.

          if (!lb_lena[lbdl-1]) begin
                        LBUF_data     <= 0 ; // Clear picture data
//                        lb_lena[lbdl] <= 0 ; // Force transparent image
                        end
    else begin

                        LBUF_data     <= ( LBUF_READ >> r_bpp_shift ) & bpp_mask[r_bpp_mask] ;
//                        lb_lena[lbdl] <= 1'b1      ; // Output enable image
    end

// Convert parallel settings to sequential piped SDI layer ones.  FMAX Optimizations.
lb_bpp_pre    <= CMD_vid_bpp               [lb_phase[lbdl-2]];
lb_bpp        <= lb_bpp_pre                                  ;
lb_tbpp       <= (CMD_vid_tile_enable[lb_phase[lbdl-1]] && ENABLE_TILE_MODE) ? CMD_vid_tile_bpp [lb_phase[lbdl-1]] : lb_bpp_pre;
lb_t_width    <= CMD_vid_tile_width        [lb_phase[lbdl-1]] ;
lb_t_height   <= CMD_vid_tile_height       [lb_phase[lbdl-1]] ;
lb_t_y_begin  <= CMD_vid_tile_y_begin      [lb_phase[lbdl-1]] ;
lb_t_base     <= CMD_vid_tile_base         [lb_phase[lbdl-1]] ;
end // always VID_CLK

BHG_delay_pipe #(.delay(ADDED_LB_DATA_DLY),.width(32)) dl_lbr1 ( .clk(VID_CLK), .in(LBUF_READ_d), .out(LBUF_READ) );


// **********************************************************************************
// **********************************************************************************
// Line Buffer Dual Port Memory
// **********************************************************************************
// **********************************************************************************

logic [LBUF_WORDS_32_adw-1:0] LBUF_RADDR = 0 ;
always_ff @(posedge VID_CLK)  LBUF_RADDR <= lbuf_addr[lb_phase[0]][LBUF_WORDS_32_adw+4:5]; // Shift out the insignificant bits used with video modes less than 32bpp.

// ***********************************************************************************************************************
// Endian Swap DDR3 write byte order.
wire [LBUF_BITS-1:0]   lbuf_wdata ;
                       end_swap      #(.width(LBUF_BITS)) lbuf_end (.ind(CMD_lbuf_wdata),.outd(lbuf_wdata),.inm(),.outm());
// ***********************************************************************************************************************
wire                   LBUF_WENA     = ( CMD_LBID == LB_MODULE_ID ) ;
altsyncram #(

    .intended_device_family  ( "MAX 10"        ),      .lpm_type                ( "altsyncram"    ),      .operation_mode          ( "DUAL_PORT"     ),
    .address_aclr_b          ( "NONE"          ),      .outdata_aclr_b          ( "NONE"          ),      .outdata_reg_b           ( "CLOCK1"        ),
    .clock_enable_input_a    ( "NORMAL"        ),      .clock_enable_input_b    ( "NORMAL"        ),      .clock_enable_output_b   ( "NORMAL"        ),
    .address_reg_b           ( "CLOCK1"        ),      .byte_size               ( 8               ),      .power_up_uninitialized  ( "FALSE"         ),
    
    .numwords_a              ( LBUF_WORDS      ),      .widthad_a               ( LBUF_ADW        ),      .width_a                 ( LBUF_BITS       ),
    .width_byteena_a         ( LBUF_BITS/8     ),
    
    .numwords_b              ( LBUF_WORDS_32   ),      .widthad_b             ( LBUF_WORDS_32_adw ),      .width_b                 ( 32              ),
    .init_file_layout        ( "PORT_B"        ),      .init_file             ("LBUF_BLANK.mif")

) LBUF_MEM (

    .clock0     ( CMD_CLK                             ),                            .clocken0   ( 1'b1                                                  ),
    .wren_a     ( CMD_lbuf_wena && LBUF_WENA          ),                            .address_a  ( CMD_lbuf_waddr                                        ),
    .data_a     ( lbuf_wdata                          ),                            .byteena_a  ( {(LBUF_BITS/8){1'b1}}                                 ),

    .clock1     ( VID_CLK                             ),                            .clocken1   ( 1'b1                                                  ),
    .address_b  ( (LBUF_WORDS_32_adw)'(LBUF_RADDR)    ),                            .q_b        ( LBUF_READ_d                                           ),

    .aclr0     (1'b0),    .aclr1        (1'b0),    .addressstall_a  (1'b0),     .addressstall_b  (1'b0),     .byteena_b (1'b1),     .clocken2 (1'b1),
    .clocken3  (1'b1),    .data_b ({32{1'b1}}),    .eccstatus       (),         .q_a (), .rden_a (1'b1),     .rden_b    (1'b1),     .wren_b   (1'b0)  );






// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// STEP 4: If ENABLE_TILE_MODE is disabled, bypass the tile system.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************

logic      [31:0] TILE_READ ;
logic      [31:0] tile_out_data ;


wire [9:0]         tile_out_c_index;
wire [4:0]         tile_out_x_index;
wire [4:0]         tile_out_y_index;
wire [7:0]         tile_out_c_add  ;
wire [7:0]         tile_out_c_bgc  ;
wire [20:0]        tile_out_base   ;
wire               tile_out_tena   ;
wire [2:0]         tile_out_bpp    ;
wire [3:0]         tile_out_chmult ;
wire [2:0]         tile_out_phase  ;
wire [HC_BITS-1:0] tile_out_hc     ;
wire               tile_out_hena   ;
wire               tile_out_lena   ;
wire               tile_out_vena   ;
wire               tile_out_hs     ;
wire               tile_out_vs     ;

// ***************************
// Perform the bypass.
// ***************************
generate if (!ENABLE_TILE_MODE) begin
                                assign tile_out_c_index  = 0 ; //lb_c_index [lbdl] ;
                                assign tile_out_x_index  = 0 ; //lb_x_index [lbdl] ;
                                assign tile_out_y_index  = 0 ; //lb_y_index [lbdl] ;
                                assign tile_out_c_add    = 0 ; //lb_c_add   [lbdl] ;
                                assign tile_out_c_bgc    = 0 ; //lb_c_bgc   [lbdl] ;
                                assign tile_out_base     = 0 ; //lb_base    [lbdl] ;
                                assign tile_out_tena     = 0 ; //lb_tena    [lbdl] ;
                                assign tile_out_chmult   = 0 ; //lb_chmult  [lbdl] ;
                                assign tile_out_bpp      = lb_bpp            ;
                                assign tile_out_phase    = lb_phase   [lbdl] ;
                                assign tile_out_hc       = lb_hc      [lbdl] ;
                                assign tile_out_hena     = lb_hena    [lbdl] ;
                                assign tile_out_lena     = lb_lena    [lbdl] ;
                                assign tile_out_vena     = lb_vena    [lbdl] ;
                                assign tile_out_hs       = lb_hs      [lbdl] ;
                                assign tile_out_vs       = lb_vs      [lbdl] ;
                                assign tile_out_data     = LBUF_data         ;
end else begin

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// STEP 5: Enable the tile system, compute the FPGA blockram tile address registers
//         based on character selection in DDR3 display screen memory.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
wire [15:0]        lbuf_dat16     =  (ENDIAN[0]=="L") ? {LBUF_data[7:0],LBUF_data[15:8]} : LBUF_data[15:0] ; // Optionally swap the Endian when addressing 16k tiles character set.
wire               tile_1kc       =  (lb_bpp == 5) || (lb_bpp == 6)                                        ; // Make an immediate wire which defines when we will be addressing 16k tiles instead of 256 tiles.
wire               tile_mirror    =  tile_1kc                         ? lbuf_dat16[14]         : 1'b0      ; // Select tile character mirror through the SDI_LAYERS.
wire [4:0]         tile_m_xor     =  tile_mirror                      ? tile_irst[lb_t_width]  : 5'd0      ;   
wire               tile_flip      =  tile_1kc                         ? lbuf_dat16[15]         : 1'b0      ; // Select tile character vertical flip through the SDI_LAYERS.
wire [4:0]         tile_f_xor     =  tile_flip                        ? tile_irst[lb_t_height] : 5'd0      ;   
wire [4:0]         tile_y_index   =  lb_t_y_begin    ^ tile_f_xor                                          ; // Tile Y position sequential through the SDI_LAYERS.
wire [4:0]         tile_x_index   =  lb_txpos [lbdl] ^ tile_m_xor                                          ; // Tile X position sequential through the SDI_LAYERS.
wire [2:0]         tile_width     =  (2'd2 + lb_t_width )          ;
wire [2:0]         tile_height    =  (2'd2 + lb_t_height)          ;
wire [9:0]         tile_c_index   =  tile_1kc                         ? lbuf_dat16[9:0] : {2'd0,LBUF_data[7:0]} ; // Select tile character between 8 bit and 10 bit through the SDI_LAYERS.

typedef struct packed {     // Generate a structure for the line buffer out bus.
                        logic [9:0]         c_index  ;
                        logic [4:0]         y_index  ;
                        logic [7:0]         c_add    ;
                        logic [7:0]         c_bgc    ;
                        logic               t_ena    ;
                        logic [2:0]         bpp      ;
                        logic [2:0]         phase    ;
                        logic [HC_BITS-1:0] hc       ;
                        logic               hena     ;
                        logic               lena     ;
                        logic               vena     ;
                        logic               hs       ;
                        logic               vs       ;
                        logic [31:0]        data     ;
                        logic [3:0]         chmult   ;
                        logic [20:0]        t_base   ;
                        logic [4:0]         x_index  ;
} lbo_bus ;

lbo_bus  lbo,lbo_dly ;

assign lbo.c_index =  tile_c_index ;
assign lbo.y_index =  tile_y_index                                                        ; // Tile Y position sequential through the SDI_LAYERS.
assign lbo.c_add   = (lb_bpp == 5) ? LBUF_data[23:16] : (lb_bpp==4) ? {LBUF_data[15:12],4'd0} : (lb_bpp==6) ? {LBUF_data[13:10],4'd0} : 8'd0 ; // Tile color addition when using 1/2/4/8 bpp tiles, IE: Change foreground colors when using 1 bpp tiles.
assign lbo.c_bgc   = (lb_bpp == 5) ? LBUF_data[31:24] : (lb_bpp==4) ? {4'd0,LBUF_data[11:8 ]} : (lb_bpp==6) ? {LBUF_data[13:10],4'd0} : 8'd0 ; // Tile background color.  IE: Color replacement for when the tile data is = 0.
assign lbo.t_ena   =  lb_tena  [lbdl] && ENABLE_TILE_MODE ;
assign lbo.bpp     =  lb_tbpp ;
assign lbo.phase   =  lb_phase [lbdl]  ;
assign lbo.hc      =  lb_hc    [lbdl]  ;
assign lbo.hena    =  lb_hena  [lbdl]  ;
assign lbo.lena    =  lb_lena  [lbdl]  ;
assign lbo.vena    =  lb_vena  [lbdl]  ;
assign lbo.hs      =  lb_hs    [lbdl]  ;
assign lbo.vs      =  lb_vs    [lbdl]  ;
assign lbo.data    =  LBUF_data          ;
assign lbo.chmult  =  tile_width + tile_height - bpp_rconv[lb_tbpp]     ;  // Generate the shift amount for the character index address multiplier.
assign lbo.x_index =    (tile_y_index << tile_width) + tile_x_index     ; // Tile X position sequential through the SDI_LAYERS.
assign lbo.t_base  =  (((tile_y_index << tile_width) + tile_x_index) >>  bpp_rconv[lb_tbpp]) + (lb_t_base<<2) ;


BHG_delay_pipe #(.delay(ADDED_TO_TILE_DLY),.width($bits(lbo_bus))) dl_lbo1 ( .clk(VID_CLK), .in(lbo), .out(lbo_dly) );


// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// *** Step 6, read tile generator look-up table.
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// Tile selection when using different 'CMD_vid_bpp' modes, 8/16a/32/16b bpp modes.
// * On a tile layer, bpp will actually mean bpc -> Bits Per Character Tile.
// --------------------------------------------------------------------------------------------------
// FGC  = Foreground color.  Adds this FGC value to any tile pixels whose color data is != 0.
// BGC  = Background color.  Replace tile pixels whose color data = 0 with this BGC value.
// MIR  = Mirror the tile.
// FLIP = Vertically flip the tile.
// --------------------------------------------------------------------------------------------------
//
//'CMD_vid_bpp' mode:
//
// 8   bpp -> Each byte = 1 character, 0 through 255, no color, mirror or flip functions.
//
//             BGC,  FGC,  Char 0-255.   *** BGC & FGC are multiplied by 16 in this mode.
// 16a bpp -> {4'h0, 4'h0, 8'h00 }                       = 16 bits / 256 possible tiles.
//
//             FLIP, MIR,  Char 0-16383.
// 16b bpp -> {1'b0, 1'b0, 14'h0000 }                    = 16 bits / 16384 possible tiles.
//
//              BGC,   FGC,  FLIP, MIR,  Char 0-16383.
// 32  bpp -> {8'h00, 8'h00, 1'b0, 1'b0, 14'h0000 }      = 32 bits / 16384 possible tiles.
//
//
// Remember, the contents inside a tile set's 'CMD_vid_tile_bpp' can be 1/2/4/8/16a/32/16b bpp.
// The tile set can only be as large as the reserved fixed available FPGA blockram.
// It is possible to have multiple tile layers when using the 'SDI_LAYERS' feature
// where each layer may share or have different tile sets so long as there is enough
// room in the single reserved FPGA blockram.
//
// **************************************************************************************************


// ***************************
// Logic tile input regs
// ***************************
localparam int tidl = 4 + ADDED_TILE_DATA_DLY + ADDED_TILE_ADDR_DLY;
logic [9:0]         tile_in_c_index [0:tidl]  = '{default:'0} ;
logic [4:0]         tile_in_x_index [0:tidl]  = '{default:'0} ;
logic [4:0]         tile_in_y_index [0:tidl]  = '{default:'0} ;
logic [7:0]         tile_in_c_add   [0:tidl]  = '{default:'0} ;
logic [7:0]         tile_in_c_bgc   [0:tidl]  = '{default:'0} ;
logic [20:0]        tile_in_base    [0:tidl]  = '{default:'0} ;
logic               tile_in_tena    [0:tidl]  = '{default:'0} ;
logic [2:0]         tile_in_bpp     [0:tidl]  = '{default:'0} ;
logic [3:0]         tile_in_chmult  [0:tidl]  = '{default:'0} ;
logic [2:0]         tile_in_phase   [0:tidl]  = '{default:'0} ;
logic [HC_BITS-1:0] tile_in_hc      [0:tidl]  = '{default:'0} ;
logic               tile_in_hena    [0:tidl]  = '{default:'0} ;
logic               tile_in_lena    [0:tidl]  = '{default:'0} ;
logic               tile_in_vena    [0:tidl]  = '{default:'0} ;
logic               tile_in_hs      [0:tidl]  = '{default:'0} ;
logic               tile_in_vs      [0:tidl]  = '{default:'0} ;
logic [31:0]        tile_in_data    [0:tidl]  = '{default:'0} ;

// ***************************
// Clock tile input regs
// ***************************
always_ff @(posedge VID_CLK) begin
    tile_in_c_index[0] <= lbo_dly.c_index ; // Select tile character between 8 bit and 14 bit through the SDI_LAYERS.
    tile_in_x_index[0] <= lbo_dly.x_index ; // Tile X position sequential through the SDI_LAYERS.
    tile_in_y_index[0] <= lbo_dly.y_index ; // Tile Y position sequential through the SDI_LAYERS.
    tile_in_c_add  [0] <= lbo_dly.c_add   ; // Tile color addition when using 1/2/4/8 bpp tiles, IE: Change foreground colors when using 1 bpp tiles.
    tile_in_c_bgc  [0] <= lbo_dly.c_bgc   ; // Tile background color.  IE: Color replacement for when the tile data is = 0.
    tile_in_base   [0] <= lbo_dly.t_base ; //lbo_dly.t_base  ; // Pre-add Y offset into the base address.
//    tile_in_base   [0] <= (lbo_dly.c_index<<lbo_dly.chmult) + lbo_dly.t_base ; //lbo_dly.t_base  ; // Pre-add Y offset into the base address.
    tile_in_tena   [0] <= lbo_dly.t_ena   ;
    tile_in_bpp    [0] <= lbo_dly.bpp     ;
    tile_in_chmult [0] <= lbo_dly.chmult  ; // Generate the shift amount for the character index address multiplier.
    tile_in_phase  [0] <= lbo_dly.phase   ;
    tile_in_hc     [0] <= lbo_dly.hc      ;
    tile_in_hena   [0] <= lbo_dly.hena    ;
    tile_in_lena   [0] <= lbo_dly.lena    ;
    tile_in_vena   [0] <= lbo_dly.vena    ;
    tile_in_hs     [0] <= lbo_dly.hs      ;
    tile_in_vs     [0] <= lbo_dly.vs      ;
    tile_in_data   [0] <= lbo_dly.data    ;

    for (int i=1 ; i <= tidl ; i++ ) begin // Same address generator functions for all the layers.
        tile_in_c_index[i] <= tile_in_c_index[i-1] ;
        tile_in_x_index[i] <= tile_in_x_index[i-1] ;
        tile_in_y_index[i] <= tile_in_y_index[i-1] ;
        tile_in_c_add  [i] <= tile_in_c_add  [i-1] ;
        tile_in_c_bgc  [i] <= tile_in_c_bgc  [i-1] ;
        tile_in_base   [i] <= tile_in_base   [i-1] ;
        tile_in_chmult [i] <= tile_in_chmult [i-1] ;
        tile_in_tena   [i] <= tile_in_tena   [i-1] ;
        tile_in_bpp    [i] <= tile_in_bpp    [i-1] ;
        tile_in_phase  [i] <= tile_in_phase  [i-1] ;
        tile_in_hc     [i] <= tile_in_hc     [i-1] ;
        tile_in_hena   [i] <= tile_in_hena   [i-1] ;
        tile_in_lena   [i] <= tile_in_lena   [i-1] ;
        tile_in_vena   [i] <= tile_in_vena   [i-1] ;
        tile_in_hs     [i] <= tile_in_hs     [i-1] ;
        tile_in_vs     [i] <= tile_in_vs     [i-1] ;
        tile_in_data   [i] <= tile_in_data   [i-1] ;
    end
end


logic [19:0] TILE_ADDR ; // Calculate the character's read address.

BHG_delay_pipe #(.delay(ADDED_TILE_ADDR_DLY+1),.width(20)) dl_ta1 ( .clk(VID_CLK), .in( 20'((tile_in_c_index[0]<<tile_in_chmult[0]) + tile_in_base[0]) ), .out(TILE_ADDR) );


// **********************************************************************************
// Tile/Font Dual Port Memory
// **********************************************************************************

localparam TILE_WORDS_32     = TILE_WORDS * (TILE_BITS/32) ;
localparam TILE_WORDS_32_adw = $clog2(TILE_WORDS_32)       ;

wire signed [PORT_ADDR_SIZE:0] tile_wadr = (PORT_ADDR_SIZE)'((CMD_tile_waddr-TILE_BASE_ADDR)>>TILE_CACHE_ADW) ;               // Change the input address offset to 0 and shift the 8-bit address 
wire                           TILE_WENA =                  ((tile_wadr >= 0) && (tile_wadr < TILE_WORDS) && CMD_tile_wena );  // to the TILE_BITS/8 address offset.


// Swap DDR3 write byte order.
wire [TILE_BITS-1:0]   tile_wdata;
wire [TILE_BITS/8-1:0] tile_wmask;
end_swap #(.width(TILE_BITS)) tile_end (.ind(CMD_tile_wdata),.outd(tile_wdata),.inm(CMD_tile_wmask),.outm(tile_wmask));

// **********************************************************************************
// Add adjustable write delay pipe to improve FMAX.
// **********************************************************************************
wire                   twe;
wire [TILE_ADW-1:0]    twa;
wire [TILE_BITS-1:0]   twd;
wire [TILE_BITS/8-1:0] twm;
localparam TWW = 1+TILE_ADW+TILE_BITS+(TILE_BITS/8);
BHG_delay_pipe #(.delay(OPTIMIZE_TW_FMAX),.width(TWW)) dl_twd ( .clk(CMD_CLK), .in({TILE_WENA,(TILE_ADW)'(tile_wadr),tile_wdata,tile_wmask}), .out({twe,twa,twd,twm}) );

altsyncram #(

    .intended_device_family  ( "MAX 10"        ),      .lpm_type                ( "altsyncram"    ),      .operation_mode          ( "DUAL_PORT"     ),
    .address_aclr_b          ( "NONE"          ),      .outdata_aclr_b          ( "NONE"          ),      .outdata_reg_b           ( "CLOCK1"        ),
    .clock_enable_input_a    ( "NORMAL"        ),      .clock_enable_input_b    ( "NORMAL"        ),      .clock_enable_output_b   ( "NORMAL"        ),
    .address_reg_b           ( "CLOCK1"        ),      .byte_size               ( 8               ),      .power_up_uninitialized  ( "FALSE"         ),
    
    .numwords_a              ( TILE_WORDS      ),      .widthad_a               ( TILE_ADW        ),      .width_a                 ( TILE_BITS       ),
    .width_byteena_a         ( TILE_BITS/8     ),
    
    .numwords_b              ( TILE_WORDS_32   ),      .widthad_b             ( TILE_WORDS_32_adw ),      .width_b                 ( 32              ),
    .init_file_layout        ( "PORT_B"        ),      .init_file             ("VGA_FONT_8x16_mono32.mif") // ( TILE_MIF_FILE   )  *******DAMN ALTERA STRING BUG!!!!

) TILE_MEM (

    .clock0     ( CMD_CLK                                              ),       .clocken0   ( 1'b1                                                  ),
    .wren_a     ( twe                                                  ),       .address_a  ( twa                                                   ),
    .data_a     ( twd                                                  ),       .byteena_a  ( twm                                                   ),

    .clock1     ( VID_CLK                                              ),       .clocken1   ( 1'b1                                                  ),
    .address_b  ( (TILE_WORDS_32_adw)'(TILE_ADDR)                      ),       .q_b        ( TILE_READ                                             ),

    .aclr0     (1'b0),    .aclr1        (1'b0),    .addressstall_a  (1'b0),     .addressstall_b  (1'b0),     .byteena_b (1'b1),     .clocken2 (1'b1),
    .clocken3  (1'b1),    .data_b ({32{1'b1}}),    .eccstatus       (),         .q_a (), .rden_a (1'b1),     .rden_b    (1'b1),     .wren_b   (1'b0));


// ***************************
// Generate tile output data
// ***************************

logic [4:0]  t_bpp_shift   = 0 ;
logic [2:0]  t_t_bpp       = 0 ;
logic [2:0]  t_t_bpp_dl    = 0 ;
logic [31:0] TILE_READ_dly ;

BHG_delay_pipe #(.delay(ADDED_TILE_DATA_DLY),.width(32)) dl_td1 ( .clk(VID_CLK), .in(TILE_READ), .out(TILE_READ_dly) );

always_ff @(posedge VID_CLK) begin  // Select between the tile read data and raw graphic data.

t_t_bpp       <=   tile_in_bpp[tidl-3] ; 
t_t_bpp_dl    <=   t_t_bpp ;


t_bpp_shift   <=   (   (tile_in_x_index[tidl-2]<<bpp_conv[t_t_bpp]) ^ bpp_endian[t_t_bpp] )  ; // FMAX optimizations.


if (tile_in_tena[tidl-1] && ENABLE_TILE_MODE) tile_out_data <= ( TILE_READ_dly >> t_bpp_shift ) & bpp_mask[t_t_bpp_dl] ;
else                                          tile_out_data <= tile_in_data[tidl-1];

end

assign tile_out_c_index  = tile_in_c_index [tidl] ;
assign tile_out_x_index  = tile_in_x_index [tidl] ;
assign tile_out_y_index  = tile_in_y_index [tidl] ;
assign tile_out_c_add    = tile_in_c_add   [tidl] ;
assign tile_out_c_bgc    = tile_in_c_bgc   [tidl] ;
assign tile_out_base     = tile_in_base    [tidl] ;
assign tile_out_tena     = tile_in_tena    [tidl] ;
assign tile_out_bpp      = tile_in_bpp     [tidl] ;
assign tile_out_chmult   = tile_in_chmult  [tidl] ;
assign tile_out_phase    = tile_in_phase   [tidl] ;
assign tile_out_hc       = tile_in_hc      [tidl] ;
assign tile_out_hena     = tile_in_hena    [tidl] ;
assign tile_out_lena     = tile_in_lena    [tidl] ;
assign tile_out_vena     = tile_in_vena    [tidl] ;
assign tile_out_hs       = tile_in_hs      [tidl] ;
assign tile_out_vs       = tile_in_vs      [tidl] ;

end
endgenerate


// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// *** Step 7: If PALETTE_ENABLED, use the palette look-up table when not in true-color mode.
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************
// **************************************************************************************************



// ***************************
// Logic tile input regs
// ***************************
localparam int padl = 1 + ENABLE_PALETTE ;
logic [2:0]         pal_in_bpp     [0:padl+1]  = '{default:'0} ;
logic [2:0]         pal_in_phase   [0:padl+1]  = '{default:'0} ;
logic [HC_BITS-1:0] pal_in_hc      [0:padl+1]  = '{default:'0} ;
logic               pal_in_tena    [0:padl+1]  = '{default:'0} ;
logic               pal_in_hena    [0:padl+1]  = '{default:'0} ;
logic               pal_in_lena    [0:padl+1]  = '{default:'0} ;
logic               pal_in_vena    [0:padl+1]  = '{default:'0} ;
logic               pal_in_hs      [0:padl+1]  = '{default:'0} ;
logic               pal_in_vs      [0:padl+1]  = '{default:'0} ;
logic [31:0]        pal_in_data    [0:padl+1]  = '{default:'0} ;
logic [31:0]        pal_out_data               = 0 ;
// ***************************
// Clock tile input regs
// ***************************
always_ff @(posedge VID_CLK) begin
    pal_in_bpp    [0] <= tile_out_bpp     ;
    pal_in_phase  [0] <= tile_out_phase   ;
    pal_in_hc     [0] <= tile_out_hc      ;
    pal_in_tena   [0] <= tile_out_tena    ;
    pal_in_hena   [0] <= tile_out_hena    ;
    pal_in_lena   [0] <= tile_out_lena    ;
    pal_in_vena   [0] <= tile_out_vena    ;
    pal_in_hs     [0] <= tile_out_hs      ;
    pal_in_vs     [0] <= tile_out_vs      ;
    pal_in_data   [0] <= tile_out_data    ;

    for (int i=1 ; i <= (padl+1) ; i++ ) begin // Same address generator functions for all the layers.
        pal_in_bpp    [i] <= pal_in_bpp    [i-1] ;
        pal_in_phase  [i] <= pal_in_phase  [i-1] ;
        pal_in_hc     [i] <= pal_in_hc     [i-1] ;
        pal_in_tena   [i] <= pal_in_tena   [i-1] ;
        pal_in_hena   [i] <= pal_in_hena   [i-1] ;
        pal_in_lena   [i] <= pal_in_lena   [i-1] ;
        pal_in_vena   [i] <= pal_in_vena   [i-1] ;
        pal_in_hs     [i] <= pal_in_hs     [i-1] ;
        pal_in_vs     [i] <= pal_in_vs     [i-1] ;
        pal_in_data   [i] <= pal_in_data   [i-1] ;
    end
end


logic      [31:0] PAL_READ ;


generate if (!ENABLE_PALETTE) assign PAL_READ = 0 ;
else begin
// **********************************************************************************
// Palette Dual Port Memory
// **********************************************************************************

localparam PAL_WORDS_32     = (PAL_WORDS >> PAL_ADR_SHIFT) * (PAL_BITS/32)  ;
localparam PAL_WORDS_32_adw = $clog2(PAL_WORDS_32)       ;

wire signed [PORT_ADDR_SIZE:0] pal_wadr = (PORT_ADDR_SIZE)'((CMD_pal_waddr-PAL_BASE_ADDR)>>PAL_CACHE_ADW) ; // Change the input address offset to 0 and shift the 8-bit address
wire                           PAL_WENA =                  ((pal_wadr >= 0) && (pal_wadr < (PAL_WORDS<<PAL_ADR_SHIFT))) && CMD_pal_wena ;        // to the PAL_BITS/8 address offset.

logic [10:0] PAL_ADDR  = 0 ;
always_ff @(posedge VID_CLK) PAL_ADDR <= (8)'((tile_out_data[7:0]==0) ? tile_out_c_bgc : (tile_out_data[7:0]+tile_out_c_add)) | ( tile_out_phase << 8 );



// Swap DDR3 write byte order.
wire [PAL_BITS-1:0]   pal_wdata;
wire [PAL_BITS/8-1:0] pal_wmask;
end_swap #(.width(PAL_BITS)) pal_end (.ind(CMD_pal_wdata),.outd(pal_wdata),.inm(CMD_pal_wmask),.outm(pal_wmask));


// **********************************************************************************
// Add adjustable write delay pipe to improve FMAX.
// **********************************************************************************
wire                  pwe;
wire [PAL_ADW-1:0]    pwa;
wire [PAL_BITS-1:0]   pwd;
wire [PAL_BITS/8-1:0] pwm;
localparam PWW = 1+PAL_ADW+PAL_BITS+(PAL_BITS/8);
BHG_delay_pipe #(.delay(OPTIMIZE_PW_FMAX),.width(PWW)) dl_pwd ( .clk(CMD_CLK), .in({PAL_WENA,(PAL_ADW)'(pal_wadr),pal_wdata,pal_wmask}), .out({pwe,pwa,pwd,pwm}) );

altsyncram #(

    .intended_device_family  ( "MAX 10"        ),      .lpm_type                ( "altsyncram"    ),      .operation_mode          ( "DUAL_PORT"     ),
    .address_aclr_b          ( "NONE"          ),      .outdata_aclr_b          ( "NONE"          ),      .outdata_reg_b           ( "CLOCK1"        ),
    .clock_enable_input_a    ( "NORMAL"        ),      .clock_enable_input_b    ( "NORMAL"        ),      .clock_enable_output_b   ( "NORMAL"        ),
    .address_reg_b           ( "CLOCK1"        ),      .byte_size               ( 8               ),      .power_up_uninitialized  ( "FALSE"         ),
    
    .numwords_a   ( PAL_WORDS >> PAL_ADR_SHIFT ),      .widthad_a      ( PAL_ADW  - PAL_ADR_SHIFT ),      .width_a       ( PAL_BITS >> PAL_ADR_SHIFT ),
    .width_byteena_a         ( PAL_BITS/8      ),
    
    .numwords_b              ( PAL_WORDS_32    ),      .widthad_b              ( PAL_WORDS_32_adw ),      .width_b                 ( 32              ),
    .init_file_layout        ( "PORT_B"        ),      .init_file              ("VGA_PALETTE_RGBA32.mif") // ( PAL_MIF_FILE    )  *******DAMN ALTERA STRING BUG!!!!

) PAL_MEM (

    .clock0     ( CMD_CLK                                           ),          .clocken0   ( 1'b1                                                  ),
    .wren_a     ( pwe                                               ),          .address_a  ( (PAL_ADW-PAL_ADR_SHIFT)'(pwa>>PAL_ADR_SHIFT)          ),
    .data_a     ( (PAL_BITS >> PAL_ADR_SHIFT)'(pwd)                 ),          .byteena_a  ( pwm                                                   ),

    .clock1     ( VID_CLK                                           ),          .clocken1   ( 1'b1                                                  ),
    .address_b  ( (PAL_WORDS_32_adw)'(PAL_ADDR)                     ),          .q_b        ( PAL_READ                                              ),

    .aclr0     (1'b0),    .aclr1        (1'b0),    .addressstall_a  (1'b0),     .addressstall_b  (1'b0),     .byteena_b (1'b1),     .clocken2 (1'b1),
    .clocken3  (1'b1),    .data_b ({32{1'b1}}),    .eccstatus       (),         .q_a (), .rden_a (1'b1),     .rden_b    (1'b1),     .wren_b   (1'b0));

end
endgenerate

// *******************************
// Generate palette output data
// *******************************

// Microsoft VGA 16 color palette. (Used when palette is disabled...)
localparam bit [31:0] dp4 [0:15]  = '{32'h00000000,32'h800000FF,32'h008000FF,32'h808000FF,32'h000080FF,32'h800080FF,32'h008080FF,32'hc0c0c0FF,
                                      32'h808080FF,32'hff0000FF,32'h00ff00FF,32'hffff00FF,32'h0000ffFF,32'hff00ffFF,32'h00ffffFF,32'hffffffFF};

// Microsoft Win95 256 color palette. (Used when palette is disabled...)
localparam bit [31:0] dp8 [0:255] = '{
32'h00000000,32'h800000FF,32'h008000FF,32'h808000FF,32'h000080FF,32'h800080FF,32'h008080FF,32'hc0c0c0FF,32'hc0dcc0FF,32'ha6caf0FF,32'h2a3faaFF,32'h2a3fffFF,32'h2a5f00FF,32'h2a5f55FF,32'h2a5faaFF,32'h2a5fffFF,
32'h2a7f00FF,32'h2a7f55FF,32'h2a7faaFF,32'h2a7fffFF,32'h2a9f00FF,32'h2a9f55FF,32'h2a9faaFF,32'h2a9fffFF,32'h2abf00FF,32'h2abf55FF,32'h2abfaaFF,32'h2abfffFF,32'h2adf00FF,32'h2adf55FF,32'h2adfaaFF,32'h2adfffFF,
32'h2aff00FF,32'h2aff55FF,32'h2affaaFF,32'h2affffFF,32'h550000FF,32'h550055FF,32'h5500aaFF,32'h5500ffFF,32'h551f00FF,32'h551f55FF,32'h551faaFF,32'h551fffFF,32'h553f00FF,32'h553f55FF,32'h553faaFF,32'h553fffFF,
32'h555f00FF,32'h555f55FF,32'h555faaFF,32'h555fffFF,32'h557f00FF,32'h557f55FF,32'h557faaFF,32'h557fffFF,32'h559f00FF,32'h559f55FF,32'h559faaFF,32'h559fffFF,32'h55bf00FF,32'h55bf55FF,32'h55bfaaFF,32'h55bfffFF,
32'h55df00FF,32'h55df55FF,32'h55dfaaFF,32'h55dfffFF,32'h55ff00FF,32'h55ff55FF,32'h55ffaaFF,32'h55ffffFF,32'h7f0000FF,32'h7f0055FF,32'h7f00aaFF,32'h7f00ffFF,32'h7f1f00FF,32'h7f1f55FF,32'h7f1faaFF,32'h7f1fffFF,
32'h7f3f00FF,32'h7f3f55FF,32'h7f3faaFF,32'h7f3fffFF,32'h7f5f00FF,32'h7f5f55FF,32'h7f5faaFF,32'h7f5fffFF,32'h7f7f00FF,32'h7f7f55FF,32'h7f7faaFF,32'h7f7fffFF,32'h7f9f00FF,32'h7f9f55FF,32'h7f9faaFF,32'h7f9fffFF,
32'h7fbf00FF,32'h7fbf55FF,32'h7fbfaaFF,32'h7fbfffFF,32'h7fdf00FF,32'h7fdf55FF,32'h7fdfaaFF,32'h7fdfffFF,32'h7fff00FF,32'h7fff55FF,32'h7fffaaFF,32'h7fffffFF,32'haa0000FF,32'haa0055FF,32'haa00aaFF,32'haa00ffFF,
32'haa1f00FF,32'haa1f55FF,32'haa1faaFF,32'haa1fffFF,32'haa3f00FF,32'haa3f55FF,32'haa3faaFF,32'haa3fffFF,32'haa5f00FF,32'haa5f55FF,32'haa5faaFF,32'haa5fffFF,32'haa7f00FF,32'haa7f55FF,32'haa7faaFF,32'haa7fffFF,
32'haa9f00FF,32'haa9f55FF,32'haa9faaFF,32'haa9fffFF,32'haabf00FF,32'haabf55FF,32'haabfaaFF,32'haabfffFF,32'haadf00FF,32'haadf55FF,32'haadfaaFF,32'haadfffFF,32'haaff00FF,32'haaff55FF,32'haaffaaFF,32'haaffffFF,
32'hd40000FF,32'hd40055FF,32'hd400aaFF,32'hd400ffFF,32'hd41f00FF,32'hd41f55FF,32'hd41faaFF,32'hd41fffFF,32'hd43f00FF,32'hd43f55FF,32'hd43faaFF,32'hd43fffFF,32'hd45f00FF,32'hd45f55FF,32'hd45faaFF,32'hd45fffFF,
32'hd47f00FF,32'hd47f55FF,32'hd47faaFF,32'hd47fffFF,32'hd49f00FF,32'hd49f55FF,32'hd49faaFF,32'hd49fffFF,32'hd4bf00FF,32'hd4bf55FF,32'hd4bfaaFF,32'hd4bfffFF,32'hd4df00FF,32'hd4df55FF,32'hd4dfaaFF,32'hd4dfffFF,
32'hd4ff00FF,32'hd4ff55FF,32'hd4ffaaFF,32'hd4ffffFF,32'hff0055FF,32'hff00aaFF,32'hff1f00FF,32'hff1f55FF,32'hff1faaFF,32'hff1fffFF,32'hff3f00FF,32'hff3f55FF,32'hff3faaFF,32'hff3fffFF,32'hff5f00FF,32'hff5f55FF,
32'hff5faaFF,32'hff5fffFF,32'hff7f00FF,32'hff7f55FF,32'hff7faaFF,32'hff7fffFF,32'hff9f00FF,32'hff9f55FF,32'hff9faaFF,32'hff9fffFF,32'hffbf00FF,32'hffbf55FF,32'hffbfaaFF,32'hffbfffFF,32'hffdf00FF,32'hffdf55FF,
32'hffdfaaFF,32'hffdfffFF,32'hffff55FF,32'hffffaaFF,32'hccccffFF,32'hffccffFF,32'h33ffffFF,32'h66ffffFF,32'h99ffffFF,32'hccffffFF,32'h007f00FF,32'h007f55FF,32'h007faaFF,32'h007fffFF,32'h009f00FF,32'h009f55FF,
32'h009faaFF,32'h009fffFF,32'h00bf00FF,32'h00bf55FF,32'h00bfaaFF,32'h00bfffFF,32'h00df00FF,32'h00df55FF,32'h00dfaaFF,32'h00dfffFF,32'h00ff55FF,32'h00ffaaFF,32'h2a0000FF,32'h2a0055FF,32'h2a00aaFF,32'h2a00ffFF,
32'h2a1f00FF,32'h2a1f55FF,32'h2a1faaFF,32'h2a1fffFF,32'h2a3f00FF,32'h2a3f55FF,32'hfffbf0FF,32'ha0a0a4FF,32'h808080FF,32'hff0000FF,32'h00ff00FF,32'hffff00FF,32'h0000ffFF,32'hff00ffFF,32'h00ffffFF,32'hffffffFF };

logic       alpha656  = 0 ;
wire  [7:0] red_16b   = {pal_in_data[padl][15:11],pal_in_data[padl][15:13]};
wire  [7:0] green_16b = {pal_in_data[padl][10: 5],pal_in_data[padl][10: 9]};
wire  [7:0] blue_16b  = {pal_in_data[padl][ 4: 0],pal_in_data[padl][ 4: 2]};    

//wire  [7:0] dp8_r     = {pal_in_data[padl][ 1: 0],pal_in_data[padl][ 7: 6],pal_in_data[padl][ 7: 6],pal_in_data[padl][ 7: 6]};
//wire  [7:0] dp8_g     = {pal_in_data[padl][ 1: 0],pal_in_data[padl][ 5: 4],pal_in_data[padl][ 5: 4],pal_in_data[padl][ 5: 4]};
//wire  [7:0] dp8_b     = {pal_in_data[padl][ 1: 0],pal_in_data[padl][ 3: 2],pal_in_data[padl][ 3: 2],pal_in_data[padl][ 3: 2]};

wire  [7:0] dp2       = {4{pal_in_data[padl][1:0]}};

wire  [7:0] dp1       = {8{pal_in_data[padl][0]}};


always_ff @(posedge VID_CLK) begin

        vid_alpha_adj <= CMD_win_alpha_adj[pal_in_phase[padl]] ; // Interleave the correct alpha control into the sequential layers.


        VENA     <=  pal_in_hena[padl] && pal_in_vena[padl] ; // Render a Video Enable output for DVI/HDMI transmitters.
        alpha656 <= (pal_in_data[padl-1][15:0] != 0)        ; // Make a transparency flag for bpp mode 16b, making anything other than color 0 non-transparent.
                                                              // calculated 1 clock early to increase the speed of the mux selection below.
        //WLENA    <= pal_in_lena[padl]                       ; // High during an active video window layer.

             if (!pal_in_lena[padl]) pal_out_data <= 32'd0    ;       // Mute output video
        else if ( pal_in_bpp[padl] <  4) begin
                                       if (ENABLE_PALETTE) begin                // Swap the palette data's endian
                                       pal_out_data[31:24] <= PAL_READ[24+:8] ;
                                       pal_out_data[23:16] <= PAL_READ[16+:8] ;
                                       pal_out_data[15: 8] <= PAL_READ[ 8+:8] ;
                                       pal_out_data[ 7: 0] <= PAL_READ[ 0+:8] ;
                                       end else if (pal_in_bpp[padl]==3) begin               // Use dummy palette
                                       pal_out_data[31: 0] <= dp8[pal_in_data[padl][7:0]] ;
                                       end else if (pal_in_bpp[padl]==2) begin
                                       pal_out_data[31: 0] <= dp4[pal_in_data[padl][3:0]] ;  // Use dummy palette
                                       end else if (pal_in_bpp[padl]==1) begin
                                       pal_out_data[31:24] <= dp2  ;  // Use dummy palette
                                       pal_out_data[23:16] <= dp2  ;
                                       pal_out_data[15: 8] <= dp2  ;
                                       pal_out_data[ 7: 0] <= (dp2!=0) ? 8'd255 : 8'd0 ; // Set alpha translucency.
                                       end else begin
                                       pal_out_data[31:24] <= dp1  ;  // Use dummy palette
                                       pal_out_data[23:16] <= dp1  ;
                                       pal_out_data[15: 8] <= dp1  ;
                                       pal_out_data[ 7: 0] <= dp1  ; // Set alpha translucency.
                                       end

    end else if ( pal_in_bpp[padl] == 4) begin                            // Display bpp depth is 16a, RGBA 4444 truecolor.

                                       pal_out_data[31:24] <= {pal_in_data[padl][15:12],pal_in_data[padl][15:12]};
                                       pal_out_data[23:16] <= {pal_in_data[padl][11: 8],pal_in_data[padl][11:08]};
                                       pal_out_data[15: 8] <= {pal_in_data[padl][ 7: 4],pal_in_data[padl][ 7: 4]};
                                       pal_out_data[ 7: 0] <= {pal_in_data[padl][ 3: 0],pal_in_data[padl][ 3: 0]};

    end else if ( pal_in_bpp[padl] == 6) begin                            // Display bpp depth is 16b, RGB  565  truecolor.

                                       pal_out_data[31:24] <= red_16b   ; 
                                       pal_out_data[23:16] <= green_16b ;
                                       pal_out_data[15: 8] <= blue_16b  ;
                                       pal_out_data[ 7: 0] <= alpha656 ? 8'd255 : 8'd0 ; // Set alpha translucency.

    end else                           pal_out_data        <=  pal_in_data[padl] ; // Display is using 32bit bpp true-color.

end

wire [2:0]         pal_out_bpp      = pal_in_bpp     [padl+1] ;
wire [2:0]         pal_out_phase    = pal_in_phase   [padl+1] ;
wire [HC_BITS-1:0] pal_out_hc       = pal_in_hc      [padl+1] ;
wire               pal_out_hena     = pal_in_hena    [padl+1] ;
wire               pal_out_lena     = pal_in_lena    [padl+1] ;
wire               pal_out_vena     = pal_in_vena    [padl+1] ;
wire               pal_out_hs       = pal_in_hs      [padl+1] ;
wire               pal_out_vs       = pal_in_vs      [padl+1] ;

// *******************************
// Assign outputs
// *******************************
assign VCLK_PHASE_OUT = pal_out_phase ;
assign hc_out         = pal_out_hc    ;
assign H_ena_out      = pal_out_hena  ;
assign V_ena_out      = pal_out_vena  ;
assign HS_out         = pal_out_hs    ;
assign VS_out         = pal_out_vs    ;
assign RGBA           = pal_out_data  ;
assign WLENA          = pal_out_lena  ;

endmodule


// *******************************
// *******************************
// *******************************
// Tiny endian swapper.
// *******************************
// *******************************
// *******************************
module end_swap #(parameter int width = 128)(input [width-1:0] ind, input [width/8-1:0] inm, output logic [width-1:0] outd, output logic [width/8-1:0] outm);
always_comb begin
for (int i=0 ; i<(width/8); i++) begin 
    outd[(i^2'd3)*8+:8] = ind[(width/8-1-i)*8+:8] ;
    outm[(i^2'd3)]      = inm[(width/8-1-i)]      ;
end
end
endmodule

// ************************************************
// ************************************************
// ************************************************
// Adjustable pipeline delay from 0 and up.
// ************************************************
// ************************************************
// ************************************************
module BHG_delay_pipe #(parameter delay = 0,parameter width = 1) (input clk,input [width:1] in,output [width:1] out) ;

// if delay is set to 0, skip the programmable clock delay.
generate if (delay==0) assign out=in;
else begin
            // Generate a programmable clock delay.
            logic [width:1] dreg [1:delay]  = '{default:'0} ;
            always_ff @(posedge clk) begin
                                                                  dreg[delay] <= in ;
                                     for (int i=delay ; i>1; i--) dreg[i-1]   <= dreg[i] ;
                                     end
                assign out = dreg[1] ;
            end
endgenerate
endmodule
