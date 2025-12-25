# Synthesis constraints for `cascade_delays` module

# Create virtual clock
create_clock -name virt_clk -period 10.000 -waveform {0.000 5.000}

# CRITICAL: Prevent optimization of select-dependent paths
# Tell Genus that select signals can change and paths must be preserved
# set_case_analysis 0 [get_ports select*]
# set_case_analysis -reset [get_ports select*]

# Protect all buffer instances - MUST preserve them
set_dont_touch [get_cells -hier -filter {ref_name == BUFV1_140P9T30R}]

# Protect all mux instances - MUST preserve them
set_dont_touch [get_cells -hier -filter {ref_name == CLKMUX2V0_140P9T30R}]
set_dont_touch [get_cells -hier -filter {ref_name == MUX3V4_140P9T30R}]

puts "INFO: cascade_delays SDC loaded with full path protection"

set_driving_cell -lib_cell BUFV1_140P9T30R [get_ports *]
set_load -pin [get_ports -filter direction==out *] 1.0fF