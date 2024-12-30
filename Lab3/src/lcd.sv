module LCD_MODULE (
    input  i_clk_800k,
    input  i_rst_n,
    input [3:0] i_state,
    inout [7:0] io_LCD_DATA,
    output o_LCD_EN,
    output o_LCD_RS,
    output o_LCD_RW,
	output o_LCD_ON,
	output o_LCD_BLON,
	output o_busy,
	output [4:0] o_state
);


	parameter READ = 1, WRITE = 0;
	parameter DATA = 1, COMMAND = 0;

	//lcd part
	logic [4:0] state, next_state;
	logic [7:0] lcd_data;
	logic lcd_rs, lcd_rw, lcd_en;
    logic [3:0] word_counter_r, word_counter_w;
	logic [3:0] prev_top_state;
    logic word_finish_r, word_finish_w;
	assign io_LCD_DATA = lcd_rw == READ && lcd_rs == COMMAND ? {1'bz, lcd_data[7:0]} : lcd_data;
	assign o_LCD_EN = lcd_en;
	assign o_LCD_RS = lcd_rs;
	assign o_LCD_RW = lcd_rw;
	assign o_LCD_ON = 1;
	assign o_LCD_BLON = 0;
	logic busy;
	assign busy = io_LCD_DATA[7];

	assign o_busy = io_LCD_DATA[7] && lcd_rw == READ && lcd_rs == COMMAND;
	assign o_state = state;

	parameter FREQ = 800000;
	parameter first_func_set_wait_time = 20000;
	parameter second_func_set_wait_time = 3300;
	parameter third_func_set_wait_time = 100;
	parameter func_set_time = 100;
	parameter read_time = 5000;
	parameter clear_display_time = 1500;

	logic [19:0] wait_counter, wait_counter_next;

	parameter S_1ST_FUNC_SET_WAIT = 0;
	parameter S_1ST_FUNC_SET = 1;
	parameter S_2ND_FUNC_SET_WAIT = 2;
	parameter S_2ND_FUNC_SET = 3;
	parameter S_3RD_FUNC_SET_WAIT = 4;
	parameter S_3RD_FUNC_SET = 5;
	parameter S_4TH_FUNC_SET_WAIT = 6;
	parameter S_4TH_FUNC_SET = 7;
	parameter S_DISPLAY_ON_WAIT = 8;
	parameter S_DISPLAY_ON = 9;
	parameter S_CLEAR_DISPLAY_WAIT = 10;
	parameter S_CLEAR_DISPLAY = 11;
	parameter S_SET_ENTRY_MODE_WAIT = 12;
	parameter S_SET_ENTRY_MODE = 13;
	parameter S_WAIT_DATA = 19;
	parameter S_SET_DDRAM_ADDRESS_WAIT = 14;
	parameter S_SET_DDRAM_ADDRESS = 15;
	parameter S_SET_DATA_WAIT = 16;
	parameter S_SET_DATA = 17;
	parameter S_END = 18;


	// ASCII
	parameter [7:0] I = 8'h49;
	parameter [7:0] D = 8'h44;
	parameter [7:0] L = 8'h4C;
	parameter [7:0] E = 8'h45;
	parameter [7:0] R = 8'h52;
	parameter [7:0] C = 8'h43;
	parameter [7:0] P = 8'h50;
	parameter [7:0] A = 8'h41;
	parameter [7:0] Y = 8'h59;
	parameter [7:0] U = 8'h55;
	parameter [7:0] S = 8'h53;

    // TOP state
    parameter S_TOP_INIT       = 0;
    parameter S_TOP_I2C        = 1;
    parameter S_TOP_IDLE	   = 2;
    parameter S_TOP_RECDING    = 3;
    parameter S_TOP_RECD_PAUSE = 4;
    parameter S_TOP_PLAYING    = 5;
    parameter S_TOP_PLAY_PAUSE = 6;

	always_comb begin
	next_state = state;
		case (state)
			S_1ST_FUNC_SET_WAIT:
				next_state = wait_counter == first_func_set_wait_time ? S_1ST_FUNC_SET : S_1ST_FUNC_SET_WAIT;
			S_1ST_FUNC_SET:
				next_state = wait_counter == func_set_time ? S_2ND_FUNC_SET_WAIT : S_1ST_FUNC_SET;
			S_2ND_FUNC_SET_WAIT:
				next_state = wait_counter == second_func_set_wait_time ? S_2ND_FUNC_SET : S_2ND_FUNC_SET_WAIT;
			S_2ND_FUNC_SET:
				next_state = wait_counter == func_set_time ? S_3RD_FUNC_SET_WAIT : S_2ND_FUNC_SET;
			S_3RD_FUNC_SET_WAIT:
				next_state = wait_counter == third_func_set_wait_time ? S_3RD_FUNC_SET : S_3RD_FUNC_SET_WAIT;
			S_3RD_FUNC_SET:
				next_state = wait_counter == func_set_time ? S_4TH_FUNC_SET_WAIT : S_3RD_FUNC_SET;
			S_4TH_FUNC_SET_WAIT:
				next_state = wait_counter == read_time && !busy ? S_4TH_FUNC_SET : S_4TH_FUNC_SET_WAIT;
			S_4TH_FUNC_SET:
				next_state = wait_counter == func_set_time ? S_DISPLAY_ON_WAIT : S_4TH_FUNC_SET;
			S_DISPLAY_ON_WAIT:
				next_state = wait_counter == read_time && !busy ? S_DISPLAY_ON : S_DISPLAY_ON_WAIT;
			S_DISPLAY_ON:
				next_state = wait_counter == func_set_time ? S_CLEAR_DISPLAY_WAIT : S_DISPLAY_ON;
			S_CLEAR_DISPLAY_WAIT:
				next_state = wait_counter == read_time && (!busy) ? S_CLEAR_DISPLAY : S_CLEAR_DISPLAY_WAIT;
			S_CLEAR_DISPLAY:
				next_state = wait_counter == clear_display_time ? S_SET_ENTRY_MODE_WAIT : S_CLEAR_DISPLAY;
			S_SET_ENTRY_MODE_WAIT:
				next_state = wait_counter == read_time && (!busy) ? S_SET_ENTRY_MODE : S_SET_ENTRY_MODE_WAIT;
			S_SET_ENTRY_MODE:	
				next_state = wait_counter == func_set_time ? S_WAIT_DATA : S_SET_ENTRY_MODE;
			S_WAIT_DATA:
				next_state = S_SET_DDRAM_ADDRESS_WAIT;
			S_SET_DDRAM_ADDRESS_WAIT:	
				next_state = wait_counter == read_time && (!busy) ? S_SET_DDRAM_ADDRESS : S_SET_DDRAM_ADDRESS_WAIT;
			S_SET_DDRAM_ADDRESS:	
				next_state = wait_counter == func_set_time ? S_SET_DATA_WAIT : S_SET_DDRAM_ADDRESS;
			S_SET_DATA_WAIT:
				next_state = wait_counter == read_time && (!busy) ? S_SET_DATA : S_SET_DATA_WAIT;
			S_SET_DATA:
				next_state = (wait_counter == func_set_time && word_finish_r ) ? S_END : S_SET_DATA;
			S_END:
				next_state = (prev_top_state != i_state) ? S_WAIT_DATA : S_END;
		endcase
	end

	always_comb begin
		lcd_data = 8'bzzzzzzzz;
		lcd_rw = 1'b0;
		lcd_rs = 1'b0;
		lcd_en = 1'b1;
		wait_counter_next = wait_counter;
        word_counter_w = word_counter_r;
        word_finish_w = 0;
		case (state)
			S_1ST_FUNC_SET_WAIT:begin
				lcd_data = 8'b00110000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				wait_counter_next = wait_counter == first_func_set_wait_time ? 0 : wait_counter + 1;
				lcd_en = 1;
			end
			S_1ST_FUNC_SET:begin
				lcd_data = 8'b00110000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
				if(wait_counter == 0) lcd_en = 0;
			end
			S_2ND_FUNC_SET_WAIT:begin
				lcd_data = 8'b00110000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				wait_counter_next = wait_counter == second_func_set_wait_time ? 0 : wait_counter + 1;
				lcd_en = 1;
			end
			S_2ND_FUNC_SET:begin
				lcd_data = 8'b00110000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
				if(wait_counter == 0) lcd_en = 0;
			end
			S_3RD_FUNC_SET_WAIT:begin
				lcd_data = 8'b00110000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				wait_counter_next = wait_counter == third_func_set_wait_time ? 0 : wait_counter + 1;
				lcd_en = 1;
			end
			S_3RD_FUNC_SET:begin
				lcd_data = 8'b00110000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
				if(wait_counter == 0) lcd_en = 0;
			end
			S_4TH_FUNC_SET_WAIT:begin
                lcd_data = 8'bzzzzzzzz;
				lcd_rw = READ;
				lcd_rs = COMMAND;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == read_time ? 0 : wait_counter + 1;
			end
			S_4TH_FUNC_SET: begin
				lcd_data = 8'b00111000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
			end
			S_DISPLAY_ON_WAIT, S_CLEAR_DISPLAY_WAIT, S_SET_ENTRY_MODE_WAIT, S_SET_DDRAM_ADDRESS_WAIT:begin
				lcd_rw = READ;
				lcd_rs = COMMAND;
				lcd_en = wait_counter == 5 ? 0 : 1;
                lcd_data = 8'bzzzzzzzz;
				wait_counter_next = wait_counter == read_time ? 0 : wait_counter + 1;
			end
			S_DISPLAY_ON: begin
				lcd_data = 8'b00001100;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
			end
			S_CLEAR_DISPLAY: begin
				lcd_data = 8'b00000001;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == clear_display_time ? 0 : wait_counter + 1;
			end
			S_SET_ENTRY_MODE: begin
				lcd_data = 8'b00000110;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
			end
			S_SET_DDRAM_ADDRESS: begin
				lcd_data = 8'b11000000;
				lcd_rw = WRITE;
				lcd_rs = COMMAND;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
			end
			S_SET_DATA_WAIT:begin
				lcd_rs = COMMAND;
				lcd_rw = READ;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == read_time ? 0 : wait_counter + 1;
                lcd_data = 8'bz1000000;
			end
			S_SET_DATA: begin
                lcd_data = 8'b00110000; // 0
                case (i_state)
                    S_TOP_INIT, S_TOP_I2C, S_TOP_IDLE: begin
                        if      (word_counter_r == 0) lcd_data = I;
                        else if (word_counter_r == 1) lcd_data = D;
                        else if (word_counter_r == 2) lcd_data = L;
                        else if (word_counter_r == 3) lcd_data = E;
                    end 
                    S_TOP_RECDING : begin
                        if      (word_counter_r == 0) lcd_data = R;
                        else if (word_counter_r == 1) lcd_data = E;
                        else if (word_counter_r == 2) lcd_data = C;
                        else if (word_counter_r == 3) lcd_data = D;
					end
                    S_TOP_PLAYING : begin
                        if      (word_counter_r == 0) lcd_data = P;
                        else if (word_counter_r == 1) lcd_data = L;
                        else if (word_counter_r == 2) lcd_data = A;
                        else if (word_counter_r == 3) lcd_data = Y;
                    end
                    S_TOP_RECD_PAUSE, S_TOP_PLAY_PAUSE: begin
                        if      (word_counter_r == 0) lcd_data = P;
                        else if (word_counter_r == 1) lcd_data = A;
                        else if (word_counter_r == 2) lcd_data = U;
                        else if (word_counter_r == 3) lcd_data = S;
                    end
                endcase
				lcd_rw = WRITE;
				lcd_rs = DATA;
				lcd_en = wait_counter == 5 ? 0 : 1;
				wait_counter_next = wait_counter == func_set_time ? 0 : wait_counter + 1;
				word_counter_w = (wait_counter == func_set_time) ? (word_counter_r == 4'd3 ? 4'd0 : word_counter_r + 1) : word_counter_r;
                // word_counter_w = (word_counter_r == 4'd4 && wait_counter == func_set_time) ? 4'd0 : word_counter_w + 1;
                if(word_counter_r == 4'd3 && wait_counter == func_set_time - 1) word_finish_w = 1;
			end
		endcase
	end

	always_ff @(posedge i_clk_800k or negedge i_rst_n) begin
		if (!i_rst_n) begin
			state <= S_1ST_FUNC_SET_WAIT;
			wait_counter <= 0;
            word_counter_r <= 4'd0;
            word_finish_r <= 0;
			prev_top_state <= 0;
		end
		else begin
			state <= next_state;
			wait_counter <= wait_counter_next;
            word_counter_r <= word_counter_w;
            word_finish_r <= word_finish_w;
			prev_top_state <= i_state;
		 end
	end

endmodule