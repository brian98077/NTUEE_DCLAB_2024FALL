module AudDSP(
	input         i_rst_n,
	input         i_clk,
	input         i_start,
	input         i_pause,
	input         i_stop,
	input [4:0]   i_speed,
	input         i_fast,
	input         i_slow_0, // constant interpolation
	input         i_slow_1, // linear interpolation
    input         i_reverse,
	input         i_daclrck,
	input [15:0]  i_sram_data,
	output        o_en_player,
	output [15:0] o_dac_data,
	output [19:0] o_sram_addr
);

	// state
	parameter S_IDLE  = 0;
	parameter S_PLAY  = 1;
	parameter S_PAUSE = 2;

	// declaration
	logic [2:0] state, state_next;
	logic signed [15:0] o_dac_data_r, o_dac_data_w, previous_data_r, previous_data_w;
	logic [19:0] o_sram_addr_r, o_sram_addr_w;
	logic previous_daclrck, en_player_r, en_player_w;
	logic [3:0] slow_counter_r, slow_counter_w;

	// outputs
	assign o_dac_data = (!i_daclrck) ? o_dac_data_w : 16'dZ;
	assign o_sram_addr = o_sram_addr_r;
	assign o_en_player = !i_daclrck && state==S_PLAY;
	// FSM 
	always_comb begin
		state_next = state;
		case (state)
			S_IDLE: begin
				if(i_start) state_next = S_PLAY;
				else 		state_next = S_IDLE;
			end 

			S_PLAY: begin
				if(i_stop) 		 state_next = S_IDLE;
				else if(i_pause) state_next = S_PAUSE;
				else 			 state_next = S_PLAY;
			end

			S_PAUSE: begin
				if(i_stop)  	 state_next = S_IDLE;
				else if(i_start) state_next = S_PLAY;
				else 			 state_next = S_PAUSE;
			end
		endcase
	end
	
	// combinational
	always_comb begin
		o_dac_data_w = 16'dZ;
		o_sram_addr_w = o_sram_addr_r;
		previous_data_w = previous_data_r;
		slow_counter_w = slow_counter_r;
		case (state)
			S_IDLE: begin
				if(i_start) begin
					o_sram_addr_w = o_sram_addr_r;
					o_dac_data_w = i_sram_data;
					previous_data_w = 16'd0;
					slow_counter_w = 4'd0;
				end
				else begin
					o_sram_addr_w = 20'd0;
					previous_data_w = 16'd0;
					slow_counter_w = 4'd0;
				end
			end

			S_PLAY: begin
				if(i_stop) begin
					o_sram_addr_w = 20'd0;
					o_dac_data_w = 16'dZ;
					previous_data_w = 16'd0;
					slow_counter_w = 4'd0;
				end
				else if(i_pause) begin
					o_sram_addr_w = o_sram_addr_r;
					o_dac_data_w = 16'dZ;
					previous_data_w = previous_data_r;
					slow_counter_w = slow_counter_r;
				end
				else begin
					if(i_fast) begin
						o_sram_addr_w = (previous_daclrck && !i_daclrck) ? o_sram_addr_r + i_speed : o_sram_addr_r;
						o_dac_data_w = i_sram_data;
					end
					else if(i_slow_0) begin // constant interpolation
						o_sram_addr_w = ((slow_counter_r == i_speed - 1) && (previous_daclrck && !i_daclrck)) ? o_sram_addr_r + 1 : o_sram_addr_r;
						o_dac_data_w = previous_data_r;
						previous_data_w = ((slow_counter_r == i_speed - 1) && (!previous_daclrck && i_daclrck)) ? i_sram_data : previous_data_r;
						slow_counter_w = ((slow_counter_r == i_speed - 1) && (previous_daclrck && !i_daclrck)) ? 4'd0 :
										 (previous_daclrck && !i_daclrck) ? slow_counter_r + 1 : slow_counter_r;
					end
					else if(i_slow_1) begin // linear interpolation
						o_sram_addr_w = ((slow_counter_r == i_speed - 1) && (previous_daclrck && !i_daclrck)) ? o_sram_addr_r + 1 : o_sram_addr_r;
						o_dac_data_w = (($signed(previous_data_r) * ($signed(i_speed) - $signed(slow_counter_r) )) + ($signed(i_sram_data) * ($signed(slow_counter_r) )))/
									   ($signed(i_speed));
						previous_data_w = ((slow_counter_r == i_speed - 1) && (!previous_daclrck && i_daclrck)) ? i_sram_data : previous_data_r;
						slow_counter_w = ((slow_counter_r == i_speed - 1) && (previous_daclrck && !i_daclrck)) ? 4'd0 :
										 (previous_daclrck && !i_daclrck) ? slow_counter_r + 1 : slow_counter_r;
					end
					else begin
						o_sram_addr_w = (previous_daclrck && !i_daclrck) ? o_sram_addr_r + 1 : o_sram_addr_r;
						o_dac_data_w = i_sram_data;
					end
				end
			end

			S_PAUSE: begin
				if(i_stop) begin
					o_sram_addr_w = 20'd0;
					o_dac_data_w = 16'dZ;
					previous_data_w = 16'd0;
					slow_counter_w = 4'd0;
				end
				else begin
					o_sram_addr_w = o_sram_addr_r;
					o_dac_data_w = 16'dZ;
					previous_data_w = previous_data_r;
					slow_counter_w = slow_counter_r;
				end
			end
		endcase
	end


	// sequential
	always_ff @(negedge i_rst_n or posedge i_clk) begin
		if(!i_rst_n) begin
			state 		 	 <= S_IDLE;
			en_player_r 	 <= 0;
			o_dac_data_r 	 <= 16'dZ;
			o_sram_addr_r	 <= 20'd0;
			previous_daclrck <= 0;
			previous_data_r  <= 16'd0;
			slow_counter_r   <= 4'd0;
		end
		else begin
			state			 <= state_next;
			en_player_r 	 <= previous_daclrck && !i_daclrck;
			o_dac_data_r 	 <= o_dac_data_w;
			o_sram_addr_r 	 <= o_sram_addr_w;
			previous_daclrck <= i_daclrck;
			previous_data_r  <= previous_data_w;
			slow_counter_r   <= slow_counter_w;
		end
	end

endmodule