//==============================================
// Simple ALU Testbench
//==============================================

`timescale 1ns/1ps

module alu_testbench;

    // DUT signals
    reg [7:0] OPA, OPB;
    reg CLK, RST, CE, MODE, CIN;
    reg [3:0] CMD;
    wire [8:0] RES_dut;
    wire COUT_dut, OFLOW_dut, G_dut, E_dut, L_dut, ERR_dut;

    // Reference model signals
    wire [8:0] RES_ref;
    wire COUT_ref, OFLOW_ref, G_ref, E_ref, L_ref, ERR_ref;

    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_count = 0;

    // DUT instantiation
    Eight_bit_ALU_rtl_design dut (
        .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .CLK(CLK), .RST(RST), .CMD(CMD),
        .CE(CE), .MODE(MODE),
        .COUT(COUT_dut), .OFLOW(OFLOW_dut),
        .RES(RES_dut),
        .G(G_dut), .E(E_dut), .L(L_dut),
        .ERR(ERR_dut)
    );

    // Reference model instantiation
    alu_reference_model ref (
        .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .MODE(MODE), .CMD(CMD),
        .RES(RES_ref),
        .COUT(COUT_ref), .OFLOW(OFLOW_ref),
        .G(G_ref), .E(E_ref), .L(L_ref),
        .ERR(ERR_ref)
    );

    // Clock generation
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    // Test stimulus
    initial begin
        // Initialize
        RST = 1; CE = 1; CIN = 0;
        OPA = 0; OPB = 0; MODE = 0; CMD = 0;
        
        @(posedge CLK);
        RST = 0;  // Release reset
        @(posedge CLK);

        // Test Arithmetic Operations
        $display("\n=== Testing Arithmetic Operations (MODE=1) ===");
        MODE = 1;
        test_arithmetic();

        // Test Logical Operations
        $display("\n=== Testing Logical Operations (MODE=0) ===");
        MODE = 0;
        test_logical();

        // Summary
        $display("\n=== TEST SUMMARY ===");
        $display("Total Tests: %0d", test_count);
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        
        if (fail_count == 0)
            $display("\n*** ALL TESTS PASSED ***\n");
        else
            $display("\n*** SOME TESTS FAILED ***\n");

        #100;
        $finish;
    end

    // Test arithmetic operations
    task test_arithmetic();
        begin
            // ADD
            apply_test(8'h0F, 8'h11, 4'b0000, "ADD");
            apply_test(8'hFF, 8'h01, 4'b0000, "ADD (overflow)");
            
            // SUB
            apply_test(8'h20, 8'h10, 4'b0001, "SUB");
            apply_test(8'h10, 8'h20, 4'b0001, "SUB (underflow)");
            
            // ADD_CIN
            CIN = 1;
            apply_test(8'h10, 8'h20, 4'b0010, "ADD_CIN");
            CIN = 0;
            
            // INC_A, DEC_A
            apply_test(8'h0A, 8'h00, 4'b0100, "INC_A");
            apply_test(8'h0A, 8'h00, 4'b0101, "DEC_A");
            
            // CMP
            apply_test(8'h10, 8'h10, 4'b1000, "CMP (equal)");
            apply_test(8'h20, 8'h10, 4'b1000, "CMP (greater)");
            apply_test(8'h10, 8'h20, 4'b1000, "CMP (less)");
        end
    endtask

    // Test logical operations
    task test_logical();
        begin
            apply_test(8'hF0, 8'h0F, 4'b0000, "AND");
            apply_test(8'hF0, 8'h0F, 4'b0001, "NAND");
            apply_test(8'hF0, 8'h0F, 4'b0010, "OR");
            apply_test(8'hF0, 8'h0F, 4'b0011, "NOR");
            apply_test(8'hAA, 8'h55, 4'b0100, "XOR");
            apply_test(8'hAA, 8'h55, 4'b0101, "XNOR");
            apply_test(8'hF0, 8'h00, 4'b0110, "NOT_A");
            apply_test(8'h00, 8'hF0, 4'b0111, "NOT_B");
            apply_test(8'hAA, 8'h00, 4'b1000, "SHR1_A");
            apply_test(8'h55, 8'h00, 4'b1001, "SHL1_A");
            apply_test(8'hAA, 8'h03, 4'b1100, "ROL_A_B");
            apply_test(8'hAA, 8'h02, 4'b1101, "ROR_A_B");
        end
    endtask

    // Apply test and check
    task apply_test(
        input [7:0] a, b,
        input [3:0] cmd,
        input [80*8:1] test_name
    );
        begin
            @(posedge CLK);
            OPA = a;
            OPB = b;
            CMD = cmd;
            
            @(posedge CLK);
            @(posedge CLK);
            
            test_count = test_count + 1;
            
            if (compare_outputs()) begin
                $display("[PASS] %s: OPA=0x%h OPB=0x%h CMD=0x%h", 
                         test_name, a, b, cmd);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s: OPA=0x%h OPB=0x%h CMD=0x%h", 
                         test_name, a, b, cmd);
                display_mismatch();
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Compare DUT vs Reference
    function compare_outputs();
        begin
            compare_outputs = 1;
            
            // Compare RES (handle Z values)
            if (RES_dut !== RES_ref) begin
                if (!((RES_dut === 9'bzzzzzzzzz) && (RES_ref === 9'bzzzzzzzzz)))
                    compare_outputs = 0;
            end
            
            // Compare flags (handle Z values)
            if (!compare_bit(COUT_dut, COUT_ref)) compare_outputs = 0;
            if (!compare_bit(OFLOW_dut, OFLOW_ref)) compare_outputs = 0;
            if (!compare_bit(G_dut, G_ref)) compare_outputs = 0;
            if (!compare_bit(E_dut, E_ref)) compare_outputs = 0;
            if (!compare_bit(L_dut, L_ref)) compare_outputs = 0;
            if (!compare_bit(ERR_dut, ERR_ref)) compare_outputs = 0;
        end
    endfunction

    // Compare single bit (handle Z)
    function compare_bit(input dut, ref);
        begin
            if (dut === ref)
                compare_bit = 1;
            else if ((dut === 1'bz) && (ref === 1'bz))
                compare_bit = 1;
            else
                compare_bit = 0;
        end
    endfunction

    // Display mismatch details
    task display_mismatch();
        begin
            $display("  DUT: RES=0x%h COUT=%b OFLOW=%b G=%b E=%b L=%b ERR=%b",
                     RES_dut, COUT_dut, OFLOW_dut, G_dut, E_dut, L_dut, ERR_dut);
            $display("  REF: RES=0x%h COUT=%b OFLOW=%b G=%b E=%b L=%b ERR=%b",
                     RES_ref, COUT_ref, OFLOW_ref, G_ref, E_ref, L_ref, ERR_ref);
        end
    endtask

    // Waveform dump
    initial begin
        $dumpfile("alu_test.vcd");
        $dumpvars(0, alu_testbench);
    end

endmodule
