module piezo_drv(
  input clk,
  input rst_n,
  input batt_low,
  input fanfare,
  output piezo,
  output piezo_n
);

// Resources
// note   hz    clock cycles (from 50mhz clk rate)  binary count          divide by 2 for 50% duty
// G6 -> 1568 = 31888                               0111_1100_1001_0000
// C7 -> 2093 = 23889                               0101_1101_0101_0001
// E7 -> 2637 = 18961                               0100_1010_0001_0001
// G7 -> 3136 = 15944                               0011_1110_0100_1000
//                                                  0011_1110_0100_1000
// fanfare = G6 C7 E7 G7 E7 G7
// battery low = G6 C7 E7 (simultaneous)
parameter FAST_SIM = 1;

localparam G6 = 14'd15944; // 14'b11_1110_0100_1000;
localparam C7 = 14'd11944; //14'b10_1110_1010_1000;
localparam E7 = 14'd9480; //14'b10_0101_0000_1000;
localparam G7 = 14'd7971; //14'b01_1111_0010_0100;
//                    01111100100100


// frequency counter
logic [13:0] freq,freq_cnt;
logic start_timer,wavereg,load_timer;

// drive freq with state machine
always_ff @(posedge clk, negedge rst_n) begin

  if(!rst_n) begin
     freq_cnt <= 14'h000;
     wavereg <= 1'b0;
  end
  else if(load_timer)
     freq_cnt <= freq;
  else if(start_timer) begin
    if(freq_cnt == 14'h0000) begin
      wavereg <= !wavereg;
      freq_cnt <= freq;
    end
    else
      freq_cnt <= freq_cnt - 1;
  end
     
end

// duration counter
logic [24:0] duration,duration_cnt;

always_ff @(posedge clk, negedge rst_n) begin

  if(!rst_n)
     duration_cnt <= 25'h00000;
  else if(load_timer)
     duration_cnt <= duration;
  else if(start_timer)
     duration_cnt <= duration_cnt - 1;
  else
     duration_cnt <= duration_cnt;
end

// state machine
typedef enum logic [2:0] {IDLE,SG6,SC7,SE7,SG7,FAN1,FAN2} state_t;
state_t state,nstate;

always_ff @(posedge clk, negedge rst_n) begin

  if(!rst_n)
    state <= IDLE;
  else
    state <= nstate;

end

logic state_buffer;

always_ff @(posedge clk) begin

  if(fanfare)
     state_buffer <= 1'b0;
  else if(batt_low)
     state_buffer <= 1'b1;

end

always_comb begin

  start_timer = 1'b0;
  load_timer = 1'b0;
  duration = 25'h0000000;
  freq = 14'h0000;
  nstate = state;
  
  case(state)

    IDLE: begin
/*      generate if(FAST_SIM) begin
        duration = 24'h004000;
      end else begin
        duration = 24'h400000;  // 2^23 clock periods
      end
      endgenerate
*/
      duration = 25'h0080000;  // 2^23 clock periods
      freq = 14'h0000;
      if(batt_low | fanfare) begin
        // freq = G6;
        load_timer = 1'b1;
        nstate = SG6;
      end
    end

    SG6: begin
      start_timer = 1'b1;
/*
      generate if(FAST_SIM) begin
        duration = 24'h004000;
      end else begin
        duration = 24'h400000;  // 2^23 clock periods
      end
      endgenerate
*/
      freq = G6;
      duration = 25'h0080000;  // 2^23 clock periods 0100_0000_0000_0000
      if(&(~duration_cnt)) begin
        load_timer = 1'b1;
        freq = C7;
        nstate = SC7;
      end
    end

    SC7: begin
      start_timer = 1'b1;
/*
      generate if(FAST_SIM) begin
        duration = 24'h004000;
      end else begin
        duration = 24'h400000;  // 2^23 clock periods
      end
      endgenerate
*/
      freq = C7;
      duration = 25'h0080000;  // 2^23 clock periods
      if(&(~duration_cnt)) begin
        load_timer = 1'b1;
        freq = E7;
        nstate = SE7;
      end
    end

    SE7: begin
      start_timer = 1'b1;
/*
      generate if(FAST_SIM) begin
        duration = 24'h006000;
      end else begin
        duration = 24'h600000; // 2^23 + 2^22 clock periods
      end
      endgenerate
*/
      freq = E7;
      duration = 25'h00C0000; // 2^23 + 2^22 clock periods
      if(batt_low&(&(~duration_cnt)))
        nstate = IDLE;
      else if(&(~duration_cnt)) begin
        load_timer = 1'b1;
        freq = G7;
        nstate = SG7;
      end
    end

    SG7: begin
      start_timer = 1'b1;
/*
      generate if(FAST_SIM) begin
        duration = 24'h002000;
      end else begin
        duration = 24'h200000; // 2^23 + 2^22 clock periods
      end
      endgenerate
*/
        freq = G7;
        duration = 25'h0040000; // 2^22 clock periods
        // 0_0000_0000_0000_0000_0000_0000
      if(&(~duration_cnt)) begin
        load_timer = 1'b1;
        freq = E7;
        nstate = FAN1;
      end
    end

    FAN1: begin
      start_timer = 1'b1;
/*
      generate if(FAST_SIM) begin
        duration = 24'h008000;
      end else begin
        duration = 24'h800000; // 2^23 + 2^22 clock periods
      end
*/
      duration = 25'h0100000; // 2^23 + 2^22 clock periods
      freq = E7;
      if(&(~duration_cnt)) begin
        load_timer = 1'b1;
        freq = G7;
        nstate = FAN2;
      end
    end

    FAN2: begin
      start_timer = 1'b1;
      freq = G7;
      if(&(~duration_cnt)) begin
        nstate = IDLE;
      end
    end

    default nstate = IDLE;

  endcase
 
end

// generate piezo signals
assign piezo = wavereg;
assign piezo_n = !piezo;

endmodule
