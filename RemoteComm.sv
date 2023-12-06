module RemoteComm(clk, rst_n, RX, TX, cmd, send_cmd, cmd_sent, resp_rdy, resp);

input clk, rst_n;		// clock and active low reset
input RX;				// serial data input
input send_cmd;			// indicates to tranmit 24-bit command (cmd)
input [15:0] cmd;		// 16-bit command

output TX;				// serial data output
output logic cmd_sent;	// indicates transmission of command complete
output resp_rdy;		// indicates 8-bit response has been received
output [7:0] resp;		// 8-bit response from DUT


//<<<  Your declaration stuff here >>>
typedef enum logic [1:0] {IDLE, TOP, BOT} state_t;

state_t state, nxt_state;	// state and next state
logic sel;					// sel=1 transmits upper 8 bits of cmd, sel=0 transmits lower bits
logic trmt;					// starts a UART transmit
logic set_cmd_snt;			// sets cmd_sent when asserted
logic [7:0]cmd_lower;		// holds lower 8-bits of cmd

wire [7:0]tx_data;			// 8-bit part to send
wire tx_done;


///////////////////////////////////////////////
// Instantiate basic 8-bit UART transceiver //
/////////////////////////////////////////////
UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
           .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(resp_rdy));

//  <<< Your implementation here >>>
// SM assignment
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
end

// SM datapath
always_comb begin
	// default outputs
	sel = 0;
	trmt = 0;
	set_cmd_snt = 0;
	nxt_state = state;
	
	case (state)
		TOP: if(tx_done) begin
			nxt_state = BOT;
			trmt = 1; // send bot half
		end
		
		BOT: if(tx_done) begin
			nxt_state = IDLE;
			set_cmd_snt = 1;
		end
		
		// IDLE state
		default: begin 
			sel = 1;
			if(send_cmd) begin
				nxt_state = TOP;
				trmt = 1; // send top half
			end
		end
	
	endcase

end

// SR_ff for cmd_sent
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		cmd_sent <= 0;
	else if(send_cmd)
		cmd_sent <= 0;
	else if(set_cmd_snt)
		cmd_sent <= 1;
end

// Register holds lower 8-bits of cmd
always_ff @(posedge clk) begin
	if(send_cmd) 
		cmd_lower <= cmd[7:0];
end

assign tx_data = sel ? cmd[15:8] : cmd_lower; // selects upper or lower 8-bits

endmodule	

