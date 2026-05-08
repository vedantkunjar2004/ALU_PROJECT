`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.05.2026 23:41:39
// Design Name: 
// Module Name: alu_verification
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module alu #(parameter WIDTH=8)(
	CLK,RST,MODE,CIN,CE,OPA,OPB,INP_VALID,CMD,RES,ERR,G,L,E,COUT,OFLOW 
);
	input wire CLK,RST,MODE,CIN,CE;                    
	input wire [WIDTH-1:0] OPA,OPB;
	input wire [1:0] INP_VALID;
	input wire [3:0] CMD;
	output reg [2*WIDTH-1:0] RES;
	output reg ERR,G,L,E,COUT,OFLOW;
	reg [1:0] count;
	reg [WIDTH-1:0] temp_mul,tempA, tempB;
	wire [WIDTH-1:0] sum_w,diff_w;
	reg [WIDTH-1:0] OPA_w,OPB_w;


	assign sum_w=OPA_w+OPB_w;
	assign diff_w=OPA_w-OPB_w;	
	always @(posedge CLK) begin
		if (MODE == 1 && (CMD == 9 || CMD == 10)) begin
			if (count < 2) 
				count <= count + 1;
			else
				count <= 1;
		end
      	else
          		count<=0;
	end
	always @(posedge CLK or posedge RST) begin    //Asynchronous Active High RESET
		if(RST) begin
			RES<=0;
			COUT<=0;
			ERR<=0;
			G<=0;
			L<=0;
			E<=0;
			OFLOW<=0;
			count<=0;
            OPA_w<=0;
            OPB_w<=0;
		end
      	else begin
			if(CE) begin
                // Latch inputs regardless of MODE so both Logic and Arithmetic get them
                OPA_w<=OPA;
                OPB_w<=OPB;

				if(MODE) begin       //Mode - 1: Arithmetic Operation | Mode - 0: Logical Operation
					RES<=0;
                        		COUT<=0;
                        		ERR<=0;
                        		G<=0;
                        		L<=0;
                        		E<=0;
                        		OFLOW<=0;
					case (CMD)
						0: case( INP_VALID) // CMD - 0 : ADD
							3:begin     // Perform OPA_w+OPB_w only if INP_VALID = 3
								RES<= OPA_w+OPB_w;
								COUT<=(OPA_w + OPB_w) > ((1<<WIDTH)-1);
							end
							default: begin     // Else ERR=1 , RES = 0
								RES<=0;
								ERR<=1'b1;
							end                              
						endcase
						1: case( INP_VALID)  // CMD -1 : SUB
							3: begin  // Perform OPA_w-OPB_w only if INP_VALID = 3
								OFLOW<=(OPA_w<OPB_w)?1:0;
								RES<=OPA_w-OPB_w;
							end
							default: begin // Else ERR=1 , RES = 0
								RES<=0;
								ERR<=1'b1;
							end
						endcase
						2: case( INP_VALID)  // CMD - 2 : ADD_CIN
							3: begin
								RES<=OPA_w+OPB_w+CIN;
								COUT <= (OPA_w + OPB_w + CIN) > ((1<<WIDTH)-1);
							end
							default: begin
								RES<=0;
								ERR<=1'b1;
							end
						endcase
						3: case(INP_VALID)  // CMD - 3 : SUB_CIN
							3: begin
								OFLOW<=(OPA_w<(OPB_w+CIN))?1:0;
								RES<=OPA_w-OPB_w-CIN;
							end
							default: begin
								RES<=0;
								ERR<=1'b1;
							end
						endcase
						4: case (INP_VALID)  // CMD - 4 : INC_A 
							1: RES<=OPA_w+1;
							3: RES<=OPA_w+1;
							default: begin
								RES<=0;
								ERR<=1;
							end
						endcase
						5: case (INP_VALID)  // CMD - 5 : DEC_A 
							1: RES<=OPA_w-1;
							3: RES<=OPA_w-1;
							default: begin
								RES<=0;
								ERR<=1;
							end
						endcase              
						6: case(INP_VALID) // CMD - 6 : INC_B
							2: RES<=OPB_w+1;
							3: RES<=OPB_w+1;
							default: begin
								RES<=0;
								ERR<=1;
							end
						endcase
						7:case(INP_VALID) // CMD - 7 : DEC_B
							2: RES<=OPB_w-1;
							3: RES<=OPB_w-1;
							default: begin
								RES<=0;
								ERR<=1;
							end
						endcase
						8: case(INP_VALID) // CMD  - 8: CMP
							3: begin
								if(OPA_w==OPB_w) 
									{E,G,L}=3'b100;
								else if (OPA_w>OPB_w)
									{E,G,L}=3'b010;
								else 
									{E,G,L}=3'b001;
							end
							default: {E,G,L}=3'b000;
						endcase
						9: case (INP_VALID) //CMD - 9: MULTIPLICATION w INC_A and INC_B
			 				3: begin
								case(count)
									1: begin
										tempA<=OPA_w+1;
										tempB<=OPB_w+1;
                                      	RES <= {2*WIDTH{1'bx}};
									end
									2: begin
										RES<=tempA*tempB;
									end
									default: RES<=RES;
								endcase
							end
							default: begin
									RES<=0;
									ERR<=1;
							end
						endcase
						10: case (INP_VALID) //CMD - 10: MULTIPLICATION w SHIL_A
                                                        3: begin
                                                                case(count)
                                                                        1: begin
                                                                                tempA<=OPA_w<<1;
                                                                          		RES<='bx;
                                                                        end
                                                                        2: begin
                                                                                RES<=tempA*OPB_w;
                                                                        end
                                                                        default: RES<=RES;
                                                                endcase
							end
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						11: case(INP_VALID) // CMD - 11: SIGNED ADDITION
							3: begin
								RES<=$signed(OPA_w) + $signed(OPB_w);
								OFLOW<=(OPA_w[WIDTH-1] == OPB_w[WIDTH-1]) && (OPA_w[WIDTH-1] != sum_w[WIDTH-1]);
								G<=($signed(OPA_w)>$signed(OPB_w));
								L<=($signed(OPA_w)<$signed(OPB_w));
								E<=(OPA_w==OPB_w);		
							end
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						12: case(INP_VALID)	// CMD - 12: SIGNED SUBTRACTION
							3: begin
								RES<= OPA_w + ( ~OPB_w + 1);
								OFLOW<=(OPA_w[WIDTH-1] ^ OPB_w[WIDTH-1]) & (diff_w[WIDTH-1] ^ OPA_w[WIDTH-1]);
								G<=($signed(OPA_w)>$signed(OPB_w));
								L<=($signed(OPA_w)<$signed(OPB_w));
								E<=(OPA_w==OPB_w);		
							end
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						default:
							RES<=0;						
					endcase
                		end
				else begin  // MODE - 0
					RES<=0;
                        		COUT<=0;
                        		ERR<=0;
                        		G<=0;
                        		L<=0;
                        		E<=0;
                        		OFLOW<=0;
					case (CMD)
						0: case( INP_VALID) // CMD - 0 : BITWISE AND
							3: RES<= OPA_w & OPB_w;
							default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						1: case(INP_VALID) // CMD - 1 : BITWISE NAND
							3: RES<= ~(OPA_w & OPB_w);
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						2: case(INP_VALID) // CMD - 2 : BITWISE OR
                                                        3: RES<= OPA_w | OPB_w;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						3: case(INP_VALID) // CMD - 3 : BITWISE NOR
                                                        3: RES<= ~(OPA_w | OPB_w);
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						4: case(INP_VALID) // CMD - 4 : BITWISE XOR
                                                        3: RES<= OPA_w ^ OPB_w;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						5: case(INP_VALID) // CMD - 5 : BITWISE XNOR
                                                        3: RES<= ~(OPA_w ^ OPB_w);
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						6: case(INP_VALID) // CMD - 6 : NOT_A
							1: RES <= ~OPA_w;
							3: RES <= ~OPA_w;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						7: case(INP_VALID) // CMD - 7 : NOT_B
							2: RES <= ~OPB_w;
							3: RES <= ~OPB_w;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						8: case(INP_VALID) // CMD - 8 : SHR1_A
							1: RES[WIDTH-1:0] <= OPA_w>>1;
							3: RES[WIDTH-1:0] <= OPA_w>>1;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						9: case(INP_VALID) // CMD - 9 : SHL1_A
							1: RES [WIDTH-1:0] <= OPA_w<<1;
							3: RES [WIDTH-1:0]<= OPA_w<<1;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						10: case(INP_VALID) // CMD - 10 : SHR1_B
							2: RES[WIDTH-1:0] <= OPB_w>>1;
							3: RES[WIDTH-1:0] <= OPB_w>>1;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						11: case(INP_VALID) // CMD - 11 : SHL1_B
							2: RES [WIDTH-1:0] <= OPB_w<<1;
							3: RES [WIDTH-1:0]<= OPB_w<<1;
                                                        default: begin
                                                                        RES<=0;
                                                                        ERR<=1;
                                                        end
						endcase
						12: case(INP_VALID) // CMD - 12 : ROL_A_B
							3: begin
								if (|(OPB_w[(2*WIDTH)-1 : WIDTH])) begin
            								ERR <= 1'b1;
								end
								else begin
									ERR <= 1'b0;
									RES[WIDTH-1:0] <= (OPA_w << (OPB_w % WIDTH)) | (OPA_w >> (WIDTH - (OPB_w % WIDTH)));
								        RES[(2*WIDTH)-1 : WIDTH] <= 0;
								end
							end
							default: begin
								RES<=0;
								ERR<=1;
                                                        end
						endcase
						13: case(INP_VALID) // CMD - 13 : ROR_A_B
							3: begin
								if (|(OPB_w[(2*WIDTH)-1 : WIDTH])) begin
            								ERR <= 1'b1;
								end
								else begin
									ERR <= 1'b0;
									RES[WIDTH-1:0] <= (OPA_w >> (OPB_w % WIDTH)) | (OPA_w << (WIDTH - (OPB_w % WIDTH)));
								        RES[(2*WIDTH)-1 : WIDTH] <= 0;
								end
							end
							default: begin
								RES<=0;
								ERR<=1;
                                                        end
						endcase
						default: begin
							RES<=0;
							ERR<=1;
						end
					endcase
				end
			end
			else begin
				RES<=RES;
				ERR<=ERR;
				COUT<=COUT;
				G<=G;
				L<=L;
				E<=E;
				OFLOW<=OFLOW;
			end
        	end
	end
endmodule


