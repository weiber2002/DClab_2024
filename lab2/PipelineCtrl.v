module PPForward ( // It reads readiness (rdy) signals from a source and a destination and generates acknowledgment (ack) signals accordingly.
	input      clk,
	input      rst_n,
	input      src_rdy, //Source ready signal, indicating the source has data or a signal to send
	output reg src_ack, // Source acknowledgment, indicating the data or signal from the source is accepted
	output reg dst_rdy, //Destination ready, indicating this module has data or a signal ready for the destination
	input      dst_ack // Destination acknowledgment signal, indicating the destination is ready to accept more data or has processed the previous data
);

reg dst_rdy_w;
always@* begin
	src_ack = src_rdy && (dst_ack || !dst_rdy);  // src_rdy -> src_ack
	dst_rdy_w = src_rdy || (dst_rdy && !dst_ack); // 有 dst_ack 就會要新的一筆，要重新準備  src_rdy -> dst_rdy
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dst_rdy <= 1'b0;
	end else if (dst_rdy != dst_rdy_w) begin
		dst_rdy <= dst_rdy_w;
	end
end

endmodule

//////////

module PPForwardLoopIn(
	input      clk,
	input      rst_n,
	input      loop_done,
	input      src_rdy,
	output reg src_ack,
	output reg dst_rdy,
	input      dst_ack
);

reg dst_rdy_w;
always@* begin
	src_ack = src_rdy && (dst_ack || !dst_rdy);
	dst_rdy_w = (src_rdy && loop_done) || (dst_rdy && !dst_ack);
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dst_rdy <= 1'b0;
	end else if (dst_rdy != dst_rdy_w) begin
		dst_rdy <= dst_rdy_w;
	end
end

endmodule

//////////

module PPForwardLoopOut(
	input      clk,
	input      rst_n,
	input      loop_done,
	input      src_rdy,
	output reg src_ack,
	output reg dst_rdy,
	input      dst_ack
);

parameter INSTANT_ACK = 1;

reg dst_rdy_w;
always@* begin
	src_ack = src_rdy && ((INSTANT_ACK != 0) && loop_done && dst_ack || !dst_rdy);
	dst_rdy_w = src_rdy || (dst_rdy && !dst_ack && !loop_done);
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		dst_rdy <= 1'b0;
	end else if (dst_rdy != dst_rdy_w) begin
		dst_rdy <= dst_rdy_w;
	end
end

endmodule
