module maze_solve(cmd_md, cmd0, lft_opn, rght_opn, mv_cmplt, sol_cmplt, clk, rst_n,
strt_hdng, dsrd_hdng, strt_mv, stp_lft, stp_rght); 

input logic cmd_md, cmd0, lft_opn, rght_opn, mv_cmplt, sol_cmplt, clk, rst_n;

output logic strt_hdng, strt_mv, stp_lft, stp_rght; 
output logic [11:0]dsrd_hdng;

logic [11:0]dsrd_hdng_sm; 
logic hdng_en; 

localparam [11:0]North = 12'h000; 
localparam [11:0]West = 12'h3FF; 
localparam [11:0]South = 12'h7FF; 
localparam [11:0]East = 12'hC00; 

assign stp_lft = cmd0; 
assign stp_rght = !cmd0; 

typedef enum logic [2:0]{IDLE,FRWRD,WAIT,SET_HDNG,STRT_HDNG}state_t;


state_t curr_state, next_state; 

always_ff @(posedge clk, negedge rst_n) begin 
  if(!rst_n) begin
	curr_state <= IDLE; 
  end else begin
	curr_state <= next_state;
  end

end

always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
	dsrd_hdng <= 0; 
  end else if(hdng_en) begin
	dsrd_hdng <= dsrd_hdng_sm; 
  end
end


always_comb begin
  strt_hdng = 0; 
  hdng_en = 0; 
  dsrd_hdng_sm = 0; 
  strt_mv = 0; 
  next_state = curr_state; 


  case(curr_state)

	SET_HDNG: begin
		if(sol_cmplt) begin
			next_state = IDLE; 
		end	
		else if(mv_cmplt & cmd0) begin
			if(lft_opn | !(lft_opn | rght_opn)) begin
				next_state = STRT_HDNG; 
				strt_hdng = 1; 
				hdng_en = 1;
				if(dsrd_hdng == North) begin
					dsrd_hdng_sm = West;
				end else if(dsrd_hdng == West) begin
					dsrd_hdng_sm = South;
				end else if(dsrd_hdng == South) begin
					dsrd_hdng_sm = East;
				end else if(dsrd_hdng == East) begin
					dsrd_hdng_sm = North;
				end
			end
		
			else if(rght_opn) begin
				next_state = STRT_HDNG;
				strt_hdng = 1; 
				hdng_en = 1;
				if(dsrd_hdng == North) begin
					dsrd_hdng_sm = East;
				end else if(dsrd_hdng == East) begin
					dsrd_hdng_sm = South;
				end else if(dsrd_hdng == South) begin
					dsrd_hdng_sm = West;
				end else if(dsrd_hdng == West) begin
					dsrd_hdng_sm = North;
				end 
			end 
			
		end else if(mv_cmplt & !cmd0) begin
			if(rght_opn  | !(lft_opn | rght_opn)) begin
				next_state = STRT_HDNG; 
				strt_hdng = 1; 
				hdng_en = 1;
				if(dsrd_hdng == North) begin
					dsrd_hdng_sm = East;
				end else if(dsrd_hdng == East) begin
					dsrd_hdng_sm = South;
				end else if(dsrd_hdng == South) begin
					dsrd_hdng_sm = West;
				end else if(dsrd_hdng == West) begin
					dsrd_hdng_sm = North;
				end

			end else
			if(lft_opn) begin
				next_state = STRT_HDNG;
				strt_hdng = 1; 
				hdng_en = 1;
				if(dsrd_hdng == North) begin
					dsrd_hdng_sm = West;
				end else if(dsrd_hdng == West) begin
					dsrd_hdng_sm = South;
				end else if(dsrd_hdng == South) begin
					dsrd_hdng_sm = East;
				end else if(dsrd_hdng == East) begin
					dsrd_hdng_sm = North;
				end
			end 

		end
		
	end

	STRT_HDNG: begin
		strt_hdng = 1;
		next_state = WAIT; 
	end
	
	WAIT: begin
		if(mv_cmplt) begin
			next_state = FRWRD; 
		end 
			
	end

	FRWRD: begin
		strt_mv = 1;
		next_state = SET_HDNG; 
	end

 
	default: begin  //IDLE
		if(!cmd_md) begin
			next_state = WAIT; 
			strt_mv = 1;
		end
	end

  endcase

end

endmodule
