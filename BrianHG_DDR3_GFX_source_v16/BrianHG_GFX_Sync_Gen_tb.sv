// *****************************************************************
// Generate a programmable VGA sync test-bench.
// v1.6, December 6, 2021
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.


module BrianHG_GFX_Sync_Gen_tb #(
parameter HC_BITS = 16,    // Width of horizontal counter.
parameter VC_BITS = 16     // Width of vertical counter.
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
localparam      endtime     = STOP_uS * 1000;


 BrianHG_GFX_Sync_Gen #(

) DUT_BHG_Sync_Gen (

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


initial begin

CLK_DIVIDE_IN       = 1    ;
VID_h_total         = 48   ;
VID_h_res           = 32   ;
VID_hs_front_porch  = 2    ;
VID_hs_size         = 6    ;
VID_hs_polarity     = 1    ;
VID_v_total         = 24   ;
VID_v_res           = 12   ;
VID_vs_front_porch  = 3    ;
VID_vs_size         = 3    ;
VID_vs_polarity     = 1    ;

reset  = 1'b1 ; // Reset input
CLK_IN = 1'b1 ;
#(50000);
reset  = 1'b0 ; // Release reset at 50ns.
end

always #period         CLK_IN = !CLK_IN ;  // create source clock oscillator
always #(endtime)      $stop            ;  // Stop simulation from going on forever.
endmodule
