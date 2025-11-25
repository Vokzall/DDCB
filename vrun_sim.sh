#!/bin/bash
mkdir -p ./workdir
cd ./workdir

vivado -mode gui -source ../scripts/simulate.tcl -notrace