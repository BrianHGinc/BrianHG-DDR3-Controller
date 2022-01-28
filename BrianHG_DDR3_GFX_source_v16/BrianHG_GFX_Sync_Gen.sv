// *****************************************************************************************************
// Demo BrianHG_GFX_Sync_Gen.sv.
// IE: Generate a programmable VGA video sync generator.
//
// Version 1.6, December 5, 2021.
//
// Written by Brian Guralnick.
// For public use.
//
// Input the H total pixels per line and total V lines in the frame with the
// display H & V resolution + the polarity of HS & VS sync with their location after the active
// H & V display area to generate sync outputs with a H & V enable for the display area.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************************************************
module BrianHG_GFX_Sync_Gen #( 
parameter HC_BITS = 16,    // Width of horizontal counter.
parameter VC_BITS = 16     // Width of vertical counter.
)(
input  logic                        CLK_IN             ,
input  logic                        reset              ,
input  logic [2:0]                  CLK_DIVIDE_IN      ,         // Set a pixel clock divider, use 0 through 7 to divide the CLK_IN 1 through 8.

input  logic [HC_BITS-1:0]          VID_h_total        ,         // Total pixel clocks per line of video
input  logic [HC_BITS-1:0]          VID_h_res          ,         // Total active display pixels per line of video
input  logic [HC_BITS-1:0]          VID_hs_front_porch ,         // Front porch size before horizontal sync.
input  logic [HC_BITS-1:0]          VID_hs_size        ,         // Width of horizontal sync.
input  logic                        VID_hs_polarity    ,         // Use 0 for positive H-Sync, use 1 for negative sync.

input  logic [VC_BITS-1:0]          VID_v_total        ,         // Total lines of video per frame
input  logic [VC_BITS-1:0]          VID_v_res          ,         // Total active display lines of video per frame
input  logic [VC_BITS-1:0]          VID_vs_front_porch ,         // Front porch size before vertical sync.
input  logic [VC_BITS-1:0]          VID_vs_size        ,         // Width of vertical sync in lines of video.
input  logic                        VID_vs_polarity    ,         // Use 0 for positive V-Sync, use 1 for negative sync.

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

logic [2:0]          clk_divide = 0 ;
logic [HC_BITS-1:0]  h_count    = 0 ;
logic [VC_BITS-1:0]  v_count    = 0 ;
logic H_ena_int = 0, HS_out_int = 0 ;
logic V_ena_int = 0, VS_out_int = 0 ;


wire h_limit   = ( h_count ==  VID_h_total                                      ) ;
wire h_ena_end = ( h_count ==  VID_h_res                                        ) ;
wire hs_on     = ( h_count == (VID_h_res + VID_hs_front_porch)                  ) ;
wire hs_off    = ( h_count == (VID_h_res + VID_hs_front_porch + VID_hs_size)    ) ;

wire v_limit   = ( v_count ==  VID_v_total                                      ) ;
wire v_ena_end = ( v_count ==  VID_v_res                                        ) ;
wire vs_on     = ( v_count == (VID_v_res + VID_vs_front_porch + 1 )             ) ;
wire vs_off    = ( v_count == (VID_v_res + VID_vs_front_porch + VID_vs_size + 1 ) ) ;

// **********************************************************************************
// 
// **********************************************************************************
always_ff @(posedge CLK_IN) begin 

if (reset) begin              // RST_OUT is clocked on the CMD_CLK source.

    CLK_PHASE_OUT  <= 0 ;
    clk_divide     <= 0 ;
    h_count        <= VID_h_total ; //1 ; //  Should be 1 if you want to minimize gates, but resetting the h/v_total
    v_count        <= VID_v_total ; //1 ; //  allows a simulation to begin active video 2 blank lines before beginning of picture
    h_count_out    <= 0 ;
    v_count_out    <= 0 ;
    H_ena_int      <= 0 ;
    V_ena_int      <= 0 ;
    H_ena          <= 0 ;
    V_ena          <= 0 ;
    Video_ena      <= 0 ;
    HS_out_int     <= VID_hs_polarity ;
    VS_out_int     <= VID_vs_polarity ;
    HS_out         <= VID_hs_polarity ;
    VS_out         <= VID_vs_polarity ;

    end else begin

    if (clk_divide == 0)             clk_divide     <= CLK_DIVIDE_IN     ; // Generate the pixel clock divider
    else                             clk_divide     <= clk_divide - 1'b1 ;
                                     CLK_PHASE_OUT  <= clk_divide        ; // Output the pixel clock divider


        if (clk_divide == CLK_DIVIDE_IN) begin  // Operate the sync section only while the clk_divider is at position 0.
        
        // Generate the H & V Counters
        
                if   (h_limit) h_count <= 1;
                else           h_count <= h_count + 1'b1;
        
                if   (h_ena_end) begin                              // Change the vertical counter as soon as the horizontal active video ends.
                            if (v_limit) v_count <= 1;              // This allows the 'V_ena' output to show ahead of the next active video line.
                            else         v_count <= v_count + 1'b1; // I've done it this way so that the video line output buffer is given maximum
                end                                                 // advance notice to begin filling when a new active video line begins.
        
        // Generate the sync outputs
        
                         if (hs_on  ) begin
                                      HS_out_int <= !VID_hs_polarity ;
                                    
                                           if (vs_on  ) VS_out_int <= !VID_vs_polarity ; // Only switch the VS output signal in parallel with the beginning
                                      else if (vs_off ) VS_out_int <=  VID_vs_polarity ; // of the HS output signal.
        
                end else if (hs_off ) HS_out_int <=  VID_hs_polarity ;
        
        // Generate the internal enable outputs
        
            if      (h_limit)   H_ena_int <= 1 ;
            else if (h_ena_end) H_ena_int <= 0 ;
        
            if      (h_ena_end) begin                 // Only evaluate the V_ena right at the point where the last pixel is being drawn.
                if      (v_limit)   V_ena_int <= 1 ;
                else if (v_ena_end) V_ena_int <= 0 ;
            end
        
        //  Generate all the Video_ena/sync outputs regs.
            H_ena       <= H_ena_int ;
            V_ena       <= V_ena_int ;
            Video_ena   <= H_ena_int && V_ena_int ;
            HS_out      <= HS_out_int ;
            VS_out      <= VS_out_int ;
        
        //  Output coordinates beginning on 0x0 instead of 1x1
            h_count_out <= h_count - 1'b1 ;
            v_count_out <= v_count - 1'b1 ;
        
        end // (clk_divide == 0)

    end // !reset
end // always CLK_IN

endmodule
