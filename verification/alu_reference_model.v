module alu_reference_model(
    input [7:0] OPA, OPB,
    input CIN, MODE, CE,
    input [3:0] CMD,
    input [1:0]INP_VALID,
    output reg [15:0] RES,
    output reg COUT, OFLOW, G, E, L, ERR
);

    reg [7:0] OPA_1, OPB_1;

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
                    RES = OPA + OPB;
                    COUT = RES[8];
                end
                4'b0001: begin  // SUB
                    OFLOW = (OPA < OPB);
                    RES = OPA - OPB;
                end
                4'b0010: begin  // ADD_CIN
                    RES = OPA + OPB + CIN;
                    COUT = RES[8];
                end
                4'b0011: begin  // SUB_CIN
                    OFLOW = (OPA < (OPB+CIN));
                    RES = OPA - OPB - CIN;
                end
                4'b0100: RES = OPA + 1;  // INC_A
                4'b0101: RES = OPA - 1;  // DEC_A
                4'b0110: RES = OPB + 1;  // INC_B
                4'b0111: RES = OPB - 1;  // DEC_B
                4'b1000: begin  // CMP
                    RES = 9'bz;
                    if (OPA == OPB) begin
                        E = 1'b1; G = 1'b0; L = 1'b0;
                    end else if (OPA > OPB) begin
                        E = 1'b0; G = 1'b1; L = 1'b0;
                    end else begin
                        E = 1'b0; G = 1'b0; L = 1'b1;
                    end
                end 
            endcase
        end 
        else begin  // Logical Mode
            case(CMD)
                4'b0000: RES = {8'b0, OPA & OPB};       // AND
                4'b0001: RES = {8'b0, ~(OPA & OPB)};    // NAND
                4'b0010: RES = {8'b0, OPA | OPB};       // OR
                4'b0011: RES = {8'b0, ~(OPA | OPB)};    // NOR
                4'b0100: RES = {8'b0, OPA ^ OPB};       // XOR
                4'b0101: RES = {8'b0, ~(OPA ^ OPB)};    // XNOR
                4'b0110: RES = {8'b0, ~OPA};            // NOT_A
                4'b0111: RES = {8'b0, ~OPB};            // NOT_B
                4'b1000: RES = {8'b0, OPA >> 1};        // SHR1_A
                4'b1001: RES = {8'b0, OPA << 1};        // SHL1_A
                4'b1010: RES = {8'b0, OPB >> 1};        // SHR1_B
                4'b1011: RES = {8'b0, OPB << 1};        // SHL1_B
                4'b1100: begin  // ROL_A_B
                    OPA_1 = OPB[0] ? {OPA[6:0], OPA[7]} : OPA;
                    OPB_1 = OPB[1] ? {OPA_1[5:0], OPA_1[7:6]} : OPA_1;
                    RES = OPB[2] ? {OPB_1[3:0], OPB_1[7:4]} : OPB_1;
                    ERR = (OPB[4] | OPB[5] | OPB[6] | OPB[7]);
                end
                4'b1101: begin  // ROR_A_B
                    OPA_1 = OPB[0] ? {OPA[0], OPA[7:1]} : OPA;
                    OPB_1 = OPB[1] ? {OPA_1[1:0], OPA_1[7:2]} : OPA_1;
                    RES = OPB[2] ? {OPB_1[3:0], OPB_1[7:4]} : OPB_1;
                    ERR = (OPB[4] | OPB[5] | OPB[6] | OPB[7]);
                end
            endcase
        end
    end

endmodule
