#include "native_query_cache_key.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/object.hpp>
#include <algorithm>

using namespace godot;

NativeQueryCacheKey::NativeQueryCacheKey() {
}

NativeQueryCacheKey::~NativeQueryCacheKey() {
}

void NativeQueryCacheKey::_bind_methods() {
    // Bind as static method so it can be called as NativeQueryCacheKey.build()
    ClassDB::bind_static_method("NativeQueryCacheKey",
        D_METHOD("build", "all_components", "any_components", "exclude_components"),
        &NativeQueryCacheKey::build);
}

int64_t NativeQueryCacheKey::build(
    const TypedArray<Variant>& all_components,
    const TypedArray<Variant>& any_components,
    const TypedArray<Variant>& exclude_components
) {
    // Extract instance IDs from each domain and sort
    // Sorting makes the hash order-insensitive within each domain
    std::vector<int64_t> all_ids, any_ids, exclude_ids;

    _extract_and_sort_ids(all_components, all_ids);
    _extract_and_sort_ids(any_components, any_ids);
    _extract_and_sort_ids(exclude_components, exclude_ids);

    // Build hash from sorted IDs with domain separation
    return _build_hash_from_sorted_ids(all_ids, any_ids, exclude_ids);
}

void NativeQueryCacheKey::_extract_and_sort_ids(
    const TypedArray<Variant>& components,
    std::vector<int64_t>& out_ids
) {
    out_ids.clear();
    out_ids.reserve(components.size());

    for (int i = 0; i < components.size(); i++) {
        Variant component = components[i];

        // Get instance ID from component (which is a Script or Component object)
        if (component.get_type() == Variant::OBJECT) {
            Object* obj = component;
            if (obj != nullptr) {
                out_ids.push_back(obj->get_instance_id());
            }
        }
    }

    // Sort for order-insensitive matching
    // [A, B, C] and [C, A, B] will produce same hash
    std::sort(out_ids.begin(), out_ids.end());
}

int64_t NativeQueryCacheKey::_build_hash_from_sorted_ids(
    const std::vector<int64_t>& all_ids,
    const std::vector<int64_t>& any_ids,
    const std::vector<int64_t>& exclude_ids
) {
    // Build layout array: [marker, count, ids...] for each domain
    // This prevents collisions between:
    //   with_all([A, B]) vs with_any([A, B])
    // Because they'll have different markers (1 vs 2)

    std::vector<int64_t> layout;

    // Reserve exact size to avoid reallocations (performance!)
    size_t total_size =
        2 + all_ids.size() +     // ALL: marker + count + ids
        2 + any_ids.size() +     // ANY: marker + count + ids
        2 + exclude_ids.size();  // NONE: marker + count + ids
    layout.reserve(total_size);

    // Domain 1: ALL components
    layout.push_back(1);  // Marker for ALL domain
    layout.push_back(static_cast<int64_t>(all_ids.size()));  // Count
    layout.insert(layout.end(), all_ids.begin(), all_ids.end());

    // Domain 2: ANY components
    layout.push_back(2);  // Marker for ANY domain
    layout.push_back(static_cast<int64_t>(any_ids.size()));  // Count
    layout.insert(layout.end(), any_ids.begin(), any_ids.end());

    // Domain 3: NONE (exclude) components
    layout.push_back(3);  // Marker for NONE domain
    layout.push_back(static_cast<int64_t>(exclude_ids.size()));  // Count
    layout.insert(layout.end(), exclude_ids.begin(), exclude_ids.end());

    // Hash the layout using FNV-1a (fast, good distribution, same as GDScript)
    const uint64_t FNV_PRIME = 1099511628211ULL;
    const uint64_t FNV_OFFSET = 14695981039346656037ULL;

    uint64_t hash = FNV_OFFSET;
    for (int64_t value : layout) {
        // Hash each byte of the int64
        const uint8_t* bytes = reinterpret_cast<const uint8_t*>(&value);
        for (size_t i = 0; i < sizeof(int64_t); i++) {
            hash ^= bytes[i];
            hash *= FNV_PRIME;
        }
    }

    return static_cast<int64_t>(hash);
}
