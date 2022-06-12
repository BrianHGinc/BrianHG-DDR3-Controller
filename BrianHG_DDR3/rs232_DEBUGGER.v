// *********************************************************************************
// *** RS232_Debugger.v Ver 1.0.  November 22, 2019
// ***
// *** New Ver 1.1, July 15, 2020 - Added parameter 'READ_REQ_1CLK'
// ***
// *** This RS232_Debugger.v allows a PC to access, real-time
// *** display & edit up to 16 megabytes of addressable memory.
// *** (For PCs with a 921600 baud limit, 1 megabyte max memory
// *** recommended as it takes 14 seconds to transfer that entire
// *** block of memory.  This improves with faster com ports as the FPGA
// *** can easily achieve more than 10 megabaud with this Verilog code.)
// *** 
// *** This RS232_Debugger.v can also generate a reset signal sent from the
// *** PC control software and it also has 4 utility 8 bit input ports which
// *** are continuously monitored  and displayed in real-time.  It also has 4
// *** utility 8 bit output ports which can be set to any value at any time.
// ***
// *** In a minimum configuration, this module uses 370 logic cells + the required
// *** SYNC_RS232_UART.v uses 107 logic cells for a total of 477 logic cells.  The
// *** total increases to 570 logic cells when every feature and all 24 address
// *** bits are being used.
// ***
// *** Written by and (C) Brian Guralnick.
// *** Using generic Verilog code which only uses synchronous logic.
// *** Well commented and intended for educational purposes.
// ***
// *********************************************************************************


module rs232_debugger #(
parameter CLK_IN_HZ    = 50000000,  // Set this parameter to your clock system clock frequency in Hertz
parameter BAUD_RATE    = 921600,    // Keep this parameter at 921600 for the commanding RS232_Debugger PC software.
parameter ADDR_SIZE    = 20,        // This sets the address size for the memory access.  24 is maximum, but unrealistic 
                                    // at 921600 baud as it would take almost 4 minutes to transfer everything.  20 address bits,
                                    // 1048576 bytes / 1 megabyte takes around 14 seconds to transfer with the built in overhead.
                                    // For those who can access faster RS232 ports, these larger memory sizes could become more viable.

parameter READ_REQ_1CLK = 0     // When 0, the 'host_rd_req' output stays high until a 'host_rd_rdy' is received.  When 1, the 'host_rd_req' pulses for 1 clock only.
)(

    input  wire clk,       // System clock.  Recommend at least 20MHz for the 921600 baud rate.
                           // This module is capable of over 100MHz on even the slowest FPGAs.

	output reg  cmd_rst=0,   // When sent by the PC RS232_Debugger utility, this outputs a high signal for 8 clock cycles.
	                       // It also runs high for 8 clock cycles during power-up.

    input  wire rxd,       // Connect this to the RS232 RXD input pin.
    output wire txd,       // Connect this to the RS232 TXD output pin.

	output reg         LED_txd,             // Optionally wire this to a LED, it will go high whenever the RS232 TXD is active.
	output reg         LED_rxd,             // Optionally wire this to a LED, it will go high whenever the RS232 RXD is active.

	output wire        host_rd_req,         // This output will pulse high for 1 clock when a read request is taking place.
	input  wire        host_rd_rdy,         // This input should be set high once the 'host_rdata[7:0]' input contains valid data.
											// Tie this input high if your read data will be always valid within 12 clock cycles since the hosr_rd_req.
	
	output reg         host_wr_ena,         // This output will pulse high for 1 clock when a write request is taking place.

	output wire [ADDR_SIZE-1:0] host_addr,  // This output contains the requested read and write address.
	output reg  [7:0]  host_wdata,          // This output contains the source RS232 8bit data to be written.
	input  wire [7:0]  host_rdata,          // This input receives the 8 bit ram data to be sent to the RS232.
	                                        // If 'host_rd_rdy' is tied to '1' the data needs to be valid within 12 clocks of the 'host_rd_req' pulse.
	
	// These are 4 8 bit utility input ports which are continuously read and displayed in the RS232_Debugger utility.
	input  wire [7:0]  in0,
	input  wire [7:0]  in1,
	input  wire [7:0]  in2,
	input  wire [7:0]  in3,


	// These are 4 8 bit utility output ports which are set by the RS232_Debugger utility.
	output reg  [7:0]  out0=0,
	output reg  [7:0]  out1=0,
	output reg  [7:0]  out2=0,
	output reg  [7:0]  out3=0
	);

reg [7:0] in_reg0,in_reg1,in_reg2,in_reg3; // These 'in_reg#[7:0]' will be used to latch all 4 'in#[7:0]' inputs in parallel before transmitting their state through the RS232 transceiver.


localparam CLK_1KHz_PERIOD  = CLK_IN_HZ / 1000 ;     // The counter period for generating an internal 1 KHz timer
localparam DEBUG_WDT_TIME   = 4'd15;                 // Com activity watch dog timer.  Time until a incomming Write to ram command is aborted due to inactive com.
localparam LED_HOLD_TIME    = 4'd15;                 // Keep the LED_rxd/txd signal high for at least this amount of ms time during RXD/TXD transactions.

reg        [17:0]  tick_1KHz_counter ;               // This reg is the counter for the main clock input which is used to generate the 1KHz timer.
reg                tick_1KHz ;                       // This reg will pulse for 1 'clk' cycle at 1KHz.
reg        [4:0]   timeout_cnt;				         // This is a counter which is used for the communications watch dog timer which times out at the 'DEBUG_WDT' parameter count running at 1KHz speed.
reg        [4:0]   led_txd_timeout, led_rxd_timeout; // These are timer counters used to keep the communication status LEDs on for the 'LED_HOLD_TIME' parameter count running at 1KHz speed.

reg       host_rd_req_r, host_rd_req_r1; 
assign    host_rd_req   = READ_REQ_1CLK  ?  (host_rd_req_r && !host_rd_req_r1) : host_rd_req_r ; // selects between a single clock pulse 'host_rd_req' or the original one which staye high until a 'host_rd_rdy' is received

// *****************************************************************************************************************************************************************************
// **** Example command structure shown in RS232 received and transmitted hex bytes:
// ****
// **** Example #1: CMD_READ_BYTES (See figure #1)
// ****                         <<      SETUP HEADER    >>  <<CMD_PREFIX> <ADDR_POINT><TRANSFER_SIZE>> <<CMD_PREFIX> <ADDR_POINT><TRANSFER_SIZE>>
// **** Read host ram  string ( 80 FF FF 00 00 00 00 00 00   52 65 61 64    00 01 00        04          52 65 61 64    00 01 00        04        ) Both copies must match for
// **** The last 16 characters RX_Buffer string             <<          Copy #1 of command          >> <<          Copy #2 of command          >>  the command to be accepted.
// ****
// ****                                                                        RX_Buffer #7,6,5,4= 32'h 52 65 61 64 = CMD_READ_BYTES
// ****                                                                        RX_Buffer #3,2,1=   24'h 00 01 00    = From Address 24'h000100
// ****                                                                        RX_Buffer #0 =       8'h 04          = Transfer 8'h04 + 1 = 5 bytes.
// ****
// ****                                                                        The RS232_Debugger will then transmit 5 bytes read from host ram port.
// **** Example #2: CMD_READ_BURST
// ****                         <<      SETUP HEADER    >>  <<CMD_PREFIX> <ADDR_POINT><TRANSFER_SIZE>> <<CMD_PREFIX> <ADDR_POINT><TRANSFER_SIZE>>
// **** Read host ram  string ( 80 FF FF 00 00 00 00 00 00   52 65 61 50    00 80 00        0F          52 65 61 50    00 80 00        0F        )
// **** The last 16 characters RX_Buffer string             <<          Copy #1 of command          >> <<          Copy #2 of command          >>
// ****
// ****                                                                        RX_Buffer #7,6,5,4= 32'h 52 65 61 50 = CMD_READ_BURST
// ****                                                                        RX_Buffer #3,2,1=   24'h 00 80 00    = From Address 24'h008000
// ****                                                                        RX_Buffer #0 =       8'h 0F          = Transfer (8'h0F + 1) *256 = 4096 bytes.
// ****
// ****                                                                        The RS232_Debugger will then transmit 4096 bytes read from host ram port.
// ****
// **** Example #3: CMD_WRITE_BYTES (See figure #2)
// ****                         <<      SETUP HEADER    >>  <<CMD_PREFIX> <ADDR_POINT><TRANSFER_SIZE>> <<CMD_PREFIX> <ADDR_POINT><TRANSFER_SIZE>>
// **** Read host ram  string ( 80 FF FF 00 00 00 00 00 00   57 72 69 74    00 01 00        04          57 72 69 74    00 01 00        04        )
// **** The last 16 characters RX_Buffer string             <<          Copy #1 of command          >> <<          Copy #2 of command          >>
// ****
// ****                                                                        RX_Buffer #7,6,5,4= 32'h 57 72 69 74 = CMD_WRITE_BYTES
// ****                                                                        RX_Buffer #3,2,1=   24'h 00 01 00    = To Address 24'h000100
// ****                                                                        RX_Buffer #0 =       8'h 04          = Transfer 8'h7F + 1 = 5 bytes.
// ****
// ****                                                                        The RS232_Debugger will now expect to receive 5 bytes which will be written
// ****                                                                        into the host ram.  The 5 received characters will be echoed back as verification.
// ****                                                                        If there is a pause or delay for more than 0.1 seconds, write command halts/aborts.
// ****
// **** Example #4: CMD_SET_PORTS (See figure #3)
// ****                         <<      SETUP HEADER    >>  <<CMD_PREFIX> <Out0><Out1><Out2><Out3>> <<CMD_PREFIX> <Out0><Out1><Out2><Out3>>
// **** Read host ram  string ( 80 FF FF 00 00 00 00 00 00   53 65 74 50    AA    BB    CC    DD     53 65 74 50    AA    BB    CC    DD    )
// **** The last 16 characters RX_Buffer string             <<       Copy #1 of command          >> <<          Copy #2 of command       >>
// ****
// ****                                                                        RX_Buffer #7,6,5,4= 32'h 53 65 74 50 = CMD_SET_PORTS
// ****                                                                        RX_Buffer #3      =  8'h AA          = Output port Out0[7:0] will be set to 8'hAA
// ****                                                                        RX_Buffer #2      =  8'h BB          = Output port Out1[7:0] will be set to 8'hBB
// ****                                                                        RX_Buffer #1      =  8'h CC          = Output port Out2[7:0] will be set to 8'hCC
// ****                                                                        RX_Buffer #0      =  8'h DD          = Output port Out3[7:0] will be set to 8'hDD
// ****
// ****                                                                        The RS232_Debugger will then transmit back the values of:
// ****                                                                        Ports In0[7:0], In1[7:0], In2[7:0], In3[7:0], then Parameter 'ADDR_SIZE[7:0]'.
// ****
// ****
// *****************************************************************************************************************************************************************************


wire [31:0]      CMD_READ_BYTES, CMD_READ_BURST, CMD_WRITE_BYTES, CMD_WRITE_BURST, CMD_RESET, CMD_SET_PORTS;  // Set wire labels for all the command strings.
reg  [15*8+7:0]  RX_buffer;               // This 16 word * 8 bit character register will take in the RS232 data as an 8 bit word pipe, 16 characters long.
wire [31:0]      CMD_PREFIX ;             // Define a 32 bit wire bus in the RX_buffer which contains the command prefix and CMD_SUFFIX
wire [23:0]      CMD_ADDRESS_POINTER ;    // Define a 24 bit wire bus for the 'CMD_ADDRESS_POINTER'
wire [7:0]       CMD_TRANSFER_SIZE ;      // Define an 8 bit wire bus for the 'CMD_TRANSFER_SIZE'

reg		   [3:0]    RXD_00_cnt; // This register will count the consecutive number of bytes = 8'h00 ahead of the command.  It will reset to 0 if any other byte value is received.
reg		   [3:0]    RXD_FF_cnt; // This register will count the number of bytes = 8'hFF ahead of the command.  It will reset to 0 if any other byte value other than 8'h00 is received.

// Assign values to all the command wires
wire       CMD_HEADER, CMD_VERIFY;
assign     CMD_HEADER          = ( RXD_FF_cnt==4'h2 && RXD_00_cnt==4'h6 );  // Two consecutive 8'hFF and then 6 consecutive 8'h00 must be transmitted
																			// as a header before a command, otherwise, all potential received commands will be ignored.

assign     CMD_VERIFY          = ( RX_buffer[15*8+7:8*8] == RX_buffer[7*8+7:0*8] ); // To verify authenticate an incoming command, the 2 consecutive identical copies
																				    // of the 8 byte command must match
 
assign     CMD_PREFIX          = RX_buffer[7*8+7:4*8] ;  // The point in the receive buffer is where the 4 character command is located
assign     CMD_READ_BYTES      = 32'h52656164 ;          // Read host ram and transmit to RS232, from 1 through 256 bytes.
assign     CMD_READ_BURST      = 32'h52656150 ;          // Page read host ram and transmit to RS232, from 256 through 65536 bytes.
assign     CMD_WRITE_BYTES     = 32'h57726974 ;          // Read RS232 data and write into host ram, from 1 through 256 bytes.
assign     CMD_WRITE_BURST     = 32'h57726950 ;          // Page Read RS232 data and write into host ram, from 256 through 65536 bytes.
assign     CMD_RESET           = 32'h52657365 ;          // Cycle the reset output command prefix
assign     CMD_SET_PORTS       = 32'h53657450 ;          // Set the general purpose output ports and read general purpose input ports + then transmit 'ADDR_SIZE' parameter.
assign     CMD_ADDRESS_POINTER = RX_buffer[3*8+7:1*8] ;  // Point to the 3 8 bit words in the command's register which contains the 24 bit starting read and write address
assign     CMD_TRANSFER_SIZE   = RX_buffer[0*8+7:0*8] ;  // Point to the 8 bit word in the command's register which contains the number of bytes+1 to transfer
														 // Or in the case of a R/W_BURST, set the byte transfer quantity to (CMD_TRANSFER_SIZE+1) * 256

reg        [16:0]   byte_count;                          // This register will be used to count the number of bytes which were requested by 'CMD_TRANSFER_SIZE' to be received or transmitted through the RS232 transceiver.
reg        [23:0]   host_addr_reg ;                      // This register will hold and count the host read and write address.
reg        [7:0]    host_rdata_reg ; 					 // when the 'host_rd_rdy' input goes high, this register will latch the 'host_rdata' input port.

assign     host_addr[ADDR_SIZE-1:0]  = host_addr_reg[ADDR_SIZE-1:0];  // Assign the host register output port the the host_addr_reg register counter


reg        [1:0]  Function ;         // This register holds which of the 4 possible program functions the RS232_Debugger is running.
wire       [1:0]  FUNC_WAIT, FUNC_READ, FUNC_WRITE, FUNC_SET_PORTS ;
assign     FUNC_WAIT       = 2'h0 ;  // This function state waits for incoming commands.  When a valid command is received, it will setup the next function state.
assign     FUNC_READ       = 2'h1 ;  // This function state will read 'byte_count+1' bytes of host ram and transmit the contents to the RS232 port's TXD.
assign     FUNC_WRITE      = 2'h2 ;  // This function state will read 'byte_count+1' bytes from the RS232 port's RXD and send the data to the host ram + send a copy back to the RS232 port's TXD.
assign     FUNC_SET_PORTS  = 2'h3 ;  // This function state will send the the 4 in#[7:0] ports' values and then the 'ADDR_SIZE' parameter through the RS232 transceiver.


reg        [3:0]      rst_clk=0;  // This will be used as a counter to pulse out the 'cmd_rst' output pin for 8 clock cycles when commanded to by the RS232.
reg        [3:0]      tx_cyc=0;   // This counter will be used to slow down and sequence actions when transmitting bytes out through the RS232 transceiver.



// *************************************************************************
// *** SYNC_RS232_UART.v setup.  Read the SYNC_RS232_UART.v file to see how
// *** I engineered this module and how I got the transmitter to function
// *** synchronously with a PC's serial incoming RXD transmission.
// *** 
// *** Timing diagrams on EEVBlog forum here:
// *** 
// *************************************************************************

wire         uart_tx_full;
wire         rxd_rdy;
reg  [4:0]   ena_rxd_dly;  //  This register will receive the UART's 'rxd_rdy' pulse and serial shift that pulse along it's 5 bits.
wire [7:0]   uart_rbyte;
reg          uart_tx;
reg  [7:0]   uart_tbyte;   // This reg will hold the byte which is about to be transmitted

sync_rs232_uart  rs232_io (	.clk(clk),
								.rxd(rxd),             // Goes to RXD Input Pin
								.txd(txd),             // Goes to TXD output pin

								.rx_data(uart_rbyte),  // Received data byte
								.rx_rdy(rxd_rdy),      // 1 clock pulse high when the received data bit is ready

								.ena_tx(uart_tx),      // Pulsed high for 1 clock when tx_data byte is ready to be sent
								.tx_data(uart_tbyte),  // The byte which will be transmitted
								.tx_busy(uart_tx_full) ); // High when the 1 word FIFO in the UART's transmit buffer is full
	defparam
		rs232_io.CLK_IN_HZ    = CLK_IN_HZ,
		rs232_io.BAUD_RATE    = BAUD_RATE;


always @ (posedge clk) begin

// ******************************************************************
// ****** Generate a generic 1 KHz timer tick pulse.
// ******************************************************************
if ( tick_1KHz_counter <= 18'h1 ) begin 
							tick_1KHz_counter <= CLK_1KHz_PERIOD[17:0];
							tick_1KHz         <= 1'b1 ;
						end else begin
							tick_1KHz_counter <= tick_1KHz_counter - 1'b1 ;
							tick_1KHz         <= 1'b0 ;
							end

// ******************************************************************
// ****** Generate a status activity RXD and TXD led driver output.
// ****** This routine keeps the LED outputs on long enough to
// ****** visibly see as the data bursts are too short to be seen.
// ******************************************************************
	if (uart_tx_full) begin
						led_txd_timeout <= LED_HOLD_TIME ;
						LED_txd         <= 1'b1 ;
						end else if ( led_txd_timeout!=5'h0 && tick_1KHz ) led_txd_timeout <= led_txd_timeout - 1'b1 ;
						else if     ( led_txd_timeout==5'h0 )              LED_txd         <= 1'b0 ;

	if (rxd_rdy) begin
						led_rxd_timeout <= LED_HOLD_TIME ;
						LED_rxd         <= 1'b1 ;
						end else if ( led_rxd_timeout!=5'h0 && tick_1KHz ) led_rxd_timeout <= led_rxd_timeout - 1'b1 ;
						else if     ( led_rxd_timeout==5'h0 )              LED_rxd         <= 1'b0 ;

// ******************************************************************
// ******************************************************************

cmd_rst <= ~rst_clk[3] ;                    // Register delay and invert latch bit 4 of the reset counter.
if (~rst_clk[3]) begin                      // *** Generate an 8 clock wide reset pulse
				rst_clk <= rst_clk + 1'b1 ;   // Count until bit 3 on the counter goes high.
end else begin

if (cmd_rst) begin                          // Last single 1 shot reset from the reset output signal 'cmd_rst'.
		host_addr_reg        <= 24'h0 ;
		host_wr_ena          <= 1'b0 ;      // make sure we aren't writing ram.
		host_rd_req_r        <= 1'b0 ;      // make sure we aren't requesting a read from memory
		host_rd_req_r1       <= 1'b0 ;      // make sure we aren't requesting a read from memory
		ena_rxd_dly[4:0]     <= 5'h0 ;      // clear out any possible RS232 transceiver rx_rdy
		RX_buffer[15*8+7:0]  <= 128'h0 ;    // clear out the entire 16 word by 8 bit character input command buffer.
		Function             <= FUNC_WAIT ; // set the program state to the 'wait for incoming command' function.
		uart_tx			     <= 1'b0 ;      // make sure no transmit character command is being sent to the RS232 transceiver.
		end else begin


// ******************************************************************************************
// *** setup a sequential accessible delayed pipe of the RS232 transceiver's 'rx_rdy' signal.
// ******************************************************************************************
		ena_rxd_dly[0]    <=  rxd_rdy ;
		ena_rxd_dly[4:1]  <=  ena_rxd_dly[3:0] ;
		host_rd_req_r1    <=  host_rd_req_r ;   // Single pulse isolator for 1 shot host_rd_req output

// ******************************************************************************************************************
// *** setup case statement for the 4 possible functions, FUNC_WAIT, FUNC_READ, FUNC_WRITE, FUNC_SET_PORTS
// ******************************************************************************************************************
case (Function)


	// ************************************************************************************************************************************************************************************
	// *** Beginning Function FUNC_WAIT.  This function state waits for incoming commands.  When a valid command is received, it will setup the next function state.
	// ************************************************************************************************************************************************************************************
	FUNC_WAIT : begin

		host_rd_req_r <= 1'b0;  // force off any ram transactions.
		host_wr_ena   <= 1'b0;

		if (ena_rxd_dly[3]) begin  // Note we are using the ena_rxd_dly[3] deliberately since if the 'FUNC_WRITE' is called, it uses a pre-setup time by triggering sequenced actions on earlier ena_rxd_dly[#]s

							RX_buffer[15*8+7:0]    <= { RX_buffer[14*8+7:0] , uart_rbyte } ;  // This will shift 1 byte at a time through the 16 character command buffer

							if      ( RX_buffer[15*8+7:15*8]==8'h00 ) 	RXD_00_cnt <= RXD_00_cnt + (RXD_00_cnt!=3'h7); // test the last byte in the 16 character buffer and
							else 										RXD_00_cnt <= 3'h0 ;                           // count the number of bytes which are sequentially = 8'h00.

							if      ( RX_buffer[15*8+7:15*8]==8'hFF )	RXD_FF_cnt <= RXD_FF_cnt + (RXD_FF_cnt!=3'h7); // test the last byte in the 16 character buffer and
							else if ( RX_buffer[15*8+7:15*8]!=8'h00 )	RXD_FF_cnt <= 3'h0 ;                           // count the number of bytes which are sequentially = 8'hFF

							end

		if ( CMD_HEADER &&  CMD_VERIFY  ) begin  // Test to see if the command prefix string meets the 2 bytes of 8'hFF,
											     // then 6 bytes of 8'h00, and then 2 command string of 8 bytes each which are identical

			// ********************************************************************************************************
			// *** setup case statement which will perform actions based on the 6 possible incoming CMD_PREFIX :
			// ***       CMD_READ_BYTES, CMD_READ_BURST, CMD_WRITE_BYTES, CMD_WRITE_BURST, CMD_RESET, CMD_SET_PORTS
			// ********************************************************************************************************
			case (CMD_PREFIX)


				// ********************************************************************************************************
				// *** CMD_PREFIX case CMD_READ_BYTES. Read host ram and transmit to RS232, from 1 through 256 bytes.
				// ********************************************************************************************************
				CMD_READ_BYTES  : begin
											byte_count[16:8]    <= 9'h0;
											byte_count[7:0]     <= CMD_TRANSFER_SIZE ;
											host_addr_reg[23:0] <= CMD_ADDRESS_POINTER ;
											Function            <= FUNC_READ ;
											tx_cyc			    <= 4'h0;
											RX_buffer[15*8+7:0] <= 128'h0;
											timeout_cnt         <= DEBUG_WDT_TIME ;  // set the receive abort timeout counter
											end  // end of case CMD_READ_BYTES

				// ********************************************************************************************************
				// *** CMD_PREFIX case CMD_WRITE_BYTES. Read RS232 data and write into host ram, from 1 through 256 bytes.
				// ********************************************************************************************************
				CMD_WRITE_BYTES : begin
											byte_count[16:8]    <= 9'h0;
											byte_count[7:0]     <= CMD_TRANSFER_SIZE ;
											host_addr_reg[23:0] <= CMD_ADDRESS_POINTER ;
											Function            <= FUNC_WRITE ;
											RX_buffer[15*8+7:0] <= 128'h0;
											timeout_cnt         <= DEBUG_WDT_TIME ;  // set the receive abort timeout counter
											end  // end of case CMD_WRITE_BYTES

				// ********************************************************************************************************
				// *** CMD_PREFIX case CMD_READ_BURST. Page read host ram and transmit to RS232, from 256 through 65536 bytes.
				// ********************************************************************************************************
				CMD_READ_BURST  : begin
											byte_count[16]      <= 1'b0;
											byte_count[15:8]    <= CMD_TRANSFER_SIZE ;
											byte_count[7:0]     <= 8'hFF ;
											host_addr_reg[23:0] <= CMD_ADDRESS_POINTER ;
											Function            <= FUNC_READ ;
											tx_cyc			    <= 4'h0;
											RX_buffer[15*8+7:0] <= 128'h0;
											timeout_cnt         <= DEBUG_WDT_TIME ;  // set the receive abort timeout counter
											end  // end of case CMD_READ_BURST

				// ********************************************************************************************************
				// *** CMD_PREFIX case CMD_WRITE_BURST. Page Read RS232 data and write into host ram, from 256 through 65536 bytes.
				// ********************************************************************************************************
				CMD_WRITE_BURST : begin 
											byte_count[16]      <= 1'b0;
											byte_count[15:8]    <= CMD_TRANSFER_SIZE ;
											byte_count[7:0]     <= 8'hFF ;
											host_addr_reg[23:0] <= CMD_ADDRESS_POINTER ;
											Function            <= FUNC_WRITE ;
											RX_buffer[15*8+7:0] <= 128'h0;
											timeout_cnt         <= DEBUG_WDT_TIME ;   // set the receive abort timeout counter
											end  // end of case CMD_WRITE_BURST

				// ********************************************************************************************************
				// *** CMD_PREFIX case CMD_RESET.  Trigger the com_rst output.
				// ********************************************************************************************************
				CMD_RESET       : begin
											rst_clk             <= 4'h0;		// Clearing the rst_clk which will begin the 8 clock reset period
											Function            <= FUNC_WAIT ;
											RX_buffer[15*8+7:0] <= 128'h0;
											end  // end of case CMD_RESET

				// *********************************************************************************************************************************************
				// *** CMD_PREFIX case CMD_SET_PORTS.  Set the general purpose output ports and read general purpose input ports + the transmit 'ADDR_SIZE' parameter.
				// *********************************************************************************************************************************************
				CMD_SET_PORTS   : begin 
											out0				<= RX_buffer[3*8+7:3*8] ;  // The 4 out# ports were sent withing the RX_buffer command's suffix.
											out1				<= RX_buffer[2*8+7:2*8] ;  // Usually, the address and data transfer size is stored here.
											out2				<= RX_buffer[1*8+7:1*8] ;
											out3				<= RX_buffer[0*8+7:0*8] ;
											// *** Parallel register all 4 peripheral input ports.
											in_reg0				<= in0 ;
											in_reg1 			<= in1 ;
											in_reg2 			<= in2 ;
											in_reg3 			<= in3 ;
											
											byte_count[16]      <= 1'b0 ;
											byte_count[15:0]    <= 16'h4 ;  // There are 5 bytes to be sent, the 4 in_reg#[7:0] registers and the 'ADDR_SIZE' parameter.
											Function            <= FUNC_SET_PORTS ;
											tx_cyc			    <= 4'h0 ;
											RX_buffer[15*8+7:0] <= 128'h0 ;
											timeout_cnt         <= DEBUG_WDT_TIME ;  // set the receive abort timeout counter
											end  // end of case CMD_SET_PORTS

				endcase
				// ********************************************************************************************************
				// *** End of case (CMD_PREFIX) for the 6 possible commands:
				// ***       CMD_READ_BYTES, CMD_READ_BURST, CMD_WRITE_BYTES, CMD_WRITE_BURST, CMD_RESET, CMD_SET_PORTS
				// ********************************************************************************************************


			end // End of Command verification if ( CMD_HEADER &&  CMD_VERIFY  )


	end
	// ************************************************************************************************************************************************************************************
	// *** Ending case Function FUNC_WAIT.
	// ************************************************************************************************************************************************************************************



	// ************************************************************************************************************************************************************************************
	// *** Beginning Function FUNC_READ.  This function will read 'byte_count+1' bytes of host ram and transmit the contents to the RS232 port's TXD.
	// ************************************************************************************************************************************************************************************
	FUNC_READ : begin

				if (~byte_count[16] && timeout_cnt!=5'h0 ) begin  //  keep on transmitting until byte counter elapses by counting below 0.

								 if ( uart_tx        ) timeout_cnt <= DEBUG_WDT_TIME ;      // If a character is transmitted, reset the watch dog timeout counter
							else if ( tick_1KHz      ) timeout_cnt <= timeout_cnt - 1'b1 ;  // Otherwise, countdown the watch dog timer once at every 1KHz tick.

					if ( host_rd_rdy ) host_rdata_reg <= host_rdata ;  // latch the host_rdata input if the host_read_rdy is set.

					if (~(uart_tx_full && tx_cyc==4'h0) && ~(~host_rd_rdy && tx_cyc==4'h1) ) begin  // only run the tx_cyc counter when the UART RS232 transmitter
																									// is ready to transmit the next character and the host_rd_ready
																									// has gone high after tx_cyc 0 when the host_re_req pulse has been sent.
						tx_cyc <= tx_cyc + 1'b1; // increment this cycle counter
						
						if (tx_cyc==4'd0)  host_rd_req_r <= 1'b1;				// pulse the host_rd_req_r with the current valid address
						else               host_rd_req_r <= 1'b0;

						if (tx_cyc==4'd13) uart_tbyte    <= host_rdata_reg ;	// expect the returned data ready within 12 clock cycles, and latch that data into the RS232 transmitter data input register

						if (tx_cyc==4'd14) uart_tx       <= 1'b1;				// Trigger the RS232 transmit data enable
						else               uart_tx       <= 1'b0;

						if (tx_cyc==4'd15) host_addr_reg <= host_addr_reg + 1'b1;  // increment the host memory address
						if (tx_cyc==4'd15) byte_count    <= byte_count - 1'b1;     // decrement the byte transfer size counter
					end

				end else begin                  // byte_count cycles has completed or timeout WDT has elapsed,
					Function      <= FUNC_WAIT; // leave FUNC_READ and switch back to FUNC_WAIT for the next command.
					uart_tx       <= 1'b0;
					host_rd_req_r <= 1'b0;
					end

			end //  End of case FUNC_READ
	// ************************************************************************************************************************************************************************************
	// *** Ending of Function FUNC_READ.
	// ************************************************************************************************************************************************************************************



	// ************************************************************************************************************************************************************************************
	// *** Beginning Function FUNC_WRITE.  This function will read 'byte_count+1' bytes from the RS232 port's RXD and send the data to the host ram + send a copy back to the RS232 port's TXD.
	// ************************************************************************************************************************************************************************************
	FUNC_WRITE : begin

					if (~byte_count[16] && timeout_cnt!=5'h0 ) begin  //  keep on reading from RS232 until byte counter elapses, or the timeout counter has reached it's end

								 if ( ena_rxd_dly[0] ) timeout_cnt <= DEBUG_WDT_TIME ;      // If a character is received, reset the watch dog timeout counter
							else if ( tick_1KHz      ) timeout_cnt <= timeout_cnt - 1'b1 ;  // Otherwise, countdown the watch dog timer once at every 1KHz tick.


							if (ena_rxd_dly[0]) host_wdata     <= uart_rbyte ;              // copy RS232 received data byte to the host memory data output port
							if (ena_rxd_dly[0]) uart_tbyte     <= uart_rbyte ;              // copy RS232 received data byte to the RS232 transmitter output data port

							if (ena_rxd_dly[1]) host_wr_ena     <= 1'b1;                    // Trigger the host memory write enable
							else                host_wr_ena     <= 1'b0;

							if (ena_rxd_dly[1]) uart_tx         <= 1'b1;					// echo back received character by triggering the RS232 transmit data enable
							else                uart_tx         <= 1'b0;

							if (ena_rxd_dly[3]) host_addr_reg   <= host_addr_reg + 1'b1 ;   // increment the host memory address
							if (ena_rxd_dly[3]) byte_count      <= byte_count - 1'b1 ;      // decrement the byte transfer size counter

					end else begin                           // byte_count cycles has completed or timeout WDT has elapsed,
							Function        <= FUNC_WAIT ;   // leave FUNC_WRITE and switch back to FUNC_WAIT for the next command.
							host_wr_ena     <= 1'b0 ;
							byte_count[16]  <= 1'b1 ;
							end

				end // End of case FUNC_WRITE	
	// ************************************************************************************************************************************************************************************
	// *** Ending of Function FUNC_WRITE.
	// ************************************************************************************************************************************************************************************



	// ************************************************************************************************************************************************************************************
	// *** Beginning of Function FUNC_SET_PORTS.  This function will send the 'ADDR_SIZE' parameter + the 4 in#[7:0] ports' data through the RS232's port's TXD.
	// ************************************************************************************************************************************************************************************
	FUNC_SET_PORTS : begin

						if (~byte_count[16]) begin  //  keep on transmitting until byte counter elapses

							if (~(uart_tx_full && tx_cyc==4'h0)) begin

								tx_cyc <= tx_cyc + 1'b1 ;

								if (tx_cyc==4'd13) begin
									case (byte_count[2:0])              // Set the RS232 transmitter's data port with the correct data during the correct byte number
										3'h4 : uart_tbyte	<= in_reg0 ;
										3'h3 : uart_tbyte	<= in_reg1 ;
										3'h2 : uart_tbyte	<= in_reg2 ;
										3'h1 : uart_tbyte	<= in_reg3 ;
										3'h0 : uart_tbyte	<= ADDR_SIZE[7:0] ;
									endcase // case (byte_count[2:0])
								end

								if (tx_cyc==4'd14) uart_tx     <= 1'b1 ;			  // Trigger the RS232 transmit data enable
								else               uart_tx     <= 1'b0 ;
								
								if (tx_cyc==4'd15) byte_count  <= byte_count - 1'b1 ; // decrement the byte transfer size counter

							end

						end else begin                   // byte_count cycles has completed, leave FUNC_SET_PORTS and switch back to FUNC_WAIT for the next command.
							Function      <= FUNC_WAIT ;
							uart_tx       <= 1'b0 ;
							host_rd_req_r <= 1'b0 ;
							end

				end // End of case FUNC_WRITE_PORTS
	// ************************************************************************************************************************************************************************************
	// *** Ending of Function FUNC_SET_PORTS.
	// ************************************************************************************************************************************************************************************



endcase // Case (Function)
// ******************************************************************************************************************
// *** End of case statement for the 4 possible functions, FUNC_WAIT, FUNC_READ, FUNC_WRITE, FUNC_SET_PORTS
// ******************************************************************************************************************


   end // ~rst
  end // ~soft_rst
 end // always @posedge
endmodule
