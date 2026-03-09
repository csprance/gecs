extends GdUnitTestSuite

## Test suite for plugin.gd ProjectSettings registration (Wave 0 — RED phase stubs)
## Tests define the behavioral contract for SYNC-01 (hz settings).
## All tests FAIL RED because plugin.gd hasn't registered settings yet.
## Plan 04 adds _register_project_settings() to plugin._enter_tree() and turns these GREEN.

# ============================================================================
# SYNC-01: ProjectSettings hz keys registration
# ============================================================================


func test_high_hz_setting_registered():
	# Stub: fails because plugin.gd hasn't registered settings yet.
	# Plan 04 adds _register_project_settings() which calls:
	#   ProjectSettings.set_setting("gecs_network/sync/high_hz", 20)
	assert_bool(ProjectSettings.has_setting("gecs_network/sync/high_hz")).is_true()


func test_medium_hz_setting_registered():
	# Stub: fails because plugin.gd hasn't registered settings yet.
	# Plan 04 registers "gecs_network/sync/medium_hz" with default 10.
	assert_bool(ProjectSettings.has_setting("gecs_network/sync/medium_hz")).is_true()


func test_low_hz_setting_registered():
	# Stub: fails because plugin.gd hasn't registered settings yet.
	# Plan 04 registers "gecs_network/sync/low_hz" with default 2.
	assert_bool(ProjectSettings.has_setting("gecs_network/sync/low_hz")).is_true()
