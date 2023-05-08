# Verilog pi calculator

This is a hardware design that calculates pi to a million digits. 

![A screenshot of the time it takes to calculate a million digits (13 hours).](https://github.com/calebabutler/verilog-pi-calculator/blob/main/time_screenshot.png?raw=true)

I have simulated the design with QuestaSim and Verilator. Verilator is free, open source and much faster than QuestaSim, so I recommend it if you want to try the simulator. It is difficult to get Verilator working on Windows, so if you are running Windows I recommend using Windows Subsystem for Linux (WSL).

How to simulate with Verilator
==============================

First, install Verilator and Git. If you are running Debian or Ubuntu:

    > sudo apt install verilator git

Next, download the git repository:

    > git clone https://github.com/calebabutler/verilog-pi-calculator.git

Make the build.sh script executable if it is not already:

    > chmod +x build.sh

Run the build.sh script:

    > ./build.sh

Then run the simulator:

    > ./obj_dir/Vpi_calculator
