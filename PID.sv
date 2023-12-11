module PID (
	input clk,				// clock
	input rst_n,			// asynch active low reset
	input moving,			// high when turning or moving foward
	input [11:0] dsrd_hdng,	// Signed desired heading
	input [11:0] actl_hdng,	// actual heading
	input hdng_vld,			// high when new valid gyro reading
	input [10:0] frwrd_spd,	// unsigned forward speed
	output at_hdng,			// asserted if error is small
	output [11:0] lft_spd,	// signed left motor speed
	output [11:0] rght_spd	// signed right motor speed
);

	logic [13:0] P_term;	
	logic [11:0] I_term;
	logic [12:0] D_term;

	// P term
	localparam P_COEFF = 4'h3;

	wire [11:0] error;				// actl_hdng - dsrd_hdng
	wire signed [9:0] err_sat; 		// saturated error
	
	assign error = actl_hdng - dsrd_hdng;
 	
	logic signed [9:0] err_sat_pipeline; 
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			err_sat_pipeline <= 0;
		end
		else begin
			err_sat_pipeline <= err_sat;
		end
	end
 
	assign err_sat = (error[11] && ~&error[10:9]) ? 10'h200 : 		// saturate to most negative number
					 (~error[11] && |error[10:9]) ? 10'h1FF :  		// saturate to most positve number
					 error[9:0];							  	 	// copy lower 10 bits
	
	assign P_term = $signed(P_COEFF) * err_sat_pipeline;

	// I term
	logic [15:0] nxt_integrator, integrator;
	wire [15:0] integrator_sum;				// sum of previous integrator and sign extended error
	wire [15:0] valid_integrator;			// integrator or integrator_sum depended on signal validity
	wire [15:0] ext_err_sat;				// sign extended err_sat
	wire overflow;

	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			integrator <= 16'h0000;
		else
			integrator <= nxt_integrator;
	end

	assign ext_err_sat = {{6{err_sat_pipeline[9]}}, err_sat_pipeline};									// sign extends error
	assign integrator_sum = ext_err_sat + integrator;									// adds extended error with integrator
	assign valid_integrator = (!overflow && hdng_vld) ? integrator_sum : integrator;    // uses previous integrator if not valid
	assign nxt_integrator = moving ? valid_integrator : 16'h0000;						// assigns next value for the ff

	assign overflow = (integrator[15] == ext_err_sat[15]) && (integrator_sum[15] != integrator[15]);	// checks for overflow

	assign I_term = integrator[15:4];

	// D term
	localparam D_COEFF = 5'h0E;
	logic signed [7:0] D_diff_sat;
	logic [10:0] D_diff;
	logic [9:0] prev_prev_err, prev_err;	// holds last two previous error values

	assign D_diff = {err_sat_pipeline[9], err_sat_pipeline} - {prev_prev_err[9], prev_prev_err};
	assign D_diff_sat = (D_diff[10] && ~&D_diff[9:7]) ? 8'h80 : // saturate to most negative
						(~D_diff[10] && |D_diff[9:7]) ? 8'h7F :	// saturate to most positive
						D_diff[7:0];							// copy lower 8 bits
	
	assign D_term = D_diff_sat * $signed(D_COEFF);		
	
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			prev_err <= 0;
			prev_prev_err <= 0;
		end 
		else if(hdng_vld) begin
			prev_err <= err_sat_pipeline;
			prev_prev_err <= prev_err;
		end
	end
	
	// PID logic
	logic [14:0] P_term_ext, I_term_ext, D_term_ext;	// Extended P, I, D terms to 15 bits
	logic [14:0] PID_sum;								// PID sum
	logic [11:0] PID;									// PID sum divided by 8
	logic [11:0] frwrd_spd_ext;							// Sign extended frwrd_spd
	
	assign at_hdng = err_sat_pipeline[9] ? (-err_sat_pipeline < 10'd30) : (err_sat_pipeline < 10'd30);
	
	assign frwrd_spd_ext = {frwrd_spd[10], frwrd_spd};	// extend to 12 bits
	
	assign P_term_ext = {{P_term[13]}, P_term};		// extend to 15 bits
	assign I_term_ext = {{3{I_term[11]}}, I_term};	// extend to 15 bits
	assign D_term_ext = {{2{D_term[12]}}, D_term};	// extend to 15 bits
	
	assign PID_sum = (P_term_ext + I_term_ext + D_term_ext); // sum P, I, D terms
	
	logic [11:0] PID_pipeline;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			PID_pipeline <= 0;
		end
		else begin
			PID_pipeline <= PID;
		end
	end
	
	assign PID = PID_sum[14:3];								 // divide sum by 8
	
	assign lft_spd = moving ? PID_pipeline + frwrd_spd : 12'h000;
	assign rght_spd = moving ? frwrd_spd - PID_pipeline : 12'h000;
	
endmodule