#!/bin/bash

mkdir -p ./workdir
cd ./workdir
rm xmvlog_activemacros_*.v
xrun \
-gui \
-access +rwc \
-sv \
../sim/* \
../synth/out/*v \
-dumpactivemacros \
-clean \
-v ../DDK/verilog/* 