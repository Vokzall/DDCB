# =====================================================
# Units Setup
# =====================================================
# =====================================================
# Simplified SDC for iterative buffer insertion
# =====================================================
set sdc_version 2.0

# Virtual clock
create_clock -name "virtual_clk" -period 20.0 -waveform {0 10.0}

# Input/Output delays
set_input_delay -clock virtual_clk 0.0 [get_ports delay_lines*]
set_input_delay -clock virtual_clk 0.0 [get_ports select*]
set_output_delay -clock virtual_clk 0.0 [get_ports out]

# Disable timing on select path
set_false_path -from [get_ports select*] -to [get_ports out]

# Set realistic driving cells and loads
set_driving_cell -lib_cell BUFV1_140P9T30R -pin Z [get_ports delay_lines*]
set_load 0.05 [get_ports out]

# Optional: Set initial max_delay constraints to prevent aggressive optimization
set_max_delay 12000 -from [get_ports delay_lines*] -to [get_ports out]

