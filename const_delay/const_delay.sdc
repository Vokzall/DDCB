# ####################################################################

#  Created by Genus(TM) Synthesis Solution 23.14-s090_1 on Tue Dec 30 13:38:30 MSK 2025

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design const_delay

set_clock_gating_check -setup 0.0 
set_driving_cell -lib_cell BUFV1_140P9T30R -library scc28nhkcp_hsc30p140_rvt_tt_v0p9_25c_basic -pin "Z" [get_ports I]
set_dont_touch [get_cells {DELAY_STAGES[0].u_delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[1].u_delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[2].u_delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[3].u_delay_inst}]
set_dont_touch [get_cells {DELAY_STAGES[4].u_delay_inst}]
