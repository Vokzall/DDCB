
# Digital Delay Control Block Project

Проект для работы с IDELAYE3 и ODELAYE3 блоками, включающий реализации для ASIC и тестовое окружение.

## Структура проекта


.
├── DDK/                 # Digital Design Kit (исключена из репозитория)
├── doc/                 # Документация
│   └── Xilinx_brief.pdf
├── reports/             # Отчеты синтеза
├── scripts/             # Скрипты для инструментов EDA
│   └── simulate.tcl
├── sim/                 # Тестовое окружение
│   ├── tb_IDELAYE3.sv
│   └── tb_ODELAYE3.sv
├── src/                 # Исходные HDL коды
│   ├── IDELAYE3_asic.sv
│   ├── IDELAYE3.v
│   ├── ODELAYE3_asic.sv
│   └── ODELAYE3.v
├── synth/               # Констрейны и файлы для синтеза
│   └── func.sdc
├── tmp/                 # Временные файлы
├── workdir/             # Рабочая директория симуляции
├── vrun_sim.sh          # Скрипт запуска симуляции в Vivado
├── xrun_sim.sh          # Скрипт запуска симуляции в Xcelium
└── README.md

## Быстрый старт

### Предварительные требования
- Xilinx Vivado (версия уточните)
- Cadence Xcelium (опционально)
- Siemens QuestaSim (опционально)

### Запуск симуляции
```bash
# Vivado симуляция
./vrun_sim.sh

# Xcelium симуляция  
./xrun_sim.sh
```

## Описание директорий

### src/ - Исходные коды
- `IDELAYE3.v` - Xilinx примитив входной задержки
- `IDELAYE3_asic.sv` - ASIC реализация IDELAYE3
- `ODELAYE3.v` - Xilinx примитив выходной задержки  
- `ODELAYE3_asic.sv` - ASIC реализация ODELAYE3

### sim/ - Тестовое окружение
- `tb_IDELAYE3.sv` - testbench для модуля IDELAYE3
- `tb_ODELAYE3.sv` - testbench для модуля ODELAYE3

### synth/ - Синтез
- `func.sdc` - timing constraints для синтеза

### workdir/
Рабочая директория симуляции (создается автоматически, файлы исключены из репозитория)

### tmp/ 
Временные файлы 

## Использование

### Симуляция
Скрипты автоматически создают рабочую директорию и запускают симуляцию:
- `vrun_sim.sh` - для Vivado Simulator
- `xrun_sim.sh` - для Xcelium

### Синтез
Используйте файлы из папки `synth/` для логического синтеза в соответствующих EDA инструментах.

## Результаты
Отчеты симуляции и синтеза сохраняются в директорию `reports/`

## Примечания
- Директория `DDK/` исключена из репозитория и должна быть предоставлена отдельно
- Временные файлы в `workdir/` и `tmp/` автоматически удаляются или игнорируются
