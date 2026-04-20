#!/usr/bin/env python3
"""
GECS Performance Report
=======================
Run after performance tests to compare results across time periods.

Usage:
    python tools/perf_report.py                        # today vs yesterday vs earliest
    python tools/perf_report.py --days 7               # compare last 7 days vs earliest
    python tools/perf_report.py --category Query       # filter to one category
    python tools/perf_report.py --scale 1000           # only show scale=1000 results
    python tools/perf_report.py --all                  # show all tests (not just major categories)
"""

import json, glob, sys, argparse
from collections import defaultdict
from datetime import datetime, date, timedelta

# ---------------------------------------------------------------------------
# Category definitions — add/remove tests here as new suites are added
# ---------------------------------------------------------------------------
CATEGORIES = {
    "Entity": [
        "entity_creation", "entity_with_components", "entity_world_addition",
        "entity_removal", "bulk_entity_operations",
    ],
    "Component": [
        "component_addition", "multiple_component_addition", "component_removal",
        "component_lookup", "component_get",
    ],
    "Query": [
        "query_with_all", "query_with_any", "query_with_none", "query_complex",
        "query_caching", "query_with_component_query", "query_with_group",
        "query_group_with_components", "query_disabled_entities_no_impact",
    ],
    "System": [
        "system_processing", "multiple_systems", "system_no_matches",
        "system_groups", "system_dynamic_entities", "system_continuous_velocity",
    ],
    "Hotpath": [
        "hotpath_query_execution", "hotpath_component_access", "hotpath_data_read",
        "hotpath_simulated_system", "hotpath_actual_system", "hotpath_multiple_queries",
        "hotpath_component_access_cached", "hotpath_component_access_helper",
    ],
    "Observer": [
        "observer_component_additions", "observer_component_removals",
        "observer_property_changes", "observer_baseline_overhead",
        "observer_frequent_changes", "observer_sporadic_changes",
        "multiple_observers_same_component", "observer_complex_query",
    ],
    "CommandBuffer": [
        "command_buffer_bulk_removal_backwards", "command_buffer_bulk_removal_command_buffer",
        "command_buffer_bulk_component_add_individual", "command_buffer_bulk_component_add_command_buffer",
        "command_buffer_state_transition_individual", "command_buffer_state_transition_command_buffer",
        "command_buffer_cache_invalidations",
    ],
    "Cache": [
        "cache_hit", "cache_miss", "cache_hit_performance", "cache_miss",
        "cache_key_generation", "cache_invalidation_impact_with", "cache_invalidation_impact_without",
    ],
    "Relationship": [
        "relationship_query_exact", "relationship_query_wildcard",
        "component_query_for_rel_comparison",
    ],
}

PREFER_LOWER = True  # lower time_ms = better


def parse_ts(ts: str) -> datetime:
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return datetime.min


def load_data(perf_dir: str = "reports/perf") -> dict[str, list[dict]]:
    data: dict[str, list[dict]] = defaultdict(list)
    for path in glob.glob(f"{perf_dir}/*.jsonl"):
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                    data[rec["test"]].append(rec)
                except Exception:
                    pass
    return data


def pick_scale(records: list[dict], prefer: int | None = None) -> tuple[int | None, list[dict]]:
    if prefer is not None:
        hits = [r for r in records if r.get("scale") == prefer]
        if hits:
            return prefer, hits
    for s in [10000, 1000, 100]:
        hits = [r for r in records if r.get("scale") == s]
        if hits:
            return s, hits
    return None, records


def pct_str(val: float | None, ref: float | None) -> str:
    if val is None or ref is None:
        return "N/A"
    if ref == 0:
        return "inf"
    diff = ((val - ref) / ref) * 100
    if abs(diff) < 1.0:
        return "~0%"
    sign = "+" if diff > 0 else "-"
    better = diff < 0  # lower is better for time
    label = "BETTER" if better else "WORSE "
    return f"{sign}{abs(diff):.1f}% {label}"


def build_results(data: dict, ref_date: date, cmp_date: date, scale_pref: int | None) -> dict:
    results = {}
    for test_name, records in data.items():
        records.sort(key=lambda r: parse_ts(r.get("timestamp", "")))
        scale, scale_records = pick_scale(records, scale_pref)
        if not scale_records:
            continue
        scale_records.sort(key=lambda r: parse_ts(r.get("timestamp", "")))

        earliest = scale_records[0]
        ref_recs = [r for r in scale_records if parse_ts(r.get("timestamp", "")).date() == ref_date]
        cmp_recs = [r for r in scale_records if parse_ts(r.get("timestamp", "")).date() == cmp_date]

        results[test_name] = {
            "scale": scale,
            "earliest_date": str(parse_ts(earliest.get("timestamp", "")).date()),
            "earliest_ms": earliest["time_ms"],
            "ref_ms": ref_recs[-1]["time_ms"] if ref_recs else None,   # "today"
            "cmp_ms": cmp_recs[-1]["time_ms"] if cmp_recs else None,   # "yesterday"
        }
    return results


def print_report(
    results: dict,
    ref_label: str,
    cmp_label: str,
    categories: dict,
    show_all: bool,
    min_diff_pct: float,
):
    # Determine which tests to show
    categorized = set()
    for tests in categories.values():
        categorized.update(tests)

    uncategorized = [t for t in results if t not in categorized]

    cats_to_show = dict(categories)
    if show_all and uncategorized:
        cats_to_show["Other"] = sorted(uncategorized)

    COL = {
        "test": 52, "scale": 7, "earliest": 24, "cmp": 14, "ref": 14,
        "vs_cmp": 20, "vs_first": 20,
    }

    header = (
        f"  {'Test':<{COL['test']}} {'Scale':>{COL['scale']}}"
        f"  {'Earliest (date)':>{COL['earliest']}}"
        f"  {cmp_label:>{COL['cmp']}}"
        f"  {ref_label:>{COL['ref']}}"
        f"  {f'vs {cmp_label}':>{COL['vs_cmp']}}"
        f"  {'vs Earliest':>{COL['vs_first']}}"
    )
    divider = "  " + "-" * (len(header) - 2)

    any_printed = False
    for cat, tests in cats_to_show.items():
        cat_rows = []
        for t in tests:
            if t not in results:
                continue
            r = results[t]
            ref = r["ref_ms"]
            cmp = r["cmp_ms"]
            earliest = r["earliest_ms"]

            # Skip if change is below threshold (when we have both ref and cmp)
            best_available = ref if ref is not None else cmp
            if min_diff_pct > 0 and best_available is not None:
                diff_first = abs(((best_available - earliest) / earliest) * 100) if earliest else 0
                diff_cmp = abs(((ref - cmp) / cmp) * 100) if (ref and cmp) else 0
                if diff_first < min_diff_pct and diff_cmp < min_diff_pct:
                    continue

            e_str = f"{earliest:.2f}ms ({r['earliest_date']})"
            cmp_str = f"{cmp:.2f}ms" if cmp is not None else "N/A"
            ref_str = f"{ref:.2f}ms" if ref is not None else "N/A"
            vs_cmp = pct_str(ref, cmp)
            vs_first = pct_str(ref if ref is not None else cmp, earliest)

            cat_rows.append((t, r["scale"], e_str, cmp_str, ref_str, vs_cmp, vs_first))

        if not cat_rows:
            continue

        print(f"\n{'='*120}")
        print(f"  {cat.upper()}")
        print(f"{'='*120}")
        print(header)
        print(divider)
        for row in cat_rows:
            t, scale, e_str, cmp_str, ref_str, vs_cmp, vs_first = row
            scale_str = str(scale) if scale is not None else "N/A"
            print(
                f"  {t:<{COL['test']}} {scale_str:>{COL['scale']}}"
                f"  {e_str:>{COL['earliest']}}"
                f"  {cmp_str:>{COL['cmp']}}"
                f"  {ref_str:>{COL['ref']}}"
                f"  {vs_cmp:>{COL['vs_cmp']}}"
                f"  {vs_first:>{COL['vs_first']}}"
            )
        any_printed = True

    if not any_printed:
        print("\n  No results found for the given filters.")


def main():
    sys.stdout.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser(description="GECS Performance Report")
    parser.add_argument("--days", type=int, default=1,
                        help="Compare today vs N days ago (default: 1 = yesterday)")
    parser.add_argument("--category", type=str, default=None,
                        help="Filter to a single category (e.g. Query, System)")
    parser.add_argument("--scale", type=int, default=None,
                        help="Only show results for this scale (100, 1000, 10000)")
    parser.add_argument("--all", dest="show_all", action="store_true",
                        help="Show all tests including uncategorized")
    parser.add_argument("--min-diff", type=float, default=0.0,
                        help="Only show tests with >= this %% change (default: 0 = show all)")
    parser.add_argument("--perf-dir", type=str, default="reports/perf",
                        help="Path to perf JSONL directory")
    parser.add_argument("--ref-date", type=str, default=None,
                        help="Reference date YYYY-MM-DD (default: today)")
    parser.add_argument("--cmp-date", type=str, default=None,
                        help="Comparison date YYYY-MM-DD (default: N days ago)")
    args = parser.parse_args()

    ref_date = date.fromisoformat(args.ref_date) if args.ref_date else date.today()
    cmp_date = date.fromisoformat(args.cmp_date) if args.cmp_date else (ref_date - timedelta(days=args.days))

    ref_label = str(ref_date) if args.ref_date else "Today"
    cmp_label = str(cmp_date) if args.cmp_date else f"-{args.days}d"

    data = load_data(args.perf_dir)
    if not data:
        print(f"No data found in {args.perf_dir}/ — run performance tests first.")
        sys.exit(1)

    results = build_results(data, ref_date, cmp_date, args.scale)

    cats = CATEGORIES
    if args.category:
        matched = {k: v for k, v in CATEGORIES.items() if k.lower() == args.category.lower()}
        if not matched:
            print(f"Unknown category '{args.category}'. Valid: {', '.join(CATEGORIES)}")
            sys.exit(1)
        cats = matched

    print(f"\nGECS Performance Report")
    print(f"  Reference : {ref_label}  ({ref_date})")
    print(f"  Compare   : {cmp_label}  ({cmp_date})")
    print(f"  Scale pref: {args.scale or 'auto (10000 > 1000 > 100)'}")
    print(f"  Data dir  : {args.perf_dir}/")

    print_report(results, ref_label, cmp_label, cats, args.show_all, args.min_diff)
    print()


if __name__ == "__main__":
    main()
