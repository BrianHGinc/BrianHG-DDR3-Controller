// ********************************************************************************************************
// ********************************************************************************************************
// ********************************************************************************************************
//
// BrianHG_DDR3_FIFOs.sv serial shifting logic cell FIFOs.
// Version 1.00, August 22, 2021.
//
// Written by Brian Guralnick.
//
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// ********************************************************************************************************
// ********************************************************************************************************
// ********************************************************************************************************

module BHG_FIFO_shifter_FWFT #(
//*************************************************************************************************************************************
parameter  int bits                 = 8,          // sets the width of the fifo.
parameter  int words                = 2,          // sets the depth of the fifo, 2, 3, 4, 5, 6...
parameter  int spare_words          = 1,          // The number of spare words before being truly full.
parameter  bit full_minus_shift_out = 0           // Full flag considers the shift_out input.  Enabling may decrease FMAX when trying to go above 300MHz.
//*************************************************************************************************************************************
)(
input                   clk,            // CLK input
input                   reset,          // reset FIFO

output logic            full,           // High when the FIFO's is full.
input                   shift_in,       // load a word into the FIFO.
input        [bits-1:0] data_in,        // data word input.

output logic            data_ready,     // High when data_out has valid data.
input                   shift_out,      // shift data out of the FIFO.
output logic [bits-1:0] data_out        // FIFO data word output
);

logic [bits-1  :0] mem  [0:words-1]  =  '{default:'0};
logic [words-1 :0] stat = 0 ;


always_comb begin
full       = stat[words-spare_words-1] ;
data_ready = stat[0];
data_out   = mem [0];
end

// Synchronous logic.
always_ff @(posedge clk) begin
if (reset) begin
        stat       <= 0 ;
    end else begin

             if (  shift_in && !shift_out ) stat <= {stat[words-2:0],1'b1} ; // Shift in an active status flag into the beginning of the status.
        else if ( !shift_in &&  shift_out ) stat <= {1'b0,stat[words-1:1]} ; // Shift out the active status flag.

                 if ( shift_in && !shift_out) begin
                                                for (int i=0;i<words;i++) if (!stat[i]) mem[i] <= data_in ;
        end else if (!shift_in &&  shift_out) begin
                                                for (int i=0;i<(words-1);i++) mem[i] <= mem[i+1] ;
        end else if ( shift_in &&  shift_out) begin
                                                for (int i=0;i<(words-1);i++) mem[i] <= stat[i+1] ? mem[i+1] : data_in ;
        end

    end // !reset
end // always_ff
endmodule



module BHG_FIFO_shifter_2clock_FWFT #(
//*************************************************************************************************************************************
parameter  int bits                 = 8,          // sets the width of the fifo.
parameter  int words                = 4,          // sets the depth of the fifo, 2, 3, 4, 5, 6...
parameter  int spare_words          = 1,          // The number of spare words before being truly full.
parameter  bit full_minus_shift_out = 0           // Full flag considers the shift_out input.  Enabling may decrease FMAX when trying to go above 300MHz.
//*************************************************************************************************************************************
)(
input                   clk_in,         // CLK input
input                   reset,          // reset FIFO

output logic            full,           // High when the FIFO's is full.
input                   shift_in,       // load a word into the FIFO.
input        [bits-1:0] data_in,        // data word input.

input                   clk_out,        // CLK input
output logic            data_ready,     // High when data_out has valid data.
input                   shift_out,      // shift data out of the FIFO.
output logic [bits-1:0] data_out        // FIFO data word output
);

logic s1_rdy,s2_full;
logic [bits-1:0] s1_data_out;

BHG_FIFO_shifter_FWFT #(
.bits                 (bits),              // sets the width of the fifo.
.words                (words),             // sets the depth of the fifo, 2, 3, 4, 5, 6...
.spare_words          (spare_words)        // The number of spare words before being truly full.
) BHG_FIFOs1 (
.reset       ( reset              ),

.clk         ( clk_in             ),
.shift_in    ( shift_in           ),
.data_in     ( data_in            ),
.full        ( full               ),

.data_ready  ( s1_rdy             ),
.shift_out   ( s1_rdy && !s2_full ),
.data_out    ( s1_data_out        ) );

logic c2_shift_in = 0, reset_l2 = 0;
always_ff @(posedge clk_out) c2_shift_in <= s1_rdy ? !c2_shift_in : 1'b0 ;
always_ff @(posedge clk_out) reset_l2    <= reset ;

BHG_FIFO_shifter_FWFT #(
.bits                 (bits),              // sets the width of the fifo.
.words                (words),             // sets the depth of the fifo, 2, 3, 4, 5, 6...
.spare_words          (spare_words)        // The number of spare words before being truly full.
) BHG_FIFOs2 (
.reset       ( reset_l2           ),

.clk         ( clk_out            ),
.shift_in    ( (s1_rdy && c2_shift_in) && !s2_full ),
.data_in     ( s1_data_out        ),
.full        ( s2_full            ),

.data_ready  ( data_ready         ),
.shift_out   ( shift_out          ),
.data_out    ( data_out           ) );

endmodule

module BHG_FIFO_X_shifter #(
//*************************************************************************************************************************************
parameter  int bits                 = 8,          // sets the width of the fifo.
parameter  int words                = 1,          // sets the depth of the fifo, 2, 3, 4, 5, 6...
parameter  int spare_words          = 1,          // The number of spare words before being truly full.
parameter  bit full_minus_shift_out = 0           // Full flag considers the shift_out input.  Enabling may decrease FMAX when trying to go above 300MHz.
//*************************************************************************************************************************************
)(
input                   clk,            // CLK input
input                   reset,          // reset FIFO

output                  full,           // High when the FIFO's is full.
input                   shift_in,       // load a word into the FIFO.
input        [bits-1:0] data_in,        // data word input.

output                  data_ready,     // High when data_out has valid data.
input                   shift_out,      // shift data out of the FIFO.
output       [bits-1:0] data_out        // FIFO data word output
);

logic [words:0]  si=0,so=0,rdy=0,fu=0;
logic [bits-1:0] data_i [0:words];
logic [bits-1:0] data_o [0:words];

// Connect input port to to the first 2 word fifo.
assign si[1]      = shift_in    ;
assign data_i[1]  = data_in     ;
assign full       = fu[1]       ;

// Connect output port the the last 2 word fifo.
assign data_ready = rdy[words]    ;
assign so[words]  = shift_out     ;
assign data_out   = data_o[words] ;

// ****************************************************************************************************************************
// Generate Elastic FIFO string.
// ****************************************************************************************************************************
genvar x;
generate
    for (x=1 ; x<=words ; x=x+1) begin : BHG_FIFO_Xs_ints

        // sequentially wire the FIFOs.
       if (x!=words) assign so[x]       = rdy[x]   && !fu[x+1];
       if (x!=1)     assign si[x]       = rdy[x-1] && !fu[x];
       if (x!=1)     assign data_i[x]   = data_o[x-1];

        // Generate the 2 word FIFOs.
        BHG_FIFO_shifter_FWFT #(
        .bits                 (bits),          // sets the width of the fifo.
        .words                (2),             // sets the depth of the fifo to 2.
        .spare_words          (spare_words)              // spare words after the full flag goes high.
        ) BHG_FIFO_Xs_ints (
        .reset       ( reset     ),
        .clk         ( clk       ),

        .shift_in    ( si    [x] ),
        .data_in     ( data_i[x] ),
        .full        ( fu    [x] ),
        
        .data_ready  ( rdy   [x] ),
        .shift_out   ( so    [x] ),
        .data_out    ( data_o[x] ) );        
    end
endgenerate

endmodule
// *****************************************************************
// *****************************************************************
// *****************************************************************
// *** BHG_FIFO_Xword_FWFT.sv V1.0, June 16, 2020
// ***
// *** This is a X word FIFO with first word feed through (FWFT),
// ***
// *** Well commented for educational purposes.
// *****************************************************************
// *****************************************************************
// *****************************************************************

module BHG_FIFO_Xword_FWFT #(
//*************************************************************************************************************************************
parameter  int bits                 = 8,          // sets the width of the fifo.
parameter  int words                = 4,          // sets the depth of the fifo, 2, 4, 8, 16, or 32...
parameter  int spare_words          = 1           // The number of spare words before being truly full.
//parameter  bit full_minus_shift_out = 0           // Full flag considers the shift_out input.  Enabling may decrease FMAX when trying to go above 300MHz.
//*************************************************************************************************************************************
)(
input                   clk,            // CLK input
input                   reset,          // reset FIFO

output logic            full,           // High when the FIFO's is full.
input                   shift_in,       // load a word into the FIFO.
input        [bits-1:0] data_in,        // data word input.

output logic            data_ready,     // High when data_out has valid data.
input                   shift_out,      // shift data out of the FIFO.
output logic [bits-1:0] data_out        // FIFO data word output
);

localparam int PTR_BITS = $clog2(words); // Determine the number of bits required for the fifo memory pointers.

logic                shift_in_safe,shift_out_safe;
logic [PTR_BITS-1:0] wr_ptr, rd_ptr ;
logic [PTR_BITS+1:0] count_full,count_ready ;
logic [bits-1    :0] fifo_mem [0:words-1] =  '{default:'0};

// Combinational logic.
always_comb begin

    shift_in_safe  = shift_in ;// && data_ready;
    shift_out_safe = shift_out;// && count_ready[PTR_BITS+1];

    full           = count_full[PTR_BITS+1] ;

    data_ready     = count_ready[PTR_BITS+1] ;
    data_out       = fifo_mem [rd_ptr] ;

end // always_comb

// Synchronous logic.
always_ff @(posedge clk) begin
if (reset) begin

        count_full   <= (PTR_BITS+2)'(words - spare_words - 1) ;
        count_ready  <= 0 ;
        wr_ptr       <= 0 ;
        rd_ptr       <= 0 ;
        //fifo_mem     <= '{default:'0};
        //data_out     <= 0 ;
        //data_ready   <= 0 ;

    end else begin


    if      (  shift_in_safe && !shift_out_safe ) count_ready  <= count_ready - 1'd1 ;
    else if ( !shift_in_safe &&  shift_out_safe ) count_ready  <= count_ready + 1'd1 ;

    if      (  shift_in_safe && !shift_out_safe ) count_full   <= count_full - 1'd1 ;
    else if ( !shift_in_safe &&  shift_out_safe ) count_full   <= count_full + 1'd1 ;

    if ( shift_in_safe  ) begin
                            fifo_mem[wr_ptr]  <= data_in ;
                            wr_ptr            <= wr_ptr + 1'd1 ;
                          end

    if (  shift_out_safe ) begin
                            rd_ptr            <= rd_ptr + 1'd1 ;
                          end

/*
    if (shift_in && !data_ready) begin
                                data_ready     <= 1 ;
                                data_out       <= data_in ;
    end else if (shift_out_safe) begin
                                data_ready     <= count_ready[PTR_BITS+1] ;
                                data_out       <= fifo_mem [rd_ptr[PTR_BITS-1:0]] ;
    end else if (shift_out)     data_ready     <= 0 ;
*/

  end // !reset
end // always_ff
endmodule

