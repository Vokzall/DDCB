# =============================================
# Project Configuration for Cadence Genus Synthesis
# =============================================

# Design Parameters
# Default design is cascade_delays; ::override_design (set from run_genus.sh)
# can switch to the const_delay reference line.
if {[info exists ::override_design]} {
    set design(DESIGN)      $::override_design
} else {
    set design(DESIGN)      "cascade_delays"
}
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
if {[info exists ::override_cascades]} {
    set design(Nmbr_cascades)   $::override_cascades
} else {
    set design(Nmbr_cascades)   11
}

# File Lists
set design(VERILOG_FILES) [list \
    "${design(VERILOG_DIR)}/${design(DESIGN)}.sv" \
]

# Library Files — 3 corners
set design(LIB_SSG) "${design(LIB_PATH)}/scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs.lib"
set design(LIB_TT)  "${design(LIB_PATH)}/scc28nhkcp_hsc30p140_rvt_tt_v0p9_25c_basic.lib"
set design(LIB_FFG) "${design(LIB_PATH)}/scc28nhkcp_hsc30p140_rvt_ffg_v0p99_125c_ccs.lib"

set design(LIB_FILES) [list \
    $design(LIB_SSG) \
    $design(LIB_TT) \
    $design(LIB_FFG) \
]

# Corner names for generate_table_delays
set design(CORNERS) [list \
    [list "slow" "view_slow"] \
    [list "typ"  "view_typ"] \
    [list "fast" "view_fast"] \
]



# LEF Files
set design(LEF_FILES) [list \
    "${design(LEF_PATH)}/scc28n_1p10m_8ic_2tmc_alpa2.lef" \
    "${design(LEF_PATH)}/scc28nhkcp_hsc30p140_rvt.lef" \
]

# SDC File
set design(SDC_FILE) "${design(SDC_PATH)}/${design(DESIGN)}.sdc"

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