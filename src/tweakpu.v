//////////////////////////////////////////////////////////////////
//
//
//////////////////////////////////////////////////////////////////

`timescale 1us/1us

//////////////////////////////////////////////////////////////////
// encoding format

// 3 operand instruction (2 in, 1 out)
// 0xcxxx .. 0xfxxx
//	   2 bits: encoding
//     6 bits: instruction
//    12 bits: registers
//    12 bits: data

// 2 operand instruction (1 in, 1 out) 
// 0x8xxx .. 0xbxxx
//	   2 bits: encoding
//     6 bits: instruction
//     8 bits: registers
//    16 bits: data

// 1 operand instruction (1 in or 1 out) 
// 0x4xxx .. 0x7xxx
//	   2 bits: encoding
//     6 bits: instruction
//     4 bits: registers
//    20 bits: data

// 0 operand instruction  
// 0x0xxx .. 0x3xxx
//	   2 bits: encoding
//     6 bits: instruction
//    24 bits: data

//////////////////////////////////////////////////////////////////
// instruction decoder
//////////////////////////////////////////////////////////////////

module tweakdec( input Trigger,
				 input [31:0] OPCODE,	// incoming composite instruction code
				 output [1:0]  ecode,	// outgoing 
				 output [5:0]  icode,
				 output [23:0] dcode,
				 output [11:0] rcode );
				 
	//////////////////////////////////////////
	// encodings
	//////////////////////////////////////////

	wire [11:0] rcode0 = { 12'b0 };
	wire [11:0] rcode1 = { OPCODE[23:20], 8'h00 };
	wire [11:0] rcode2 = { OPCODE[7:0], 4'h0 };
	wire [11:0] rcode3 = { OPCODE[11:0] };

	wire [23:0] dcode0 = { OPCODE[23:0] };
	wire [23:0] dcode1 = { OPCODE[19:0], 4'h0 };
	wire [23:0] dcode2 = { OPCODE[23:8], 8'h00 };
	wire [23:0] dcode3 = { OPCODE[23:12], 12'h000 };

	wire [1:0] iecode = OPCODE[31:30];
	wire [5:0] iicode = OPCODE[29:24];

	reg [23:0] idcode;
	reg [11:0] ircode;

	always @*
	begin
	  case(iecode)
	    2'b00: idcode = dcode0;
	    2'b01: idcode = dcode1;
	    2'b10: idcode = dcode2;
	    2'b11: idcode = dcode3;
	  endcase
	end
	always @*
	begin
	  case(iecode)
	    2'b00: ircode = rcode0;
	    2'b01: ircode = rcode1;
	    2'b10: ircode = rcode2;
	    2'b11: ircode = rcode3;
	  endcase
	end
	
	//////////////////////////////////////////
	
	assign ecode[1:0] = iecode[1:0];		
	assign icode[5:0] = iicode[5:0];		
	assign dcode[23:0] = idcode[23:0];		
	assign rcode[11:0] = ircode[11:0];		
	
endmodule
				 
//////////////////////////////////////////////////////////////////
// ALU
//////////////////////////////////////////////////////////////////

module tweakalu3(	input AluTrigger, input [5:0] icode, 
					input [31:0] ain, input [31:0] bin, 
					output [31:0] outc );

	parameter [4:0]

		alucode_add = 5'b00000,
		alucode_sub = 5'b00001,

		alucode_and = 5'b00010,
		alucode_or =  5'b00011,
		alucode_xor = 5'b00100;

	reg [31:0] resC = 0;
	
	wire [31:0] res_add = (ain+bin);
	wire [31:0] res_sub = (ain-bin);
	wire [31:0] res_and = (ain&bin);
	wire [31:0] res_or = (ain|bin);
	wire [31:0] res_xor = (ain^bin);

	always @( posedge AluTrigger )
	begin
		case( icode )
			alucode_add :	begin		resC<=res_add;		end
			alucode_sub :	begin		resC<=res_sub;		end
			alucode_and :	begin		resC<=res_and;		end
			alucode_or  :	begin		resC<=res_or;		end
			alucode_xor :	begin		resC<=res_xor;		end
			default :		begin		resC<=ain;			end
		endcase
	end
	
	assign outc = resC;
	
endmodule
	
//////////////////////////////////////////////////////////////////

module tweakalu2(	input AluTrigger, input [5:0] icode, 
					input [31:0] ain,
					output [31:0] outb );

	parameter [4:0]

		alucode_copy = 5'b00000,
		alucode_neg = 5'b00001;

	reg [31:0] res = 0;
	
	wire [31:0] res_copy = (ain);
	wire [31:0] res_neg = (-ain);

	always @( posedge AluTrigger )
	begin
		case( icode )
			alucode_copy :	begin		res<=res_copy;		end
			alucode_neg :	begin		res<=res_neg;		end
			default :		begin		res<=ain;			end
		endcase
	end
	
	assign outb = res;
	
endmodule
	
//////////////////////////////////////////////////////////////////
// Registers
//////////////////////////////////////////////////////////////////

module tweakregs( input Trigger, input rW, input [3:0] address, input [31:0] inp, output [31:0] outp );

	reg [31:0] registers [0:15];
	reg [31:0] outputbuffer;
	
	wire WriteTrigger = Trigger&rW;
	wire ReadTrigger = Trigger&(!rW);
	
	always @( posedge WriteTrigger )
		begin
			registers[address] = inp; 
		end
	always @( posedge ReadTrigger )
		begin
			outputbuffer = registers[address]; 
		end
		
	assign outp = outputbuffer;

endmodule

//////////////////////////////////////////////////////////////////

module Memory( input READENA, input [3:0] addr_in, output [31:0] dataout );
 
	parameter NUMWORDS = 8;
	parameter WORDSIZE = 32;
	
	reg [ WORDSIZE -1 : 0 ] InsMem[ 0: NUMWORDS-1 ];
	reg [ WORDSIZE -1 : 0 ] OutReg;
	
	initial begin
		OutReg = 0;
		InsMem[0] = { 8'hf0, 8'h00, 16'h1 };
		InsMem[1] = { 8'h40, 8'h00, 16'h1 };
		InsMem[2] = { 8'hf0, 8'h00, 16'h2 };
		InsMem[3] = { 8'h30, 8'h00, 16'h3 };
		InsMem[4] = { 8'h00, 8'h00, 16'h4 };
		InsMem[5] = { 8'hf0, 8'h00, 16'h5 };
		InsMem[6] = { 8'h00, 8'h00, 16'h6 };
		InsMem[7] = { 8'h60, 8'h00, 16'h7 };
	end

	always @( posedge READENA )
		begin
		OutReg = InsMem[ addr_in[ 2:0 ] ];
		end

	assign dataout = OutReg;
	
 endmodule
 
 //////////////////////////////////////////////////////////////////

module tweakpu (input CLK, input RESET, output op );

	//////////////////////////////

	reg [3:0] ADDRESS;
	reg HCLK;
	reg HCLK2;
	reg [31:0] cur_opcode;
	reg [31:0] regobuf;
	reg [31:0] regibuf;

	//////////////////////////////

	wire RegLoadStoreTrigger;
	wire [3:0] RegAddress;
	wire [31:0] RegInput;
	wire [31:0] RegOutput;
	wire RegrW;
	
	wire [31:0] memdata;
	wire [31:0] alu_result;

	//////////////////////////////

	wire [1:0] ecodeA;
	wire [5:0] icodeA;
	wire [23:0] dcodeA;
	wire [11:0] rcodeA;

	//////////////////////////////

	reg rENA, rENAD;
	
	wire NRES = ! RESET;
	wire NCLK = ! CLK;
	wire HCLK3 = ! HCLK;
	wire HCLK4 = ! HCLK2;

	wire phase_A = HCLK3&NRES;
	wire phase_B = HCLK2&NRES;
	wire phase_C = HCLK&rENA;
	wire phase_D = HCLK4&rENAD;

	//////////////////////////////

	initial begin
		rENA = 0;
		rENAD = 0;
		ADDRESS = 4'h0;
		HCLK = 1;
		HCLK2 = 1;
		cur_opcode = 32'h00;
	end
	
	//////////////////////////////
	
	always @( posedge phase_C )
		begin
		rENAD <= 1;
		end

	always @( negedge CLK )
		begin
		cur_opcode = memdata; // sample memory
		end

	always @( posedge CLK )
		begin
		rENA <= 1;
		HCLK <= ~ HCLK;
		ADDRESS <= RESET ? 0 : ADDRESS+1;
		end

	always @( negedge CLK )
		begin
		HCLK2 = ~ HCLK2;
		end

	//////////////////////////////

	always @ (posedge phase_A )
		begin
		end
		
	//////////////////////////////

	always @ (posedge phase_B )
		begin
		regibuf <= regobuf;
		end

	//////////////////////////////

	always @( posedge phase_C )
		begin
		regobuf <= RegOutput; // buffer the output register
		end

	//////////////////////////////
	always @( posedge phase_D )
		begin
		end

	//////////////////////////////
	// Load/Store Regs
	//////////////////////////////

	assign RegLoadStoreTrigger = phase_B & (ecodeA==1) & (icodeA<2);
	assign RegrW = (icodeA==1);
	assign RegAddress = rcodeA[3:0];

	//////////////////////////////
	// instantiate units
	//////////////////////////////

	tweakdec	mydecoderA( phase_A, cur_opcode, ecodeA, icodeA, dcodeA, rcodeA );

	tweakregs	MyRegs( RegLoadStoreTrigger, RegrW, RegAddress, RegInput, RegOutput );

	tweakalu3	myalu(	phase_C, icodeA, 
						regibuf, regobuf, 
						alu_result );
						
	Memory 		MyMemory( CLK, ADDRESS, memdata );

	//////////////////////////////
	//
	//////////////////////////////

	assign op = alu_result[0];

endmodule

//////////////////////////////////////////////////////////////////

module testbench;

	///////////////////////////////

	reg CLK = 0;
	reg RESET = 1;
	wire opo;

	///////////////////////////////
	tweakpu tpu ( CLK, RESET, opo );
	///////////////////////////////

	integer i;

	initial begin
//	$hello("yo",1);
	$dumpfile("tweakpu.vcd");
	$dumpvars(0,testbench);
	#5 RESET = 0;
	for( i=0; i<100; i=i+1 )
		CLK = #2 ~CLK;	
	end


endmodule


/////////////////////////////////////////////////////////////////
