//////////////////////////////////////////////////////////////////
//
//
//////////////////////////////////////////////////////////////////

`timescale 1us/1us

//////////////////////////////////////////////////////////////////
// encoding format

// 0 operand instruction  
// 0x0xxx .. 0x3xxx
//	   2 bits: encoding [00]
//     6 bits: instruction
//    24 bits: data

// 1 operand instruction (1 in or 1 out) 
// 0x4xxx .. 0x7xxx
//	   2 bits: encoding [01]
//     6 bits: instruction
//     4 bits: registers
//    20 bits: data

// 2 operand instruction (1 in, 1 out) 
// 0x8xxx .. 0xbxxx
//	   2 bits: encoding [10]
//     6 bits: instruction
//     8 bits: registers
//    16 bits: data

// 3 operand instruction (2 in, 1 out)
// 0xcxxx .. 0xfxxx
//	   2 bits: encoding [11]
//     6 bits: instruction
//    12 bits: registers
//    12 bits: data




//////////////////////////////////////////////////////////////////
// instruction decoder
//////////////////////////////////////////////////////////////////

module tweak_decoder(	input [31:0] OPCODE,		// incoming: composite instruction code
						output [1:0] encoding,		// outgoing: encoding format 
						output [5:0] alu_opcode,	// outgoing: decoded alu opcode
						output [23:0] immed_data,	// outgoing: immediate data
						output [11:0] reg_code );	// outgoing: register data
				 
	//////////////////////////////////////////
	// encodings
	//////////////////////////////////////////

	wire [11:0] regs_0 = { 12'b0 };
	wire [11:0] regs_4 = { OPCODE[23:20], 8'h00 };
	wire [11:0] regs_8 = { OPCODE[7:0], 4'h0 };
	wire [11:0] regs_12 = { OPCODE[11:0] };

	wire [23:0] data_24 = { OPCODE[23:0] };
	wire [23:0] data_20 = { OPCODE[19:0], 4'h0 };
	wire [23:0] data_16 = { OPCODE[23:8], 8'h00 };
	wire [23:0] data_12 = { OPCODE[23:12], 12'h000 };

	wire [1:0] iecode = OPCODE[31:30];
	wire [5:0] iicode = OPCODE[29:24];

	reg [23:0] data_out;
	reg [11:0] regs_out;

	//////////////////////////////////////////
	always @*
	begin
	  case(iecode)
	    2'b00: data_out = data_24;	// 0 operands
	    2'b01: data_out = data_20;	// 1 operands
	    2'b10: data_out = data_16;	// 2 operands
	    2'b11: data_out = data_12;	// 3 operands
	  endcase
	end
	//////////////////////////////////////////
	always @*
	begin
	  case(iecode)
	    2'b00: regs_out = regs_0;
	    2'b01: regs_out = regs_4;
	    2'b10: regs_out = regs_8;
	    2'b11: regs_out = regs_12;
	  endcase
	end
	
	//////////////////////////////////////////
	
	assign encoding[1:0] = iecode[1:0];		
	assign alu_opcode[5:0] = iicode[5:0];		
	assign immed_data[23:0] = data_out[23:0];		
	assign reg_code[11:0] = regs_out[11:0];		
	
endmodule
				 
//////////////////////////////////////////////////////////////////
// ALU
//////////////////////////////////////////////////////////////////

module tweak_alu(	input AluTrigger, input [5:0] alu_opcode, 
					input [31:0] arg_a, input [31:0] arg_b, 
					output [31:0] result );

	parameter [4:0]

		alucode_add = 6'b000000,
		alucode_sub = 6'b000001,

		alucode_and = 6'b000010,
		alucode_or =  6'b000011,
		alucode_xor = 6'b000100;

	reg [31:0] res = 0;
	
	wire [31:0] res_add = (arg_a+arg_b);
	wire [31:0] res_sub = (arg_a-arg_b);
	wire [31:0] res_and = (arg_a&arg_b);
	wire [31:0] res_or = (arg_a|arg_b);
	wire [31:0] res_xor = (arg_a^arg_b);

	always @( posedge AluTrigger )
	begin
		case( alu_opcode )
			alucode_add :	begin		res<=res_add;		end
			alucode_sub :	begin		res<=res_sub;		end
			alucode_and :	begin		res<=res_and;		end
			alucode_or  :	begin		res<=res_or;		end
			alucode_xor :	begin		res<=res_xor;		end
			default :		begin		res<=arg_a;			end
		endcase
	end
	
	assign result = res;
	
endmodule

//////////////////////////////////////////////////////////////////
// Register Load Store Controller
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
// Registers
//////////////////////////////////////////////////////////////////

module tweak_registers( input ls_trigger, input rW, input [3:0] address, input [31:0] inp, output [31:0] outp );

	reg [31:0] registers [0:15];
	reg [31:0] outputbuffer;
	
	wire LoadTrigger = ls_trigger&(!rW);
	wire StoreTrigger = ls_trigger&rW;
	
	always @( posedge StoreTrigger )
		begin
			registers[address] = inp; 
		end
	always @( posedge LoadTrigger )
		begin
			outputbuffer = registers[address]; 
		end
		
	assign outp = outputbuffer;

endmodule

//////////////////////////////////////////////////////////////////
// ROM
//////////////////////////////////////////////////////////////////

module tweak_rom( input read_ena, input [3:0] addr_in, output [31:0] data_out );
 
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

	always @( posedge read_ena )
		begin
		OutReg = InsMem[ addr_in[ 2:0 ] ];
		end

	assign data_out = OutReg;
	
 endmodule
 
 //////////////////////////////////////////////////////////////////

module tweak_cpu (input CLK, input RESET, output op );

	//////////////////////////////

	reg [3:0] ADDRESS;
	reg [31:0] composite_opcode;
	reg [31:0] regobuf;
	reg [31:0] regibuf;

	//////////////////////////////
	// sub clocks
	//////////////////////////////

	wire NRES = ! RESET;
	wire NCLK = ! CLK;
	reg clk_h1;
	reg clk_h2;
	wire clk_h3 = ! clk_h1;
	wire clk_h4 = ! clk_h2;

	//////////////////////////////
	// phases
	//////////////////////////////

	reg phase_C_enable, phase_D_enable;
	wire phase_A = clk_h3&NRES;
	wire phase_B = clk_h2&NRES;
	wire phase_C = clk_h1&phase_C_enable;
	wire phase_D = clk_h4&phase_D_enable;

	//////////////////////////////
	// registers
	//////////////////////////////

	wire 		reg_ls_trigger;
	wire [3:0]	reg_address;
	wire 		reg_l_or_s;
	wire [31:0] reg_input;
	wire [31:0] reg_output;
	
	//////////////////////////////

	wire [31:0] rom_data;
	wire [31:0] alu_result;

	//////////////////////////////
	// decoder output
	//////////////////////////////

	wire [1:0] dec_encoding_fmt;
	wire [5:0] dec_alu_opcode;
	wire [23:0] dec_immed_data;
	wire [11:0] dec_register_code;

	//////////////////////////////
	// boot up
	//////////////////////////////

	initial begin
		phase_C_enable = 0;
		phase_D_enable = 0;
		ADDRESS = 4'h0;
		clk_h1 = 1;
		clk_h2 = 1;
		composite_opcode = 32'h00;
	end
	
	//////////////////////////////

	always @( posedge CLK )

		begin
		phase_C_enable <= 1;
		clk_h1 <= ~ clk_h1;
		ADDRESS <= RESET ? 0 : ADDRESS+1;
		end

	//////////////////////////////

	always @( negedge CLK )
		begin
		composite_opcode = rom_data; // sample ROM, write to composite_opcode
		end

	//////////////////////////////

	always @( negedge CLK )
		begin
		clk_h2 = ~ clk_h2;
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
		regobuf <= reg_output; // buffer the output register
		phase_D_enable <= 1;
		end

	//////////////////////////////
	
	always @( posedge phase_C )
		begin
		end

	//////////////////////////////

	always @( posedge phase_D )
		begin
		end

	//////////////////////////////
	// Load/Store Regs
	//  todo : replace with load store controller
	//////////////////////////////

	assign reg_ls_trigger = phase_B & (dec_encoding_fmt==1) & (dec_alu_opcode<2);
	assign reg_l_or_s = (dec_encoding_fmt==1);
	assign reg_address = dec_register_code[3:0];

	//////////////////////////////
	// instantiate units
	//////////////////////////////

	tweak_decoder	the_decoder( composite_opcode, dec_encoding_fmt, dec_alu_opcode, dec_immed_data, dec_register_code );

	tweak_registers	the_regs( reg_ls_trigger, reg_l_or_s, reg_address, reg_input, reg_output );

	tweak_alu		the_alu(	phase_C, dec_alu_opcode, 
								regibuf, regobuf, 
								alu_result );
						
	tweak_rom 		the_rom( CLK, ADDRESS, rom_data );

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
	tweak_cpu tpu ( CLK, RESET, opo );
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
