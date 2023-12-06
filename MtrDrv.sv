module MtrDrv(lft_spd,rght_spd,vbatt,clk,rst_n,lft_PWM1,lft_PWM2,rght_PWM1,rght_PWM2);

input signed [11:0] lft_spd, rght_spd;
input [5:0] vbatt;
input clk,rst_n;
output lft_PWM1,lft_PWM2,rght_PWM1,rght_PWM2;

logic signed [23:0] lft_prod,rght_prod;
logic signed [12:0] lft_prodscaled,rght_prodscaled;
logic signed [12:0] scale_factor;

DutyScaleROM scale_read(.clk(clk),.batt_level(vbatt),.scale(scale_factor));

// multiply scalefactor to left speed and divide by 2048 (11 bit left shift)
assign lft_prod = scale_factor * lft_spd;
assign lft_prodscaled = lft_prod[23:11];

assign rght_prod = scale_factor * rght_spd;
assign rght_prodscaled = rght_prod[23:11];

// 14-bit to 12-bit saturation
logic [11:0] lft_scaled, rght_scaled;
assign lft_scaled = (lft_prodscaled[12] && !{&lft_prodscaled[11]}) ? 12'h800 :
                    (!lft_prodscaled[12] && lft_prodscaled[11]) ? 12'h7FF : lft_prodscaled[11:0];

assign rght_scaled = (rght_prodscaled[12] && !{&rght_prodscaled[11]}) ? 12'h800 :
                    (!rght_prodscaled[12] && rght_prodscaled[11]) ? 12'h7FF : rght_prodscaled[11:0];

// generate PWM signals
PWM12 lftpwm(.duty(lft_scaled + 12'h800),.clk(clk),.rst_n(rst_n),.PWM1(lft_PWM1),.PWM2(lft_PWM2));
PWM12 rghtpwm(.duty(rght_scaled + 12'h800),.clk(clk),.rst_n(rst_n),.PWM1(rght_PWM1),.PWM2(rght_PWM2));

endmodule