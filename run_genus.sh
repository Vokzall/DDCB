#!/bin/bash
# =====================================================
# Genus Synthesis Launch Script
# =====================================================
# Usage:
#   ./run_genus.sh                  - synthesize cascade_delays
#   ./run_genus.sh const_delay [N]  - synthesize const_delay with N cascades (default 5)
#   ./run_genus.sh idelay           - synthesize IDELAYE3 wrapper
#   ./run_genus.sh odelay           - synthesize ODELAYE3 wrapper

if [ "$1" == "const_delay" ]; then
    N_CASCADES=${2:-5}
    echo "=== Synthesizing const_delay with $N_CASCADES cascades ==="
    cd const_delay
    rm -f ./*log* ./*cmd*
    genus -f ./genus.tcl -log ./genus.log -execute "set Nbr_const_delay_cascades $N_CASCADES"

elif [ "$1" == "idelay" ]; then
    echo "=== Synthesizing IDELAYE3 wrapper ==="
    mkdir -p workdir
    cd workdir
    rm -f ./*log* ./*cmd*
    genus -f ../scripts/genus_wrapper.tcl -log ./genus.log -execute "set setup_env_file setup_env_idelay.tcl"

elif [ "$1" == "odelay" ]; then
    echo "=== Synthesizing ODELAYE3 wrapper ==="
    mkdir -p workdir
    cd workdir
    rm -f ./*log* ./*cmd*
    genus -f ../scripts/genus_wrapper.tcl -log ./genus.log -execute "set setup_env_file setup_env_odelay.tcl"

else
    echo "=== Synthesizing cascade_delays ==="
    mkdir -p workdir
    cd workdir
    rm -f ./*log* ./*cmd*
    genus -f ../scripts/genus.tcl -log ./genus.log
fi
