module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output logic [4:0] avm_address,
    output logic  avm_read,
    input  [31:0] avm_readdata,
    output logic  avm_write,
    output logic [31:0] avm_writedata,
    input         avm_waitrequest
);

// address location
localparam RX_BASE = 0*4;
localparam TX_BASE = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT = 6;
localparam RX_OK_BIT = 7;

// state 
localparam CHECK_READ = 3'b000, READ = 3'b001, CALC = 3'b010,  CHECK_WRITE = 3'b011, WRITE = 3'b100;

// reg
logic [6:0] counter_r, counter_w; // 1~32 n, 33~64 d, 65~96 enc 
logic [2:0] state_r, state_w;
logic [255:0] d_r, d_w;
logic [255:0] n_r, n_w;
logic [255:0] enc_r, enc_w; // encrypted data
logic [255:0] dec_r, dec_w; // decrypted data
logic [4:0]   avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;
logic rsa_start_r, rsa_start_w; // start calc


//wire
logic rsa_finished; // calc finishied
logic [255:0] decrypt_data;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8]; //247~240


// core
Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),  // 先n再D'
    .i_n(n_r),
    .o_a_pow_d(decrypt_data),
    .o_finished(rsa_finished)
);

//sequential logic 
always_ff @(posedge avm_clk  or posedge avm_rst) begin  // active low reset?????
    if(avm_rst) begin
        counter_r <= 0;
        state_r <= CHECK_READ;
        d_r <= 0;
        n_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;   //!!!!!!!!!!!! 抬起來才有 wait request
        avm_write_r <= 0;
        rsa_start_r <= 0;
    end
    else begin
        counter_r <= counter_w;
        state_r <= state_w;
        d_r <= d_w;
        n_r <= n_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        rsa_start_r <= rsa_start_w;
    end
end

// FSM
always_comb begin
    state_w = state_r;
    case(state_r)
    CHECK_READ: begin
        if(~avm_waitrequest && avm_readdata[RX_OK_BIT]) begin
            state_w = READ;
        end
        else begin
            state_w = CHECK_READ;
        end
    end
    READ: begin
        if(~avm_waitrequest) begin
            state_w = CHECK_READ;
            if(counter_r == 7'd96)
                state_w = CALC;
        end
        else begin
            state_w = READ;
        end
    end
    CALC: begin
        if(rsa_finished) begin
            state_w = CHECK_WRITE;
        end
        else begin
            state_w = CALC;
        end
    end
    CHECK_WRITE: begin
        if(~avm_waitrequest && avm_readdata[TX_OK_BIT]) begin
            state_w = WRITE;
        end
        else begin
            state_w = CHECK_WRITE;
        end
    end
    WRITE: begin
        if(~avm_waitrequest) begin
            state_w = CHECK_WRITE;
            if(counter_r == 7'd31)  // 只送 31個bit
                state_w = CHECK_READ;
        end
        else begin
            state_w = WRITE;
        end
    end
    endcase
end

// combinational logic -- data logic
always_comb begin
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    avm_address_w = avm_address_r;
    counter_w = counter_r;

    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    rsa_start_w = rsa_start_r;
    dec_w = dec_r;


    case(state_r) 
    CHECK_READ: begin
        if(~avm_waitrequest && avm_readdata[RX_OK_BIT]) begin
            avm_read_w = 1;  // 讀 readdata
            avm_write_w = 0;
            avm_address_w = RX_BASE;
            counter_w = counter_r + 1;
        end else begin
            avm_read_w = 1;
            avm_write_w = 0;
            avm_address_w = STATUS_BASE;
            counter_w = counter_r;
        end
    end

    READ: begin
        if(~avm_waitrequest) begin
            avm_read_w = 1;  // 要讀 RX_OK_BIT
            avm_write_w = 0;
            avm_address_w = STATUS_BASE;
            if(counter_r <=  7'd32) begin
                n_w = (n_r<<8) + avm_readdata[7:0]; // 一次八位
            end
            else if(counter_r <= 7'd64) begin
                d_w = (d_r<<8) + avm_readdata[7:0];
            end
            else if (counter_r <= 7'd95) begin
                enc_w = (enc_r<<8) + avm_readdata[7:0];
            end
            else begin
                enc_w = (enc_r<<8) + avm_readdata[7:0];  // + has higher priority than << 
                rsa_start_w = 1;                         // if we don't use () it will lead to different result
                avm_address_w = STATUS_BASE;
            end
        end
        else begin
            avm_read_w = 1;
            avm_write_w = 0;
            avm_address_w = RX_BASE;
        end
    end
    CALC: begin
        rsa_start_w = 0;  // this fucking rsa_start_w should be 0
        avm_read_w = 1; // read 要一直是1
        avm_write_w = 0;
        avm_address_w = STATUS_BASE;
        if(rsa_finished) begin
            dec_w = decrypt_data;
            counter_w = 0;
        end
    end
    CHECK_WRITE :begin
        if(~avm_waitrequest && avm_readdata[TX_OK_BIT]) begin
            avm_read_w = 0;
            avm_write_w = 1;
            avm_address_w = TX_BASE;
            counter_w = counter_r + 1;
        end
        else begin
            avm_read_w = 1;
            avm_write_w = 0;;
            avm_address_w = STATUS_BASE;
        end
    end
    WRITE: begin
        if(~avm_waitrequest) begin
            avm_read_w = 1;
            avm_write_w = 0;
            avm_address_w = STATUS_BASE;
            if(counter_r <= 7'd30) begin  //Receive 31-Byte plain text x
                dec_w = dec_r<<8;
            end
            else begin
                dec_w = 0;
                counter_w = 7'd64;
                enc_w = 0;
            end
        end
        else begin
            avm_read_w = 0;
            avm_write_w = 1;
            avm_address_w = TX_BASE;
        end
    end
    endcase
end

endmodule