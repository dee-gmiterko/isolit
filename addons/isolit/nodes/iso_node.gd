@tool
@icon("res://addons/isolit/icons/iso_node.svg")
extends Node2D
class_name IsoNode

enum SurfaceType { NONE, FLOOR, WALL_X, WALL_Y, FLAT }

const GROUP := "iso_nodes"

static var version: int = 0

## Local to the nearest IsoNode ancestor.
@export var world_position: Vector3 = Vector3.ZERO:
	set(value):
		world_position = value
		_sync_screen_position()
		version += 1

@export var surface_type: SurfaceType = SurfaceType.NONE:
	set(value):
		surface_type = value
		version += 1

@export_flags_2d_render var receiver_mask: int = 1:
	set(value):
		receiver_mask = value
		version += 1

var _syncing := false


func _init() -> void:
	set_notify_transform(true)


func _enter_tree() -> void:
	add_to_group(GROUP)
	_sync_screen_position()
	version += 1


func _exit_tree() -> void:
	remove_from_group(GROUP)
	version += 1


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED:
		return
	version += 1
	if _syncing:
		_syncing = false
		return
	var solved := IsoProjection.screen_to_world(position, world_position.z)
	if solved != world_position:
		world_position = solved


func _sync_screen_position() -> void:
	var screen := IsoProjection.world_to_screen(world_position)
	if screen == position:
		return
	_syncing = true
	position = screen


func _validate_property(property: Dictionary) -> void:
	if property.name == "material":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func config_key(origin: Vector3, canvas: Vector2) -> String:
	return "%d|%s|%s|%d" % [surface_type, origin, canvas, receiver_mask]


func apply_config(mat: ShaderMaterial, origin: Vector3, canvas: Vector2) -> void:
	mat.set_shader_parameter("surface_type", surface_type)
	mat.set_shader_parameter("origin_world", origin)
	mat.set_shader_parameter("origin_canvas", canvas)
	mat.set_shader_parameter("receiver_mask", receiver_mask)
