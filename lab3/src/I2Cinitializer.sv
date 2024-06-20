module I2Cinitializer (
    input i_rst_n,
    input i_clk,
    input i_start,
    output o_finished,
    output o_sclk,
    inout  o_sdat,
    output o_oen

);


localparam inst_num = 11;
localparam data_num = 11*24;

localparam [ data_num-1 : 0 ] setup_data = {
    24'b0011_0100_000_1111_0_0000_0000, //reset
    24'b0011_0100_000_0000_0_1001_0111, //left line in
    24'b0011_0100_000_0001_0_1001_0111, //right line in
    24'b0011_0100_000_0010_0_0111_1001, //left headphone out
    24'b0011_0100_000_0011_0_0111_1001, //right headphone out
    24'b0011_0100_000_0100_0_0001_0101, //analog audio path control
    24'b0011_0100_000_0101_0_0000_0000, //digital audio path control
    24'b0011_0100_000_0110_0_0000_0000, //power down control
    24'b0011_0100_000_0111_0_0100_0010, //digital audio interface format
    24'b0011_0100_000_1000_0_0001_1001, //sample rate control
    24'b0011_0100_000_1001_0_0000_0001  //digital audio interface activation
};

typedef enum  {
    IDLE,
    WAIT1,
    WAIT2,
    PREP,
    SEND,
    KEEP,
    ACK_PREP,
    ACK_SEND,
    ACK_KEEP,
    FINISH_0,
    FINISH_1,
    FINISH_2
} state_e;

logic [8:0] inst_counter_w, inst_counter_r;
logic finished_w, finished_r;
logic sclk_w, sclk_r;
logic sdat_w, sdat_r;
logic oen_w, oen_r;
logic [data_num-1:0] data_w, data_r;

state_e state_w, state_r;

assign o_finished = finished_r;
assign o_sclk = sclk_r;
assign o_sdat = (oen_r)? sdat_r : 1'bz;
assign o_oen = oen_r;


// sequential logic
always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
        state_r <= IDLE;
        inst_counter_r <= 0;
        finished_r <= 0;
        sclk_r <= 1;
        sdat_r <= 1;
        oen_r <= 1;
        data_r <= setup_data;
    end else begin
        state_r <= state_w;
        inst_counter_r <= inst_counter_w;
        finished_r <= finished_w;
        sclk_r <= sclk_w;
        sdat_r <= sdat_w;
        oen_r <= oen_w;
        data_r <= data_w;
    end
end

// FSM
always_comb begin
    state_w = state_r;
    case(state_r)
        IDLE: begin
            if(i_start) begin
                state_w = WAIT1;
            end
            else begin
                state_w = IDLE;
            end
        end
        WAIT1: begin
            state_w = WAIT2;
        end
        WAIT2: begin
            state_w = PREP;
        end
        PREP: begin
            state_w = SEND;
        end
        SEND: begin
            state_w = KEEP;
        end
        KEEP: begin
            if(inst_counter_r[2:0] == 3'b111) begin
                state_w = ACK_PREP;
            end
            else begin
                state_w = PREP;
            end
        end
        ACK_PREP: begin
            state_w = ACK_SEND;
        end
        ACK_SEND: begin
            state_w = ACK_KEEP;
        end
        ACK_KEEP: begin
            if(inst_counter_r == (data_num - 1'b1)) begin
                state_w = FINISH_0;
            end else begin
                state_w = PREP;
            end
        end
        FINISH_0: begin
            state_w = FINISH_1;
        end
        FINISH_1: begin
            state_w = FINISH_2;
        end
        FINISH_2: begin
            state_w = FINISH_2;
        end
    endcase
end

// combinational logic
always_comb begin
    sdat_w = sdat_r;
    sclk_w = sclk_r;
    oen_w = oen_r;
    data_w = data_r;
    finished_w = finished_r;
    inst_counter_w = inst_counter_r;

    case(state_r)
        IDLE: begin
            if(i_start) begin
                sdat_w = 1'b0;
                sclk_w = 1'b1;
                oen_w = 1'b1;
            end 
        end
        WAIT1: begin
            sclk_w = 1'b0;
            sdat_w = 1'b0;
            oen_w = 1'b1;
        end
        WAIT2: begin
            sclk_w = 1'b0;
            sdat_w = data_r[data_num-1'b1];
            oen_w = 1'b1;
        end
        PREP: begin
            sclk_w = 1'b1;
            sdat_w = sdat_r;
            oen_w = 1'b1;
        end
        SEND: begin
            sclk_w = 1'b0;
            sdat_w = sdat_r;
            oen_w = 1'b1;
            data_w = data_r << 1;
            inst_counter_w =   inst_counter_r + 1'b1;
        end
        KEEP: begin
            if(inst_counter_r[2:0] == 3'b111) begin
                sclk_w = 1'b0;
                sdat_w = 1'b0;
                oen_w = 1'b0;
            end
            else begin
                sclk_w = 1'b0;
                sdat_w = data_r[data_num-1'b1];
                oen_w = 1'b1;
            end
        end
        ACK_PREP: begin
            sclk_w = 1'b1;
            sdat_w = 1'b0;
            oen_w = 1'b0;
        end     
        ACK_SEND: begin
            sclk_w = 1'b0;
            sdat_w = 1'b0;
            oen_w = 1'b0;
        end
        ACK_KEEP: begin
            if(inst_counter_r == (data_num - 1'b1)) begin
                sclk_w = 1'b0;
                sdat_w = 1'b0;
                oen_w = 1'b1;
            end
            else begin
                sclk_w = 1'b0;
                sdat_w = data_r[data_num-1'b1];
                oen_w = 1'b1;
            end
        end
        FINISH_0: begin
            sclk_w = 1'b1;
            sdat_w = 1'b0;
            oen_w = 1'b1;
        end
        FINISH_1: begin
            sclk_w = 1'b1;
            sdat_w = 1'b1;
            oen_w = 1'b1;
            finished_w = 1'b1;
        end
        FINISH_2: begin
            sclk_w = 1'b1;
            sdat_w = 1'b1;
            oen_w = 1'b1;
        end
    endcase
end



endmodule
