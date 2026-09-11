@tool
class_name GECSExplorerCodec
extends RefCounted
## Lossless, object-free Variant transport. Display truncation is never editable data.

const MAX_BYTES := 262144
const MAX_ITEMS := 4096

static func supported(value: Variant, depth := 0) -> bool:
	if depth > 8 or typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return false
	if value is Array or value is Dictionary:
		if value.size() > MAX_ITEMS:
			return false
		if value is Array and value.is_typed() and value.get_typed_builtin() == TYPE_OBJECT:
			return false
		if value is Dictionary and value.is_typed() and (value.get_typed_key_builtin() == TYPE_OBJECT or value.get_typed_value_builtin() == TYPE_OBJECT):
			return false
		for key in value:
			if not supported(key, depth + 1):
				return false
			if value is Dictionary and not supported(value[key], depth + 1):
				return false
	return true

static func encode(value: Variant) -> Dictionary:
	var result := {"type": typeof(value), "editable": false, "display": str(value).left(512)}
	if value is Object and is_instance_valid(value):
		result["object_id"] = value.get_instance_id()
		result["path"] = value.resource_path if value is Resource else (str(value.get_path()) if value is Node and value.is_inside_tree() else "")
	if supported(value):
		var bytes := var_to_bytes(value)
		if bytes.size() <= MAX_BYTES:
			result["value"] = Marshalls.raw_to_base64(bytes)
			result["editable"] = true
	return result

static func decode(encoded: Dictionary) -> Variant:
	if not encoded.get("editable", false) or str(encoded.get("value", "")).length() > MAX_BYTES * 2:
		return null
	return bytes_to_var(Marshalls.base64_to_raw(encoded.get("value", "")))

static func equal(a: Dictionary, b: Dictionary) -> bool:
	return a.get("type") == b.get("type") and a.get("value") == b.get("value") and a.get("object_id") == b.get("object_id")

static func valid(encoded: Dictionary) -> bool:
	if encoded.get("editable") != true or not encoded.get("value") is String: return false
	var value: Variant = decode(encoded)
	return typeof(value) == encoded.get("type", -1) and supported(value) and encode(value).get("value") == encoded.value
