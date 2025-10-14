# GECS Changelog

## [5.0.0] - 2025-01-XX - Relationship System Complete Overhaul

### ⚠️ BREAKING CHANGES

#### Removed Weak/Strong Matching System

The weak/strong matching system has been completely replaced with a simpler, more intuitive approach:

- **`weak` parameter removed** from all relationship methods
- **`Component.equals()` method removed** - use component queries instead
- **Type matching is now the default** - matches by component type only
- **Component queries for property matching** - use dictionaries for property-based filtering

**Migration:**

| Old (v4.x)                                                                | New (v5.0)                                                                           |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `entity.has_relationship(Relationship.new(C_Eats.new(5), target), false)` | `entity.has_relationship(Relationship.new({C_Eats: {'value': {"_eq": 5}}}, target))` |
| `entity.has_relationship(Relationship.new(C_Eats.new(), target), true)`   | `entity.has_relationship(Relationship.new(C_Eats.new(), target))`                    |
| `entity.get_relationship(rel, true, true)`                                | `entity.get_relationship(rel)`                                                       |
| `entity.get_relationships(rel, true)`                                     | `entity.get_relationships(rel)`                                                      |
| Override `equals()` in component                                          | Use component queries: `{C_Type: {'prop': {"_eq": value}}}`                          |

#### Component Query Improvements

- **Target component queries added** - Query both relation AND target component properties
- **Cannot add query relationships to entities** - Queries are for matching only, not storage
- **Fixed bug with falsy values** - Component queries now correctly handle `0`, `false`, etc.

### ✨ New Features

#### Simplified Relationship Matching

```gdscript
# Type matching (default) - matches by component type
entity.has_relationship(Relationship.new(C_Damage.new(), target))

# Component query - matches by property criteria
entity.has_relationship(Relationship.new({C_Damage: {'amount': {"_gte": 50}}}, target))

# Query both relation AND target
var strong_buffs = ECS.world.query.with_relationship([
    Relationship.new(
        {C_Buff: {'duration': {"_gt": 10}}},
        {C_Player: {'level': {"_gte": 5}}}
    )
]).execute()
```

#### Target Component Queries (NEW!)

```gdscript
# Query relationships by target component properties
var high_hp_targets = ECS.world.query.with_relationship([
    Relationship.new(C_Targeting.new(), {C_Health: {'hp': {"_gte": 100}}})
]).execute()

# Mix relation and target queries
var critical_effects = ECS.world.query.with_relationship([
    Relationship.new(
        {C_Damage: {'type': {"_in": ["fire", "ice"]}}},
        {C_Entity: {'level': {"_gte": 10}}}
    )
]).execute()
```

#### Limited Relationship Removal

```gdscript
# Remove specific number of relationships
entity.remove_relationship(Relationship.new(C_Damage.new(), null), 1)  # Remove 1 damage
entity.remove_relationship(Relationship.new(C_Buff.new(), null), 3)    # Remove up to 3 buffs

# Combine with component queries
entity.remove_relationship(
    Relationship.new({C_Damage: {'amount': {"_gt": 20}}}, null),
    2  # Remove up to 2 high-damage effects
)
```

### 🚨 Migration Guide

#### 1. Remove `weak` Parameters

```gdscript
# ❌ Old (v4.x)
entity.has_relationship(rel, true)
entity.get_relationship(rel, true, true)
entity.get_relationships(rel, false)

# ✅ New (v5.0)
entity.has_relationship(rel)
entity.get_relationship(rel)
entity.get_relationships(rel)
```

#### 2. Replace Strong Matching with Component Queries

```gdscript
# ❌ Old (v4.x) - strong matching for exact values
entity.has_relationship(Relationship.new(C_Eats.new(5), target), false)

# ✅ New (v5.0) - component query
entity.has_relationship(Relationship.new({C_Eats: {'value': {"_eq": 5}}}, target))
```

#### 3. Remove `equals()` Overrides

```gdscript
# ❌ Old (v4.x) - custom equals() method
class_name C_Damage extends Component:
    @export var amount: int = 0

    func equals(other: Component) -> bool:
        return amount == other.amount

# ✅ New (v5.0) - use component queries
# No equals() method needed!
# Query by property: {C_Damage: {'amount': {"_eq": 50}}}
```

#### 4. Check any deps function and sorting order

Topological sort was broken in previous versions. It is now fixed and as a result some systems may now be running in the correct order defined in the deps
but it may end up to be the wrong order for your game code. Check these depenencies by doing: `print(ECS.world.systems_by_group)` this will show you the sorted
systems and how they are running. Do a comparison between this version and the previous versions of GECS.

### 🧪 Test Suite Improvements

#### Performance Test Cleanup

- **Eliminated orphan nodes** - Refactored all performance tests to use `scene_runner` pattern
- **Proper lifecycle management** - Tests now use `auto_free()` and `world.purge()` for cleanup
- **Consistent test structure** - All performance tests follow same pattern as core tests
- **Zero orphan nodes** - Performance tests now maintain clean test environment

**Files Updated:**

- `addons/gecs/tests/performance/performance_test_base.gd` - Uses scene_runner for proper test setup
- `addons/gecs/tests/performance/performance_test_entities.gd` - Refactored to use auto_free pattern
- `addons/gecs/tests/performance/performance_test_components.gd` - Simplified cleanup using world.purge
- `addons/gecs/tests/performance/performance_test_queries.gd` - Removed manual cleanup code
- `addons/gecs/tests/performance/performance_test_systems.gd` - Uses scene_runner for world management
- `addons/gecs/tests/performance/performance_test_integration.gd` - Consistent with core test patterns
- `addons/gecs/tests/performance/performance_test_system_process.gd` - Proper node lifecycle management

### 📦 Files Changed

- `addons/gecs/ecs/relationship.gd` - **BREAKING**: Removed weak parameter, added target_query support
- `addons/gecs/ecs/entity.gd` - **BREAKING**: Removed weak parameters from all methods, added limit parameter for removal
- `addons/gecs/ecs/component.gd` - **BREAKING**: Removed equals() method
- `addons/gecs/lib/component_query_matcher.gd` - **FIXED**: Properly handle falsy values (0, false, etc.)
- `addons/gecs/docs/RELATIONSHIPS.md` - Complete rewrite for new system
- `addons/gecs/docs/CLAUDE.md` - Updated with new relationship patterns
- `addons/gecs/tests/core/test_relationships.gd` - Updated all tests to new API

---

## [3.8.0] - 2024-XX-XX - Performance Boost & Documentation Overhaul

## 🎯 Major Improvements

### ⚡ Performance Optimizations

- **1.58x Query Performance Boost** - Implemented QueryBuilder pooling and world-level query caching
- **Fixed Component Replacement Bug** - Entities no longer processed twice when components are replaced
- **Array Operations Performance Revolution** - 4.6x faster intersection, 2.6x faster difference, 1.8x faster union operations
- **Memory Leak Prevention** - Better resource management and cleanup

### 📚 Complete Documentation Restructure

- **User-Friendly Learning Path** - Progressive guides from 5-minute tutorial to advanced optimization
- **Comprehensive Guides** - New Getting Started, Best Practices, Performance, and Troubleshooting guides
- **Addon-Centric Documentation** - All docs now ship with the addon for better distribution
- **Consistent Naming Conventions** - Standardized C*, s*, e*, o* prefixes throughout
- **Community Integration** - Discord links throughout for support

### 🧪 Enhanced Testing Framework

- **Performance Test Suite** - Comprehensive benchmarking for all ECS operations
- **Regression Detection** - Automated performance threshold monitoring
- **Better Test Organization** - Restructured tests into logical groups (core/, performance/)

## 🔧 Technical Changes

### Core Framework

- **QueryBuilder Pooling** - Reduced object creation overhead
- **World-Level Query Caching** - Hash-based caching with automatic invalidation
- **Component Replacement Fix** - Proper removal before replacement in entity.gd:97-111
- **Array Performance Revolution** - Algorithmic improvements from O(n²) to O(n) complexity using dictionary lookups

### Documentation Structure

- **Root README.md** - Clean overview pointing to addon documentation
- **addons/gecs/README.md** - Complete documentation index for distribution
- **addons/gecs/docs/** - All user guides properly organized
- **Progressive Learning Path** - 5min → 20min → 60min guide progression

### Testing & Quality

- **Performance Baselines** - Established benchmarks for regression detection
- **Comprehensive Coverage** - Entity, Component, Query, System, and Integration tests
- **Cross-Platform Compatibility** - Improved test reliability

## 📈 Performance Metrics

### Array Operations Benchmarks

- **Intersection Operations**: 4.6x faster (0.888ms → 0.194ms)
- **Difference Operations**: 2.6x faster (0.361ms → 0.141ms)
- **Union Operations**: 1.8x faster (0.372ms → 0.209ms)
- **No Overlap Scenarios**: 4.2x faster (0.629ms → 0.149ms)

### Algorithmic Improvements

- **O(n²) → O(n) Complexity**: Replaced Array.has() with Dictionary lookups
- **Smart Size Optimization**: Intersect operations use smaller array for lookup table
- **Uniqueness Tracking**: Union operations prevent duplicates with dictionary-based deduplication
- **Consistent Optimization Pattern**: All array operations use same high-performance approach

### Framework Performance

- **Query Caching**: 1.58x speedup for repeated queries
- **Component Operations**: Reduced double-processing bugs
- **Memory Usage**: Better cleanup and resource management
- **Test Suite**: Comprehensive benchmarking with automatic thresholds

## 🎮 For Game Developers

- **Dramatically Faster Games** - Up to 4.6x performance improvement in entity filtering and complex queries
- **Better Documentation** - Clear learning path from beginner to advanced
- **Consistent Patterns** - Standardized naming and organization conventions
- **Community Support** - Discord integration for help and discussions

## 🔄 Migration Notes

This is a **backward-compatible** update. No breaking changes to the API.

- Existing projects will automatically benefit from performance improvements
- Documentation has been reorganized but all links remain functional
- Test structure improved but does not affect game development

## 🌟 Community

- **Discord**: [Join our community](https://discord.gg/eB43XU2tmn)
- **Documentation**: [Complete guides](addons/gecs/README.md)
- **Issues**: [Report bugs or request features](https://github.com/csprance/gecs/issues)

---

**Full Changelog**: [v3.7.0...v3.8.0](https://github.com/csprance/gecs/compare/v3.7.0...v3.8.0)

The v3.8.0 version reflects a significant minor release with substantial improvements to performance, documentation, and testing while maintaining full backward compatibility with the existing v3.x API.
