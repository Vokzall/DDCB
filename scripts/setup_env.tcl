# =============================================
# Project Configuration for Cadence Genus Synthesis
# =============================================

# Design Parameters
set design(DESIGN)          "cascade_delays"
set design(TECHNOLOGY)      "tsmc28nm"
set design(CLK_NAME)        "clk"
set design(CLK_PERIOD)      "1.0"    ;# ns
set design(VIRTUAL_CLK)     "virt_clk"
set design(VIRTUAL_PERIOD)  "10.0"   ;# ns

# Path Configuration
set design(VERILOG_DIR)     "../src"
set design(LIB_PATH)        "../DDK/libs"
set design(LEF_PATH)        "../DDK/lefs"
set design(SDC_PATH)        "../synth/constraints"
set design(MMMC_PATH)       "./mmmc"
set design(REPORT_DIR)      "../reports"
set design(QRC_PATH)        "../DDK/tech/CMAX"
set design(Nmbr_cascades)   6

# File Lists
set design(VERILOG_FILES) [list \
    "${design(VERILOG_DIR)}/cascade_delays.sv" \
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
set design(SDC_FILE) "${design(SDC_PATH)}/cascade_delays.sdc"

# MMMC File
set design(MMMC_FILE) "${design(MMMC_PATH)}/view_definition.tcl"

# QRC File
set design(QRC_FILE) "${design(QRC_PATH)}/qrcTechFile"

# =============================================
# Optional: Create directories if they don't exist
# =============================================
# proc create_directories {} {
#     global design
    
#     foreach dir [list \
#         $design(REPORT_DIR) \
#         $design(VERILOG_DIR) \
#         $design(LIB_PATH) \
#         $design(LEF_PATH) \
#         $design(SDC_PATH) \
#         $design(MMMC_PATH) \
#         $design(QRC_PATH) \
#     ] {
#         if {![file exists $dir]} {
#             file mkdir $dir
#             puts "Created directory: $dir"
#         }
#     }
# }

# =============================================
# Validation function
# =============================================
proc validate_config {} {
    global design
    
    puts "========================================"
    puts "Project Configuration Validation"
    puts "========================================"
    puts "Design Name:       $design(DESIGN)"
    puts "Technology:        $design(TECHNOLOGY)"
    puts "Clock:             $design(CLK_NAME) @ ${design(CLK_PERIOD)}ns"
    puts "Virtual Clock:     $design(VIRTUAL_CLK) @ ${design(VIRTUAL_PERIOD)}ns"
    puts ""
    
    # Check if required files exist
    set required_files [list \
        $design(VERILOG_FILES) \
        $design(LIB_FILES) \
        $design(LEF_FILES) \
        $design(SDC_FILE) \
        $design(MMMC_FILE) \
        $design(QRC_FILE) \
    ]
    
    foreach file_list $required_files {
        foreach file $file_list {
            if {![file exists $file]} {
                puts "WARNING: File not found - $file"
            }
        }
    }
    puts "========================================"
}

# =============================================
# Load configuration in Genus
# =============================================
# proc load_genus_config {} {
#     global design
    
#     # Set design name
#     set_db design:design_name $design(DESIGN)
    
#     # Read RTL
#     read_hdl -sv $design(VERILOG_FILES)
    
#     # Elaborate design
#     elaborate $design(DESIGN)
    
#     # Read libraries
#     read_libs $design(LIB_FILES)
    
#     # Read LEF
#     read_lefs $design(LEF_FILES)
    
#     # Read constraints
#     read_sdc $design(SDC_FILE)
    
#     # Set operating conditions if needed
#     # set_db operating_conditions ...
    
#     puts "Configuration loaded successfully for design: $design(DESIGN)"
# }