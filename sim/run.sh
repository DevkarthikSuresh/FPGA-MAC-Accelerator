#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2012 -Wall -s tb_streaming_mac -o build/tb rtl/streaming_mac.sv sim/tb_streaming_mac.sv
(cd build && vvp tb)
