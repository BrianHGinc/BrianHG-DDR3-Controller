// *****************************************************************
// *** SYNC_RS232_UART.v V1.0, November 22, 2019
// ***
// *** This transceiver follows slight baud timing errors introduced
// *** by the external host interface's clock making the TDX output
// *** clock timing synchronize to the RXD coming in allowing
// *** high speed synchronous communications.  A requirement
// *** for PC RS232 full duplex synchronous communications.
// ***
// *** Written by Brian Guralnick.
// *** Using generic Verilog code which only uses synchronous logic.
// *** Well commented for educational purposes.
// *****************************************************************

module sync_rs232_uart #(
// Setup parameters
parameter CLK_IN_HZ    = 50000000,    // Set to system input clock frequency
parameter BAUD_RATE    = 921600       // Set to desired baud rate
)( 
	input  wire       clk,            // System clock
	input  wire       rxd,            // RS232 serial input data pin
	output reg        rx_rdy,         // Pulsed high for 1 system clock when the received 8 bit data byte is ready
	output reg  [7:0] rx_data,        // Received 8 bit data byte.
	
	input  wire       ena_tx,         // Signals the transmitter to latch the 8 bit data and begin transmitting
	input  wire [7:0] tx_data,        // 8 bit data byte input to be transmitted
	output reg        txd,            // RS232 serial output data pin
	output reg        tx_busy,        // High when transmitter is busy.  Low when you may load a byte to transmit
	
	output reg        rx_sample_pulse // For debugging RXD errors only.  This is an output test pulse
	                                  // aligned to when the receiver has sampled the RXD input.
  ) ;


localparam RX_PERIOD    = (CLK_IN_HZ / BAUD_RATE) -1 ; // Set's a reference counter size for each transmitted/received serial data bit
localparam TX_PERIOD    = (CLK_IN_HZ / BAUD_RATE) -1 ;

// Receiver regs
reg     [15:0]     rx_period ;
reg     [3:0]      rx_position ;
reg     [9:0]      rx_byte ;
reg                rxd_reg, last_rxd ;
reg		   rx_busy, rx_last_busy ;

// Transmitter regs
reg     [15:0]     tx_period   = 16'h0 ;
reg     [3:0]      tx_position = 4'h0 ;
reg     [9:0]      tx_byte     = 10'b1111111111 ;
reg     [7:0]      tx_data_reg = 8'b11111111 ;
reg                tx_run      = 1'b0 ;



//********************************************************************************************
// make the rx_trigger 'WIRE' equal to any new RXD input High to Low transition (IE start bit)
// when the receiver is not busy receiving a byte
//********************************************************************************************
wire    rx_trigger ;
assign  rx_trigger = ( ~rxd_reg && last_rxd && ~rx_busy );


always @ (posedge clk) begin
//********************************
// Receiver functions.
//********************************

// register clock the UART RDX input signal.
// This is a personal preference as I prefer FPGA inputs which don't directly feed combinational logic
rxd_reg      <= rxd;
last_rxd     <= rxd_reg;                  // create a 1 clock delay register of the rxd_reg serial bit

rx_last_busy <= rx_busy;                  // create a 1 clock delay of the rx_busy resister.
rx_rdy       <= rx_last_busy && ~rx_busy; // create the rx_rdy out pulse for 1 single clock when the rx_busy flag has gone low signifying that rx_data is ready


if ( rx_trigger )	begin                                        // if a 'rx_trigger' event has taken place
			rx_period      <= ( RX_PERIOD[15:0] >> 1 ) ; // set the period clock to half way inside a serial bit.  This makes the best time to sample incoming
			                                             // serial bits as the source baud rate may be slightly slow or fast maintaining a good data capture window all the way until the stop bit
			rx_busy        <= 1'd1 ;                     // set the rx_busy flag to signify operation of the UART serial receiver
			rx_position    <= 4'h9 ;                     // set the serial bit counter to position 9
	end else begin
	
	if ( rx_period==0 ) begin				     // if the receiver period counter has reached it's end
			rx_period	    <=  RX_PERIOD[15:0] ;    // reset the period counter
			rx_sample_pulse <=  rx_busy ;                // *** This is only a test pulse for debugging purposes
		
				if ( rx_position != 0 ) begin                  // if the receiver's bit position counter hasn't reached it's end
					rx_position   <= rx_position - 1'd1 ;  // decrement the position counter
					rx_byte[9]    <= rxd_reg ;             // load the receiver's serial shift regitser with the RXD input pin
					rx_byte[8:0]  <= rx_byte[9:1] ;        // shift the input serial shift register.

				end else begin                         // if the receiver's bit position counter reached 0
					rx_data       <= rx_byte[9:2]; // load the output data register with the correct 8 bit contents of the serial input register
					rx_busy       <= 1'b0;         // turn off the serial receiver busy flag
				end

			end else begin                                 // if the receiver period counter has not reached it's end
					rx_period <= rx_period - 1'b1; // just decrement the receiver period counter
					rx_sample_pulse <=  1'b0 ;     // *** This is only a test pulse for debugging purposes
					end
end // ~rx_trigger



//***********************************************************
// SYNCHRONOUS! Transmitter functions
//              This was the most puzzling to get just right
//              So that both high and low speed intermittent
//              and continuous COM transactions would never
//              cause a byte error when communicating with
//              a PC as fast as possible.
//***********************************************************

		if (ena_tx) begin                    // If a transmit request comes in
			tx_data_reg    <= tx_data ;  // register a copy of the input data bus
			tx_busy        <= 1 ;        // Set the busy flag
		end


// ***********************************************************************************************************************
// This section prepares the data, controls and shift register during the middle of the previous transmission bit.
// ***********************************************************************************************************************

if ( tx_period == (TX_PERIOD[15:0] >> 1) ) begin    // ******* at the center of a serial transmitter bit ********

		if ( tx_position==1 ) begin      // during the transmission of a stop bit
				tx_run  <= 0 ;   // turn off the transmitter running flag.  This point is the beginning of when
				                 // a synchronous transmit word alignment to an incomming RXD rx_trigger is permitted

				if (tx_busy) begin                         // before the next start bit, if the busy flag was set,
					tx_byte[8:1] <= tx_data_reg[7:0] ; // load the register copy of the tx_data_reg into the serial shift register
					tx_byte[9]   <= 1'b1 ;             // Add a stop bit into the shift register's 10th bit
					tx_byte[0]   <= 1'b0 ;             // Add a start bit into the serial shift register's first bit
					tx_busy      <= 1'b0 ;             // Turn off the busy flag signifying that another transmit byte may be loaded
					end				   // into the tx_data_reg

			end else begin

				tx_byte[8:0] <= tx_byte[9:1] ;   // at any other point than the stop-bit period, shift the serial tx_byte shift register
				tx_byte[9]   <= 1'b1 ;           // load a default stop bit into bit 10 of the serial shift register

				if ( tx_position == 0 ) tx_run  <= ~txd ;  // during the 'center of a serial 'START' transmitter bit'
						                           // if the serial UART TXD output pin has a start bit, turn on the transmitter running flag
						                           // which signifies the point where it is no longer permit-able to align a transmit word
						                           // to an incoming RXD byte potentially corrupting a serial transmission.
			end
end


// ***********************************************************************************************************************
// This section takes the above prepared registers and sends them out during the transition edge of the tx_period clock
// and during inactivity, or during the permitted alignment window, it will re-align the transmission period clock to
// a potential incoming rx_trigger event.
// ***********************************************************************************************************************

// if a RXD start bit transition edge is detected and the transmitter is not running,
// IE during the safe synchronous transmit word alignment period
// set halfway between the center of transmitting the stop bit and next start bit 

if (  rx_trigger && ~tx_run ) begin			

		tx_period      <= TX_PERIOD[15:0] - 2'h2 ;    // reset "SYNCHRONIZE" the transmit period timer to the rx_trigger event, recognizing that the rx_trigger is
							      // delayed by 2 clocks, so we shave off 2 additional clock cycles for dead perfect parallel TXD output alignment.

		tx_position    <= 1'b0 ;                      // force set the transmit reference position to the start bit
		txd            <= tx_byte[0] ;                // immediately set the UART TXD output to the serial out shift register's start bit.  IE see above if(tx_busy)

	end else if ( tx_period==0  )begin                    // if the transmitter period counter has reached it's end

		tx_period      <= TX_PERIOD[15:0]  ;          // reset the period counter
		txd            <= tx_byte[0] ;                // set the UART TXD output to the serial shift register's output.

		if ( tx_position == 0 ) tx_position <= 4'h9 ; // if the transmitter reference bit position counter is at the start bit, set it to bit 1.
		else tx_position  <= tx_position - 1'b1 ;     // otherwise, count down the position counter towards the stop bit

	end else tx_period <= tx_period - 1'b1 ;              // if the transmit period has not reached it's end, it should count down.

end // always

endmodule
