extends GdUnitTestSuite

## Test suite for NetAdapter
## Tests singleplayer defaults, peer lists, and cache invalidation.

# ============================================================================
# SINGLEPLAYER DEFAULTS (no multiplayer peer)
# ============================================================================


func test_is_server_returns_true_singleplayer():
	var adapter = NetAdapter.new()
	# Force no multiplayer by invalidating cache
	adapter.invalidate_cache()
	# In test environment without multiplayer peer, is_server should return true
	# (singleplayer = "server")
	assert_bool(adapter.is_server()).is_true()


func test_get_my_peer_id_returns_one_singleplayer():
	var adapter = NetAdapter.new()
	# Default peer_id in singleplayer should be 1
	assert_int(adapter.get_my_peer_id()).is_equal(1)


func test_is_in_game_reflects_peer_status():
	var adapter = NetAdapter.new()
	# GdUnit4 runs with a SceneTree that has an OfflineMultiplayerPeer,
	# which reports CONNECTION_CONNECTED. Verify is_in_game matches
	# the actual peer connection status.
	var mp = adapter.get_multiplayer()
	if mp and mp.multiplayer_peer:
		var connected = (
			mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		)
		assert_bool(adapter.is_in_game()).is_equal(connected)
	else:
		assert_bool(adapter.is_in_game()).is_false()


func test_get_remote_sender_id_returns_zero():
	var adapter = NetAdapter.new()
	# No RPC in progress, should return 0
	assert_int(adapter.get_remote_sender_id()).is_equal(0)


# ============================================================================
# PEER LISTS
# ============================================================================


func test_get_connected_peers_empty_singleplayer():
	var adapter = NetAdapter.new()
	var peers = adapter.get_connected_peers()
	assert_array(peers).is_empty()


func test_get_all_peers_includes_self():
	var adapter = NetAdapter.new()
	var peers = adapter.get_all_peers()
	assert_bool(peers.has(1)).is_true()


func test_get_all_peers_size_singleplayer():
	var adapter = NetAdapter.new()
	var peers = adapter.get_all_peers()
	# Only self (peer_id=1)
	assert_int(peers.size()).is_equal(1)


# ============================================================================
# CACHE
# ============================================================================


func test_invalidate_cache_clears_state():
	var adapter = NetAdapter.new()
	# Force cache population
	adapter.get_multiplayer()
	# Invalidate
	adapter.invalidate_cache()
	assert_bool(adapter._cache_valid).is_false()
	assert_object(adapter._cached_multiplayer).is_null()


func test_get_multiplayer_caches_result():
	var adapter = NetAdapter.new()
	var mp1 = adapter.get_multiplayer()
	var mp2 = adapter.get_multiplayer()
	# Should return same reference (cached)
	if mp1 != null:
		assert_object(mp2).is_same(mp1)
		assert_bool(adapter._cache_valid).is_true()
	else:
		# If multiplayer is not available in test env, both should be null
		assert_object(mp2).is_null()


func test_invalidate_then_refetch():
	var adapter = NetAdapter.new()
	adapter.get_multiplayer()
	adapter.invalidate_cache()
	# After invalidation, next call should re-fetch
	var mp = adapter.get_multiplayer()
	# Result depends on test environment, but should not crash
	if mp != null:
		assert_bool(adapter._cache_valid).is_true()
	else:
		assert_bool(adapter._cache_valid).is_false()


# ============================================================================
# MULTIPLAYER PROPERTY ACCESSOR
# ============================================================================


func test_multiplayer_property_returns_same_as_get_multiplayer():
	var adapter = NetAdapter.new()
	var via_property = adapter.multiplayer
	var via_method = adapter.get_multiplayer()
	if via_property != null:
		assert_object(via_property).is_same(via_method)
	else:
		assert_object(via_method).is_null()
