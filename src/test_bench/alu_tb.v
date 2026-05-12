

module alu_testbench;

    // DUT signals
    reg [7:0] OPA, OPB;
    reg CLK, RST, CE, MODE, CIN;
    reg [3:0] CMD;
	reg [1:0]INP_VALID; 
    wire [15:0] RES_dut;
    wire COUT_dut, OFLOW_dut, G_dut, E_dut, L_dut, ERR_dut;

    // Reference model signals
	wire [15:0] RES_ref;
    wire COUT_ref, OFLOW_ref, G_ref, E_ref, L_ref, ERR_ref;

    // Test counters
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_count = 0;
	reg cmp;
	reg abcd;

    // DUT instantiation
    alu dut (
        .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .CLK(CLK), .RST(RST), .CMD(CMD),
        .CE(CE), .MODE(MODE),
		.INP_VALID(INP_VALID),
        .COUT(COUT_dut), .OFLOW(OFLOW_dut),
        .RES(RES_dut),
        .G(G_dut), .E(E_dut), .L(L_dut),
        .ERR(ERR_dut)
    );

    // Reference model instantiation
    alu_reference_model ref (
		.CE(CE),
        .OPA(OPA), .OPB(OPB), .CIN(CIN),
        .MODE(MODE), .CMD(CMD),
		.INP_VALID(INP_VALID),
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
        // all 0
        RST = 0; CE = 0; CIN = 0;
        OPA = 0; OPB = 0; MODE = 0; CMD = 0;
        //rst 
        @(posedge CLK);
		RST = 1; CE = 0; CIN = 0;
        OPA = 0; OPB = 0; MODE = 0; CMD = 0;
		//rst low and clock enable
        @(posedge CLK);
		RST = 0; CE = 1; CIN = 0;
        OPA = 0; OPB = 0; MODE = 0; CMD = 0;
		//rst low and clock disable
        @(posedge CLK);
		RST = 0; CE = 0; CIN = 0;
        OPA = 0; OPB = 0; MODE = 0; CMD = 0;
		//mode 1
        @(posedge CLK);
		RST = 0; CE = 1; CIN = 0;
        OPA = 1; OPB = 1; MODE = 1; CMD = 0;
		//mode 0
        @(posedge CLK);
		RST = 0; CE = 1; CIN = 0;
        OPA = 1; OPB = 1; MODE = 0; CMD = 0;
		//cmd invalid arithmetic
        @(posedge CLK);
		RST = 0; CE = 1; CIN = 0;
        OPA = 1; OPB = 1; MODE = 1; CMD = 4'b1111;
		//cmd invalid logical
        @(posedge CLK);
		RST = 0; CE = 1; CIN = 0;
        OPA = 1; OPB = 1; MODE = 0; CMD = 4'b1111;
        
        @(posedge CLK);
		begin	RST = 0; 	CE = 1; INP_VALID = 2'b11;	end  // Release reset

		@(posedge CLK);

        // Test Arithmetic Operations
        $display("\n=== Testing Arithmetic Operations (MODE=1) ===");
        MODE = 1;					test_arithmetic();
            
		// INVALID 01
        $display("\n=== Testing Arithmetic Operations (INVALID=b01) ===");
		INP_VALID = 2'b01;	        test_arithmetic();
					
		// INVALID 10
        $display("\n=== Testing Arithmetic Operations (INVALID=b10) ===");
		INP_VALID = 2'b10;	        test_arithmetic();

		// INVALID 00
		$display("\n=== Testing Arithmetic Operations (INVALID=b00) ===");
		INP_VALID = 2'b00;	        test_arithmetic();
					
        // Test Logical Operations
        $display("\n=== Testing Logical Operations (MODE=0) ===");
        MODE = 0;
		INP_VALID = 2'b11;			test_logical();

		// INVALID 01
        $display("\n=== Testing Logical Operations (INVALID=b01) ===");
		INP_VALID = 2'b01;	        test_logical();
					
		// INVALID 10
        $display("\n=== Testing Logical Operations (INVALID=b10) ===");
		INP_VALID = 2'b10;	        test_logical();

		// INVALID 00
		$display("\n=== Testing Logical Operations (INVALID=b00) ===");
		INP_VALID = 2'b00;	        test_logical();
		
        // Summary
        $display("\n=== TEST SUMMARY ===");
        $display("Total Tests: %0d", test_count);
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        
        if (fail_count == 0)
            $display("\n*** ALL TESTS PASSED ***\n");
        else
            $display("\n*** SOME TESTS FAILED ***\n");

        #200;
        $finish;
    end

    // Test arithmetic operations
    task test_arithmetic();
		begin
			// ADD
					apply_test(8'h01, 8'h01, 4'b0000, "ADD");
					apply_test(8'hFF, 8'h01, 4'b0000, "ADD");
					apply_test(8'h00, 8'h00, 4'b0000, "ADD");
            
            // SUB
					apply_test(8'h01, 8'h01, 4'b0001, "SUB");
					apply_test(8'h00, 8'h01, 4'b0001, "SUB");
					apply_test(8'h50, 8'h50, 4'b0001, "SUB");
            
            // ADD_CIN
            CIN = 1;
					apply_test(8'hFF, 8'h00, 4'b0010, "ADD_CIN");
					CIN = 0;
					apply_test(8'hFF, 8'h00, 4'b0010, "ADD_CIN");
					CIN = 1;
					apply_test(8'h01, 8'h01, 4'b0010, "ADD_CIN");
            CIN = 0;

			// SUB_CIN
            CIN = 1;
					apply_test(8'h0A, 8'h03, 4'b0011, "SUB_CIN");
					apply_test(8'h00, 8'h00, 4'b0011, "SUB_CIN");
					CIN = 0;
					apply_test(8'h01, 8'h01, 4'b0011, "SUB_CIN");
					CIN = 1;
					apply_test(8'h01, 8'h01, 4'b0011, "SUB_CIN");
            CIN = 0;
			
            // INC_A
			apply_test(8'h50, 8'h00, 4'b0100, "INC_A");
			apply_test(8'hFF, 8'h00, 4'b0100, "INC_A");
			apply_test(8'h0A, 8'h00, 4'b0100, "INC_A");

            // DEC_A
			apply_test(8'h49, 8'h00, 4'b0101, "DEC_A");
			apply_test(8'h00, 8'h00, 4'b0101, "DEC_A");
			apply_test(8'h0A, 8'h00, 4'b0101, "DEC_A");
	
            // INC_B
			apply_test(8'h00, 8'h50, 4'b0110, "INC_B");
			apply_test(8'h00, 8'hFF, 4'b0110, "INC_B");

            // INC_B
			apply_test(8'h00, 8'h49, 4'b0111, "DEC_B");
			apply_test(8'h00, 8'h00, 4'b0111, "DEC_B");
            
            // CMP
			apply_test(8'd200, 8'd100, 4'b1000, "CMP (equal)");
			apply_test(8'd50, 8'd200, 4'b1000, "CMP (greater)");
			apply_test(8'd128, 8'd128, 4'b1000, "CMP (less)");

            // MUL_AB
			apply_test(8'hFE, 8'hFE, 4'b1001, "MUL_AB");//FF*FF 11111111 11111111
			apply_test(8'hFF, 8'hFF, 4'b1001, "MUL_AB");//00*00 11111111 11111111
			apply_test(8'hFE, 8'hFE, 4'b1001, "MUL_AB");//FF*FF 11111111 11111111

			apply_test(8'h03, 8'h04, 4'b1001, "MUL_AB"); //4*5  00000100 00000101
			apply_test(8'h00, 8'h05, 4'b1001, "MUL_AB");//1*6
			apply_test(8'hFF, 8'hFF, 4'b1001, "MUL_AB");//0*0
					
			apply_test(8'h60, 8'h60, 4'b1001, "MUL_AB");//70*70
			apply_test(8'h7E, 8'h7E, 4'b1001, "MUL_AB");//7F*7F
			apply_test(8'h08, 8'h08, 4'b1001, "MUL_AB");//9*9
			apply_test(8'h03, 8'h03, 4'b1001, "MUL_AB");//4*4
			apply_test(8'h07, 8'h07, 4'b1001, "MUL_AB");//08*08


            // SHIFT_MUL
			apply_test(8'hFE, 8'h00, 4'b1010, "SHIFT_MUL");//1
			apply_test(8'hFF, 8'h05, 4'b1010, "SHIFT_MUL");//0
			apply_test(8'hFE, 8'h00, 4'b1010, "SHIFT_MUL");//1
					
			apply_test(8'h04, 8'h03, 4'b1010, "SHIFT_MUL");
			apply_test(8'h00, 8'h05, 4'b1010, "SHIFT_MUL");

			apply_test(8'h7E, 8'h01, 4'b1010, "SHIFT_MUL");
			apply_test(8'h55, 8'h01, 4'b1010, "SHIFT_MUL");
			apply_test(8'h04, 8'h02, 4'b1010, "SHIFT_MUL");
			apply_test(8'h02, 8'h02, 4'b1010, "SHIFT_MUL");
			apply_test(8'h01, 8'h04, 4'b1010, "SHIFT_MUL");

            // S_ADD
			apply_test(8'h10, 8'h20, 4'b1011, "S_ADD");
			apply_test(8'h20, 8'h10, 4'b1011, "S_ADD");
			apply_test(8'h20, 8'h20, 4'b1011, "S_ADD");

			apply_test(8'h70, 8'h70, 4'b1011, "S_ADD");
			apply_test(8'hA0, 8'hA0, 4'b1011, "S_ADD");
			apply_test(8'h10, 8'h10, 4'b1011, "S_ADD");

			apply_test(8'h70, 8'h90, 4'b1011, "S_ADD");
			//apply_test(8'h90, 8'h20, 4'b1011, "S_ADD");

			apply_test(8'h00, 8'h00, 4'b1011, "S_ADD");
			apply_test(8'hFF, 8'hFF, 4'b1011, "S_ADD");
			apply_test(8'h00, 8'h00, 4'b1011, "S_ADD");

			// S_SUB
			apply_test(8'h50, 8'h30, 4'b1100, "S_SUB");
			apply_test(8'h30, 8'h50, 4'b1100, "S_SUB");
			apply_test(8'h40, 8'h40, 4'b1100, "S_SUB");

			apply_test(8'h70, 8'h90, 4'b1100, "S_SUB");
			apply_test(8'hA0, 8'h70, 4'b1100, "S_SUB");
			apply_test(8'h90, 8'h70, 4'b1100, "S_SUB");
			apply_test(8'h50, 8'h10, 4'b1100, "S_SUB");

			apply_test(8'h02, 8'hFF, 4'b1100, "S_SUB");
			apply_test(8'h10, 8'hF0, 4'b1100, "S_SUB");

			apply_test(8'h00, 8'h00, 4'b1100, "S_SUB");
			apply_test(8'hFF, 8'hFF, 4'b1100, "S_SUB");
			apply_test(8'h00, 8'h00, 4'b1100, "S_SUB");

		end
    endtask

    // Test logical operations
    task test_logical();
		begin
			apply_test(8'hAA, 8'h55, 4'b0000, "AND");
			apply_test(8'hAA, 8'h55, 4'b0001, "NAND");
			apply_test(8'hAA, 8'h55, 4'b0010, "OR");
			apply_test(8'hAA, 8'h55, 4'b0011, "NOR");
			apply_test(8'hFF, 8'hFF, 4'b0100, "XOR");
			apply_test(8'hFF, 8'hFF, 4'b0101, "XNOR");
			apply_test(8'hAA, 8'hAA, 4'b0110, "NOT_A");
			apply_test(8'hAA, 8'hAA, 4'b0111, "NOT_B");
			apply_test(8'b10101010, 8'd0, 4'b1000, "SHR1_A");
			apply_test(8'b01010101, 8'h00, 4'b1001, "SHL1_A");
			apply_test(8'h00, 8'b10101010, 4'b1010, "SHR1_B");
			apply_test(8'h00, 8'b01010101, 4'b1011, "SHL1_B");
			apply_test(8'hCC, 8'h0B, 4'b1100, "ROL_A_B");
			apply_test(8'hCC, 8'h6B, 4'b1100, "ROL_A_B");

			apply_test(8'hC1, 8'h60, 4'b1100, "ROL_A_B");
			apply_test(8'hC2, 8'h61, 4'b1100, "ROL_A_B");
			apply_test(8'hC3, 8'h62, 4'b1100, "ROL_A_B");
			apply_test(8'hC4, 8'h63, 4'b1100, "ROL_A_B");
			apply_test(8'hC5, 8'h64, 4'b1100, "ROL_A_B");
			apply_test(8'hC6, 8'h65, 4'b1100, "ROL_A_B");
			apply_test(8'hC6, 8'h66, 4'b1100, "ROL_A_B");
			apply_test(8'hC6, 8'h67, 4'b1100, "ROL_A_B");
			apply_test(8'hC6, 8'b000000x0, 4'b1100, "ROL_A_B");

			apply_test(8'hCC, 8'h0B, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h6B, 4'b1101, "ROR_A_B");

			apply_test(8'hCC, 8'h00, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h01, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h02, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h03, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h04, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h05, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h06, 4'b1101, "ROR_A_B");
			apply_test(8'hCC, 8'h07, 4'b1101, "ROR_A_B");
			apply_test(8'hC6, 8'b000000x0, 4'b1101, "ROR_A_B");
			
			apply_test(8'hC6, 8'b000000x0, 4'b1111, "extra");
			
        end
    endtask

    // Apply test and check
    task apply_test(
        input [7:0] a, b,
        input [3:0] cmd,
        input [80*8:1] test_name
    );
        begin
            OPA = a;
            OPB = b;
            CMD = cmd;
            
            @(posedge CLK);
            @(posedge CLK);
            
            test_count = test_count + 1;
            compare_outputs(cmp);
            if (cmp) begin
                $display("[PASS] %s: OPA=0x%h OPB=0x%h CMD=0x%h", 
                         test_name, a, b, cmd);
                //display_mismatch();
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
    task compare_outputs;
		output reg compare__outputs;
        begin
            compare__outputs = 1;

			if (MODE == 4'd1 && (CMD == 4'd9 || CMD == 4'd10) && INP_VALID == 2'b11)
				begin
            		abcd = 1;
					@(posedge CLK);		if (RES_dut !== 1'bx ) 		compare__outputs = 0;
					@(posedge CLK);		if (RES_dut !== RES_ref) 	compare__outputs = 0;
				end
			else	begin
            // Compare RES (handle Z values)
            if (RES_dut !== RES_ref) begin
		
                    compare__outputs = 0;
            end
			end
			
            // Compare flags (handle Z values)
            if (!compare_bit(COUT_dut, COUT_ref)) compare__outputs = 0;
            if (!compare_bit(OFLOW_dut, OFLOW_ref)) compare__outputs = 0;
            if (!compare_bit(G_dut, G_ref)) compare__outputs = 0;
            if (!compare_bit(E_dut, E_ref)) compare__outputs = 0;
            if (!compare_bit(L_dut, L_ref)) compare__outputs = 0;
            if (!compare_bit(ERR_dut, ERR_ref)) compare__outputs = 0;
        end
endtask

    // Compare single bit (handle Z)
    function compare_bit;
		input dut, ref;
        begin
            if (dut === ref)
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
