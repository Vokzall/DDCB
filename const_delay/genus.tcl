# Cadence Genus(TM) Synthesis Solution, Version 23.14-s090_1, built Feb 27 2025 10:49:50

# Date: Tue Dec 30 02:09:50 2025
# Host: yaroslavPC (x86_64 w/Linux 5.15.0-139-generic) (16cores*32cpus*1physical cpu*AMD Ryzen 9 7950X 16-Core Processor 1024KB)
# OS:   Ubuntu 20.04.6 LTS

read_libs /home/yaroslav/Project/DDCB/DDK/libs/scc28nhkcp_hsc30p140_rvt_tt_v0p9_25c_basic.lib
read_hdl const_delay.v -sv
read_physical -lef [list /home/yaroslav/Project/DDCB/DDK/lefs/scc28n_1p10m_8ic_2tmc_alpa2.lef /home/yaroslav/Project/DDCB/DDK/lefs/scc28nhkcp_hsc30p140_rvt.lef]
elaborate
set_dont_touch [get_cells -hier -filter {ref_name == DEL4V4_140P9T30R}]
set_driving_cell -lib_cell BUFV1_140P9T30R [get_ports -filter direction==in *]
set_load -pin [get_ports -filter direction==out *] 1.0fF
report_timing -unconstrained -from I -to O
write_netlist > ./const_delay_netlist.v
write_sdf > ./const_delay.sdf
write_sdc > ./const_delay.sdc