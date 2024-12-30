module Top (
	input i_rst_n,
	input i_clk,
	input i_CLK50,
	input i_key_0,
	input i_key_1,
	input i_key_2,
	input [3:0] i_speed, // design how user can decide mode on your own
	input i_fast,
	input i_slow_0,
	input i_slow_1,
	


	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	output [3:0] o_record_time,
	//output [3:0] o_record_time_I2C
	// output [5:0] o_play_time,

	// LCD (optional display)
	 input        i_clk_800k,
	 inout  [7:0] o_LCD_DATA,
	 output       o_LCD_EN,
	 output       o_LCD_RS,
	 output       o_LCD_RW,
	 output       o_LCD_ON,
	 output       o_LCD_BLON,
	 output			o_LCD_busy,
	 output	[4:0]		o_LCD_state

	// LED
	// output  [8:0] o_ledg,
	// output [17:0] o_ledr
);

// design the FSM and states as you like
parameter S_INIT       = 0;
parameter S_I2C        = 1;
parameter S_IDLE	   = 2;
parameter S_RECDING    = 3;
parameter S_RECD_PAUSE = 4;
parameter S_PLAYING    = 5;
parameter S_PLAY_PAUSE = 6;




logic [3:0] state, next_state;

logic i2c_oen, i2c_sdat;
logic [19:0] addr_record, addr_play;
logic [15:0] data_record, data_play, dac_data;

logic i2c_start, i2c_finished;

logic [19:0] addr_recorded_counter, addr_recorded_counter_next;
parameter NUMS_OF_WORDS = 1024000; // 1024000 words = 2048000 bytes = 2MB

logic player_en;
logic recorder_start, recorder_pause, recorder_stop;
logic recorder_start_next, recorder_pause_next, recorder_stop_next;
logic dsp_start, dsp_pause, dsp_stop;
logic dsp_start_next, dsp_pause_next, dsp_stop_next;

//debug//
logic notack;
assign notack = (!i2c_oen) && o_I2C_SCLK && (!io_I2C_SDAT);

//debug//

logic is_record_existed, is_record_existed_next;

assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

assign o_SRAM_ADDR = (state == S_RECDING) ? addr_record : addr_play[19:0];
assign io_SRAM_DQ  = (state == S_RECDING) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state != S_RECDING) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign o_SRAM_WE_N = (state == S_RECDING) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

// below is a simple example for module division
// you can design these as you like

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(i2c_start),
	.o_finished(i2c_finished),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
	//.o_test(o_record_time_I2C)
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(i_rst_n),
	.i_clk(i_AUD_BCLK),
	.i_start(dsp_start),
	.i_pause(dsp_pause),
	.i_stop(dsp_stop),
	.i_speed(i_speed),
	.i_fast(i_fast),
	.i_slow_0(i_slow_0), // constant interpolation
	.i_slow_1(i_slow_1), // linear interpolation
	.i_daclrck(i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.o_en_player(player_en),
	.o_dac_data(dac_data), 
	.o_sram_addr(addr_play)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(i_rst_n),
	.i_bclk(i_AUD_BCLK),
	.i_daclrck(i_AUD_DACLRCK),
	.i_en(player_en), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n(i_rst_n), 
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(recorder_start),
	.i_pause(recorder_pause),
	.i_stop(recorder_stop),
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_data(data_record)
);


LCD_MODULE LCD0(
	.i_clk_800k(i_clk_800k),
    .i_rst_n(i_rst_n),
	.i_state(state),
    .io_LCD_DATA(o_LCD_DATA),
    .o_LCD_EN(o_LCD_EN),
    .o_LCD_RS(o_LCD_RS),
    .o_LCD_RW(o_LCD_RW),
	 .o_state(o_LCD_state),
	 .o_busy(o_LCD_busy),
	 .o_LCD_ON(o_LCD_ON),
	 .o_LCD_BLON(o_LCD_BLON)
);


 assign o_record_time = state;

always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state <= S_INIT;
		recorder_start <= 0;
		recorder_pause <= 0;
		recorder_stop <= 0;
		dsp_start <= 0;
		dsp_pause <= 0;
		dsp_stop <= 0;
		
	end
	else begin
		state <= next_state;
		recorder_start <= recorder_start_next;
		recorder_pause <= recorder_pause_next;
		recorder_stop <= recorder_stop_next;
		dsp_start <= dsp_start_next;
		dsp_pause <= dsp_pause_next;
		dsp_stop <= dsp_stop_next;
	end
end

always_comb begin
	next_state = state;
	case (state)
		S_INIT: 
			if(i_key_0) begin
				next_state = S_I2C;
			end
		S_I2C:
			if(i2c_finished) begin
				next_state = S_IDLE;
			end
		S_IDLE:
			if(i_key_0) begin
				next_state = S_RECDING;
			end
			else if(i_key_1) begin
				next_state = S_PLAYING;
			end
		S_RECDING:
			if(i_key_1) begin
				next_state = S_RECD_PAUSE;
			end
			else if(i_key_2) begin
				next_state = S_IDLE;
			end
		S_RECD_PAUSE:
			if(i_key_0) begin
				next_state = S_RECDING;
			end
			else if(i_key_2) begin
				next_state = S_IDLE;
			end
		S_PLAYING:
			if(i_key_0) begin
				next_state = S_PLAY_PAUSE;
			end
			else if(i_key_2) begin
				next_state = S_IDLE;
			end
		S_PLAY_PAUSE:
			if(i_key_1) begin
				next_state = S_PLAYING;
			end
			else if(i_key_2) begin
				next_state = S_IDLE;
			end
		
	endcase
end

// interaction with I2CIitializer
assign i2c_start = (state == S_I2C) ? 1'b1 : 1'b0;


// interaction with MODE and option selection
always_comb begin
	recorder_start_next = 0;
	recorder_pause_next = 0;
	recorder_stop_next = 0;
	dsp_start_next = 0;
	dsp_pause_next = 0;
	dsp_stop_next = 0;
	case(state)
		S_IDLE: // 0 for record, 1 for play, 2 for option
			if(i_key_0) begin
				recorder_start_next = 1;
			end
			else if(i_key_1) begin
				dsp_start_next = 1;
			end
		S_RECDING:
			if(i_key_1) begin
				recorder_pause_next = 1;
			end
			else if(i_key_2) begin
				recorder_stop_next = 1;
			end
		S_RECD_PAUSE:
			if(i_key_0) begin
				recorder_pause_next = 1;
			end
			else if(i_key_2) begin
				recorder_stop_next = 1;
			end
		S_PLAYING:
			if(i_key_0) begin
				dsp_pause_next = 1;
			end
			else if(i_key_2) begin
				dsp_stop_next = 1;
			end
		S_PLAY_PAUSE:
			if(i_key_1) begin
				dsp_start_next = 1;
			end
			else if(i_key_2) begin
				dsp_stop_next = 1;
			end
			
	endcase
end

endmodule
