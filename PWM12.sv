module PWM12(duty,clk,rst_n,PWM1,PWM2);

input [11:0] duty;
input clk,rst_n;
output reg PWM1,PWM2;

localparam NONOVERLAP = 12'h02c;

logic [11:0] cnt;
logic PWM1_S,PWM1_R,PWM2_S,PWM2_R;


assign PWM1_S = (cnt >= duty+NONOVERLAP) ? 1'b1 : 1'b0;
assign PWM1_R = (&cnt) ? 1'b1 : 1'b0;

assign PWM2_S = (cnt >= NONOVERLAP) ? 1'b1 : 1'b0;
assign PWM2_R = (cnt >= duty) ? 1'b1 : 1'b0;

// duty control counter for PWM
always_ff @(posedge clk,negedge rst_n) begin
  if(!rst_n)
    cnt <= 12'h000;
  else
    cnt <= cnt+1;
end

always_ff @(posedge clk,negedge rst_n) begin
  if(!rst_n)
    PWM2 <= 1'b0;
  else if(PWM2_R)
    PWM2 <= 1'b0;
  else if(PWM2_S)
    PWM2 <= 1'b1;
  else
    PWM2 <= PWM2;
end

always_ff @(posedge clk,negedge rst_n)begin
  if(!rst_n)
    PWM1 <= 1'b0;
  else if(PWM1_R)
    PWM1 <= 1'b0;
  else if(PWM1_S)
    PWM1 <= 1'b1;
  else
    PWM1 <= PWM1;
end

endmodule