\# Low-Power UART Design with Activity-Based Clock Gating



!\[Language](https://img.shields.io/badge/Language-Verilog-blue) !\[Tool](https://img.shields.io/badge/Tool-Xilinx%20Vivado-green) !\[Status](https://img.shields.io/badge/Status-Completed-brightgreen)



\## 📌 Overview

This repository contains the implementation of a \*\*Universal Asynchronous Receiver-Transmitter (UART)\*\* enhanced with advanced power management features. Unlike standard UARTs, this design incorporates an intelligent \*\*Power Manager\*\* and \*\*Clock Gating\*\* logic to significantly reduce dynamic power consumption during idle states.



This project was developed during a research internship at \*\*IIIT Allahabad\*\* (Summer 2025).



📄 \*\*\[Read the Full Project Report](report.pdf)\*\*



---



\## ✨ Key Features

\* \*\*Full-Duplex Communication:\*\* Simultaneous transmission and reception.

\* \*\*Configurable Parameters:\*\*

&nbsp;   \* \*\*Baud Rates:\*\* 2400, 4800, 9600, 19200 bps.

&nbsp;   \* \*\*Parity:\*\* None, Odd, Even.

\* \*\*Advanced Power Management:\*\* Four distinct power modes managed by a Finite State Machine (FSM).

\* \*\*Clock Gating:\*\* granular control over clock signals to `TxUnit`, `RxUnit`, and `BaudGen` to minimize switching power.

\* \*\*Error Detection:\*\* Parity, Framing, and Overrun error flags.



---



\## 🔋 Power Management Architecture

The core innovation of this design is the \*\*PowerManager\*\* module, which transitions the system between modes based on activity flags (`tx\_active`, `rx\_active`) and user inputs.



| Mode | Description | Power Consumption (Est.) |

| :--- | :--- | :--- |

| \*\*Normal\*\* | All modules active. Full performance. | 157.4 mW |

| \*\*Low Power\*\* | Clocks gated; enabled only during active data transfer. | 114.4 mW |

| \*\*Sleep\*\* | TX disabled. RX active (waiting for start bit). | 87.4 mW |

| \*\*Deep Sleep\*\* | All clocks disabled. Wake-up requires reset/interrupt. | \*\*73.9 mW\*\* |



\*> \*\*Impact:\*\* Deep Sleep mode achieves a \*\*~53% reduction\*\* in total power consumption compared to Normal mode.\*



---



\## ⚙️ System Architecture

The design follows a modular hierarchical structure:



!\[System Architecture](Pics/pic\_4.png)

\*Figure 1: RTL Schematic showing the Duplex wrapper connecting the Transmitter, Receiver, and Power Manager.\*



\### Modules

1\.  \*\*Duplex (Top):\*\* Wraps all sub-modules and handles I/O mapping.

2\.  \*\*PowerManager:\*\* Monitors activity and controls clock enable signals.

3\.  \*\*TxUnit / RxUnit:\*\* Handles serialization (PISO) and deserialization (SIPO).

4\.  \*\*BaudGen:\*\* Generates precise timing pulses based on the system clock.

5\.  \*\*ErrorCheck:\*\* Computes and verifies parity bits.

6\.  \*\*ClockGate:\*\* Technology-independent clock gating latch/FF logic.



---



\## 📊 Simulation \& Verification

The design was verified using a comprehensive Verilog testbench (`tb.v`) covering \*\*11 distinct test cases\*\*, including:

\* Basic transmission (No Parity, Odd, Even).

\* Baud rate switching on-the-fly.

\* Power mode transitions (verifying logic retention when clocks are gated).

\* Error injection and detection.



!\[Simulation Waveform](Pics/pic\_3.png)

\*Figure 2: Simulation waveform demonstrating successful data transmission and flag assertion.\*



---



\## 📉 Implementation Results

Synthesized and implemented using \*\*Xilinx Vivado\*\*. The design is highly optimized for FPGA resources.



| Resource | Utilization | Utilization % |

| :--- | :--- | :--- |

| \*\*LUT\*\* | 112 | 0.27% |

| \*\*FF\*\* | 96 | 0.12% |

| \*\*IO\*\* | 38 | 12.67% |



!\[Resource Utilization](Pics/pic\_1.png)



---



\## 🚀 How to Run

1\.  \*\*Clone the repository:\*\*

&nbsp;   ```bash

&nbsp;   git clone \[https://github.com/Aryan-Singh-verilog/UART\_with\_power\_saving.git](https://github.com/Aryan-Singh-verilog/UART\_with\_power\_saving.git)

&nbsp;   ```

2\.  \*\*Open in Vivado:\*\*

&nbsp;   \* Create a new project.

&nbsp;   \* Add all files from the `RTL/` folder as Design Sources.

&nbsp;   \* Add `tb.v` as the Simulation Source.

3\.  \*\*Run Simulation:\*\*

&nbsp;   \* Run Behavioral Simulation to view waveforms.



---



\## 👨‍💻 Author

\*\*Aryan Singh\*\*

\* \*\*Institute:\*\* IIIT Manipur

\* \*\*Project Type:\*\* Research Internship (IIIT Allahabad)

\* \*\*Domain:\*\* VLSI / Digital Design



---

