# Verilog Face Detector Project

This project implements a Haar Cascade face detector in Verilog hardware description language.

## Project Structure

```
verilog_face_detector/
├── data/
│   ├── haarcascade_frontalface_default.xml    # OpenCV cascade (original)
│   └── cascade_data.mem                       # Parsed for Verilog
├── src/                                       # Verilog modules (8 files)
│   ├── face_detector.v
│   ├── control_fsm.v
│   ├── integral_image.v
│   ├── feature_calculator.v
│   ├── weak_classifier.v
│   ├── stage_evaluator.v
│   ├── haar_cascade_rom.v
│   └── feature_rom.v
├── sim/
│   ├── tb_face_detector.v                     # Testbench
│   ├── image.txt                              # Test image (64x64 pixels)
│   └── prepared_images/                       # Hex images for simulation
├── test_images/                               # Your raw face images (.jpg, .png, etc.)
├── parse_cascade.py                           # XML → Memory converter
├── prepare_test_images.py                     # Batch image converter
└── README.md                                  # This file
```

---

## Overview

This project is a hardware implementation of the Viola-Jones Haar Cascade face detector using Verilog. It parses OpenCV's cascade data, processes grayscale images, and simulates face detection in hardware.

---

## Objectives

- Implement a real-time-capable face detector using the Viola–Jones Haar Cascade algorithm in Verilog
- Translate OpenCV cascade data into a hardware-friendly ROM layout
- Support 64x64 grayscale images with integral image acceleration and a sliding-window scan
- Provide a self-contained simulation and waveform-driven debugging setup

---

## Step-by-Step Usage Guide

### 1. Install Required Tools

**On Ubuntu:**
```bash
sudo apt update
sudo apt install iverilog gtkwave python3-pip
pip install Pillow numpy lxml
```

### 2. Prepare Haar Cascade Data

Place `haarcascade_frontalface_default.xml` in the `data/` folder (from OpenCV).

Run the parser to convert XML to Verilog memory format:
```bash
python3 parse_cascade.py
```
This creates `data/cascade_data.mem` for use in simulation.

### 3. Prepare Test Images

Put your face images (`.jpg`, `.png`, `.bmp`, `.pgm`) in `test_images/`.

Convert all images to 64x64 grayscale hex format for Verilog:
```bash
python3 prepare_test_images.py
```
This creates `sim/prepared_images/face_01.txt`, `face_02.txt`, ...

### 4. Run Simulation

To test a single image:
```bash
cp sim/prepared_images/face_01.txt sim/image.txt
cd sim
iverilog -o run_sim tb_face_detector.v ../src/*.v
vvp run_sim
```

To test all prepared images automatically (loops through `sim/prepared_images/*.txt`):
```bash
cd sim
chmod +x test_all_images.sh
./test_all_images.sh
```
Notes:
- The script compiles once and runs each prepared image in turn.
- To open GTKWave automatically after the last run, set `OPEN_WAVE=1`:
  ```bash
  OPEN_WAVE=1 ./test_all_images.sh
  ```

### 5. View Results

Check the console for output like:
```
========================================
Detection Results:
========================================
✓ FACE DETECTED!
  Position: (x, y)
  Scale: ...
========================================
```
Or:
```
✗ No face detected
```

### 6. Debug with Waveforms

After running the simulation, you can open GTKWave with pre-configured signals:

```bash
# Or manually open:
gtkwave waveform.vcd waveform.gtkw
```

**Key Signals to Monitor:**
- `dut.control.state[2:0]`: FSM state (0=IDLE, 1=COMPUTE_INTEGRAL, 2=INIT_SCAN, 3=EVAL_CASCADE, 4=NEXT_STAGE, 5=NEXT_WINDOW, 6=FINISH)
- `dut.control.ii_done`: Should go high after all 4096 pixels are loaded
- `dut.control.stage_start`: Should pulse when starting cascade stage evaluation
- `dut.control.stage_done`: Should pulse when stage evaluation completes
- `dut.control.stage_passed`: Shows if current stage passed (1) or failed (0)
- `dut.control.window_x/y`: Current detection window position
- `dut.done`: Should go high when detection completes (either face found or full scan done)

**Common Issues:**
- FSM stuck in `COMPUTE_INTEGRAL` (state=1): Integral image module not completing
- FSM stuck in `EVAL_CASCADE` (state=3): Stage evaluator not completing
- FSM stuck in `NEXT_WINDOW` (state=5): Window scanning logic issue

---

## How It Works

1. **Cascade Data Parsing:** Converts OpenCV XML to Verilog memory format.
2. **Image Preparation:** Converts images to 64x64 grayscale hex for Verilog.
3. **Simulation:** Loads image, computes integral image, scans windows, evaluates cascade stages, and reports detection.
4. **Testbench:** Automates pixel feeding, result reporting, and waveform generation.

---

## Methodology Adopted

- Data preparation
  - Parse OpenCV's `haarcascade_frontalface_default.xml` into a packed hex memory file (`data/cascade_data.mem`)
  - Convert raw images to 64x64 grayscale hex (`sim/prepared_images/*.txt`)
- Hardware pipeline
  - `integral_image`: builds integral image as pixels stream in
  - `feature_calculator`: generates rectangle queries and accumulates weighted sums
  - `weak_classifier`: compares feature values against thresholds
  - `stage_evaluator`: iterates weak classifiers and thresholds per stage
  - `control_fsm`: orchestrates window scan, stage transitions, and result reporting
- Simulation and debug
  - Icarus Verilog testbench streams pixels, prints results, and dumps `waveform.vcd`
  - GTKWave + `waveform.gtkw` for focused signal inspection

---

## Replication Instructions

1. Clone or copy the repository.
2. Install all required tools and Python packages.
3. Place your images in `test_images/`.
4. Run `prepare_test_images.py` to convert images.
5. Run simulation as shown above.
6. Analyze results and waveforms.

---

## Troubleshooting

- **No images found:** Ensure `test_images/` contains supported image files.
- **Python errors:** Install missing packages with `pip install Pillow numpy lxml`.
- **Simulation timeout (stuck in state 3):** This indicates the stage evaluator is stuck waiting for the feature calculator, which is waiting for `rect_sum_valid` from the integral image module. The handshake timing needs to be fixed in `feature_calculator.v`:
  - The `QUERY_SUM` state should wait for `rect_sum_valid` before transitioning to `ACCUMULATE`
  - Fixed by keeping `query_valid` HIGH until `rect_sum_valid` is received
- **ROM not loading:** Ensure `cascade_data.mem` exists and is not empty.
- **ROM warnings ("Too many words"):** Safe to ignore - the first 16,384 words are loaded correctly.

---

## Results (examples)

- Console output indicates detection status and window parameters after the scan completes
- Waveform trace shows FSM progress (`control.state`), integral image completion (`ii_done`), stage evaluation pulses, and `done`
- Prepared inputs under `sim/prepared_images/face_XX.txt` have been validated to run through the full pipeline in simulation

---


## References

- OpenCV Haar Cascade: https://github.com/opencv/opencv/tree/master/data/haarcascades
- Viola-Jones Face Detection Algorithm
- Icarus Verilog: http://iverilog.icarus.com/
- GTKWave: http://gtkwave.sourceforge.net/
