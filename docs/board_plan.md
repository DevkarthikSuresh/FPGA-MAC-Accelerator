# Board bring-up and MNIST roadmap

## 1. Validate the core

Run the supplied testbench. Inspect `in_valid`, `product_valid`, `acc`, `out_valid` and `out_sum`. Confirm one pair can enter per cycle and that the final product is included. Fix any simulation issues before hardware integration.

## 2. Identify the board

Confirm the Spartan-7 part, exact development board revision, pin constraints, oscillator and I/O voltage. The legacy XDC is a recovered record, not a verified constraint set for the streaming top. Create a new Vivado project with the correct part and use `streaming_mac` as the core; add a board-specific wrapper with a clock, synchronized reset, and BRAM or UART interface. Never reuse legacy pins blindly. Run synthesis, implementation and timing analysis. Record LUT, FF, DSP and BRAM counts and achieved timing; a 100 MHz constraint is a target, not proof of closure.

## 3. Test a small classifier first

Run the Python demo to export weights and an input. Build a controller that streams one activation/weight pair per cycle, iterating across features for each class. Bias addition and signed argmax can initially run on the host; later move them into RTL. Compare each hardware raw sum with `expected_dot_products.hex` before comparing the predicted label. Keep ReLU disabled on final logits. The demo is 64 features × 10 classes, 640 MACs per sample.

## 4. Move to MNIST (future work)

Train a 784-to-10 linear classifier in software, quantize weights and activations and evaluate a held-out test set. Export 7,840 weights (7,840 bytes with int8), biases and reference vectors. Store input and weights in BRAM (check actual board capacity) or stream via a host interface. At one pair per clock, the arithmetic pipeline consumes 7,840 input cycles per sample, plus pipeline fill/drain and controller/I/O overhead. Compare bit-exact hardware logits against integer software logits and then measure end-to-end latency and accuracy. A multilayer network with intermediate ReLU can follow once the linear baseline works.

## 5. Record measurements

Use actual board measurements for the README: clock and timing slack, area, MAC rate, per-sample latency including I/O, integer agreement, accuracy, and power if measured. Retain raw Vivado reports, test vectors, and photos or waveforms. Do not infer hardware accuracy or Fmax from a software experiment.
