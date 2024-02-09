module temp_sens
(
input clk,
input SET,		//запуск устройства
input RESET,	//сброс состояния
input MISO,		// *

output MOSI,	// spi_interface
output reg CS,		// *
output SCK,		// *

output reg [7:0]HEX0,	//младшее число
output reg [7:0]HEX1,	//старшее число

output [7:0]LED,			//вывод шины данных
output LED8
);

reg [4:0]state_q=0;			//регистр состояний

reg [7:0]Dconf=8'h84, Dctrlm=8'hA3;	//регистры установки режима работы датчика BME280
//регистры хранящие адрес ячеек памяти
reg [7:0]ADconf=8'h75, 
			ADctrlm=8'h74, 
			ADdigm1=8'h88, 
			ADdigb1=8'h89, 
			ADdigm2=8'h8A,
			ADdigb2=8'h8B,
			ADdigm3=8'h8C,
			ADdigb3=8'h8D,
			ADtemp_msb=8'hFA,
			ADtemp_lsb=8'hFB, 
			ADtemp_xlsb=8'hFC;

wire [7:0]D_i;
reg [7:0]D_outw;
wire transfer_end;
 
reg [19:0]adc_temp;
reg [31:0]temp, var1, var2;
reg [31:0]digT1, digT2,digT3;	//температурные поправки
reg [31:0]temperature;

reg start;							//регистр начала отправки/приема данных по spi		
reg [3:0]counter;					//регистр счета отправленных бит через spi
reg [3:0]com_ct=0;				//регистр выбора передаваемого байта
reg [3:0]record_ct=0;
reg new_adc=0;

assign LED=D_outw;
assign LED8=MISO;

spi_alexa spi(						//spi интерфейс
.clk(clk),
.start(start),
.MISO(MISO),
.MOSI(MOSI),
.CS(CS),
.D_outw(D_outw),
.D_i(D_i),
.transfer_end(transfer_end));

always@*	//мультиплексор выбора передачи данных
	begin
		case(com_ct)
			0:	D_outw=ADconf;	//передача конфигурации
			1:	D_outw=Dconf;
			2:	D_outw=ADctrlm;
			3:	D_outw=Dctrlm;	
			4:	D_outw=ADdigm1;	//запись температурных поправок
			5:	D_outw=ADdigb1;
			6:	D_outw=ADdigm2;
			7:	D_outw=ADdigb2;
			8:	D_outw=ADdigm3;
			9:	D_outw=ADdigb3;
			10:D_outw=ADtemp_msb;	//считывание данных о температуре
			11:D_outw=ADtemp_lsb;
			12:D_outw=ADtemp_xlsb;
			13:D_outw=0;
			14:D_outw=0;
			15:D_outw=0;
		endcase
	end
always@(posedge clk)//мультиплексор выборазаписи данных
	begin
	case(record_ct)
			1:	digT1[7:0]<=	D_i[7:0];	//температурные поправки
			2:	digT1[15:8]<=	D_i[7:0];
			3:	digT2[7:0]<=	D_i[7:0];
			4:	digT2[15:8]<=	D_i[7:0];
			5:	digT3[7:0]<=	D_i[7:0];
			6:	digT3[15:8]<=	D_i[7:0];
			7:	temp[19:16]<=	D_i[7:4];	//старшие 4 бита температуры
			8:	temp[15:8]<=	D_i[7:0];			//8 бит температуры 15-8
			9:	temp[7:0]<=		D_i[7:0];			//* 7-0
		endcase
	end

	always@(posedge clk)
	begin
			if(SET==0)
				state_q<=1;
			else
			if(RESET==0)
				state_q<=0;
		case(state_q)
			0:	begin
					CS<=1;				//сброс
					start<=0;
					com_ct<=0;
					record_ct<=0;		//*
				end
				
			1:	begin
					counter<=7;			//запись конфигурации
					state_q<=state_q+1;
				end
			2:	begin
					start<=1;
					state_q<=state_q+1;
				end
			3:	begin
					CS<=0;
					start<=0;
					counter<=counter-1;
					if(counter==0)
						state_q<=state_q+1;
					com_ct<=com_ct+1;
				end
			4:	begin
					CS<=1;
					if(com_ct==4)
						begin
							state_q<=state_q+1;
						end
					else
					state_q<=1;
				end
				
			5:	begin
					counter<=7;			//считывание температурных поправок
					state_q<=state_q+1;
				end
			6:	begin
					start<=1;
					state_q<=state_q+1;
					record_ct<=0;
				end
			7:	begin
					CS<=0;
					start<=0;
					counter<=counter-1;
					if(counter==0)
						state_q<=state_q+1;
					com_ct<=com_ct+1;
				end
			8:	begin
					CS<=1;
					if(com_ct>5)
						record_ct<=com_ct-5;
					if(com_ct==10)
						begin
						state_q<=state_q+1;
						end
					else
					state_q<=5;
				end
			
			9:	begin
					state_q<=state_q+1;	//считывание последнего байта температурных поправок
					record_ct<=0;	
					counter<=7;
				end
			10:begin
					CS<=0;
					start<=0;
					counter<=counter-1;
					if(counter==0)
						state_q<=state_q+1;
					com_ct<=com_ct+1;
				end
			11:begin
					CS<=1;
					counter<=8;			
					state_q<=state_q+1;
					record_ct<=com_ct-5;
				end
				
			12:begin
					counter<=7;			//возврат к передаче	10-го состояния com_ct
					state_q<=state_q+1;
					record_ct<=0;
					com_ct<=10;
				end
				
			13:begin
					counter<=7;			//считывание температуры
					state_q<=state_q+1;
					record_ct<=0;
				end
			14:begin
					start<=1;
					state_q<=state_q+1;
				end
			15:begin
					CS<=0;
					start<=0;
					counter<=counter-1;
					if(counter==0)
						state_q<=state_q+1;
					com_ct<=com_ct+1;
				end
			16:begin
					CS<=1;
					counter<=7;
					if(com_ct<14)
						state_q<=state_q+1;
					if(com_ct>11)
						record_ct<=com_ct-5;
					if(com_ct==14&&new_adc==1)
						state_q<=12;
				end
			endcase
					
	end

////простой делитель частоты////	
reg [21:0]count=2499999;
wire clk_25;
assign clk_25=~(|count[21:0]);
always@(posedge clk)begin
		count<=count-1;
	if(clk_25==1)begin
		count<=2499999;
		new_adc<=1;
		end
	if(new_adc==1)
		new_adc<=0;
	end
////////////////////////////////
//вычисление температуры в DEG.c//
always@(posedge clk)begin
if(new_adc==1)
	begin
	var1<=((((adc_temp>>3)-(digT1<<1)))*(digT2)) >> 11;
	var2<=((((adc_temp>>4-digT1)*(adc_temp>>4-digT1))>> 12)*digT3) >> 14;
	temp=var1 + var2;
	temperature=(temp*5+128)>>8;
	end
end
//////////////////////////////

reg [3:0]modulo;
reg [3:0]total;
always@(posedge clk_25)
	begin
	modulo<=temperature%10;
	case(modulo)
	0:
		begin
			HEX0<=8'hC0;
		end
	1:
		begin
			HEX0<=8'hF9;
		end
	2:
		begin
			HEX0<=8'hA4;
		end
	3:
		begin
			HEX0<=8'hB0;
		end
	4:
		begin
			HEX0<=8'h99;
		end
	5:
		begin
			HEX0<=8'h92;
		end
	6:
		begin
			HEX0<=8'h82;
		end
	7:
		begin
			HEX0<=8'hF8;
		end
	8:
		begin
			HEX0<=8'h80;
		end
	9:
		begin
			HEX0<=8'h90;
		end
	endcase
	total<=temperature/10;
	case(total)
	0:
		begin
			HEX1<=8'hC0;
		end
	1:
		begin
			HEX1<=8'hF9;
		end
	2:
		begin
			HEX1<=8'hA4;
		end
	3:
		begin
			HEX1<=8'hB0;
		end
	4:
		begin
			HEX1<=8'h99;
		end
	5:
		begin
			HEX1<=8'h92;
		end
	6:
		begin
			HEX1<=8'h82;
		end
	7:
		begin
			HEX1<=8'hF8;
		end
	8:
		begin
			HEX1<=8'h80;
		end
	9:
		begin
			HEX1<=8'h90;
		end
	endcase
	end

	
endmodule
