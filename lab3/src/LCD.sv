module LCD(
    input clk,
    input rst_n,
    inout [7:0] LCDdata,
    output LCD_ON,   //
    output LCD_BLON, //   
    output LCD_RW,   //   LCD Read/Write Select, 0 = Write, 1 = Read
    output LCD_EN,   //   LCD Enable
    output LCD_RS,   //   LCD Command/Data Select, 0 = Command, 1 = Data
    // input [3:0] status,
    input i_start_record, // 可以只跳一下
    input i_start_play,
    input i_pause_record,
    input i_pause_play,
    input i_stop,
    input [2:0] i_speed,
    input i_fast, // 要一直留著
    input i_slow_0, // constant interpolation
    input i_slow_1 // linear interpolation

);

localparam [69:0] initialize = {
    // wait 15 ms
    10'b0000110000, // Function set
    // wait 4.1 ms
    10'b0000110000, // Function set
    // wait 100 us
    10'b0000110000, // Function set
    // wait busy flag
    10'b0000111000,  // Function set
    // wait busy flag
    10'b0000001100,// Display on 
    // wait busy flag
    10'b0000000001, // Clear display
    // wait busy flag
    10'b0000000110 // Entry mode set
    // initial done
};

typedef enum {
    /// initialize
    IDLE,
    IDLE1, 
    IDLE2,
    WAIT_BUSY,
    FUN_SET,
    DIS_ON,
    DIS_CLR,
    ENTRY_MODE,
    INIT_FIN,
    PLAY,
    PAUSE_PLAY,
    RECORD,
    PAUSE_RECORD

} state_t;

state_t state_w, state_r;
reg [9:0] data_w, data_r;
reg [19:0] init_counter_w, init_counter_r;  // 計時大 delay
reg [5:0] state_counter_w, state_counter_r; // 用來推進 initailize 的步驟
reg [19:0] counter_w, counter_r; // 開始寫入 lcd 
reg en_w, en_r;

assign LCD_ON = 1'b1;
assign LCD_BLON = 1'b1;


// RS, RW, DATA[7:0]
assign LCD_RS  = data_r[9];
assign LCD_RW  = data_r[8];
assign LCDdata = (state_r == WAIT_BUSY)?  8'bzzzzzzzz : data_r[7:0]; // Wait Busy, lcd data should be input
assign LCD_EN = en_r;

always_ff @(posedge clk or negedge rst_n) begin
     if(~rst_n) begin
        state_r <= IDLE;
        data_r  <= initialize[69:60];
        init_counter_r <= 0;
        state_counter_r <= IDLE2;
        counter_r <= 0;
        en_r <= 1'b1;
     end
     else begin
        state_r <= state_w;
        data_r  <= data_w;
        init_counter_r <= init_counter_w;
        state_counter_r <= state_counter_w;
        counter_r <= counter_w;
        en_r <= en_w;
     end
end

// FSM
always_comb begin
    state_w = state_r;
    case(state_r)
        IDLE: begin
            if( init_counter_r == 20'd210000) begin // 205000 cycle = 4.1 ms
                state_w = IDLE1;
            end
        end
        IDLE1: begin
            if( init_counter_r == 20'd6000) begin // 5000 cycle 100 mus
                state_w = IDLE2;
            end
        end
        IDLE2: begin
            state_w = WAIT_BUSY;
        end
        WAIT_BUSY: begin
            if(LCDdata[7] == 1'b0) begin
                case(state_counter_r) 
                    IDLE2: begin
                        state_w = FUN_SET;
                    end
                    FUN_SET: begin
                        state_w = DIS_ON;
                    end
                    DIS_ON: begin
                        state_w = DIS_CLR;
                    end
                    DIS_CLR: begin
                        state_w = ENTRY_MODE;
                    end
                    ENTRY_MODE: begin
                        state_w = INIT_FIN;
                    end
                endcase
            end
        end
        FUN_SET: begin 
            state_w = WAIT_BUSY;
        end
        DIS_ON: begin
            state_w = WAIT_BUSY;
        end
        DIS_CLR: begin
            state_w = WAIT_BUSY;
        end
        ENTRY_MODE: begin
            state_w = WAIT_BUSY;
        end
        INIT_FIN: begin
            if(i_start_play) begin
                state_w = PLAY;
            end
            else if(i_start_record) begin
                state_w = RECORD;
            end
        end
        PLAY: begin
            if(i_pause_play) begin
                state_w = PAUSE_PLAY;
            end
            else if(i_stop) begin
                state_w = INIT_FIN;
            end
        end
        PAUSE_PLAY: begin
            if(i_start_play) begin
                state_w = PLAY;
            end
            else if(i_stop) begin
                state_w = INIT_FIN;
            end
        end
        RECORD: begin
            if(i_pause_record) begin
                state_w = PAUSE_RECORD;
            end
            else if(i_stop) begin
                state_w = INIT_FIN;
            end
        end
        PAUSE_RECORD: begin
            if(i_start_record) begin
                state_w = RECORD;
            end
            else if(i_stop) begin
                state_w = INIT_FIN;
            end
        end


    endcase
end

// combinational logic

always_comb begin
    data_w = data_r;
    init_counter_w = init_counter_r;
    state_counter_w = state_counter_r;
    counter_w = counter_r;
    en_w = en_r;


    case(state_r) 
        IDLE: begin
            init_counter_w = init_counter_r + 1;
            data_w = initialize[69:60];
            if(init_counter_r == 20'd210000) begin
                init_counter_w = 0;
                data_w = initialize[59:50];
            end
        end
        IDLE1: begin
            init_counter_w = init_counter_r + 1'b1;
            if(init_counter_r == 20'd6000) begin
                init_counter_w = 0;
                data_w = initialize[49:40];
            end
        end
        IDLE2: begin
            data_w = 10'b01zzzzzzzz;  // Wait Busy, lcd data should be input
            state_counter_w = IDLE2;
        end
        WAIT_BUSY: begin
            if(LCDdata[7] == 1'b0) begin
                case(state_counter_r) 
                    IDLE2: begin
                        data_w = initialize[39:30];
                    end
                    FUN_SET: begin
                        data_w = initialize[29:20];
                    end
                    DIS_ON: begin
                        data_w = initialize[19:10];
                    end
                    DIS_CLR: begin
                        data_w = initialize[9:0];
                    end
                    ENTRY_MODE: begin
                        data_w = 10'b1000_0000_00; // RW = 1, RS = 0
                    end

                endcase
            end
        end
        FUN_SET: begin
            data_w = 10'b01zzzzzzzz; // RW = 0, RS = 1(read)
            state_counter_w = FUN_SET;
        end
        DIS_ON: begin
            data_w = 10'b01zzzzzzzz; 
            state_counter_w = DIS_ON;
        end
        DIS_CLR: begin
            data_w = 10'b01zzzzzzzz; 
            state_counter_w = DIS_CLR;
        end
        ENTRY_MODE: begin
            data_w = 10'b01zzzzzzzz; 
            state_counter_w = ENTRY_MODE;
        end
        INIT_FIN: begin
            data_w = 10'b1000_0000_00; 
            counter_w = 0;
            en_w  = 1'b0;
        end
        PLAY: begin
            counter_w = counter_r + 1'b1;
            state_counter_w = PLAY;
            if(i_pause_play || i_stop) begin
                counter_w = 0;
                en_w = 1'b0;
            end

            case(counter_r)
                // we don't check the busy flag here we wait 5000 cycles 
                0: begin
                    data_w = initialize[39:30];     // Function set 39 mus 
                    en_w = 1'b1; 
                end
                1: en_w = 1'b0;
                5000: begin
                    data_w = initialize[29:20];  // Display on 39 mus
                    en_w = 1'b1;
                end
                5001: en_w = 1'b0;
                10000: begin
                    data_w = initialize[19:10]; // Clear display 1.53 ms 76500 cycles
                    en_w = 1'b1;
                end
                10001: en_w = 1'b0;
                100000: begin
                    data_w = initialize[9:0]; // Entry mode set 39 mus
                    en_w = 1'b1;
                end
                100001: en_w = 1'b0;
                //  after you write one character, the LCD controller automatically updates the DDRAM 
                //  address to point to the next location
                105000: begin
                    data_w = 10'b0010_000000; // address = 0x80
                    en_w = 1'b1;
                end
                105001: en_w = 1'b0;
                110000: begin
                    data_w = 10'b10_01110000; // p
                    en_w = 1'b1;
                end
                110001: en_w = 1'b0;
                115000: begin
                    data_w = 10'b10_01101100; // l
                    en_w = 1'b1;
                end
                115001: en_w = 1'b0;
                120000: begin
                    data_w = 10'b10_01100001; // a
                    en_w = 1'b1;
                end
                120001: en_w = 1'b0;
                125000: begin
                    data_w = 10'b10_01111001; // y
                    en_w = 1'b1;
                end
                125001: en_w = 1'b0;
                130000: begin
                    data_w = 10'b10_00100000; // space
                    en_w = 1'b1;
                end
                130001: en_w = 1'b0;

                135000: begin // fast slow normal
                    en_w = 1'b1;
                    if(i_fast)  data_w = 10'b10_01100110; // f
                    else if (i_slow_0 || i_slow_1)  data_w = 10'b10_0111_0011; // s
                    else  data_w = 10'b10_01101110; //n
                end
                135001: en_w = 1'b0;

                140000: begin 
                    en_w = 1'b1;
                    if(i_fast) data_w = 10'b10_01100001; // a
                    else if (i_slow_0 || i_slow_1) data_w = 10'b10_01111100; // l
                    else data_w = 10'b10_01101111; // o
                end
                140001: en_w = 1'b0;

                145000: begin
                    en_w = 1'b1;
                    if(i_fast) data_w = 10'b10_01110011; // s
                    else if (i_slow_0 || i_slow_1) data_w = 10'b10_01101111; // o
                    else data_w = 10'b10_01110010; // r
                end
                145001: en_w = 1'b0;

                150000: begin
                    en_w = 1'b1;
                    if(i_fast) data_w = 10'b10_01110100; // t
                    else if (i_slow_0 || i_slow_1) data_w = 10'b10_01110111; // w
                    else data_w = 10'b10_01101101; // m
                end
                150001: en_w = 1'b0;
                
                155000: begin
                    en_w = 1'b1;
                    if(i_fast) data_w = 10'b10_00100000; //space
                    else if(i_slow_0) data_w = 10'b10_00110000; // 0
                    else if(i_slow_1) data_w = 10'b10_00110001; // 1
                    else data_w = 10'b10_01100001; // a
                end
                155001: en_w = 1'b0;

                160000: begin
                    en_w = 1'b1;
                    if(i_fast || i_slow_0 || i_slow_1) data_w = 10'b10_00100000; //space
                    else data_w = 10'b10_01110011; // l
                end
                160001: en_w = 1'b0;
            
                165000: begin
                    en_w = 1'b1;
                    data_w = 10'b10_00100000; // space
                end
                165001: en_w = 1'b0;

                170000: begin
                    en_w = 1'b1;
                    data_w = 10'b00_11000000; // address = 0xC0
                end
                170001: en_w = 1'b0;
                
                175000: begin
                    en_w = 1'b1;
                    if(i_fast) data_w = 10'b10_01011000; // X
                    else if(i_slow_0 || i_slow_1) data_w = 10'b10_01111110; // ~
                end
                175001: en_w = 1'b0;

                180000: begin
                    en_w = 1'b1;
                    $display(i_speed);
                    if(i_fast || i_slow_0 ||  i_slow_1) begin
                        case(i_speed)
                            3'd0: data_w = 10'b10_00110001; // 1
                            3'd1: data_w = 10'b10_00110010; // 2
                            3'd2: data_w = 10'b10_00110011; // 3
                            3'd3: data_w = 10'b10_00110100; // 4
                            3'd4: data_w = 10'b10_00110101; // 5
                            3'd5: data_w = 10'b10_00110110; // 6
                            3'd6: data_w = 10'b10_00110111; // 7
                            3'd7: data_w = 10'b10_00111000; // 8
                        endcase
                    end
                    else data_w = 10'b10_00100000; // space
   
                    
                end
                180001: en_w = 1'b0;

                185000: begin
                    data_w = 10'b10_00100000; // space
                    en_w = 1'b1;
                end
                185001: en_w = 1'b0;
                //////////////////////////////////////// 記得改時間
                3000000: begin
                    counter_w = 0;
                end
            endcase
            
        end
        
        RECORD: begin
            state_counter_w = RECORD;
            counter_w = counter_r + 1'b1;
            if(i_pause_play || i_stop) begin
                counter_w = 0;
                en_w = 1'b0;
            end

            case(counter_r)
                // we don't check the busy flag here we wait 5000 cycles 
                0: begin
                    data_w = initialize[39:30];     // Function set 39 mus 
                    en_w = 1'b1; 
                end
                1: en_w = 1'b0;
                5000: begin
                    data_w = initialize[29:20];  // Display on 39 mus
                    en_w = 1'b1;
                end
                5001: en_w = 1'b0;
                10000: begin
                    data_w = initialize[19:10]; // Clear display 1.53 ms 76500 cycles
                    en_w = 1'b1;
                end
                10001: en_w = 1'b0;
                100000: begin
                    data_w = initialize[9:0]; // Entry mode set 39 mus
                    en_w = 1'b1;
                end
                100001: en_w = 1'b0;
                //  after you write one character, the LCD controller automatically updates the DDRAM 
                //  address to point to the next location
                105000: begin
                    data_w = 10'b0010_000000; // address = 0x80
                    en_w = 1'b1;
                end
                105001: en_w = 1'b0;
                110000: begin
                    data_w = 10'b10_01010010; // R
                    en_w = 1'b1;
                end
                110001: en_w = 1'b0;
                115000: begin
                    data_w = 10'b10_01100101; // e
                    en_w = 1'b1;
                end
                115001: en_w = 1'b0;
                120000: begin
                    data_w = 10'b10_01100011; // c
                    en_w = 1'b1;
                end
                120001: en_w = 1'b0;
                125000: begin
                    data_w = 10'b10_01101111; // o
                    en_w = 1'b1;
                end
                125001: en_w = 1'b0;
                130000: begin
                    data_w = 10'b10_01110010; // r
                    en_w = 1'b1;
                end
                130001: en_w = 1'b0;
                135000: begin
                    data_w = 10'b10_01100100; // d
                    en_w = 1'b1;
                end
                135001: en_w = 1'b0;
                140000: begin
                    data_w = 10'b10_00100000; // space
                    en_w = 1'b1;
                end
                3000000: begin
                    counter_w = 0;
                end
            endcase
        end
        PAUSE_PLAY: begin
            state_counter_w = PAUSE_PLAY;
            en_w = 1'b0;
            counter_w = 1'b0;

        end
        PAUSE_RECORD: begin
            state_counter_w = PAUSE_RECORD;
            en_w = 1'b0;
            counter_w = 1'b0;
        end

    endcase
end



// RS = 0, RW = 1 Read busy flag
// RS = 0, RW = 0 Instruction Register wirte as an internal operation ( display clear)
// RS = 1, RW = 0 Write data to DDRAM or CGRAM
// RS = 1, RW = 1 Read data from DDRAM or CGRAM

endmodule 