@tool
@icon("res://addons/isolit/icons/collision_iso_rectangle.svg")
extends CollisionIsoPolygon
class_name CollisionIsoRectangle

## Rectangle on the ground plane, width along world x and height along world y, in world tiles.

@export var width: float = 1.0:
	set(value):
		width = value
		_rebuild()

@export var height: float = 1.0:
	set(value):
		height = value
		_rebuild()


func _rebuild() -> void:
	var half := Vector2(width, height) * 0.5
	_set_world_points(PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]))
