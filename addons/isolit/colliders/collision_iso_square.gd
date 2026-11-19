@tool
@icon("res://addons/isolit/icons/collision_iso_square.svg")
extends CollisionIsoPolygon
class_name CollisionIsoSquare

## Square on the ground plane, side length in world tiles.

@export var size: float = 1.0:
	set(value):
		size = value
		_rebuild()


func _rebuild() -> void:
	var half := size * 0.5
	_set_world_points(PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	]))
