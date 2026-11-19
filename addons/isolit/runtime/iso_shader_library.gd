extends RefCounted
class_name IsoShaderLibrary

enum BlendMode { ADD, SUBTRACT, MIX, OVERLAY }

const ENTRY_PATH := "res://addons/isolit/shaders/iso_receiver_fast.gdshader"

const COMMON_INCLUDE_PATH := "res://addons/isolit/shaders/iso_receiver_common.gdshaderinc"
# Preloaded so exports ship the includes (.gdshaderinc files are not exported as dependencies).
const COMMON_INCLUDE: ShaderInclude = preload("res://addons/isolit/shaders/iso_receiver_common.gdshaderinc")
const INCLUDE_UNITS: Array[ShaderInclude] = [
	preload("res://addons/isolit/shaders/iso_header.gdshaderinc"),
	preload("res://addons/isolit/shaders/iso_shade.gdshaderinc"),
	preload("res://addons/isolit/shaders/iso_fragment.gdshaderinc"),
]


static func is_receiver(shader: Shader) -> bool:
	return shader != null and shader.resource_path == ENTRY_PATH
