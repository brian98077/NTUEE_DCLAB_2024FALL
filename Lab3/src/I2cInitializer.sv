module I2cInitializer (
    input i_rst_n,
    input i_clk,
    input i_start,
    output o_finished,
    output o_sclk,
    output o_sdat,
    output o_oen,
    //inout io_I2C_SDAT,
    // input i_key,
    output [3:0] cur_command,
    output [3:0] o_ack
);

parameter WM8731_ADDR = 7'b0011010;
parameter num_init_commands = 11;
// parameter logic [26:0] WM8731_INIT[7] = '{
//     27'b00110100_00001111_00000000_1,  // Reset:                  0011_0100_000_1111_0_0000_0000
//     27'b00110100_00000100_00010101_1,  // Analogue Audio Path:    0011_0100_000_0100_0_0001_0101
//     27'b00110100_00000101_00000000_1,  // Digital Audio Path:     0011_0100_000_0101_0_0000_0000
//     27'b00110100_00000110_00000000_1,  // Power Down Control:     0011_0100_000_0110_0_0000_0000
//     27'b00110100_00000111_01000010_1,  // Digital Audio Interface:0011_0100_000_0111_0_0100_0010
//     27'b00110100_00001000_00011001_1,  // Sampling Control:       0011_0100_000_1000_0_0001_1001
//     27'b00110100_00001001_00000001_1   // Active Control:         0011_0100_000_1001_0_0000_0001
// };

logic io_I2C_SDAT;


parameter nums_of_INIT = 10;
parameter logic [24:0] WM8731_INIT[nums_of_INIT] = '{
    // 25'b00110100_00011110_00000000_0, // Reset:                  
    25'b00110100_00000000_10010111_0, // Left Line In
    25'b00110100_00000010_10010111_0, // Right Line In
    25'b00110100_00000100_01111001_0, // Left Headphone Out
    25'b00110100_00000110_01111001_0, // Right Headphone Out
    25'b00110100_00001000_00010101_0, // Analogue Audio Path Control
    25'b00110100_00001010_00000000_0, // Digital Audio Path Control
    25'b00110100_00001100_00000000_0, // Power Down Control
    25'b00110100_00001110_01000010_0, // Digital Audio Interface Format
    25'b00110100_00010000_00011001_0, // Sampling Control
    25'b00110100_00010010_00000001_0  // Active Control
};




//state
parameter S_NINITED = 0;
parameter S_SENDING_POS = 2;
parameter S_SENDING_NEG = 1;
parameter S_ACK_NEG = 4;
parameter S_ACK_POS = 3;
parameter S_FINISHING = 5;
parameter S_INITED = 6;
parameter S_SEND_START = 7;
parameter S_SEND_FAILED = 8;

wire i_key;
assign i_key = 1;
reg [3:0] state, next_state;
reg [3:0] cur_init_command, next_init_command;
reg [4:0] cur_command_bit, next_command_bit;
reg [3:0] finishing_cycle_counter, next_finishing_cycle_counter;

reg oen, next_oen;
reg sdat, next_sdat;
reg sclk, next_sclk;
reg start_bit, next_start_bit;

assign o_oen = oen;
assign o_finished = (state == S_INITED);
assign o_sclk = sclk;
assign o_sdat = sdat;
assign cur_command = cur_init_command;
logic is_functioning;
assign o_is_functioning = is_functioning;
logic [2:0] ack, ack_next;
assign o_ack = ack;

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        state <= S_NINITED;
        cur_init_command <= 0;
        cur_command_bit <= 0;
        finishing_cycle_counter <= 0;
        start_bit <= 1'b1;
        ack <= 3'b000;
    end else begin
        state <= next_state;
        cur_init_command <= next_init_command;
        cur_command_bit <= next_command_bit;
        finishing_cycle_counter <= next_finishing_cycle_counter;
        start_bit <= next_start_bit;
        ack <= ack_next;
    end
end

always_comb begin
	sdat = 0;
	oen = 0;
	sclk = 0;
    is_functioning = 1;
    next_state = state;
    next_init_command = cur_init_command;
    next_command_bit = cur_command_bit;
    next_finishing_cycle_counter = finishing_cycle_counter;
    ack_next = ack;
        case (state)
            S_NINITED: begin
                sdat = 1;
                sclk = 1;
                oen = 1;
                is_functioning = 0;
                if (i_start) begin
                    next_state = S_SEND_START;
                    next_finishing_cycle_counter = 0;
                end 
            end
            S_SEND_START: begin
                sdat = 0;
                sclk = 1;
                oen = 1;
                next_state = finishing_cycle_counter == 3 ? S_SENDING_NEG : S_SEND_START;
                next_finishing_cycle_counter = finishing_cycle_counter == 3 ? 0 : finishing_cycle_counter + 1;
                next_command_bit = 24;
                ack_next = 3'b000;
            end
            S_SENDING_NEG: begin
                sclk = 0;
					oen = 1;
					sdat = 1;
                next_state = S_SENDING_POS;
            end
            S_SENDING_POS: begin
                sclk = 1;
                sdat = WM8731_INIT[cur_init_command][cur_command_bit];
					oen = 1;
                next_command_bit = cur_command_bit - 1;
                next_state = (cur_command_bit == 1) || (cur_command_bit == 9) || (cur_command_bit == 17) ? S_ACK_NEG : S_SENDING_NEG;
                next_finishing_cycle_counter = (cur_command_bit == 1) || (cur_command_bit == 9) || (cur_command_bit == 17) ? 0 : finishing_cycle_counter;
            end
            S_ACK_NEG: begin
                sclk = 0;
                oen = 0;
					 sdat = 0;
                next_state = S_ACK_POS;
            end
            S_ACK_POS: begin
                sclk = 1;
                oen = 0;
			    sdat = 0;
                next_finishing_cycle_counter = io_I2C_SDAT == 0 ? 0 : finishing_cycle_counter == nums_of_INIT - 1 ? 0 : finishing_cycle_counter + 1;
                if(io_I2C_SDAT == 0) begin
                    if(cur_command_bit == 0) begin
                        next_state = S_FINISHING;
                    end
                    else begin
                        next_state = S_SENDING_NEG;
                    end
                end
                else begin
                    next_state = finishing_cycle_counter == nums_of_INIT - 1 ? S_SEND_FAILED : S_ACK_POS;
                end
                ack_next[2] = io_I2C_SDAT == 0 && cur_command_bit == 16 ? 1 : ack[2];
                ack_next[1] = io_I2C_SDAT == 0 && cur_command_bit == 8 ? 1 : ack[1];
                ack_next[0] = io_I2C_SDAT == 0 && cur_command_bit == 0 ? 1 : ack[0];
                
            end
            S_FINISHING: begin
                is_functioning = 0;
                sclk = 0;
                oen = 0;
                sdat = 0;
                next_state = (i_key) ? (cur_init_command == num_init_commands - 1) ? S_INITED : S_SEND_START : S_FINISHING;
                if(i_key) begin
                    next_command_bit = 24;
                    next_init_command = cur_init_command + 1;
                end
			end
            S_SEND_FAILED: begin
                is_functioning = 0;
                sclk = 0;
                oen = 0;
                sdat = 0;
                if(i_key) begin
                    ack_next = 3'b000;
                    next_state = S_SEND_START;
                end
            end
        endcase
end
 
endmodule