# GECS Performance Viewer (uv project)

Interactive explorer for JSONL performance logs created by GECS test suites under `reports/perf/`.

## Install & Run (uv)

```bash
# From repo root (first time)
uv sync                     # create venv & install deps, now entry point available
uv run perf-viewer --dir reports/perf --out perf_report.html

# Show specific tests initially (space separated list)
uv run perf-viewer --dir reports/perf --default-tests test_world_query test_entity_lifecycle

# Remember last selection (persists in browser localStorage)
uv run perf-viewer --dir reports/perf --remember-selection

# Alternative direct module invocation (equivalent):
uv run python -m perf_viewer.cli --dir reports/perf

# Install as a global uv tool (run from repo root)
uv tool install ./tools/perf_viewer
perf-viewer --dir reports/perf
```

Fish shell users can still run the above commands unchanged.

## JSONL Format

Each line: `{"timestamp": <iso8601|epoch|epoch_ms>, "test": "name", "scale": <int>, "time_ms": <float>, "godot_version": "4.2.1"}`

- Additional fields preserved and shown via hover if present.
- Source file path added automatically as `__source_file`.

## Output

Generates a single self‑contained HTML file with:

- Left-side sidebar with checkboxes for each unique test (multi-select) plus Hide/Show toggle.
- One full-width Plotly chart row per test (only rows you select are shown).
- Lines per scale value within each test chart (one color per scale).
- Hover tooltip: test, scale, time_ms, godot_version.
- Visibility persistence when `--remember-selection` is used (row-level).
- Unified y-axis range across all charts for easier visual comparison of absolute time_ms values.

## Roadmap

- Percentile bands / smoothing.
- Regression detection annotations.
- Optional scale filtering UI.

## Development

```bash
# Add or upgrade deps
uv add pandas plotly
# Re-sync if pyproject changed
uv sync
# Run after changes
uv run perf-viewer
```

If your editor shows import warnings for pandas/plotly before installing, run the uv add command above; the code itself is correct.

## License

MIT (matches GECS framework license).
