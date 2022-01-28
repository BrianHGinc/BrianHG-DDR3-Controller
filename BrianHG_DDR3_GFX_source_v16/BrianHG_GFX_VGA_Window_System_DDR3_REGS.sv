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
module BrianHG_GFX_VGA_Window_System_DDR3_REGS #(

parameter int        HWREG_BASE_ADDRESS       = 32'h00000100,             // The first address where the HW REG controls are located for window layer 0
parameter int        HWREG_BASE_ADDR_LSWAP    = 32'h000000F0,             // The first address where the 16 byte control to swap the SDI & PDI layer order.
parameter string     ENDIAN                   = "Little",                 // Enter "Little" or "Big".  Used for selecting the Endian in tile mode when addressing 16k tiles.

parameter bit [1:0]  OPTIMIZE_TW_FMAX         = 1,                        // Adds a D-Latch buffer for writing to the tile memory when dealing with huge TILE mem sizes.
parameter bit [1:0]  OPTIMIZE_PW_FMAX         = 1,                        // Adds a D-Latch buffer for writing to the tile memory when dealing with huge palette mem sizes.

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

output                                 CMD_VID_hena             , // Horizontal Video Enable in the CMD_CLK domain.
output                                 CMD_VID_vena             , // Vertical   Video Enable in the CMD_CLK domain.

// **********************************************************************
// **** Video clock domain and output timing from BrianHG_GFX_Sync_Gen.sv
// **********************************************************************
input                               VID_RST                              , // Video output pixel clock's reset.
input                               VID_CLK                              , // Reference PLL clock.
input                               VID_CLK_2x                           , // Reference PLL clock.
output                              PIXEL_CLK                            , // Pixel output clock.
output       [31:0]                 RGBA                                 , // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend
output                              VENA_out                             , // High during active video.
output                              HS_out                               , // Horizontal sync output.
output                              VS_out                                 // Vertical sync output.
);


logic               CMD_win_enable         [0:LAYERS-1];
logic [2:0]         CMD_win_bpp            [0:LAYERS-1];
logic [31:0]        CMD_win_base_addr      [0:LAYERS-1];
logic [HC_BITS-1:0] CMD_win_bitmap_width   [0:LAYERS-1];
logic [HC_BITS-1:0] CMD_win_bitmap_x_pos   [0:LAYERS-1];
logic [VC_BITS-1:0] CMD_win_bitmap_y_pos   [0:LAYERS-1];
logic [HC_BITS-1:0] CMD_win_x_offset       [0:LAYERS-1];
logic [VC_BITS-1:0] CMD_win_y_offset       [0:LAYERS-1];
logic [HC_BITS-1:0] CMD_win_x_size         [0:LAYERS-1];
logic [VC_BITS-1:0] CMD_win_y_size         [0:LAYERS-1];
logic [3:0]         CMD_win_scale_width    [0:LAYERS-1];
logic [3:0]         CMD_win_scale_height   [0:LAYERS-1];
logic [3:0]         CMD_win_scale_h_begin  [0:LAYERS-1];
logic [3:0]         CMD_win_scale_v_begin  [0:LAYERS-1];
logic               CMD_win_tile_enable    [0:LAYERS-1];
logic [2:0]         CMD_win_tile_bpp       [0:LAYERS-1];
logic [15:0]        CMD_win_tile_base      [0:LAYERS-1];
logic [1:0]         CMD_win_tile_width     [0:LAYERS-1];
logic [1:0]         CMD_win_tile_height    [0:LAYERS-1];

logic [23:0]        CMD_BGC_RGB                        ; // Global system 24 bit background  color for where no active window exists,
                                                         // or any pixels where all the layers are transparent all the way down right through the bottom layer.
logic [7:0]         CMD_win_alpha_adj      [0:LAYERS-1];

// *** Yes, the SDI & PDI swap positions are intentionally reversed as this is a grand crossbar 'X' swapper.
logic [7:0]         CMD_SDI_layer_swap [0:PDI_LAYERS-1]; // Re-position the SDI layer order of each PDI layer line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
logic [7:0]         CMD_PDI_layer_swap [0:SDI_LAYERS-1]; // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 

logic [2:0]         CLK_DIVIDER ; // Supports 0 through 7 to divide the clock from 1 through 8.
                                  // Also cannot be higher than SDI_LAYERS and only SDI layers 0 through this number will be shown.

logic [2:0]         VIDEO_MODE  ; // Supports 480p, 480px2, 480px4, 480px8, 720p, 720px2, 1280x1024, 1280x1024x2, 1080p, 1080px2.
                                  // x2,x4,x8 requires the PLL clock and divider to be set accordingly,
                                  // otherwise the scan rate will be divided by that factor.


localparam HW_REGS_SIZE=10; // was 10 for 16 windows.
wire  [7:0]  hw_reg8 [0:2**HW_REGS_SIZE-1] ;
wire  [15:0] hw_reg16[0:2**HW_REGS_SIZE-1] ;
wire  [31:0] hw_reg32[0:2**HW_REGS_SIZE-1] ;

HW_Regs #(

    .ENDIAN             (ENDIAN          ), // Enter "B****" for Big Endian, anything else for Little Endian.
    .PORT_ADDR_SIZE     (PORT_ADDR_SIZE  ), // This parameter is passed by the top module
    .PORT_CACHE_BITS    (PORT_CACHE_BITS ), // This parameter is passed by the top module
    .BASE_WRITE_ADDRESS (32'h00000000    ), // Where the HW_REGS are held in RAM
    .HW_REGS_SIZE       (HW_REGS_SIZE    ), // 2^12 = 4096 bytes
    .RST_8_PARAM_SIZE   (29),//41              ), // Number of default values
    .RST16_PARAM_SIZE   (8               ), // Number of default values
    .RST32_PARAM_SIZE   (1               ), // Number of default values

    .RESET_VALUES_8     ('{  {HWREG_BASE_ADDRESS+16'h001F, 8'b01000000},      // VIDEO_MODE & Clock divider, 1080p / divide by 1.
                             {HWREG_BASE_ADDRESS+16'h001A, 8'h00      },      // Global system 24 bit color background color RED
                             {HWREG_BASE_ADDRESS+16'h001B, 8'h00      },      // Global system 24 bit color background color GREEN
                             {HWREG_BASE_ADDRESS+16'h001C, 8'h00      },      // Global system 24 bit color background color BLUE

                             {HWREG_BASE_ADDR_LSWAP+8'h00, 8'h00      },      // On PDI_layer 0 output, do not swap the sequential order of the the SDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h01, 8'h00      },      // On PDI_layer 1 output, do not swap the sequential order of the the SDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h02, 8'h00      },      // On PDI_layer 2 output, do not swap the sequential order of the the SDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h03, 8'h00      },      // On PDI_layer 3 output, do not swap the sequential order of the the SDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h04, 8'h00      },      // On PDI_layer 4 output, do not swap the sequential order of the the SDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h05, 8'h00      },      // On PDI_layer 5 output, do not swap the sequential order of the the SDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h06, 8'h00      },      // On PDI_layer 6 output, do not swap the sequential order of the the SDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h07, 8'h00      },      // On PDI_layer 7 output, do not swap the sequential order of the the SDI_layers.

                             {HWREG_BASE_ADDR_LSWAP+8'h08, 8'h00      },      // During SDI_layer phase 0, do not swap around any of the the PDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h09, 8'h00      },      // During SDI_layer phase 1, do not swap around any of the the PDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h0A, 8'h00      },      // During SDI_layer phase 2, do not swap around any of the the PDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h0B, 8'h00      },      // During SDI_layer phase 3, do not swap around any of the the PDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h0C, 8'h00      },      // During SDI_layer phase 4, do not swap around any of the the PDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h0D, 8'h00      },      // During SDI_layer phase 5, do not swap around any of the the PDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h0E, 8'h00      },      // During SDI_layer phase 6, do not swap around any of the the PDI_layers.
                             {HWREG_BASE_ADDR_LSWAP+8'h0F, 8'h00      },      // During SDI_layer phase 7, do not swap around any of the the PDI_layers.

                             {HWREG_BASE_ADDRESS+16'h0004, 8'b10000101},      // Window[0] Screen bpp     = 5 and enabled.
                             {HWREG_BASE_ADDRESS+16'h0005, 8'h7F      },      // Window[0] alpha adjust   = 100% Opaque.  *** 8 bit SIGNED value from +127 to -128.
                             {HWREG_BASE_ADDRESS+16'h0014, 8'h00      },      // Window[0] Scale width
                             {HWREG_BASE_ADDRESS+16'h0015, 8'h00      },      // Window[0] Scale height
                             {HWREG_BASE_ADDRESS+16'h0018, 8'b00000000},      // Window[0] Tile = Disabled, 1 bpp font.
                             {HWREG_BASE_ADDRESS+16'h0019, 8'b00010010},      // Window[0] Tile Width X Height, 8 X 16.

                             {HWREG_BASE_ADDRESS+16'h0024, 8'b00000000},      // Window[1]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h0044, 8'b00000000},      // Window[2]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h0064, 8'b00000000}   }),//,      // Window[3]  Screen bpp     = 0 and disabled.
/*                             {HWREG_BASE_ADDRESS+16'h0084, 8'b00000000},      // Window[4]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h00A4, 8'b00000000},      // Window[5]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h00C4, 8'b00000000},      // Window[6]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h00E4, 8'b00000000},      // Window[7]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h0104, 8'b00000000},      // Window[8]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h0124, 8'b00000000},      // Window[9]  Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h0144, 8'b00000000},      // Window[10] Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h0164, 8'b00000000},      // Window[11] Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h0184, 8'b00000000},      // Window[12] Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h01A4, 8'b00000000},      // Window[13] Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h01C4, 8'b00000000},      // Window[14] Screen bpp     = 0 and disabled.
                             {HWREG_BASE_ADDRESS+16'h01E4, 8'b00000000}    }),// Window[15] Screen bpp     = 0 and disabled.
*/

    .RESET_VALUES16     ('{  {HWREG_BASE_ADDRESS+16'h0006, 16'd2048},         // Window[0] Bitmap width
                             {HWREG_BASE_ADDRESS+16'h0008, 16'd0   },         // Window[0] Bitmap X pos offset.
                             {HWREG_BASE_ADDRESS+16'h000A, 16'd0   },         // Window[0] Bitmap Y pos offset.
                             {HWREG_BASE_ADDRESS+16'h000C, 16'd0   },         // Window[0] window X pos.
                             {HWREG_BASE_ADDRESS+16'h000E, 16'd0   },         // Window[0] window Y pos.
                             {HWREG_BASE_ADDRESS+16'h0010, 16'd1920},         // Window[0] Window width.
                             {HWREG_BASE_ADDRESS+16'h0012, 16'd1080},         // Window[0] Window height.
                             {HWREG_BASE_ADDRESS+16'h0016, 16'h0000}      }), // Window[0] Tile/font base address

    .RESET_VALUES32     ('{  {HWREG_BASE_ADDRESS+16'h0000, 32'h00000000}  })  // Window[0] base DDR3 address

) BHG_VGA_HWREGS (
    .RESET         ( CMD_RST      ),    .CLK           ( CMD_CLK      ),
    .WE            ( TAP_wena     ),    .ADDR_IN       ( TAP_waddr    ),
    .DATA_IN       ( TAP_wdata    ),    .WMASK         ( TAP_wmask    ),
    .HW_REGS__8bit ( hw_reg8      ),    .HW_REGS_16bit ( hw_reg16     ),
    .HW_REGS_32bit ( hw_reg32     ) );


localparam int win_len = 8'h20 ;                                                      // Length of bytes between each new window layer.
always_comb begin                                                                     // Also, don't forget everything is offset by the HWREG_BASE_ADDRESS parameter.
  for (int x=0;x<LAYERS;x++) begin
    CMD_win_base_addr      [x] = hw_reg32[HWREG_BASE_ADDRESS+(x*win_len)+8'h00]     ; // The beginning DDR3 memory address for the window.  Align to every 32 bytes.

    CMD_win_enable         [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h04][7]  ; // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
    CMD_win_bpp            [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h04][2:0]; // Bits per pixel.  Use (0,1,2,3,4,5,6) for (1,2,4,8,16a,32,16b) bpp, *16a bpp=4444 RGBA, 16b bpp=565 RGB.

    CMD_win_alpha_adj      [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h05]     ; // 0=translucency will be determined by the graphic data, 127=100% opaque, -128=100% transparent.

    CMD_win_bitmap_width   [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h06]     ; // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.  Align to every 4 bytes.
    CMD_win_bitmap_x_pos   [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h08]     ; // The beginning X pixel position inside the bitmap in memory.  IE: Scroll left on a huge bitmap.
    CMD_win_bitmap_y_pos   [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h0A]     ; // The beginning Y line position inside the bitmap in memory.   IE: Scroll down on a huge bitmap.

    CMD_win_x_offset       [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h0C]     ; // The onscreen X position of the window.
    CMD_win_y_offset       [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h0E]     ; // The onscreen Y position of the window.
    CMD_win_x_size         [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h10]     ; // The onscreen display width of the window.      *** Using 0 will disable the window.
    CMD_win_y_size         [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h12]     ; // The onscreen display height of the window.     *** Using 0 will disable the window.

    CMD_win_scale_width    [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h14][3:0]; // Pixel horizontal zoom width.  Use 0 thru 15 for 1x through 16x size.
    CMD_win_scale_h_begin  [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h14][7:4]; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
    CMD_win_scale_height   [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h15][3:0]; // Pixel vertical zoom height.   Use 0 thru 15 for 1x through 16x size.
    CMD_win_scale_v_begin  [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h15][7:4]; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.

    CMD_win_tile_base      [x] = hw_reg16[HWREG_BASE_ADDRESS+(x*win_len)+8'h16]     ; // Base address (multiplied by) X 16 bytes of where the windows font begins.  ***NOT counting the TILE_BASE_ADDR when writing into the DDR3.
    CMD_win_tile_enable    [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h18][7]  ; // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
    CMD_win_tile_bpp       [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h18][2:0]; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
    CMD_win_tile_width     [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h19][5:4]; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32 pixels.
    CMD_win_tile_height    [x] = hw_reg8 [HWREG_BASE_ADDRESS+(x*win_len)+8'h19][1:0]; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32 pixels.
  end // for x


CMD_BGC_RGB[23:16] = hw_reg8[HWREG_BASE_ADDRESS+16'h001A]     ; // Global system 24 bit color background color for where no active window exists,
CMD_BGC_RGB[15: 8] = hw_reg8[HWREG_BASE_ADDRESS+16'h001B]     ; // or any pixels where all the layers are transparent all the way through the bottom layer.
CMD_BGC_RGB[ 7: 0] = hw_reg8[HWREG_BASE_ADDRESS+16'h001C]     ; // 

VIDEO_MODE  = hw_reg8[HWREG_BASE_ADDRESS+16'h001F][6:4]; // 1 special address for changing the global VIDEO_MODE.
CLK_DIVIDER = hw_reg8[HWREG_BASE_ADDRESS+16'h001F][2:0]; // 1 special address for changing the global CLK_DIVIDER.

// *** Yes, the SDI & PDI swap positions are intentionally reversed as this is a grand crossbar 'X' swapper.
for (int x=0;x<PDI_LAYERS;x++) CMD_SDI_layer_swap[x] = hw_reg8[HWREG_BASE_ADDR_LSWAP+x+0];
for (int x=0;x<SDI_LAYERS;x++) CMD_PDI_layer_swap[x] = hw_reg8[HWREG_BASE_ADDR_LSWAP+x+8];

end // _comb


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
//.TILE_MIF_FILE         ( TILE_MIF_FILE         ),
.ENABLE_PALETTE        ( ENABLE_PALETTE        ),
.SKIP_PALETTE_DELAY    ( SKIP_PALETTE_DELAY    ),
.PAL_BITS              ( PAL_BITS              ),
.PAL_BASE_ADDR         ( PAL_BASE_ADDR         ),
.PAL_WORDS             ( PAL_WORDS             ),
.PAL_ADR_SHIFT         ( PAL_ADR_SHIFT         ),
//.PAL_MIF_FILE          ( PAL_MIF_FILE          ),
.OPTIMIZE_TW_FMAX      ( OPTIMIZE_TW_FMAX      ),
.OPTIMIZE_PW_FMAX      ( OPTIMIZE_PW_FMAX      )

) BHG_VGASYS (

.CMD_RST                ( CMD_RST                 ), // CMD section reset.
.CMD_CLK                ( CMD_CLK                 ), // System CMD RAM clock.
.CMD_DDR3_ready         ( CMD_DDR3_ready          ), // Enables display and DDR3 reading of data.

.CMD_win_enable         ( CMD_win_enable          ), // Enable the window layer. 
.CMD_win_bpp            ( CMD_win_bpp             ), // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_win_base_addr      ( CMD_win_base_addr       ), // The beginning memory address for the window.
.CMD_win_bitmap_width   ( CMD_win_bitmap_width    ), // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.
.CMD_win_bitmap_x_pos   ( CMD_win_bitmap_x_pos    ), // The beginning X pixel position inside the bitmap in memory.
.CMD_win_bitmap_y_pos   ( CMD_win_bitmap_y_pos    ), // The beginning Y line position inside the bitmap in memory.
.CMD_win_x_offset       ( CMD_win_x_offset        ), // The onscreen X position of the window.
.CMD_win_y_offset       ( CMD_win_y_offset        ), // The onscreen Y position of the window.
.CMD_win_x_size         ( CMD_win_x_size          ), // The onscreen display width of the window.      *** Using 0 will disable the window.
.CMD_win_y_size         ( CMD_win_y_size          ), // The onscreen display height of the window.     *** Using 0 will disable the window.
.CMD_win_scale_width    ( CMD_win_scale_width     ), // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
.CMD_win_scale_height   ( CMD_win_scale_height    ), // Pixel vertical zoom height.   For 1x,2x,3x thru 16x, use 0,1,2 thru 15.
.CMD_win_scale_h_begin  ( CMD_win_scale_h_begin   ), // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
.CMD_win_scale_v_begin  ( CMD_win_scale_v_begin   ), // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
.CMD_win_tile_enable    ( CMD_win_tile_enable     ), // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
.CMD_win_tile_base      ( CMD_win_tile_base       ), // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
.CMD_win_tile_bpp       ( CMD_win_tile_bpp        ), // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_win_tile_width     ( CMD_win_tile_width      ), // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
.CMD_win_tile_height    ( CMD_win_tile_height     ), // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
.CMD_win_alpha_adj      ( CMD_win_alpha_adj       ), // When 0, the layer translucency will be determined by the graphic data.

.CMD_BGC_RGB            ( CMD_BGC_RGB             ), // Bottom background color when every layer's pixel happens to be transparent. 
.CMD_SDI_layer_swap     ( CMD_SDI_layer_swap      ), // Re-position the SDI layer order of each PDI layer line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
.CMD_PDI_layer_swap     ( CMD_PDI_layer_swap      ), // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 

.CMD_VID_hena           ( CMD_VID_hena            ), // Horizontal Video Enable in the CMD_CLK domain.
.CMD_VID_vena           ( CMD_VID_vena            ), // Vertical   Video Enable in the CMD_CLK domain.

.CMD_busy               ( CMD_busy                ), // Only send out commands when DDR3 is not busy.
.CMD_ena                ( CMD_ena                 ), // Transmit a DDR3 command.
.CMD_write_ena          ( CMD_write_ena           ), // Send a write data command. *** Not in use.
.CMD_wdata              ( CMD_wdata               ), // Write data.                *** Not in use.
.CMD_wmask              ( CMD_wmask               ), // Write mask.                *** Not in use.
.CMD_addr               ( CMD_addr                ), // DDR3 memory address in byte form.
.CMD_read_vector_tx     ( CMD_read_vector_tx      ), // Contains the destination line buffer address.  ***_tx to avoid confusion, IE: Send this port to the DDR3's read vector input.
.CMD_priority_boost     ( CMD_priority_boost      ), // Boost the read command above everything else including DDR3 refresh. *** Not in use.
.CMD_read_ready         ( CMD_read_ready          ),
.CMD_rdata              ( CMD_rdata               ), 
.CMD_read_vector_rx     ( CMD_read_vector_rx      ), // Contains the destination line buffer address.  ***_rx to avoid confusion, IE: the DDR3's read vector results drives this port.
.TAP_wena               ( TAP_wena                ),
.TAP_waddr              ( TAP_waddr               ),
.TAP_wdata              ( TAP_wdata               ),
.TAP_wmask              ( TAP_wmask               ),

.VID_RST                ( VID_RST                 ), // Video output pixel clock's reset.
.VID_CLK                ( VID_CLK                 ), // Reference PLL clock.
.VID_CLK_2x             ( VID_CLK_2x              ), // Reference PLL clock.
.CLK_DIVIDER            ( CLK_DIVIDER             ), // Supports 0 through 7 to divide the clock from 1 through 8.
.VIDEO_MODE             ( VIDEO_MODE              ), // See source code for mode list.
.PIXEL_CLK              ( PIXEL_CLK               ), // Pixel output clock.
.RGBA                   ( RGBA                    ), // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend
.VENA_out               ( VENA_out                ), // High during active video.
.HS_out                 ( HS_out                  ), // Horizontal sync output.
.VS_out                 ( VS_out                  )  // Vertical sync output.
);

endmodule
