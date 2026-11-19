@tool
extends EditorPlugin

const AUTOLOAD_NAME := "IsoManager"
const AUTOLOAD_PATH := "res://addons/isolit/runtime/iso_manager.gd"

const IsoLightRegistryScript := preload("res://addons/isolit/runtime/iso_light_registry.gd")

const EDITOR_REFRESH_INTERVAL := 1.0 / 30.0

var _registry: IsoLightRegistry
var _refresh_accum := 0.0


func _enter_tree() -> void:
	_add_live_globals()
	_persist_globals()
	_persist_project_settings()
	_ensure_autoload()
	_registry = IsoLightRegistryScript.new()
	set_process(true)

func _exit_tree() -> void:
	set_process(false)
	_registry = null

func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	_unpersist_globals()
	_unpersist_project_settings()

## Guarded: add_autoload_singleton rewrites project.godot on every call.
func _ensure_autoload() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

## Autoloads don't run in the editor, so the plugin drives the same refresh() as IsoManager.
func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum < EDITOR_REFRESH_INTERVAL:
		return
	_refresh_accum = 0.0
	IsoProjection.reload_settings()
	if _registry == null or EditorInterface.get_edited_scene_root() == null:
		return
	_registry.refresh(get_tree(), EditorInterface.get_editor_viewport_2d(),
		EditorInterface.get_edited_scene_root())

# Shader globals are registered twice: persisted under shader_globals/* so exports and
# editor startup have them before any receiver shader compiles, and live via
# RenderingServer because project.godot's shader_globals are only parsed at startup.

func _ps_global_defs() -> Array:
	return [
		{
			"name": "iso_light_data",
			"def": {"type": "sampler2D", "value": "", "filter": "nearest", "repeat": "disable"},
		},
		{"name": "iso_light_count", "def": {"type": "int", "value": 0}},
		{"name": "iso_tile_w", "def": {"type": "float", "value": IsoProjection.DEFAULT_TILE_W}},
		{"name": "iso_tile_h", "def": {"type": "float", "value": IsoProjection.DEFAULT_TILE_H}},
		{"name": "iso_tile_z", "def": {"type": "float", "value": IsoProjection.DEFAULT_TILE_Z}},
		{"name": "iso_ambient_color", "def": {"type": "color", "value": Color(1, 1, 1, 1)}},
		{"name": "iso_ambient_energy", "def": {"type": "float", "value": 1.0}},
		{"name": "iso_tile_origin", "def": {"type": "ivec2", "value": Vector2i.ZERO}},
		{"name": "iso_tile_grid", "def": {"type": "ivec2", "value": Vector2i.ZERO}},
		{"name": "iso_directional_count", "def": {"type": "int", "value": 0}},
		{
			"name": "iso_tile_headers",
			"def": {"type": "sampler2D", "value": "", "filter": "nearest", "repeat": "disable"},
		},
		{
			"name": "iso_tile_indices",
			"def": {"type": "sampler2D", "value": "", "filter": "nearest", "repeat": "disable"},
		},
		{
			"name": "iso_shadow_atlas",
			"def": {"type": "sampler2D", "value": "", "filter": "linear", "repeat": "disable"},
		},
	]

func _rs_global_defs() -> Array:
	return [
		{
			"name": "iso_light_data",
			"type": RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,
			"value": _placeholder_texture(),
		},
		{"name": "iso_light_count", "type": RenderingServer.GLOBAL_VAR_TYPE_INT, "value": 0},
		{"name": "iso_tile_w", "type": RenderingServer.GLOBAL_VAR_TYPE_FLOAT, "value": IsoProjection.DEFAULT_TILE_W},
		{"name": "iso_tile_h", "type": RenderingServer.GLOBAL_VAR_TYPE_FLOAT, "value": IsoProjection.DEFAULT_TILE_H},
		{"name": "iso_tile_z", "type": RenderingServer.GLOBAL_VAR_TYPE_FLOAT, "value": IsoProjection.DEFAULT_TILE_Z},
		{"name": "iso_ambient_color", "type": RenderingServer.GLOBAL_VAR_TYPE_COLOR, "value": Color(1, 1, 1, 1)},
		{"name": "iso_ambient_energy", "type": RenderingServer.GLOBAL_VAR_TYPE_FLOAT, "value": 1.0},
		{"name": "iso_tile_origin", "type": RenderingServer.GLOBAL_VAR_TYPE_IVEC2, "value": Vector2i.ZERO},
		{"name": "iso_tile_grid", "type": RenderingServer.GLOBAL_VAR_TYPE_IVEC2, "value": Vector2i.ZERO},
		{"name": "iso_directional_count", "type": RenderingServer.GLOBAL_VAR_TYPE_INT, "value": 0},
		{"name": "iso_tile_headers", "type": RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, "value": _placeholder_texture()},
		{"name": "iso_tile_indices", "type": RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, "value": _placeholder_texture()},
		{"name": "iso_shadow_atlas", "type": RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, "value": _placeholder_texture()},
	]

func _persist_globals() -> void:
	var ps_changed := false
	for d in _ps_global_defs():
		var key: String = "shader_globals/" + str(d.name)
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, d.def)
			ps_changed = true
	if ps_changed:
		ProjectSettings.save()

func _unpersist_globals() -> void:
	var ps_changed := false
	for d in _ps_global_defs():
		var key: String = "shader_globals/" + str(d.name)
		if ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, null)
			ps_changed = true
	if ps_changed:
		ProjectSettings.save()

func _project_setting_defs() -> Array:
	return [
		{
			"name": "isolit/projection/tile_width",
			"default": IsoProjection.DEFAULT_TILE_W,
			"info": {
				"name": "isolit/projection/tile_width",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,4096,1,or_greater",
			},
		},
		{
			"name": "isolit/projection/tile_height",
			"default": IsoProjection.DEFAULT_TILE_H,
			"info": {
				"name": "isolit/projection/tile_height",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,4096,1,or_greater",
			},
		},
		{
			"name": "isolit/projection/tile_z",
			"default": IsoProjection.DEFAULT_TILE_Z,
			"info": {
				"name": "isolit/projection/tile_z",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1,4096,1,or_greater",
			},
		},
	]

func _persist_project_settings() -> void:
	var changed := false
	var defs := _project_setting_defs()
	for d in defs:
		if not ProjectSettings.has_setting(d.name):
			ProjectSettings.set_setting(d.name, d.default)
			changed = true
		ProjectSettings.set_initial_value(d.name, d.default)
		ProjectSettings.add_property_info(d.info)
	# Without explicit order, a non-default setting jumps to file order in the dialog.
	var order := ProjectSettings.get_order(defs[0].name)
	for d in defs:
		ProjectSettings.set_order(d.name, order)
		order += 1
	if changed:
		ProjectSettings.save()

func _unpersist_project_settings() -> void:
	var changed := false
	for d in _project_setting_defs():
		if ProjectSettings.has_setting(d.name):
			ProjectSettings.set_setting(d.name, null)
			changed = true
	if changed:
		ProjectSettings.save()

func _add_live_globals() -> void:
	var existing := RenderingServer.global_shader_parameter_get_list()
	for g in _rs_global_defs():
		if not existing.has(g.name):
			RenderingServer.global_shader_parameter_add(g.name, g.type, g.value)

func _placeholder_texture() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBAF)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
