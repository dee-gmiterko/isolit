extends RefCounted

## Per-frame state shared by the registry modules.

var canvas_xform: Transform2D
var vp_size: Vector2

# Every enabled light, directionals first.
var visible: Array = []
var positional: Array = []
var dir_count := 0

# Tile (x, y) of a world point is floor(world.xy) - tile_origin; zero tile_grid = no grid.
var tile_origin := Vector2i.ZERO
var tile_grid := Vector2i.ZERO


## False when the frame should be skipped.
func begin(tree: SceneTree, viewport: Viewport) -> bool:
	if tree == null or viewport == null:
		return false
	vp_size = viewport.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return false

	canvas_xform = viewport.get_global_canvas_transform() * viewport.get_canvas_transform()
	return true
