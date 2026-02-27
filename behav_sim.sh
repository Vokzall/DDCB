#!/bin/bash
# Behavioral simulation of cascade_delays
# No SDF, no lib_cells - only behavioral models with hardcoded delays

mkdir -p ./workdir
cd ./workdir

xrun \
    -gui \
    -access +rwc \
    -sv \
    ../src/BUFV1_140P9T30R_behav.sv \
    ../src/MUX3V4_140P9T30R_behav.sv \
    ../src/behav_const_delay.v \
    ../src/cascade_delays.sv \
    ../sim/tb_cascade_delays.sv \
    -clean \
    -define Nmbr_cascades=7
