module conv(
rst, clk, 
M0_R_req, M0_addr, M0_R_data, M0_W_req, M0_W_data,
M1_R_req, M1_addr, M1_R_data, M1_W_req, M1_W_data,
start,finish

);

input 	rst;
input 	clk;

output	          M0_R_req;
output reg [31:0] M0_addr;
input	   [31:0] M0_R_data;
output	   [3:0]  M0_W_req;
output     [31:0] M0_W_data;

output      	  M1_R_req;
output     [31:0] M1_addr;
input      [31:0] M1_R_data;
output reg [3:0]  M1_W_req;
output reg [31:0] M1_W_data;

input start;
output reg finish;


reg [1:0] cs;
reg [1:0] ns;
reg [9:0] data_addr;
reg [9:0] w_base_addr;
reg [31:0] weight[0:9];
reg [31:0] libuff[0:73];
wire [63:0] result[0:8];
reg [63:0] temp;
reg [31:0] outp [0:675];
integer i;
integer count = 0;
integer w_count = 0;
integer cnt = 0;
integer limit;

wire weight_save;

parameter  IDLE=2'b00;
parameter  GETVALUE=2'b01;
parameter  CONV=2'b10;
parameter  FINISH=2'b11;
reg  getv_en;
reg  acc_en;
reg  w_base_acc_en;
assign M0_R_req = 1'b1;
assign M1_R_req = 1'b1;
assign M1_W_req = 1'b1;
assign result[0] = libuff[0]*weight[0];
assign result[1] = libuff[1]*weight[1];
assign result[2] = libuff[2]*weight[2];
assign result[3] = libuff[28]*weight[3];
assign result[4] = libuff[29]*weight[4];
assign result[5] = libuff[30]*weight[5];
assign result[6] = libuff[56]*weight[6];
assign result[7] = libuff[57]*weight[7];
assign result[8] = libuff[58]*weight[8];





//write your code here
always @(posedge clk,negedge rst)begin
     if(!rst)begin
         cs<=IDLE;
         getv_en<=1'b0;
         acc_en<=1'b0;
         w_base_acc_en<=1'b1;
     end
     else begin
         cs<=ns;
     end     
end
always @(*)begin
    ns = cs ;
	case(cs)
		IDLE:begin//initial
			if(start)begin
                limit = 26;
			    ns=GETVALUE;
			end
            else begin
                ns=IDLE;
            end
		end
		GETVALUE:begin//get value
			if(conv_count==676)begin//check finish signal
				ns=FINISH;
			end
			else begin
                if(getv_en==1)begin
                    if(count>72)begin
                        if(( conv_count != limit ) && ( conv_count != limit+1)) begin
                            ns = CONV;
                        end
                        else begin
                            limit = limit + 28;
                            ns = cs;
                        end
                    end
                    else begin
                        ns = cs;
                    end
                end
			end
		end
		CONV:ns=GETVALUE;//convolution and write data into M1_memory
		FINISH:ns=IDLE;//turn to idle
	endcase
end


/*always @ (posedge clk)begin
    case(cs)
        IDLE:begin
            data_addr <= 10'b0;
        end
        GETVALUE:begin
                 if(count==0)begin
                     M0_addr <= {20'b0,data_addr,2'b0};
                     libuff[count] <= M0_R_data;
                     count = count + 1;
                     acc_en <=1'b1;
                 end
                 else begin
                 if(count<74)begin  
                     M0_addr <= {20'b0,data_addr,2'b0};
                     libuff[count] <= M0_R_data;
                     count = count + 1;
                 end
                 else begin//move every element while count is 74
                     M0_addr <= {20'b0,data_addr,2'b0};
                     libuff[74] <= M0_R_data;
                     for(i=73;i>=0;i=i-1)begin
                        libuff[i]<=libuff[i+1];
                     end
                        count = count + 1;
                 end    
        end
        CONV:begin
           M1_W_req <= 1'b1;
           temp <= (result[0]+result[1])+(result[2]+result[3])+(result[4]+result[5])+(result[6]+result[7])+result[8]+{32'b0,weight[9]};
           outp[count-74] <= temp[47:16]+temp[15];
           M1_W_data <= outp[count-74];
        end
            
        FINISH:begin
            finish <= 1'b1;
        end   
      endcase  
end*/

always @ (*)begin
    case(cs)
        IDLE:begin

        end
        GETVALUE:begin
            if(count<74)begin
                libuff[count] = M0_R_data;
            end
            else begin
                libuff[74] = M0_R_data;
                for(i=73;i>=0;i=i-1)begin
                    libuff[i]=libuff[i+1];
                end
            end
        end
        CONV:begin
            temp = (result[0]+result[1])+(result[2]+result[3])+(result[4]+result[5])+(result[6]+result[7])+result[8];
            outp[count-74] = temp[47:16]+temp[15];
            M1_W_data = outp[count-74];
        end
        FINISH:begin
            finish = 1'b1;
        end   
      endcase  
end



reg [9:0] tmp ;

// always@(posedge clk) begin
//     if (rst) begin
//         tmp <= 10'b0;
//     end
//     else begin
//         if (~w_count)begin
//              tmp <= 10'd784;
//              /*M0_addr <= {20'b0,tmp,2'b0};
//              weight[w_count]<=M0_R_data;
//              w_count = w_count +1;*/
//         end
//         else tmp <= tmp + 10'b1;
//     end
// end


assign weight_save = cnt < 10'd10;
//assign M0_addr     = {20'b0,cnt+10'd784,2'b0};


always @ (*) begin
    if(getv_en==0)begin//get weight and bias
        M0_addr = {20'b0,cnt+10'd784,2'b0};
    end
    else begin//get value
        M0_addr = {20'b0,count,2'b0};
    end
end

always@(*)begin
    if(weight_save)begin
        getv_en=1'b0;
    end
    else begin
        getv_en=1'b1;
    end
end

always@(posedge clk) begin
    if (getv_en) begin
        if (rst) begin
            count <= 0;
        end
        else begin
            count <= count + 1;
        end
    end
end

always@(*) begin
    if(count ==73)begin
        conv_en=1'b1;
    end
    else begin
        conv_en=1'b0;
    end
end

always@(posedge clk) begin
    if(conv_en==0)begin
        conv_count <= 0 
    end
    else begin
        conv_count <= conv_count + 1;
    end
end

always@(posedge clk) begin
    if (rst) begin
        cnt <= 10'b0;
    end
    else begin
        cnt <= cnt + 10'b1;
    end
end

always@(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 10; i = i + 1) begin
            weight[i] <= 32'b0;
        end
    end
    else begin
        if (weight_save)
            weight[cnt] <= M0_R_data;
        end
    end
end



/*always@(posedge clk)begin
    if(w_base_acc_en)begin
        // tmp <= w_base_addr + 1 ;
        tmp <= tmp + 1 ;
    end
end*/


// always @ (posedge clk)begin
// 	//get weight
//     if(w_count==0)begin
//         M0_addr<={20'b0,tmp,2'b0};
//         weight[w_count]<=M0_R_data;
//         w_count=w_count+1;
//     end
//     else begin                                                         
//         if(w_count<10)begin
//             // M0_addr<={20'b0,w_base_addr,2'b0};
//             M0_addr<={20'b0,tmp,2'b0};
//             weight[w_count]<=M0_R_data;
//             w_count = w_count + 1; 
//         end
//         else begin
//             getv_en <=1'b1;
//         end
// 
//     end
// end


endmodule  
