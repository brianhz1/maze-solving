module reset_synch(clk, RST_n, rst_n);

input logic clk, RST_n; 
output logic rst_n; 
logic ff1; 

always_ff @(negedge clk) begin 
if(!RST_n) begin
ff1 <= 0; 
rst_n <= 0; 

end else begin
ff1 <= 1'b1; 
rst_n <= ff1; 
end


end


endmodule 
