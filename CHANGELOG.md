# GECS v3.8.0 - Performance Boost & Documentation Overhaul

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
