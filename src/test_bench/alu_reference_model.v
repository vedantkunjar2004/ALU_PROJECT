`timescale 1ns / 1ps
`default_nettype none
module alu_reference_model(
    input wire [7:0] OPA, OPB,
    input wire CIN, MODE, CE,
    input wire [3:0] CMD,
    input wire [1:0]INP_VALID,
    output reg [15:0] RES,
    output reg COUT, OFLOW, G, E, L, ERR
);

    reg [7:0] OPA_1, OPB_1;
    wire signed [7:0]sa = OPA;
    wire signed [7:0]sb = OPB;
    
     
    always @(*) begin
        // Default values
        RES = 16'b0;
        COUT = 1'b0;
        OFLOW = 1'b0;
        G = 1'b0;
        E = 1'b0;
        L = 1'b0;
        ERR = 1'b0;

        if (MODE) begin  // Arithmetic Mode
            case(CMD)
                4'b0000: begin  // ADD
                    if(INP_VALID==2'b11) begin
                    RES = OPA + OPB;
                    COUT = RES[8];
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                end
                4'b0001: begin  // SUB
                    if(INP_VALID==2'b11) begin
                    OFLOW = (OPA < OPB);
                    RES = OPA - OPB;
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                end
                4'b0010: begin  // ADD_CIN
                    if(INP_VALID==2'b11) begin
                    RES = OPA + OPB + CIN;
                    COUT = RES[8];
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                end
                4'b0011: begin  // SUB_CIN
                    if(INP_VALID==2'b11) begin
                    OFLOW = (OPA < (OPB+CIN));
                    RES = OPA - OPB - CIN;
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                end
                4'b0100: begin   // INC_A
                    if((INP_VALID==2'b11) || (INP_VALID==2'b01)) begin
                    RES = OPA + 1;  
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                    end
                4'b0101: begin   // DEC_A
                    if((INP_VALID==2'b11) || (INP_VALID==2'b01)) begin
                    RES = OPA - 1;  
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                    end
                4'b0110: begin   // INC_B
                    if((INP_VALID==2'b11) || (INP_VALID==2'b10)) begin
                    RES = OPB + 1;  
                    end
                else begin
                    RES=0; ERR=1;
                    end
                    end
                4'b0111:  begin  // DEC_B
                    if((INP_VALID==2'b11) || (INP_VALID==2'b10)) begin
                    RES = OPB - 1;  
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                    end
                4'b1000: begin  // CMP
                    if(INP_VALID==2'b11) begin
                    RES = 9'bz;
                        if (OPA == OPB) begin
                        E = 1'b1; G = 1'b0; L = 1'b0;
                        end else if (OPA > OPB) begin
                        E = 1'b0; G = 1'b1; L = 1'b0;
                        end else begin
                        E = 1'b0; G = 1'b0; L = 1'b1;
                        end
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                end
                4'b1001: begin
                    if(INP_VALID==11) begin
                    RES= (OPA + 1) * (OPB + 1);
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                    end
                4'b1010: begin
                    if(INP_VALID==11) begin
                    RES= (OPA << 1) * OPB;
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                    end
                4'b1011: begin
                     if(INP_VALID==11) begin
                     RES = sa + sb;
                     OFLOW = (sa[7]==sb[7]) && (sa[7]!=RES[7]);
                     end                 
                    else begin
                    RES=0; ERR=1;
                    end
                    end
                4'b1100: begin
                    if(INP_VALID==11) begin
                    RES= sa-sb;
                     OFLOW = (sa[7]!=sb[7]) && (sa[7]!=RES[7]);
                     end
                     else begin
                    RES=0; ERR=1;
                    end
                    end
            endcase
        end
        else begin  // Logical Mode
            case(CMD)
                4'b0000: begin if(INP_VALID==2'b11) begin RES = {8'b0, OPA & OPB}; end else begin RES=0; ERR=1; end end      // AND
                4'b0001: begin if(INP_VALID==2'b11) begin RES = {8'b0, ~(OPA & OPB)}; end else begin RES=0; ERR=1; end end    // NAND
                4'b0010: begin if(INP_VALID==2'b11) begin RES = {8'b0, OPA | OPB}; end else begin RES=0; ERR=1; end end       // OR
                4'b0011: begin if(INP_VALID==2'b11) begin RES = {8'b0, ~(OPA | OPB)}; end else begin RES=0; ERR=1; end end    // NOR
                4'b0100: begin if(INP_VALID==2'b11) begin RES = {8'b0, OPA ^ OPB}; end else begin RES=0; ERR=1; end end       // XOR
                4'b0101: begin if(INP_VALID==2'b11) begin RES = {8'b0, ~(OPA ^ OPB)}; end else begin RES=0; ERR=1; end end    // XNOR
                4'b0110: begin if((INP_VALID==2'b11) || (INP_VALID==01)) begin RES = {8'b0, ~OPA}; end else begin RES=0; ERR=1; end end            // NOT_A
                4'b0111: begin if((INP_VALID==2'b11) || (INP_VALID==10)) begin RES = {8'b0, ~OPB}; end else begin RES=0; ERR=1; end end            // NOT_B
                4'b1000: begin if((INP_VALID==2'b11) || (INP_VALID==01)) begin RES = {8'b0, OPA>>1}; end else begin RES=0; ERR=1; end end       // SHR1_A
                4'b1001: begin if((INP_VALID==2'b11) || (INP_VALID==01)) begin RES = {8'b0, OPA<<1}; end else begin RES=0; ERR=1; end end        // SHL1_A
                4'b1010: begin if((INP_VALID==2'b11) || (INP_VALID==10)) begin RES = {8'b0, OPB>>1}; end else begin RES=0; ERR=1; end end        // SHR1_B
                4'b1011: begin if((INP_VALID==2'b11) || (INP_VALID==10)) begin RES = {8'b0, OPB<<1}; end else begin RES=0; ERR=1; end end        // SHL1_B
                4'b1100: begin  // ROL_A_B
                    if(INP_VALID==2'b11) begin
                    OPA_1 = OPB[0] ? {OPA[6:0], OPA[7]} : OPA;
                    OPB_1 = OPB[1] ? {OPA_1[5:0], OPA_1[7:6]} : OPA_1;
                    RES = OPB[2] ? {OPB_1[3:0], OPB_1[7:4]} : OPB_1;
                    ERR = (OPB[4] | OPB[5] | OPB[6] | OPB[7]);
                    end
                    else begin
                    RES=0; ERR=1;
                    end
                end
                4'b1101: begin  // ROR_A_B
                    if(INP_VALID==2'b11) begin
                    OPA_1 = OPB[0] ? {OPA[0], OPA[7:1]} : OPA;
                    OPB_1 = OPB[1] ? {OPA_1[1:0], OPA_1[7:2]} : OPA_1;
                    RES = OPB[2] ? {OPB_1[3:0], OPB_1[7:4]} : OPB_1;
                    ERR = (OPB[4] | OPB[5] | OPB[6] | OPB[7]);
                    end
                 else begin
                    RES=0; ERR=1;
                    end
                end
            endcase
        end
    end

endmodule

