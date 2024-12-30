module AudRecorder (
    input i_rst_n,
    input i_clk,
    input i_lrc,
    input i_start,
    input i_pause,
    input i_stop,
    input i_data,
    output [19:0] o_address,
    output [15:0] o_data
);
    parameter CHANNEL = 0; // 0: left, 1: right
    parameter MAX_WORDS = 20'hfffff;

    parameter S_IDLE = 0;
    parameter S_REC  = 1;
    parameter S_STORE = 2;
    parameter S_WAIT = 3;
    parameter S_PAUSE = 4;
    parameter S_UPDATE = 5;
    parameter S_CLEAR = 6;

    logic [2:0] state_r, state_w;
    logic [19:0] addr_r, addr_w;
    logic [4:0] cnt_r, cnt_w;
    logic [15:0] data_r, data_w;
    logic [19:0] addr_clear_r, addr_clear_w;
    logic [4:0] cnt_clear_r, cnt_clear_w;


    assign o_address = (state_r == S_CLEAR)? addr_clear_r : addr_r;
    assign o_data = (state_r == S_CLEAR) ? 16'd0 : data_r;
    // FSM
    always_comb begin
        state_w = state_r;
        case (state_r)
            S_IDLE:  state_w = (i_start) ? S_CLEAR : S_IDLE;
            S_CLEAR: state_w = (addr_clear_r == MAX_WORDS) ? S_WAIT : S_CLEAR;
            S_REC: begin
                if(cnt_r == 5'd15) begin
                    state_w = S_STORE;
                end
                else if(i_stop) begin
                    state_w = S_IDLE;
                end
                else if(i_pause) begin
                    state_w = S_PAUSE;
                end
                else begin
                    state_w = (i_lrc != CHANNEL) ? S_WAIT : S_REC;
                end
            end
            S_STORE: begin
                if(i_stop) begin
                    state_w = S_IDLE;
                end
                else if(i_pause) begin
                    state_w = S_PAUSE;
                end
                else begin
                    state_w = (i_lrc != CHANNEL) ? S_WAIT : S_STORE;
                end
            end
            S_UPDATE: state_w = (addr_r == MAX_WORDS) ? S_IDLE : S_REC;
            S_WAIT: begin
                if(i_stop) begin
                    state_w = S_IDLE;
                end
                else if(i_pause) begin
                    state_w = S_PAUSE;
                end
                else begin
                    state_w = (i_lrc == CHANNEL) ? S_UPDATE : S_WAIT;
                end
            end
            S_PAUSE: state_w = (i_pause) ? S_WAIT : S_PAUSE;
        endcase
    end

    // combinational logic
    always_comb begin
        addr_w = addr_r;
        addr_clear_w = addr_clear_r;
        data_w = data_r;
        cnt_w = cnt_r;
        case (state_r)
            S_IDLE: begin
                addr_w = 20'd0;
                cnt_w = 5'd0;
                data_w = 16'd0;
                addr_clear_w = 20'd0;
            end
            S_CLEAR: begin
                addr_clear_w = addr_clear_r + 20'd1;
            end
            S_REC: begin
                cnt_w = cnt_r + 5'd1;
                data_w[5'd15 - cnt_r] = i_data;
            end
            S_UPDATE: begin
                addr_w = (cnt_r == 16)? addr_r + 20'd1: addr_r;
                cnt_w = 5'd1;
                data_w = {i_data, 15'd0};
            end
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if(~i_rst_n) begin
            state_r <= S_IDLE;
            addr_r <= 20'd0;
            cnt_r <= 4'd0;
            data_r <= 16'd0;
            addr_clear_r <= 20'd0;
        end
        else begin
            state_r <= state_w;
            addr_clear_r <= addr_clear_w;
            addr_r <= addr_w;
            cnt_r <= cnt_w;
            data_r <= data_w;
        end
    end

endmodule