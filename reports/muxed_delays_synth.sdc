# ####################################################################

#  Created by Genus(TM) Synthesis Solution 23.14-s090_1 on Tue Dec 02 18:02:12 MSK 2025

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design muxed_delays

create_clock -name "virtual_clk" -period 20.0 -waveform {0.0 10.0} 
set_load -pin_load 0.05 [get_ports out]
set_false_path -from [list \
  [get_ports {select[1]}]  \
  [get_ports {select[0]}] ] -to [get_ports out]
set_max_delay 12000 -from [list \
  [get_ports {delay_lines[3]}]  \
  [get_ports {delay_lines[2]}]  \
  [get_ports {delay_lines[1]}]  \
  [get_ports {delay_lines[0]}] ] -to [get_ports out]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks virtual_clk] -add_delay 0.0 [get_ports {delay_lines[3]}]
set_input_delay -clock [get_clocks virtual_clk] -add_delay 0.0 [get_ports {delay_lines[2]}]
set_input_delay -clock [get_clocks virtual_clk] -add_delay 0.0 [get_ports {delay_lines[1]}]
set_input_delay -clock [get_clocks virtual_clk] -add_delay 0.0 [get_ports {delay_lines[0]}]
set_input_delay -clock [get_clocks virtual_clk] -add_delay 0.0 [get_ports {select[1]}]
set_input_delay -clock [get_clocks virtual_clk] -add_delay 0.0 [get_ports {select[0]}]
set_output_delay -clock [get_clocks virtual_clk] -add_delay 0.0 [get_ports out]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {delay_lines[3]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {delay_lines[2]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {delay_lines[1]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {delay_lines[0]}]
set_wire_load_mode "enclosed"
