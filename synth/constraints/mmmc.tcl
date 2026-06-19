# =====================================================
# MMMC configuration for cascade_delays
# 3 corners: SSG (slow), TT (typical), FFG (fast)
# All use CMAX RC corner (only one available)
# =====================================================

# --- Library sets ---
create_library_set \
    -name lib_ssg \
    -timing "../DDK/libs/scc28nhkcp_hsc30p140_rvt_ssg_v0p81_-40c_ccs.lib"

create_library_set \
    -name lib_tt \
    -timing "../DDK/libs/scc28nhkcp_hsc30p140_rvt_tt_v0p9_25c_basic.lib"

create_library_set \
    -name lib_ffg \
    -timing "../DDK/libs/scc28nhkcp_hsc30p140_rvt_ffg_v0p99_125c_ccs.lib"

# --- Timing conditions ---
create_timing_condition -name tc_ssg -library_sets lib_ssg
create_timing_condition -name tc_tt  -library_sets lib_tt
create_timing_condition -name tc_ffg -library_sets lib_ffg

# --- RC corner (only CMAX available) ---
create_rc_corner \
    -name rc_cmax \
    -qrc_tech "../DDK/tech/CMAX/qrcTechFile"

# --- Delay corners ---
create_delay_corner -name dc_slow -timing_condition tc_ssg -rc_corner rc_cmax
create_delay_corner -name dc_typ  -timing_condition tc_tt  -rc_corner rc_cmax
create_delay_corner -name dc_fast -timing_condition tc_ffg -rc_corner rc_cmax

# --- Constraint mode ---
create_constraint_mode \
    -name cm_func \
    -sdc_files "$design(SDC_FILE)"

# --- Analysis views ---
create_analysis_view -name view_slow -constraint_mode cm_func -delay_corner dc_slow
create_analysis_view -name view_typ  -constraint_mode cm_func -delay_corner dc_typ
create_analysis_view -name view_fast -constraint_mode cm_func -delay_corner dc_fast

set_analysis_view \
    -setup {view_slow view_typ view_fast} \
    -hold  {view_fast}
