#!/usr/bin/env python3
"""
Full 3^N enumeration of cascade_delays configurations.

Parses SDF files (slow/typ/fast corners), extracts per-stage
DEL and MUX delays, then enumerates all 3^N combinations to find
32 uniformly-spaced delay steps.

Per stage choices:
  I2 = direct wire (0 DEL): MUX I2->Z
  I1 = 1 DEL:               del1 + MUX I1->Z
  I0 = 3 DEL:               del1 + del2 + del3 + MUX I0->Z

Usage: python3 sdf_analysis.py [--sdf-dir ../synth/out] [--num-stages 12] [--num-steps 32]
"""

import re
import sys
import os
import argparse
import itertools
from dataclasses import dataclass
from typing import List, Tuple, Dict


@dataclass
class StageDelays:
    """Delays for one stage."""
    del1: Tuple[float, float] = (0, 0)
    del2: Tuple[float, float] = (0, 0)
    del3: Tuple[float, float] = (0, 0)
    mux_i0: Tuple[float, float] = (0, 0)
    mux_i1: Tuple[float, float] = (0, 0)
    mux_i2: Tuple[float, float] = (0, 0)


def parse_sdf(filepath: str, num_stages: int) -> List[StageDelays]:
    """Parse SDF file, extract per-stage delays."""
    with open(filepath, 'r') as f:
        content = f.read()

    stages = [StageDelays() for _ in range(num_stages)]
    cells = re.findall(r'\(CELL\s*(.*?)\)\s*(?=\(CELL|\)$)', content, re.DOTALL)

    for cell_text in cells:
        ctype_m = re.search(r'\(CELLTYPE\s+"(\w+)"\)', cell_text)
        inst_m = re.search(r'\(INSTANCE\s+(.*?)\)', cell_text)
        if not ctype_m or not inst_m:
            continue

        ctype = ctype_m.group(1)
        inst = inst_m.group(1)

        idx_m = re.search(r'DELAY_STAGES\\\[(\d+)\\\]', inst)
        if not idx_m:
            continue
        idx = int(idx_m.group(1))
        if idx >= num_stages:
            continue

        if ctype == 'DEL1V4_140P9T30R':
            iopath_m = re.search(r'\(IOPATH\s+I\s+Z\s+\([^)]*?(\d+)\)\s+\([^)]*?(\d+)\)\)', cell_text)
            if iopath_m:
                rise, fall = float(iopath_m.group(1)), float(iopath_m.group(2))
                if 'del1_inst' in inst:
                    stages[idx].del1 = (rise, fall)
                elif 'del2_inst' in inst:
                    stages[idx].del2 = (rise, fall)
                elif 'del3_inst' in inst:
                    stages[idx].del3 = (rise, fall)

        elif ctype == 'MUX3V4_140P9T30R':
            for pin, attr in [('I0', 'mux_i0'), ('I1', 'mux_i1'), ('I2', 'mux_i2')]:
                pattern = rf'(?<!\S)\(IOPATH\s+{pin}\s+Z\s+\(::([\d.]+)\)\s+\(::([\d.]+)\)\)'
                matches = re.findall(pattern, cell_text)
                if matches:
                    rise, fall = float(matches[-1][0]), float(matches[-1][1])
                    setattr(stages[idx], attr, (rise, fall))

    return stages


def calc_stage_delay(stage: StageDelays, choice: int) -> Tuple[float, float]:
    if choice == 0:
        return stage.mux_i2
    elif choice == 1:
        return (stage.del1[0] + stage.mux_i1[0],
                stage.del1[1] + stage.mux_i1[1])
    else:
        return (stage.del1[0] + stage.del2[0] + stage.del3[0] + stage.mux_i0[0],
                stage.del1[1] + stage.del2[1] + stage.del3[1] + stage.mux_i0[1])


def calc_total_delay(stages: List[StageDelays], choices: Tuple[int, ...]) -> Tuple[float, float]:
    total_r, total_f = 0.0, 0.0
    for i, choice in enumerate(choices):
        r, f = calc_stage_delay(stages[i], choice)
        total_r += r
        total_f += f
    return (total_r, total_f)


def choices_to_select_pattern(choices: Tuple[int, ...]) -> str:
    mapping = {0: "10", 1: "01", 2: "00"}
    return "".join(mapping[choices[i]] for i in range(len(choices) - 1, -1, -1))


def uniformity_cost(configs: list) -> float:
    n = len(configs)
    if n < 2:
        return float('inf')
    delays = [c[0] for c in configs]
    ideal_step = (delays[-1] - delays[0]) / (n - 1)
    cost = 0.0
    for i in range(1, n):
        dev = (delays[i] - delays[i-1]) - ideal_step
        cost += dev * dev
    return cost


def greedy_drop(candidates: list, num_keep: int) -> list:
    num_to_drop = len(candidates) - num_keep
    for drop_round in range(num_to_drop):
        best_cost = float('inf')
        best_idx = -1
        for j in range(1, len(candidates) - 1):
            trial = candidates[:j] + candidates[j+1:]
            cost = uniformity_cost(trial)
            if cost < best_cost:
                best_cost = cost
                best_idx = j
        candidates = candidates[:best_idx] + candidates[best_idx+1:]
        if (drop_round + 1) % 100 == 0:
            print(f"  Dropped {drop_round + 1}/{num_to_drop}...", flush=True)
    return candidates


def main():
    parser = argparse.ArgumentParser(description='3^N SDF-based delay analysis')
    parser.add_argument('--sdf-dir', default='../synth/out', help='Directory with SDF files')
    parser.add_argument('--design', default='cascade_delays', help='Design name')
    parser.add_argument('--num-stages', type=int, default=12)
    parser.add_argument('--num-steps', type=int, default=32)
    parser.add_argument('--report-dir', default='../reports', help='Output directory')
    args = parser.parse_args()

    N = args.num_stages
    total_combos = 3 ** N
    corner_names = ['slow', 'typ', 'fast']

    # --- Parse SDF files ---
    print(f"Parsing SDF files for {N} stages...")
    corner_stages: Dict[str, List[StageDelays]] = {}
    for cn in corner_names:
        sdf_path = f'{args.sdf_dir}/{args.design}_{cn}.sdf'
        if not os.path.exists(sdf_path):
            print(f"  WARNING: {sdf_path} not found, skipping corner '{cn}'")
            continue
        corner_stages[cn] = parse_sdf(sdf_path, N)
        print(f"  {cn}: parsed {sdf_path}")

    if 'typ' not in corner_stages:
        print("ERROR: typical corner SDF is required")
        sys.exit(1)

    # Print per-stage info for typical
    print("\nPer-stage delays (typical):")
    for i, s in enumerate(corner_stages['typ']):
        print(f"  Stage {i:2d}: del1=({s.del1[0]:.0f},{s.del1[1]:.0f}) "
              f"del2=({s.del2[0]:.0f},{s.del2[1]:.0f}) "
              f"del3=({s.del3[0]:.0f},{s.del3[1]:.0f}) "
              f"mux_I0=({s.mux_i0[0]:.0f},{s.mux_i0[1]:.0f}) "
              f"mux_I1=({s.mux_i1[0]:.0f},{s.mux_i1[1]:.0f}) "
              f"mux_I2=({s.mux_i2[0]:.0f},{s.mux_i2[1]:.0f})")

    # --- Enumerate all 3^N combinations ---
    print(f"\nEnumerating all {total_combos} combinations...")

    # For each combo: {corner: (rise, fall)} and typ_avg
    # Store: (typ_avg, choices, {corner: (rise, fall)})
    all_results = []

    for combo_idx, choices in enumerate(itertools.product(range(3), repeat=N)):
        delays = {}
        for cn, stages in corner_stages.items():
            delays[cn] = calc_total_delay(stages, choices)

        typ_r, typ_f = delays['typ']
        typ_avg = (typ_r + typ_f) / 2.0
        all_results.append((typ_avg, choices, delays))

        if (combo_idx + 1) % 100000 == 0:
            print(f"  {combo_idx + 1}/{total_combos}...", flush=True)

    print(f"  Done. {len(all_results)} combinations.")

    all_results.sort(key=lambda x: x[0])
    print(f"  Typ avg range: {all_results[0][0]:.1f} .. {all_results[-1][0]:.1f} ps")

    # Deduplicate by typ_avg
    seen = set()
    unique_results = []
    for entry in all_results:
        key = round(entry[0], 1)
        if key not in seen:
            seen.add(key)
            unique_results.append(entry)

    print(f"  Unique delay values: {len(unique_results)}")

    # --- Select uniform steps ---
    print(f"\nSelecting {args.num_steps} uniform steps (greedy drop from {len(unique_results)})...")

    if len(unique_results) <= args.num_steps:
        selected = unique_results[:]
    else:
        selected = greedy_drop(unique_results[:], args.num_steps)

    # --- Compute ideal values ---
    typ_min = selected[0][0]
    typ_max = selected[-1][0]
    ideal_step = (typ_max - typ_min) / (args.num_steps - 1) if args.num_steps > 1 else 0

    # --- Report ---
    os.makedirs(args.report_dir, exist_ok=True)
    report_file = os.path.join(args.report_dir, 'delay_analysis.txt')
    sel_width = N * 2
    available_corners = [cn for cn in corner_names if cn in corner_stages]

    with open(report_file, 'w') as f:
        f.write("=" * 130 + "\n")
        f.write("     PROGRAMMABLE DELAY LINE - FULL 3^N ENUMERATION ANALYSIS\n")
        f.write("=" * 130 + "\n")
        f.write(f"Design:         {args.design}\n")
        f.write(f"Stages:         {N}\n")
        f.write(f"Total combos:   {total_combos}\n")
        f.write(f"Unique delays:  {len(unique_results)}\n")
        f.write(f"LUT steps:      {args.num_steps}\n")
        f.write(f"Ideal step:     {ideal_step:.2f} ps (typ avg)\n")
        f.write(f"Corners:        {', '.join(available_corners)}\n")
        f.write("=" * 130 + "\n\n")

        f.write("Architecture per stage:\n")
        f.write("  I0 - 3x DEL1V4 (3 DEL) : select=00\n")
        f.write("  I1 - 1x DEL1V4 (1 DEL) : select=01\n")
        f.write("  I2 - Direct wire (0 DEL): select=10\n")
        f.write("  (del1 is shared between I1 and I0 paths)\n\n")

        # --- Per-stage delays ---
        for cn in available_corners:
            f.write(f"Per-stage delays ({cn}):\n")
            for i, s in enumerate(corner_stages[cn]):
                f.write(f"  Stage {i:2d}: del1=({s.del1[0]:.0f},{s.del1[1]:.0f}) "
                        f"del2=({s.del2[0]:.0f},{s.del2[1]:.0f}) "
                        f"del3=({s.del3[0]:.0f},{s.del3[1]:.0f}) "
                        f"mux_I0=({s.mux_i0[0]:.0f},{s.mux_i0[1]:.0f}) "
                        f"mux_I1=({s.mux_i1[0]:.0f},{s.mux_i1[1]:.0f}) "
                        f"mux_I2=({s.mux_i2[0]:.0f},{s.mux_i2[1]:.0f})\n")
            f.write("\n")

        # --- Main table ---
        f.write("=" * 130 + "\n")
        f.write(f"                     SELECTED {args.num_steps} UNIFORM STEPS\n")
        f.write("=" * 130 + "\n\n")

        # Build header
        hdr = f"| {'#':>3} | {'I0':>2} | {'I1':>2} | {'I2':>2} | {'DEL':>3} |"
        # Slow R/F and |R-F|
        if 'slow' in corner_stages:
            hdr += f" {'slw_R':>6} | {'slw_F':>6} | {'slw|RF|':>7} |"
        # Typ R/F/Avg/Ideal/Err%
        hdr += f" {'typ_R':>6} | {'typ_F':>6} | {'typ_avg':>7} | {'ideal':>7} | {'err%':>5} | {'typ|RF|':>7} |"
        # Fast R/F and |R-F|
        if 'fast' in corner_stages:
            hdr += f" {'fst_R':>6} | {'fst_F':>6} | {'fst|RF|':>7} |"
        # Step size
        hdr += f" {'step':>6} |"

        f.write(hdr + "\n")
        f.write("=" * len(hdr) + "\n")

        prev_avg = None
        for step_idx, (typ_avg, choices, delays) in enumerate(selected):
            cnt_i0 = sum(1 for c in choices if c == 2)
            cnt_i1 = sum(1 for c in choices if c == 1)
            cnt_i2 = sum(1 for c in choices if c == 0)
            del_total = cnt_i0 * 3 + cnt_i1

            ideal_val = typ_min + step_idx * ideal_step
            err_pct = ((typ_avg - ideal_val) / ideal_val * 100) if ideal_val > 0 else 0

            typ_r, typ_f = delays['typ']
            typ_rf = abs(typ_r - typ_f)

            step_ps = typ_avg - prev_avg if prev_avg is not None else 0
            prev_avg = typ_avg

            line = f"| {step_idx:3d} | {cnt_i0:2d} | {cnt_i1:2d} | {cnt_i2:2d} | {del_total:3d} |"

            if 'slow' in corner_stages:
                sr, sf = delays.get('slow', (0, 0))
                line += f" {sr:6.0f} | {sf:6.0f} | {abs(sr-sf):7.0f} |"

            line += f" {typ_r:6.0f} | {typ_f:6.0f} | {typ_avg:7.0f} | {ideal_val:7.0f} | {err_pct:+5.1f} | {typ_rf:7.0f} |"

            if 'fast' in corner_stages:
                fr, ff = delays.get('fast', (0, 0))
                line += f" {fr:6.0f} | {ff:6.0f} | {abs(fr-ff):7.0f} |"

            line += f" {step_ps:6.1f} |"

            f.write(line + "\n")

        f.write("=" * len(hdr) + "\n\n")

        # --- Select patterns ---
        f.write("=" * 130 + "\n")
        f.write("                     SELECT PATTERNS\n")
        f.write("=" * 130 + "\n\n")

        f.write(f"| {'#':>3} | {'Select':<{sel_width}} | {'I0':>2} | {'I1':>2} | {'I2':>2} |\n")
        f.write("=" * (18 + sel_width) + "\n")

        for step_idx, (_, choices, _) in enumerate(selected):
            pat = choices_to_select_pattern(choices)
            cnt_i0 = sum(1 for c in choices if c == 2)
            cnt_i1 = sum(1 for c in choices if c == 1)
            cnt_i2 = sum(1 for c in choices if c == 0)
            f.write(f"| {step_idx:3d} | {pat} | {cnt_i0:2d} | {cnt_i1:2d} | {cnt_i2:2d} |\n")

        f.write("=" * (18 + sel_width) + "\n\n")

        # --- SELECT_LUT ---
        f.write("=" * 130 + "\n")
        f.write("                     SELECT_LUT (for RTL)\n")
        f.write("=" * 130 + "\n\n")

        f.write(f"localparam logic [{sel_width}-1:0] SELECT_LUT [0:31] = '{{\n")

        for step_idx, (typ_avg, choices, _) in enumerate(selected):
            pat = choices_to_select_pattern(choices)
            cnt_i0 = sum(1 for c in choices if c == 2)
            cnt_i1 = sum(1 for c in choices if c == 1)
            del_total = cnt_i0 * 3 + cnt_i1
            comma = "," if step_idx < len(selected) - 1 else " "
            comment = f"// step {step_idx:2d}: DEL={del_total:2d}  typ_avg={typ_avg:.0f} ps"
            f.write(f"    {sel_width}'b{pat}{comma}  {comment}\n")

        f.write("};\n\n")

        # --- Summary per corner ---
        f.write("=" * 130 + "\n")
        f.write("                     DELAY SUMMARY\n")
        f.write("=" * 130 + "\n\n")

        for cn in available_corners:
            f.write(f"Corner: {cn.upper()}\n")
            f.write("-" * 70 + "\n")

            rises = [d[cn][0] for _, _, d in selected if cn in d]
            falls = [d[cn][1] for _, _, d in selected if cn in d]
            avgs = [(d[cn][0] + d[cn][1]) / 2 for _, _, d in selected if cn in d]

            for label, vals in [("RISE", rises), ("FALL", falls), ("AVG", avgs)]:
                if len(vals) < 2:
                    continue
                dmin, dmax = min(vals), max(vals)
                rng = dmax - dmin
                steps_list = [vals[i] - vals[i-1] for i in range(1, len(vals))]
                step_min_v = min(steps_list)
                step_max_v = max(steps_list)
                step_avg_v = sum(steps_list) / len(steps_list)
                lsb = rng / (args.num_steps - 1)
                f.write(f"  {label:4s}: {dmin:7.0f}..{dmax:7.0f} ps  "
                        f"range={rng:7.0f} ps  step_avg={step_avg_v:6.1f} ps  "
                        f"step_min={step_min_v:6.1f}  step_max={step_max_v:6.1f}  "
                        f"LSB={lsb:.2f} ps\n")

            rf_diffs = [abs(d[cn][0] - d[cn][1]) for _, _, d in selected if cn in d]
            if rf_diffs:
                f.write(f"  |R-F|: avg={sum(rf_diffs)/len(rf_diffs):.1f} ps  "
                        f"max={max(rf_diffs):.0f} ps  min={min(rf_diffs):.0f} ps\n")
            f.write("\n")

        f.write("=" * 130 + "\n")
        f.write("End of Analysis\n")
        f.write("=" * 130 + "\n")

    print(f"\nReport written to: {report_file}")

    # Console summary
    print(f"\n{'='*60}")
    print(f"SUMMARY: {args.num_steps} steps from {total_combos} combos")
    print(f"{'='*60}")
    print(f"Typ avg range: {selected[0][0]:.0f} .. {selected[-1][0]:.0f} ps")
    print(f"Ideal step: {ideal_step:.1f} ps")

    for cn in available_corners:
        rises = [d[cn][0] for _, _, d in selected if cn in d]
        falls = [d[cn][1] for _, _, d in selected if cn in d]
        rf = [abs(d[cn][0] - d[cn][1]) for _, _, d in selected if cn in d]
        print(f"  {cn.upper()}: Rise {min(rises):.0f}..{max(rises):.0f}  "
              f"Fall {min(falls):.0f}..{max(falls):.0f}  "
              f"|R-F| avg={sum(rf)/len(rf):.0f} max={max(rf):.0f} ps")


if __name__ == '__main__':
    main()
