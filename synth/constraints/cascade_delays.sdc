# Synthesis constraints for `cascade_delays` module

# Create virtual clock
create_clock -name virt_clk -period 10.000 -waveform {0.000 5.000}

# CRITICAL: Prevent optimization of select-dependent paths
# Tell Genus that select signals can change and paths must be preserved
# set_case_analysis 0 [get_ports select*]
# set_case_analysis -reset [get_ports select*]

# Make select ports "dont_touch" so they're not optimized away  
set_dont_touch [get_ports select*]

# Protect all buffer instances - MUST preserve them
set_dont_touch [get_cells -hier -filter {ref_name == BUFV1_140P9T30R}]

# Protect all mux instances - MUST preserve them
set_dont_touch [get_cells -hier -filter {ref_name == CLKMUX2V0_140P9T30R}]

# Disable size-only optimization (allow only exact cell usage)
set_size_only -all_instances [get_cells -hier -filter {ref_name == BUFV1_140P9T30R}]
set_size_only -all_instances [get_cells -hier -filter {ref_name == CLKMUX2V0_140P9T30R}]

# Prevent constant propagation through select pins
set_attr [get_pins -hier */S] propagate_constants false

puts "INFO: cascade_delays SDC loaded with full path protection"