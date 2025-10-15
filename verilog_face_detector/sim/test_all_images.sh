#!/bin/bash
# Test single image.txt with Verilog face detector
echo "Testing image.txt..."
iverilog -o run_sim tb_face_detector.v ../src/*.v
vvp run_sim
echo "\nOpening GTKWave with pre-configured signals..."
gtkwave waveform.vcd waveform.gtkw &