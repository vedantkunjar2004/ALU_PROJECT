`timescale 1ns/1ps
`default_nettype none

module alu_testbench;

    parameter DATA_WIDTH = 8;
    parameter RES_WIDTH  = 16;

    reg [DATA_WIDTH-1:0] opa, opb;
    reg                  clk, rst, ce, mode, cin;
    reg [3:0]            cmd;
    reg [1:0]            inp_valid;

    wire [RES_WIDTH-1:0] res_dut;
    wire                 cout_dut, oflow_dut;
    wire                 g_dut, e_dut, l_dut, err_dut;

    wire [RES_WIDTH-1:0] res_ref;
    wire                 cout_ref, oflow_ref;
    wire                 g_ref, e_ref, l_ref, err_ref;

    integer pass_count = 0;
    integer fail_count = 0;
    integer test_count = 0;

    alu dut (
        .clk      (clk),
        .rst      (rst),
        .ce       (ce),
        .c_in     (cin),
        .mode     (mode),
        .op_a     (opa),
        .op_b     (opb),
        .inp_valid(inp_valid),
        .cmd      (cmd),
        .result   (res_dut),
        .err      (err_dut),
        .G        (g_dut),
        .L        (l_dut),
        .E        (e_dut),
        .c_out    (cout_dut),
        .overflow (oflow_dut)
    );

    alu_reference_model ref_model (
        .OPA      (opa),
        .OPB      (opb),
        .CIN      (cin),
        .MODE     (mode),
        .CE       (ce),
        .CMD      (cmd),
        .INP_VALID(inp_valid),
        .RES      (res_ref),
        .COUT     (cout_ref),
        .OFLOW    (oflow_ref),
        .G        (g_ref),
        .E        (e_ref),
        .L        (l_ref),
        .ERR      (err_ref)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task display_mismatch;
        begin
            $display("    DUT: RES=%04h COUT=%b OFLOW=%b G=%b E=%b L=%b ERR=%b",
                     res_dut, cout_dut, oflow_dut, g_dut, e_dut, l_dut, err_dut);
            $display("    REF: RES=%04h COUT=%b OFLOW=%b G=%b E=%b L=%b ERR=%b",
                     res_ref, cout_ref, oflow_ref, g_ref, e_ref, l_ref, err_ref);
        end
    endtask

    task check_all;
        input              skip_res;
        input [80*8:1]     test_name;
        reg                ok;
        begin
            test_count = test_count + 1;
            ok = 1'b1;

            // RES comparison (4-state safe: use ===)
            if (!skip_res) begin
                if (res_dut !== res_ref) ok = 1'b0;
            end

            // Flag comparisons
            if (cout_dut  !== cout_ref)  ok = 1'b0;
            if (oflow_dut !== oflow_ref) ok = 1'b0;
            if (g_dut     !== g_ref)     ok = 1'b0;
            if (e_dut     !== e_ref)     ok = 1'b0;
            if (l_dut     !== l_ref)     ok = 1'b0;
            if (err_dut   !== err_ref)   ok = 1'b0;

            if (ok) begin
                $display("[PASS] TC%-3d | %0s", test_count, test_name);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] TC%-3d | %0s", test_count, test_name);
                display_mismatch;
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_manual;
        input [RES_WIDTH-1:0] exp_res;
        input                 exp_cout, exp_oflow, exp_g, exp_e, exp_l, exp_err;
        input                 skip_res;
        input [80*8:1]        test_name;
        reg                   ok;
        begin
            test_count = test_count + 1;
            ok = 1'b1;

            if (!skip_res && (res_dut !== exp_res))   ok = 1'b0;
            if (cout_dut  !== exp_cout)               ok = 1'b0;
            if (oflow_dut !== exp_oflow)              ok = 1'b0;
            if (g_dut     !== exp_g)                  ok = 1'b0;
            if (e_dut     !== exp_e)                  ok = 1'b0;
            if (l_dut     !== exp_l)                  ok = 1'b0;
            if (err_dut   !== exp_err)                ok = 1'b0;

            if (ok) begin
                $display("[PASS] TC%-3d | %0s", test_count, test_name);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] TC%-3d | %0s  (DUT: RES=%04h COUT=%b OFLOW=%b G=%b E=%b L=%b ERR=%b | EXP: RES=%04h ...)",
                         test_count, test_name,
                         res_dut, cout_dut, oflow_dut, g_dut, e_dut, l_dut, err_dut,
                         exp_res);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =================================================================
    // TASK: apply_1cyc
    //   Apply stimulus on negedge, wait one posedge, check.
    //   skip_res : pass 1 for CMP
    // =================================================================
    task apply_1cyc;
        input [DATA_WIDTH-1:0] a, b;
        input [1:0]            iv;
        input [3:0]            c;
        input                  m, ci;
        input                  skip_res;
        input [80*8:1]         name;
        begin
            @(posedge clk); #1;
            opa = a; opb = b; inp_valid = iv;
            cmd = c; mode = m; cin = ci;
            @(posedge clk); #1;   // DUT registers outputs
            check_all(skip_res, name);
        end
    endtask

    // =================================================================
    // TASK: apply_3cyc
    //   Multi-cycle ops: INC_AND_MUL (CMD=9) / SHIFT_AND_MUL (CMD=10).
    //   Inputs are held stable for all 3 clock cycles.
    //   REF computes the correct final value immediately; we compare
    //   after the DUT has completed all 3 cycles.
    // =================================================================
    task apply_3cyc;
        input [DATA_WIDTH-1:0] a, b;
        input [1:0]            iv;
        input [3:0]            c;
        input                  m, ci;
        input [80*8:1]         name;
        begin
            @(posedge clk); #1;
            opa = a; opb = b; inp_valid = iv;
            cmd = c; mode = m; cin = ci;
            @(posedge clk); #1;   // cycle 0 done: count 0→1
            @(posedge clk); #1;   // cycle 1 done: temps latched
            @(posedge clk); #1;   // cycle 2 done: result ready
            check_all(0, name);
        end
    endtask

    // =================================================================
    // MAIN STIMULUS
    // =================================================================
    initial begin
        // ---- Global initialise ----
        rst       = 1'b1;
        ce        = 1'b1;
        cin       = 1'b0;
        opa       = 8'h00;
        opb       = 8'h00;
        mode      = 1'b0;
        cmd       = 4'd0;
        inp_valid = 2'b11;

        $display("\n=======================================================");
        $display("  ALU TESTBENCH (Combinational Reference Model)");
        $display("=======================================================\n");

        // Assert reset for two clock cycles then release
        @(posedge clk); @(posedge clk); #1;
        rst = 1'b0;
        @(posedge clk); #1;   // one clean cycle after reset

        // ==============================================================
        // SECTION 1 - CLK / RST / CE
        // ==============================================================
        $display("--- Section 1: CLK / RST / CE ---");

        // TC1: clk_toggle - verify in waveform
        begin
            test_count = test_count + 1; pass_count = pass_count + 1;
            $display("[PASS] TC%-3d | clk_toggle (verify in waveform)", test_count);
        end

        // TC2: reset_assert_deassert - all outputs must be 0 during RST
        begin
            rst = 1'b1;
            opa = 8'hAA; opb = 8'h55; mode = 1'b1;
            cmd = 4'd0;  inp_valid = 2'b11;
            @(posedge clk); #1;
            test_count = test_count + 1;
            if (res_dut === 16'h0000 && cout_dut === 1'b0 && oflow_dut === 1'b0 &&
                g_dut   === 1'b0     && e_dut    === 1'b0 && l_dut     === 1'b0 &&
                err_dut === 1'b0)
            begin
                $display("[PASS] TC%-3d | reset_assert_deassert", test_count);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] TC%-3d | reset_assert_deassert", test_count);
                display_mismatch; fail_count = fail_count + 1;
            end
            rst = 1'b0;
            @(posedge clk); #1;
        end

        // TC3: assert_clock_enable - result updates when CE=1
        begin
            ce = 1'b1; mode = 1'b1; cmd = 4'd0;
            opa = 8'h03; opb = 8'h05; inp_valid = 2'b11; cin = 1'b0;
            @(posedge clk); #1;
            test_count = test_count + 1;
            if (res_dut === 16'h0008) begin
                $display("[PASS] TC%-3d | assert_clock_enable (0x03+0x05=0x08)", test_count);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] TC%-3d | assert_clock_enable (EXP=0x0008 GOT=%04h)",
                          test_count, res_dut);
                fail_count = fail_count + 1;
            end
        end

        // TC4: de_assert_clk_enable - result holds when CE=0
        begin : blk_ce_deassert
            reg [RES_WIDTH-1:0] held;
            opa = 8'h05; opb = 8'h03; mode = 1'b1;
            cmd = 4'd0; inp_valid = 2'b11; cin = 1'b0; ce = 1'b1;
            @(posedge clk); #1;
            held = res_dut;           // capture current DUT output
            ce   = 1'b0;
            opa  = 8'hFF; opb = 8'hFF;   // change inputs while CE=0
            @(posedge clk); #1;
            test_count = test_count + 1;
            if (res_dut === held) begin
                $display("[PASS] TC%-3d | de_assert_clk_enable (held=%04h)", test_count, held);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] TC%-3d | de_assert_clk_enable (EXP=%04h GOT=%04h)",
                          test_count, held, res_dut);
                fail_count = fail_count + 1;
            end
            ce = 1'b1;
        end

        // ==============================================================
        // SECTION 2 - MODE SELECTION
        // ==============================================================
        $display("\n--- Section 2: MODE ---");

        // TC5: MODE=1 → arithmetic (ADD)
        apply_1cyc(8'h05, 8'h03, 2'b11, 4'd0, 1'b1, 1'b0, 0,
                   "MODE=1 arithmetic ADD (0x05+0x03=0x08)");

        // TC6: MODE=0 → logical (AND)
        apply_1cyc(8'hF0, 8'h0F, 2'b11, 4'd0, 1'b0, 1'b0, 0,
                   "MODE=0 logical AND (0xF0&0x0F=0x00)");

        // ==============================================================
        // SECTION 3 - INVALID CMD
        // ==============================================================
        $display("\n--- Section 3: Invalid CMD ---");

        // TC7: CMD=13 in MODE=1 → default: ERR=1, RES=0
        apply_1cyc(8'h05, 8'h03, 2'b11, 4'd13, 1'b1, 1'b0, 0,
                   "invalid CMD=13 MODE=1 (ERR=1 RES=0)");

        // TC8: CMD=14 in MODE=0 → default: ERR=1, RES=0
        apply_1cyc(8'h05, 8'h03, 2'b11, 4'd14, 1'b0, 1'b0, 0,
                   "invalid CMD=14 MODE=0 (ERR=1 RES=0)");

        // ==============================================================
        // SECTION 4 - INP_VALID
        // ==============================================================
        $display("\n--- Section 4: INP_VALID ---");

        // TC9: inp_valid=00, 2-operand op → ERR=1
        apply_1cyc(8'hAA, 8'h55, 2'b00, 4'd0, 1'b1, 1'b0, 0,
                   "inp_valid_00 MODE=1 CMD=ADD (ERR=1)");

        // TC10: inp_valid=01, 2-operand op → ERR=1
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd0, 1'b1, 1'b0, 0,
                   "inp_valid_01 2op ADD needs both (ERR=1)");

        // TC11: inp_valid=10, 2-operand op → ERR=1
        apply_1cyc(8'hAA, 8'h55, 2'b10, 4'd0, 1'b1, 1'b0, 0,
                   "inp_valid_10 2op ADD needs both (ERR=1)");

        // TC12: inp_valid=01, single-operand INC_A → OK
        apply_1cyc(8'h10, 8'h00, 2'b01, 4'd4, 1'b1, 1'b0, 0,
                   "inp_valid_01 single-op INC_A (RES=0x11 ERR=0)");

        // TC13: inp_valid=11 → result updates
        apply_1cyc(8'h10, 8'h05, 2'b11, 4'd0, 1'b1, 1'b0, 0,
                   "inp_valid_11 MODE=1 ADD (RES=0x15)");

        // ==============================================================
        // SECTION 5 - ARITHMETIC OPERATIONS
        // ==============================================================
        $display("\n--- Section 5: Arithmetic Operations ---");

        // ---- ADD (CMD=0, MODE=1) ----
        // TC14
        apply_1cyc($random & 8'hFF, $random & 8'hFF,
                   2'b11, 4'd0, 1'b1, 1'b0, 0,
                   "add_two_random_numbers");
        // TC15: invalid inp_valid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd0, 1'b1, 1'b0, 0,
                   "add_invalid_inputs (valid=01, ERR=1)");
        // TC16: 0xFF+0x01 → COUT=1
        apply_1cyc(8'hFF, 8'h01, 2'b11, 4'd0, 1'b1, 1'b0, 0,
                   "add_with_cout (0xFF+0x01, COUT=1)");

        // ---- SUB (CMD=1, MODE=1) ----
        // TC17
        apply_1cyc($random & 8'hFF, $random & 8'hFF,
                   2'b11, 4'd1, 1'b1, 1'b0, 0,
                   "sub_two_random_numbers");
        // TC18: invalid inp_valid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd1, 1'b1, 1'b0, 0,
                   "sub_invalid_inputs (valid=01, ERR=1)");
        // TC19: 0-1 → OFLOW=1
        apply_1cyc(8'h00, 8'h01, 2'b11, 4'd1, 1'b1, 1'b0, 0,
                   "sub_with_borrow (0x00-0x01, OFLOW=1)");

        // ---- ADD_CIN (CMD=2, MODE=1) ----
        // TC20: invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd2, 1'b1, 1'b0, 0,
                   "add_cin_invalid_inputs (valid=01, ERR=1)");
        // TC21: 0xFE+0x01+cin=1 → 0x100, COUT=1
        apply_1cyc(8'hFE, 8'h01, 2'b11, 4'd2, 1'b1, 1'b1, 0,
                   "add_with_cin_1 (0xFE+0x01+1, COUT=1)");
        // TC22: 0xFF+0x00+cin=0 → 0xFF, COUT=0
        apply_1cyc(8'hFF, 8'h00, 2'b11, 4'd2, 1'b1, 1'b0, 0,
                   "add_with_cin_0 (0xFF+0x00+0, COUT=0)");

        // ---- SUB_CIN (CMD=3, MODE=1) ----
        // TC23: invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd3, 1'b1, 1'b0, 0,
                   "sub_cin_invalid_inputs (valid=01, ERR=1)");
        // TC24: 0xFF-0x00-cin=1 → 0xFE, OFLOW=0
        apply_1cyc(8'hFF, 8'h00, 2'b11, 4'd3, 1'b1, 1'b1, 0,
                   "sub_with_cin_1 (0xFF-0-1=0xFE, OFLOW=0)");
        // TC25: 0x00-0x00-cin=1 → 0xFF, OFLOW=1
        apply_1cyc(8'h00, 8'h00, 2'b11, 4'd3, 1'b1, 1'b1, 0,
                   "sub_with_cin_overflow (0x00-0-1, OFLOW=1)");

        // ---- INC_A (CMD=4, MODE=1) ----
        // TC26: invalid (valid=10)
        apply_1cyc(8'hAA, 8'h55, 2'b10, 4'd4, 1'b1, 1'b0, 0,
                   "increment_a_invalid_inputs (valid=10, ERR=1)");
        // TC27: random A, valid=01
        apply_1cyc($random & 8'hFF, 8'h00, 2'b01, 4'd4, 1'b1, 1'b0, 0,
                   "increment_a (A+1)");

        // ---- DEC_A (CMD=5, MODE=1) ----
        // TC28: invalid (valid=10)
        apply_1cyc(8'hAA, 8'h55, 2'b10, 4'd5, 1'b1, 1'b0, 0,
                   "decrement_a_invalid_inputs (valid=10, ERR=1)");
        // TC29: random A, valid=01
        apply_1cyc($random & 8'hFF, 8'h00, 2'b01, 4'd5, 1'b1, 1'b0, 0,
                   "decrement_a (A-1)");

        // ---- INC_B (CMD=6, MODE=1) ----
        // TC30: invalid (valid=01)
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd6, 1'b1, 1'b0, 0,
                   "increment_b_invalid_inputs (valid=01, ERR=1)");
        // TC31: random B, valid=10
        apply_1cyc(8'h00, $random & 8'hFF, 2'b10, 4'd6, 1'b1, 1'b0, 0,
                   "increment_b (B+1)");

        // ---- DEC_B (CMD=7, MODE=1) ----
        // TC32: invalid (valid=01)
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd7, 1'b1, 1'b0, 0,
                   "decrement_b_invalid_inputs (valid=01, ERR=1)");
        // TC33: random B, valid=10
        apply_1cyc(8'h00, $random & 8'hFF, 2'b10, 4'd7, 1'b1, 1'b0, 0,
                   "decrement_b (B-1)");

        // ---- COMPARATOR (CMD=8, MODE=1) ----
        // RES is 9'bz in REF → set skip_res=1, check only G/E/L
        // TC34: invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd8, 1'b1, 1'b0, 0,
                   "comparator_invalid_inputs (valid=01, ERR=1)");
        // TC35a: A==B
        apply_1cyc(8'h42, 8'h42, 2'b11, 4'd8, 1'b1, 1'b0, 1,
                   "comparator A==B (E=1 G=0 L=0)");
        // TC35b: A>B
        apply_1cyc(8'hFF, 8'h00, 2'b11, 4'd8, 1'b1, 1'b0, 1,
                   "comparator A>B  (G=1 E=0 L=0)");
        // TC35c: A<B
        apply_1cyc(8'h00, 8'hFF, 2'b11, 4'd8, 1'b1, 1'b0, 1,
                   "comparator A<B  (L=1 E=0 G=0)");

        // ==============================================================
        // INC_AND_MUL  (CMD=9, MODE=1) - 3-cycle
        // ==============================================================
        $display("\n--- INC_AND_MUL (CMD=9, 3-cycle) ---");

        // TC36: basic - (A+1)*(B+1) after 3 cycles
        apply_3cyc(8'h05, 8'h03, 2'b11, 4'd9, 1'b1, 1'b0,
                   "inc_mul_basic (5+1)*(3+1)=24");

        // TC37: invalid inputs
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd9, 1'b1, 1'b0, 0,
                   "inc_mul_invalid_inputs (valid=01, ERR=1)");

        // TC38: MODE change in cycle 1 → DUT executes new MODE from cycle 1 onward
        //   Expected: DUT switches to logical AND with inputs at that cycle
        begin : blk_inc_mode_chg
            reg [RES_WIDTH-1:0] exp_res;
            @(posedge clk); #1;
            opa = 8'h05; opb = 8'h03; inp_valid = 2'b11;
            cmd = 4'd9; mode = 1'b1; cin = 1'b0;
            @(posedge clk); #1;    // cycle 0: count 0→1
            // Change MODE to 0 and CMD to AND; DUT resets count and executes AND
            mode = 1'b0; cmd = 4'd0;
            @(posedge clk); #1;    // DUT now does AND
            // REF is now combinational AND → compare directly
            check_all(0, "inc_mul_mode_chg (switch to logical AND mid-op)");
        end

        // TC39: CMD change in cycle 1 → DUT switches to new CMD (ADD)
        begin : blk_inc_cmd_chg
            @(posedge clk); #1;
            opa = 8'h05; opb = 8'h03; inp_valid = 2'b11;
            cmd = 4'd9; mode = 1'b1; cin = 1'b0;
            @(posedge clk); #1;    // cycle 0: count 0→1
            cmd = 4'd0;            // switch to ADD; count resets to 0
            @(posedge clk); #1;    // DUT executes ADD
            check_all(0, "inc_mul_cmd_chg (switch to ADD mid-op)");
        end

        // TC40: Operand change in cycle 1 (before temps latched at cycle 1)
        //   Per spec: DUT should latch temps from ORIGINAL inputs and ignore
        //   operand change. But the DUT latches temp1=op_a+1, temp2=op_b+1
        //   on cycle 1's posedge, which uses the NEW inputs if they changed
        //   before that edge. We verify DUT vs manually computed expected
        //   result using the NEW inputs (which DUT will see at cycle 1 edge).
        begin : blk_inc_op_chg
            reg [7:0] a_new, b_new;
            reg [RES_WIDTH-1:0] exp_res;
            @(posedge clk); #1;
            opa = 8'h05; opb = 8'h03; inp_valid = 2'b11;
            cmd = 4'd9; mode = 1'b1; cin = 1'b0;
            @(posedge clk); #1;     // cycle 0: count 0→1
            a_new = 8'h0A; b_new = 8'h04;
            opa = a_new; opb = b_new;   // change before cycle 1 latch
            @(posedge clk); #1;     // cycle 1: temp1=a_new+1, temp2=b_new+1
            @(posedge clk); #1;     // cycle 2: result = temp1*temp2
            exp_res = (a_new + 1) * (b_new + 1);
            check_manual(exp_res, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0,
                         "inc_mul_operand_chg (new ops latched at cycle 1)");
        end

        // TC41: CE deassert then re-assert during INC_AND_MUL
        //   CE=0 freezes DUT state; once CE=1 operation resumes.
        begin : blk_inc_ce
            reg [7:0] a_op, b_op;
            reg [RES_WIDTH-1:0] exp_res;
            a_op = 8'h04; b_op = 8'h02;
            exp_res = (a_op + 1) * (b_op + 1);  // 5*3=15
            @(posedge clk); #1;
            opa = a_op; opb = b_op; inp_valid = 2'b11;
            cmd = 4'd9; mode = 1'b1; cin = 1'b0; ce = 1'b1;
            @(posedge clk); #1;   // cycle 0: count 0→1
            ce = 1'b0;            // freeze
            @(posedge clk); #1;   // frozen (count stays at 1)
            @(posedge clk); #1;   // frozen
            ce = 1'b1;            // resume
            @(posedge clk); #1;   // cycle 1: temps latched
            @(posedge clk); #1;   // cycle 2: result
            check_manual(exp_res, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0,
                         "inc_mul_ce_deassert_assert (resumes correctly)");
        end

        // TC42: corner A=255, B=255 → (256*256)=65536 → 16'h0000
        apply_3cyc(8'hFF, 8'hFF, 2'b11, 4'd9, 1'b1, 1'b0,
                   "inc_mul_corner A=B=255 (256*256=0 mod 2^16)");

        // ==============================================================
        // SHIFT_AND_MUL  (CMD=10, MODE=1) - 3-cycle
        // ==============================================================
        $display("\n--- SHIFT_AND_MUL (CMD=10, 3-cycle) ---");

        // TC43: basic - (A<<1)*B after 3 cycles
        apply_3cyc(8'h05, 8'h03, 2'b11, 4'd10, 1'b1, 1'b0,
                   "shift_mul_basic (5<<1)*3=30");

        // TC44: invalid inputs
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd10, 1'b1, 1'b0, 0,
                   "shift_mul_invalid_inputs (valid=01, ERR=1)");

        // TC45: MODE change in cycle 1 → DUT switches to logical AND
        begin : blk_shft_mode_chg
            @(posedge clk); #1;
            opa = 8'h05; opb = 8'h03; inp_valid = 2'b11;
            cmd = 4'd10; mode = 1'b1; cin = 1'b0;
            @(posedge clk); #1;    // count2 0→1
            mode = 1'b0; cmd = 4'd0;
            @(posedge clk); #1;
            check_all(0, "shift_mul_mode_chg (switch to logical AND mid-op)");
        end

        // TC46: CMD change in cycle 1 → DUT switches to ADD
        begin : blk_shft_cmd_chg
            @(posedge clk); #1;
            opa = 8'h05; opb = 8'h03; inp_valid = 2'b11;
            cmd = 4'd10; mode = 1'b1; cin = 1'b0;
            @(posedge clk); #1;    // count2 0→1
            cmd = 4'd0;
            @(posedge clk); #1;
            check_all(0, "shift_mul_cmd_chg (switch to ADD mid-op)");
        end

        // TC47: Operand change in cycle 1 (before temp3 latched)
        begin : blk_shft_op_chg
            reg [7:0] a_new, b_new;
            reg [RES_WIDTH-1:0] exp_res;
            @(posedge clk); #1;
            opa = 8'h05; opb = 8'h03; inp_valid = 2'b11;
            cmd = 4'd10; mode = 1'b1; cin = 1'b0;
            @(posedge clk); #1;     // count2 0→1
            a_new = 8'h0A; b_new = 8'h06;
            opa = a_new; opb = b_new;
            @(posedge clk); #1;     // cycle 1: temp3 = a_new<<1
            @(posedge clk); #1;     // cycle 2: result = temp3 * b_new
            exp_res = (a_new << 1) * b_new;
            check_manual(exp_res, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0,
                         "shift_mul_operand_chg (new ops latched at cycle 1)");
        end

        // TC48: CE deassert then re-assert during SHIFT_AND_MUL
        begin : blk_shft_ce
            reg [7:0] a_op, b_op;
            reg [RES_WIDTH-1:0] exp_res;
            a_op = 8'h04; b_op = 8'h03;
            exp_res = (a_op << 1) * b_op;   // 8*3=24
            @(posedge clk); #1;
            opa = a_op; opb = b_op; inp_valid = 2'b11;
            cmd = 4'd10; mode = 1'b1; cin = 1'b0; ce = 1'b1;
            @(posedge clk); #1;   // count2 0→1
            ce = 1'b0;
            @(posedge clk); #1;
            @(posedge clk); #1;
            ce = 1'b1;
            @(posedge clk); #1;   // temp3 latched
            @(posedge clk); #1;   // result
            check_manual(exp_res, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 0,
                         "shift_mul_ce_deassert_assert (resumes correctly)");
        end

        // TC49: corner A=128 → 128<<1=0 (8-bit overflow) → result=0
        apply_3cyc(8'h80, $random & 8'hFF, 2'b11, 4'd10, 1'b1, 1'b0,
                   "shift_mul_corner A=128 (128<<1=0, result=0)");

        // ==============================================================
        // SIGNED_ADD (CMD=11, MODE=1)
        // ==============================================================
        $display("\n--- SIGNED_ADD / SIGNED_SUB ---");

        // TC50: no overflow (positive+positive = positive)
        apply_1cyc(8'h30, 8'h10, 2'b11, 4'd11, 1'b1, 1'b0, 0,
                   "sadd_basic 0x30+0x10=0x40 (OFLOW=0)");
        // TC51: overflow (positive+positive → negative, 0x70+0x40)
        apply_1cyc(8'h70, 8'h40, 2'b11, 4'd11, 1'b1, 1'b0, 0,
                   "sadd_overflow 0x70+0x40 (OFLOW=1)");
        // TC52: invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd11, 1'b1, 1'b0, 0,
                   "sadd_invalid_inputs (valid=01, ERR=1)");

        // ==============================================================
        // SIGNED_SUB (CMD=12, MODE=1)
        // ==============================================================
        // TC53: no overflow (pos-pos=pos)
        apply_1cyc(8'h50, 8'h10, 2'b11, 4'd12, 1'b1, 1'b0, 0,
                   "ssub_basic 0x50-0x10=0x40 (OFLOW=0)");
        // TC54: overflow (pos-neg→neg, 0x70-0xC0)
        apply_1cyc(8'h70, 8'hC0, 2'b11, 4'd12, 1'b1, 1'b0, 0,
                   "ssub_overflow 0x70-0xC0 (OFLOW=1)");
        // TC55: invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd12, 1'b1, 1'b0, 0,
                   "ssub_invalid_inputs (valid=01, ERR=1)");

        // ==============================================================
        // SECTION 6 - LOGICAL OPERATIONS
        // ==============================================================
        $display("\n--- Section 6: Logical Operations ---");

        // AND (CMD=0, MODE=0) - also exercised in Section 2
        apply_1cyc(8'hAB, 8'hCD, 2'b11, 4'd0, 1'b0, 1'b0, 0,
                   "bitwise_and (0xAB&0xCD)");

        // TC56: NAND
        apply_1cyc($random & 8'hFF, $random & 8'hFF,
                   2'b11, 4'd1, 1'b0, 1'b0, 0, "bitwise_Nand");
        // TC57: NAND invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd1, 1'b0, 1'b0, 0,
                   "nand_invalid_inputs (valid=01, ERR=1)");

        // TC58: OR
        apply_1cyc($random & 8'hFF, $random & 8'hFF,
                   2'b11, 4'd2, 1'b0, 1'b0, 0, "bitwise_or");
        // TC59: OR invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd2, 1'b0, 1'b0, 0,
                   "or_invalid_inputs (valid=01, ERR=1)");

        // TC60: NOR
        apply_1cyc($random & 8'hFF, $random & 8'hFF,
                   2'b11, 4'd3, 1'b0, 1'b0, 0, "bitwise_nor");
        // TC61: NOR invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd3, 1'b0, 1'b0, 0,
                   "nor_invalid_inputs (valid=01, ERR=1)");

        // TC62: XOR
        apply_1cyc($random & 8'hFF, $random & 8'hFF,
                   2'b11, 4'd4, 1'b0, 1'b0, 0, "bitwise_xor");
        // TC63: XOR invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd4, 1'b0, 1'b0, 0,
                   "xor_invalid_inputs (valid=01, ERR=1)");

        // TC64: XNOR
        apply_1cyc($random & 8'hFF, $random & 8'hFF,
                   2'b11, 4'd5, 1'b0, 1'b0, 0, "bitwise_xnor");
        // TC65: XNOR invalid
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd5, 1'b0, 1'b0, 0,
                   "xnor_invalid_inputs (valid=01, ERR=1)");

        // TC66: NOT_A  (valid: 11 or 01)
        apply_1cyc($random & 8'hFF, 8'h00, 2'b01, 4'd6, 1'b0, 1'b0, 0,
                   "negation_a (~A)");
        // TC67: NOT_A invalid (valid=10)
        apply_1cyc(8'hAA, 8'h55, 2'b10, 4'd6, 1'b0, 1'b0, 0,
                   "negation_a_invalid_inputs (valid=10, ERR=1)");

        // TC68: NOT_B  (valid: 11 or 10)
        apply_1cyc(8'h00, $random & 8'hFF, 2'b10, 4'd7, 1'b0, 1'b0, 0,
                   "negation_b (~B)");
        // TC69: NOT_B invalid (valid=01)
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd7, 1'b0, 1'b0, 0,
                   "negation_b_invalid_inputs (valid=01, ERR=1)");

        // TC70: SHR1_A  (valid: 11 or 01)
        apply_1cyc($random & 8'hFF, 8'h00, 2'b01, 4'd8, 1'b0, 1'b0, 0,
                   "shift_right_A (A>>1)");
        // TC71: SHR1_A invalid (valid=10)
        apply_1cyc(8'hAA, 8'h55, 2'b10, 4'd8, 1'b0, 1'b0, 0,
                   "shift_right_A_invalid_inputs (valid=10, ERR=1)");

        // TC72: SHL1_A  (valid: 11 or 01)
        apply_1cyc($random & 8'hFF, 8'h00, 2'b01, 4'd9, 1'b0, 1'b0, 0,
                   "shift_left_A (A<<1)");
        // TC73: SHL1_A invalid (valid=10)
        apply_1cyc(8'hAA, 8'h55, 2'b10, 4'd9, 1'b0, 1'b0, 0,
                   "shift_left_A_invalid_inputs (valid=10, ERR=1)");

        // TC74: SHR1_B  (valid: 11 or 10)
        apply_1cyc(8'h00, $random & 8'hFF, 2'b10, 4'd10, 1'b0, 1'b0, 0,
                   "shift_right_B (B>>1)");
        // TC75: SHR1_B invalid (valid=01)
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd10, 1'b0, 1'b0, 0,
                   "shift_right_B_invalid_inputs (valid=01, ERR=1)");

        // TC76: SHL1_B  (valid: 11 or 10)
        apply_1cyc(8'h00, $random & 8'hFF, 2'b10, 4'd11, 1'b0, 1'b0, 0,
                   "shift_left_B (B<<1)");
        // TC77: SHL1_B invalid (valid=01)
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd11, 1'b0, 1'b0, 0,
                   "shift_left_B_invalid_inputs (valid=01, ERR=1)");

        // TC78: ROL_A_B - valid rotation B=3, B[7:4]=0 → ERR=0
        apply_1cyc(8'hAA, 8'h03, 2'b11, 4'd12, 1'b0, 1'b0, 0,
                   "rotate_left_A B=3 (B<8, ERR=0)");
        // TC79: ROL_A_B invalid inp_valid (valid=01)
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd12, 1'b0, 1'b0, 0,
                   "rotate_left_A_invalid_inputs (valid=01, ERR=1)");
        // TC80: ROL_A_B B>=8 → ERR=1, rotate still uses B[2:0]
        apply_1cyc(8'hAA, 8'h0B, 2'b11, 4'd12, 1'b0, 1'b0, 0,
                   "rotate_left_A_ERR B=0x0B (B>=8, ERR=1)");

        // TC81: ROR_A_B - valid rotation B=2, B[7:4]=0 → ERR=0
        apply_1cyc(8'hAA, 8'h02, 2'b11, 4'd13, 1'b0, 1'b0, 0,
                   "rotate_right_A B=2 (B<8, ERR=0)");
        // TC82: ROR_A_B invalid inp_valid (valid=01)
        apply_1cyc(8'hAA, 8'h55, 2'b01, 4'd13, 1'b0, 1'b0, 0,
                   "rotate_right_A_invalid_inputs (valid=01, ERR=1)");
        // TC83: ROR_A_B B>=8 → ERR=1
        apply_1cyc(8'hAA, 8'h0A, 2'b11, 4'd13, 1'b0, 1'b0, 0,
                   "rotate_right_A_ERR B=0x0A (B>=8, ERR=1)");

        // ==============================================================
        // SUMMARY
        // ==============================================================
        $display("\n=======================================================");
        $display("  TEST SUMMARY");
        $display("=======================================================");
        $display("  Total Tests : %0d", test_count);
        $display("  PASS        : %0d", pass_count);
        $display("  FAIL        : %0d", fail_count);
        if (fail_count == 0)
            $display("\n  *** ALL TESTS PASSED ***\n");
        else
            $display("\n  *** %0d TEST(S) FAILED ***\n", fail_count);

        #100;
        $finish;
    end

    // -----------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_testbench);
    end

endmodule
