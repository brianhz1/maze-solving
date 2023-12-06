module UART_rx (
	input clk,				// clock
	input rst_n,			// active low asynch reset
	input RX,				// serial data input
	input clr_rdy,			// sets rdy to 0 when asserted
	output [7:0] rx_data,	// byte received
	output logic rdy		// asserted and stays high when byte receives until next byte or clr_rdy is asserted
);

	typedef enum logic {IDLE, RECEIVE} state_t;
	
	state_t state, nxt_state;			// state machine state and next state
	logic start, receiving, set_rdy;	// state machine output
	logic [3:0] bit_cnt;				// count for number of bits received
	logic [11:0] baud_cnt;				// clk divider by 2604 (19200 baud)
	logic [8:0] rx_shift_reg;			// holds data shifted in
	logic shift;						// shift in a bit
	
	// state machine assignment
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	// state machine next state logic 
	always_comb begin
		// default outputs
		nxt_state = state;
		start = 0;
		receiving = 0;
		set_rdy = 0;
		
		case (state)
			IDLE: if (!RX) begin
				start = 1;
				nxt_state = RECEIVE;
			end
			RECEIVE: if (bit_cnt >= 10) begin
				nxt_state = IDLE;
				set_rdy = 1;
			end else
				receiving = 1;
		
		endcase
		
	end
	
	// SR-FF for rdy
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			rdy <= 0;
		else if (start | clr_rdy)
			rdy <= 0;
		else if (set_rdy)
			rdy <= 1;
	end
	
	// 4-bit counter for number of bits transmitted
	always_ff @(posedge clk) begin
		if (start)
			bit_cnt <= 4'h0;
		else if (shift)
			bit_cnt <= bit_cnt + 1;		// increment
	end
	
	// 12-bit clock divider
	always_ff @(posedge clk) begin
		if (start | shift)
			baud_cnt <= start ? 1301: 2603; // assign half baud period on start, otherwise full baud
		else if (receiving) 
			baud_cnt <= baud_cnt - 1;		// decrement counter
	end
	
	assign shift = (baud_cnt == 0);		// shift when counter reaches 0
	
	// shift logic
	always_ff @(posedge clk) begin
		if (shift) 
			rx_shift_reg <= {RX, rx_shift_reg[8:1]};	// shift in bit at RX
	end
	
	assign rx_data = rx_shift_reg[7:0];		// output lower 8 bits
	
endmodule