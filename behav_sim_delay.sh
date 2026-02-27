#!/bin/bash
# Behavioral simulation of ODELAYE3 + IDELAYE3
# No SDF, no lib_cells - only behavioral models with hardcoded delays

mkdir -p ./workdir
cd ./workdir

xrun \
    -access +rwc \
    -sv \
    ../src/BUFV1_140P9T30R_behav.sv \
    ../src/MUX3V4_140P9T30R_behav.sv \
    ../src/behav_const_delay.v \
    ../src/cascade_delays.sv \
    ../src/ODELAYE3.sv \
    ../src/IDELAYE3.sv \
    ../sim/tb_odelay_idelay.sv \
    -clean \
    -define Nmbr_cascades=7
