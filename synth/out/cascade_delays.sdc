# ####################################################################

#  Created by Genus(TM) Synthesis Solution 23.14-s090_1 on Fri Dec 05 12:35:37 MSK 2025

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design cascade_delays

create_clock -name "virt_clk" -period 10.0 -waveform {0.0 5.0} 
set_clock_gating_check -setup 0.0 
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports in]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[7]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[6]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[5]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[4]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[3]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[2]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[1]}]
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs -pin "Z" [get_ports {select[0]}]
set_wire_load_mode "enclosed"
set_dont_touch [get_cells {DELAY_STAGES[0].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[0].genblk1.mux_inst}]
set_dont_touch [get_cells {DELAY_STAGES[1].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[1].genblk1.mux_inst}]
set_dont_touch [get_cells {DELAY_STAGES[2].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[2].genblk1.mux_inst}]
set_dont_touch [get_cells {DELAY_STAGES[3].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[3].genblk1.mux_inst}]
set_dont_touch [get_cells {DELAY_STAGES[4].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[4].genblk1.mux_inst}]
set_dont_touch [get_cells {DELAY_STAGES[5].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[5].genblk1.mux_inst}]
set_dont_touch [get_cells {DELAY_STAGES[6].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[6].genblk1.mux_inst}]
set_dont_touch [get_cells {DELAY_STAGES[7].genblk1.delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[7].genblk1.mux_inst}]
