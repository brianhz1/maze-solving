module cmd_proc(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, send_resp, strt_cal, cal_done, in_cal,
sol_cmplt, strt_hdng, strt_mv, stp_lft, stp_rght, dsrd_hdng, mv_cmplt, cmd_md);

input logic clk, rst_n, cmd_rdy, cal_done, sol_cmplt, mv_cmplt; 
input logic [15:0] cmd; 

output logic clr_cmd_rdy, send_resp, strt_cal, in_cal, strt_hdng, strt_mv,
stp_lft, stp_rght, cmd_md; 
output logic [11:0] dsrd_hdng; 

typedef enum logic [2:0] {IDLE, STRT_CAL, WAIT_CAL, STRT_HDNG, WAIT_HDNG, 
STRT_MV, WAIT_MV, SOLVE} state_t; 

state_t curr_state, next_state; 

logic hdng_en, mov_en; 

always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		dsrd_hdng <= 0; 
	end else if(hdng_en) begin
		dsrd_hdng <= cmd[11:0];
	end
end

always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		{stp_lft, stp_rght} <= 0; 
	end else if(mov_en) begin
		{stp_lft, stp_rght} <= cmd[1:0];
	end
end



always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin 
		curr_state <= IDLE;
	end else begin
		curr_state <= next_state; 
	end
end

always_comb begin
next_state = curr_state;
clr_cmd_rdy = 0; 
send_resp = 0; 
strt_cal = 0; 
in_cal = 0; 
strt_hdng = 0; 
strt_mv = 0; 
hdng_en = 0; 
mov_en = 0;
cmd_md = 1; 
	case(curr_state) 

		WAIT_CAL: begin
			in_cal = 1; 
			if(cal_done) begin
				next_state = IDLE; 
				send_resp = 1;
			end	
		end

		WAIT_HDNG: begin
			if(mv_cmplt) begin
				next_state = IDLE; 
				send_resp = 1; 
			end

		end


		WAIT_MV: begin
			if(mv_cmplt) begin
				next_state = IDLE; 
				send_resp = 1; 
			end
		end

		SOLVE: begin
			cmd_md = 0; 
			if(sol_cmplt) begin
				next_state = IDLE;
				send_resp = 1;
			end

		end

		default: begin //IDLE
			if(cmd_rdy) begin 
				clr_cmd_rdy = 1;
				case(cmd[15:13])
					3'b000: begin
						next_state = WAIT_CAL; 
						strt_cal = 1; 
					end

					3'b001: begin
						next_state = WAIT_HDNG; 
						hdng_en = 1; 
						strt_hdng = 1; 
					end	
	
					3'b010: begin
						next_state = WAIT_MV; 
						strt_mv = 1; 
						mov_en = 1;
						
					end

					3'b011: begin
						next_state = SOLVE; 
					end
					
					default: begin

					end 
				
				endcase
				 
			end
		end
	endcase
end


endmodule
