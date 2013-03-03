//////////////////////////////////////////////////////////////////
//
//
//////////////////////////////////////////////////////////////////

`timescale 1us/1us

//////////////////////////////////////////////////////////////////
// encoding format

// 24bit load immediate instruction  
//	   4 bits: encoding [0000]
//     4 bits: register
//    24 bits: data

// 3 operand instruction (2 in, 1 out) 
//	   4 bits: encoding [0001]
//     4 bits: alu ins
//    12 bits: registers
//    12 bits: xxx

//////////////////////////////////////////////////////////////////
// ROM
//////////////////////////////////////////////////////////////////

module tweak_rom( input read_ena,
				  input [3:0] addr_in,
				  output [31:0] data_out );
 
	parameter NUMWORDS = 16;
	parameter WORDSIZE = 32;
	
	reg [ WORDSIZE -1 : 0 ] InsMem[ 0: NUMWORDS-1 ];
	reg [ WORDSIZE -1 : 0 ] OutReg;
	
	initial begin
		OutReg = 0;
		InsMem[0] = { 4'h0, 4'h0, 24'h888888 }; // ldi #888888, r0
		InsMem[1] = { 4'h0, 4'h1, 24'h444444 }; // ldi #444444, r1
		InsMem[2] = { 4'h1, 4'h1, 24'h012000 }; // add r0, r1, r2
		InsMem[3] = { 4'h0, 4'h0, 24'h222222 }; // ldi #222222, r0
		InsMem[4] = { 4'h1, 4'h1, 24'h021000 }; // add r0, r2, r1
		InsMem[5] = { 4'h0, 4'h0, 24'h111111 }; // ldi #111111, r0
		InsMem[6] = { 4'h1, 4'h1, 24'h012000 }; // add r0, r1, r2
		InsMem[7] = { 4'h0, 4'h0, 24'h000001 }; // ldi #1, r0
		InsMem[8] = { 4'h1, 4'h7, 24'h201000 }; // asr r2,r0,r1
		InsMem[9] = { 4'h1, 4'h7, 24'h102000 }; // asr r1,r0,r2
		InsMem[10] = { 4'h1, 4'h7, 24'h201000 }; // asr r2,r0,r1
		InsMem[11] = { 4'h1, 4'h7, 24'h102000 }; // asr r1,r0,r2
		InsMem[12] = { 4'h1, 4'h6, 24'h201000 }; // asl r2,r0,r1
		InsMem[13] = { 4'h1, 4'h6, 24'h102000 }; // asl r1,r0,r2
		InsMem[14] = { 4'h1, 4'h6, 24'h201000 }; // asl r2,r0,r1
		InsMem[15] = { 4'h1, 4'h6, 24'h102000 }; // asl r1,r0,r2
	end

	always @( posedge read_ena )
		begin
		OutReg = InsMem[ addr_in[ 3:0 ] ];
		end

	assign data_out = OutReg;
	
 endmodule

//////////////////////////////////////////////////////////////////
// instruction decoder
//////////////////////////////////////////////////////////////////

module tweak_decoder(	input [31:0] OPCODE,		// incoming: composite instruction code
						output [3:0] encoding,		// outgoing: encoding format 
						output [3:0] alu_opcode,	// outgoing: decoded alu opcode
						output [23:0] immed_data );	// outgoing: immediate data
				 
	//////////////////////////////////////////
	// encodings
	//////////////////////////////////////////

	wire [23:0] data_24 = { OPCODE[23:0] };
	wire [23:0] data_20 = { OPCODE[19:0], 4'h0 };
	wire [23:0] data_16 = { OPCODE[23:8], 8'h00 };
	wire [23:0] data_12 = { OPCODE[23:12], 12'h000 };

	wire [3:0] format_code = OPCODE[31:28];

	//reg [23:0] data_out = { OPCODE[23:0] };

	//////////////////////////////////////////
//	always @*
//	begin
//	  case(format_code)
//	    4'h0: data_out = data_24;	// 0 operands
//	    4'h1: data_out = data_20;	// 1 operands
//	    4'h2: data_out = data_16;	// 2 operands
//	    4'h3: data_out = data_12;	// 3 operands
//	  endcase
//	end	
	//////////////////////////////////////////
	assign encoding[3:0] = OPCODE[31:28];		
	assign alu_opcode[3:0] = OPCODE[27:24];		
	assign immed_data[23:0] = OPCODE[23:0];		
	
endmodule
				 
//////////////////////////////////////////////////////////////////
// ALU
//////////////////////////////////////////////////////////////////

module tweak_alu(	input [3:0] alu_opcode, 
					input [31:0] arg_a, input [31:0] arg_b, 
					output [31:0] result );

	parameter [4:0]

		alucode_nop = 4'h0,
		alucode_add = 4'h1,
		alucode_sub = 4'h2,
		alucode_and = 4'h3,
		alucode_or =  4'h4,
		alucode_xor = 4'h5,
		alucode_asl = 4'h6,
		alucode_asr = 4'h7;
	
	wire [31:0] res_nop = 0;
	wire [31:0] res_add = (arg_a+arg_b);
	wire [31:0] res_sub = (arg_a-arg_b);
	wire [31:0] res_and = (arg_a&arg_b);
	wire [31:0] res_or  = (arg_a|arg_b);
	wire [31:0] res_xor = (arg_a^arg_b);
	wire [31:0] res_asl = (arg_a<<arg_b);
	wire [31:0] res_asr = (arg_a>>arg_b);

	assign result
		= (alu_opcode==alucode_nop) ? res_nop
		: (alu_opcode==alucode_add) ? res_add
		: (alu_opcode==alucode_sub) ? res_sub
		: (alu_opcode==alucode_and) ? res_and
		: (alu_opcode==alucode_xor) ? res_xor
		: (alu_opcode==alucode_or)  ? res_or
		: (alu_opcode==alucode_asl) ? res_asl
		: (alu_opcode==alucode_asr) ? res_asr
		: arg_a;
		
endmodule

//////////////////////////////////////////////////////////////////
// Registers
//////////////////////////////////////////////////////////////////

module tweak_registers( input clear_trigger,
						input l_trigger,
						input s_trigger,
						input [3:0] lu_addra,
						input [3:0] lu_addrb,
						input [3:0] su_addr,
						input [31:0] su_inp,
						output [31:0] lu_outpa,
						output [31:0] lu_outpb );

	reg [31:0] registers [0:15];
	reg [31:0] outbufa;
	reg [31:0] outbufb;
		
	always @( clear_trigger )
		begin
			registers[0] <= 0;
			registers[1] <= 0;
			registers[2] <= 0;
			registers[3] <= 0;
			registers[4] <= 0;
			registers[5] <= 0;
			registers[6] <= 0;
			registers[7] <= 0;
			registers[8] <= 0;
			registers[9] <= 0;
			registers[10] <= 0;
			registers[11] <= 0;
			registers[12] <= 0;
			registers[13] <= 0;
			registers[14] <= 0;
			registers[15] <= 0;
		end
	always @( posedge s_trigger )
		begin
			registers[su_addr] = su_inp; 
		end
	always @( posedge l_trigger )
		begin
		outbufa <= registers[lu_addra];		
		outbufb <= registers[lu_addrb];		
		end
	assign lu_outpa = outbufa;
	assign lu_outpb = outbufb;

endmodule
 
//////////////////////////////////////////////////////////////////

module tweak_cpu( input CLK,
				  input RESET );

	//////////////////////////////

	reg [31:0] composite_opcode;

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
	// register file
	//////////////////////////////

	wire reg_clear_trigger = ! RESET;


	wire [3:0]	reg_addrc;
	
	wire [31:0] reg_outpa;
	wire [31:0] reg_outpb;

	//////////////////////////////

	reg [3:0] rom_address;
	wire [31:0] rom_data;

	//////////////////////////////
	// decoder output
	//////////////////////////////

	wire [3:0] dec_encoding_fmt;
	wire [3:0] dec_alu_opcode;
	wire [23:0] dec_immed_data;
	wire [11:0] dec_register_code = dec_immed_data[23:12];

	//////////////////////////////
	// load unit
	//////////////////////////////

	wire lu_loadi = (dec_encoding_fmt==4'b0000);
	wire lu_loadr = (dec_encoding_fmt==4'b0001);

	wire [3:0] lu_addra = lu_loadr ? dec_register_code[11:8] 
								   : 0;
	wire [3:0] lu_addrb = lu_loadr ? dec_register_code[7:4]
								   : 0;

	wire [31:0] imm_data_32 = { 8'h00, dec_immed_data[23:0] };

	wire lur_trigger = phase_A&phase_B&lu_loadr;

	//////////////////////////////

	wire [31:0] alu_result;

	wire [31:0] alu_inppa = lu_loadi ? imm_data_32 : reg_outpa;
	wire [31:0] alu_inppb = lu_loadi ? imm_data_32 : reg_outpb;

	//////////////////////////////
	// store unit
	//////////////////////////////

	wire su_src_imm = (dec_encoding_fmt==4'b0000);
	wire [31:0] su_src = su_src_imm ? imm_data_32 : alu_result;
	wire [3:0] su_addr = lu_loadi ? dec_alu_opcode 
	                              : dec_register_code[3:0];
	wire sur_store = 1;
	wire sur_trigger = phase_C&phase_D&sur_store;

	//////////////////////////////
	// boot up
	//////////////////////////////

	initial begin
		phase_C_enable = 0;
		phase_D_enable = 0;
		rom_address = 4'h0;
		clk_h1 = 1;
		clk_h2 = 1;
		composite_opcode = 32'h00;
	end
	
	//////////////////////////////

	always @( posedge CLK )

		begin
		phase_C_enable <= 1;
		clk_h1 <= ~ clk_h1;
		end

	//////////////////////////////

	always @( negedge CLK )
		begin
		clk_h2 = ~ clk_h2;
		end

	//////////////////////////////
	// PhaseA (ins fetch)
	//////////////////////////////

	always @ (posedge phase_A )
		begin
		composite_opcode = rom_data; // sample ROM, write to composite_opcode
		end
		
	//////////////////////////////
	// PhaseB (load)
	//////////////////////////////


	//////////////////////////////
	// PhaseC 
	//////////////////////////////

	always @( posedge phase_C )
		begin
		phase_D_enable <= 1;
		end

	//////////////////////////////
	// PhaseD (store, IP address ca)
	//////////////////////////////

	always @( posedge phase_D )
		begin
		rom_address <= rom_address+1;
		end

	//////////////////////////////
	// instantiate units
	//////////////////////////////

	tweak_registers	the_regs( reg_clear_trigger,
							  lur_trigger,
							  sur_trigger,
							  lu_addra,
							  lu_addrb,
							  su_addr,
							  su_src,
							  reg_outpa,
							  reg_outpb );

	tweak_decoder	the_decoder( composite_opcode,
								 dec_encoding_fmt,
								 dec_alu_opcode,
								 dec_immed_data );

	tweak_alu		the_alu( dec_alu_opcode, 
							 alu_inppa, alu_inppb, 
							 alu_result );
						
	tweak_rom 		the_rom( CLK, rom_address, rom_data );

	//////////////////////////////
	//
	//////////////////////////////

endmodule

//////////////////////////////////////////////////////////////////
module testbench;
	reg CLK = 0;
	reg RESET = 1;
	///////////////////////////////
	tweak_cpu tpu ( CLK, RESET );
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
//////////////////////////////////////////////////////////////////
