module UART_tx (
	input clk,				// clock
	input rst_n,			// active low asynch reset
	input trmt,				// initiate transmission
	input [7:0] tx_data,	// byte to transmit
	output TX,				// serial data output
	output reg tx_done		// asserted when transmission complete
);

	typedef enum logic {IDLE, TRANSMIT} state_t;
	
	state_t state, nxt_state;			// state machine state and next state
	logic init, transmitting, set_done;	// state machine output
	logic [3:0] bit_cnt;				// count for number of bits transmitted
	logic [11:0] baud_cnt;				// clk divider by 2604 (19200 baud)
	logic [8:0] tx_shift_reg;			// data to shift out
	logic shift;						// shift a bit out
	
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
		init = 0;
		transmitting = 0;
		set_done = 0;
		
		case (state)
			IDLE: if (trmt) begin
				init = 1;
				nxt_state = TRANSMIT;
			end
			TRANSMIT: if (bit_cnt >= 10) begin
				nxt_state = IDLE;
				set_done = 1;
			end else
				transmitting = 1;
		
		endcase
		
	end
	
	// SR-FF for tx_done
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			tx_done <= 0;
		else if (init)
			tx_done <= 0;
		else if (set_done)
			tx_done <= 1;
	end
	
	// 4-bit counter for number of bits transmitted
	always_ff @(posedge clk) begin
		if (init)
			bit_cnt <= 4'h0;
		else if (shift)
			bit_cnt <= bit_cnt + 1;		// increment by 1
	end
	
	// 12-bit clock divider
	always_ff @(posedge clk) begin
		if (init | shift)
			baud_cnt <= 12'h000;
		else if (transmitting) 
			baud_cnt <= baud_cnt + 1;	// increment by 1
	end

	assign shift = baud_cnt >= 2603;	// shift every 2064 clock cycles

	// shift logic
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			tx_shift_reg <= '1;
		else if (init) 
			tx_shift_reg <= {tx_data, 1'b0};			// parallel load 
		else if (shift)
			tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};	// shift in 1'b1
	end
	
	assign TX = tx_shift_reg[0];	// shift out LSB

endmodule
