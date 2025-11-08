#ifndef NATIVE_QUERY_CACHE_KEY_H
#define NATIVE_QUERY_CACHE_KEY_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <vector>

using namespace godot;

class NativeQueryCacheKey : public RefCounted {
    GDCLASS(NativeQueryCacheKey, RefCounted)

protected:
    static void _bind_methods();

public:
    NativeQueryCacheKey();
    ~NativeQueryCacheKey();

    // Main API: Build cache key from component arrays
    // Returns int64 hash that matches GDScript QueryCacheKey.build()
    static int64_t build(
        const TypedArray<Variant>& all_components,
        const TypedArray<Variant>& any_components,
        const TypedArray<Variant>& exclude_components
    );

private:
    // Helper: Extract instance IDs from component array and sort
    static void _extract_and_sort_ids(
        const TypedArray<Variant>& components,
        std::vector<int64_t>& out_ids
    );

    // Helper: Build hash from sorted ID arrays using domain-separated layout
    static int64_t _build_hash_from_sorted_ids(
        const std::vector<int64_t>& all_ids,
        const std::vector<int64_t>& any_ids,
        const std::vector<int64_t>& exclude_ids
    );
};

#endif // NATIVE_QUERY_CACHE_KEY_H
