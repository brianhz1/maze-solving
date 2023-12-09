
//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of mazeRunner.  Fusion correction     //
// comes from IR_Dtrm when en_fusion is high.   //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,IR_Dtrm,
                  SS_n,SCLK,MOSI,MISO,INT,moving,en_fusion);

  parameter FAST_SIM = 1;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;							// SPI input from inertial sensor
  input INT;							// goes high when measurement ready
  input strt_cal;						// initiate claibration of yaw readings
  input moving;							// Only integrate yaw when going
  input en_fusion;						// do fusion corr only when forward at decent clip
  input [8:0] IR_Dtrm;					// derivative term of IR sensors (used for fusion)
  
  output cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs
 

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////
  logic [7:0]cyh_ff; 
  logic [7:0]cyl_ff; 
  
  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  logic wrt, vld, C_Y_H, C_Y_L; 
  logic [15:0]cmd;  

  //////////////////////////////////////////////////////////////
  // Declare any needed internal signals that connect blocks //
  ////////////////////////////////////////////////////////////
  wire done;
  wire [15:0] inert_data;		// Data back from inertial sensor (only lower 8-bits used)
  wire signed [15:0] yaw_rt;
  
  
  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum logic[2:0] {INIT1, INIT2, INIT3, INIT_WAIT, IDLE, R_LOW, R_HIGH, VALID}state_t; 
  state_t curr_state, next_state; 
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
                 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rspns(inert_data),.cmd(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and gaurdrail info and produces a heading reading            //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),
                        .vld(vld),.rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),
						.en_fusion(en_fusion),.IR_Dtrm(IR_Dtrm),.heading(heading));
	

  //<< remaining logic (SM, timer, holding registers...) >>

  //double flop INT signal
  logic INT_ff;
  logic INT_df;
  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		INT_df <= 1'b0; 
		INT_ff <= 1'b0; 
	end else begin
		INT_ff <= INT; 
		INT_df <= INT_ff; 
	end
  end

  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		cyh_ff <= 8'h00; 
	end else if(C_Y_H) begin
		cyh_ff <= inert_data;
	end

  end

   always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		cyl_ff <= 8'h00; 
	end else if(C_Y_L) begin
		cyl_ff <= inert_data;
	end

  end
  
  assign yaw_rt = {cyh_ff, cyl_ff}; 

  always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
	curr_state <= INIT1; 
	else
	curr_state <= next_state; 
  end

	logic [15:0] timer;
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n)
			timer <= 15'h0000;
		else
			timer <= timer+1;
	end

  always_comb begin
	wrt = 0; 
	vld = 0; 
	C_Y_H = 0; 
	C_Y_L = 0; 
	cmd = 16'h0000; 
	next_state = curr_state; 
	
  	case(curr_state) 
		INIT1: begin //INIT1
			if(&timer) begin
				wrt = 1; 
				next_state = INIT2; 
				cmd = 16'h0D02; 
			end
		end
		
		INIT2: begin
			if(done) begin
				wrt = 1; 
				next_state = INIT3; 
				cmd = 16'h1160; 
			end
		end

		INIT3: begin
			if(done) begin
				wrt = 1;
				next_state = INIT_WAIT; 
				cmd = 16'h1440; 
			end
		end
		
		// waits for SPI cmd from INIT3 to finish
		INIT_WAIT: begin 
			if(done)
				next_state = IDLE;
		end

		IDLE: begin
			if(INT_df) begin
				next_state = R_LOW; 
				cmd = 16'hA600; 
				wrt = 1; 
			end
		end
		
		R_LOW: begin
			if(done) begin
				next_state = R_HIGH; 
				C_Y_L = 1;
				cmd = 16'hA700; 
				wrt = 1; 
			end 
		end

		R_HIGH: begin
			if(done) begin
				next_state = VALID; 
				C_Y_H = 1; 
			end 
		end
		
		VALID: begin
			vld = 1;
			next_state = IDLE;
		end
  	endcase 
  end
  
 
endmodule
	  