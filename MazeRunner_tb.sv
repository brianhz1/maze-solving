`timescale 1ns/1ps
module MazeRunner_tb();

  //<< optional include or import >>
  
  reg clk,RST_n;
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xDA0 is nominal
  
  logic cmd_sent;				
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  
  /////////////////////////////////////////////////////////////////////////
  // Signals interconnecting MazeRunner to RunnerPhysics and RemoteComm //
  ///////////////////////////////////////////////////////////////////////
  wire TX_RX,RX_TX;
  wire INRT_SS_n,INRT_SCLK,INRT_MOSI,INRT_MISO,INRT_INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;
  wire IR_lft_en,IR_cntr_en,IR_rght_en;  
  
  localparam FAST_SIM = 1'b1;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.INRT_SS_n(INRT_SS_n),.INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI),.INRT_MISO(INRT_MISO),.INRT_INT(INRT_INT),
				  .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
				  .A2D_MISO(A2D_MISO),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
				  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.RX(RX_TX),.TX(TX_RX),
				  .hall_n(hall_n),.piezo(),.piezo_n(),.IR_lft_en(IR_lft_en),
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED());
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .send_cmd(send_cmd),
               .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
			   
				  
  RunnerPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(INRT_SS_n),.SCLK(INRT_SCLK),.MISO(INRT_MISO),
                      .MOSI(INRT_MOSI),.INT(INRT_INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),
                     .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),.IR_rght_en(IR_rght_en),
					 .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					 .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));
	
					 
  initial begin
	batt = 12'hDA0;  	// this is value to use with RunnerPhysics
	clk = 0;
    	RST_n = 0;
	repeat(1000) @(posedge clk);
	RST_n = 1;
	repeat(1000) @(posedge clk);
	
	cmd = 16'h0000; // calibrate command
	send_cmd = 1;
	@(posedge clk);
	send_cmd = 0;
	@(posedge resp_rdy);
	#1;
	if(resp !== 8'hA5) begin
		$display("Incorrect response");
		$stop();
	end
	@(posedge clk);
	
//	cmd = 16'h23FF; // turn west command
//	send_cmd = 1;
//	@(posedge clk);
//	send_cmd = 0;
//	@(posedge resp_rdy);
//	#1;
//	if(resp !== 8'hA5) begin
//		$display("Incorrect response");
//		$stop();
//	end
//	if(!(iPHYS.heading_robot[19:8] > (12'h3ff - 8'h30)) && !(iPHYS.heading_robot[19:8] < (12'h3ff + 8'h30)) ) begin
//		$display("INCORRECT MOVE");
//		$stop();
//	end
//	@(posedge clk);
	
	cmd = 16'h6000; // solve command with right affinity
	send_cmd = 1;
	@(posedge clk);
	send_cmd = 0;
	@(negedge hall_n)
	
	 if(iPHYS.xx[14:12] !== 3'b011) begin
		 $display("Incorrect response");
		 $stop();
	 end
	 if(iPHYS.xx[14:12] !== 3'b011) begin
		 $display("Incorrect response");
		 $stop();
	 end

	#5000;	
	$display("PASS");
	$stop();
  end
  
  always
    #5 clk = ~clk;
	
endmodule