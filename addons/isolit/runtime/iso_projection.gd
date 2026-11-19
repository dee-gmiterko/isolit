extends RefCounted
class_name IsoProjection

## World (vec3, tiles, Z up) <-> screen (vec2, pixels):
##   screen.x = (world.x - world.y) * (TILE_W / 2)
##   screen.y = (world.x + world.y) * (TILE_H / 2) - world.z * TILE_Z

const SETTING_TILE_W := "isolit/projection/tile_width"
const SETTING_TILE_H := "isolit/projection/tile_height"
const SETTING_TILE_Z := "isolit/projection/tile_z"

const DEFAULT_TILE_W := 128.0
const DEFAULT_TILE_H := 64.0   # TILE_W / 2 yields a classic 2:1 isometric view
const DEFAULT_TILE_Z := 64.0

static var tile_w := DEFAULT_TILE_W
static var tile_h := DEFAULT_TILE_H
static var tile_z := DEFAULT_TILE_Z


## Read the isolit/projection/* project settings and publish them as shader globals.
static func reload_settings() -> void:
	tile_w = float(ProjectSettings.get_setting(SETTING_TILE_W, DEFAULT_TILE_W))
	tile_h = float(ProjectSettings.get_setting(SETTING_TILE_H, DEFAULT_TILE_H))
	tile_z = float(ProjectSettings.get_setting(SETTING_TILE_Z, DEFAULT_TILE_Z))
	RenderingServer.global_shader_parameter_set("iso_tile_w", tile_w)
	RenderingServer.global_shader_parameter_set("iso_tile_h", tile_h)
	RenderingServer.global_shader_parameter_set("iso_tile_z", tile_z)


static func world_to_screen(world: Vector3) -> Vector2:
	return Vector2(
		(world.x - world.y) * (tile_w * 0.5),
		(world.x + world.y) * (tile_h * 0.5) - world.z * tile_z)


## Inverse of world_to_screen on a fixed Z plane.
static func screen_to_world(screen: Vector2, z: float) -> Vector3:
	var sy := screen.y + z * tile_z
	# screen.x = (x - y) * a, sy = (x + y) * b  =>  x = screen.x/(2a) + sy/(2b), etc.
	var a := tile_w * 0.5
	var b := tile_h * 0.5
	var u := screen.x / a    # x - y
	var v := sy / b          # x + y
	return Vector3((u + v) * 0.5, (v - u) * 0.5, z)
