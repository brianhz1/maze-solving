module IR_math #(parameter signed NOM_IR= 12'h900) ( 
	input clk,
	input rst_n,
	input lft_opn, 
	input rght_opn, 
	input signed [11:0] lft_IR, 
	input signed [11:0] rght_IR, 
	input signed [8:0] IR_Dtrm,
	input en_fusion,
	input [11:0] dsrd_hdng,
	output [11:0] dsrd_hdng_adj
);	

	wire signed [12:0] IR_diff;
	wire signed [11:0] IR_term;
	wire signed [12:0] ext_IR_term;
	wire signed [12:0] ext_D_term;
	wire signed [12:0] PD;
	
	logic [12:0] PD_pipeline;
	
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			PD_pipeline <= 0;
		else
			PD_pipeline <= PD;
	end
	
	assign IR_diff = lft_IR - rght_IR;								// diff between left and right sensors
	
	assign IR_term = (lft_opn & rght_opn) ? 12'h000 : 			    // both sensors open use only gyro
					  lft_opn ? NOM_IR - rght_IR : 				// left sensor open use right only
					  rght_opn ? lft_IR - NOM_IR : 				// right sensor open use left only
					  IR_diff[12:1];  								// both sensors closed
					  
	assign ext_IR_term	= {{6{IR_term[11]}} ,IR_term[11:5]};	    // divide by 32 and sign extend to 13 bits
	
	assign ext_D_term = {{2{IR_Dtrm[8]}}, IR_Dtrm, 2'b00};			// multiply by 4 and sign extend to 13 bits
	
	assign PD = (ext_D_term + ext_IR_term);							// get PD from P and D terms

	assign dsrd_hdng_adj = en_fusion ? PD_pipeline[12:1] + dsrd_hdng : dsrd_hdng;	// get adjusted heading
	
endmodule