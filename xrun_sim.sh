#!/bin/bash

mkdir -p ./workdir
cd ./workdir
rm -f xmvlog_activemacros_*.v
xrun \
-access +rwc \
-sv \
../sim/tb_wrapper.sv \
../src/IDELAYE3.sv \
../src/ODELAYE3.sv \
../synth/out/cascade_delays_netlist.v \
-dumpactivemacros \
-clean \
-v ../DDK/verilog/*
