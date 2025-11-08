#ifndef GECS_REGISTER_TYPES_H
#define GECS_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_gecs_native_module(ModuleInitializationLevel p_level);
void uninitialize_gecs_native_module(ModuleInitializationLevel p_level);

#endif // GECS_REGISTER_TYPES_H
