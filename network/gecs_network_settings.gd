## GECSNetworkSettings — typed constants for all gecs/network/sync/* ProjectSettings paths.
##
## Use these constants instead of raw strings to prevent typos and make
## refactoring safe. All four network settings are registered by
## addons/gecs/plugin.gd via add_gecs_network_project_settings().
##
## Usage:
##   ProjectSettings.get_setting(GECSNetworkSettings.HIGH_HZ, 20)
class_name GECSNetworkSettings

## Project Settings path for high-priority sync rate (default: 20 Hz).
const HIGH_HZ := "gecs/network/sync/high_hz"

## Project Settings path for medium-priority sync rate (default: 10 Hz).
const MEDIUM_HZ := "gecs/network/sync/medium_hz"

## Project Settings path for low-priority sync rate (default: 2 Hz).
const LOW_HZ := "gecs/network/sync/low_hz"

## Project Settings path for reconciliation broadcast interval in seconds (default: 30.0).
const RECONCILIATION_INTERVAL := "gecs/network/sync/reconciliation_interval"
