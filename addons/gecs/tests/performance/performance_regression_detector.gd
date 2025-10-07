## Performance Regression Detection Utility for GECS
## This utility can analyze historical performance data and detect regressions
## Usage: can be called from test suites or run standalone for analysis

class_name PerformanceRegressionDetector
extends RefCounted


## Configuration for regression detection
const DEFAULT_REGRESSION_THRESHOLD = 20.0  # 20% performance regression threshold
const DEFAULT_IMPROVEMENT_THRESHOLD = 5.0   # 5% improvement threshold
const REPORTS_DIR = "res://reports/perf/"


## Analyze all available performance reports for regressions
static func analyze_all_reports(regression_threshold: float = DEFAULT_REGRESSION_THRESHOLD) -> Dictionary:
	var analysis_results = {
		"summary": {
			"total_report_types": 0,
			"reports_with_regressions": 0,
			"reports_with_improvements": 0,
			"reports_stable": 0,
			"reports_insufficient_data": 0
		},
		"report_analyses": {}
	}
	
	var report_types = [
		"array-performance",
		"component-performance", 
		"entity-performance",
		"integration-performance",
		"query-performance",
		"set-performance",
		"system-performance"
	]
	
	analysis_results.summary.total_report_types = report_types.size()
	
	for report_type in report_types:
		var analysis = analyze_report_history(report_type, regression_threshold)
		analysis_results.report_analyses[report_type] = analysis
		
		# Update summary
		if analysis.status == "insufficient_data":
			analysis_results.summary.reports_insufficient_data += 1
		elif analysis.has_regressions:
			analysis_results.summary.reports_with_regressions += 1
		elif analysis.has_improvements:
			analysis_results.summary.reports_with_improvements += 1
		else:
			analysis_results.summary.reports_stable += 1
	
	return analysis_results


## Analyze a specific report type's historical data
static func analyze_report_history(report_type: String, regression_threshold: float = DEFAULT_REGRESSION_THRESHOLD) -> Dictionary:
	var historical_data = load_historical_data(report_type)
	
	if historical_data.size() < 2:
		return {
			"status": "insufficient_data",
			"report_type": report_type,
			"available_reports": historical_data.size(),
			"message": "Need at least 2 historical reports for comparison"
		}
	
	# Compare latest with previous
	var latest = historical_data[0]
	var previous = historical_data[1]
	
	var comparison = compare_reports(previous, latest, regression_threshold)
	comparison["report_type"] = report_type
	comparison["latest_timestamp"] = latest.timestamp
	comparison["previous_timestamp"] = previous.timestamp
	comparison["available_reports"] = historical_data.size()
	
	return comparison


## Compare two performance reports
static func compare_reports(baseline_report: Dictionary, current_report: Dictionary, regression_threshold: float) -> Dictionary:
	var baseline_results = baseline_report.get("results", {})
	var current_results = current_report.get("results", {})
	
	var comparison = {
		"status": "compared",
		"has_regressions": false,
		"has_improvements": false,
		"regressions": [],
		"improvements": [],
		"stable": [],
		"new_tests": [],
		"removed_tests": []
	}
	
	# Check for regressions and improvements
	for test_name in current_results:
		var current_result = current_results[test_name]
		
		if baseline_results.has(test_name):
			var baseline_result = baseline_results[test_name]
			var current_time = current_result.avg_time_ms
			var baseline_time = baseline_result.avg_time_ms
			
			if baseline_time > 0:
				var change_percent = ((current_time - baseline_time) / baseline_time) * 100.0
				
				var test_comparison = {
					"test_name": test_name,
					"current_time_ms": current_time,
					"baseline_time_ms": baseline_time,
					"change_percent": change_percent,
					"change_ms": current_time - baseline_time
				}
				
				if change_percent > regression_threshold:
					comparison.regressions.append(test_comparison)
					comparison.has_regressions = true
				elif change_percent < -DEFAULT_IMPROVEMENT_THRESHOLD:
					comparison.improvements.append(test_comparison)
					comparison.has_improvements = true
				else:
					comparison.stable.append(test_comparison)
		else:
			comparison.new_tests.append(test_name)
	
	# Check for removed tests
	for test_name in baseline_results:
		if not current_results.has(test_name):
			comparison.removed_tests.append(test_name)
	
	return comparison


## Load historical performance data for a report type
static func load_historical_data(report_type: String) -> Array[Dictionary]:
	var dir = DirAccess.open(REPORTS_DIR)
	var historical_data: Array[Dictionary] = []
	
	if not dir:
		prints("Performance history directory not found: %s" % REPORTS_DIR)
		return historical_data
	
	# Find all files matching the report pattern
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var pattern = "-%s.json" % report_type
	
	while file_name != "":
		if file_name.ends_with(pattern):
			var full_path = "%s%s" % [REPORTS_DIR, file_name]
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				var json_string = file.get_as_text()
				file.close()
				var json = JSON.new()
				var parse_result = json.parse(json_string)
				if parse_result == OK:
					historical_data.append(json.get_data())
		file_name = dir.get_next()
	
	# Sort by timestamp (most recent first)
	historical_data.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	return historical_data


## Print detailed analysis results
static func print_analysis_results(analysis_results: Dictionary):
	prints("\n=== GECS Performance Regression Analysis ===")
	
	var summary = analysis_results.summary
	prints("\nSummary:")
	prints("  Total report types analyzed: %d" % summary.total_report_types)
	prints("  Reports with regressions: %d" % summary.reports_with_regressions)
	prints("  Reports with improvements: %d" % summary.reports_with_improvements)
	prints("  Stable reports: %d" % summary.reports_stable)
	prints("  Reports with insufficient data: %d" % summary.reports_insufficient_data)
	
	# Print detailed results for each report type
	for report_type in analysis_results.report_analyses:
		var analysis = analysis_results.report_analyses[report_type]
		prints("\n--- %s ---" % report_type.capitalize().replace("-", " "))
		
		if analysis.status == "insufficient_data":
			prints("  Status: %s" % analysis.message)
			continue
		
		prints("  Available reports: %d" % analysis.available_reports)
		prints("  Latest: %s" % analysis.latest_timestamp)
		prints("  Previous: %s" % analysis.previous_timestamp)
		
		if analysis.has_regressions:
			prints("  ⚠️  REGRESSIONS (%d):" % analysis.regressions.size())
			for regression in analysis.regressions:
				prints("    %s: %.3f ms → %.3f ms (%.1f%% slower)" % [
					regression.test_name,
					regression.baseline_time_ms,
					regression.current_time_ms,
					regression.change_percent
				])
		
		if analysis.has_improvements:
			prints("  ✅ IMPROVEMENTS (%d):" % analysis.improvements.size())
			for improvement in analysis.improvements:
				prints("    %s: %.3f ms → %.3f ms (%.1f%% faster)" % [
					improvement.test_name,
					improvement.baseline_time_ms,
					improvement.current_time_ms,
					abs(improvement.change_percent)
				])
		
		if analysis.stable.size() > 0:
			prints("  ➡️  Stable tests: %d" % analysis.stable.size())
		
		if analysis.new_tests.size() > 0:
			prints("  🆕 New tests: %d" % analysis.new_tests.size())
		
		if analysis.removed_tests.size() > 0:
			prints("  🗑️  Removed tests: %d" % analysis.removed_tests.size())


## Generate a concise regression report for CI/CD
static func generate_regression_report(analysis_results: Dictionary) -> String:
	var summary = analysis_results.summary
	var report_lines = []
	
	report_lines.append("# GECS Performance Analysis Report")
	report_lines.append("")
	report_lines.append("## Summary")
	report_lines.append("- Total report types: %d" % summary.total_report_types)
	report_lines.append("- Regressions detected: %d" % summary.reports_with_regressions)
	report_lines.append("- Improvements detected: %d" % summary.reports_with_improvements)
	report_lines.append("- Stable performance: %d" % summary.reports_stable)
	
	if summary.reports_with_regressions > 0:
		report_lines.append("")
		report_lines.append("## ⚠️ Performance Regressions Detected")
		
		for report_type in analysis_results.report_analyses:
			var analysis = analysis_results.report_analyses[report_type]
			if analysis.get("has_regressions", false):
				report_lines.append("")
				report_lines.append("### %s" % report_type.capitalize().replace("-", " "))
				
				for regression in analysis.regressions:
					report_lines.append("- **%s**: %.1f%% slower (%.3f ms → %.3f ms)" % [
						regression.test_name,
						regression.change_percent,
						regression.baseline_time_ms,
						regression.current_time_ms
					])
	
	if summary.reports_with_improvements > 0:
		report_lines.append("")
		report_lines.append("## ✅ Performance Improvements")
		
		for report_type in analysis_results.report_analyses:
			var analysis = analysis_results.report_analyses[report_type]
			if analysis.get("has_improvements", false):
				report_lines.append("")
				report_lines.append("### %s" % report_type.capitalize().replace("-", " "))
				
				for improvement in analysis.improvements:
					report_lines.append("- **%s**: %.1f%% faster (%.3f ms → %.3f ms)" % [
						improvement.test_name,
						abs(improvement.change_percent),
						improvement.baseline_time_ms,
						improvement.current_time_ms
					])
	
	return "\n".join(report_lines)


## Save regression analysis to file
static func save_analysis_report(analysis_results: Dictionary, filename: String = ""):
	if filename.is_empty():
		var timestamp = Time.get_datetime_dict_from_system()
		var date_str = "%02d-%02d-%04d" % [timestamp.month, timestamp.day, timestamp.year]
		filename = "res://reports/perf/%s-regression-analysis.json" % date_str
	
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		var data = {
			"timestamp": Time.get_datetime_string_from_system(),
			"analysis_results": analysis_results
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		prints("Regression analysis saved to: %s" % filename)
		return filename
	else:
		prints("Failed to save regression analysis to: %s" % filename)
		return ""


## Main entry point for standalone analysis
static func run_analysis(regression_threshold: float = DEFAULT_REGRESSION_THRESHOLD):
	prints("Starting GECS Performance Regression Analysis...")
	
	var analysis_results = analyze_all_reports(regression_threshold)
	print_analysis_results(analysis_results)
	
	# Save analysis results
	var filename = save_analysis_report(analysis_results)
	
	# Generate markdown report
	var markdown_report = generate_regression_report(analysis_results)
	var md_filename = filename.replace(".json", ".md")
	var md_file = FileAccess.open(md_filename, FileAccess.WRITE)
	if md_file:
		md_file.store_string(markdown_report)
		md_file.close()
		prints("Markdown report saved to: %s" % md_filename)
	
	# Return true if no regressions found, false otherwise
	return analysis_results.summary.reports_with_regressions == 0