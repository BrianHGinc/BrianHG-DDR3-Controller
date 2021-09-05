// *********************************************************************
//
// BrianHG_DDR3_COMMANDER_tb.sv multi-platform, multi-DMA-port (16 read and 16 write ports max) cache controller test bench.
// Version 1.00, August 22, 2021.
//
//
// Written by Brian Guralnick.
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
`timescale 1 ps/ 1 ps // 1 picosecond steps, 1 picosecond precision.

module BrianHG_DDR3_COMMANDER_tb #(

parameter int        sim_ddr_ack_delay       = 2   -2,           // 1 for first, 2 for sequential burst.  Test Bench Specific control, Defines the DDR3 controller ack delay.
parameter int        sim_ddr_read_delay      = 10  -2,           // 11 for first shot, 9-10 for sequential burst Test Bench Specific control, Defines the DDR3 read delay.


// ****************  System clock generation and operation.
parameter int        CLK_KHZ_IN              = 400000,            // PLL source input clock frequency in KHz.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_SIZE_GB            = 4,                // Use 0,1,2,4 or 8.  (0=512mb) Caution: Must be correct as ram chip size affects the tRFC REFRESH period.
parameter int        DDR3_WIDTH_DQ           = 8,//16,               // Use 8 or 16.  The width of each DDR3 ram chip.

parameter int        DDR3_NUM_CHIPS          = 1,                // 1, 2, or 4 for the number of DDR3 RAM chips.

parameter int        DDR3_WIDTH_ADDR         = 7,//15,               // Use for the number of bits to address each row.
parameter int        DDR3_WIDTH_BANK         = 1,//3,                // Use for the number of bits to address each bank.
parameter int        DDR3_WIDTH_CAS          = 8,//10,               // Use for the number of bits to address each column.

parameter int        DDR3_WIDTH_DM           = (DDR3_WIDTH_DQ*DDR3_NUM_CHIPS/8), // The width of the byte write data mask.

parameter string     BANK_ROW_ORDER          = "BANK_ROW_COL",   // Only supports "ROW_BANK_COL" or "BANK_ROW_COL".  Choose to optimize your memory access.

parameter int        PORT_ADDR_SIZE          = (DDR3_WIDTH_ADDR + DDR3_WIDTH_BANK + DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)),

// ************************************************************************************************************************************
// ****************  BrianHG_DDR3_COMMANDER configuration parameter settings.
parameter int        PORT_R_TOTAL            = 2,                // Set the total number of DDR3 controller read ports, 1 to 16 max.
parameter int        PORT_W_TOTAL            = 2,                // Set the total number of DDR3 controller write ports, 1 to 16 max.
parameter int        PORT_VECTOR_SIZE        = 8,//32,               // Sets the width of each port's VECTOR input and output

// ************************************************************************************************************************************
// ***** DO NOT CHANGE THE NEXT 4 PARAMETERS FOR THIS VERSION OF THE BrianHG_DDR3_COMMANDER.sv... *************************************
parameter int        PORT_CACHE_BITS         = (8*DDR3_WIDTH_DM*8),                  // Note that this value must be a multiple of ' (8*DDR3_WIDTH_DQ*DDR3_NUM_CHIPS)* burst 8 '.
parameter int        CACHE_ADDR_WIDTH        = $clog2(PORT_CACHE_BITS/8),            // This is the number of LSB address bits which address all the available 8 bit bytes inside the cache word.
parameter int        DDR3_VECTOR_SIZE        = (PORT_ADDR_SIZE+4),                   // Sets the width of the VECTOR for the DDR3_PHY_SEQ controller.  4 bits for 16 possible read ports.
parameter int        CACHE_ROW_BASE          = (DDR3_WIDTH_CAS + (DDR3_WIDTH_DM-1)), // Sets the starting address bit where a new row & bank begins.
// ************************************************************************************************************************************

// PORT_'feature' = '{array a,b,c,d,..} Sets the feature for each DDR3 ram controller interface port 0 to port 15.
parameter bit [8:0]  PORT_R_DATA_WIDTH    [0:15] = '{  8,  8, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64}, 
parameter bit [8:0]  PORT_W_DATA_WIDTH    [0:15] = '{  8,  8, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64}, 
                                                            // Use 8,16,32,64,128, or 256 bits, maximum = 'PORT_CACHE_BITS'
                                                            // As a precaution, this will prune/ignore unused data bits and write masks bits, however,
                                                            // all the data ports will still be 'PORT_CACHE_BITS' bits and the write masks will be 'PORT_CACHE_WMASK' bits.
                                                            // (a 'PORT_CACHE_BITS' bit wide data bus has 32 individual mask-able bytes (8 bit words))
                                                            // For ports sizes below 'PORT_CACHE_BITS', the data is stored and received in Big Endian.  

parameter bit [2:0]  PORT_R_PRIORITY      [0:15] = '{  1,  1,  1,  2,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
parameter bit [2:0]  PORT_W_PRIORITY      [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
                                                            // Use 1 through 6 for normal operation.  Use 7 for above refresh priority.  Use 0 for bottom
                                                            // priority, only during free cycles once every other operation has been completed.
                                                            // Open row policy/smart row access only works between ports with identical
                                                            // priority.  If a port with a higher priority receives a request, even if another
                                                            // port's request matches the current page, the higher priority port will take
                                                            // president and force the ram controller to leave the current page.
                                                            // *(Only use 7 for small occasional access bursts which must take president above
                                                            //   all else, yet not consume memory access beyond the extended refresh requirements.)

parameter bit        PORT_R_CMD_STACK     [0:15] = '{  1,  1,  1,  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
                                                            // Sets the size of the intermediate read command request stack.
                                                            // 0=4 level deep.  1=8 level deep.
                                                            // The size of the number of read commands built up in advance while the read channel waits
                                                            // for the DDR3_PHY_SEQ to return the read request data.  (Stored in logic cells)
                                                            // Multiple reads must be accumulated to allow an efficient continuous read burst.
                                                            // IE: Use 8 level deep when running a small data port width like 8 or 16 so sequential read cache
                                                            // hits continue through the command input allowing cache miss read req later-on in the req stream to be
                                                            // immediately be sent to the DDR3_PHY_SEQ before the DDR3 even returns the first read req data.

parameter bit [8:0]  PORT_W_CACHE_TOUT    [0:15] = '{ 64, 32, 16,  4, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64},
                                                            // A timeout for the write cache to dump it's contents to ram.
                                                            // 0   = immediate writes, or no write cache.
                                                            // 255 = Wait up to 255 CMD_CLK clock cycles since the previous write req.
                                                            //       to the same 'PORT_CACHE_BITS' bit block before writing to ram.  Write reqs outside
                                                            //       the current 'PORT_CACHE_BITS' bit cache block clears the timer and forces an immediate write.

parameter bit        PORT_CACHE_SMART     [0:15] = '{  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1},
                                                            // When enabled, if an existing read cache exists at the same write request address,
                                                            // that read's cache will immediately be updated with the new write data.  (Only on the same port number...)
                                                            // This function may impact the FMAX for the system clock and increase LUT usage.
                                                            // *** Disable when designing a memory read/write testing algorithm.

parameter bit [8:0]  PORT_R_MAX_BURST     [0:15] = '{256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256},
parameter bit [8:0]  PORT_W_MAX_BURST     [0:15] = '{256,256,256,256,256,256,256,256,256,256,256,256,256,256,256,256},
                                                            // 1 through 256, 0=No sequential burst priority.
                                                            // Defines the maximum consecutive read or write burst commands from a single
                                                            // port if another read/write port requests exists with the same priority level,
                                                            // but their memory request exist in a different row.  * Every 1 counts for a BL8 burst.
                                                            // This will prevent a single continuous stream port from hogging up all the ram access time.
                                                            // IE: If set to 0, commander will seek if other read/write requests are ready before
                                                            // continuing access to the same port DDR3 access.

parameter bit        SMART_BANK                  = 1        // 1=ON, 0=OFF, With SMART_BANK enabled, the BrianHG_DDR3_COMMANDER will remember which
                                                            // ROW# has been activated in each DDR3 BANK# so that when prioritizing read and write
                                                            // ports of equal priority, multiple commands across multiple banks whose ROWs have
                                                            // matching existing activation will be prioritized/coalesced as if they were part of
                                                            // the sequential burst as PRECHARGE and ACTIVATE commands are not needed when bursting
                                                            // between active banks maintaining an unbroken read/write stream.
                                                            // (Of course the BrianHG_DDR3_PHY_SEQ is able to handle smart banking as well...)
                                                            // Note that enabling this feature uses additional logic cells and may impact FMAX.
                                                            // Disabling this feature will only coalesce commands in the current access ROW.
                                                            // Parameter 'BANK_ROW_ORDER' will define which address bits define the accessed BANK number.
)(
RST_IN,    // Reset input
RESET,       PLL_LOCKED,
CLK_IN,
DDR3_CLK,    DDR3_CLK_DQS, DDR3_CLK_RDQ, CMD_CLK,

// ********** Commands to DDR3_COMMANDER
CMD_W_busy,      CMD_write_req,  CMD_waddr,            CMD_wdata,           CMD_wmask,   CMD_W_priority_boost,
CMD_R_busy,      CMD_read_req,   CMD_raddr,            CMD_read_vector_in,
CMD_read_ready,  CMD_read_data,  CMD_read_vector_out,  CMD_read_addr_out,                CMD_R_priority_boost,

// ********** Commands to DDR3_PHY_SEQ.
SEQ_CMD_ENA_t,  SEQ_WRITE_ENA,
SEQ_ADDR,       SEQ_WDATA,       SEQ_WMASK,  SEQ_RDATA_VECT_IN,   SEQ_refresh_hold,
SEQ_BUSY_t,     SEQ_RDATA_RDY_t, SEQ_RDATA,  SEQ_RDATA_VECT_OUT,  SEQ_refresh_queue,

// ********** Diagnostic flags.
SEQ_CAL_PASS, DDR3_READY );


// ********************************************************************************************
// Test bench IO logic.
// ********************************************************************************************
string     TB_COMMAND_SCRIPT_FILE = "DDR3_COMMAND_script.txt";	 // Choose one of the following strings...
string                Script_CMD  = "*** POWER_UP ***" ; // Message line in waveform
logic [12:0]          Script_LINE = 0  ; // Message line in waveform

input  logic RST_IN,CLK_IN;
output logic RESET,PLL_LOCKED,DDR3_CLK,DDR3_CLK_DQS,DDR3_CLK_RDQ,CMD_CLK;

// ****************************************
// DDR3 commander interface.
// ****************************************
output logic                         CMD_R_busy          [0:PORT_R_TOTAL-1];  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.
output logic                         CMD_W_busy          [0:PORT_W_TOTAL-1];  // For each port, when high, the DDR3 controller will not accept an incoming command on that port.


output logic                         CMD_write_req       [0:PORT_W_TOTAL-1];  // Write request for each port.

output logic [PORT_ADDR_SIZE-1:0]    CMD_waddr           [0:PORT_W_TOTAL-1];  // Address pointer for each write memory port.
output logic [PORT_CACHE_BITS-1:0]   CMD_wdata           [0:PORT_W_TOTAL-1];  // During a 'CMD_write_req', this data will be written into the DDR3 at address 'CMD_addr'.
                                                                              // Each port's 'PORT_DATA_WIDTH' setting will prune the unused write data bits.
output logic [PORT_CACHE_BITS/8-1:0] CMD_wmask           [0:PORT_W_TOTAL-1];  // Write mask for the individual bytes within the 256 bit data bus.
                                                                              // When low, the associated byte will not be written.
                                                                              // Each port's 'PORT_DATA_WIDTH' setting will prune the unused mask bits.


output logic [PORT_ADDR_SIZE-1:0]    CMD_raddr           [0:PORT_R_TOTAL-1];  // Address pointer for each read memory port.
output logic                         CMD_read_req        [0:PORT_R_TOTAL-1];  // Performs a read request for each port.
output logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_in  [0:PORT_R_TOTAL-1];  // The contents of the 'CMD_read_vector_in' during a 'CMD_read_req' will be sent to the
                                                                              // 'CMD_read_vector_out' in parallel with the 'CMD_read_data' during the 'CMD_read_ready' pulse.

output logic                         CMD_read_ready      [0:PORT_R_TOTAL-1];  // Goes high for 1 clock when the read command data is valid.
output logic [PORT_CACHE_BITS-1:0]   CMD_read_data       [0:PORT_R_TOTAL-1];  // Valid read data when 'CMD_read_ready' is high.
output logic [PORT_VECTOR_SIZE-1:0]  CMD_read_vector_out [0:PORT_R_TOTAL-1];  // Returns the 'CMD_read_vector_in' which was sampled during the 'CMD_read_req' in parallel
                                                                              // with the 'CMD_read_data'.  This allows for multiple post reads where the output
                                                                              // has a destination pointer. 
output logic [PORT_ADDR_SIZE-1:0]    CMD_read_addr_out   [0:PORT_R_TOTAL-1];  // A return of the address which was sent in with the read request.


output logic                        CMD_R_priority_boost [0:PORT_R_TOTAL-1];  // Boosts the port's 'PORT_R_PRIORITY' parameter by a weight of 8 when set.
output logic                        CMD_W_priority_boost [0:PORT_W_TOTAL-1];  // Boosts the port's 'PORT_W_PRIORITY' parameter by a weight of 8 when set.


output logic                                        SEQ_CMD_ENA_t;
output logic                                        SEQ_WRITE_ENA;
output logic [PORT_ADDR_SIZE-1:0]                   SEQ_ADDR;
output logic [PORT_CACHE_BITS-1:0]                  SEQ_WDATA;
output logic [PORT_CACHE_BITS/8-1:0]                SEQ_WMASK;
output logic [DDR3_VECTOR_SIZE-1:0]                 SEQ_RDATA_VECT_IN;  // Embed multiple read request returns into the SEQ_RDATA_VECT_IN.
output logic                                        SEQ_refresh_hold;

output logic                                        SEQ_BUSY_t;
output logic                                        SEQ_RDATA_RDY_t;
output logic [PORT_CACHE_BITS-1:0]                  SEQ_RDATA;
output logic [DDR3_VECTOR_SIZE-1:0]                 SEQ_RDATA_VECT_OUT;
output logic [3:0]                                  SEQ_refresh_queue;

output logic                                        SEQ_CAL_PASS;
output logic                                        DDR3_READY;


localparam      period   = 500000000/CLK_KHZ_IN ;
localparam      STOP_uS  = 1000000 ;
localparam      endtime  = STOP_uS * 10;


// **********************************************************************************************************************
// This module is the smart cache multi-port controller which commands the BrianHG_DDR3_PHY_SEQ ram controller.
// **********************************************************************************************************************
BrianHG_DDR3_COMMANDER  #(.DDR3_SIZE_GB        (DDR3_SIZE_GB),        .DDR3_WIDTH_DQ       (DDR3_WIDTH_DQ),      .DDR3_NUM_CHIPS      (DDR3_NUM_CHIPS),
                          .DDR3_WIDTH_ADDR     (DDR3_WIDTH_ADDR),     .DDR3_WIDTH_BANK     (DDR3_WIDTH_BANK),    .DDR3_WIDTH_CAS      (DDR3_WIDTH_CAS),
                          .DDR3_WIDTH_DM       (DDR3_WIDTH_DM),       .BANK_ROW_ORDER      (BANK_ROW_ORDER),

                          .PORT_R_TOTAL        (PORT_R_TOTAL),        .PORT_W_TOTAL        (PORT_W_TOTAL),       .PORT_VECTOR_SIZE    (PORT_VECTOR_SIZE),
                          .PORT_R_DATA_WIDTH   (PORT_R_DATA_WIDTH),   .PORT_W_DATA_WIDTH   (PORT_W_DATA_WIDTH),
                          .PORT_R_PRIORITY     (PORT_R_PRIORITY),     .PORT_W_PRIORITY     (PORT_W_PRIORITY),    .PORT_R_CMD_STACK    (PORT_R_CMD_STACK),
                          .PORT_CACHE_SMART    (PORT_CACHE_SMART),    .PORT_W_CACHE_TOUT   (PORT_W_CACHE_TOUT),
                          .PORT_R_MAX_BURST    (PORT_R_MAX_BURST),    .PORT_W_MAX_BURST    (PORT_W_MAX_BURST),   .SMART_BANK          (SMART_BANK)
) DUT_COMMANDER (
                          // *** Interface command port. ***
                          .RST_IN              (RESET               ),                          .CMD_CLK              (CMD_CLK             ),

                          // *** DDR3 Commander functions ***
                          .CMD_W_busy          (CMD_W_busy          ),                          .CMD_write_req        (CMD_write_req       ),
                          .CMD_waddr           (CMD_waddr           ),                          .CMD_wdata            (CMD_wdata           ),
                          .CMD_wmask           (CMD_wmask           ),                          .CMD_W_priority_boost (CMD_W_priority_boost),

                          .CMD_R_busy          (CMD_R_busy          ),                          .CMD_read_req         (CMD_read_req        ),
                          .CMD_raddr           (CMD_raddr           ),                          .CMD_read_vector_in   (CMD_read_vector_in  ),
                          .CMD_read_ready      (CMD_read_ready      ),                          .CMD_read_data        (CMD_read_data       ),
                          .CMD_read_vector_out (CMD_read_vector_out ),                          .CMD_read_addr_out    (CMD_read_addr_out   ),
                          .CMD_R_priority_boost(CMD_R_priority_boost),

                          // *** Controls which send commands to the BrianHG_DDR3_PHY_SEQ. ***
                          .SEQ_CMD_ENA_t       (SEQ_CMD_ENA_t),       .SEQ_WRITE_ENA       (SEQ_WRITE_ENA),      .SEQ_ADDR            (SEQ_ADDR),
                          .SEQ_WDATA           (SEQ_WDATA),           .SEQ_WMASK           (SEQ_WMASK),          .SEQ_RDVEC_TO_DDR3   (SEQ_RDATA_VECT_IN),
                          .SEQ_refresh_hold    (SEQ_refresh_hold),
  
                          // *** Results returned from the BrianHG_DDR3_PHY_SEQ. ***
                          .DDR3_READY          (DDR3_READY),          .SEQ_CAL_PASS        (SEQ_CAL_PASS),
                          .SEQ_BUSY_t          (SEQ_BUSY_t),          .SEQ_RDATA_RDY_t     (SEQ_RDATA_RDY_t),    .SEQ_RDATA           (SEQ_RDATA),
                          .SEQ_RDVEC_FROM_DDR3 (SEQ_RDATA_VECT_OUT) );

// ***********************************************************************************************

//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************

localparam int               MEM_ADDR_SHIFT           = CACHE_ADDR_WIDTH ;                      // This tells how much to shift the ram read and write address.
localparam int               MEM_SIZE                 = 8192 ; // 2**(PORT_ADDR_SIZE-MEM_ADDR_SHIFT) ;    // This contains the number of words in the addressable ram, not the bytes.
logic [PORT_CACHE_BITS-1:0]  HUNK_MEM [0:MEM_SIZE-1] ;                                          // A block of memory to simulate the DDR3_PHY_SEQ module connected to a DDR3 ram chip.


logic       [7:0]            WDT_COUNTER;                                                       // Wait for 15 clocks or inactivity before forcing a simulation stop.
logic                        WAIT_IDLE        = 0;                                              // When high, insert a idle wait before every command.
localparam int               WDT_RESET_TIME   = 255;                                            // Set the WDT timeout clock cycles.
localparam int               SYS_IDLE_TIME    = WDT_RESET_TIME-64;                              // Consider system idle after 12 clocks of inactivity.
localparam real              DDR3_CK_MHZ_REAL = CLK_KHZ_IN / 1000 ;                             // Generate the DDR3 CK clock frequency.
localparam real              DDR3_CK_pERIOD   = 1000 / DDR3_CK_MHZ_REAL ;                       // Generate the DDR3 CK period in nanoseconds.
                            
logic                        seq_read_ena        [0:sim_ddr_read_delay] ;
logic [PORT_ADDR_SIZE-1:0]   seq_read_buf_addr   [0:sim_ddr_read_delay] ;
logic [DDR3_VECTOR_SIZE-1:0] seq_read_buf_vec    [0:sim_ddr_read_delay] ;
logic [sim_ddr_ack_delay:0]  SEQ_BUSY_DLY ; 

initial begin
WDT_COUNTER       = WDT_RESET_TIME  ; // Set the initial inactivity timer to maximum so that the code later-on wont immediately stop the simulation.


//for (int i=0 ; i<(MEM_SIZE*4) ; i+=4) HUNK_MEM[(i/4)] = {16'(i+0),16'(i+1),16'(i+2),16'(i+3)} ; // Fill ram with dummy memory.
for (int i=0 ; i<(MEM_SIZE*8) ; i+=8) HUNK_MEM[(i/8)] = {8'(i+0),8'(i+1),8'(i+2),8'(i+3),8'(i+4),8'(i+5),8'(i+6),8'(i+7)} ; // Fill ram with dummy memory.
//for (int i=0 ; i<(MEM_SIZE*8) ; i+=8) HUNK_MEM[(i/8)] = {8'(i+7),8'(i+6),8'(i+5),8'(i+4),8'(i+3),8'(i+2),8'(i+1),8'(i+0)} ; // Fill ram with dummy memory.

for (int i=0 ; i<PORT_R_TOTAL ; i++) begin
                                        CMD_read_req[i]          = 0 ; // Clear all the read requests.
                                        CMD_raddr[i]             = 0 ; // Clear all the read requests.
                                        CMD_read_vector_in[i]    = 0 ; // Clear all the read requests.
                                        CMD_R_priority_boost[i]  = 0 ; // Clear all the read requests.
                                     end
for (int i=0 ; i<PORT_W_TOTAL ; i++) begin
                                        CMD_write_req[i]         = 0 ; // Clear all the write requests.
                                        CMD_waddr[i]             = 0 ; // Clear all the write requests.
                                        CMD_wdata[i]             = 0 ; // Clear all the write requests.
                                        CMD_wmask[i]             = 0 ; // Clear all the write requests.
                                        CMD_W_priority_boost[i]  = 0 ; // Clear all the write requests.
                                     end

// Simulate results from local 'dummy' DDR3_PHY_SEQ so that the DDR3_COMMANDER can be tested on it's own
DDR3_READY          = 0 ; // Tie this to !reset for this simulation
SEQ_CAL_PASS        = 0 ; // Tie this to !reset for this simulation
//SEQ_BUSY_t          = 0 ; // Tie this with a 1 CMD_CLK clock delay to the driven SEQ_CMD_ENA_t to simulate a 1 cycle access delay.


SEQ_RDATA_RDY_t     = 0 ; // Tie these next 3 to a simulated memory block's read with a 2 clock delay.
SEQ_RDATA           = 0 ;
SEQ_RDATA_VECT_OUT  = 0 ;
SEQ_BUSY_DLY        = 0 ;

for (int i=0 ; i<=sim_ddr_read_delay ; i++) begin
seq_read_ena     [i] = 0 ;
seq_read_buf_addr[i] = 0 ;
seq_read_buf_vec [i] = 0 ;
end


RST_IN = 1'b1 ; // Reset input
CLK_IN = 1'b1 ;
#(50000);
RST_IN = 1'b0 ; // Release reset at 50ns.

while (!PLL_LOCKED) @(negedge CMD_CLK);
execute_ascii_file(TB_COMMAND_SCRIPT_FILE);

end

always #period                  CLK_IN = !CLK_IN;                                             // create source clock oscillator
always @(posedge CLK_IN)   WDT_COUNTER = (SEQ_BUSY_t!=SEQ_CMD_ENA_t ) ? WDT_RESET_TIME : (WDT_COUNTER-1'b1) ;   // Setup a simulation inactivity watchdog countdown timer.
always @(posedge CLK_IN) if (WDT_COUNTER==0) begin
                                             Script_CMD  = "*** WDT_STOP ***" ;
                                             $stop;                                           // Automatically stop the simulation if the inactivity timer reaches 0.
                                             end
always_comb SEQ_BUSY_t = SEQ_BUSY_DLY[sim_ddr_ack_delay] ;
always_comb CMD_CLK    = CLK_IN ;
always_comb RESET      = RST_IN ;
always_comb PLL_LOCKED = !RST_IN ;

always @(posedge CMD_CLK) begin
DDR3_READY   <= !RESET; // make ready high when reset goes low.
SEQ_CAL_PASS <= !RESET; // make ready high when reset goes low.


SEQ_BUSY_DLY[sim_ddr_ack_delay:0] <= {SEQ_BUSY_DLY[sim_ddr_ack_delay-1:0],SEQ_CMD_ENA_t} ; // Simulate the activity of the SEQ_BUSY_t output of the DDR3_PHY_SEQ module taking 2 clocks to respond to a command

// ****************************  Simulate a write to ram based on DDR3_COMMANDER's outputs to the 
    if ( SEQ_BUSY_DLY[0] != SEQ_CMD_ENA_t ) begin // A new command has been detected.

            if (SEQ_WRITE_ENA) begin // A write command has been detected
            
                seq_read_ena     [0] <= 0 ; // Pipe through the read command enable pulse.
                
                if ((SEQ_ADDR>>MEM_ADDR_SHIFT) < MEM_SIZE ) begin // protect against write outside allocated hunk_mem
                        for (int i=0 ; i<(DDR3_WIDTH_DM*8) ; i++) begin                         // Only write the mask enabled bits
                            if (SEQ_WMASK[i]==1) HUNK_MEM[SEQ_ADDR>>MEM_ADDR_SHIFT][(i*8) +: 8] <= SEQ_WDATA[(i*8) +: 8] ;// ****** Write to the simulated DDR3 ram inside the register array HUNK_MEM.
                        end
                end // protect against write outside allocated hunk_mem
                
            end else begin // end of a write command...

                // This is an added phony delay for the read stage to simulate the read delay pipe from the DDR3_PHY.
                
                seq_read_ena     [0] <= 1 ;                // Pipe through the read command enable pulse.
                seq_read_buf_addr[0] <= SEQ_ADDR ;         // Pipe through the read address.
                seq_read_buf_vec [0] <= SEQ_RDATA_VECT_IN; // Pipe through the read vector input.

            end // end of a read command...

    end else begin

                seq_read_ena     [0] <= 0 ; // Pipe through the read command enable pulse.
                //seq_read_buf_addr[0] <= 0 ; // Pipe through the read address.
                //seq_read_buf_vec [0] <= 0 ; // Pipe through the read vector input.

    end // no command being sent

                seq_read_ena     [1:sim_ddr_read_delay] <= seq_read_ena     [0:sim_ddr_read_delay-1] ; // Pipe through the read command enable pulse.
                seq_read_buf_addr[1:sim_ddr_read_delay] <= seq_read_buf_addr[0:sim_ddr_read_delay-1] ; // Pipe through the read address.
                seq_read_buf_vec [1:sim_ddr_read_delay] <= seq_read_buf_vec [0:sim_ddr_read_delay-1] ; // Pipe through the read vector input.


    // ****** Read back the simulated DDR3 ram inside the register array HUNK_MEM.

    if ( seq_read_ena[sim_ddr_read_delay] )   SEQ_RDATA_RDY_t    <= !SEQ_RDATA_RDY_t ; // Toggle read data flag to simulate the way the DDR3_PHY_SEQ cycles the rdata ready flag.

    if ( seq_read_ena[sim_ddr_read_delay] && ((seq_read_buf_addr[sim_ddr_read_delay]>>MEM_ADDR_SHIFT) < MEM_SIZE) ) begin // protect against read outside allocated hunk_mem
                SEQ_RDATA          <= HUNK_MEM[seq_read_buf_addr[sim_ddr_read_delay]>>MEM_ADDR_SHIFT] ;                   // send out the HUNK_MEM from the requested read address.
    end

    SEQ_RDATA_VECT_OUT <= seq_read_buf_vec [sim_ddr_read_delay] ;  // return the read data vector which was issued during the read request command.

end // @(posedge CMD_CLK)



// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// task execute_ascii_file(<"source ASCII file name">);
// 
// Opens the ASCII file and scans for the '@' symbol.
// After each '@' symbol, a string is read as a command function.
// Each function then goes through a 'case(command_in)' which then executes the appropriate function.
//
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************

task execute_ascii_file(string source_file_name);
 begin
    integer fin_pointer,fout_pointer,fin_running,r;
    string  command_in,message_string,destination_file_name,bmp_file_name;

    byte    unsigned    char        ;
    byte    unsigned    draw_color  ;
    integer unsigned    line_number ;

    line_number  = 1;
    fout_pointer = 0;

    fin_pointer= $fopen(source_file_name, "r");
    if (fin_pointer==0)
    begin
       $display("Could not open file '%s' for reading",source_file_name);
       $stop;     
    end

while (fin_pointer!=0 && ! $feof(fin_pointer)) begin // Continue processing until the end of the source file.

  char = 0;
  while (char != "@" && ! $feof(fin_pointer) && fin_pointer!=0 ) begin // scan for the @ character until end of source file.
  char = $fgetc(fin_pointer);
  if (char==0 || fin_pointer==0 )  $stop;                               // something went wrong
  if (char==10) line_number = line_number + 1;       // increment the internal source file line counter.
  end


if (! $feof(fin_pointer) ) begin  // if not end of source file retrieve command string

  r = $fscanf(fin_pointer,"%s",command_in); // Read in the command string after the @ character.
  if (fout_pointer!=0) $fwrite(fout_pointer,"Line#%d, ",13'(line_number)); // :pg the executed command line number.

  case (command_in) // select command string.

  "CMD"        : begin
                 tx_DDR3_cmd(fin_pointer, fout_pointer, line_number);
                 end

  "RESET"      : begin
                 Script_LINE = line_number;
                 Script_CMD  = command_in;
                 send_rst();                                          // pulses the reset signal for 1 clock.
                 if (fout_pointer!=0) $fwrite(fout_pointer,"Sending a reset to the BrianHG_DDR3_PHY_SEQ module.\n");
                 end

  "WAIT_SEQ_READY" : begin
                 Script_LINE = line_number;
                 Script_CMD  = command_in;
                 wait_rdy();                                          // pulses the reset signal for 1 clock.
                 if (fout_pointer!=0) $fwrite(fout_pointer,"Waiting for the BrianHG_DDR3_PHY_SEQ module to become ready.\n");
                 end

  "LOG_FILE"   : begin                                                  // begin logging the results.
                   if (fout_pointer==0) begin
                   r = $fscanf(fin_pointer,"%s",destination_file_name); // Read file name for the log file
                     fout_pointer= $fopen(destination_file_name,"w");   // Open that file name for writing.
                     if (fout_pointer==0) begin
                          $display("\nCould not open log file '%s' for writing.\n",destination_file_name);
                          $stop;
                     end else begin
                     $fwrite(fout_pointer,"Log file requested in '%s' at line#%d.\n\n",source_file_name,13'(line_number));
                     end
                   end else begin
                     $sformat(message_string,"\n*** Error in command script at line #%d.\n    You cannot open a LOG_FILE since the current log file '%s' is already running.\n    You must first '@END_LOG_FILE' if you wish to open a new log file.\n",13'(line_number),destination_file_name);
                     $display("%s",message_string);
                     $fclose(fin_pointer);
                     if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                     if (fout_pointer!=0) $fclose(fout_pointer);
                     $stop;
                   end
                 end

  "END_LOG_FILE" : if (fout_pointer!=0)begin                           // Stop logging the commands and close the current log file.
                       $sformat(message_string,"@%s command at line number %d.\n",command_in,13'(line_number));
                       $display("%s",message_string);
                       $fwrite(fout_pointer,"%s",message_string);
                       $fclose(fout_pointer);
                       fout_pointer = 0;
                   end

  "STOP"       :  begin // force a temporary stop.
                  $sformat(message_string,"@%s command at line number %d.\nType 'Run -All' to continue.",command_in,13'(line_number));
                  $display("%s",message_string);
                  if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                  $stop;
                  end

  "END"        :  begin // force seek to the end of the source file.

                 wait_idle();

                  $sformat(message_string,"@%s command at line number %d.\n",command_in,13'(line_number));
                  $display("%s",message_string);
                  $fclose(fin_pointer);
                  if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                  fin_pointer = 0;
                  end

  default      :  begin // Unknown command
                  $sformat(message_string,"Source ASCII file '%s' has an unknown command '@%s' at line number %d.\nProcessign stopped due to error.\n",source_file_name,command_in,13'(line_number));
                  $display("%s",message_string);
                  if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
                  $stop;
                  end
  endcase

end // if !end of source file

end// while not eof


// Finished reading source file.  Close files and stop.
while ((WDT_COUNTER >= SYS_IDLE_TIME )) @(negedge CMD_CLK); // wait for busy to clear
Script_CMD  = "*** END of script file. ***" ;

$sformat(message_string,"\nEnd of command source ASCII file '%s'.\n%d lines processed.\n",source_file_name,13'(line_number));
$display("%s",message_string);
$fclose(fin_pointer);
if (fout_pointer!=0) $fwrite(fout_pointer,"%s",message_string);
if (fout_pointer!=0) $fclose(fout_pointer);
fin_pointer  = 0;
fout_pointer = 0;
end
endtask





// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// task send_rst();
// 
// sends a reset.
//
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
task send_rst();
begin
@(negedge CLK_IN); 
RST_IN = 1;
@(negedge CLK_IN); 
@(negedge CLK_IN); 
@(negedge CLK_IN); 
@(negedge CLK_IN); 
RST_IN = 0;
@(negedge CLK_IN);

@(posedge CMD_CLK); // Re-sync to CMD_CLK.

wait_rdy();

@(negedge CMD_CLK);
end
endtask

// ***********************************************************************************************************
// task wait_rdy();
// Wait for DUT_GEOFF input buffer ready.
// ***********************************************************************************************************
task wait_rdy();
begin
  //while (SEQ_BUSY_t) @(negedge CMD_CLK); // wait for busy to clear
  while (SEQ_BUSY_t!=SEQ_CMD_ENA_t || !DDR3_READY || RESET) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
end
endtask

// ***********************************************************************************************************
// task tx_r_cmd(integer dest,string msg,integer ln);
// ***********************************************************************************************************
task tx_r_cmd(integer dest,string msg,integer ln, integer port);
begin

    while (CMD_R_busy[port]==1) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
    WDT_COUNTER          = WDT_RESET_TIME ; // Reset the watchdog timer.

    Script_LINE = ln;
    Script_CMD  = msg;
    if (dest!=0) $fwrite(dest,"%s",msg);
    CMD_read_req[port] = 1;
    @(negedge CMD_CLK);
    CMD_read_req[port] = 0;
end
endtask
// ***********************************************************************************************************
// task tx_w_cmd(integer dest,string msg,integer ln, integer port);
// ***********************************************************************************************************
task tx_w_cmd(integer dest,string msg,integer ln, integer port);
begin

    while (CMD_W_busy[port]==1) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
    WDT_COUNTER          = WDT_RESET_TIME ; // Reset the watchdog timer.

    Script_LINE = ln;
    Script_CMD  = msg;
    if (dest!=0) $fwrite(dest,"%s",msg);
    CMD_write_req[port] = 1;
    @(negedge CMD_CLK);
    CMD_write_req[port] = 0;
end
endtask

// ***********************************************************************************************************
// task wait_idle();
// ***********************************************************************************************************
task wait_idle();
begin
Script_CMD = "Waiting for last command to finish.";
  while (WDT_COUNTER > SYS_IDLE_TIME) @(negedge CMD_CLK); // wait for busy to clear
  WDT_COUNTER          = WDT_RESET_TIME ; // Reset the watchdog timer.
end
endtask


// ***********************************************************************************************************
// task tx_DDR3_cmd(integer src, integer dest, integer ln);
// tx the DDR3 command.
// ***********************************************************************************************************
task tx_DDR3_cmd(integer src, integer dest, integer ln);
begin

   integer unsigned                         r;//,faddr,fvect;
   string                                   cmd,msg;
   logic unsigned  [PORT_ADDR_SIZE-1:0]     addr,faddr;
   logic unsigned  [PORT_CACHE_BITS-1:0]    wdata;
   logic unsigned  [PORT_CACHE_BITS/8-1:0]  wmask;
   logic unsigned  [PORT_VECTOR_SIZE-1:0]   vect,fvect;  // Embed multiple read request returns into the SEQ_RDATA_VECT_IN.
   logic unsigned  [3:0]                    port;  // Which read and write port to be accessed...

  //while (WAIT_IDLE && (WDT_COUNTER > SYS_IDLE_TIME)) @(negedge CMD_CLK); // wait for busy to clear

   r = $fscanf(src,"%s",cmd);                      // retrieve which shape to draw

case (cmd)

   "READ","read" : begin // READ
                //wait_rdy();
 
                r = $fscanf(src,"%d%h%h",port,faddr,fvect); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Read on port %d at address (%h) to vector (%h).",port,faddr,fvect); // Create the log and waveform message.

                addr = (PORT_ADDR_SIZE)'(faddr) ;

                CMD_raddr[port]             = addr                      ;   // Setup read request pointers.
                CMD_read_vector_in[port]    = (PORT_VECTOR_SIZE)'(fvect);
                CMD_R_priority_boost[port]  = 0 ; 

                tx_r_cmd(dest,msg,ln,port); 
                end

   "WRITE","write" : begin // READ

                //wait_rdy();
 
                r = $fscanf(src,"%d%h%b%h",port,faddr,wmask,wdata); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Write on port %d at address (%h) with data (%h).",port,faddr,wdata); // Create the log and waveform message.

                addr = (PORT_ADDR_SIZE)'(faddr) ;

                CMD_waddr[port]             = addr ; // Setup write request pointers.
                CMD_wdata[port]             = wdata;
                CMD_wmask[port]             = wmask;
                CMD_W_priority_boost[port]  = 0;

                if (dest!=0)    begin
                                $sformat(msg,"%s\n                                         MASK -> (",msg);
                                for (int n=(PORT_CACHE_BITS/8-1) ; n>=0 ; n--) $sformat(msg,"%s%b%b",msg,wmask[n],wmask[n]);
                                $sformat(msg,"%s).",msg);
                                end
                tx_w_cmd(dest,msg,ln,port); 
                end

   "DELAY","delay" : begin // Delay in microseconds.
 
                //wait_rdy();
                r = $fscanf(src,"%d",faddr); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Delaying for %d nanoseconds.",13'(faddr)); // Create the log and waveform message.
                Script_LINE = ln;
                Script_CMD  = msg;
                if (dest!=0) $fwrite(dest,"%s",msg);
                for (int n=0 ; n<=((faddr*1)/DDR3_CK_pERIOD); n++) begin
                                                        @(negedge CMD_CLK);
                                                        WDT_COUNTER = WDT_RESET_TIME ;
                                                        end
                                                        @(negedge CMD_CLK);
                end

   default : begin
                wait_rdy();
                 while ((WDT_COUNTER > SYS_IDLE_TIME)) @(negedge CMD_CLK); // wait for busy to clear
                 
                  $sformat(msg,"Unknown CMD '%s' at line number %d.\nProcessign stopped due to error.\n",cmd,13'(ln));
                  $display("%s",msg);
                  while ((WDT_COUNTER >= 2 )) @(negedge CMD_CLK); // wait for busy to clear
                  if (dest!=0) $fwrite(dest,"%s",msg);
                  @(negedge CMD_CLK);
                  $stop;

                end


endcase

if (dest!=0) $fwrite(dest,"\n"); // Add a carriage return.

end
endtask



endmodule
