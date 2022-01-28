// *****************************************************************
// A BrianHG_GFX_Window_DDR3_Reader_tb test-bench.
// v1.6, December 6, 2021
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.


module BrianHG_GFX_Window_DDR3_Reader_tb #(

parameter int        PORT_ADDR_SIZE      = 24 ,            // Must match PORT_ADDR_SIZE.
parameter int        PORT_VECTOR_SIZE    = 11 ,            // Must match PORT_VECTOR_SIZE and be at least large enough for the video line pointer + line buffer module ID.
parameter int        PORT_CACHE_BITS     = 128,            // Must match PORT_R/W_DATA_WIDTH and be PORT_CACHE_BITS wide for optimum speed.
parameter            HC_BITS             = 16,             // Width of horizontal counter.
parameter            VC_BITS             = 16,             // Width of vertical counter.
parameter bit [3:0]  PDI_LAYERS          = 1,              // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
parameter bit [3:0]  SDI_LAYERS          = 1,              // Use 1,2,4, or 8 sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system.

parameter int        LBUF_BITS           = PORT_CACHE_BITS,            // The bit width of the CMD_line_buf_wdata
parameter int        LBUF_WORDS          = 64,//256,                        // The total number of 'CMD_line_buf_wdata' words of memory.
                                                                       // Anything less than 256 will still use the same minimum M9K/M10K blocks.
                                                                       // Only use factors of 2, IE: 256/512/1024...
parameter bit [9:0]  MAX_BURST           = LBUF_WORDS/4/SDI_LAYERS,    // Generic maximum burst length.  IE: A burst will not be called unless this many free words exist inside the line buffer memory.
parameter bit [9:0]  MAX_BURST_1st       = (MAX_BURST/4),              // In a multi-window system, this defines the maximum read burst size per window after the H-reset period
                                                                       // allowing all the window buffers to gain a minimal amount of graphic data before running full length bursts.

// ******* Do not edit these ****
parameter bit [6:0]  LAYERS              = PDI_LAYERS * SDI_LAYERS     // Total window layers in system
)(
output logic                        CLK_IN             ,
output logic                        reset              ,
output logic [2:0]                  CLK_DIVIDE_IN      ,         // Set a pixel clock divider, use 0 through 7 to divide the clock 1 through 8.
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
localparam      endtime     = STOP_uS * 500;


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
.H_ena              ( H_ena              ),
.V_ena              ( V_ena              ),
.Video_ena          ( Video_ena          ),
.HS_out             ( HS_out             ),
.VS_out             ( VS_out             ),
.CLK_PHASE_OUT      ( CLK_PHASE_OUT      ),
.h_count_out        ( h_count_out        ),
.v_count_out        ( v_count_out        ) );


logic                         CMD_DDR3_ready ;
logic                         CMD_win_enable         [0:LAYERS-1] ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
logic [2:0]                   CMD_win_bpp            [0:LAYERS-1] ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
logic [31:0]                  CMD_win_base_addr      [0:LAYERS-1] ; // The beginning memory address for the window.
logic [HC_BITS-1:0]           CMD_win_bitmap_width   [0:LAYERS-1] ; // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.
logic [HC_BITS-1:0]           CMD_win_bitmap_x_pos   [0:LAYERS-1] ; // The beginning X pixel position inside the bitmap in memory.
logic [VC_BITS-1:0]           CMD_win_bitmap_y_pos   [0:LAYERS-1] ; // The beginning Y line position inside the bitmap in memory.
logic [HC_BITS-1:0]           CMD_win_x_offset       [0:LAYERS-1] ; // The onscreen X position of the window.
logic [VC_BITS-1:0]           CMD_win_y_offset       [0:LAYERS-1] ; // The onscreen Y position of the window.
logic [HC_BITS-1:0]           CMD_win_x_size         [0:LAYERS-1] ; // The onscreen display width of the window.      *** Using 0 will disable the window.
logic [VC_BITS-1:0]           CMD_win_y_size         [0:LAYERS-1] ; // The onscreen display height of the window.     *** Using 0 will disable the window.
logic [3:0]                   CMD_win_scale_width    [0:LAYERS-1] ; // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
logic [3:0]                   CMD_win_scale_height   [0:LAYERS-1] ; // Pixel vertical zoom height.   For 1x,2x,3x thru 16x, use 0,1,2 thru 15.
logic [3:0]                   CMD_win_scale_h_begin  [0:LAYERS-1] ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
logic [3:0]                   CMD_win_scale_v_begin  [0:LAYERS-1] ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
logic [7:0]                   CMD_win_alpha_override [0:LAYERS-1] ; // When 0, the layer translucency will be determined by the graphic data.
logic                         CMD_win_tile_enable    [0:LAYERS-1] ; // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
logic [15:0]                  CMD_win_tile_base      [0:LAYERS-1] ; // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
logic [2:0]                   CMD_win_tile_bpp       [0:LAYERS-1] ; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
logic [1:0]                   CMD_win_tile_width     [0:LAYERS-1] ; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
logic [1:0]                   CMD_win_tile_height    [0:LAYERS-1] ; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32

logic                         CMD_busy                             = 0              ; // Only send out commands when DDR3 is not busy.

logic                         lb_stat_hrst                         = 0              ; // Strobes for 1 clock when the end of the display line has been reached.
logic                         lb_stat_vena                         = 0              ; // High during the active lines of the display frame.
logic                         lb_stat_qinc           [0:LAYERS-1]  = '{default:'0}  ; // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.


BrianHG_GFX_Window_DDR3_Reader #(

.PORT_ADDR_SIZE      ( PORT_ADDR_SIZE   ), // Must match PORT_ADDR_SIZE.
.PORT_VECTOR_SIZE    ( PORT_VECTOR_SIZE ), // Must match PORT_VECTOR_SIZE and be at least large enough for the video line pointer + line buffer module ID.
.PORT_CACHE_BITS     ( PORT_CACHE_BITS  ), // Must match PORT_R/W_DATA_WIDTH and be PORT_CACHE_BITS wide for optimum speed.
.HC_BITS             ( HC_BITS          ), // Width of horizontal counter.
.VC_BITS             ( VC_BITS          ), // Width of vertical counter.
.PDI_LAYERS          ( PDI_LAYERS       ), // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
.SDI_LAYERS          ( SDI_LAYERS       ), // Number of sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system. Only 1/2/4/8 are allowed.
.LBUF_BITS           ( LBUF_BITS        ), // The bit width of the CMD_line_buf_wdata
.LBUF_WORDS          ( LBUF_WORDS       ), // The total number of 'CMD_line_buf_wdata' words of memory.
.MAX_BURST_1st       ( MAX_BURST_1st    ), // In a multi-window system, this defines the maximum read burst size per window after the H-reset period
.MAX_BURST           ( MAX_BURST        )  // Generic maximum burst length.   

) DUT_WDR (

.CMD_RST                ( reset                  ), // CMD section reset.
.CMD_CLK                ( CLK_IN                 ), // System CMD RAM clock.
.CMD_DDR3_ready         ( CMD_DDR3_ready         ), // Enables display and DDR3 reading of data.

.CMD_win_enable         ( CMD_win_enable         ), // Enable window layer.
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

.CMD_win_alpha_override ( CMD_win_alpha_override ), // When 0, the layer translucency will be determined by the graphic data.

.CMD_win_tile_enable    ( CMD_win_tile_enable    ), // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
.CMD_win_tile_base      ( CMD_win_tile_base      ), // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
                                                    // *** This is the address inside the line buffer tile/font blockram which always begins at 0, NOT the DDR3 TAP_xxx port write address.
.CMD_win_tile_bpp       ( CMD_win_tile_bpp       ), // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_win_tile_width     ( CMD_win_tile_width     ), // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
.CMD_win_tile_height    ( CMD_win_tile_height    ), // Defines the height of the tile. 0,1,2,3 = 4,8,16,32

.CMD_busy               ( CMD_busy               ), // Only send out commands when DDR3 is not busy.
.CMD_ena                (                        ), // Transmit a DDR3 command.
.CMD_write_ena          (                        ), // Send a write data command. *** Not in use.
.CMD_wdata              (                        ), // Write data.                *** Not in use.
.CMD_wmask              (                        ), // Write mask.                *** Not in use.
.CMD_addr               (                        ), // DDR3 memory address in byte form.
.CMD_read_vector_tx     (                        ), // Contains the destination line buffer address.  ***_tx to avoid confusion, IE: Send this port to the DDR3's read vector input.
.CMD_priority_boost     (                        ), // Boost the read command above everything else including DDR3 refresh. *** Unused for now.

.lb_stat_hrst           ( lb_stat_hrst           ), // Strobes for 1 clock when the end of the display line has been reached.
.lb_stat_vena           ( lb_stat_vena           ), // High during the active lines of the display frame.
.lb_stat_qinc           ( lb_stat_qinc           ), // Pulses for 1 CMD_CLK every time the read line buffer passes every 4th LBUF_WORDS address.

.CMD_vid_ena            (                        ), // Enable the display line. 
.CMD_vid_bpp            (                        ), // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_vid_h_offset       (                        ), // The beginning display X coordinate for the video.
.CMD_vid_h_width        (                        ), // The display width of the video.      0 = Disable video layer.
.CMD_vid_pixel_width    (                        ), // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
.CMD_vid_width_begin    (                        ), // Begin the display left shifted part-way into a zoomed pixel.
.CMD_vid_x_buf_begin    (                        ), // Within the line buffer, this defines the first pixel to be shown.
.CMD_vid_alpha_override (                        ), // When 0, the layer translucency will be determined by the graphic data.
.CMD_vid_tile_enable    (                        ), // Tile mode enable.
.CMD_vid_tile_base      (                        ), // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
.CMD_vid_tile_bpp       (                        ), // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
.CMD_vid_tile_width     (                        ), // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
.CMD_vid_tile_height    (                        ), // Defines the height of the tile. 0,1,2,3 = 4,8,16,32
.CMD_vid_tile_x_begin   (                        ), // When displaying a line with tile enabled, this left shifts into the beginning of the first tile displayed.
.CMD_vid_tile_y_begin   (                        )  // When displaying a line with tile enabled, this coordinate defines the displayed tile's Y coordinate.
);



localparam   LBUF_WORDS_32     =  LBUF_WORDS * (LBUF_BITS/32) ;
localparam   LBUF_WORDS_32_adw =  $clog2(LBUF_WORDS_32)       ;
localparam   lb_ch_adw         =  $clog2(LBUF_WORDS_32 / SDI_LAYERS) ; // Set the upper address bit limit in the line buffer counter.
localparam   lb_toggle_bit     =  $clog2(LBUF_BITS/32)+5+2    ;        // +5 means the line buffer status will increment once every LBUF_WORD address, +2 means once every 4th addresses.
//localparam   lb_toggle_bit     =  lb_ch_adw + 4 - 2 ;                  // The toggle address bit at the individual channel level which tells the Window Memory Reader the FIFO line read position divided into 4 banks.
                                                                       // +4 signifies the sub-address bits used when addressing 1bpp mode, IE 32 bits = 32 pixels = 4 address bits
                                                                       // -2 signifies that we should use 2 bits below the MSB address so that this output toggles 8 times during an entire channel's
                                                                       // read buffer length instead of toggling only 1 time like what the MSB address bit would actually do.
logic        lb_stat_hrst_dl0                = 0 ;
logic        lb_stat_hrst_dl1                = 0 ;
logic        lb_stat_qinc_dl0  [0:LAYERS-1]  = '{default:'0} ; 
logic        lb_stat_qinc_dl1  [0:LAYERS-1]  = '{default:'0} ; 
logic [15:0] lbuf_addr                       = 0 ;

initial begin

// Setup a 480p output raster.
CLK_DIVIDE_IN       = SDI_LAYERS-1 ;
VID_h_total         = 858     /4     ; // = 48   ;
VID_h_res           = 720     /4     ; // = 32   ;
VID_hs_front_porch  = 16      /4     ; // = 2    ;
VID_hs_size         = 62      /4     ; // = 6    ;
VID_v_total         = 525     /4     ; // = 24   ;
VID_v_res           = 480     /4     ; // = 12   ;
VID_vs_front_porch  = 6       /4     ; // = 3    ;
VID_vs_size         = 6       /4     ; // = 3    ;
VID_hs_polarity     = 1              ; // = 1    ;
VID_vs_polarity     = 1              ; // = 1    ;

CMD_busy            = 0 ;

// Initialize the metrics for drawing a video line.
for (int i=0 ; i<LAYERS ; i++) begin

    CMD_win_enable         [i] = 1              ; // Enable window layer.
    CMD_win_bpp            [i] = 5              ; // Bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB.
    CMD_win_base_addr      [i] = 32'h00000000   ; // The beginning memory address for the window.
    CMD_win_bitmap_width   [i] = 4096           ; // The full width of the bitmap stored in memory.  If tile mode is enabled, then the number of tiles wide.
    CMD_win_bitmap_x_pos   [i] = 0              ; // The beginning X pixel position inside the bitmap in memory.
    CMD_win_bitmap_y_pos   [i] = 0              ; // The beginning Y line position inside the bitmap in memory.

    CMD_win_x_offset       [i] = 0              ; // The onscreen X position of the window.
    CMD_win_y_offset       [i] = 0              ; // The onscreen Y position of the window.
    CMD_win_x_size         [i] = 4096           ; // The onscreen display width of the window.      *** Using 0 will disable the window.
    CMD_win_y_size         [i] = 32             ; // The onscreen display height of the window.     *** Using 0 will disable the window.

    CMD_win_scale_width    [i] = 0              ; // Pixel horizontal zoom width.  For 1x,2x,3x thru 16x, use 0,1,2 thru 15.  
    CMD_win_scale_height   [i] = 0              ; // Pixel vertical zoom height.   For 1x,2x,3x thru 16x, use 0,1,2 thru 15. 
    CMD_win_scale_h_begin  [i] = 0              ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.
    CMD_win_scale_v_begin  [i] = 0              ; // Begin display part-way into a zoomed pixel for sub-pixel accurate scrolling.

    CMD_win_alpha_override [i] = 0              ; // When 0, the layer translucency will be determined by the graphic data.

    CMD_win_tile_enable    [i] = 0              ; // Enable Tile mode enable.  *** Display will be corrupt if the BrianHG_GFX_Video_Line_Buffer's ENABLE_TILE_MODE=0
    CMD_win_tile_base      [i] = 0              ; // Defines the beginning tile 16 bit base address (multiplied by) X 16 bytes for a maximum of 1 megabytes addressable tile set.
    CMD_win_tile_bpp       [i] = 0              ; // Defines the tile bits per pixel.  For 1,2,4,8,16a,32,16b bpp, use 0,1,2,3,4,5,6.  *16a bpp = 4444 RGBA, 16b bpp = 565 RGB. 
    CMD_win_tile_width     [i] = 1              ; // Defines the width of the tile.  0,1,2,3 = 4,8,16,32
    CMD_win_tile_height    [i] = 1              ; // Defines the height of the tile. 0,1,2,3 = 4,8,16,32

end

//    CMD_win_base_addr      [1] = 32'h00000100   ; // The beginning memory address for the window.

reset          = 1'b1 ; // Reset input
CLK_IN         = 1'b1 ;
CMD_DDR3_ready = 1'b0 ;

#(period); // Align to clock input.

#(50000);
reset          = 1'b0 ; // Release reset at 50ns.
CMD_DDR3_ready = 1'b1 ;
end

always #period         CLK_IN = !CLK_IN ;  // create source clock oscillator
always #(endtime)      $stop            ;  // Stop simulation from going on forever.


// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ****** Generate the line buffer read position progress to simulating the 'lb_stat_qinc[]' pulse. **********
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************

always_ff @(posedge CLK_IN) begin

// *** Channel independent flags.
    if (reset) begin
        lb_stat_vena         <= 0 ;
        lb_stat_hrst         <= 0 ;
        lb_stat_hrst_dl0     <= 0 ;
        lb_stat_hrst_dl1     <= 0 ;
        
        lbuf_addr            <= 0 ;
    end else begin
        lb_stat_hrst_dl0     <=  H_ena                                      ; // plbp_hena[0]
        lb_stat_hrst_dl1     <=  lb_stat_hrst_dl0                           ;
        lb_stat_hrst         <= !lb_stat_hrst_dl0    && lb_stat_hrst_dl1    ; // Sanitized 1 clock delay single CMD_CLK horizontal reset pulse once a display line finishes.
        lb_stat_vena         <=  V_ena                                      ; // High during the lines of active video.

        if      (lb_stat_hrst)                           lbuf_addr <=  0 ;
        else if (H_ena && V_ena && (CLK_PHASE_OUT == 0)) lbuf_addr <= lbuf_addr + (32>>(SDI_LAYERS-1)) ; // Simulate reading address increment per 32 bit pixel.

    end // !rst

// *** Channel dependent flags.
for (int i = 0 ; i < LAYERS ; i++ ) begin
    if (reset) begin
        lb_stat_qinc     [i] <= 0 ;
        lb_stat_qinc_dl0 [i] <= 0 ;
        lb_stat_qinc_dl1 [i] <= 0 ;
    end else begin
        lb_stat_qinc_dl0 [i] <=  lbuf_addr[lb_toggle_bit]                   ; // lbuf_addr[i][lb_toggle_bit] = buffered line buffer read address position, IE, once toggled means that this read address has already been sent.
        lb_stat_qinc_dl1 [i] <=  lb_stat_qinc_dl0 [i]                       ;
        lb_stat_qinc     [i] <=  (lb_stat_qinc_dl1 [i] != lb_stat_qinc_dl0 [i]) && lb_stat_hrst_dl0      ; // Sanitized output which will not accidentally trigger a read during the horizontal reset.
    end // !rst
end // for i

end // @clk



endmodule
