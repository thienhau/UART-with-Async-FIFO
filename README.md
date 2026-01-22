# UART Full-Duplex with Asynchronous FIFO (CDC-Ready)

A robust Verilog implementation of a UART core designed for SoC integration. This design features **Asynchronous FIFOs** to facilitate reliable data transfer between a high-speed **System Clock Domain** and a low-speed **UART Baud-rate Domain**.

## 📖 Overview
In modern FPGA/ASIC designs, peripherals like UART operate at much lower frequencies than the main system bus. This repository provides a complete solution that bridges these two domains using Asynchronous FIFOs. It prevents **metastability** and ensures data integrity during **Clock Domain Crossing (CDC)**.



## ✨ Key Features
- **True Full-Duplex:** Independent Transmitter and Receiver modules for simultaneous bi-directional communication.
- **Robust CDC Architecture:** - Uses **Asynchronous FIFOs** for both TX and RX paths to decouple different clock regions.
    - Implements **Gray-coded pointers** to safely cross clock boundaries.
    - **Multi-stage synchronizers** (Double Flip-Flop) used for all pointer transfers.
- **Input Synchronization:** The RX input pin is protected by a double-flop synchronizer to handle external asynchronous signals and prevent metastability.
- **Oversampling Logic:** The RX core samples data at the center of each bit period to maximize timing margin and baud-rate error tolerance.
- **Highly Parameterizable:** Easily adjust FIFO depth, data width, and baud-rate constants.



## 🏗️ System Architecture
The design acts as a bridge between two distinct clock regions:
1. **System Domain (`sys_clk`):** High-speed domain where your main logic, CPU, or Bus (AXI/APB) operates.
2. **UART Domain (`uart_clk`):** Low-speed domain dedicated to serial bit-shifting at the target baud rate.

| Component | Write Side (Source) | Read Side (Destination) | Clock Crossing |
| :--- | :--- | :--- | :--- |
| **TX FIFO** | System Domain (`sys_clk`) | UART Domain (`uart_clk`) | Fast to Slow |
| **RX FIFO** | UART Domain (`uart_clk`) | System Domain (`sys_clk`) | Slow to Fast |

## 🧪 Parameters & Configuration
The top-level module `uart_full_duplex` uses the following parameters:
- `CLK_PER_BIT`: Number of `uart_clk` cycles per UART bit.
  - *Calculation:* CLK_PER_BIT = f_{uart_clk}/{BaudRate}
  - *Example:* For 100MHz clock and 115200 Baud, CLK_PER_BIT approx 86.8.
- `DATA_WIDTH`: Size of the data packet (default: 8 bits).
- `ADDR_WIDTH`: Determines FIFO depth (Depth = 2^{ADDR_WIDTH}).

## 💻 Requirements
- **Simulation:** ModelSim, Icarus Verilog, QuestaSim, or Vivado Simulator.
- **Synthesis:** Xilinx Vivado (Compatible with Arty Z7/Zynq), Intel Quartus, or Yosys.

## 🔍 Testing & Verification
The design is rigorously verified using a self-checking testbench architecture. It features an automated **Scoreboard** for end-to-end data integrity validation across different clock domains.

### 📊 Verification Methodology
- **Loopback Testing:** The `uart_tx_pin` is externally tied to `uart_rx_pin` to verify the complete transceiver chain.
- **Automated Scoreboard:** A golden reference model tracks all transmitted bytes and compares them against received data in real-time, reporting mismatches instantly.
- **Asynchronous Environment:** The simulation environment uses two independent clocks to mimic real-world CDC conditions:
    - **System Domain:** 100MHz (`sys_clk`)
    - **UART Domain:** 10MHz (`uart_clk`)

### 📋 Test Scenarios
The test suite (comprising 20 comprehensive tests) covers:
1. **Data Integrity (Group 1):** Validates standard patterns (`0x55`, `0xAA`, `0xFF`) to ensure no bit-flips during serialization or FIFO buffering.
2. **FIFO & Flow Control Stress (Group 2):**
    - **Burst Transfers:** Sending rapid sequences (up to 20 bytes) to exercise the `tx_fifo_full` back-pressure mechanism.
    - **Rapid Random:** Verifies FIFO stability when data is fed in at high speed.
3. **Timing & Asynchronous Robustness (Group 3):**
    - **CDC Handshaking:** Checks the synchronization of Gray code pointers between two clock domains.
    - **Long Stream Stress:** Continuously transmits **1000 random bytes** to ensure zero drift.
4. **Corner Cases (Group 4):**
    - **Reset Recovery:** Activates a reset during data transmission to test the ability to recover the IDLE state.
    - **Random Delays:** Simulates random delays in input data.
