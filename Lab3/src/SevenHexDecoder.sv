module SevenHexDecoder (
	input        [4:0] i_hex,
	output logic [6:0] o_seven_ten,
	output logic [6:0] o_seven_one
);

/* The layout of seven segment display, 1: dark
 *    00
 *   5  1
 *    66
 *   4  2
 *    33
 */
parameter D0 = 7'b1000000;
parameter D1 = 7'b1111001;
parameter D2 = 7'b0100100;
parameter D3 = 7'b0110000;
parameter D4 = 7'b0011001;
parameter D5 = 7'b0010010;
parameter D6 = 7'b0000010;
parameter D7 = 7'b1011000;
parameter D8 = 7'b0000000;
parameter D9 = 7'b0010000;
parameter alphabet_A = 7'b0001000;
parameter alphabet_F = 7'b0001110;
parameter alphabet_S = 7'b0010010;
parameter alphabet_L = 7'b1000111;
parameter alphabet_o = 7'b0100011;
parameter alphabet_t = 7'b0000111;
parameter alphabet_null = 7'b1111111;
always_comb begin
	o_seven_ten = alphabet_null; o_seven_one = alphabet_null;
	case(i_hex)
		5'h0: begin o_seven_ten = D0; o_seven_one = D0; end
		5'h1: begin o_seven_ten = D0; o_seven_one = D1; end
		5'h2: begin o_seven_ten = D0; o_seven_one = D2; end
		5'h3: begin o_seven_ten = D0; o_seven_one = D3; end
		5'h4: begin o_seven_ten = D0; o_seven_one = D4; end
		5'h5: begin o_seven_ten = D0; o_seven_one = D5; end
		5'h6: begin o_seven_ten = D0; o_seven_one = D6; end
		5'h7: begin o_seven_ten = D0; o_seven_one = D7; end
		5'h8: begin o_seven_ten = D0; o_seven_one = D8; end
		5'h9: begin o_seven_ten = D0; o_seven_one = D9; end
		5'ha: begin o_seven_ten = D1; o_seven_one = D0; end
		5'hb: begin o_seven_ten = D1; o_seven_one = D1; end
		5'hc: begin o_seven_ten = D1; o_seven_one = D2; end
		5'hd: begin o_seven_ten = D1; o_seven_one = D3; end
		5'he: begin o_seven_ten = D1; o_seven_one = D4; end
		5'hf: begin o_seven_ten = D1; o_seven_one = D5; end
		5'd16: begin o_seven_ten = alphabet_F; o_seven_one = alphabet_A; end
		5'd17: begin o_seven_ten = alphabet_S; o_seven_one = alphabet_t; end
		5'd18: begin o_seven_ten = alphabet_o; o_seven_one = D0; end
		5'd19: begin o_seven_ten = alphabet_S; o_seven_one = alphabet_L; end
		5'd20: begin o_seven_ten = alphabet_null; o_seven_one = alphabet_null; end
		5'd21: begin o_seven_ten = alphabet_o; o_seven_one = D1; end
	endcase
end

endmodule
