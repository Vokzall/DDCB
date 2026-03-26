# Synthesis constraints for ODELAYE3 wrapper

# Real clock on CLK port
create_clock -name clk -period 10.000 -waveform {0.000 5.000} [get_ports CLK]

# Protect cascade_delays cells — already synthesized
set_dont_touch [get_cells -hier -filter {ref_name == DEL1V4_140P9T30R}]
set_dont_touch [get_cells -hier -filter {ref_name == MUX3V4_140P9T30R}]

# I/O
set_driving_cell -lib_cell BUFV1_140P9T30R [get_ports -filter direction==in *]
set_load -min -pin_load [get_ports -filter direction==out *] 3.3fF

set_input_delay  -clock clk 0.5 [get_ports {CE EN_VTC ODATAIN INC RST}]
set_output_delay -clock clk 0.5 [get_ports {DATAOUT CNTVALUEOUT}]

puts "INFO: ODELAYE3 SDC loaded"
