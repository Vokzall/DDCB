#!/bin/bash

mkdir -p ./workdir
cd ./workdir
rm xmvlog_activemacros_*.v
xrun \
-gui \
-access +rwc \
-sv \
../src/*IDELAYE3*v \
../sim/*IDELAYE3*v \
-dumpactivemacros \
-clean \