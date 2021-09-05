// *********************************************************************
//
// BrianHG_DDR3_CMD_SEQUENCER_tb DDR3 sequencer.
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

module BrianHG_DDR3_CMD_SEQUENCER_tb #(

// ****************  System clock generation and operation.
parameter int        CLK_MHZ_IN              = 400,              // Clock source input clock frequency in MHz.

// ****************  DDR3 ram chip configuration settings
parameter int        DDR3_WIDTH_DQ           = 8,                // Use 8 or 16.  The width of each DDR3 ram chip.

parameter int        DDR3_NUM_CHIPS          = 1,                // 1, 2, or 4 for the number of DDR3 RAM chips.
parameter int        DDR3_NUM_CK             = (DDR3_NUM_CHIPS), // Select the number of DDR3_CLK & DDR3_CLK# output pairs.  Add 1 for every DDR3 Ram chip.
                                                                 // These are placed on a DDR DQ or DDR CK# IO output pins.

parameter int        DDR3_WIDTH_ADDR         = 15,               // Use for the number of bits to address each row.
parameter int        DDR3_WIDTH_BANK         = 3,                // Use for the number of bits to address each bank.
parameter int        DDR3_WIDTH_CAS          = 10,               // Use for the number of bits to address each column.

parameter int        DDR3_RWDQ_BITS          = (DDR3_WIDTH_DQ*DDR3_NUM_CHIPS*8), // Must equal to total bus width across all DDR3 ram chips *8.

// ****************  DDR3 controller configuration parameter settings.
parameter int        PORT_VECTOR_SIZE        = 16                // Set the width of the IN_RD_VECTOR & OUT_RD_VECTOR port, 1 through 64.
)
(
RST_IN    ,CMD_CLK   ,
IN_ENA    ,IN_WENA   ,IN_BANK   ,IN_RAS    ,IN_CAS    ,IN_WDATA  ,IN_WMASK  ,IN_VECTOR ,
CMD_ACK   ,CMD_READY ,CMD_CMD   ,CMD_NAME  ,CMD_BANK  ,CMD_A     ,CMD_WDATA ,CMD_WMASK ,CMD_VECTOR,
REF_REQ,  ,REF_ACK   ,IDLE    );

localparam string  DDR_CMD_NAME [0:15] = '{"MRS","REF","PRE","ACT","WRI","REA","ZQC","nop",
                                           "xop","xop","xop","xop","xop","xop","xop","NOP"};


string     TB_COMMAND_SCRIPT_FILE = "DDR3_CMD_SEQ_script.txt";	 // Choose one of the following strings...
string                Script_CMD  = "*** POWER_UP ***" ;     // Message line in waveform
logic [12:0]          Script_LINE = 0  ;                     // Message line in waveform

input  logic RST_IN,CMD_CLK ;

input  logic                        IN_ENA    ;
input  logic                        IN_WENA   ;
input  logic [DDR3_WIDTH_BANK-1:0]  IN_BANK   ;
input  logic [DDR3_WIDTH_ADDR-1:0]  IN_RAS    ;
input  logic [DDR3_WIDTH_CAS-1:0]   IN_CAS    ;
input  logic [DDR3_RWDQ_BITS-1:0]   IN_WDATA  ;
input  logic [DDR3_RWDQ_BITS/8-1:0] IN_WMASK  ;
input  logic [PORT_VECTOR_SIZE-1:0] IN_VECTOR ;  // Embed multiple read request returns into the IN_RD_VECTOR.

output logic                        CMD_ACK    ; 
output logic                        CMD_READY  ; 
output logic [3:0]                  CMD_CMD    ; // DDR3 command out, {CS#,RAS#,CAS#,WE#}.
output string                       CMD_NAME = "xxx" ;
output logic [DDR3_WIDTH_BANK-1:0]  CMD_BANK   ; 
output logic [DDR3_WIDTH_ADDR-1:0]  CMD_A      ; 
output logic [DDR3_RWDQ_BITS-1:0]   CMD_WDATA  ; 
output logic [DDR3_RWDQ_BITS/8-1:0] CMD_WMASK  ; 
output logic [PORT_VECTOR_SIZE-1:0] CMD_VECTOR ; 

input  logic                        REF_REQ    ;
output logic                        REF_ACK    ;
output logic                        IDLE       ;
logic  auto_wait = 0 ;

localparam      period   = 500000/CLK_MHZ_IN ;

// **************************************************************************************************************************
// This module receives user commands and sequences the DDR3 commands depending on the activated rows in the selected banks
// and refresh command requests.
// **************************************************************************************************************************

BrianHG_DDR3_CMD_SEQUENCER #(
.USE_TOGGLE_ENA      ( 0                   ),     // When enabled, the (IN_ENA/IN_BUSY) & (OUT_READ_READY) toggle state to define the next command.
.USE_TOGGLE_OUT      ( 0                   ),     // When enabled, the (OUT_READY) & (OUT_ACK) use toggle state to define the next command.
.DDR3_WIDTH_BANK     ( DDR3_WIDTH_BANK     ),     // Use for the number of bits to address each bank.
.DDR3_WIDTH_ROW      ( DDR3_WIDTH_ADDR     ),     // Use for the number of bits to address each row.
.DDR3_WIDTH_CAS      ( DDR3_WIDTH_CAS      ),     // Use for the number of bits to address each column.
.DDR3_RWDQ_BITS      ( DDR3_RWDQ_BITS      ),     // Must equal to total bus width across all DDR3 ram chips *8.
.PORT_VECTOR_SIZE    ( PORT_VECTOR_SIZE    )      // Set the width of the SEQ_RDATA_VECT_IN & SEQ_RDATA_VECT_OUT port, 1 through 64.
) DUT_CMD_SEQ (
.reset            ( RST_IN           ),
.CLK              ( CMD_CLK          ),
.IN_ENA           ( IN_ENA           ),
.IN_BUSY          ( IN_BUSY          ), // An output which tells you the input is busy and the IN_ENA will be ignored.
.IN_WENA          ( IN_WENA          ),
.IN_BANK          ( IN_BANK          ),
.IN_RAS           ( IN_RAS           ),
.IN_CAS           ( IN_CAS           ),
.IN_WDATA         ( IN_WDATA         ),
.IN_WMASK         ( IN_WMASK         ),
.IN_RD_VECTOR     ( IN_VECTOR        ),

.OUT_ACK          ( CMD_ACK          ), // An input which tells internal fifo to send another command out.
.OUT_READY        ( CMD_READY        ), // Notifies that the data on all the out's are valid.
.OUT_CMD          ( CMD_CMD          ), // DDR3 command out wiring order {CS#,RAS#,CAS#,WE#}.
.OUT_TXB          (                  ), // DDR3 command out command signal bit order {nop,zqc,rea,wri,act,pre,ref,mrs}.
.OUT_BANK         ( CMD_BANK         ),
.OUT_A            ( CMD_A            ),
.OUT_WDATA        ( CMD_WDATA        ),
.OUT_WMASK        ( CMD_WMASK        ),

.IN_READ_RDY_t    (                  ),     // This input is always a toggle since it comes from the DDR3_RDQ clock domain.
.IN_READ_DATA     (                  ),
.OUT_READ_READY   (                  ),
.OUT_READ_DATA    (                  ),
.OUT_RD_VECTOR    ( CMD_VECTOR       ),

.IN_REFRESH_t     ( REF_REQ          ),
.OUT_REFRESH_ack  ( REF_ACK          ),
.OUT_IDLE         ( IDLE             ),

.READ_CAL_PAT_t   (                  ),    // Toggles after every read once the READ_CAL_PAT_v data is valid.
.READ_CAL_PAT_v   (                  )     // Valid read cal pattern detected in read.
 );


//************************************************************************************************************************************************************
//************************************************************************************************************************************************************
//************************************************************************************************************************************************************

logic       [7:0] WDT_COUNTER;                                                       // Wait for 15 clocks or inactivity before forcing a simulation stop.
logic             WAIT_IDLE        = 0;                                              // When high, insert a idle wait before every command.
localparam int    WDT_RESET_TIME   = 16;                                             // Set the WDT timeout clock cycles.
localparam int    SYS_IDLE_TIME    = WDT_RESET_TIME-8;                               // Consider system idle after 12 clocks of inactivity.

initial begin
WDT_COUNTER = WDT_RESET_TIME  ; // Set the initial inactivity timer to maximum so that the code later-on wont immediately stop the simulation.
IN_ENA    = 0 ;
IN_WENA   = 0 ;
IN_BANK   = 0 ;
IN_RAS    = 0 ;
IN_CAS    = 0 ;
IN_WDATA  = 0 ;
IN_WMASK  = 0 ;
IN_VECTOR = 0 ;
CMD_ACK   = 0 ;
auto_wait = 0 ;
REF_REQ   = 0 ;

RST_IN  = 1'b1 ; // Reset input
CMD_CLK = 1'b1 ;
#(50000);
RST_IN  = 1'b0 ; // Release reset at 50ns.

while (RST_IN) @(negedge CMD_CLK);
execute_ascii_file(TB_COMMAND_SCRIPT_FILE);

end

always_comb                CMD_NAME     =  DDR_CMD_NAME[CMD_CMD] ;                                  // Display the command name in the output waveform
always #period             CMD_CLK      = !CMD_CLK;                                                 // create source clock oscillator
always @(posedge CMD_CLK)   WDT_COUNTER = (IN_ENA || RST_IN || !IDLE) ? WDT_RESET_TIME : (WDT_COUNTER-1'b1) ; // Setup a simulation inactivity watchdog countdown timer.
always @(posedge CMD_CLK) if (WDT_COUNTER==0) begin
                                             Script_CMD  = "*** WDT_STOP ***" ;
                                             $stop;                                                // Automatically stop the simulation if the inactivity timer reaches 0.
                                             end




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

  "WAIT_IN_READY" : begin
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
@(negedge CMD_CLK); 
RST_IN = 1;
@(negedge CMD_CLK); 
@(negedge CMD_CLK); 
@(negedge CMD_CLK); 
@(negedge CMD_CLK); 
RST_IN = 0;
@(negedge CMD_CLK);
end
endtask

// ***********************************************************************************************************
// task wait_rdy();
// Wait for DUT_GEOFF input buffer ready.
// ***********************************************************************************************************
task wait_rdy();
begin
    if (!auto_wait) @(negedge CMD_CLK); // wait for busy to clear
    else while (IN_BUSY) @(negedge CMD_CLK); // wait for busy to clear
         //  while (IN_BUSY_t!=IN_CMD_ENA_t) @(negedge CMD_CLK); // wait for busy to clear with toggle style interface
end
endtask

// ***********************************************************************************************************
// task txcmd(integer dest,string msg,integer ln);
// ***********************************************************************************************************
task txcmd(integer dest,string msg,integer ln);
begin
    Script_LINE = ln;
    Script_CMD  = msg;
    if (dest!=0) $fwrite(dest,"%s",msg);

    //IN_CMD_ENA_t = !IN_CMD_ENA_t; // toggle style interface.
    if (auto_wait) wait_rdy();
    IN_ENA = 1;
    @(negedge CMD_CLK);
    IN_ENA = 0;
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

   integer unsigned                         r,faddr,fvect;
   string                                   cmd,msg;


  //while (WAIT_IDLE && (WDT_COUNTER > SYS_IDLE_TIME)) @(negedge CMD_CLK); // wait for busy to clear

   r = $fscanf(src,"%s",cmd);                      // retrieve which shape to draw

case (cmd)

   "REFRESH","refresh"  : REF_REQ = !REF_REQ;
   "AWAIT"  ,"await"    : r = $fscanf(src,"%b",auto_wait); // retrieve the command argument.
   "OUTENA" ,"outena"   : r = $fscanf(src,"%b",CMD_ACK);   // retrieve the command argument.

   "READ","read" : begin // READ
                //wait_rdy();
 
                r = $fscanf(src,"%h%h%h%h",IN_BANK,IN_RAS,IN_CAS,IN_VECTOR); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Read  bank (%h), row (%h), cas (%h), to vector (%h).",IN_BANK,IN_RAS,IN_CAS,IN_VECTOR); // Create the log and waveform message.
                IN_WENA = 0 ;
                txcmd(dest,msg,ln); 
                end

   "WRITE","write" : begin // READ

                //wait_rdy();
 
                r = $fscanf(src,"%h%h%h%b%h",IN_BANK,IN_RAS,IN_CAS,IN_WMASK,IN_WDATA); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Write bank (%h), row (%h), cas (%h) with data (%h).",IN_BANK,IN_RAS,IN_CAS,IN_WDATA); // Create the log and waveform message.

                IN_WENA  = 1 ;
 

                if (dest!=0)    begin
                                $sformat(msg,"%s\n                                        MASK -> (",msg);
                                for (int n=(DDR3_RWDQ_BITS/8-1) ; n>=0 ; n--) $sformat(msg,"%s%b%b",msg,IN_WMASK[n],IN_WMASK[n]);
                                $sformat(msg,"%s).",msg);
                                end
                txcmd(dest,msg,ln); 
                end

   "DELAY","delay" : begin // Delay in microseconds.
 
                //wait_rdy();
                r = $fscanf(src,"%d",faddr); // retrieve the DDR Bank # and ADDRESS command.
                $sformat(msg,"Delaying for %d clock cycles",13'(faddr)); // Create the log and waveform message.
                Script_LINE = ln;
                Script_CMD  = msg;
                if (dest!=0) $fwrite(dest,"%s",msg);
                for (int n=1 ; n<=faddr; n++) begin
                                                        @(negedge CMD_CLK);
                                                        WDT_COUNTER = WDT_RESET_TIME ;
                                                        end
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
