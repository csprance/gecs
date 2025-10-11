# GECS Changelog

## [5.1.0] - 2025-01-XX - Relationship System Enhancements

### ⚠️ BREAKING CHANGES

#### Relationship Matching Default Changed to Weak Matching
- **`Relationship.matches()` now defaults to weak matching** (`weak = true` instead of `weak = false`)
- **Impact**: Relationship matching now prioritizes component type over exact data matching by default
- **Migration**: Review relationship removal code that relies on exact data matching

**Before (v5.0 and earlier):**
```gdscript
# Strong matching by default - only matched exact component data
relationship.matches(other_relationship)  # weak = false (default)
```

**After (v5.1+):**
```gdscript
# Weak matching by default - matches by component type
relationship.matches(other_relationship)  # weak = true (default)

# For exact data matching, explicitly use strong matching:
relationship.matches(other_relationship, false)
```

### ✨ New Features

#### Component Query Support in Relationships
- **Added dictionary-based component queries in relationships** - Filter relationships by component properties
- **Automatic weak/strong matching detection** - Component queries automatically use weak matching
- **New `ComponentQueryMatcher`** - Advanced property-based matching for relationships

#### Limited Relationship Removal
- **Added `limit` parameter to `Entity.remove_relationship()`** - Control exactly how many matching relationships to remove
- **Added `limit` parameter to `Entity.remove_relationships()`** - Apply limits to batch relationship removal operations
- **Backward compatible** - Default behavior unchanged (`limit = -1` removes all matching relationships)

### 🚨 Migration Guide

#### 1. Review Relationship Matching Code
**Check any manual calls to `relationship.matches()`:**

```gdscript
# ❌ This behavior changed (now uses weak matching by default)
if rel.matches(search_relationship):
    # This now matches by component type, not exact data

# ✅ Explicit strong matching (preserves old behavior)
if rel.matches(search_relationship, false):
    # This matches exact component data like before
```

#### 2. Entity Relationship Removal (Usually No Change Needed)
The auto-detection in `Entity.remove_relationship()` maintains expected behavior:

```gdscript
# These work the same as before:
entity.remove_relationship(Relationship.new(C_Damage.new(50), target))  # Strong matching
entity.remove_relationship(Relationship.new({C_Damage: {"value": {"_gt": 20}}}, null))  # Weak matching (auto-detected)
```

#### 3. Test Relationship-Heavy Code
**Areas to test carefully:**
- Custom relationship matching logic
- Systems that rely on exact component data matching
- Relationship queries with specific data requirements

### 🎯 New Use Cases Enabled

#### Advanced Component Queries in Relationships
```gdscript
# Remove damage effects above 50 points
entity.remove_relationship(
    Relationship.new({C_Damage: {"amount": {"_gt": 50}}}, null)
)

# Remove buffs with less than 5 seconds remaining
entity.remove_relationship(
    Relationship.new({C_Buff: {"duration": {"_lt": 5.0}}}, null)
)
```

#### Limited Relationship Removal
```gdscript
# Remove 2 poison stacks instead of all
entity.remove_relationship(Relationship.new(C_Poison.new(), null), 2)

# Healing potion removes 3 damage effects
entity.remove_relationship(Relationship.new(C_Damage.new(), null), 3)

# Consume 5 health potions
entity.remove_relationship(Relationship.new(C_HasItem.new(), C_HealthPotion), 5)
```

### 📦 Files Changed
- `addons/gecs/ecs/relationship.gd` - **BREAKING**: Default weak matching, component queries
- `addons/gecs/ecs/entity.gd` - Added limit parameter support with auto-detection
- `addons/gecs/lib/component_query_matcher.gd` - **NEW**: Advanced component query system  
- `addons/gecs/docs/RELATIONSHIPS.md` - Comprehensive updates for new features
- `addons/gecs/docs/BEST_PRACTICES.md` - Migration guidance and best practices
- `addons/gecs/tests/core/test_relationships.gd` - Test coverage for all new functionality
- `CLAUDE.md` - Quick reference updates

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
