@tool
@icon("res://addons/isolit/icons/collision_iso_polygon.svg")
extends CollisionPolygon2D
class_name CollisionIsoPolygon

## Base for collision shapes defined on the ground plane in world tiles, centred on the node.
## Shapes call _rebuild() from their property setters only.


func _enter_tree() -> void:
	_rebuild()


func _rebuild() -> void:
	pass


## Takes points as (world x, world y) in tiles and stores them projected to screen space.
func _set_world_points(points: PackedVector2Array) -> void:
	var screen := PackedVector2Array()
	for point in points:
		screen.append(IsoProjection.world_to_screen(Vector3(point.x, point.y, 0.0)))
	polygon = screen
