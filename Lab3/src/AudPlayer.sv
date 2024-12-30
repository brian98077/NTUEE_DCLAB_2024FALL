module AudPlayer (
    input i_rst_n,
    input i_bclk,
    input i_daclrck,
    input i_en,
    input [15:0] i_dac_data,
    output o_aud_dacdat
);
    parameter CHANNEL = 0; // 0: left channel, 1: right channel

    parameter S_IDLE = 0;
    parameter S_PLAY = 1;

    logic [1:0] state_r, state_w;
    logic [3:0] cnt_r, cnt_w;

    logic [15:0] dac_data_r, dac_data_w;

    assign o_aud_dacdat = (state_r == S_PLAY) ? dac_data_r[4'd15 - cnt_r]: 0;
    // FSM
    always_comb begin
        case (state_r)
            S_IDLE: state_w = (i_en) ? S_PLAY: S_IDLE;
            S_PLAY: begin
                state_w = (cnt_r == 4'd15)? S_IDLE : S_PLAY;
            end
            default: state_w = state_r;
        endcase
    end
    // Combinational logic
    always_comb begin
        cnt_w = cnt_r;
        dac_data_w = dac_data_r;
        case (state_r)
            S_IDLE: begin
                dac_data_w = (i_en) ? i_dac_data : 16'd0;
            end
            S_PLAY: begin
                cnt_w = (cnt_r == 4'd15)? 4'd0 : cnt_r + 4'd1;
            end
        endcase
    end

    always_ff @(posedge i_bclk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            state_r <= S_IDLE;
            cnt_r <= 4'd0;
            dac_data_r <= 16'd0;
        end 
        else begin
            state_r <= state_w;
            cnt_r <= cnt_w;
            dac_data_r <= dac_data_w;
        end
    end
endmodule