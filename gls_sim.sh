#!/bin/bash

mkdir -p ./workdir
cd ./workdir
rm xmvlog_activemacros_*.v
xrun \
-gui \
-access +rwc \
-sv \
../sim/tb_wrapper.sv \
../synth/out/cascade_delays_netlist.v \
../src/ODELAYE3.sv \
../src/cascade_delays_netlist.sv \
../src/IDELAYE3.sv \
-dumpactivemacros \
-clean \
-define GLS \
-v ../DDK/verilog/* \
-sdf_file ../synth/out/cascade_delays.sdf \
-sdf_verbose