`timescale 1ns / 1ps

`default_nettype none

module alu_design #( parameter DATA_WIDTH = 8, parameter RES_WIDTH  = 2 * DATA_WIDTH)(
    input wire clk,
    input wire rst,
    input wire ce,
    input wire c_in,
    input wire mode,
    input wire [DATA_WIDTH-1:0]op_a,
    input wire [DATA_WIDTH-1:0]op_b,
    input wire [1:0]inp_valid,
    input wire [3:0]cmd,
    output reg [RES_WIDTH-1:0]result,
    output reg err,
    output reg G,
    output reg L,
    output reg E,
    output reg c_out,
    output reg overflow
);

    reg [1:0]count;
    reg [1:0]count2;
    reg [DATA_WIDTH-1:0]temp1, temp2, temp3;

    wire [DATA_WIDTH:0]uadd_result = {1'b0, op_a} + {1'b0, op_b};
    wire [DATA_WIDTH:0]uadd_cin_result = {1'b0, op_a} + {1'b0, op_b} + {{DATA_WIDTH{1'b0}}, c_in};

    wire signed [DATA_WIDTH-1:0]s_a = op_a;
    wire signed [DATA_WIDTH-1:0]s_b = op_b;

    wire signed [DATA_WIDTH:0]sadd_result = s_a + s_b;
    wire signed [DATA_WIDTH:0]ssub_result = s_a - s_b;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= {RES_WIDTH{1'b0}};
            G <= 1'b0;
            L <= 1'b0;
            E <= 1'b0;
            err <= 1'b0;
            c_out <= 1'b0;
            overflow <= 1'b0;
            count <= 2'd0;
            count2 <= 2'd0;
            temp1 <= {DATA_WIDTH{1'b0}};
            temp2 <= {DATA_WIDTH{1'b0}};
        end
        else if (ce) begin
            err <= 1'b0;
            c_out <= 1'b0;
            overflow <= 1'b0;
            G <= 1'b0;
            L <= 1'b0;
            E <= 1'b0;

            if (!mode) begin
                count <= 2'd0;

                case (cmd)
                    4'd0: begin                                                         // AND
                        if (inp_valid == 2'b11) result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}},  op_a & op_b};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd1: begin                                                         // NAND
                        if (inp_valid == 2'b11) result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, ~(op_a & op_b)};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd2: begin                                                         // OR
                        if (inp_valid == 2'b11) result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}},  op_a | op_b};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd3: begin                                                         // NOR
                        if (inp_valid == 2'b11) result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, ~(op_a | op_b)};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd4: begin                                                         // XOR
                        if (inp_valid == 2'b11) result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}},  op_a ^ op_b};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd5: begin                                                         // XNOR
                        if (inp_valid == 2'b11) result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, ~(op_a ^ op_b)};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd6: begin                                                         // NOT A
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b01))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, ~op_a};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd7: begin                                                         // NOT B
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b10))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, ~op_b};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd8: begin                                                         // SHR A by 1
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b01))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a >> 1};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd9: begin                                                         // SHL A by 1
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b01))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a << 1};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd10: begin                                                        // SHR B by 1
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b10))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_b >> 1};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd11: begin                                                        // SHL B by 1
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b10))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_b << 1};
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd12: begin
                        if (inp_valid == 2'b11) begin                                   //ROTATE LEFT
                            
                            err <= |op_b[7:3];
                            case (op_b[2:0])
                                3'd0: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a};
                                3'd1: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[6:0], op_a[7]};
                                3'd2: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[5:0], op_a[7:6]};
                                3'd3: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[4:0], op_a[7:5]};
                                3'd4: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[3:0], op_a[7:4]};
                                3'd5: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[2:0], op_a[7:3]};
                                3'd6: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[1:0], op_a[7:2]};
                                3'd7: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[0],   op_a[7:1]};
                            endcase
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd13: begin
                        if (inp_valid == 2'b11) begin                                   //ROTATE RIGHT
                            
                            err <= |op_b[7:3];
                            case (op_b[2:0])
                                3'd0: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a};
                                3'd1: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[0],   op_a[7:1]};
                                3'd2: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[1:0], op_a[7:2]};
                                3'd3: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[2:0], op_a[7:3]};
                                3'd4: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[3:0], op_a[7:4]};
                                3'd5: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[4:0], op_a[7:5]};
                                3'd6: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[5:0], op_a[7:6]};
                                3'd7: result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a[6:0], op_a[7]};
                            endcase
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    default: begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                endcase

            end
            else begin

                case (cmd)
                    4'd0: begin
                        count <= 2'd0;
                        if (inp_valid == 2'b11) begin                                    //UNSIGNED ADD
                            result <= {{(RES_WIDTH-DATA_WIDTH-1){1'b0}}, uadd_result};
                            c_out  <= uadd_result[DATA_WIDTH];
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd1: begin
                        count <= 2'd0;
                        if (inp_valid == 2'b11) begin                               //UNSIGNED SUB
                            result   <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a - op_b};
                            overflow <= (op_b > op_a);
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd2: begin
                        count <= 2'd0;
                        if (inp_valid == 2'b11) begin
                            
                            result <= {{(RES_WIDTH-DATA_WIDTH-1){1'b0}}, uadd_cin_result};  //UNSIGNED ADD CIN
                            c_out  <= uadd_cin_result[DATA_WIDTH];
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd3: begin
                        count <= 2'd0;
                        if (inp_valid == 2'b11) begin
                            result   <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a - op_b - c_in};  //UNSIGNED SUB CIN
                            overflow <= ((op_b + c_in) > op_a);
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd4: begin
                        count <= 2'd0;
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b01))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a + 1'b1};   //INC A
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd5: begin
                        count <= 2'd0;
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b01))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_a - 1'b1};   //DEC A
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd6: begin
                        count <= 2'd0;
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b10))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_b + 1'b1};   //INC B
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end
                    4'd7: begin
                        count <= 2'd0;
                        if ((inp_valid == 2'b11) || (inp_valid == 2'b10))
                            result <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, op_b - 1'b1};   //DEC B
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd8: begin
                        count <= 2'd0;
                        if (inp_valid == 2'b11) begin                                       //COMPARATOR
                            result <= {RES_WIDTH{1'b0}};
                            if      (op_a > op_b) G <= 1'b1;
                            else if (op_a < op_b) L <= 1'b1;
                            else                  E <= 1'b1;
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd9: begin
                        if (inp_valid == 2'b11) begin                                       //INC AND MULTIPLY
                            case (count)
                                2'd0: begin
                                    temp1 <= op_a + 1'b1;
                                    temp2 <= op_b + 1'b1;
                                    count <= 2'd1;
                                end
                                2'd1: begin
                                    count <= 2'd2;
                                end
                                2'd2: begin
                                    result <= temp1 * temp2;
                                    count  <= 2'd0;
                                end
                                default: count <= 2'd0;
                            endcase
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; count <= 2'd0; err <= 1'b1; end
                    end

                    4'd10: begin
                        if (inp_valid == 2'b11) begin                            //SHIFT AND MULTIPLY
                            case (count2)
                                2'd0: begin
                                    temp3  <= op_a << 1;
                                    temp2  <= op_b;
                                    count2 <= 2'd1;
                                end
                                2'd1: begin
                                    count2 <= 2'd2;
                                end
                                2'd2: begin
                                    result <= temp3 * temp2;
                                    count2  <= 2'd0;
                                end
                                default: count2 <= 2'd0;
                            endcase
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; count2 <= 2'd0; err <= 1'b1; end
                    end

                    4'd11: begin
                        count <= 2'd0;
                        if (inp_valid == 2'b11) begin
                            result   <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, sadd_result[DATA_WIDTH-1:0]};  //SIGNED ADDITION
                            c_out    <= sadd_result[DATA_WIDTH];
                            overflow <= (s_a[DATA_WIDTH-1] == s_b[DATA_WIDTH-1]) &&
                                        (sadd_result[DATA_WIDTH-1] != s_a[DATA_WIDTH-1]);
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    4'd12: begin
                        count <= 2'd0;
                        if (inp_valid == 2'b11) begin
                            result   <= {{(RES_WIDTH-DATA_WIDTH){1'b0}}, ssub_result[DATA_WIDTH-1:0]};  //SIGNED SUBTRACTION
                            c_out    <= ssub_result[DATA_WIDTH];
                            overflow <= (s_a[DATA_WIDTH-1] != s_b[DATA_WIDTH-1]) &&
                                        (ssub_result[DATA_WIDTH-1] != s_a[DATA_WIDTH-1]);
                        end
                        else begin result <= {RES_WIDTH{1'b0}}; err <= 1'b1; end
                    end

                    default: begin result <= {RES_WIDTH{1'b0}}; count <= 2'd0; err <= 1'b1; end
                endcase
            end
        end
    end

endmodule
