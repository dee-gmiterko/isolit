@tool
@icon("res://addons/isolit/icons/collision_iso_circle.svg")
extends CollisionIsoPolygon
class_name CollisionIsoCircle

## Circle on the ground plane, radius in world tiles.

@export var radius: float = 1.0:
	set(value):
		radius = value
		_rebuild()

@export_range(3, 128, 1) var segments: int = 32:
	set(value):
		segments = maxi(value, 3)
		_rebuild()


func _rebuild() -> void:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	_set_world_points(points)
