module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!
localparam S_CHECK_STATUS_PUBLIC = 0;
localparam S_GET_PUBLIC_KEY = 1;
localparam S_CHECK_STATUS_PRIVATE = 2;
localparam S_GET_PRIVATE_KEY = 3;
localparam S_CHECK_STATUS_DATA = 4;
localparam S_GET_DATA = 5;
localparam S_WAIT_CALCULATE = 6;
localparam S_CHECK_STATUS_SEND = 7;
localparam S_SEND_DATA = 8;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [3:0] state_r, state_w;
logic [6:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

logic [31:0] wait_counter_w, wait_counter_r;

assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8];

Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),
    .i_n(n_r),
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask
task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask


logic rrdy, trdy;
assign rrdy = avm_readdata[7];
assign trdy = avm_readdata[6];

assign avm_address = ((state_r == S_GET_PRIVATE_KEY) || (state_r == S_GET_PUBLIC_KEY) || (state_r == S_GET_DATA)) ? RX_BASE :
                    (state_r == S_SEND_DATA) ? TX_BASE : STATUS_BASE;

always_comb begin
    // state transition
    state_w = state_r;
    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    dec_w = dec_r;
    bytes_counter_w = bytes_counter_r;
    rsa_start_w = 0;
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    wait_counter_w = wait_counter_r;
    avm_address_w = avm_address_r;
    case (state_r)
        S_CHECK_STATUS_PUBLIC:begin
            if(!avm_waitrequest && rrdy) begin
                state_w = S_GET_PUBLIC_KEY;
            end
        end
        S_GET_PUBLIC_KEY:begin
            if(!avm_waitrequest) begin
                n_w[bytes_counter_r * 8 + 7 -: 8] = avm_readdata[7:0];
                state_w = (bytes_counter_r == 0) ? S_CHECK_STATUS_PRIVATE : S_CHECK_STATUS_PUBLIC;
                bytes_counter_w = (bytes_counter_r == 0) ? 31 : bytes_counter_r - 1;
            end
        end
        S_CHECK_STATUS_PRIVATE:begin
            if(!avm_waitrequest && rrdy) begin
                state_w = S_GET_PRIVATE_KEY;
            end
        end
        S_GET_PRIVATE_KEY:begin
            if(!avm_waitrequest) begin
                d_w[bytes_counter_r * 8 + 7 -: 8] = avm_readdata[7:0];
                state_w = (bytes_counter_r == 0) ? S_CHECK_STATUS_DATA : S_CHECK_STATUS_PRIVATE;
                bytes_counter_w = (bytes_counter_r == 0) ? 31 : bytes_counter_r - 1;
            end
        end
        S_CHECK_STATUS_DATA:begin
            if(!avm_waitrequest && rrdy) begin
                state_w = S_GET_DATA;
                wait_counter_w = 0;
            end
            else if (wait_counter_r == 10000000) begin
                wait_counter_w = 0;
                state_w = S_CHECK_STATUS_PUBLIC;
                avm_write_w = 0;
                avm_read_w = 1;
                n_w = 0;
                d_w = 0;
                enc_w =0;
                dec_w = 0;
                avm_address_w = 0;
                bytes_counter_w = 31;
            end
            else begin
                wait_counter_w = wait_counter_r + 1;
            end
        end
        S_GET_DATA:begin
            if(!avm_waitrequest) begin
                enc_w[bytes_counter_r * 8 + 7 -: 8] = avm_readdata[7:0];
                state_w = (bytes_counter_r == 0) ? S_WAIT_CALCULATE : S_CHECK_STATUS_DATA;
                bytes_counter_w = (bytes_counter_r == 0) ? 31 : bytes_counter_r - 1;
                avm_read_w = (bytes_counter_r == 0) ? 0 : 1;
            end
        end
        S_WAIT_CALCULATE:begin
            rsa_start_w = (rsa_finished == 1) ? 0 : 1;
            state_w = (rsa_finished == 1) ? S_CHECK_STATUS_SEND : S_WAIT_CALCULATE;
            avm_read_w = (rsa_finished == 1) ? 1 : 0;
            
        end
        S_CHECK_STATUS_SEND:begin
            if((rsa_dec[bytes_counter_r * 8 + 7 -: 8] == 8'b00000000) && bytes_counter_r != 0) begin
                bytes_counter_w = bytes_counter_r - 1;
            end
            else if(!avm_waitrequest && trdy) begin
                dec_w[247-:8] = rsa_dec[bytes_counter_r * 8 + 7 -: 8];
                avm_read_w = 0;
                avm_write_w = 1;
                state_w = S_SEND_DATA;
            end
        end
        S_SEND_DATA:begin
            if(!avm_waitrequest) begin
                state_w = (bytes_counter_r == 0) ? S_CHECK_STATUS_DATA : S_CHECK_STATUS_SEND;
                bytes_counter_w = (bytes_counter_r == 0) ? 31 : bytes_counter_r - 1;
                avm_write_w = 0;
                avm_read_w = 1;
            end
        end
        endcase
end


    

always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_CHECK_STATUS_PUBLIC;
        bytes_counter_r <= 31;
        rsa_start_r <= 0;
		wait_counter_r <= 0;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;
		wait_counter_r <= wait_counter_w;
    end
end

endmodule
