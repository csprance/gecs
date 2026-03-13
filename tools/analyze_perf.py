#!/usr/bin/env python3
"""Analyze and compare GECS performance test results between two dates."""

import json
import os
from datetime import datetime
from collections import defaultdict
from pathlib import Path

def parse_jsonl(filepath):
    """Parse a JSONL file and return list of records."""
    records = []
    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    records.append(json.loads(line))
    except FileNotFoundError:
        pass
    return records

def get_records_by_date(records, target_date):
    """Filter records by date (YYYY-MM-DD format)."""
    filtered = []
    for record in records:
        timestamp = record.get('timestamp', '')
        if timestamp.startswith(target_date):
            filtered.append(record)
    return filtered

def calculate_stats(records):
    """Calculate average and min/max for records."""
    if not records:
        return None

    times = [r.get('time_ms', 0) for r in records]
    return {
        'avg': sum(times) / len(times),
        'min': min(times),
        'max': max(times),
        'count': len(times)
    }

def main():
    perf_dir = Path('reports/perf')

    # Dates to compare
    date_old = '2025-10-15'  # October 15th
    date_new = '2025-10-19'  # Today (October 19th)

    # Collect all data
    all_tests = defaultdict(lambda: {'old': [], 'new': []})

    # Read all JSONL files
    for jsonl_file in perf_dir.glob('*.jsonl'):
        test_name = jsonl_file.stem
        records = parse_jsonl(jsonl_file)

        old_records = get_records_by_date(records, date_old)
        new_records = get_records_by_date(records, date_new)

        if old_records or new_records:
            all_tests[test_name]['old'] = old_records
            all_tests[test_name]['new'] = new_records

    # Generate report
    print("=" * 100)
    print(f"GECS Performance Comparison: {date_old} vs {date_new}")
    print("=" * 100)
    print()

    # Sort tests by category
    improvements = []
    regressions = []
    new_tests = []
    missing_tests = []

    for test_name in sorted(all_tests.keys()):
        data = all_tests[test_name]
        old_stats = calculate_stats(data['old'])
        new_stats = calculate_stats(data['new'])

        if old_stats and new_stats:
            # Compare
            old_avg = old_stats['avg']
            new_avg = new_stats['avg']
            diff_ms = new_avg - old_avg
            diff_pct = ((new_avg - old_avg) / old_avg) * 100 if old_avg > 0 else 0

            result = {
                'name': test_name,
                'old_avg': old_avg,
                'new_avg': new_avg,
                'diff_ms': diff_ms,
                'diff_pct': diff_pct,
                'old_stats': old_stats,
                'new_stats': new_stats
            }

            if diff_pct < -5:  # 5% faster = improvement
                improvements.append(result)
            elif diff_pct > 5:  # 5% slower = regression
                regressions.append(result)
        elif new_stats and not old_stats:
            new_tests.append({'name': test_name, 'stats': new_stats})
        elif old_stats and not new_stats:
            missing_tests.append({'name': test_name, 'stats': old_stats})

    # Print improvements
    if improvements:
        print(f"\n[+] IMPROVEMENTS ({len(improvements)} tests)")
        print("-" * 100)
        improvements.sort(key=lambda x: x['diff_pct'])
        for r in improvements:
            print(f"  {r['name']:<50} {r['old_avg']:>8.2f}ms -> {r['new_avg']:>8.2f}ms  ({r['diff_pct']:>+6.1f}%)")

    # Print regressions
    if regressions:
        print(f"\n[-] REGRESSIONS ({len(regressions)} tests)")
        print("-" * 100)
        regressions.sort(key=lambda x: x['diff_pct'], reverse=True)
        for r in regressions:
            print(f"  {r['name']:<50} {r['old_avg']:>8.2f}ms -> {r['new_avg']:>8.2f}ms  ({r['diff_pct']:>+6.1f}%)")

    # Print new tests
    if new_tests:
        print(f"\n[*] NEW TESTS ({len(new_tests)} tests)")
        print("-" * 100)
        for t in sorted(new_tests, key=lambda x: x['name']):
            print(f"  {t['name']:<50} {t['stats']['avg']:>8.2f}ms (new)")

    # Print missing tests
    if missing_tests:
        print(f"\n[!] MISSING TESTS ({len(missing_tests)} tests)")
        print("-" * 100)
        for t in sorted(missing_tests, key=lambda x: x['name']):
            print(f"  {t['name']:<50} {t['stats']['avg']:>8.2f}ms (missing from {date_new})")

    # Summary statistics
    print(f"\n" + "=" * 100)
    print("SUMMARY")
    print("=" * 100)
    if improvements or regressions:
        total_tests = len(improvements) + len(regressions)
        avg_improvement = sum(r['diff_pct'] for r in improvements) / len(improvements) if improvements else 0
        avg_regression = sum(r['diff_pct'] for r in regressions) / len(regressions) if regressions else 0

        print(f"Total tests compared: {total_tests}")
        print(f"Improvements: {len(improvements)} tests (avg {avg_improvement:.1f}% faster)")
        print(f"Regressions: {len(regressions)} tests (avg {avg_regression:.1f}% slower)")
        print(f"New tests: {len(new_tests)}")
        print(f"Missing tests: {len(missing_tests)}")
    else:
        print("No comparable data found between the two dates.")

    print()

if __name__ == '__main__':
    main()
