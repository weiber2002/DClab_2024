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

localparam IDLE = 2'b00, PREP = 2'b01, MONT = 2'b10, CALC = 2'b11;

//reg
logic [1:0] state_r, state_w;
logic [255:0] m_r, m_w;
logic [255:0] t_r, t_w;
logic [7:0] counter_r, counter_w;
logic finish_r, finish_w;

//wire
logic o_prep; 			// prep finished
logic i_mont_start;     // mont can be started
logic o_mont1, o_mont2; // mont output finished
logic [255:0] o_prep_data;
logic [255:0] o_mont1_data;
logic [255:0] o_mont2_data;

assign o_a_pow_d = m_r;
assign o_finished = finish_r;

Montgomery  mont1(.i_clk(i_clk), .i_rst(i_rst), .i_mont_start(i_mont_start),  .i_a(m_r),    .i_b(t_r),   .i_n(i_n), .o_data(o_mont1_data), .o_mont_finished(o_mont1));
Montgomery  mont2(.i_clk(i_clk), .i_rst(i_rst), .i_mont_start(i_mont_start),  .i_a(t_r),    .i_b(t_r),   .i_n(i_n), .o_data(o_mont2_data), .o_mont_finished(o_mont2));
ModuloProduct Mop(.i_clk(i_clk), .i_rst(i_rst), .i_prep_start(i_start), .i_a(i_a),             	   .i_n(i_n), .o_data(o_prep_data),  .o_prep_finished(o_prep));

// sequential logic
always_ff @(posedge i_clk) begin
	if(i_rst) begin
		state_r <= IDLE;
		m_r <= 1;
		t_r <= 0;
		finish_r <= 0;
		counter_r <= 0;
	end
	else begin
		state_r <= state_w;
		m_r  <= m_w;
		t_r <= t_w;
		finish_r <= finish_w;
		counter_r <= counter_w;
	end
end

// combinational logic -- control logic
always_comb begin
	state_w  = state_r;
	finish_w = 1'b0;
	counter_w = counter_r;

	case(state_r) 
	IDLE: begin
		if(i_start) 
			state_w = PREP;
	end
	PREP: begin
		if(o_prep) 
			state_w = MONT;
		else
			state_w = PREP;
	end
	MONT: begin
		if(o_mont1 && o_mont2) 
			state_w = CALC;
		else 
			state_w = MONT;
	end
	CALC: begin
		if(counter_r == 8'd255) begin
			finish_w = 1;
			state_w = IDLE;
			counter_w = 0;
		end
		else  begin
			state_w = MONT;
			counter_w = counter_r + 1;
		end
	end
	endcase
end

// combinational logic -- data logic
always_comb begin
	m_w = m_r;
	t_w = t_r;
	i_mont_start = 1'b0;
	case(state_r) 
	IDLE: begin
		m_w = 1;
		t_w = 0;
	end
	PREP: begin
		m_w = 1;
		t_w = o_prep_data;
	end
	MONT: begin
		if(o_mont1 && o_mont2)begin
			if(i_d[counter_r])
				m_w = o_mont1_data;
			t_w = o_mont2_data;
		end
		i_mont_start = 1'b1;
	end
	endcase
end

endmodule

module Montgomery(
	input 	i_clk,
	input 	i_rst,
	input 	i_mont_start,
	input 	[255:0] i_a,
	input 	[255:0] i_b,
	input 	[255:0] i_n,
	output 	[255:0] o_data,
	output 	o_mont_finished
);
localparam S_IDLE = 2'd0, S_PROC = 2'd1;

//reg 
logic  state_r, state_w;
logic [7:0] counter_r, counter_w;
logic [257:0] m_r, m_w;
logic finish_r, finish_w;

//wire
logic [257:0] temp1, temp2, temp3;
assign temp1 = (i_a[counter_r])? m_r+i_b : m_r ;
assign temp2 = (temp1[0])? temp1+i_n : temp1;
assign temp3 = temp2 >> 1;
assign o_mont_finished = finish_r;
assign o_data = m_r[255:0];


// sequential logic
always_ff @(posedge i_clk ) begin
	if(i_rst) begin
		counter_r <= 0;
		state_r <= S_IDLE;
		m_r <= 0;
		finish_r <= 0;
	end
	else begin
		counter_r <= counter_w;
		state_r <= state_w;
		m_r <= m_w;
		finish_r <= finish_w;
	end
end
// combinational logic -- FSM
always_comb begin
	finish_w = 0;
	state_w = state_r;
	counter_w = counter_r;
	case(state_r) 
	S_IDLE: begin
		if(i_mont_start) 
			state_w = S_PROC;
		else
			state_w = S_IDLE;
	end
	S_PROC: begin
		if(counter_r == 8'd255) begin
			counter_w = 0;
			state_w = S_IDLE;
			finish_w = 1;
		end
		else begin
			counter_w = counter_r + 1;
			state_w = S_PROC;
		end
	end
	endcase
end
//combinational logic -- data logic
always_comb begin
	case(state_r) 
	S_IDLE:
		m_w = 0;
	S_PROC: 
		m_w = (temp3>=i_n)? temp3-i_n:temp3;
	endcase
end

endmodule

module ModuloProduct(
	input 	i_clk,
	input 	i_rst,
	input 	i_prep_start,
	input 	[255:0] i_a, // cipher test y
	input 	[255:0] i_n,
	output  [255:0] o_data,
	output 	o_prep_finished
);
localparam S_IDLE = 2'd0;
localparam S_PROC = 2'd1;

// reg
logic state_r, state_w;
logic [7:0]   counter_r, counter_w;
logic [256:0] t_r, t_w;  // need to compare 2t > N or not, so 257 bits
logic o_finish_r, o_finish_w;
// wire
logic [256:0] tt_compare;

assign tt_compare = t_r << 1;
assign o_data = t_r[255:0];
assign o_prep_finished = o_finish_r;


// sequential logic
always_ff @(posedge i_clk ) begin
	if(i_rst) begin
		state_r <= S_IDLE;
		counter_r <= 8'd0;
		t_r <= 8'd0;
		o_finish_r <= 1'd0;
	end
	else begin
		state_r <= state_w;
		counter_r <= counter_w;
		t_r <= t_w;
		o_finish_r <= o_finish_w;
	end
end

// combintational logic -- control logic
always_comb begin
	state_w = state_r;
	counter_w = counter_r;
	o_finish_w = 1'd0;

	case(state_r)
	S_IDLE: begin
		counter_w  = 8'd0;
		if(i_prep_start) begin
			state_w = S_PROC;
		end
	end
// originally is 256 and return m, however, with the property of data, we can return t at 255
	S_PROC: begin
		if(counter_r == 8'd255) begin 
			state_w = S_IDLE;
			counter_w = 8'd0;
			o_finish_w = 1'd1;
		end
		else begin
			state_w = S_PROC;
			counter_w = counter_r + 8'd1;
		end
	end
	endcase
end

// combintational logic -- data logic

always_comb begin
	t_w = t_r;

	case(state_r) 
	S_IDLE: begin
		if(i_prep_start) 
			t_w = {1'b0, i_a};
		else 
			t_w = 0;
	end

	S_PROC: begin
		if (tt_compare > i_n) 
			t_w = tt_compare - i_n;
		else 
			t_w = tt_compare;
	end
	endcase
end


endmodule