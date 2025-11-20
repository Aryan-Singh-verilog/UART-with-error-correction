\# Low-Power UART Design with Activity-Based Clock Gating



\## Overview

This repository contains the implementation of a Universal Asynchronous Receiver-Transmitter (UART) enhanced with advanced power management features. Unlike standard UARTs, this design incorporates an intelligent Power Manager and Clock Gating logic to significantly reduce dynamic power consumption during idle states.



This project was developed during a research internship at IIIT Allahabad under the supervision of Prof. Manish Goswami.



\## Key Features

\- Full-Duplex Communication: Simultaneous transmission and reception.

\- Configurable Baud Rates: Supports 2400, 4800, 9600, and 19200 bps.

\- Configurable Parity: Supports None, Odd, and Even parity modes.

\- Advanced Power Management: Four distinct power modes managed by a Finite State Machine.

\- Clock Gating: Granular control over clock signals to TxUnit, RxUnit, and BaudGen to minimize switching power.

\- Error Detection: Parity, Framing, and Overrun error flags.



\## Power Management Architecture

The design transitions between modes based on activity flags. The Deep Sleep mode achieves approximately 53% reduction in total power consumption compared to Normal mode.



Power Consumption Analysis (at 100 MHz, 25% toggle rate):

\- Normal Mode: 157.4 mW

\- Low Power Mode: 114.4 mW

\- Sleep Mode: 87.4 mW

\- Deep Sleep Mode: 73.9 mW



\## System Architecture

The design follows a modular hierarchical structure:

\- Duplex (Top): Wrapper integrating Transmitter, Receiver, and Power Manager.

\- PowerManager: State machine controller for power modes.

\- TxUnit \& RxUnit: Core transmitter and receiver modules.

\- BaudGen: Configurable baud rate generator.

\- ErrorCheck: Parity generation and error detection logic.



!\[System Architecture](Pics/pic\_4.png)



\## Simulation and Verification

The design was verified using a comprehensive Verilog testbench covering 11 distinct test cases.

\- Test cases include: Basic transmission, Parity checks, Baud rate switching, and Power management transitions.



!\[Simulation Waveform](Pics/pic\_3.png)



\## Implementation Results

Synthesized and implemented using Xilinx Vivado.



Resource Utilization:

\- LUT: 112 (0.27%)

\- FF: 96 (0.12%)

\- IO: 38 (12.67%)

\- BUFG: 2 (6.25%)



!\[Resource Utilization](Pics/pic\_1.png)



\## Author

Aryan Singh

B.Tech in Electronics and Communication Engineering

Indian Institute of Information Technology, Manipur

