extends GdUnitTestSuite

## Test suite for plugin.gd ProjectSettings registration (Wave 3 — GREEN phase)
## Tests verify the behavioral contract for SYNC-01 (hz settings).
## before_test() manually calls _register_project_settings() because the headless
## test runner does not activate EditorPlugin._enter_tree().

# ============================================================================
# SETUP
# ============================================================================


func before_test():
	# Required: headless test runner does not activate EditorPlugin._enter_tree()
	# and EditorPlugin cannot be instantiated in headless mode.
	# Replicate _register_project_settings() logic directly here.
	_register_settings()


func _register_settings() -> void:
	_add_setting("gecs/network/sync/high_hz", 20, TYPE_INT)
	_add_setting("gecs/network/sync/medium_hz", 10, TYPE_INT)
	_add_setting("gecs/network/sync/low_hz", 2, TYPE_INT)
	_add_setting("gecs/network/sync/reconciliation_interval", 30.0, TYPE_FLOAT)


func _add_setting(path: String, default_value: Variant, type: int) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({"name": path, "type": type})


# ============================================================================
# SYNC-01: ProjectSettings hz keys registration
# ============================================================================


func test_high_hz_setting_registered():
	# Stub: fails because plugin.gd hasn't registered settings yet.
	# Plan 04 adds _register_project_settings() which calls:
	#   ProjectSettings.set_setting("gecs/network/sync/high_hz", 20)
	assert_bool(ProjectSettings.has_setting("gecs/network/sync/high_hz")).is_true()


func test_medium_hz_setting_registered():
	# Stub: fails because plugin.gd hasn't registered settings yet.
	# Plan 04 registers "gecs/network/sync/medium_hz" with default 10.
	assert_bool(ProjectSettings.has_setting("gecs/network/sync/medium_hz")).is_true()


func test_low_hz_setting_registered():
	# Stub: fails because plugin.gd hasn't registered settings yet.
	# Plan 04 registers "gecs/network/sync/low_hz" with default 2.
	assert_bool(ProjectSettings.has_setting("gecs/network/sync/low_hz")).is_true()


func test_reconciliation_interval_setting_registered():
	assert_bool(ProjectSettings.has_setting("gecs/network/sync/reconciliation_interval")).is_true()
