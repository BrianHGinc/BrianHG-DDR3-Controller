// *****************************************************************************************************
// BrianHG_GFX_Layer_mixer.sv
// Takes in multiple layers of 32bit RGBA video, Parallel and serial:
// Offers a 24bit RGB background color for below bottom layer, IE all pixels on all active layers happen to be transparent.
// Offers adjustment offset to the Alpha channel's opacity of each layer.
// Then offers serial layer order swapping of each parallel layer channel.
// Then offers parallel layer order swapping.
//
// Then mixes all parallel streams.
//
// Then mixes all resulting serial layers into the 1 final output stream.
//
// Version 1.6, January 2, 2022.
//
// Written by Brian Guralnick.
// For public use.
//
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Typedef structures.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
typedef struct packed {              // Generate a structure for the sync generator bus.
                logic  [2:0] phase ;
                logic        h_ena ;
                logic        v_ena ;
                logic        vena  ;
                logic        hs    ;
                logic        vs    ;
                logic        wlena ;
                logic [31:0] rgba  ;
                } vlb_bus ;


module BrianHG_GFX_Layer_mixer #(

parameter bit [3:0]  PDI_LAYERS             = 1,                       // Number of parallel layered 'BrianHG_GFX_Video_Line_Buffer' modules in the system.  1 through 8 is allowed.
parameter bit [3:0]  SDI_LAYERS             = 1,                       // Use 1,2,4, or 8 sequential display layers in each 'BrianHG_GFX_Video_Line_Buffer' module in the system.

parameter bit        ENABLE_alpha_adj       = 1,                       // Use 0 to bypass the alpha adjustment logic
parameter bit        ENABLE_SDI_layer_swap  = 1,                       // Use 0 to bypass the serial layer swapping logic
parameter bit        ENABLE_PDI_layer_swap  = 1,                       // Use 0 to bypass the parallel layer swapping logic

// ******* Do not edit these ****
parameter bit [6:0]  LAYERS                 = PDI_LAYERS * SDI_LAYERS  // Total window layers in system
)(

// *******************************************************************************
// ***** Layer alpha override and order re-positioning control inputs. 
// *******************************************************************************
input        [2:0]         CLK_DIVIDER                        , // Supports 0 through 7 to divide the clock from 1 through 8.
                                                                // Also cannot be higher than SDI_LAYERS and only SDI layers 0 through this number will be shown.

input       [23:0]         CMD_BGC_RGB                        , // Bottom background color when every layer's pixel happens to be transparent. 

input        [7:0]         CMD_SDI_layer_swap [0:PDI_LAYERS-1], // Re-position the SDI layer order of each PDI layer line buffer's output stream. (A Horizontal SDI PHASE layer swap / PDI layer)
input        [7:0]         CMD_PDI_layer_swap [0:SDI_LAYERS-1], // Re-position the PDI layer order of each SDI layer. (A PDI Vertical swap/SDI Layer PHASE) 

// *********************************************************************************************
// **** Video clock domain and input timing from at least 1 BrianHG_GFX_Video_Line_Buffer.
// *********************************************************************************************
input                      VID_RST                            , // Video output pixel clock's reset.
input                      VID_CLK                            , // Video output pixel clock.

input        [2:0]         VCLK_PHASE_IN                      , // Used with sync gen is there are 
input                      H_ena_in                           , // Horizontal video enable.
input                      V_ena_in                           , // Vertical video enable.
input                      VENA_in                            , // High during active video.
input                      HS_in                              , // Horizontal sync output.
input                      VS_in                              , // Vertical sync output.

// ***************************************************************************************
// **** Video video picture stream from every BrianHG_GFX_Video_Line_Buffer PDI layer
// **** with the embedded SDI layers on each line buffer PDI layer output.
// ***************************************************************************************
input                      WLENA_in           [0:PDI_LAYERS-1], // Window Layer Active In.
input        [31:0]        RGBA_in            [0:PDI_LAYERS-1], // 32 bit Video picture data input: Reg, Green, Blue, Alpha-Blend
input        [7:0]         alpha_adj_in       [0:PDI_LAYERS-1], // When 0, the layer translucency will be determined by the graphic data.
                                                                // Any figure from +1 to +127 will progressive force all the graphics opaque.
                                                                // Any figure from -1 to -128 will progressive force all the graphics transparent.

// ***************************************************************************************
// **** Singular mixed video output channel.
// ***************************************************************************************
output       [31:0]        RGBA_out                           , // 32 bit Video picture data output: Reg, Green, Blue, Alpha-Blend

output       [2:0]         VCLK_PHASE_OUT                     , // Pixel clock divider position.
output                     H_ena_out                          , // Horizontal video enable.
output                     V_ena_out                          , // Vertical video enable.
output                     VENA_out                           , // High during active video.
output                     HS_out                             , // Horizontal sync output.
output                     VS_out                               // Vertical sync output.
);


generate
if ( (SDI_LAYERS!=1) && (SDI_LAYERS!=2) && (SDI_LAYERS!=4) && (SDI_LAYERS!=8) )  initial begin
$warning("**************************************");
$warning("*** BrianHG_GFX_Layer_mixer ERROR. ***");
$warning("***********************************************************");
$warning("*** Your current parameter .SDI_LAYERS(%d) is invalid. ***",6'(SDI_LAYERS));
$warning("*** It can only be 1, 2, 4, or 8.                       ***");
$warning("***********************************************************");
$error;
$stop;
end
if ( (PDI_LAYERS<1) || (PDI_LAYERS>8) )  initial begin
$warning("***************************************");
$warning("*** BrianHG_GFX_Layer_mixer ERROR.  ***");
$warning("***********************************************************");
$warning("*** Your current parameter .PDI_LAYERS(%d) is invalid. ***",6'(PDI_LAYERS));
$warning("*** It can only be anywhere from 1 through 8.           ***");
$warning("***********************************************************");
$error;
$stop;
end
endgenerate


vlb_bus  vlb_vid_in  [0:PDI_LAYERS-1] ;
vlb_bus  alpha_out   [0:PDI_LAYERS-1] ;
vlb_bus  sdi_swap    [0:PDI_LAYERS-1] ;
vlb_bus  pdi_swap    [0:PDI_LAYERS-1] ;
vlb_bus  sdi_mix                      ;

 // PDI layer by PDI layer Copy input bus to vlb structure.
always_comb for (int i=0;i<PDI_LAYERS;i++) vlb_vid_in[i] = '{VCLK_PHASE_IN,H_ena_in,V_ena_in,VENA_in,HS_in,VS_in,WLENA_in[i],RGBA_in[i]};

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// CMD_win_alpha_adj for each layer.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
genvar z ;
generate if (!ENABLE_alpha_adj) begin
    assign alpha_out = vlb_vid_in ;
end else begin

    wire [7:0] alpha_result [0:PDI_LAYERS-1] ;
    for (z=0;z<PDI_LAYERS;z++) begin : ADJAI
                               ALPHA_ADJ adja ( .adj(alpha_adj_in[z]), .WLENA_in(WLENA_in[z]), .ain(vlb_vid_in[z].rgba[7:0]), .aout(alpha_result[z]) );
                               end


    always_ff @(posedge VID_CLK) begin

        for (int i=0 ; i<PDI_LAYERS; i++) begin
                                          alpha_out[i].rgba  <= {vlb_vid_in[i].rgba[31:8],alpha_result[i]};
                                          alpha_out[i].wlena <=  vlb_vid_in[i].wlena ;
                                          alpha_out[i].phase <=  vlb_vid_in[i].phase ;
                                          alpha_out[i].h_ena <=  vlb_vid_in[i].h_ena ;
                                          alpha_out[i].v_ena <=  vlb_vid_in[i].v_ena ;
                                          alpha_out[i].vena  <=  vlb_vid_in[i].vena  ;
                                          alpha_out[i].hs    <=  vlb_vid_in[i].hs    ;
                                          alpha_out[i].vs    <=  vlb_vid_in[i].vs    ;
                                          end
    end

end endgenerate

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// SDI sequence phase swapper on each PDI layer.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
generate if (!ENABLE_SDI_layer_swap || SDI_LAYERS==1) begin
    assign sdi_swap = alpha_out;
end else begin

    for (z=0;z<PDI_LAYERS;z++) begin : SDI_LSWAP
                               SDI_SWAPPER #(.SDI_LAYERS(SDI_LAYERS)) sdi_swapr
                                            (.clk(VID_CLK), .divider(CLK_DIVIDER), .swap(CMD_SDI_layer_swap[z]), .in(alpha_out[z]), .out(sdi_swap[z]) );
                               end

end endgenerate


// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// PDI channel swapper at each SDI phase position.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
generate if (!ENABLE_PDI_layer_swap || PDI_LAYERS==1) begin
    assign pdi_swap = sdi_swap;
end else begin

always_ff @(posedge VID_CLK) begin

    for (int i=0;i<PDI_LAYERS;i++) begin
                                   pdi_swap[i] <= sdi_swap[(i+CMD_PDI_layer_swap[sdi_swap[i].phase][6:4])^CMD_PDI_layer_swap[sdi_swap[i].phase][2:0]];
                                   end

end

end endgenerate



// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Progressive PDI-SDI layer mixer.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
vlb_bus  pdi_mix  [0:PDI_LAYERS];
vlb_bus  pdi_dly  [0:PDI_LAYERS-1][0:PDI_LAYERS-1];

generate if (LAYERS    ==1) begin

    assign sdi_mix = pdi_swap[0];

end else if (PDI_LAYERS==1) begin

    // Only use the final SDI_LAYER mixer if there is a single PDI_LAYER...
    SDI_mixer sdi_mixr ( .clk(VID_CLK), .pre_rgb(CMD_BGC_RGB), .in(pdi_swap[0]), .out(sdi_mix) );

end else begin

    // Run a multi-PDI_LAYERS SDI_LAYER mixer chain.

    // Assign the all the source video PDI_LAYERS to the bottom first PDI_LAYER tap.
    assign pdi_dly[PDI_LAYERS-1] = pdi_swap ;

    // Generate all the tap delays for each PDI_LAYER to synchronize with each SDI_LAYER mixer's output the next PDI_LAYER's SDI_LAYER mixer in the chain.
    for (z=PDI_LAYERS-1;z>0;z--) begin : PDI_ZDLY
                                 PDI_vh_dly #(.channels(PDI_LAYERS))  pdi_zdly ( .clk(VID_CLK),.dly(CLK_DIVIDER), .in(pdi_dly[z]),.out(pdi_dly[z-1]) );
                                 end


    // Assign the complete bottom background color.
    assign pdi_mix[PDI_LAYERS].rgba = {CMD_BGC_RGB,8'd0};

    // Sequentially mix the SDI layers feeding the bottom input from each successive PDI_LAYERS using the correctly horizontal delay compensated PDI layer tap.
    for (z=PDI_LAYERS  ;z>0;z--) begin : PDI_MIXR
                                 SDI_mixer sdi_mixr ( .clk(VID_CLK),.pre_rgb(pdi_mix[z].rgba[31:8]),.in(pdi_dly[z-1][z-1]),.out(pdi_mix[z-1]) );
                                 end

    // Assign the final mixed video output to the final SDI_LAYER mixer's output.
    assign sdi_mix = pdi_mix[0];

end endgenerate


// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Assign outputs.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
assign RGBA_out       = sdi_mix.rgba  ;
assign VCLK_PHASE_OUT = sdi_mix.phase ;
assign H_ena_out      = sdi_mix.h_ena ;
assign V_ena_out      = sdi_mix.v_ena ;
assign VENA_out       = sdi_mix.vena  ;
assign HS_out         = sdi_mix.hs    ;
assign VS_out         = sdi_mix.vs    ;

endmodule


// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// SDI_LAYER swapper.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
module SDI_SWAPPER  #(parameter SDI_LAYERS=1)(input clk, input [2:0] divider, input [7:0] swap, input vlb_bus in, output vlb_bus out);

vlb_bus ireg[0:SDI_LAYERS-1] ;
vlb_bus oreg[0:SDI_LAYERS-1] ;

logic [2:0] phase_dly  = 0;

    always_ff @(posedge clk) begin

        phase_dly  <= in.phase ;

        // Store the input into it's own cell.
        if (in.phase<SDI_LAYERS)                              ireg[in.phase] <= in ;
        // Block transfer all the input cells into a latch.
        if (in.phase==divider) for (int i=0;i<SDI_LAYERS;i++) oreg[i]        <= ireg[i];

        // cross convert and set output.
        out.phase <= phase_dly                                   ;
        out.rgba  <= oreg[(phase_dly+swap[6:4])^swap[2:0]].rgba  ;
        out.wlena <= oreg[0].wlena ;
        out.h_ena <= oreg[0].h_ena ;
        out.v_ena <= oreg[0].v_ena ;
        out.vena  <= oreg[0].vena  ;
        out.hs    <= oreg[0].hs    ;
        out.vs    <= oreg[0].vs    ;
 
    end

endmodule

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Adjust alpha compensation.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
module ALPHA_ADJ (input wire [7:0] adj, input wire WLENA_in, input wire [7:0] ain, output [7:0] aout);

    wire [8:0] alpha_fixp = (ain +           {adj[6:0],adj[6]}  ) ;
    wire [8:0] alpha_fixn = (ain - 8'(8'd255^{adj[6:0],adj[6]}) ) ;

    // Use the active window area flag WLENA_in[] to ensure a transparent alpha no matter the alpha adjust setting for that layer.
    assign aout = (!WLENA_in) ? 8'd0 : (!adj[7]) ? (alpha_fixp[8] ? 8'd255 : alpha_fixp[7:0]) :    // Add so that an overshoot =255
                                                   (alpha_fixn[8] ? 8'd0   : alpha_fixn[7:0])    ; // subtract so that an undershoot =0

endmodule

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Mix SDI layers together with an input channel for the bottom background layer.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
module SDI_mixer (input clk, input [23:0] pre_rgb, input vlb_bus in, output vlb_bus out);

    // When mixing the initial bottom layer, assign the BGC background color to the layer beneath that one.
    // Otherwise, use the previous calculated mix layer as the new bottom layer.
    logic mix_bgc ;
    wire [7:0] mix_bot_r = mix_bgc ? pre_rgb[23:16] : out.rgba[31:24] ;
    wire [7:0] mix_bot_g = mix_bgc ? pre_rgb[15: 8] : out.rgba[23:16] ;
    wire [7:0] mix_bot_b = mix_bgc ? pre_rgb[ 7: 0] : out.rgba[15: 8] ;
    wire [7:0] mix_r ;
    wire [7:0] mix_g ;
    wire [7:0] mix_b ;

    // Calculate the mix using the previous layer as the bottom and the current pixel data as the top layer RGB and alpha in the mixing process.
    mixer #(.mbits(8),.dbits(8)) mix_sdi_r (.mix(in.rgba[7:0]),.bot(mix_bot_r),.top(in.rgba[31:24]),.out(mix_r));
    mixer #(.mbits(8),.dbits(8)) mix_sdi_g (.mix(in.rgba[7:0]),.bot(mix_bot_g),.top(in.rgba[23:16]),.out(mix_g));
    mixer #(.mbits(8),.dbits(8)) mix_sdi_b (.mix(in.rgba[7:0]),.bot(mix_bot_b),.top(in.rgba[15: 8]),.out(mix_b));

    // Sequentially clock the pixel pipe.
    always_ff @(posedge clk) begin

        mix_bgc <= (in.phase==0) ; // Prepare the next cycle to have the bottom BGC mix color.

        out.rgba  <= {mix_r,mix_g,mix_b,in.rgba[7:0]};
        out.wlena <= in.wlena ;
        out.phase <= in.phase ;
        out.h_ena <= in.h_ena ;
        out.v_ena <= in.v_ena ;
        out.vena  <= in.vena  ;
        out.hs    <= in.hs    ;
        out.vs    <= in.vs    ;

    end

endmodule

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Basic TOP/BOTTOM alpha blending mixer.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
module mixer #(parameter mbits=8, parameter dbits=8)(input [mbits-1:0] mix, input [dbits-1:0] top, input [dbits-1:0] bot, output [dbits-1:0] out);

    wire [mbits-1:0] mtop = mix;
    wire [mbits-1:0] mbot = ((mbits)'(2**mbits-1))-mix;

    // The added LSB bit set to 1 in the multipliers helps retain full contrast without loosing a single shade.
    // This is necessary since running the display through multiple layers would otherwise mean loosing 1 brightness per mixing layer.
    // IE: 16 layers means a big loss of contrast, 16 out of 255.

    wire [mbits+dbits+1:0] fact_top = {mtop,1'b1} * {top,1'b1} ; 
    wire [mbits+dbits+1:0] fact_bot = {mbot,1'b1} * {bot,1'b1} ; 

    assign out = (dbits)'((fact_top>>(mbits+2))+(fact_bot>>(mbits+2)));

endmodule

// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
// Variable horizontal shift delay register from 1 clk to 8 clks.
// **********************************************************************************
// **********************************************************************************
// **********************************************************************************
module PDI_vh_dly #(parameter channels=1)(input clk,input [2:0] dly, input vlb_bus in[0:channels-1], output vlb_bus out[0:channels-1]);

    vlb_bus in_dly[0:channels-1][0:7];

    // Assign all input channels to all delay line channels, delay position 0
    always_comb  for (int i=0; i<channels; i++) in_dly[i][0] = in[i] ;

    // Generate the delay chain channels
    always_ff @(posedge clk) begin
            for (int x=1; x<8; x++) begin
                for (int i=0; i<channels; i++) in_dly[i][x] <= in_dly[i][x-1];
            end
        end

    // Generate the output with the selected adjustable delay input.
    always_ff @(posedge clk) for (int i=0; i<channels; i++) out[i] <= in_dly[i][dly];

endmodule

