# ALU_PROJECT

# Parameterized ALU — RTL Design & Functional Verification

> **Arithmetic Logic Unit — 8-bit, 27-operation, two-stage pipelined design in Verilog HDL**  
> Fully verified against a combinational golden reference model with dual-model scoreboard methodology.

![Language](https://img.shields.io/badge/Language-Verilog%20HDL-blue)
![Operations](https://img.shields.io/badge/Operations-13%20Arithmetic%20%2B%2014%20Logic-green)
![Coverage](https://img.shields.io/badge/Statement%20Coverage-98.08%25-brightgreen)
![Sim Tool](https://img.shields.io/badge/Simulation-Vivado%20%2F%20Questa%20SIM-orange)
![Tests](https://img.shields.io/badge/Tests-All%20Passed%20%E2%9C%85-brightgreen)
![License](https://img.shields.io/badge/License-Academic%20Use-lightgrey)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Design Architecture](#2-design-architecture)
3. [Signal Reference](#3-signal-reference)
4. [Parameters & Configuration](#4-parameters--configuration)
5. [Supported Operations](#5-supported-operations)
6. [Timing Behaviour](#6-timing-behaviour)
7. [Working of the Design](#7-working-of-the-design)
8. [Testbench Architecture](#8-testbench-architecture)
9. [Simulation Results](#9-simulation-results)
10. [Coverage Report](#10-coverage-report)
11. [RTL Quality Checks](#11-rtl-quality-checks)
12. [Repository Structure](#12-repository-structure)
13. [How to Simulate](#13-how-to-simulate)
14. [Future Work](#14-future-work)

---

## 1. Project Overview

This project implements a fully parameterized, synthesizable **8-bit Arithmetic Logic Unit (ALU)** in Verilog HDL. The design supports **13 arithmetic** and **14 logical operations** across two selectable modes, including multi-cycle multiply operations and bitwise rotate commands with automatic error detection.

The ALU (`alu_design`) is parameterized by `DATA_WIDTH` (default 8 bits) and `RES_WIDTH` (default 16 bits), making it reusable across different datapath widths without any code modification.

Verification follows a **dual-model methodology**: the DUT is checked cycle-by-cycle against a purely combinational golden reference model (`alu_reference_model`) using a self-checking scoreboard. All 13 arithmetic and 14 logical operations were validated under all four `INP_VALID` encodings with zero failures.

**Key Highlights:**
- Two-stage synchronous pipeline with clock-enable gate
- Zero-latency combinational pre-compute block for add/subtract variants
- Multi-cycle multiply support (3-cycle latency) via internal counters — no external handshake required
- Input-validity (`INP_VALID`) gating on every command branch — invalid inputs assert `err` and zero the output
- Dual-model self-checking testbench with pass/fail logger and mismatch printer
- `'default_nettype none`, non-blocking assignments, two-process FSM style throughout
- **98.08% statement coverage**, **96.34% branch coverage** (Questa SIM)

---

## 2. Design Architecture

The `alu_design` module is organized into four logical layers:

```
  clk, rst, ce ──────────────────────────────────────────────────────────────────┐
                                                                                  │
  op_a [7:0] ──►┌─────────────────────┐                                          │
  op_b [7:0] ──►│  Combinational      │  uadd, uadd_cin,                         │
  c_in        ──►│  Pre-Compute        ├─ sadd, ssub  ──►┌──────────────────┐    │
                 │  (Zero Latency)     │  (wires only)   │   Stage 1        │    │
                 └─────────────────────┘                 │   Computation    │    │
                                                         │   Register       │    │
  mode ────────────────────────────────────────────────►│                  │    │
  cmd  [3:0] ─────────────────────────────────────────►│  Selects result  │    │
  inp_valid [1:0] ──────────────────────────────────── ►│  based on        ├──► │──► Stage 2
                                                         │  mode + cmd      │    │    Output
                                                         │  + inp_valid     │    │    Register
                                                         │                  │    │        │
                                                         │  Multi-cycle:    │    │        ▼
                                                         │  count  (cmd 9)  │    │   result [15:0]
                                                         │  count2 (cmd 10) │    │   c_out
                                                         │  temp1/2/3       │    │   overflow
                                                         └──────────────────┘    │   G / E / L
                                                                                  │   err
                                                                                  └───────────────
```

### Four Internal Layers

**1. Combinational Pre-Compute (Zero Latency)**
Computes all addition/subtraction variants as wires before the clock edge, making them immediately available to Stage 1:
```verilog
wire [DATA_WIDTH:0] uadd_result     = {1'b0, op_a} + {1'b0, op_b};
wire [DATA_WIDTH:0] uadd_cin_result = {1'b0, op_a} + {1'b0, op_b} + {{DATA_WIDTH{1'b0}}, c_in};
wire signed [DATA_WIDTH:0] sadd_result = s_a + s_b;
wire signed [DATA_WIDTH:0] ssub_result = s_a - s_b;
```

**2. Stage 1 — Computation Register**
Synchronous `always` block that decodes `mode` and `cmd`, validates `inp_valid`, implements the multi-cycle state machine, and stores results in Stage-1 registers.

**3. Multi-Cycle Pipeline Registers**
Counters `count` / `count2` and temporaries `temp1`, `temp2`, `temp3` hold intermediate products across clock cycles for `cmd 9` (INC-and-Multiply) and `cmd 10` (Shift-and-Multiply). The two counters are mutually exclusive.

**4. Stage 2 — Output Register**
Re-latches all Stage-1 outputs on the next clock edge (still gated by `ce`), adding exactly one additional registered cycle before results appear on the output ports.

---

## 3. Signal Reference

### Inputs

| Signal | Width | Description |
|---|---|---|
| `clk` | 1-bit | System clock — all registers are posedge triggered |
| `rst` | 1-bit | Synchronous active-high reset — clears all registers and counters to 0 |
| `ce` | 1-bit | Clock Enable — when low, all pipeline registers stall and hold their value |
| `mode` | 1-bit | Operation mode: `0` = Logic, `1` = Arithmetic |
| `c_in` | 1-bit | Carry-in for `ADD_CIN` (cmd 2) and `SUB_CIN` (cmd 3) |
| `op_a` | 8-bit | Operand A (`DATA_WIDTH` bits) |
| `op_b` | 8-bit | Operand B (`DATA_WIDTH` bits) |
| `inp_valid` | 2-bit | Operand validity encoding (see table below) |
| `cmd` | 4-bit | Command selector — operation to perform within the selected mode |

**`inp_valid` Encoding:**

| `inp_valid` | Meaning |
|---|---|
| `2'b11` | Both operands valid — dual-operand operations execute normally |
| `2'b01` | Only A valid — A-only operations succeed; dual-operand ops assert `err` |
| `2'b10` | Only B valid — B-only operations succeed; dual-operand ops assert `err` |
| `2'b00` | Neither valid — all operations assert `err` and output zero |

### Outputs

| Signal | Width | Description |
|---|---|---|
| `result` | 16-bit | Operation result (`RES_WIDTH = 2×DATA_WIDTH`), zero-extended |
| `c_out` | 1-bit | Carry-out flag — set on arithmetic carry from MSB |
| `overflow` | 1-bit | Overflow flag — set on signed arithmetic overflow or unsigned borrow |
| `G` | 1-bit | Greater-than flag: `op_a > op_b` (Comparator only) |
| `E` | 1-bit | Equal flag: `op_a == op_b` (Comparator only) |
| `L` | 1-bit | Less-than flag: `op_a < op_b` (Comparator only) |
| `err` | 1-bit | Error flag — asserted when `inp_valid` is insufficient, command is out of range, or rotate shift amount has non-zero upper bits |

---

## 4. Parameters & Configuration

| Parameter | Default | Description |
|---|---|---|
| `DATA_WIDTH` | `8` | Operand width in bits |
| `RES_WIDTH` | `16` | Result width in bits (must be `2 × DATA_WIDTH`) |

To use a wider ALU (e.g. 16-bit operands, 32-bit result), instantiate as:
```verilog
alu_design #(.DATA_WIDTH(16), .RES_WIDTH(32)) u_alu ( ... );
```
No other changes are required — all internal counter widths and pre-compute wires scale automatically.

---

## 5. Supported Operations

### Arithmetic Operations (`mode = 1`)

| CMD | Mnemonic | Operation | Cycles | `inp_valid` |
|---|---|---|---|---|
| 0 | `ADD` | `op_a + op_b`; `c_out` on carry | 2 | `2'b11` |
| 1 | `SUB` | `op_a - op_b`; `overflow` if borrow | 2 | `2'b11` |
| 2 | `ADD_CIN` | `op_a + op_b + c_in` | 2 | `2'b11` |
| 3 | `SUB_CIN` | `op_a - op_b - c_in` | 2 | `2'b11` |
| 4 | `INC_A` | `op_a + 1` | 2 | `2'b11` or `2'b01` |
| 5 | `DEC_A` | `op_a - 1` | 2 | `2'b11` or `2'b01` |
| 6 | `INC_B` | `op_b + 1` | 2 | `2'b11` or `2'b10` |
| 7 | `DEC_B` | `op_b - 1` | 2 | `2'b11` or `2'b10` |
| 8 | `CMP` | Sets `G`/`E`/`L` flags: `op_a` vs `op_b` | 2 | `2'b11` |
| 9 | `MUL_AB` | `(op_a + 1) × (op_b + 1)` | 3 | `2'b11` |
| 10 | `SHIFT_MUL` | `(op_a << 1) × op_b` | 3 | `2'b11` |
| 11 | `S_ADD` | Signed `op_a + op_b`; `overflow` flag | 2 | `2'b11` |
| 12 | `S_SUB` | Signed `op_a - op_b`; `overflow` flag | 2 | `2'b11` |

### Logic Operations (`mode = 0`)

| CMD | Mnemonic | Operation | `inp_valid` |
|---|---|---|---|
| 0 | `AND` | `op_a & op_b` | `2'b11` |
| 1 | `NAND` | `~(op_a & op_b)` | `2'b11` |
| 2 | `OR` | `op_a \| op_b` | `2'b11` |
| 3 | `NOR` | `~(op_a \| op_b)` | `2'b11` |
| 4 | `XOR` | `op_a ^ op_b` | `2'b11` |
| 5 | `XNOR` | `~(op_a ^ op_b)` | `2'b11` |
| 6 | `NOT_A` | `~op_a` | `2'b11` or `2'b01` |
| 7 | `NOT_B` | `~op_b` | `2'b11` or `2'b10` |
| 8 | `SHR_A` | `op_a >> 1` | `2'b11` or `2'b01` |
| 9 | `SHL_A` | `op_a << 1` | `2'b11` or `2'b01` |
| 10 | `SHR_B` | `op_b >> 1` | `2'b11` or `2'b10` |
| 11 | `SHL_B` | `op_b << 1` | `2'b11` or `2'b10` |
| 12 | `ROL_A_B` | Rotate-left A by `op_b[2:0]` bits; `err` if `op_b[7:3] ≠ 0` | `2'b11` |
| 13 | `ROR_A_B` | Rotate-right A by `op_b[2:0]` bits; `err` if `op_b[7:3] ≠ 0` | `2'b11` |

> Commands outside the valid range (≥ 14 in logic mode, ≥ 13 in arithmetic mode) assert `err` and output zero.

---

## 6. Timing Behaviour

The ALU is a **two-stage synchronous pipeline** clocked at the system frequency:

```
  Inputs applied    Stage 1 latches    Stage 2 latches    Output valid
       │                  │                  │                  │
  ─────▼──────────────────▼──────────────────▼──────────────────▼────►
      Cycle N          Cycle N+1          Cycle N+2
  (cmd, op_a, op_b)  (result_s1)        (result port)
```

| Operation Type | Commands | Pipeline Latency |
|---|---|---|
| Single-cycle | cmd 0–8, 11–12 | **2 clock cycles** (Stage 1 + Stage 2) |
| Multi-cycle | cmd 9, 10 (`MUL_AB`, `SHIFT_MUL`) | **3 clock cycles** (latch → compute → Stage 2) |

**Multi-cycle detail (cmd 9 — INC-and-Multiply):**
```
  Cycle N   (count=0): latch  temp1 = op_a+1,  temp2 = op_b+1;  count → 1
  Cycle N+1 (count=1): compute result_s1 = temp1 × temp2;        count → 0
  Cycle N+2           : Stage 2 registers result → output ports
```

**Multi-cycle detail (cmd 10 — Shift-and-Multiply):**
```
  Cycle N   (count2=0): latch  temp3 = op_a<<1, temp2 = op_b;   count2 → 1
  Cycle N+1 (count2=1): compute result_s1 = temp3 × temp2;       count2 → 0
  Cycle N+2            : Stage 2 registers result → output ports
```

**Clock Enable (`ce`):** When deasserted, the entire pipeline stalls — all Stage-1 and Stage-2 registers hold their current values.

**Reset (`rst`):** Synchronous; clears every register, counter, and temporary to 0 on the next rising clock edge.

---

## 7. Working of the Design

### Input Phase
On each rising clock edge (with `ce` high and `rst` low), the combinational pre-compute block has already resolved all addition/subtraction variants as wires. Stage 1 reads `mode` and `cmd` to select the correct computation path, then validates `inp_valid` within each branch.

### Operation Phase

**Single-cycle (cmd 0–8, 11–12):** Result is computed and registered into Stage-1 registers in one clock. Signed operations use `sadd_result` / `ssub_result` pre-compute wires to detect overflow from sign-bit extension.

**Multi-cycle (cmd 9, 10):** Stage 1 uses internal counters to sequence across two sub-cycles before producing `result_s1`. The counters `count` and `count2` are mutually exclusive — only one multi-cycle operation can be active at a time.

**Invalid inputs:** If `inp_valid` is insufficient for the selected command, `result_s1` is zeroed and `err_s1` is asserted. Stage 2 propagates this to the output ports.

### Output Phase
Stage 2 re-latches all Stage-1 outputs (`result`, `c_out`, `overflow`, `G`, `E`, `L`, `err`) on the next clock edge, still gated by `ce`. For multi-cycle operations, the valid output appears one cycle later (total 3 cycles from input).

---

## 8. Testbench Architecture

The testbench (`alu_testbench`) instantiates both the DUT and the reference model, drives them with identical stimulus, and compares every output port via a self-checking scoreboard.

```
                    ┌─────────────────────────────────────────────────┐
                    │               alu_testbench                      │
                    │                                                   │
                    │   ┌──────────────┐      ┌──────────────────┐     │
  Stimulus ─────────┼──►│     DUT      ├─────►│                  │     │
  Driver            │   │ (alu_design) │      │   Scoreboard     ├──►  │ pass / fail
  (apply_test)      │   └──────────────┘      │ (compare_outputs)│     │ log + count
                    │                         │                  │     │
                    │   ┌──────────────┐      │  === operator    │     │
  Same stimulus ────┼──►│  Reference   ├─────►│  handles X/Z     │     │
                    │   │  Model       │      └──────────────────┘     │
                    │   │ (comb. only) │                                │
                    │   └──────────────┘                                │
                    └─────────────────────────────────────────────────┘
```

### Testbench Components

| Component | Description |
|---|---|
| **Clock Generator** | 100 MHz clock (`CLK` toggling every 5 ns) in a `forever` loop; all stimulus synchronized to rising edges |
| **`alu_reference_model`** | Purely combinational (`always @(*)`) golden model — mirrors all DUT operations; produces expected output immediately after inputs change |
| **`test_arithmetic()`** | Sweeps all 13 arithmetic commands with boundary-value operands (`0x00`, `0x01`, `0xFF`, `0xFE`, etc.) and all `c_in` states |
| **`test_logical()`** | Sweeps all 14 logic commands with alternating-bit operands (`0xAA`/`0x55`) and rotation amounts 0–7 plus out-of-range upper bits |
| **`apply_test()`** | Drives one test vector, waits pipeline latency, calls `compare_outputs`, increments pass/fail counters, logs result |
| **`compare_outputs`** | Compares every output using `===` (case-equality, handles X/Z); adds 2 extra clock waits for multi-cycle commands |
| **`display_mismatch`** | Prints full DUT and REF output buses on any failure for rapid root-cause analysis |
| **Pass/Fail Logger** | Maintains `pass_count`, `fail_count`, `test_count`; prints final summary before `$finish` |

### INP_VALID Coverage Strategy

Both task groups (`test_arithmetic` and `test_logical`) are called **four times each** — once per `inp_valid` encoding — to verify that the DUT correctly gates every operation on partial or invalid operand conditions:

| Run | `inp_valid` | Expected Behaviour |
|---|---|---|
| 1 | `2'b11` | All operations execute normally |
| 2 | `2'b01` | A-only ops succeed; dual-operand ops assert `err` |
| 3 | `2'b10` | B-only ops succeed; dual-operand ops assert `err` |
| 4 | `2'b00` | All operations assert `err` and output zero |

---

## 9. Simulation Results

Simulation was performed using **Vivado Simulator** for functional validation and **Questa SIM** for coverage analysis.

### Waveform Analysis

Key observations from the arithmetic mode sweep waveform:

- The `result` bus transitions **1–2 cycles after** command inputs change, confirming the two-stage pipeline latency
- For `cmd 9` and `cmd 10` (visible around the 200–400 ns region), the `result` bus holds a don't-care intermediate value before settling to the correct product — consistent with 3-cycle latency
- `c_out` pulses correctly on unsigned addition carry-outs
- `err` asserts cleanly on invalid commands and invalid `inp_valid` encodings, then de-asserts when valid inputs are restored
- `inp_valid` transitions through all four encodings across the sweep, exercising all error-gating paths

### Testbench Log Summary

```
=== TEST SUMMARY ===
Total Tests : N
PASS        : N
FAIL        : 0

*** ALL TESTS PASSED ***
```

All DUT outputs matched the reference model across every test vector — validating correct implementation of all 13 arithmetic and 14 logical operations under all four `INP_VALID` conditions.

### Test Cases Covered

**Arithmetic Corner Cases:**

| Operation | Corner Cases Exercised |
|---|---|
| `ADD` | Normal (1+1), carry-overflow (0xFF+1), zero (0+0) |
| `SUB` | Equal (1-1), borrow (0-1), large equal (0x50-0x50) |
| `ADD_CIN` | CIN=1 with 0xFF (carry chain), CIN=0, normal 1+1+1 |
| `SUB_CIN` | CIN=1 with borrow, zero operands, CIN=0 |
| `INC_A` / `DEC_A` | Mid-value (0x50), max rollover (0xFF), underflow (0x00) |
| `INC_B` / `DEC_B` | Mid-value (0x50), max rollover (0xFF), underflow (0x00) |
| `CMP` | All three flag paths: A>B, A<B, A=B |
| `MUL_AB` | Large operands (0xFE×0xFF), small (3×4), zero, boundary |
| `SHIFT_MUL` | MSB-set operand, zero-multiply, shift combinations |
| `S_ADD` / `S_SUB` | Positive overflow, negative overflow, zero, max signed |

**Logical Corner Cases:**

| Operation | Corner Cases Exercised |
|---|---|
| `AND` / `NAND` | Alternating pattern 0xAA/0x55 (no common bits) |
| `OR` / `NOR` | Complementary OR pattern |
| `XOR` / `XNOR` | All-ones operands (XOR = 0x00, XNOR = 0xFF) |
| `NOT_A` / `NOT_B` | 0xAA pattern (bitwise complement) |
| `SHR_A/B` / `SHL_A/B` | Alternating bit pattern, shift direction check |
| `ROL_A_B` / `ROR_A_B` | All amounts 0–7; upper-bit `err` path via 0x6B |
| Invalid CMD | `cmd = 0xF` in both modes — `err` asserted |

---

## 10. Coverage Report

Code coverage was collected using **Questa SIM**. The coverage HTML report was generated after running the full testbench suite.

### Overall Summary

| Design Scope | Hits % | Coverage % |
|---|---|---|
| `alu_testbench` (total) | 86.98% | **77.92%** |
| `test_arithmetic` | 100.00% | 100.00% |
| `test_logical` | 100.00% | 100.00% |
| `apply_test` | 100.00% | 100.00% |
| `compare_outputs` | 97.29% | 98.33% |
| `compare_bit` | 100.00% | 100.00% |
| `display_mismatch` | 100.00% | 100.00% |
| `dut` | 95.61% | **97.62%** |
| `ref` | 93.50% | 74.98% |

### Coverage by Type (DUT)

| Coverage Type | Bins | Hits | Misses | Coverage |
|---|---|---|---|---|
| Statements | 521 | 511 | 10 | **98.08%** |
| Branches | 246 | 237 | 9 | **96.34%** |
| FEC Expressions | 17 | 5 | 12 | 29.41% |
| FEC Conditions | 27 | 24 | 3 | 88.88% |
| Toggles | 710 | 546 | 164 | 76.90% |

### Coverage Observations

- All 13 arithmetic `case` branches and all 14 logic `case` branches were exercised
- The `default` (invalid cmd) branch was hit by driving `cmd = 4'hF` in both modes
- Multi-cycle state machine transitions (`count`: 0→1→0 for cmd 9; `count2`: 0→1→0 for cmd 10) were fully exercised
- `INP_VALID` error branches were triggered for every applicable command across all four encodings
- Rotate commands with upper-bit error (`op_b[7:3] ≠ 0`) were covered via operands such as `0x6B`
- Stage-2 output pipeline toggling confirmed for all output signals

### Reference Model Bug Fixes Identified During Verification

Three bugs were caught in the original reference model and corrected — demonstrating the value of the dual-model methodology:

| # | Bug | Root Cause | Fix |
|---|---|---|---|
| 1 | `INP_VALID` never matched for cmd 9/10/11/12 | Used decimal `11` instead of `2'b11` — a 2-bit signal can never equal decimal 11 | Changed to `2'b11` |
| 2 | `CMP` output produced X/Z toggles | Assigned `9'bz` to a 16-bit `result` register | Changed to `16'b0` |
| 3 | Overflow flag never set for `S_ADD` / `S_SUB` | Incorrect `INP_VALID` check prevented the overflow branch from being entered | Corrected condition to `2'b11` |

---

## 11. RTL Quality Checks

| Check | Observation | Status |
|---|---|---|
| `` `default_nettype none `` | Declared in all RTL files — undriven signals are compile errors, not silent X | ✅ PASS |
| Non-blocking assignments | All sequential blocks use `<=` — correct flip-flop modelling, no race conditions | ✅ PASS |
| Two-process FSM style | Stage-1 computation and Stage-2 output registration are separate `always` blocks | ✅ PASS |
| Default case | Every `case` statement has a `default` branch that asserts `err` and zeroes outputs — no latches | ✅ PASS |
| Parameterization | `DATA_WIDTH` and `RES_WIDTH` scale all internal widths without code changes | ✅ PASS |
| Latch inference | No latches — all outputs registered | ✅ PASS |
| Combinational loops | No combinational feedback detected | ✅ PASS |
| Reset completeness | All registers and counters assigned in the synchronous reset branch | ✅ PASS |

---

## 12. Repository Structure

```
alu-rtl/
├── alu_design.v            # Top-level ALU — parameterized, two-stage pipeline
├── alu_reference_model.v   # Combinational golden reference model (testbench use only)
├── alu_testbench.v         # Self-checking testbench — scoreboard + pass/fail logger
└── README.md
```

---

## 13. How to Simulate

### Prerequisites
- **Questa SIM** (Mentor/Siemens) or **Vivado Simulator** — Verilog-2001 support required

### Steps (Questa SIM)

```bash
# 1. Compile all design and testbench files
vlog alu_design.v alu_reference_model.v alu_testbench.v

# 2. Launch simulation
vsim -coverage work.alu_testbench

# 3. Add signals and run
add wave -recursive *
run -all

# 4. Generate coverage report
coverage report -html -output coverage_report/
```

### Steps (Vivado Simulator)

```tcl
# 1. Add source and simulation files
add_files alu_design.v
add_files -fileset sim_1 {alu_reference_model.v alu_testbench.v}
set_property top alu_testbench [get_filesets sim_1]

# 2. Launch and run simulation
launch_simulation
run all
```

> **Tip:** The testbench automatically accounts for 2-cycle pipeline latency on normal operations and 3-cycle latency on `cmd 9` / `cmd 10`. No manual timing adjustments are needed when changing `DATA_WIDTH` — the reference model scales with the parameter automatically.

---

## 14. Future Work

| Enhancement | Description |
|---|---|
| **Division Support** | Add a restoring or non-restoring divider as additional multi-cycle commands (e.g., cmd 13/14) |
| **Handshake Interface** | Replace implicit cycle-count synchronization for multi-cycle ops with a `valid`/`ready` handshake to make latency-agnostic |
| **Formal Verification** | Apply bounded model checking (e.g., Yosys/sby) to formally prove DUT output always equals the reference model for all input combinations |
| **Wider Parameterization** | Validate 16-bit and 32-bit configurations; add regression tests that auto-adapt to `DATA_WIDTH` |
| **SystemVerilog Covergroups** | Add `covergroup` constructs to measure cross-coverage between `mode`, `cmd`, and all four `inp_valid` encodings |
| **Power Analysis** | Use Vivado power estimator to characterize dynamic power across the full operation set |
| **FPGA Demo** | Map the design to an FPGA board with a seven-segment display driver to demonstrate live ALU output |

---

## Author

**Vedant Vasant Kunjar** — Roll No. 6948  
Tools: Vivado 2024.x (Xilinx/AMD) · Questa SIM (Mentor/Siemens EDA)  
Language: Verilog HDL (IEEE 1364-2001)

---

*For academic and engineering reference use only.*
