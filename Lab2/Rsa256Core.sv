module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d, // private key
	input  [255:0] i_n,
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished
);
	parameter S_IDLE = 3'd0;
	parameter S_PREP = 3'd1;
	parameter S_MONT = 3'd2;
	parameter S_CLAC = 3'd3;  
	parameter S_DONE = 3'd4;

	logic [2:0] state, state_next;
	//modulo of product
	logic o_mp_valid, i_mp_finished;
	logic [256:0] o_mp_a;
	logic [255:0] o_mp_N, o_mp_b, i_mp_result;
	logic [8:0] o_mp_k;
	//montgomery for m
	logic o_mont_m_valid, i_mont_m_finished;
	logic [255:0] o_mont_m_N, o_mont_m_a, o_mont_m_b, i_mont_m_result;
	//montgomery for t
	logic o_mont_t_valid, i_mont_t_finished;
	logic [255:0] o_mont_t_N, o_mont_t_a, o_mont_t_b, i_mont_t_result;

	//calculation
	logic [255:0] t, t_next, m, m_next, d, d_next, y, y_next;
	logic [9:0] counter, counter_next;
	
	// ====== Assignment ======
	assign o_a_pow_d = m;

	assign o_finished = (state == S_DONE);
	assign o_mp_valid = state == S_PREP;
	assign o_mont_m_valid = (state == S_MONT) && d[0];
	assign o_mont_t_valid = (state == S_MONT);
	
	assign o_mp_N = i_n;
	assign o_mp_a = {1'b1, 256'b0}; //2^256
	assign o_mp_b = y; //y
	assign o_mp_k = 9'd256; //256
	
	assign o_mont_m_N = i_n;
	assign o_mont_m_a = m;
	assign o_mont_m_b = t;

	assign o_mont_t_N = i_n;
	assign o_mont_t_a = t;
	assign o_mont_t_b = t;

	// ====== Module declaration ======
	ModuloofProduct moduloofproduct(
		.clk(i_clk),
		.reset(i_rst),
		.i_a(o_mp_a),
		.i_b(o_mp_b),
		.i_N(o_mp_N),
		.i_k(o_mp_k),
		.i_valid(o_mp_valid),
		.o_m(i_mp_result),
		.o_valid(i_mp_finished)
	);
	Montgomery montgomery_m(
		.clk(i_clk),
		.reset(i_rst),
		.i_a(o_mont_m_a),
		.i_b(o_mont_m_b),
		.i_N(o_mont_m_N),
		.i_valid(o_mont_m_valid),
		.o_m(i_mont_m_result),
		.o_valid(i_mont_m_finished)
	);
	Montgomery montgomery_t(
		.clk(i_clk),
		.reset(i_rst),
		.i_a(o_mont_t_a),
		.i_b(o_mont_t_b),
		.i_N(o_mont_t_N),
		.i_valid(o_mont_t_valid),
		.o_m(i_mont_t_result),
		.o_valid(i_mont_t_finished)
	);

	// ====== FSM ======
	always_comb begin
		state_next = state;
		case (state)
			S_IDLE: begin
				state_next = i_start ? S_PREP : S_IDLE;
			end
			S_PREP: begin
				state_next = i_mp_finished ? S_MONT : S_PREP;
			end
			S_MONT: begin
				state_next = i_mont_t_finished ? S_CLAC : S_MONT;
			end
			S_CLAC: begin
				state_next = (counter == 10'd255) ? S_DONE : S_MONT;
			end
			S_DONE: begin
				state_next = S_IDLE;
			end
		endcase
	end
	// ====== Counter ======
	always_comb begin
		counter_next = counter;
		case (state)
			S_IDLE: begin
				counter_next = 10'd0;
			end
			S_PREP, S_MONT: begin
				counter_next = counter;
			end
			S_CLAC: begin
				counter_next = counter + 1;
			end
		endcase
	end
	// ====== calculation ======
	always_comb begin
		t_next = t;
		m_next = m;
		d_next = d;
		y_next = y;
		case (state)
			S_IDLE: begin
				if (i_start) begin
					t_next = 256'd0;
					m_next = 256'd1;
					d_next = i_d;
					y_next = i_a;
				end
			end
			S_PREP: begin
				t_next = (i_mp_finished)? i_mp_result: t;
			end
			S_MONT: begin
				t_next = (i_mont_t_finished)? i_mont_t_result: t;
				m_next = (i_mont_m_finished)? i_mont_m_result: m; 
			end
			S_CLAC: begin
				d_next = d >> 1'b1;
			end
		endcase
	end
	// ====== Sequential logic ======
	always_ff @(posedge i_clk or posedge i_rst) begin
		if (i_rst) begin
			state <= S_IDLE;
			t <= 256'd0;
			m <= 256'd0;
			d <= 256'd0;
			counter <= 10'd0;
			y <= 256'd0;
		end 
		else begin
			state <= state_next;
			t <= t_next;
			m <= m_next;
			d <= d_next;
			y <= y_next;
			counter <= counter_next;
		end
	end
endmodule

module ModuloofProduct (
	input clk,
	input reset,
	input i_valid,
	input [256:0] i_a,
	input [255:0] i_b,
	input [255:0] i_N,
	input [8:0] i_k,
	output [255:0] o_m, // a*b mod N
	output o_valid
);
	parameter S_IDLE	= 3'd0;
	parameter S_OP 		= 3'd1;
	parameter S_FINISH 	= 3'd2;

	logic [264:0] m, m_next, t, t_next;
	logic [256:0] a, a_next;
	logic [264:0] sum_m_t, sum_2t;
	logic [9:0] counter, counter_next;
	logic [2:0] state, state_next;
	

	// ====== Assignment ======
	assign o_valid = (state == S_FINISH);
	assign o_m = m;
	assign sum_m_t = m + t; //overflow?
	assign sum_2t = t << 1; //overflow?
	// ====== FSM ======
	always_comb begin
		state_next = state;
		case (state)
			S_IDLE: begin
				state_next = i_valid ? S_OP : S_IDLE;
			end
			S_OP: begin
				state_next = (counter == i_k) ? S_FINISH : S_OP;
			end
			S_FINISH: begin
				state_next = S_IDLE;
			end
		endcase
	end

	// ====== Counter ======
	always_comb begin
		counter_next = counter;
		case (state)
			S_IDLE: begin
				counter_next = 0;
			end
			S_OP: begin
				counter_next = counter + 1;
			end
			S_FINISH: begin
				counter_next = 0;
			end
		endcase
	end

	// ====== combinational logic ======
	always_comb begin
		a_next = a;
		m_next = m;
		t_next = t;
		case (state)
			S_IDLE: begin
				a_next = (i_valid)? i_a: 0;
				t_next = (i_valid)? i_b: 0;
				m_next = (i_valid)? 265'd0: m;
			end
			S_OP: begin
				a_next = 	a >> 1;
				t_next = 	(sum_2t >= i_N)?  sum_2t - i_N: sum_2t;
				m_next =	(!a[0])? m:
							(sum_m_t >= i_N)? sum_m_t - i_N: sum_m_t;
			end
			S_FINISH: begin
				m_next = m;
			end
		endcase
	end

	// ====== Sequential logic ======
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			state <= S_IDLE;
			m <= 265'd0;
			counter <= 10'd0;
			a <= 256'd0;
			t <= 265'd0;
		end 
		else begin
			state <= state_next;
			m <= m_next;
			counter <= counter_next;
			a <= a_next;
			t <= t_next;
		end
	end

endmodule

module Montgomery (
	input clk,
	input reset,
	input i_valid,
	input [255:0] i_N,
	input [255:0] i_a,
	input [255:0] i_b,
	output o_valid,
	output [255:0] o_m
);

parameter S_IDLE   = 0;
parameter S_OP     = 1;
parameter S_FINISH = 2;

logic [264:0] m, m_next;
logic [255:0] a, a_next;
logic [9:0] counter, counter_next;
logic [2:0] state, state_next;
logic o_valid_r, o_valid_w;
logic [264:0] sum_m_b;

assign o_m = m[255:0];
assign sum_m_b = m + i_b;
assign o_valid = o_valid_r;

// combinational
always_comb begin
	a_next = 256'd0;
	m_next = m;
	case (state)

		S_IDLE : begin
			if(i_valid) a_next = i_a;
		end 

		S_OP : begin
			a_next = (a >> 1);
			if(a[0]) begin
				if(sum_m_b[0]) m_next = (sum_m_b + i_N) >> 1;
				else           m_next =  sum_m_b >> 1;
			end
			else begin
				if(m[0]) m_next = (m + i_N) >> 1;
				else     m_next =  m >> 1;
			end
		end

		S_FINISH : begin
			if(counter == 10'd257) m_next = 265'd0;
			else if(m >= i_N) m_next = m - i_N;
		end

	endcase
end

// FSM
always_comb begin
	state_next = state;
	case (state)

		S_IDLE: begin
			if(i_valid) state_next = S_OP;
			else 		state_next = state;
		end

		S_OP: begin
			state_next = (counter == 10'd255) ? S_FINISH : S_OP;
		end

		S_FINISH: begin
			state_next = (counter == 10'd257) ? S_IDLE : S_FINISH;
		end

		default: state_next = state;
	endcase
end

// counter
always_comb begin
	counter_next = counter;
	case (state)

		S_IDLE   : counter_next = counter;

		S_OP     : counter_next = counter + 1;

		S_FINISH : counter_next = (counter == 10'd257) ? 10'd0 : counter + 1;

		default: counter_next = counter;
	endcase
end

// o_valid
always_comb begin
	o_valid_w = 0;
	if(state == S_FINISH && state_next == S_FINISH) o_valid_w = 1;
end

// sequential
always_ff @(posedge reset or posedge clk) begin
	if(reset) begin
		state <= S_IDLE;
		m <= 265'd0;
		counter <= 10'd0;
		o_valid_r <= 0;
		a <= 256'd0;
	end
	else begin
		m <= m_next;
		counter <= counter_next;
		state <= state_next;
		o_valid_r <= o_valid_w;
		a <= a_next;
	end
end
endmodule