@tool
@icon("res://addons/isolit/icons/iso_canvas_modulate.svg")
extends Node2D
class_name IsoCanvasModulate

## Ambient / darkness source

const GROUP := "iso_canvas_modulate"

@export var color: Color = Color("#1a1a1a"):
	set(value):
		color = value
		_apply()

@export var ambient_energy: float = 1.0:
	set(value):
		ambient_energy = value
		_apply()


func _enter_tree() -> void:
	add_to_group(GROUP)
	_apply()
	_warn_if_conflicting()
	update_configuration_warnings()


func _exit_tree() -> void:
	remove_from_group(GROUP)


func _apply() -> void:
	RenderingServer.global_shader_parameter_set("iso_ambient_color", color)
	RenderingServer.global_shader_parameter_set("iso_ambient_energy", ambient_energy)


func _warn_if_conflicting() -> void:
	if Engine.is_editor_hint():
		return
	if _find_native_canvas_modulate():
		push_warning("IsoCanvasModulate: a native CanvasModulate is present and will double-darken IsoLit output. Remove it.")
	if get_tree().get_nodes_in_group(GROUP).size() > 1:
		push_warning("IsoCanvasModulate: multiple instances found; the last one in the tree wins.")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not is_inside_tree():
		return warnings
	if _find_native_canvas_modulate():
		warnings.append("A native CanvasModulate is present. It will multiply IsoLit's output and double-darken the scene. Remove it and let IsoCanvasModulate own ambient/darkness.")
	if get_tree().get_nodes_in_group(GROUP).size() > 1:
		warnings.append("Multiple IsoCanvasModulate nodes found. Only one is expected; the last one in the tree wins.")
	return warnings


func _find_native_canvas_modulate() -> bool:
	var root := get_tree().get_edited_scene_root() if Engine.is_editor_hint() else get_tree().get_root()
	if root == null:
		return false
	return root.find_children("*", "CanvasModulate", true, false).size() > 0
