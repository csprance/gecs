# GECS Performance Testing Guide

> **Framework-level performance testing for GECS developers**

This document explains how to run and interpret the GECS performance tests. This is primarily for framework developers and contributors who need to ensure GECS maintains high performance.

**For game developers:** See [Performance Optimization Guide](PERFORMANCE_OPTIMIZATION.md) for optimizing your games.

## 📋 Prerequisites

- GECS framework development environment
- gdUnit4 testing framework
- Godot 4.x
- Test system dependencies: `s_performance_test.gd` and `s_complex_performance_test.gd` in tests/systems/

## 🎯 Overview

The GECS performance test suite provides comprehensive benchmarking for all critical ECS operations:

- **Entity Operations**: Creation, destruction, world management
- **Component Operations**: Addition, removal, lookup, indexing
- **Query Performance**: All query types, caching, complex scenarios
- **System Processing**: Single/multiple systems, different scales
- **Array Operations**: Optimized set operations (intersect, union, difference)
- **Integration Tests**: Realistic game scenarios and stress tests

## 🚀 Running Performance Tests

### Prerequisites

Set the `GODOT_BIN` environment variable to your Godot executable:

```bash
# Windows
setx GODOT_BIN "C:\path\to\godot.exe"

# Linux/Mac
export GODOT_BIN="/path/to/godot"
```

### Running Individual Test Suites

```bash
# Entity performance tests
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_entities.gd

# Component performance tests
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_components.gd

# Query performance tests
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_queries.gd

# System performance tests
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_systems.gd

# Array operations performance tests
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_arrays.gd

# Integration performance tests
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_integration.gd
```

### Running Complete Performance Suite

```bash
# Run all performance tests with comprehensive reporting
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_master.gd

# Quick smoke test to verify basic performance
addons/gdUnit4/runtest.cmd -a res://addons/gecs/tests/performance/performance_test_master.gd::test_performance_smoke_test
```

## 📊 Test Scales

The performance tests use three different scales:

- **SMALL_SCALE**: 100 entities (for fine-grained testing)
- **MEDIUM_SCALE**: 1,000 entities (for typical game scenarios)
- **LARGE_SCALE**: 10,000 entities (for stress testing)

## ⏱️ Performance Thresholds

The tests include automatic performance threshold checking:

### Entity Operations

- Create 100 entities: < 10ms
- Create 1,000 entities: < 50ms
- Add 1,000 entities to world: < 100ms

### Component Operations

- Add components to 100 entities: < 10ms
- Add components to 1,000 entities: < 75ms
- Component lookup in 1,000 entities: < 30ms

### Query Performance

- Simple query on 100 entities: < 5ms
- Simple query on 1,000 entities: < 20ms
- Simple query on 10,000 entities: < 100ms
- Complex queries: < 50ms

### System Processing

- Process 100 entities: < 5ms
- Process 1,000 entities: < 30ms
- Process 10,000 entities: < 150ms

### Game Loop Performance

- Realistic game frame (1,000 entities): < 16ms (60 FPS target)

## 📈 Understanding Results

### Performance Metrics

Each test provides:

- **Average Time**: Mean execution time across multiple runs
- **Min/Max Time**: Best and worst execution times
- **Standard Deviation**: Consistency of performance
- **Operations/Second**: Throughput measurement
- **Time/Operation**: Per-item processing time

### Result Files

Performance results are saved to `res://reports/` with timestamps:

- `entity_performance_results.json`
- `component_performance_results.json`
- `query_performance_results.json`
- `system_performance_results.json`
- `array_performance_results.json`
- `integration_performance_results.json`
- `complete_performance_results_[timestamp].json`

### Interpreting Results

**Good Performance Indicators:**

- ✅ High operations/second (>10,000 for simple operations)
- ✅ Low standard deviation (consistent performance)
- ✅ Linear scaling with entity count
- ✅ Query cache hit rates >80%

**Performance Warning Signs:**

- ⚠️ Tests taking >50ms consistently
- ⚠️ Exponential time scaling with entity count
- ⚠️ High standard deviation (inconsistent performance)
- ⚠️ Cache hit rates <50%

## 🔄 Regression Testing

To monitor performance over time:

1. **Establish Baseline**: Run the complete test suite and save results
2. **Regular Testing**: Run tests after significant changes
3. **Compare Results**: Use the master test suite's regression checking
4. **Set Alerts**: Monitor for >20% performance degradation

## 🎯 Optimization Areas

Based on test results, focus optimization efforts on:

1. **Query Performance**: Most critical for gameplay
2. **Component Operations**: High frequency operations
3. **Array Operations**: Core performance building blocks
4. **System Processing**: Frame-rate critical
5. **Memory Usage**: Large-scale scenarios

## ⚠️ Common Issues

### Missing Dependencies
If tests fail with missing class errors, ensure these files exist:
- `addons/gecs/tests/systems/s_performance_test.gd`
- `addons/gecs/tests/systems/s_complex_performance_test.gd`

### gdUnit4 Setup
Beyond setting `GODOT_BIN`, ensure:
- gdUnit4 plugin is enabled in project settings
- All test component classes are properly defined

## 🔧 Custom Performance Tests

To create custom performance tests:

1. Extend `PerformanceTestBase`
2. Use the `benchmark()` method for timing
3. Set appropriate performance thresholds
4. Include in the master test suite

Example:

```gdscript
extends PerformanceTestBase

func test_my_custom_operation():
    var my_test = func():
        # Your operation here
        pass

    benchmark("My_Custom_Test", my_test)
    assert_performance_threshold("My_Custom_Test", 10.0, "Custom operation too slow")
```

## 📚 Related Documentation

- **[Performance Optimization](PERFORMANCE_OPTIMIZATION.md)** - User-focused optimization guide
- **[Best Practices](BEST_PRACTICES.md)** - Write performant ECS code
- **[Core Concepts](CORE_CONCEPTS.md)** - Understanding the ECS architecture

---

_This performance testing framework ensures GECS maintains high performance as the codebase evolves. It's a critical tool for framework development and optimization efforts._
