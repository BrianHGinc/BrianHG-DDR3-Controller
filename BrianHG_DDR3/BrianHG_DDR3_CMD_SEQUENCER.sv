// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
//
// BrianHG_DDR3_CMD_SEQUENCER DDR3 sequencer.
// Version 1.50, November 28, 2021.
//               Added *preserve* and duplicate logic to minimize fanouts to help FMAX.
//
// Written by Brian Guralnick.
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
//
// BHG_DDR3_CMD_SEQUENCER.sv, input read/write commands, output the necessary sequence of DDR3 commands required to read or write the data.
//
// Designed for >300MHz FMAX on a -8, >400MHz FMAX on a -6 CycloneV/Max10.
// This module initiation takes in the IN_xxx command input and compares the selected bank & address to the previous
// used stored bank & address generating a status flag as the command is piped the first 3 sections.
// Section 4 decides based on an external refresh flag request input and the bank status which 7 different commands should be sent
// out to DDR3 memory.
//
// The output commands come out as fast as possible, it is up the external DDR3 PHY pin driver to time & limit the commands
// going out to the DDR3.  This way, this module may be run on a clock of half or quarter speed of the DDR3 PHY.
// Only BL8 is supported in this module, so, with continuous consecutive reads, in theory this module can continuously perform a saturated burst
// running at quarter speed, however, it is still better to run this module at half or full speed to prevent occasional 1 clock alignment delays
// at the DDR3 full CK speed when surrounding PRE & ACT commands are requested.
//
// For ASYNC clocks designs, you may place a dual clock FIFO between this section and the PHY command output section making it possible to run
// this section at an arbitrary clock frequency separate of the DDR3 CK clock frequency.  Your FIFO you choose must show the data out with the
// data out ready/!empty flag for this to work as well as pass through all the write data and write mask.  Read Vector data may be handled
// separately by a FIFO counting the read commands and DDR3 read data ready results.
//
// Since the target FMAX is so high for the slower -8 Altera FPGAs, this module has to be done in a multi-stage pipelined approach. 
//
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************
// ************************************************************************************************************************************************

module BrianHG_DDR3_CMD_SEQUENCER #(

parameter bit        USE_TOGGLE_ENA          = 1,                     // When enabled, the (IN_ENA/IN_BUSY) & (OUT_READ_READY) toggle state to define the next command.
parameter bit        USE_TOGGLE_OUT          = 1,                     // When enabled, the (OUT_READY) & (OUT_ACK) use toggle state to define the next command.
parameter int        DDR3_WIDTH_BANK         = 3,                     // Use for the number of bits to address each bank.
parameter int        DDR3_WIDTH_ROW          = 15,                    // Use for the number of bits to address each row, ***16 maximum.
parameter int        DDR3_WIDTH_CAS          = 10,                    // Use for the number of bits to address each column.
parameter int        DDR3_RWDQ_BITS          = 16,                    // Must equal to total bus width across all DDR3 ram chips.  The MASK width is divided by 8.
parameter int        PORT_VECTOR_SIZE        = 8,                     // Set the width of the IN_RD_VECTOR & OUT_RD_VECTOR.
parameter int        CAL_WIDTH               = (DDR3_RWDQ_BITS/8),    // The total bit width of the 'high' or 'low' pins in the read calibration pattern.
parameter bit        BHG_EXTRA_SPEED         = 1                      // Use '1' for even better FMAX performance or when overclocking the core.  This will increase logic cell usage.
)(
input                                reset            ,
input                                CLK              ,

input                                IN_ENA           ,
output logic                         IN_BUSY          ,

input                                IN_WENA          ,
input        [DDR3_WIDTH_BANK-1:0]   IN_BANK          ,
input        [DDR3_WIDTH_ROW-1:0]    IN_RAS           ,
input        [DDR3_WIDTH_CAS-1:0]    IN_CAS           ,
input        [DDR3_RWDQ_BITS-1:0]    IN_WDATA         ,
input        [DDR3_RWDQ_BITS/8-1:0]  IN_WMASK         ,
input        [PORT_VECTOR_SIZE-1:0]  IN_RD_VECTOR     ,
input                                IN_REFRESH_t     , // Invert/toggle this input once every time a refresh request is required.

input                                OUT_ACK          , // Tells internal fifo to send another command.
output logic                         OUT_READY        ,
output logic [3:0]                   OUT_CMD          , // DDR3 command out wiring order {CS#,RAS#,CAS#,WE#}.
output logic [7:0]                   OUT_TXB          , // DDR3 command out command signal bit order {nop,zqc,rea,wri,act,pre,ref,mrs}.
output logic [DDR3_WIDTH_BANK-1:0]   OUT_BANK         ,
output logic [DDR3_WIDTH_ROW-1:0]    OUT_A            ,
output logic [DDR3_RWDQ_BITS-1:0]    OUT_WDATA        ,
output logic [DDR3_RWDQ_BITS/8-1:0]  OUT_WMASK        ,

input                                IN_READ_RDY_t    , // From DDR3 IO phy module
input        [DDR3_RWDQ_BITS-1:0]    IN_READ_DATA     , // From DDR3 IO phy module
output logic                         OUT_READ_READY   ,
output logic [DDR3_RWDQ_BITS-1:0]    OUT_READ_DATA    ,
output logic [PORT_VECTOR_SIZE-1:0]  OUT_RD_VECTOR    ,  // Note that the 'preserve' here ensures the data latch location of the fifo's inferred memory block used for the read vector.

output logic                         OUT_REFRESH_ack  ,  // Once this output has become = to the 'IN_REFRESH_t' input, a refresh has been done.
output logic                         OUT_IDLE         ,  // When the DDR3 has not been sent any commands, IE S4_ready is always low.

output logic                         READ_CAL_PAT_t   ,  // Toggles after every read once the READ_CAL_PAT_v data is valid.
output logic                         READ_CAL_PAT_v  );  // Valid read cal pattern detected in read.

// Multistage pipeline registers, deliberately laid out by name for visual purposes.
logic                         S1_WENA      =0 ;
logic [DDR3_WIDTH_BANK-1:0]   S1_BANK      =0 ;
logic [DDR3_WIDTH_ROW-1:0]    S1_RAS       =0 ;
logic [DDR3_WIDTH_CAS-1:0]    S1_CAS       =0 ;
logic [DDR3_RWDQ_BITS-1:0]    S1_WDATA     =0 ;
logic [DDR3_RWDQ_BITS/8-1:0]  S1_WMASK     =0 ;
logic                         S1_REF_REQ   =0 ;

logic                         S2_WENA      =0 ;
logic [DDR3_WIDTH_BANK-1:0]   S2_BANK      =0 ;
logic [DDR3_WIDTH_ROW-1:0]    S2_RAS       =0 ;
logic [DDR3_WIDTH_CAS-1:0]    S2_CAS       =0 ;
logic [DDR3_RWDQ_BITS-1:0]    S2_WDATA     =0 ;
logic [DDR3_RWDQ_BITS/8-1:0]  S2_WMASK     =0 ;
logic                         S2_REF_REQ   =0 ;

logic                         S3_WENA      =0 ;
logic [DDR3_WIDTH_BANK-1:0]   S3_BANK      =0 ;
logic [DDR3_WIDTH_ROW-1:0]    S3_RAS       =0 ;
logic [DDR3_WIDTH_CAS-1:0]    S3_CAS       =0 ;
logic [DDR3_RWDQ_BITS-1:0]    S3_WDATA     =0 ;
logic [DDR3_RWDQ_BITS/8-1:0]  S3_WMASK     =0 ;
logic                         S3_REF_REQ   =0 ;


logic                         S1_ready     =0, S2_ready     =0, S3_ready     =0, S4_ready     =0;
logic                         S1_ack       =0, S2_ack       =0, S3_ack       =0, S4_ack       =0;
logic                         S1_load      =0, S2_load      =0, S3_load      =0, S4_load      =0;
logic                         S1_busy      =0, S4_busy      =0;
(*preserve*) logic [DDR3_WIDTH_ROW-1:0]    bank_row_mem [0:(2**DDR3_WIDTH_BANK-1)] = '{default:'0} ; // A register of each bank's previously accessed row,
(*preserve*) logic [15:0]                  bank_mem_in_compare=0, row_in_compare=0 ;
//logic [3:0]                   S2_BANK_MATCH=0;
(*preserve*) logic                         S3_BANK_MATCH=0;

logic                         phold        =0;

(*preserve*) logic [2**DDR3_WIDTH_BANK-1:0] BANK_ACT     = 0 ; // True when a bank's row has been activated.  When set, a PRECHARGE
                                                               // is required before a new ACTIVATE command is requested on the same bank.
(*preserve*) logic                          BANK_ACT_ANY = 0 ; // This flag is cleared during a precharge all, and set during an activate command.

logic  [5:0]               idle_counter =0 ; // Timer for 
logic                      idle_reset   =0 ;

logic                      REF_REQ,IN_REF_REQ=0,IN_REF_LAT=0,IN_REF_LAT2=0,REF_HOLD=0;

logic                      IN_READ_RDY_tdl=0,S4_ready_t=0;

logic IN_ENA_dl,BUSY_t,IN_BUSY_int,IN_ENA_int,S4_ack_t;

// These are the output DDR3 command functions generated by this module.
// DDR3 command out wiring order {CS#,RAS#,CAS#,WE#}.
localparam bit [3:0] CMD_MRS  = 0  ;
localparam bit [3:0] CMD_REF  = 1  ;
localparam bit [3:0] CMD_PRE  = 2  ;
localparam bit [3:0] CMD_ACT  = 3  ;
localparam bit [3:0] CMD_WRI  = 4  ;
localparam bit [3:0] CMD_REA  = 5  ;
localparam bit [3:0] CMD_ZQC  = 6  ;
localparam bit [3:0] CMD_NOP  = 15 ; // Device NOP + deselect.

localparam bit [2:0] tx_prea_all  = 0 ;
localparam bit [2:0] tx_refresh   = 1 ;
localparam bit [2:0] tx_prea      = 2 ;
localparam bit [2:0] tx_activate  = 3 ;
localparam bit [2:0] tx_read      = 4 ;
localparam bit [2:0] tx_write     = 5 ;


localparam bit [7:0] TXB_MRS  = 8'b00000001 ;
localparam bit [7:0] TXB_REF  = 8'b00000010 ;
localparam bit [7:0] TXB_PRE  = 8'b00000100 ;
localparam bit [7:0] TXB_ACT  = 8'b00001000 ;
localparam bit [7:0] TXB_WRI  = 8'b00010000 ;
localparam bit [7:0] TXB_REA  = 8'b00100000 ;
localparam bit [7:0] TXB_ZQC  = 8'b01000000 ;
localparam bit [7:0] TXB_NOP  = 8'b10000000 ; // Device NOP + deselect.

logic                        vect_shift_out ;
logic [PORT_VECTOR_SIZE-1:0] vect_fifo_data_out;

(*preserve*) logic reset_latch,reset_latch2;
logic [3:0]                  RCP_h=0,RCP_l=0;


logic                         OUT_READ_READYp = 0 ;
logic [DDR3_RWDQ_BITS-1:0]    OUT_READ_DATAp  = 0 ;
logic [PORT_VECTOR_SIZE-1:0]  OUT_RD_VECTORp  = 0 ;


// **********************************************
// FIFO ram for the vector feed through.
// **********************************************
logic [PORT_VECTOR_SIZE-1:0] vector_pipe_mem   [0:15]  = '{default:'0} ;
logic [PORT_VECTOR_SIZE-1:0] OUT_RD_VECTOR_int         = 0             ;
logic [3:0]                  vwpos=0,vrpos=0;
logic                        load_vect = 0;
logic [PORT_VECTOR_SIZE-1:0] vect_data_dl = 0;

always_comb begin

// Read and load flags must be sorted in reverse order to simulate properly.
// This combinational logic generates the FIFO shifting pipe processor.

    // For stage 4, this generates a BUSY flag meaning that other commands need to be inserted into the output
    // before S3 should be allowed to send additional commands.

    REF_REQ = IN_REF_LAT != IN_REF_LAT2 ;

    if (S3_ready) begin
             if ( BANK_ACT_ANY  && S3_REF_REQ                 )  S4_busy = 1 ; // send_cmd(tx_prea_all);
        else if (!BANK_ACT_ANY  && S3_REF_REQ                 )  S4_busy = 0 ; // send_cmd(tx_refresh);
        else if (!S3_BANK_MATCH && BANK_ACT[S3_BANK] && !phold)  S4_busy = 1 ; // send_cmd(tx_prea);       // phold is set by the activate and cleared by a read or write.
        else if (!BANK_ACT[S3_BANK])                             S4_busy = 1 ; // send_cmd(tx_activate);   // phold prevents a precharge infinite loop as 'S3_BANK_MATCH'
        else                                                     S4_busy = 0 ; // send_cmd(tx_read/write); // will not change until the next read/write command comes in.
    end else S4_busy = 0 ;

    S4_ack_t  =  OUT_ACK  ;

    if (!USE_TOGGLE_OUT)  S4_ack    =  OUT_ACK  ;
    else                  S4_ack    =  S4_ack_t==S4_ready_t ; // translate the toggle input ack to positive logic logic ack.

    // Assign the earlier stage flags to operate like a FIFO or Elastic buffer which shows the output in advance of the '_read' signal.

    S4_load = (S3_ready && (!S4_ready || S4_ack) ) ;   // ***** The S4/3_ack  must be assigned first so the simulator knows the priority order of the sync chain.
    S3_ack  =  S4_load  && !S4_busy;
    //S3_busy =  S3_ready && !S3_ack  ;

    S3_load = (S2_ready && (!S3_ready || (S4_load && !S4_busy)) ) ;
    S2_ack  =  S3_load ;
    //S2_busy =  S2_ready && !S2_ack  ;

    S2_load = (S1_ready && (!S2_ready || S3_load) ) ;
    S1_ack  =  S2_load ;
    S1_busy =  S1_ready && !S1_ack  ;

    // Assign IO ports.
    IN_BUSY_int    =  S1_busy || REF_HOLD ;                    // Assign the command input busy flag to the output port IN_BUSY.

    if (USE_TOGGLE_ENA) IN_BUSY = BUSY_t ;                     // Select between toggle style IN_BUSY output and busy true or false.
    else                IN_BUSY = IN_BUSY_int ;

    if (USE_TOGGLE_ENA) IN_ENA_int = (IN_ENA != IN_ENA_dl) && !IN_BUSY_int ; // Select between toggle style IN_ENA input or true or false input.
    else                IN_ENA_int = IN_ENA ;
    
    S1_load        = (IN_ENA_int && !S1_busy) || IN_REF_REQ  ; // Assign the command enable input to S1_load, prevent a 'load' when the input is busy.
    
    if (!USE_TOGGLE_OUT)  OUT_READY  =  S4_ready   ;           // Assign the output ready flag to S4_ready
    else                  OUT_READY  =  S4_ready_t ;           // Assign the toggle version of the output ready.

    //row_in_compare = 16'(S1_RAS)         ;                     // For the compare done in stage 2, convert the x bits of RAS to a 16 bit wire for the 4x4 compare.
    row_in_compare = 16'(S2_RAS)         ;                     // For the compare done in stage 3, for all in 1 compare.

end // comb


// Generate an extra output latch layer to help increase FMAX when the extra speed parameter is enabled.
generate 
if (BHG_EXTRA_SPEED)    begin
                 always_ff @(posedge CLK)   begin
                                            OUT_READ_DATA    <= OUT_READ_DATAp  ;
                                            OUT_RD_VECTOR    <= OUT_RD_VECTORp  ;
                                            OUT_READ_READY   <= OUT_READ_READYp ;
                                            end
                        end else begin
                                            assign OUT_READ_DATA  = OUT_READ_DATAp  ;
                                            assign OUT_RD_VECTOR  = OUT_RD_VECTORp  ;
                                            assign OUT_READ_READY = OUT_READ_READYp ;
                        end
endgenerate


always_ff @(posedge CLK) begin
reset_latch  <= reset ;
reset_latch2 <= reset_latch ;
// ***************************************************************************************************************************
// Manage read data and read-calibration test pattern.
// Always latch read data to output regardless of reset so that the power-up sequence may analyze the read-calibration pattern
// ***************************************************************************************************************************
                                        IN_READ_RDY_tdl        <= IN_READ_RDY_t ;          // detect toggle change
                                        READ_CAL_PAT_t         <= IN_READ_RDY_tdl ;        // Toggle the read cal pattern toggle output
if (IN_READ_RDY_t != IN_READ_RDY_tdl)   OUT_READ_DATAp         <= IN_READ_DATA ;

for (int i=0 ; i<4 ; i++ ) begin
                            RCP_h[i] <= OUT_READ_DATAp[i*2*CAL_WIDTH           +: CAL_WIDTH] == {CAL_WIDTH{(1'b1)}} ;
                            RCP_l[i] <= OUT_READ_DATAp[i*2*CAL_WIDTH+CAL_WIDTH +: CAL_WIDTH] == {CAL_WIDTH{(1'b0)}} ;
                           end

READ_CAL_PAT_v <= ((RCP_h == 4'hf) && (RCP_l == 4'hf)) ;
// ***************************************************************************************************************************
// Vector FIFO memory FMAX accelerator by isolating it's read inside a 2nd layer LC for write and read.
// ***************************************************************************************************************************
                                            load_vect         <= (S1_load && !IN_REF_REQ && !IN_WENA) ;
                                            vect_data_dl      <= IN_RD_VECTOR ;
                                            OUT_RD_VECTOR_int <= vector_pipe_mem[vrpos] ; // Add a DFF latch stage to help improve FMAX performance. 
      if (IN_READ_RDY_t != IN_READ_RDY_tdl) OUT_RD_VECTORp    <= OUT_RD_VECTOR_int      ; // Select the DFF latch stage to help improve FMAX performance. 

// ***************************************************************************************************************************

if (reset_latch2) begin

    //bank_row_mem    <= '{default:'0} ; // Disabling this clear helps FMAX.
    BANK_ACT        <= 0 ;
    BANK_ACT_ANY    <= 0 ;
    phold           <= 0 ;

    S1_ready        <= 0 ;
    S2_ready        <= 0 ;
    S3_ready        <= 0 ;
    S4_ready        <= 0 ;
    S4_ready_t      <= 0 ;

    REF_HOLD        <= 0 ;
    IN_REF_REQ      <= 0 ;
    IN_REF_LAT      <= IN_REFRESH_t ;
    IN_REF_LAT2     <= IN_REF_LAT ;
    OUT_REFRESH_ack <= IN_REF_LAT2 ;

    OUT_CMD         <= CMD_NOP ;
    OUT_TXB         <= 0 ;

    OUT_READ_READYp <= 0 ;
    
    IN_ENA_dl       <= IN_ENA ;
    BUSY_t          <= IN_ENA ;
    
    vwpos           <= 0 ;
    vrpos           <= 0 ;

end else begin

// *************************************************************************
// Logic for handling IN_ENA/IN_BUSY if 'USE_TOGGLE_ENA' is enabled. 
// *************************************************************************

if (!IN_BUSY_int)  IN_ENA_dl   <= IN_ENA ;
if (!IN_BUSY_int)  BUSY_t      <= IN_ENA ;


// *************************************************************************
// Generate a output which goes high after 32 clocks of nothing happening.
// *************************************************************************
                               idle_reset      <= S2_ready ;  // Make sure a refresh doesn't affect the idle timer.
         if (idle_reset)       idle_counter    <= 6'd0 ;
    else if (!idle_counter[5]) idle_counter    <= idle_counter + 1'b1 ;
                               OUT_IDLE        <= idle_counter[5] ;

                               //  Latch refresh request.                               
                               IN_REF_LAT      <= IN_REFRESH_t ;
                               

    // Refresh management.  Sets up a sequence of events where external normal command
    // input is halted, wait for the halt to clear the last command, send a refresh
    // down the pipe, then release the halt.

    // Prevent refresh load if an external command is being sent, yet allow the insert of
    // the refresh during an existing busy port generated by the external commands saturating
    // the input.  This way, no request commands will be lost if a refresh and input
    // request com in at the same time.

         if (REF_REQ && !REF_HOLD && !S1_load) REF_HOLD    <= 1 ;
    else if (REF_HOLD && !S1_ready && !IN_REF_REQ) begin
                                IN_REF_REQ      <= 1;
                                IN_REF_LAT2     <= IN_REF_LAT ;
                                end
    else if (REF_HOLD && IN_REF_REQ)           IN_REF_REQ  <= 0 ;
    else if (REF_HOLD)                         REF_HOLD    <= 0 ; // Keep the hold for 1 extra clock before allowing new commands.

// *************************************************************************
// Stage 1, load input into registers, copy the previous accessed
// current requested BANK's row into the compare register and
// update the BANK's row register with the new row request one coming in.
// *************************************************************************
    if (S1_load) begin
                
                //bank_mem_in_compare     <= 16'(bank_row_mem [IN_BANK]) ;
                //bank_row_mem [IN_BANK]  <= IN_RAS ;

                S1_WENA                 <= IN_WENA          ;
                S1_BANK                 <= IN_BANK          ;
                S1_RAS                  <= IN_RAS           ;
                S1_CAS                  <= IN_CAS           ;
                S1_WDATA                <= IN_WDATA         ;
                S1_WMASK                <= IN_WMASK         ;
                S1_REF_REQ              <= IN_REF_REQ       ;
    end
// Generate S1_ready flag.
    if      (S1_load) S1_ready <= 1 ;
    else if (S1_ack ) S1_ready <= 0 ;

// *************************************************************************
// Stage 2, compare the previous accessed BANK's row with the
// new requested row coming in breaking the compare down
// into 4 blocks of 4x4 bits to generating 4 bit result
// to achieve the best possible FMAX.
// *************************************************************************
    if (S2_load) begin

                bank_mem_in_compare     <= 16'(bank_row_mem [S1_BANK]) ;
                bank_row_mem [S1_BANK]  <= S1_RAS ;

                S2_WENA                <= S1_WENA          ;
                S2_BANK                <= S1_BANK          ;
                S2_RAS                 <= S1_RAS           ;
                S2_CAS                 <= S1_CAS           ;
                S2_WDATA               <= S1_WDATA         ;
                S2_WMASK               <= S1_WMASK         ;
                S2_REF_REQ             <= S1_REF_REQ       ;

            //for (int i=0 ; i<4; i++) begin                 // Divide the bank match into 4x4bit chunks for top FMAX.
            //    S2_BANK_MATCH[i]       <= (bank_mem_in_compare[i*4 +:4] == row_in_compare[i*4 +:4]) ;
            //end
    end
// Generate S2_ready flag.
    if      (S2_load) S2_ready <= 1 ;
    else if (S2_ack ) S2_ready <= 0 ;

// *************************************************************************
// Stage 3, check if all the 4 bits of S2's match are
// equal and coalesce that into 1 register.
// *************************************************************************
    if (S3_load) begin
                S3_WENA                 <= S2_WENA          ;
                S3_BANK                 <= S2_BANK          ;
                S3_RAS                  <= S2_RAS           ;
                S3_CAS                  <= S2_CAS           ;
                S3_WDATA                <= S2_WDATA         ;
                S3_WMASK                <= S2_WMASK ^ ((DDR3_RWDQ_BITS/8)'(2**(DDR3_RWDQ_BITS/8)-1)) ; // *** Invert the mask in preparation for the DDR3.
                S3_REF_REQ              <= S2_REF_REQ       ;

                //S3_BANK_MATCH           <= (S2_BANK_MATCH==4'b1111) && !S2_REF_REQ ; // Test that the final 4 bit compare all match

                S3_BANK_MATCH           <= (bank_mem_in_compare == row_in_compare) && !S2_REF_REQ ; // Test that the final 4 bit compare all match
    end
// Generate S3_ready flag.
    if      (S3_load) S3_ready <= 1 ;
    else if (S3_ack ) S3_ready <= 0 ;

// *************************************************************************
// Stage 4, Generate commands
// *************************************************************************

    if (S4_load) begin
                OUT_BANK                <= S3_BANK          ;
                OUT_WDATA               <= S3_WDATA         ;
                OUT_WMASK               <= S3_WMASK         ;
    end

    if (S4_load ) begin
             if ( BANK_ACT_ANY  && S3_REF_REQ                 )   send_cmd(tx_prea_all);
        else if (!BANK_ACT_ANY  && S3_REF_REQ                 )   send_cmd(tx_refresh);
        else if (!S3_BANK_MATCH && BANK_ACT[S3_BANK] && !phold)   send_cmd(tx_prea);       // phold is set by the activate and cleared by a read or write.
        else if (!BANK_ACT[S3_BANK])                              send_cmd(tx_activate);   // phold prevents a precharge infinite loop as 'S3_BANK_MATCH'
        else if (!S3_WENA)                                        send_cmd(tx_read);       // will not change until the next read/write command comes in.
        else                                                      send_cmd(tx_write);
    end
// Generate S4_ready flag.
    if      (S4_load || S4_busy)  S4_ready <= 1 ;
    else if (S4_ack )             S4_ready <= 0 ;
// Generate S4_ready_t flag.
    if      ((S4_load || S4_busy) && (S4_ack_t==S4_ready_t))  S4_ready_t <= !S4_ready_t ;


// *************************************************************************
// *************************************************************************
// *************************************************************************
// DDR3 Read data & vector pipeline processing.
// *************************************************************************
// *************************************************************************
// *************************************************************************

    if (load_vect)                          begin                                     // A valid read command has been loaded
                                            vector_pipe_mem[vwpos] <= vect_data_dl ;  // load vector into pipe mem
                                            vwpos                  <= vwpos + 1'b1;   // increment write position.
                                            end

    if (IN_READ_RDY_t != IN_READ_RDY_tdl)   begin                                              // Read data from the DDR3 has returned a read.
                                            vrpos                  <= vrpos + 1'b1 ;           // increment read position.
                     if (!USE_TOGGLE_ENA)   OUT_READ_READYp        <= 1 ;                      // No toggle, turn on for 1 clock period.
                     else                   OUT_READ_READYp        <= !OUT_READ_READYp ;       // Toggle output mode.
            end else if (!USE_TOGGLE_ENA)   OUT_READ_READYp        <= 0 ;                      // No toggle, turn on for 1 clock period, IE turn off now.


  end // !reset
end // always


// *************************************************************************
// Send command tasks.
// *************************************************************************
task send_cmd (bit [2:0] cmd);
begin
    case (cmd)
    tx_refresh: begin
                phold             <= 1'b0        ; // no longer needed.
                OUT_CMD           <= CMD_REF     ;
                OUT_TXB           <= TXB_REF     ;
                OUT_REFRESH_ack   <= IN_REF_LAT2 ;
                end

    tx_prea_all:begin
                phold             <= 1'b0    ; // no longer needed.
                OUT_CMD           <= CMD_PRE ;
                OUT_TXB           <= TXB_PRE ;
                BANK_ACT          <= 0       ; // Deactivate all banks.
                BANK_ACT_ANY      <= 1'b0    ;
                OUT_A[10]         <= 1'b1    ; // All bank preacharge.
                end

    tx_prea   : begin
                phold             <= 1'b0    ; // no longer needed.
                OUT_CMD           <= CMD_PRE ;
                OUT_TXB           <= TXB_PRE ;
                BANK_ACT[S3_BANK] <= 1'b0    ; // Deactivate the precharged bank.
                OUT_A[10]         <= 1'b0    ; // Single bank preacharge.
                end

    tx_activate:begin
                phold             <= 1'b1    ; // Prevent a precharge/activate infinite loop.
                BANK_ACT[S3_BANK] <= 1'b1    ; // Activate the selected bank.
                BANK_ACT_ANY      <= 1'b1    ;
                OUT_A             <= S3_RAS  ; // Which row to activate.
                OUT_CMD           <= CMD_ACT ;
                OUT_TXB           <= TXB_ACT ;
                end

    tx_read   : begin
                phold             <= 1'b0    ; // no longer needed.
                SET_cas()                    ; // Output the CAS address on the DDR3 A bus.
                OUT_CMD           <= CMD_REA ;
                OUT_TXB           <= TXB_REA ;
                end

    tx_write  : begin
                phold             <= 1'b0    ; // no longer needed.
                SET_cas()                    ; // Output the CAS address on the DDR3 A bus.
                OUT_CMD           <= CMD_WRI ;
                OUT_TXB           <= TXB_WRI ;
                end
    endcase

end
endtask

// *************************************************************************
// Output the CAS address on the DDR3 A bus.
// *************************************************************************
task SET_cas();
    begin
    OUT_A[9:0]                        <= S3_CAS[9:0] ; // Column address at the beginning of a sequential burst
    if (DDR3_WIDTH_CAS==10) OUT_A[11] <= 1'b0        ; // Default 0 for additional column address.
    else                    OUT_A[11] <= S3_CAS[10]  ; // Assign the additional MSB Column address used in 4 bit DDR3 devices.
    OUT_A[10]                         <= 1'b0        ; // Disable AUTO-PRECHARGE.  We keep the banks open and precharge manually only when needed.
    OUT_A[12]                         <= 1'b1        ; // Set burst length to BL8.
    OUT_A[DDR3_WIDTH_ROW-1:13]        <= 0           ;
    end
endtask

endmodule
