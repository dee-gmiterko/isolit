extends RefCounted
class_name IsoLightRegistry

## Gather / pack / bin, called once per frame by iso_manager.gd at runtime and plugin.gd in the editor.

const ReceiverDriverScript := preload("res://addons/isolit/runtime/registry/receiver_driver.gd")
var _receiver_driver := ReceiverDriverScript.new()

const LightPackerScript := preload("res://addons/isolit/runtime/registry/light_packer.gd")
const WorldTilesScript := preload("res://addons/isolit/runtime/registry/world_tiles.gd")
var _light_packer := LightPackerScript.new()
var _world_tiles := WorldTilesScript.new()

const FrameContextScript := preload("res://addons/isolit/runtime/registry/frame_context.gd")
var _ctx := FrameContextScript.new()

const LightCacheScript := preload("res://addons/isolit/runtime/registry/light_cache.gd")
var _light_cache := LightCacheScript.new()


func _init() -> void:
	_light_cache.set_fan_out(_on_tree_changed)

## receiver_root bounds the IsoNode material walk; null skips it.
func refresh(tree: SceneTree, viewport: Viewport, receiver_root: Node = null) -> void:
	if not _ctx.begin(tree, viewport):
		return

	_ctx.visible = _light_cache.collect_enabled(tree)
	var count: int = _ctx.visible.size()

	_receiver_driver.apply(receiver_root)

	# Directionals first: the shader shades rows [0, dir_count) for every fragment and
	# finds the rest through the tile grid.
	var directionals: Array = []
	var positional: Array = []
	for l in _ctx.visible:
		if l is IsoDirectionalLight:
			directionals.append(l)
		else:
			positional.append(l)
	_ctx.visible = directionals + positional
	_ctx.positional = positional
	_ctx.dir_count = directionals.size()

	_world_tiles.compute_grid(_ctx)

	if count == 0:
		_light_packer.publish_empty()
		_world_tiles.publish_empty()
	else:
		_light_packer.pack_and_publish(_ctx)
		_world_tiles.build_and_publish(_ctx)

func _on_tree_changed(node: Node) -> void:
	_receiver_driver.mark_receivers_dirty()
