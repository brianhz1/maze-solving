module navigate(clk,rst_n,strt_hdng,strt_mv,stp_lft,stp_rght,mv_cmplt,hdng_rdy,moving,
                en_fusion,at_hdng,lft_opn,rght_opn,frwrd_opn,frwrd_spd);
				
  parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
  input clk,rst_n;					// 50MHz clock and asynch active low reset
  input strt_hdng;					// indicates should start a new heading
  input strt_mv;					// indicates should start a new forward move
  input stp_lft;					// indicates should stop at first left opening
  input stp_rght;					// indicates should stop at first right opening
  input hdng_rdy;					// new heading reading ready....used to pace frwrd_spd increments
  output logic mv_cmplt;			// asserted when heading or forward move complete
  output logic moving;				// enables integration in PID and in inertial_integrator
  output en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
  input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
  input lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
  output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID
  
  //<< Your declarations of states, regs, wires, ...>>
  typedef enum logic [2:0] {IDLE, HDNG, ACCEL, DEC, DEC_FAST} state_t;
  state_t state, nxt_state;			 // state and next state
  logic lft_opn_rise, rght_opn_rise; // rising edge detectors for lft/rght_opn
  logic lft_opn_prev, rght_opn_prev; // prev value of lft/rght_opn
  
  logic init_frwrd;					 // sets forward speed to MIN_FRWRD when asserted
  logic inc_frwrd;					 // accelerates by incrementing foward speed
  logic dec_frwrd, dec_frwrd_fast;	 // decelerate by decrementing foward slowly or quickly
  logic [5:0] frwrd_inc;
  
  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  
  ////////////////////////////////
  // Now form forward register //
  //////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  frwrd_spd <= 11'h000;
	else if (init_frwrd)		// assert this signal when leaving IDLE due to strt_mv
	  frwrd_spd <= MIN_FRWRD;									// min speed to get motors moving
	else if (hdng_rdy && inc_frwrd && (frwrd_spd<MAX_FRWRD))	// max out at 2A0
	  frwrd_spd <= frwrd_spd + {5'h00,frwrd_inc};				// always accel at 1x frwrd_inc
	else if (hdng_rdy && (frwrd_spd>11'h000) && (dec_frwrd | dec_frwrd_fast))
	  frwrd_spd <= ((dec_frwrd_fast) && (frwrd_spd>{2'h0,frwrd_inc,3'b000})) ? frwrd_spd - {2'h0,frwrd_inc,3'b000} : // 8x accel rate
                    (dec_frwrd_fast) ? 11'h000 :	  // if non zero but smaller than dec amnt set to zero.
	                (frwrd_spd>{4'h0,frwrd_inc,1'b0}) ? frwrd_spd - {4'h0,frwrd_inc,1'b0} : // slow down at 2x accel rate
					11'h000;

  //<< Your implementation of ancillary circuits and SM >>
	assign frwrd_inc = FAST_SIM ? 6'h18 : 6'h02;
  
	// assert en_fusion when forward speed is greater than 50% max speed
	assign en_fusion = (frwrd_spd > MAX_FRWRD[10:1]);
  
	// ff for previous lft/rght_opn
	always_ff @(posedge clk) begin
		lft_opn_prev <= lft_opn;
		rght_opn_prev <= rght_opn;
	end
	// edge detectors for lft/rght_opn
	assign lft_opn_rise = lft_opn & ~lft_opn_prev;
	assign rght_opn_rise = rght_opn & ~rght_opn_prev;
  
	// SM assignments
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else 
			state <= nxt_state;
	end
	
	// SM next state logic
	always_comb begin
		// default outputs
		moving = 0;
		init_frwrd = 0;
		inc_frwrd = 0;
		dec_frwrd = 0;
		dec_frwrd_fast = 0;
		mv_cmplt = 0;
		nxt_state = state;
		
		case (state)
			HDNG: if (at_hdng) begin
				mv_cmplt = 1;
				nxt_state = IDLE;
			end else
				moving = 1;
				
			ACCEL: begin
				moving = 1;
				inc_frwrd = 1;
				
				if ((lft_opn_rise && stp_lft) || (rght_opn_rise && stp_rght)) // open wall on left or right
					nxt_state = DEC;
				else if (~frwrd_opn) // wall in front
					nxt_state = DEC_FAST; 
			end
				
			DEC: begin
				moving = 1;
				dec_frwrd = 1;
				if (frwrd_spd == 0) begin
					mv_cmplt = 1;
					nxt_state = IDLE;
				end
			end
			
			DEC_FAST: begin
				moving = 1;
				dec_frwrd_fast = 1;
				if (frwrd_spd == 0) begin
					mv_cmplt = 1;
					nxt_state = IDLE;
				end
			end
			
			// IDLE state
			default: if (strt_hdng)
				nxt_state = HDNG;
			else if (strt_mv) begin
				init_frwrd = 1;
				nxt_state = ACCEL;
			end
		endcase
	
	end

endmodule
  