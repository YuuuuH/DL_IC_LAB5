module conv_yt(
input             rst,
input             clk, 
output            M0_R_req,
output     [31:0] M0_addr,
input      [31:0] M0_R_data,
output     [3:0]  M0_W_req,
output     [31:0] M0_W_data,
output            M1_R_req,
output     [31:0] M1_addr,
input      [31:0] M1_R_data,
output reg [3:0]  M1_W_req,
output     [31:0] M1_W_data,
input             start,
output reg        finish
);


parameter [2:0] STATE_IDLE   = 3'b000,
                STATE_SETW   = 3'b001,
                STATE_CAL    = 3'b010,
                STATE_FINISH = 3'b011;

reg               weights_write_latched;
reg               buff_write_latched;
reg        [31:0] licnt;
reg        [31:0] limit;
reg               stop_M1_W;
reg        [31:0] delay_weight2;
reg        [31:0] weight_delay;
reg        [31:0] delay_buff;
reg        [31:0] delay_buff2;
reg        [ 2:0] state;
reg        [ 2:0] nxt_state;

reg               setw_b;
reg               cal_b;

reg        [31:0] cnt;
reg               cnt_rst;

reg signed [31:0] weights         [0: 9];
reg signed [31:0] buff            [0:58];

wire        [31:0]partial_product_round[0:8]; 
wire        [63:0]partial_product [0: 8];
reg               weights_input;
reg               buff_write;
reg               weights_write;
wire              state_setw_done;
wire              state_cal_done;

reg               state_finish_done;
wire       [31:0] out;
integer           i;
reg               licnt_write;


assign partial_product[0] = buff[0] * weights[0];
assign partial_product[1] = buff[1] * weights[1];
assign partial_product[2] = buff[2] * weights[2];
assign partial_product[3] = buff[28] * weights[3];
assign partial_product[4] = buff[29] * weights[4];
assign partial_product[5] = buff[30] * weights[5];
assign partial_product[6] = buff[56] * weights[6];
assign partial_product[7] = buff[57] * weights[7];
assign partial_product[8] = buff[58] * weights[8];

assign partial_product_round[0] = partial_product[0][47:16] + {31'b0 , partial_product[0][15]};
assign partial_product_round[1] = partial_product[1][47:16] + {31'b0 , partial_product[1][15]};
assign partial_product_round[2] = partial_product[2][47:16] + {31'b0 , partial_product[2][15]};
assign partial_product_round[3] = partial_product[3][47:16] + {31'b0 , partial_product[3][15]};
assign partial_product_round[4] = partial_product[4][47:16] + {31'b0 , partial_product[4][15]};
assign partial_product_round[5] = partial_product[5][47:16] + {31'b0 , partial_product[5][15]};
assign partial_product_round[6] = partial_product[6][47:16] + {31'b0 , partial_product[6][15]};
assign partial_product_round[7] = partial_product[7][47:16] + {31'b0 , partial_product[7][15]};
assign partial_product_round[8] = partial_product[8][47:16] + {31'b0 , partial_product[8][15]};


assign out = partial_product_round[0] + partial_product_round[1] + partial_product_round[2] +
             partial_product_round[3] + partial_product_round[4] + partial_product_round[5] +
             partial_product_round[6] + partial_product_round[7] + partial_product_round[8] +
             weights[9];

assign M0_R_req   = 1'b1;
assign M1_R_req   = 1'b1;

assign M0_addr    = weights_input ? {20'b0, licnt, 2'b0} : {20'b0, cnt + 10'd784, 2'b0};
assign M1_addr    = {20'b0, cnt-56 ,2'b0};
assign M1_W_data  = out;

/*
always @(posedge clk) begin
    if (~rst) begin
        M1_addr <= 32'b0;
    end
    else begin
        if (delay) begin
            
        end
    end
end
*/

assign state_setw_done   = cnt == 32'd9;
assign state_cal_done    = cnt == 32'd783;

reg    [31:0]  M1_addr_delay2;
reg    [31:0]  M1_addr_delay;

always @(posedge clk) begin
    if (~rst) state <= STATE_IDLE;
    else      state <= nxt_state;
end

always @(*) begin
    nxt_state = state;
    case(state)
        STATE_IDLE  :   nxt_state = start                ? STATE_SETW     : STATE_IDLE;
        STATE_SETW  :   nxt_state = state_setw_done      ? STATE_CAL      : STATE_SETW;
        STATE_CAL   :   nxt_state = state_cal_done       ? STATE_FINISH   : STATE_CAL;
        STATE_FINISH:   nxt_state = state_finish_done    ? STATE_IDLE     : STATE_FINISH;
    endcase
end

always @(*) begin
    cnt_rst       = 1'b0;
    weights_write = 1'b0;
    buff_write    = 1'b0;
    finish        = 1'b0;
    M1_W_req      = 4'b0000;
    licnt_write   = 1'b0;
    //delay         = 1'b0;
    case(state)
        STATE_IDLE:   begin 
            cnt_rst       = start;
        end
        STATE_SETW:   begin 
            cnt_rst       = state_setw_done;
            weights_write = 1'b1;
            weights_input = 1'b0;
        end
        STATE_CAL:    begin 
            cnt_rst       = state_cal_done;
            buff_write    = 1'b1;
            licnt_write   = 1'b1;
            weights_input = 1'b1;
            if((licnt>=58)&&stop_M1_W==1'b1)begin
               // delay     = 1'b1;
                M1_W_req  = 4'b1111;
            end
        end
        STATE_FINISH: begin 
            state_finish_done = 1'b1;
            finish            = 1'b1;
        end
    endcase
end

// delay one block method
 
always @(posedge clk) begin
    if (~rst) begin
        buff_write_latched <= 1'b0;
    end
    else begin
        buff_write_latched <= buff_write;
    end
end

always @(posedge clk) begin
    if (~rst) begin
        weights_write_latched <= 1'b0;
    end
    else begin
        weights_write_latched <= weights_write;
    end
end


always @(posedge clk) begin
    if (~licnt_write) begin
        limit     <= 32'd28;
        licnt     <= 32'b0;
    end
    else begin
        if(licnt==783||licnt==784)begin
            stop_M1_W <= 1'b1;
        end
        else begin
            if(licnt<=limit)begin
                if(licnt < limit-1)begin
                    licnt <= licnt + 32'b1;
                stop_M1_W <= 1'b1;
            end
                else begin
                    licnt <= licnt + 32'b1;
                    stop_M1_W <= 1'b0;
                end
            end
            else begin
                licnt <= licnt + 32'b1;
                stop_M1_W <= 1'b1;
                limit <= limit + 28;
            end
        end
    end
end


always @(posedge clk) begin
    if (~rst) begin
        cnt <= 32'b0;
    end
    else begin
        if(cnt_rst==1)begin
            cnt <= 32'b0;
        end
        else begin
            if(licnt!=limit)begin
                if(licnt!=limit+1)begin
                   cnt <= cnt + 32'b1;
                end
            end
        end
       // cnt <= cnt_rst ? 32'b0 : cnt + 32'b1;
    end
end


always @(posedge clk) begin
    if (~rst) begin
        for (i = 0; i < 10; i = i + 1) begin
            weights[i] <= 32'b0;
        end
    end
    else begin
        if (weights_write_latched) begin
            weights[9] <= M0_R_data;
            for (i = 0; i < 9; i = i + 1) begin
                weights[i] <= weights[i + 1];
            end
        end
    end
end

always @(posedge clk) begin
    if (~rst) begin
        for (i = 0; i < 59; i = i + 1) begin
            buff[i] <= 32'b0;
        end
    end
    else begin
        if (buff_write_latched) begin 
            buff[58]   <= M0_R_data;
            for (i = 0; i < 58; i = i + 1) begin
                buff[i] <= buff[i + 1];
            end
        end
    end
end

always @(posedge clk) begin
    if (~rst) begin
        for (i=0; i<59; i=i+1) begin
            buff[i] <= 32'b0;
        end
    end
    else begin
        if(cal_b)begin
            buff[58]<=M0_R_data;
            for(i=0;i<58;i=i+1)begin
                buff[i]<=buff[i+1];
            end
        end
    end
end


endmodule

