#!/bin/bash
# =====================================================
# Genus Synthesis Launch Script
# =====================================================

# Переход в рабочую директорию
cd workdir

# Проверка существования необходимых файлов
if [ ! -f ../src/muxed_delays.sv ]; then
    echo "ERROR: RTL file not found: ../src/muxed_delays.sv"
    exit 1
fi

if [ ! -f ../synth/muxed_delays.sdc ]; then
    echo "ERROR: SDC file not found: ../synth/muxed_delays.sdc"
    exit 1
fi

if [ ! -f ../DDK/scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs.lib ]; then
    echo "ERROR: Library file not found"
    exit 1
fi

if [ ! -f ../scripts/iterative_delay_synthesis.tcl ]; then
    echo "ERROR: Iterative synthesis script not found"
    exit 1
fi

# Создать директорию для отчетов если не существует
mkdir -p ../reports

echo "=========================================="
echo "Starting Genus Synthesis"
echo "=========================================="
echo "Working directory: $(pwd)"
echo "Library: scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs.lib"
echo "RTL: ../src/muxed_delays.sv"
echo "SDC: ../synth/muxed_delays.sdc"
echo "=========================================="
echo ""

# Запуск Genus с автоматическим выполнением скрипта
genus -f ../scripts/run_synthesis.tcl -log ./genus.log

echo ""
echo "=========================================="
echo "Synthesis Complete"
echo "=========================================="
echo "Check results in ../reports/"
echo "  - genus.log              (Synthesis log)"
echo "  - muxed_delays_synth.v   (Netlist)"
echo "  - muxed_delays_synth.sdc (Constraints)"
echo "  - muxed_delays.sdf       (Delays)"
echo "=========================================="