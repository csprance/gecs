#!/usr/bin/env python3
from __future__ import annotations

"""GECS Performance Results Explorer (UV Project Edition)

Interactive dashboard for JSONL perf logs under reports/perf/**.

Features:
    - Dropdown test selection; per-scale time_ms lines.
    - Timestamp normalization (ISO8601 or epoch).
    - Hover details include test, scale, time_ms, godot_version, source file.

Run with uv:
    uv run perf-viewer                 # default directory reports/perf
    uv run perf-viewer --dir reports/perf --out perf_report.html

Install globally (optional):
    uv tool install .

Expected JSONL fields: timestamp, test, scale, time_ms, optional godot_version.
"""
import argparse
import math
from typing import Any, Iterable, List, Dict, Tuple, TYPE_CHECKING
import json
import os
import sys
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional

try:
    import pandas as pd  # type: ignore
    import plotly.graph_objs as go  # type: ignore
    from plotly.offline import plot  # type: ignore

    if TYPE_CHECKING:  # lightweight stubs for editors

        class _Scatter:  # pragma: no cover - typing aid only
            ...

        class _Figure:
            data: List[Any]

        # Re-map go.Scatter for type hints
        go.Scatter = _Scatter  # type: ignore
except ImportError:  # pragma: no cover
    print("Install dependencies: uv add pandas plotly", file=sys.stderr)
    raise


def parse_timestamp(ts: Any) -> datetime:
    """Parse timestamp (ISO8601 or epoch seconds/millis) producing UTC-aware datetimes."""
    if isinstance(ts, (int, float)):
        # Interpret large numeric (>1e12) as milliseconds.
        if ts > 1e12:
            return datetime.fromtimestamp(ts / 1000.0, tz=timezone.utc)
        return datetime.fromtimestamp(ts, tz=timezone.utc)
    if isinstance(ts, str):
        for fmt in (
            "%Y-%m-%dT%H:%M:%S.%fZ",
            "%Y-%m-%dT%H:%M:%S.%f",
            "%Y-%m-%dT%H:%M:%S",
            "%Y-%m-%d %H:%M:%S",
        ):
            try:
                return datetime.strptime(ts, fmt).replace(tzinfo=timezone.utc)
            except ValueError:
                continue
        # Fallback to fromisoformat after stripping trailing Z.
        try:
            iso = ts.replace("Z", "")
            return datetime.fromisoformat(iso).replace(tzinfo=timezone.utc)
        except Exception:
            pass
    # Final fallback: now (UTC)
    return datetime.now(timezone.utc)


def load_jsonl_files(root_dir: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for dirpath, _, filenames in os.walk(root_dir):
        for fname in filenames:
            if not fname.lower().endswith(".jsonl"):
                continue
            full_path = os.path.join(dirpath, fname)
            with open(full_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                        obj["__source_file"] = os.path.relpath(full_path, root_dir)
                        rows.append(obj)
                    except json.JSONDecodeError:
                        continue
    return rows


def build_dataframe(rows: List[Dict[str, Any]]) -> "pd.DataFrame":
    if not rows:
        return pd.DataFrame(
            columns=[
                "timestamp",
                "test",
                "scale",
                "time_ms",
                "godot_version",
                "__source_file",
            ]
        )
    df = pd.DataFrame(rows)
    for col in ["timestamp", "test", "scale", "time_ms"]:
        if col not in df.columns:
            raise ValueError(f"Missing required field '{col}' in performance data")
    df["_dt"] = df["timestamp"].apply(parse_timestamp)
    return df.sort_values(by=["test", "scale", "_dt"])  # stable ordering


def generate_plot(df: "pd.DataFrame", default_tests: List[str], remember: bool) -> str:
    if df.empty:
        return "<h3>No performance data found.</h3>"
    tests = list(sorted([str(x) for x in df["test"].unique().tolist()]))
    scales = list(sorted(df["scale"].unique().tolist()))
    default_set = (
        set(default_tests) if default_tests else {tests[0]} if tests else set()
    )

    # Compute a shared y-axis range across all tests using a robust (95th percentile) cap
    # to avoid extreme outliers (e.g., a sporadic 100k spike) dominating the scale.
    raw_min = float(df["time_ms"].min())
    raw_max = float(df["time_ms"].max())
    # Use pandas quantile for robustness (falls back to raw_max if NaN)
    robust_max = float(df["time_ms"].quantile(0.95)) if len(df) else raw_max
    if math.isnan(robust_max) or robust_max <= 0:
        robust_max = raw_max

    # Decide whether to clip: only clip if raw_max is significantly larger than robust_max
    clip = raw_max > robust_max * 1.2  # 20%+ higher indicates outliers
    target_max = robust_max if clip else raw_max

    def nice_ceiling(x: float) -> float:
        if x <= 0:
            return 1.0
        exp = math.floor(math.log10(x))
        scale = 10 ** exp
        for m in (1, 2, 2.5, 5, 10):
            if x <= m * scale:
                return m * scale
        return 10 * scale

    clipped_max_nice = nice_ceiling(target_max)
    full_max_nice = nice_ceiling(raw_max)
    shared_range = [0.0, clipped_max_nice]

    # Build per-test figure rows
    rows_html: List[str] = []
    for test_name in tests:
        sub = df[df["test"] == test_name]
        traces = []
        for scale_val in scales:
            sub_scale = sub[sub["scale"] == scale_val]
            if sub_scale.empty:
                continue
            hover_text = [
                f"test={test_name}<br>scale={scale_val}<br>time_ms={t:.3f}<br>godot={gv}"
                for t, gv in zip(
                    sub_scale["time_ms"], sub_scale.get("godot_version", ["-"])
                )
            ]
            traces.append(
                go.Scatter(
                    x=sub_scale["_dt"],
                    y=sub_scale["time_ms"],
                    mode="lines+markers",
                    name=f"scale={scale_val}",
                    hovertext=hover_text,
                    hoverinfo="text",
                )
            )
        if not traces:
            continue
        layout = go.Layout(
            title=f"{test_name}",
            xaxis=dict(title="Time"),
            yaxis=dict(title="time_ms", range=shared_range),
            legend=dict(orientation="h"),
            margin=dict(l=50, r=20, t=40, b=50),
            height=320,
        )
        fig = go.Figure(data=traces, layout=layout)
        fig_div = plot(fig, include_plotlyjs=False, output_type="div")
        row_style = "" if test_name in default_set else "display:none;"
        rows_html.append(
            f"<div class='test-row' data-test='{test_name}' style='{row_style}'>"
            + fig_div
            + "</div>"
        )

    cb_parts: List[str] = []
    for t in tests:
        checked_attr = " checked" if t in default_set else ""
        cb_parts.append(
            f"<label style='display:block'><input type='checkbox' class='test-toggle' value='{t}'{checked_attr}/> {t}</label>"
        )
    checks_html = "".join(cb_parts)
    storage_flag = "true" if remember else "false"
    scale_toggle_btn = (
        "<button id='toggle-scale' style='margin-top:4px;background:#2d2d2d;color:#ccc;border:1px solid #444;padding:2px 8px;border-radius:4px;cursor:pointer;font-size:11px;'>"
        + ("Full Scale" if clip else "Clip Outliers")
        + "</button>"
        if raw_max != 0 and (clip or raw_max != clipped_max_nice)
        else ""
    )
    scale_badge = (
        f"<span id='scale-mode-label' style='font-size:10px;color:#888;margin-left:4px;'>{'clipped' if clip else 'full'}</span>"
        if scale_toggle_btn
        else ""
    )
    sidebar = (
        "<div id='sidebar' class='expanded'>"
        "<div class='sidebar-header'>"
        "<span class='title'>Tests" + scale_badge + "</span>"
        "<button id='collapse-btn' title='Hide sidebar'>Hide ✕</button>"
        "</div>"
        f"<div id='test-list'>{checks_html}</div>"
        "<div class='sidebar-actions'>"
        "<button id='select-all'>All</button>"
        "<button id='clear-all'>None</button>"
        "<button id='invert'>Invert</button>"
        + scale_toggle_btn +
        "</div>"
        "<div class='sidebar-footer'>Row visibility auto-saved.</div>"
        "</div>"
        "<button id='show-sidebar-btn' style='display:none;position:fixed;top:0.5rem;left:0.5rem;z-index:1000;background:#333;color:#eee;border:1px solid #444;padding:4px 10px;border-radius:4px;font-size:12px;cursor:pointer;'>Show Tests</button>"
    )
    content = "<div id='content'>" + "".join(rows_html) + "</div>"
    css = (
        "<style>"
        "html,body{margin:0;padding:0;font-family:system-ui,sans-serif;background:#111;color:#eee}"
        "#layout{display:flex;align-items:stretch;width:100%;}"
        "#sidebar{background:#1e1e1e;width:260px;flex:0 0 260px;display:flex;flex-direction:column;border-right:1px solid #333;transition:transform .25s ease,opacity .25s ease;}"
        "#sidebar.hidden{transform:translateX(-270px);opacity:0;pointer-events:none;}"
        "#sidebar .sidebar-header{display:flex;align-items:center;justify-content:space-between;padding:.5rem .6rem;border-bottom:1px solid #333;}"
        "#sidebar .sidebar-header .title{font-weight:600;font-size:14px;}"
        "#collapse-btn{background:#333;color:#ddd;border:1px solid #444;padding:2px 8px;border-radius:4px;cursor:pointer;font-size:11px;}"
        "#test-list{overflow:auto;padding:.5rem;flex:1 1 auto;}"
        "#test-list label{font-size:12px;margin-bottom:2px;}"
        "#sidebar .sidebar-actions{padding:.25rem .6rem;display:flex;gap:.5rem;flex-wrap:wrap;}"
        "#sidebar .sidebar-actions button{background:#2d2d2d;color:#ccc;border:1px solid #444;padding:2px 8px;border-radius:4px;cursor:pointer;font-size:11px;}"
        "#sidebar .sidebar-footer{padding:.4rem .6rem;font-size:10px;color:#aaa;border-top:1px solid #333;}"
        "#content{flex:1 1 auto;padding:0.75rem;min-width:0;transition:margin-left .25s ease;}"
        ".test-row{margin-bottom:1.5rem;background:#181818;padding:.75rem .75rem .5rem;border-radius:6px;box-shadow:0 1px 3px rgba(0,0,0,.4);}"
        ".test-row:last-child{margin-bottom:0;}"
        ".test-row .plotly-graph-div{width:100% !important;}"
        ".test-row h2{margin:0 0 .5rem;font-size:16px;}"
        "button:focus-visible{outline:2px solid #666;outline-offset:2px;}"
        "@media (max-width:900px){#sidebar{position:fixed;z-index:1000;height:100vh;}#content{margin-left:0;padding-top:300px}}"
        "</style>"
    )
    script = (
        "<script>"
        "document.addEventListener('DOMContentLoaded', function(){"
    f"const remember={storage_flag};const key='gecs_perf_selected_tests_rows';"
    f"const clippedRange=[0,{clipped_max_nice}];const fullRange=[0,{full_max_nice}];let scaleMode={'\"clipped\"' if clip else '\"full\"'};"
        "const checkboxes=[...document.querySelectorAll('.test-toggle')];"
        "const rows=[...document.querySelectorAll('.test-row')];"
        "const sidebar=document.getElementById('sidebar');const collapseBtn=document.getElementById('collapse-btn');const showBtn=document.getElementById('show-sidebar-btn');"
        "function applySelection(sel){const set=new Set(sel);rows.forEach(r=>{r.style.display=set.has(r.dataset.test)?'':'none';});resizeCharts();}"
        "function currentSelection(){return checkboxes.filter(cb=>cb.checked).map(cb=>cb.value);}"
        "function loadPersisted(){if(!remember)return null;try{const raw=localStorage.getItem(key);if(!raw)return null;return JSON.parse(raw);}catch(e){return null}}"
        "function persist(sel){if(remember)localStorage.setItem(key,JSON.stringify(sel));}"
        "function resizeCharts(){if(!window.Plotly)return;document.querySelectorAll('.plotly-graph-div').forEach(g=>{try{window.Plotly.Plots.resize(g);}catch(e){}});}"
        "const persisted=loadPersisted();if(persisted){const set=new Set(persisted);checkboxes.forEach(cb=>cb.checked=set.has(cb.value));}"
        "applySelection(currentSelection());"
        "checkboxes.forEach(cb=>cb.addEventListener('change',()=>{const sel=currentSelection();applySelection(sel);persist(sel);}));"
        "document.getElementById('select-all').onclick=()=>{checkboxes.forEach(cb=>cb.checked=true);const sel=currentSelection();applySelection(sel);persist(sel);};"
        "document.getElementById('clear-all').onclick=()=>{checkboxes.forEach(cb=>cb.checked=false);const sel=currentSelection();applySelection(sel);persist(sel);};"
        "document.getElementById('invert').onclick=()=>{checkboxes.forEach(cb=>cb.checked=!cb.checked);const sel=currentSelection();applySelection(sel);persist(sel);};"
        "collapseBtn.onclick=()=>{sidebar.classList.add('hidden');showBtn.style.display='block';setTimeout(resizeCharts,300);};"
        "showBtn.onclick=()=>{sidebar.classList.remove('hidden');showBtn.style.display='none';setTimeout(resizeCharts,100);};"
        "const toggleScale=document.getElementById('toggle-scale');const scaleLabel=document.getElementById('scale-mode-label');"
        "if(toggleScale){toggleScale.onclick=()=>{scaleMode=scaleMode==='clipped'?'full':'clipped';const r=scaleMode==='clipped'?clippedRange:fullRange;toggleScale.textContent=scaleMode==='clipped'?'Full Scale':'Clip Outliers';if(scaleLabel) scaleLabel.textContent=scaleMode;document.querySelectorAll('.plotly-graph-div').forEach(g=>{try{Plotly.relayout(g,{ 'yaxis.range': r });}catch(e){}});};}"
        "window.addEventListener('resize',resizeCharts);"
        "});"
        "</script>"
    )
    plotly_js = "<script src='https://cdn.plot.ly/plotly-latest.min.js'></script>"
    return plotly_js + css + "<div id='layout'>" + sidebar + content + "</div>" + script


def build_html(body: str) -> str:
    generated = datetime.now(timezone.utc).isoformat()
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8"/>
    <title>GECS Performance Explorer</title>
    <style>
        body{{font-family:system-ui,sans-serif;margin:0;padding:1rem}}
        header{{margin-bottom:1rem}}
        .info{{font-size:.8rem;color:#666}}
    </style>
</head>
<body>
    <header><h1>GECS Performance Explorer</h1><p>Use the left panel to show/hide tests (All/None/Invert or individual checkboxes).</p></header>
    {body}
    <footer class="info">Generated at {generated}</footer>
</body>
</html>"""


def main(argv: Optional[List[str]] = None) -> None:
    parser = argparse.ArgumentParser(description="GECS performance JSONL explorer")
    parser.add_argument("--dir", default="reports/perf", help="Root perf directory")
    parser.add_argument("--out", default="perf_report.html", help="Output HTML file")
    parser.add_argument(
        "--default-tests",
        nargs="*",
        default=[],
        help="Tests to show initially (space-separated). If empty, first test is shown.",
    )
    parser.add_argument(
        "--remember-selection",
        action="store_true",
        help="Persist selected tests in localStorage to restore on next open.",
    )
    args = parser.parse_args(argv)

    rows = load_jsonl_files(args.dir)
    df = build_dataframe(rows)
    body = generate_plot(df, args.default_tests, args.remember_selection)
    html = build_html(body)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(html)
    print(
        f"Wrote {args.out} (tests={df['test'].nunique() if not df.empty else 0} rows={len(df)})"
    )


if __name__ == "__main__":  # pragma: no cover
    main()
