# UART with Asynchronous FIFO

A Verilog implementation of a UART (Universal Asynchronous Receiver/Transmitter) with an asynchronous FIFO for clock-domain crossing between transmitter and receiver domains.

## Overview
This repository contains a Verilog UART core integrated with an asynchronous FIFO to safely cross data between different clock domains. The design is suitable for FPGA implementation and simulation.

## Features
- UART transmitter and receiver (configurable baud rate)
- Asynchronous FIFO for safe transfer between different clock domains
- Parameterizable data width and FIFO depth
- Simple testbench(s) for simulation
- Suitable for synthesis on common FPGA families

## Requirements
- Verilog simulator: Icarus Verilog, ModelSim/Questa, or similar
- Synthesis tool for target FPGA (e.g., Xilinx Vivado, Intel Quartus)
- Make (optional) or shell scripts for running simulations

## Parameters & Configuration
Typical parameters you may find or add:
- CLOCK_FREQ — system clock frequency (Hz)
- BAUD_RATE — UART baud rate (bps)
- DATA_BITS — number of data bits (e.g., 8)
- FIFO_DEPTH — depth of asynchronous FIFO

Consult the top-level module comments for exact parameter names.

## Tests
- Use the provided testbench(es) in tb/ to validate transmit and receive functionality.
- Add directed tests to exercise corner cases (start/stop bits, buffer full/empty).
- Test long stream stress with large amounts of data.

## Author
thienhau
