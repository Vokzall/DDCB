#!/usr/bin/env python3
"""
Find optimal delay sequences with uniform steps for rise and fall transitions.
Goal: Find LONGEST sequence with reasonable uniformity.
Rise and fall steps can differ.
"""

import argparse
import csv
from dataclasses import dataclass
from typing import List, Tuple, Dict
import sys


@dataclass
class DelayEntry:
    select: str
    rise: int
    fall: int


def load_delays(filename: str) -> List[DelayEntry]:
    """Load delay data from CSV file."""
    entries = []
    with open(filename, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            entries.append(DelayEntry(
                select=row['SELECT'],
                rise=int(row['RISE']),
                fall=int(row['FALL'])
            ))
    return entries


def find_best_sequence_greedy(
    entries: List[DelayEntry],
    min_step: int = 8,
    max_step: int = 30,
    max_distance: int = 3
) -> List[Tuple[int, int, int, int, str, int]]:
    """
    Greedy approach: find longest sequence with reasonable uniformity.
    Priority: LENGTH first, then uniformity.
    """
    # Build lookup
    rise_to_entries: Dict[int, List[DelayEntry]] = {}
    for e in entries:
        if e.rise not in rise_to_entries:
            rise_to_entries[e.rise] = []
        rise_to_entries[e.rise].append(e)

    rise_values = sorted(rise_to_entries.keys())

    best_result = []

    for start_idx, start_rise in enumerate(rise_values):
        for step in range(min_step, max_step + 1):
            sequence = []
            current_rise = start_rise

            # Find first entry
            first_entry = None
            for e in rise_to_entries.get(current_rise, []):
                first_entry = e
                break

            if first_entry is None:
                continue

            sequence.append((
                current_rise, first_entry.fall,
                first_entry.rise, first_entry.fall,
                first_entry.select, 0
            ))

            # Extend sequence
            for i in range(1, 100):  # Max 100 steps
                target_rise = start_rise + i * step
                target_fall = first_entry.fall + i * step  # Assume similar step for fall

                best_match = None
                best_dist = float('inf')

                for r in rise_values:
                    if abs(r - target_rise) > max_distance:
                        continue
                    for e in rise_to_entries.get(r, []):
                        dist = abs(e.rise - target_rise) + abs(e.fall - target_fall)
                        if dist < best_dist and dist <= max_distance * 2:
                            best_dist = dist
                            best_match = e

                if best_match is None:
                    break

                sequence.append((
                    target_rise, target_fall,
                    best_match.rise, best_match.fall,
                    best_match.select,
                    best_dist
                ))

            # Priority: longest sequence
            if len(sequence) > len(best_result):
                best_result = sequence

    return best_result


def print_sequence(sequence: List[Tuple[int, int, int, int, str, int]], title: str = ""):
    """Print sequence in formatted table."""
    if not sequence:
        print("No sequence found")
        return

    if title:
        print(f"\n{title}")
    print("=" * 80)
    print(f"{'#':>3} | {'TGT_R':>5} | {'TGT_F':>5} | {'ACT_R':>5} | {'ACT_F':>5} | {'SELECT':^16} | {'DIST':>4}")
    print("-" * 80)

    total_dist = 0
    for i, (tr, tf, ar, af, sel, dist) in enumerate(sequence, 1):
        print(f"{i:>3} | {tr:>5} | {tf:>5} | {ar:>5} | {af:>5} | {sel:^16} | {dist:>4}")
        total_dist += dist

    print("-" * 80)
    print(f"Length: {len(sequence)}, Total distance: {total_dist}")

    # Calculate and show steps
    if len(sequence) > 1:
        rise_steps = [sequence[i][2] - sequence[i-1][2] for i in range(1, len(sequence))]
        fall_steps = [sequence[i][3] - sequence[i-1][3] for i in range(1, len(sequence))]
        print(f"Rise steps: min={min(rise_steps)}, max={max(rise_steps)}, avg={sum(rise_steps)/len(rise_steps):.1f}")
        print(f"Fall steps: min={min(fall_steps)}, max={max(fall_steps)}, avg={sum(fall_steps)/len(fall_steps):.1f}")
    print("=" * 80)


def main():
    parser = argparse.ArgumentParser(description='Find optimal delay sequences')
    parser.add_argument('input', nargs='?', default='reports/delay_simplified.txt',
                        help='Input CSV file (default: reports/delay_simplified.txt)')
    parser.add_argument('-n', '--length', type=int, default=16,
                        help='Target sequence length (default: 16)')
    parser.add_argument('--min-step', type=int, default=8,
                        help='Minimum step size in ps (default: 8)')
    parser.add_argument('--max-step', type=int, default=30,
                        help='Maximum step size in ps (default: 30)')
    parser.add_argument('--max-dist', type=int, default=5,
                        help='Maximum distance from target (default: 5)')
    parser.add_argument('-o', '--output', type=str, default=None,
                        help='Output file (default: stdout)')

    args = parser.parse_args()

    # Load data
    print(f"Loading {args.input}...")
    try:
        entries = load_delays(args.input)
    except FileNotFoundError:
        print(f"Error: File '{args.input}' not found")
        sys.exit(1)

    print(f"Loaded {len(entries)} entries")

    # Get delay range
    rise_min = min(e.rise for e in entries)
    rise_max = max(e.rise for e in entries)
    fall_min = min(e.fall for e in entries)
    fall_max = max(e.fall for e in entries)

    print(f"Rise range: {rise_min} - {rise_max} ps")
    print(f"Fall range: {fall_min} - {fall_max} ps")

    # Find best greedy sequence
    print(f"\nSearching for longest sequence (step {args.min_step}-{args.max_step} ps)...")
    best = find_best_sequence_greedy(
        entries,
        min_step=args.min_step,
        max_step=args.max_step,
        max_distance=args.max_dist
    )

    if best:
        print_sequence(best, "BEST SEQUENCE (Longest)")
    else:
        print("No sequence found with given parameters")

    # Output to file if requested
    if args.output and best:
        with open(args.output, 'w') as f:
            f.write("# Delay Sequence\n")
            f.write("# TGT_RISE,TGT_FALL,ACT_RISE,ACT_FALL,SELECT,DISTANCE\n")
            for tr, tf, ar, af, sel, dist in best:
                f.write(f"{tr},{tf},{ar},{af},{sel},{dist}\n")
        print(f"\nSequence saved to {args.output}")


if __name__ == '__main__':
    main()
