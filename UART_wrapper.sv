module UART_wrapper (clk, rst_n, RX, cmd_rdy, cmd, clr_cmd_rdy, trmt, resp, tx_done, TX);
	input clk, rst_n;		// clock and active low asynch reset
	input RX; 				// UART rx line
	input trmt;				// start a transmition
	input [7:0] resp;		// sent upon pulse from trmt 
	input clr_cmd_rdy;		// knocks down cmd_rdy
	output logic cmd_rdy; 	// asserted after valid 16-bit command received
	output [15:0] cmd; 		// 16-bit command
	output tx_done;			// Asserted after resp has been sent
	output TX;				// UART tx line

	// Internal signals
	wire rx_rdy;
	wire [7:0] rx_data;
	logic clr_rx_rdy;		// resets rx_rdy in UART
	logic [7:0] cmd_upper;	// upper 8 bits of command
	logic en;				// enables cmd_upper register

	// Instantiate UART
	UART iUART(.clk(clk),.rst_n(rst_n),.RX(RX),.TX(TX),.rx_rdy(rx_rdy),.clr_rx_rdy(clr_rx_rdy),.rx_data(rx_data),.trmt(trmt),.tx_data(resp[7:0]),.tx_done(tx_done));

	typedef enum logic [1:0] {IDLE, RECEIVE_BOT, CMD_RDY} state_t;
	state_t state, nxt_state;	// state and next state of SM
	
	// SM assignment
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else 
			state <= nxt_state;
	end
	
	// SM datapath
	always_comb begin
		// default outputs
		clr_rx_rdy = 0;
		cmd_rdy = 0;
		en = 0;
		nxt_state = state;
		
		case (state)
			RECEIVE_BOT: if (rx_rdy) begin
				nxt_state = CMD_RDY;
				cmd_rdy = 1;
			end
			
			CMD_RDY: begin
				cmd_rdy = 1;
				if (clr_cmd_rdy)
					nxt_state = IDLE;
					clr_rx_rdy = 1;
			end
			
			// IDLE state
			default: if (rx_rdy) begin
				nxt_state = RECEIVE_BOT;
				clr_rx_rdy = 1;
				en = 1;
			end
		
		endcase
	
	end
	
	// register holds upper 8 bits of command
	always_ff @(posedge clk) begin
		if (en)
			cmd_upper <= rx_data;
	end
	
	assign cmd = {cmd_upper, rx_data}; // combines upper and lower parts of cmd

endmodule