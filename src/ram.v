`timescale 1us/1us

module tweakram (
clk         , // Clock Input
address     , // Address Input
data        , // Data bi-directional
cs          , // Chip Select
we          , // Write Enable/Read Enable
oe            // Output Enable
); 

parameter DATA_WIDTH = 8 ;
parameter ADDR_WIDTH = 4 ;
parameter RAM_DEPTH = 1 << ADDR_WIDTH;

reg [0:4] i;
	
//--------------Input Ports----------------------- 
input                                     clk          ;
input [ADDR_WIDTH-1:0] address ;
input                                     cs           ;
input                                     we          ;
input                                     oe           ; 

//--------------Inout Ports----------------------- 
inout [DATA_WIDTH-1:0]  data       ;

//--------------Internal variables---------------- 
reg [DATA_WIDTH-1:0]   data_out = 8'hff;
reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];

//--------------Code Starts Here------------------ 

// Tri-State Buffer control 
// output : When we = 0, oe = 1, cs = 1
assign data = (cs && oe && !we) ? data_out : 8'bz; 

// Memory Write Block 
// Write Operation : When we = 1, cs = 1
always @ (posedge clk)
begin : MEM_WRITE
   if ( cs && we ) begin
       mem[address] = data;
   end
end

// Memory Read Block 
// Read Operation : When we = 0, oe = 1, cs = 1
always @ (posedge clk)
begin : MEM_READ
    if (cs && !we && oe) begin
         data_out = mem[address];
    end
end

initial
	begin
		for( i=0; i<RAM_DEPTH; i=i+1 )
			begin
				mem[i] = 0;
			end
		mem[1] = 8'h10;
		mem[2] = 8'h01;
		mem[3] = 8'h11;
		mem[4] = 8'h02;
		mem[5] = 8'h40;
		mem[6] = 8'h22;
		mem[7] = 8'h08;
		
		//mem[7] = 2;
	end
	
endmodule // End of Module ram_sp_sr_sw

