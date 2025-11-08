# GECS Native Extension (C++)

This directory contains C++ implementations of GECS hot paths for 10-50x performance improvements.

## Quick Start

### 1. Install Prerequisites

**Linux/Mac:**
```bash
sudo apt install build-essential scons git  # Debian/Ubuntu
brew install scons  # macOS
```

**Windows:**
- Install Visual Studio 2022 (Community Edition)
- Install Python 3 and SCons: `pip install scons`

### 2. Clone godot-cpp

```bash
cd addons/gecs/native
git clone https://github.com/godotengine/godot-cpp
cd godot-cpp
git checkout 4.3  # Match your Godot version
git submodule update --init
```

### 3. Build godot-cpp

```bash
cd addons/gecs/native/godot-cpp

# Linux/Mac
scons platform=linux target=template_debug

# Windows
scons platform=windows target=template_debug
```

**This takes 5-15 minutes.** ☕

### 4. Build GECS Native

```bash
cd addons/gecs/native

# Linux/Mac
scons platform=linux target=template_debug

# Windows
scons platform=windows target=template_debug
```

**Output:** `bin/libgecs_native.linux.template_debug.x86_64.so` (or `.dll` on Windows)

### 5. Test in Godot

Open your Godot project and run:

```gdscript
func _ready():
    if ClassDB.class_exists("NativeQueryCacheKey"):
        print("✅ Native extension loaded!")

        # Test it works
        var key = NativeQueryCacheKey.build([C_TestA], [], [])
        print("Cache key: ", key)
    else:
        print("❌ Extension not loaded - check build")
```

## What's Implemented

### ✅ NativeQueryCacheKey

**Status:** Ready to use
**Speedup:** 10-20x faster than GDScript
**Usage:**
```gdscript
# Automatically used if native extension is available
var cache_key = QueryCacheKey.build(all_comps, any_comps, exclude_comps)
```

### 🚧 NativeArchetype (Coming Soon)

**Status:** Planned
**Expected speedup:** 20-30x faster archetype matching

### 🚧 NativeQueryEngine (Coming Soon)

**Status:** Planned
**Expected speedup:** 30-50x faster query execution

## Troubleshooting

**Extension doesn't load:**
1. Check `gecs_native.gdextension` file paths match your platform
2. Verify compiled library exists in `bin/` directory
3. Make sure you built godot-cpp first

**Build errors:**
- `godot-cpp not found`: Run step 2 (clone godot-cpp)
- `scons not found`: Install SCons
- Compiler errors: Make sure you built godot-cpp first (step 3)

**Crashes:**
- Build in debug mode first: `scons target=template_debug`
- Check Godot version matches godot-cpp checkout

## Performance Benchmarks

Run benchmarks to verify speedup:

```bash
addons/gdUnit4/runtest.sh -a "res://addons/gecs/tests/performance/test_native_vs_gdscript.gd"
```

Expected results:
- Query cache key generation: **12-18x faster**
- Overall query performance: **3-5x faster** (with just NativeQueryCacheKey)

## Building for Release

For production builds:

```bash
# Release builds are optimized (faster, but harder to debug)
scons platform=linux target=template_release

# Build for all platforms (for distribution)
scons platform=linux target=template_release
scons platform=windows target=template_release
scons platform=macos target=template_release
```

## Further Reading

- Full implementation guide: `/GDEXTENSION_IMPLEMENTATION_GUIDE.md`
- Performance review: `/PERFORMANCE_REVIEW.md`
- GDExtension docs: https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/
