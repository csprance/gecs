## Deterministic statistics checks: these assert arithmetic, not machine speed.
extends GdUnitTestSuite


func test_record_samples_preserves_order_and_computes_statistics():
	var samples: Array[float] = [4.0, 1.0, 3.0, 2.0]
	var result := PerfHelpers.record_samples(
		"helper_samples_even", 4, samples, 2, {"fixture": true}
	)
	assert_float(result.median_ms).is_equal(2.5)
	assert_float(result.mean_ms).is_equal(2.5)
	assert_float(result.min_ms).is_equal(1.0)
	assert_float(result.max_ms).is_equal(4.0)
	assert_float(result.p95_ms).is_equal(4.0)
	assert_float(result.time_ms).is_equal(result.median_ms)
	assert_array(samples).is_equal([4.0, 1.0, 3.0, 2.0])
	assert_array(result.samples_ms).is_equal(samples)
	samples[0] = 100.0
	assert_float(result.samples_ms[0]).is_equal(4.0)
	assert_bool(result.workload.fixture).is_true()


func test_nearest_rank_p95_and_odd_median():
	var samples: Array[float] = []
	for i in range(1, 22):
		samples.append(float(i))
	var result := PerfHelpers.record_samples("helper_samples_odd", 21, samples)
	assert_float(result.median_ms).is_equal(11.0)
	assert_float(result.p95_ms).is_equal(20.0)
	assert_int(result.runs).is_equal(21)
