module AudRecorder(
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

typedef enum logic [2:0]{
	IDLE,
	WAIT,
	RECORD,
	PAUSE
} state_t;

state_t state_w, state_r;
logic [4:0] counter_w, counter_r;
logic [19:0] addr_w, addr_r;
logic [15:0] data_w, data_r;

assign o_address = addr_r;
assign o_data = data_r;

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if(~i_rst_n) begin
		state_r <= IDLE;
		counter_r <= 1'b0;
		addr_r <= 20'h0;
		data_r <= 16'b0;
	end
	else begin
		state_r <= state_w;
		counter_r <= counter_w;
		addr_r <= addr_w;
		data_r <= data_w;
	end
end

// FSM
always_comb begin
	state_w = state_r;
	case(state_r) 
		IDLE: begin
			if(i_start) begin
				state_w = WAIT;
			end
		end
		WAIT: begin
			if (i_stop) begin
				state_w = IDLE;
			end else if(i_pause) begin
				state_w = PAUSE;
			end else if (i_lrc) begin // wait for right channel
				state_w = RECORD;
			end
		end
		RECORD: begin
			if(i_stop) begin
				state_w = IDLE;
			end else if(i_pause) begin
				state_w = PAUSE;
			end else if(!i_lrc) begin // it's left channel now, need to wait for right channel
				state_w = WAIT;
			end	
		end
		PAUSE: begin
			if(i_start) begin
				state_w = WAIT;
			end else if(i_stop) begin
				state_w = IDLE;
			end
		end
	endcase
end

always_comb begin
	counter_w = counter_r;
	addr_w = addr_r;
	data_w = data_r;

	case(state_r) 
		IDLE: begin
			addr_w = 20'h0;
			data_w = 16'b0;
			counter_w = 4'b0;
		end
		WAIT: begin
			addr_w = addr_r;
			data_w = 1'b0;
			counter_w = 4'b0;
		end
		RECORD: begin  // 會有第一筆錄的不完整的問題 可能在i_start時剛好是 i_lrck，cycle進行到一半
			if(!i_lrc) begin
				addr_w = addr_r + 20'b1;
				counter_w = 0;
			end // i_pause、 i_stop 不變
			else if(counter_r != 5'd16) begin
				counter_w = counter_r + 4'b1;
				data_w = {data_r[15:0], i_data};
			end 
			else begin
				
			end
		end
		PAUSE: begin
		end
	endcase
end

endmodule