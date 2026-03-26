# =============================================
# Project Configuration — ODELAYE3 wrapper synthesis
# =============================================

set design(DESIGN)          "ODELAYE3"
set design(TECHNOLOGY)      "tsmc28nm"
set design(CLK_NAME)        "CLK"
set design(CLK_PERIOD)      "10.0"   ;# ns

# Path Configuration
set design(VERILOG_DIR)     "../src"
set design(LIB_PATH)        "../DDK/libs"
set design(LEF_PATH)        "../DDK/lefs"
set design(SDC_PATH)        "../synth/constraints"
set design(REPORT_DIR)      "../reports"
set design(QRC_PATH)        "../DDK/tech/CMAX"
set design(Nmbr_cascades)   11

# Verilog: wrapper RTL + pre-synthesized cascade_delays netlist
set design(VERILOG_FILES) [list \
    "${design(VERILOG_DIR)}/ODELAYE3.sv" \
]
set design(NETLIST_FILES) [list \
    "../synth/out/cascade_delays_netlist.v" \
]

# Library Files
set design(LIB_FILES) [list \
    ${design(LIB_PATH)}/scc28nhkcp_hsc30p140_rvt_tt_v0p9_25c_basic.lib \
]

# LEF Files
set design(LEF_FILES) [list \
    "${design(LEF_PATH)}/scc28n_1p10m_8ic_2tmc_alpa2.lef" \
    "${design(LEF_PATH)}/scc28nhkcp_hsc30p140_rvt.lef" \
]

# SDC File
set design(SDC_FILE) "${design(SDC_PATH)}/ODELAYE3.sdc"

# QRC File
set design(QRC_FILE) "${design(QRC_PATH)}/qrcTechFile"
