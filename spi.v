module spi
(
input clk,
input start,
input MISO,
input CS,
input [7:0]D_outw,

output [7:0]D_i,
output reg MOSI,
output reg transfer_end
);

assign D_i=D;
reg [7:0]D;
reg [7:0]D_out;

always@(posedge clk)
begin
	if(CS==0)
	begin
		D[0]<=MISO;
		D[7:1]<=D[6:0];
	end
end

always@(negedge clk)
begin
if(start==1)
	begin
	D_out=D_outw;
	end
	
if(CS==0)
	begin
		MOSI<=D_out[7];
		D_out[7:1]<=D_out[6:0];
	end
end

always@(posedge CS, negedge clk)
begin
	if(CS==1)
	begin
	transfer_end<=1;
	end
	else begin
	if(clk==0)
	begin
	transfer_end<=0;
	end end
end



endmodule
