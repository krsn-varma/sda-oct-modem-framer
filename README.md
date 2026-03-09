# sda-oct-modem-framer

## Overview
This repository contains a Verilog implementation of an Optical Communications Terminal (OCT) Modem Frame Construction module. The design strictly adheres to the framing guidelines outlined in the SDA OCT Standard v4.0.0. It accepts raw payload data and constructs a fully formatted modem frame consisting of a Preamble, Header (with CRC-16 and Convolutional Encoding), Payload (with CRC-32), and Forward Error Correction (LDPC Parity).


## Architecture
The design utilizes a highly modular, synchronous architecture with a clean separation between control logic and the datapath.

### 1. FSM-Based Control Path
The heart of the module is a 6-state Finite State Machine (`IDLE`, `PREAMBLE`, `HEADER`, `PAYLOAD`, `PAY_CRC`, `PAY_FEC`). 
* **Deterministic Flow:** The FSM ensures that every field is transmitted in the exact order required by the SDA specification.
* **Handshake Logic:** The controller implements AXI-Stream `tvalid`/`tready` handshaking. This allows the FSM to "pause" the frame if complex sub-modules (like the Convolutional Encoder or LDPC) require extra clock cycles to process data.

### 2. Datapath and DSP
* **Header Path:** Includes a CRC-16 generator and a Rate 1/6 Convolutional Encoder (FEC-1).
* **Payload Path:** Features a CRC-32 generator and a 15-bit LFSR Scrambler. The scrambler ensures DC balance and high transition density for the optical receiver.
* **LDPC (FEC-2):** A behavioral timing model simulates the high-latency math required for LDPC parity generation, providing a realistic backpressure scenario for the FSM.


### Sub-Modules
* `crc16_serial` & `crc32_serial`: Serial CRC calculators for the Header and Payload fields.

* `header_fec1_encoder`: A Rate 1/6 Convolutional Encoder that expands the raw Header and Header-CRC bits.

* `payload_ldpc_behavioral`: A scalable behavioral model representing the payload LDPC (FEC-2) encoding process, utilizing AXI-Stream handshakes to simulate mathematical latency.

---

## Scaling Strategy and Verification
A key feature of this implementation is the use of **full parameterization** instead of hard-coded values. 

### Why we scale the fields:
In a production environment, frames consist of thousands of bits. For this project, we have scaled the `PAYLOAD_LEN` and `HEADER_LEN` down to smaller values (e.g., 16 bits and 2 bits).

1. **Simulation Velocity:** Reduces simulation time from minutes to milliseconds, allowing for rapid debugging.
2. **Visual Clarity:** Allows developers to verify the entire frame lifecycle (Preamble to Frame Done) within a single waveform window without manual bit-counting.
3. **Logic Integrity:** Since the design is parameterized, verifying the logic at a small scale proves the robustness of the FSM and handshaking interfaces, which remain identical at full standard scales.

---

## Assumptions and Constraints
To facilitate practical simulation and verification within standard testbench environments, the following assumptions and constraints were applied to this implementation:

* **Behavioral LDPC Modeling:** Full LDPC matrix calculation requires significant parallel processing and memory, which is beyond the scope of a framing module assignment. The `payload_ldpc_behavioral` module simulates the timing, latency, and AXI-Stream backpressure of an LDPC block without implementing the underlying matrix math.

* **Continuous vs. Discrete Framing:** The module is designed to support back-to-back framing (returning to `IDLE` for a single clock cycle before restarting). The provided testbench demonstrates a single discrete frame generation for clarity in the log output.

* **Synchronous Reset:** The system uses a synchronous active-low reset (`rst_n`) to ensure clean startup behavior in FPGA/ASIC hardware.

---

## How to Run the Simulation
1. Load all `.v` files (top-level module, sub-modules, and testbench) into your preferred Verilog simulator (e.g., ModelSim, Vivado, or EDA Playground).
2. Set `tb_oct_frame` as the top-level entity for the simulation.
3. Run the simulation. The testbench uses `$monitor` to print a highly readable, state-by-state log of the frame construction process directly to the console.

## File Structure
* `oct_frame_builder.v` - Top-level FSM and datapath multiplexer.
* `header_fec1_encoder.v` - Rate 1/6 Convolutional Encoder for the header.
* `payload_ldpc_behavioral.v` - Behavioral timing model for the LDPC encoder.
* `crc_modules.v` - Contains both `crc16_serial` and `crc32_serial` logic.
* `tb_oct_frame.v` - Self-checking testbench to verify frame generation and state transitions.
