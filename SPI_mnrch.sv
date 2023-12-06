module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, wt_data, done, rd_data);
	input clk;				// clk
	input rst_n;			// active low async reset
	input MISO;				// SPI MISO line
	input wrt;				// initiate SPI transmission when high
	input [15:0] wt_data;	// data to send
	output logic SS_n;		// Serf select
	output logic SCLK;		// SPI SCLK
	output MOSI;			// SPI MOSI line
	output logic done;		// held high after a transmission is complete
	output [15:0] rd_data;	// data received by SPI

	typedef enum logic [2:0] {IDLE, FRONT, SHIFT, BACK} state_t;

	logic smpl;		// rise of SCLK
	logic shft;		// fall of SCLK
	wire done15;	// high when 15 bits shifted
	logic ld_SCLK;	// initials SCLK to 5'10111
	logic init;
	logic set_done;	// sets done and SS_n
	logic [4:0] SCLK_div;	// clk divider counter to generate SCLK
	logic [3:0] bit_cntr;	// counts number of bits shifted
	logic [15:0] shft_reg;	// 16-bit shift register for SPI MOSI and MISO lines
	logic MISO_smpl;  		// sample of MISO done at rising edge of SCLK
	
	state_t state, nxt_state; // state and next state

	// SM assignment
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) 
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	// SM datapath
	always_comb begin
		ld_SCLK = 0;
		init = 0;
		smpl = 0;
		shft = 0;
		set_done = 0;
		nxt_state = state;
		
		case (state)
			IDLE: begin
				ld_SCLK = 1;
				if(wrt) begin
					nxt_state = FRONT;
					init = 1;
				end
			end
			
			FRONT: if(&SCLK_div)
				nxt_state = SHIFT;
		
			SHIFT: begin				
				if(done15)
					nxt_state = BACK;
				else if(&SCLK_div)
					shft = 1;
				else if(SCLK_div == 5'b01111)
					smpl = 1;
			end
			
			BACK: begin
				if(&SCLK_div) begin
					nxt_state = IDLE;
					shft = 1;
					set_done = 1;
					ld_SCLK = 1;
				end
				else if(SCLK_div == 5'b01111)
					smpl = 1;
			end	
		endcase
	end
	
	// infer done SR_ff
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) 
			done <= 0;
		else if(init)
			done <= 0;
		else if(set_done)
			done <= 1;
	end
	
	// infer SS_n SR_FF
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) 
			SS_n <= 1;
		else if(init)
			SS_n <= 0;
		else if(set_done)
			SS_n <= 1;
	end
	
	// bit counter
	always_ff @(posedge clk) begin
		if(shft)
			bit_cntr <= bit_cntr + 1;
		else if(init)
			bit_cntr <= 4'b0000;
	end
	
	// asserts done15 when 16-bits shifted
	assign done15 = &bit_cntr;
	
	// SCLK generator
	always_ff @(posedge clk) begin
		if(ld_SCLK)
			SCLK_div <= 5'b10111;
		else
			SCLK_div <= SCLK_div + 1;
	end	
	
	// assigns SCLK to MSB of counter
	assign SCLK = SCLK_div[4];
	
	// MISO sample ff
	always_ff @(posedge clk) begin
		if(smpl)
			MISO_smpl <= MISO;
	end
	
	// infer SPI 16-bit shift register
	always_ff @(posedge clk) begin
		if(init)
			shft_reg <= wt_data;
		else if(shft)
			shft_reg <= {shft_reg[14:0], MISO_smpl};
	end
	
	// set MOSI to MSB of shft_reg
	assign MOSI = shft_reg[15];
	
	assign rd_data = shft_reg;
	
endmodule