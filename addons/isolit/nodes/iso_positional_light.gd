@tool
extends IsoLight
class_name IsoPositionalLight

signal tile_changed(light: IsoPositionalLight)

## Local to the nearest IsoNode ancestor.
@export var world_position: Vector3 = Vector3.ZERO:
	set(value):
		world_position = value
		_sync_screen_position()

@export_group("Falloff")
@export var range: float = 4.0
@export var falloff: float = 1.0


var _syncing := false
var _last_tile := Vector2i.ZERO


func _init() -> void:
	set_notify_transform(true)


func _enter_tree() -> void:
	_sync_screen_position()
	super()
	_last_tile = world_tile()


func _exit_tree() -> void:
	super()
	IsoShadowAtlas.release(self)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var tile := world_tile()
	if tile != _last_tile:
		_last_tile = tile
		tile_changed.emit(self)


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED:
		return
	if _syncing:
		_syncing = false
		return
	set_position_from_screen(position)


func _sync_screen_position() -> void:
	var screen := IsoProjection.world_to_screen(world_position)
	if screen == position:
		return
	_syncing = true
	position = screen


func set_position_from_screen(screen_pos: Vector2) -> void:
	world_position = IsoProjection.screen_to_world(screen_pos, world_position.z)


func global_world_position() -> Vector3:
	var total := world_position
	var p := get_parent()
	while p != null:
		if p is IsoNode:
			total += p.world_position
		p = p.get_parent()
	return total


func world_tile() -> Vector2i:
	var w := global_world_position()
	return Vector2i(floori(w.x), floori(w.y))


## dx, dy are tile offsets from this light's tile.
func update_obstructed(dx: int, dy: int, obstructed: bool) -> void:
	IsoShadowAtlas.update(self, dx, dy, obstructed)
