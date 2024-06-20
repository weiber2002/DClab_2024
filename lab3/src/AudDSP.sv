module AudDSP(  //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! 這邊資料傳過去 要等 I2S把資料送完，要等下一個 LRCLK才能操作，只能用一個cycle
                // 在 ~i_daclrck 時，將 i_dac_data 送出
    input i_rst_n,
    input i_clk,
    input i_start,
    input i_pause,
    input i_stop,
    input [2:0] i_speed,  //i_speed + 1 -- real speed
    input i_fast,
    input i_slow_0,
    input i_slow_1,
    input i_daclrck,
    input [15:0] i_sram_data,
    output[15:0] o_dac_data,
    output[19:0] o_sram_addr
);
     // 1024k words by 16 bits
localparam endsram_addr = 20'd1024000; // 1024*1024  // not 1024000
typedef enum {
    IDLE,
    PLAY,
    PAUSE
} state_t;

state_t state_r, state_w;
logic [3:0] counter_w, counter_r;
logic signed [15:0] data_w, data_r;
logic signed [15:0] prev_data_w, prev_data_r;
logic [19:0] addr_w, addr_r;
logic prev_daclrclk_w, prev_daclrclk_r;

assign o_sram_addr = addr_r;
assign o_dac_data = data_r;

// sequential logic
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
        state_r <= IDLE;
        counter_r <= 20'd0;
        data_r <= 16'd0;
        addr_r <= 20'd0;
        prev_daclrclk_r <= 1'b0;
        prev_data_r <= 16'd0;
    end
    else begin
        state_r <= state_w;
        counter_r <= counter_w;
        data_r <= data_w;
        addr_r <= addr_w;
        prev_daclrclk_r <= prev_daclrclk_w;
        prev_data_r <= prev_data_w;
    end
end

// FSM
always_comb begin
    state_w = state_r;
    case(state_r)
        IDLE: begin
            if(i_start) begin
                state_w = PLAY;
            end
        end
        PLAY: begin
            if(i_pause) begin
                state_w = PAUSE;
            end else if(i_stop) begin
                state_w = IDLE;
            end else if (addr_r >= endsram_addr ) begin // finish
                state_w = IDLE;
            end 
        end
        PAUSE: begin
            if(i_start) begin
                state_w = PLAY;
            end else if(i_stop) begin
                state_w = IDLE;
            end
        end
    endcase
end

// combinataional logic
always_comb begin
    counter_w = counter_r;
    addr_w = addr_r;
    prev_daclrclk_w = i_daclrck;
    data_w = data_r;
    prev_data_w = prev_data_r;
    case(state_r)
        IDLE: begin
            counter_w = 20'd0;
            addr_w = 20'd0;
            data_w = 16'bz;
            prev_data_w = 16'd0;
            if(i_start) begin
                data_w = i_sram_data;
            end
        end
        PLAY: begin
            if(i_pause) begin
                data_w = 16'bz;
                counter_w = 1'd0;
            end
            else if(i_stop || addr_r >= endsram_addr) begin // 最後一個少錄沒什麼影響
                data_w = 16'bz;
                addr_w = 20'd0;
                counter_w = 20'd0;
                prev_data_w = 16'd0;
            end 
            else begin
                if(i_fast) begin
                    data_w = i_sram_data;
                    counter_w = 1'd0;
                    if(~prev_daclrclk_r && i_daclrck) begin //(i_daclrck) begin player 用右聲道傳
                        addr_w = addr_r + i_speed + 20'd1;  
                        prev_data_w = $signed(i_sram_data);           
                    end
                end 
                else if(i_slow_0) begin
                    data_w = i_sram_data;
                    if(counter_r >= i_speed) begin
                        if(~prev_daclrclk_r && i_daclrck) begin 
                            addr_w = addr_r + 20'd1;
                            counter_w = 1'd0;
                            prev_data_w = $signed(i_sram_data);
                        end
                    end else begin
                        if(~prev_daclrclk_r && i_daclrck) begin
                            counter_w = counter_r + 1'd1;
                            prev_data_w = $signed(i_sram_data);
                        end
                    end
                end 
                else if(i_slow_1) begin
                    //If counter_r has fewer bits than speed_copy or the result data_w, Verilog will perform sign extension on $signed(counter_r) to 
                    // match the operation's largest operand size before the calculation
                    data_w = ((1 + $signed(i_speed) - $signed(counter_r))*prev_data_r + $signed(i_sram_data)*$signed(counter_r))/ (1 + $signed(i_speed)) ;    
                    // data_w = (counter_r == 4'd4) ? (prev_data_r * (1 + $signed(i_speed) - $signed(0)) + $signed(i_sram_data) * $signed(0)) / (1 + $signed(i_speed)) :
                    //                                          (prev_data_r * (1 + $signed(i_speed) - $signed(counter_r)) + $signed(i_sram_data) * $signed(counter_r)) / (1 + $signed(i_speed));                   ;
                    if(counter_r >= i_speed) begin
                        if(~prev_daclrclk_r && i_daclrck) begin 
                            addr_w = addr_r + 20'd1;
                            counter_w = 1'd0;
                            prev_data_w = $signed(i_sram_data);
                        end
                    end
                    else begin
                        if(~prev_daclrclk_r && i_daclrck) begin
                            counter_w = counter_r + 1'd1;
                        end 
                    end
                end
                else begin
                    data_w = i_sram_data;
                    counter_w = 1'd0;
                    if(~prev_daclrclk_r && i_daclrck) begin //(i_daclrck) begin player 用右聲道傳
                        addr_w = addr_r + 20'd1;   
                        prev_data_w = $signed(i_sram_data);          
                    end
                end
            end
        end
        PAUSE: begin
            data_w = 16'bz;
            if(i_stop) begin
                data_w = 16'bz;
                addr_w = 20'd0;
                counter_w = 20'd0;
                prev_data_w = 16'd0;
            end else if(i_start) begin
                data_w = i_sram_data;
            end
        end
    endcase
end


endmodule

