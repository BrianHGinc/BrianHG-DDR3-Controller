/*
    Hardware Control Registers
    by Jonathan Nock & Brian Guralnick

    V2.0. 30th November, 2021.

    HW_REGS are 16KB of 16-bit values held in RAM at BASE_WRITE_ADDRESS.

    At reset, key registers are set to default RESET_VALUES specified in this module.
*/

module HW_Regs #(

    parameter string      ENDIAN                           = "Big" , // Enter "B****" for Big Endian,  "L****" for Little Endian.
    parameter int         PORT_ADDR_SIZE                   = 19    , // This parameter is passed by the top module
    parameter int         PORT_CACHE_BITS                  = 128   , // This parameter is passed by the top module
    parameter             HW_REGS_SIZE                     = 12    , // 2^14 = 16384 bytes
    parameter int         RST_8_PARAM_SIZE                 = 4     , // Number of default values
    parameter int         RST16_PARAM_SIZE                 = 2     , // Number of default values
    parameter int         RST32_PARAM_SIZE                 = 1     , // Number of default values
    parameter int         BASE_WRITE_ADDRESS               = 32'h0 , // Where the HW_REGS are held in RAM
    parameter bit [23:0]  RESET_VALUES_8[1:RST_8_PARAM_SIZE] = '{
            {16'h00, 8'h10}, {16'h01, 8'h00}, {16'h02, 8'h10}, {16'h03, 8'h00}
    },
    parameter bit [31:0]  RESET_VALUES16[1:RST16_PARAM_SIZE] = '{
            {16'h00, 16'h0010}, {16'h02, 16'h0010}
    },
    parameter bit [47:0]  RESET_VALUES32[1:RST32_PARAM_SIZE] = '{
            {16'h00, 32'h00100010}
    }

)(

    input                               RESET,
    input                               CLK,
    input                               WE,
    input          [PORT_ADDR_SIZE-1:0] ADDR_IN,
    input         [PORT_CACHE_BITS-1:0] DATA_IN,
    input       [PORT_CACHE_BITS/8-1:0] WMASK,
    output  logic               [  7:0] HW_REGS__8bit[0:(2**HW_REGS_SIZE-1)],
    output  logic               [ 15:0] HW_REGS_16bit[0:(2**HW_REGS_SIZE-1)],
    output  logic               [ 31:0] HW_REGS_32bit[0:(2**HW_REGS_SIZE-1)]

);

localparam bit       endian_h16 = (ENDIAN[0] == "L") ? 1'b1 : 1'b0 ;
localparam bit       endian_l16 = (ENDIAN[0] == "L") ? 1'b0 : 1'b1 ;
localparam bit [1:0] endian_h32 = (ENDIAN[0] == "L") ? 2'd3 : 2'd0 ;
localparam bit [1:0] endian_m32 = (ENDIAN[0] == "L") ? 2'd2 : 2'd1 ;
localparam bit [1:0] endian_n32 = (ENDIAN[0] == "L") ? 2'd1 : 2'd2 ;
localparam bit [1:0] endian_l32 = (ENDIAN[0] == "L") ? 2'd0 : 2'd3 ;

wire enable   = ( ADDR_IN[PORT_ADDR_SIZE-1:0] >= BASE_WRITE_ADDRESS[PORT_ADDR_SIZE-1:0] ) && ( ADDR_IN[PORT_ADDR_SIZE-1:0] < (BASE_WRITE_ADDRESS[PORT_ADDR_SIZE-1:0]+2**HW_REGS_SIZE) ) ;   // upper x-bits of ADDR_IN should equal BASE_WRITE_ADDRESS for a successful read or write
wire valid_wr = WE && enable ;

integer x;
always_comb begin
    for (x = 0; x < (2**HW_REGS_SIZE-1); x = x + 1)  HW_REGS_16bit[x] = { HW_REGS__8bit[x+endian_h16], HW_REGS__8bit[x+endian_l16] } ;
    for (x = 0; x < (2**HW_REGS_SIZE-3); x = x + 1)  HW_REGS_32bit[x] = { HW_REGS__8bit[x+endian_h32], HW_REGS__8bit[x+endian_m32], HW_REGS__8bit[x+endian_n32], HW_REGS__8bit[x+endian_l32] } ;
end

integer i ;
always @( posedge CLK ) begin
    
    if ( RESET ) begin
        // reset registers to initial values
        if (RST_8_PARAM_SIZE != 0) begin
            for (i = 1; i <= RST_8_PARAM_SIZE; i = i + 1) begin
                HW_REGS__8bit[(RESET_VALUES_8[i][21:8])] <= RESET_VALUES_8[i][ 7:0] ;
            end
        end
        if (RST16_PARAM_SIZE != 0) begin
            for (i = 1; i <= RST16_PARAM_SIZE; i = i + 1) begin
                HW_REGS__8bit[{RESET_VALUES16[i][29:16] + endian_l16}] <= RESET_VALUES16[i][ 7:0] ;
                HW_REGS__8bit[{RESET_VALUES16[i][29:16] + endian_h16}] <= RESET_VALUES16[i][15:8] ;
            end
        end
        if (RST32_PARAM_SIZE != 0) begin
            for (i = 1; i <= RST32_PARAM_SIZE; i = i + 1) begin
                HW_REGS__8bit[{RESET_VALUES32[i][45:32] + endian_h32}] <= RESET_VALUES32[i][ 7: 0] ;
                HW_REGS__8bit[{RESET_VALUES32[i][45:32] + endian_m32}] <= RESET_VALUES32[i][15: 8] ;
                HW_REGS__8bit[{RESET_VALUES32[i][45:32] + endian_n32}] <= RESET_VALUES32[i][23:16] ;
                HW_REGS__8bit[{RESET_VALUES32[i][45:32] + endian_l32}] <= RESET_VALUES32[i][31:24] ;
            end
        end
    end
    else
    begin
        for (i = 0; i < PORT_CACHE_BITS/8; i = i + 1)  begin
            if (valid_wr && WMASK[i]) begin
                HW_REGS__8bit[( (ADDR_IN[HW_REGS_SIZE-1:0]-BASE_WRITE_ADDRESS[PORT_ADDR_SIZE-1:0]) | (i^(PORT_CACHE_BITS/8-1)) )] <= DATA_IN[i*8+:8] ;
            end
        end
    end
    
end

endmodule
