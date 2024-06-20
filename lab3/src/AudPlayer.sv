module AudPlayer( // 在 ~i_daclrck 時，將 i_dac_data 送出
    input i_rst_n,
    input i_bclk,
    input i_daclrck,
    input i_en,
    input signed [15:0] i_dac_data,
    output o_aud_dacdat
    // output o_daclrck // for test
);

typedef enum logic [1:0] {
    IDLE,
    WAIT,
    PLAY
} state_t;

state_t state_r, state_w;
logic [4:0] counter_r, counter_w;
logic dat_w, dat_r;
logic fin_w, fin_r;

assign o_aud_dacdat = dat_r;
// assign o_daclrck = i_daclrck;

// sequential logic
always_ff @(posedge i_bclk or negedge i_rst_n) begin
    if(~i_rst_n) begin
        state_r <= IDLE;
        counter_r <= 4'd15;
        dat_r <= 1'b0;
        fin_r <= 1'b0;
    end
    else begin
        state_r <= state_w;
        counter_r <= counter_w;
        dat_r <= dat_w;
        fin_r <= fin_w;
    end
end

// FSM
always_comb begin
    state_w = state_r;
    case(state_r)
        IDLE: begin
            if(i_en && i_daclrck) begin // state== PLAY
                state_w = WAIT;
            end
        end
        WAIT: begin
            if(~i_en) begin
                state_w = IDLE;
            end else if(~i_daclrck && fin_r) begin
                state_w = PLAY;
            end
        end
        PLAY: begin
            if(~i_en) begin
                state_w = IDLE;
            end else if(counter_r == 4'd15) begin
                state_w = WAIT;
            end
        end
    endcase
end

// combinational logic

always_comb begin
    counter_w = 1'b0;
    dat_w = 1'b0;
    fin_w = 1'b0;

    case(state_r)
    IDLE: begin
        counter_w = 4'd0;
        dat_w = 1'b0;
        fin_w = 1'b0;
       
    end
    WAIT: begin
        
        if(~i_daclrck && fin_r) begin
            counter_w = 4'd1;
            fin_w = 1'b0;
            dat_w = i_dac_data[15 - counter_r];
        
        end else if(i_daclrck) begin
            counter_w = 4'd0;
            fin_w = 1'b1;
            dat_w = 1'b0;
        end
        else begin
            counter_w = 4'd0;
            fin_w = 1'b0;
            dat_w = 1'b0;
        end
    end
    PLAY: begin
        dat_w = i_dac_data[15 - counter_r];
        if(i_daclrck) begin
            counter_w = 4'd1;
            fin_w = 1'b0;
        end else if(counter_r < 4'd15) begin
            counter_w = counter_r + 4'd1;
            fin_w = 1'b0;
            
        end else begin
            // counter_w = counter_r is written above
            fin_w = 1'b0;
            counter_w = 4'd0;
        end 
    end
    endcase
end

// 會有第一筆不完整的問題，可能在i_en時剛好是 ~i_daclrck，cycle進行到一半
endmodule