# Synthesis constraints for `const_delay` module (pure delay chain, no select)

# Create virtual clock
create_clock -name virt_clk -period 10.000 -waveform {0.000 5.000}

# Protect all delay instances - MUST preserve them
set_dont_touch [get_cells -hier -filter {ref_name == DEL2V0_140P9T30R}]

puts "INFO: const_delay SDC loaded with full path protection"

set_driving_cell -lib_cell BUFV1_140P9T30R [get_ports -filter direction==in *]
set_load -min -pin_load [get_ports -filter direction==out *] 3.3fF
