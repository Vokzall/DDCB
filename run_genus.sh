#!/bin/bash
# =====================================================
# Genus Synthesis Launch Script
# =====================================================

mkdir -p workdir
# Переход в рабочую директорию
cd workdir
rm ./*log* ./*cmd*
# Запуск Genus с автоматическим выполнением скрипта
genus -f ../scripts/genus.tcl -log ./genus.log
