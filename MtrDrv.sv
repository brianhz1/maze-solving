module MtrDrv(lft_spd,rght_spd,vbatt,clk,rst_n,lftPWM1,lftPWM2,rghtPWM1,rghtPWM2);

input signed [11:0] lft_spd, rght_spd;
input [11:0] vbatt;
input clk,rst_n;
output lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;

logic signed [23:0] lft_prod,rght_prod;
logic signed [12:0] lft_prodscaled,rght_prodscaled;
logic signed [12:0] scale_factor;

DutyScaleROM scale_read(.clk(clk),.batt_level(vbatt[9:4]),.scale(scale_factor));

logic signed [11:0] lft_spd_pipeline, rght_spd_pipeline;
logic signed [23:0] lft_prod_pipeline,rght_prod_pipeline;
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		lft_spd_pipeline <= 0;
		rght_spd_pipeline <= 0;
		
		lft_prod_pipeline <= 0;
		rght_prod_pipeline <= 0;
	end
	else begin
		lft_spd_pipeline <= lft_spd;
		rght_spd_pipeline <= rght_spd;
		
		lft_prod_pipeline <= lft_prod;
		rght_prod_pipeline <= rght_prod;
	end
end

// multiply scalefactor to left speed and divide by 2048 (11 bit left shift)
assign lft_prod = scale_factor * lft_spd_pipeline;
assign lft_prodscaled = lft_prod_pipeline[23:11];

assign rght_prod = scale_factor * rght_spd_pipeline;
assign rght_prodscaled = rght_prod_pipeline[23:11];

// 14-bit to 12-bit saturation
logic [11:0] lft_scaled, rght_scaled;
assign lft_scaled = (lft_prodscaled[12] && !{&lft_prodscaled[11]}) ? 12'h800 :
                    (!lft_prodscaled[12] && lft_prodscaled[11]) ? 12'h7FF : lft_prodscaled[11:0];

assign rght_scaled = (rght_prodscaled[12] && !{&rght_prodscaled[11]}) ? 12'h800 :
                    (!rght_prodscaled[12] && rght_prodscaled[11]) ? 12'h7FF : rght_prodscaled[11:0];

logic [11:0] lft_negative;
assign lft_negative = (~lft_scaled) + 1; 

// generate PWM signals
PWM12 lftpwm(.duty(12'h800 + lft_negative),.clk(clk),.rst_n(rst_n),.PWM1(lftPWM1),.PWM2(lftPWM2));
PWM12 rghtpwm(.duty(12'h800 + rght_scaled),.clk(clk),.rst_n(rst_n),.PWM1(rghtPWM1),.PWM2(rghtPWM2));

endmodule