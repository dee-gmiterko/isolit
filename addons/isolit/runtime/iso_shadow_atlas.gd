extends RefCounted
class_name IsoShadowAtlas

## Layout constants must match ISO_SHADOW_* in iso_header.gdshaderinc.

const MAX_WORLD_SIZE := 64
const HALF := MAX_WORLD_SIZE / 2
const BORDER := 1
const SUB := 3   # texels per tile side; a tile update fills a SUB x SUB block
const SLOT := (2 * HALF + 1 + 2 * BORDER) * SUB
const SLOTS_PER_ROW := 8

const GLOBAL_NAME := "iso_shadow_atlas"

static var _image: Image
static var _texture: ImageTexture
static var _slots: Dictionary = {}   # light instance id -> slot index
static var _free: Array[int] = []
static var _slot_count := 0
static var _dirty := false
static var _flush_queued := false


## dx, dy are tile offsets from the light's tile.
static func update(light: IsoPositionalLight, dx: int, dy: int, obstructed: bool) -> void:
	if dx < -HALF or dy < -HALF or dx > HALF or dy > HALF:
		return
	var id := light.get_instance_id()
	if not _slots.has(id):
		_slots[id] = _alloc_slot()
	var px: Vector2i = _slot_px(_slots[id]) + Vector2i(dx + HALF + BORDER, dy + HALF + BORDER) * SUB
	_image.fill_rect(Rect2i(px, Vector2i(SUB, SUB)), Color(1.0 if obstructed else 0.0, 0.0, 0.0))
	_mark_dirty()


static func release(light: IsoPositionalLight) -> void:
	var id := light.get_instance_id()
	if not _slots.has(id):
		return
	var slot: int = _slots[id]
	_slots.erase(id)
	_image.fill_rect(Rect2i(_slot_px(slot), Vector2i(SLOT, SLOT)), Color.BLACK)
	_free.append(slot)
	_mark_dirty()


static func slot_of(light: IsoPositionalLight) -> int:
	return _slots.get(light.get_instance_id(), -1)


static func flush() -> void:
	_flush_queued = false
	if not _dirty:
		return
	_dirty = false
	if _texture == null or _texture.get_size() != Vector2(_image.get_size()):
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	RenderingServer.global_shader_parameter_set(GLOBAL_NAME, _texture)


static func _mark_dirty() -> void:
	_dirty = true
	if _flush_queued:
		return
	_flush_queued = true
	(func() -> void: flush()).call_deferred()


static func _alloc_slot() -> int:
	if not _free.is_empty():
		return _free.pop_back()
	var slot := _slot_count
	_slot_count += 1
	_ensure_capacity(slot)
	return slot


static func _slot_px(slot: int) -> Vector2i:
	return Vector2i((slot % SLOTS_PER_ROW) * SLOT, (slot / SLOTS_PER_ROW) * SLOT)


static func _ensure_capacity(slot: int) -> void:
	var width := SLOTS_PER_ROW * SLOT
	var height := (slot / SLOTS_PER_ROW + 1) * SLOT
	if _image == null:
		_image = Image.create(width, height, false, Image.FORMAT_R8)
		_image.fill(Color.BLACK)
		return
	if _image.get_height() >= height:
		return
	var grown := Image.create(width, height, false, Image.FORMAT_R8)
	grown.fill(Color.BLACK)
	grown.blit_rect(_image, Rect2i(Vector2i.ZERO, _image.get_size()), Vector2i.ZERO)
	_image = grown
