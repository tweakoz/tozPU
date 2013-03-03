//////////////////////////////////////////////////////////////////
//
//
//////////////////////////////////////////////////////////////////

`timescale 1us/1us

//////////////////////////////////////////////////////////////////
// encoding format

// 0 operand instruction  
//	   2 bits: encoding [00]
//     2 bits: lsu ins
//     4 bits: alu ins
//    24 bits: data

// 1 operand instruction (1 in or 1 out) 
//	   2 bits: encoding [01]
//     2 bits: lsu ins
//     4 bits: alu ins
//     4 bits: registers
//    20 bits: data

// 2 operand instruction (1 in, 1 out) 
//	   2 bits: encoding [10]
//     2 bits: lsu ins
//     4 bits: alu ins
//     8 bits: registers
//    16 bits: data

// 3 operand instruction (2 in, 1 out)
//	   2 bits: encoding [11]
//     2 bits: lsu ins
//     4 bits: alu ins
//    12 bits: registers
//    12 bits: data

//////////////////////////////////////////////////////////////////
// ROM
//////////////////////////////////////////////////////////////////

module tweak_rom( input read_ena,
				  input [3:0] addr_in,
				  output [31:0] data_out );
 
	parameter NUMWORDS = 8;
	parameter WORDSIZE = 32;
	
	reg [ WORDSIZE -1 : 0 ] InsMem[ 0: NUMWORDS-1 ];
	reg [ WORDSIZE -1 : 0 ] OutReg;
	
	initial begin
		OutReg = 0;
		InsMem[0] = { 2'b00, 2'b01, 4'h0, 24'hffffff };
		InsMem[1] = { 2'b00, 2'b00, 4'h0, 24'hffffff };
		InsMem[2] = { 2'b00, 2'b00, 4'h0, 24'hffffff };
		InsMem[3] = { 2'b00, 2'b00, 4'h0, 24'hffffff };
		InsMem[4] = { 2'b00, 2'b00, 4'h0, 24'hffffff };
		InsMem[5] = { 2'b00, 2'b00, 4'h0, 24'hffffff };
		InsMem[6] = { 2'b00, 2'b00, 4'h0, 24'hffffff };
		InsMem[7] = { 2'b00, 2'b00, 4'h0, 24'hffffff };
	end

	always @( posedge read_ena )
		begin
		OutReg = InsMem[ addr_in[ 2:0 ] ];
		end

	assign data_out = OutReg;
	
 endmodule

//////////////////////////////////////////////////////////////////
// instruction decoder
//////////////////////////////////////////////////////////////////

module tweak_decoder(	input [31:0] OPCODE,		// incoming: composite instruction code
						output [1:0] encoding,		// outgoing: encoding format 
						output [3:0] alu_opcode,	// outgoing: decoded alu opcode
						output [1:0] lsu_opcode,	// outgoing: decoded lsu opcode
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

	wire [1:0] format_code = OPCODE[31:30];
	wire [5:0] instr_code = OPCODE[29:24];

	reg [23:0] data_out;
	reg [11:0] regs_out;

	//////////////////////////////////////////
	always @*
	begin
	  case(format_code)
	    2'b00: data_out = data_24;	// 0 operands
	    2'b01: data_out = data_20;	// 1 operands
	    2'b10: data_out = data_16;	// 2 operands
	    2'b11: data_out = data_12;	// 3 operands
	  endcase
	end
	//////////////////////////////////////////
	always @*
	begin
	  case(format_code)
	    2'b00: regs_out = regs_0;
	    2'b01: regs_out = regs_4;
	    2'b10: regs_out = regs_8;
	    2'b11: regs_out = regs_12;
	  endcase
	end
	
	//////////////////////////////////////////
	
	assign encoding[1:0] = format_code[1:0];		
	assign alu_opcode[3:0] = instr_code[3:0];		
	assign lsu_opcode[1:0] = instr_code[5:4];		
	assign immed_data[23:0] = data_out[23:0];		
	assign reg_code[11:0] = regs_out[11:0];		
	
endmodule
				 
//////////////////////////////////////////////////////////////////
// ALU
//////////////////////////////////////////////////////////////////

module tweak_alu(	input [3:0] alu_opcode, 
					input [31:0] arg_a, input [31:0] arg_b, 
					output [31:0] result );

	parameter [4:0]

		alucode_add = 4'h0,
		alucode_sub = 4'h1,
		alucode_and = 4'h2,
		alucode_or =  4'h3,
		alucode_xor = 4'h4,
		alucode_asl = 4'h5,
		alucode_asr = 4'h6;
	
	wire [31:0] res_add = (arg_a+arg_b);
	wire [31:0] res_sub = (arg_a-arg_b);
	wire [31:0] res_and = (arg_a&arg_b);
	wire [31:0] res_or  = (arg_a|arg_b);
	wire [31:0] res_xor = (arg_a^arg_b);
	wire [31:0] res_asl = (arg_a<<arg_b);
	wire [31:0] res_asr = (arg_a>>arg_b);

	assign result
		= (alu_opcode==alucode_add) ? res_add
		: (alu_opcode==alucode_sub) ? res_sub
		: (alu_opcode==alucode_and) ? res_and
		: (alu_opcode==alucode_xor) ? res_xor
		: (alu_opcode==alucode_or)  ? res_or
		: (alu_opcode==alucode_asl) ? res_asl
		: (alu_opcode==alucode_asr) ? res_asr
		: arg_a;
		
endmodule

//////////////////////////////////////////////////////////////////
// LSU
//////////////////////////////////////////////////////////////////

module tweak_lsu( input [1:0] lsu_opcode, 
				  output load,
				  output store );

	assign load = (lsu_opcode==2'b01);
	assign store = (lsu_opcode==2'b10);

endmodule

//////////////////////////////////////////////////////////////////
// Registers
//////////////////////////////////////////////////////////////////

module tweak_registers( input clear_trigger,
						input l_trigger,
						input s_trigger,
						input [3:0] addra,
						input [3:0] addrb,
						input [31:0] inp,
						output [31:0] outpa,
						output [31:0] outpb );

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
			registers[addra] = inp; 
		end
	always @( posedge l_trigger )
		begin
		outbufa <= registers[addra];		
		outbufb <= registers[addrb];		
		end
	assign outpa = outbufa;
	assign outpb = outbufb;

endmodule
 
//////////////////////////////////////////////////////////////////

module tweak_cpu( input CLK,
				  input RESET,
				  output op );

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

	wire 		reg_clear_trigger;
	wire 		reg_l_trigger;
	wire 		reg_s_trigger;
	reg [31:0]  reg_input;

	wire [3:0]	reg_addra;
	wire [3:0]	reg_addrb;
	wire [31:0] reg_outpa;
	wire [31:0] reg_outpb;
	
	//////////////////////////////

	reg [3:0] rom_address;
	wire [31:0] rom_data;

	//////////////////////////////

	wire [31:0] alu_result;
	reg [31:0] alu_result_buf;

	wire lsu_load;
	wire lsu_store;

	//////////////////////////////
	// decoder output
	//////////////////////////////

	wire [1:0] dec_encoding_fmt;
	wire [3:0] dec_alu_opcode;
	wire [1:0] dec_lsu_opcode;
	wire [23:0] dec_immed_data;
	wire [11:0] dec_register_code;


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

	assign reg_clear_trigger = ! RESET;
	assign reg_addra[3:0] = dec_register_code[3:0];
	assign reg_addrb[3:0] = dec_register_code[7:4];
	assign reg_l_trigger = phase_A&phase_B&lsu_load;

	//////////////////////////////
	// PhaseC 
	//////////////////////////////

	always @( posedge phase_C )
		begin
		phase_D_enable <= 1;
		alu_result_buf <= alu_result;
		reg_input <= alu_result;
		end

	//////////////////////////////
	// PhaseD (store, IP address ca)
	//////////////////////////////

	assign reg_s_trigger = phase_C&phase_D&lsu_store;
	
	always @( posedge phase_D )
		begin
		rom_address <= rom_address+1;
		end

	//////////////////////////////
	// Load/Store Regs
	//  todo : replace with load store controller
	//////////////////////////////

	assign reg_address = dec_register_code[3:0];

	//////////////////////////////
	// instantiate units
	//////////////////////////////

	tweak_registers	the_regs( reg_clear_trigger,
							  reg_l_trigger,
							  reg_s_trigger,
							  reg_addra,
							  reg_addrb,
							  reg_input,
							  reg_outpa,
							  reg_outpb );

	tweak_decoder	the_decoder( composite_opcode,
								 dec_encoding_fmt,
								 dec_alu_opcode,
								 dec_lsu_opcode,
								 dec_immed_data,
								 dec_register_code );

	tweak_lsu       the_lsu( dec_lsu_opcode, lsu_load, lsu_store );

	tweak_alu		the_alu( dec_alu_opcode, 
							 reg_outpa, reg_outpb, 
							 alu_result );
						
	tweak_rom 		the_rom( CLK, rom_address, rom_data );

	//////////////////////////////
	//
	//////////////////////////////

	assign op = alu_result[0];

endmodule

//////////////////////////////////////////////////////////////////
module testbench;
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
//////////////////////////////////////////////////////////////////
