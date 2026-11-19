extends RefCounted

## Cached list of the iso_lights group, rebuilt only on tree changes.

var _light_cache: Array[IsoLight] = []
var _cache_dirty: bool = true
var _cache_tree: SceneTree = null
var _on_changed := Callable()


func set_fan_out(cb: Callable) -> void:
	_on_changed = cb


func collect_enabled(tree: SceneTree) -> Array[IsoLight]:
	var lights := _get_cached_lights(tree)
	var visible: Array[IsoLight] = []
	for light in lights:
		if not is_instance_valid(light):
			_cache_dirty = true
			continue
		if light.enabled and light.is_visible_in_tree():
			visible.append(light)
	return visible


func _get_cached_lights(tree: SceneTree) -> Array[IsoLight]:
	if tree != _cache_tree:
		_bind_cache_tree(tree)
		_cache_dirty = true
	if _cache_dirty:
		_rebuild_light_cache(tree)
	return _light_cache

func _bind_cache_tree(tree: SceneTree) -> void:
	if _cache_tree != null and is_instance_valid(_cache_tree):
		if _cache_tree.node_added.is_connected(_on_tree_changed):
			_cache_tree.node_added.disconnect(_on_tree_changed)
		if _cache_tree.node_removed.is_connected(_on_tree_changed):
			_cache_tree.node_removed.disconnect(_on_tree_changed)
	_cache_tree = tree
	if tree != null:
		if not tree.node_added.is_connected(_on_tree_changed):
			tree.node_added.connect(_on_tree_changed)
		if not tree.node_removed.is_connected(_on_tree_changed):
			tree.node_removed.connect(_on_tree_changed)

func _on_tree_changed(node: Node) -> void:
	_cache_dirty = true
	_on_changed.call(node)


func _rebuild_light_cache(tree: SceneTree) -> void:
	_light_cache.clear()
	for node in tree.get_nodes_in_group("iso_lights"):
		var light := node as IsoLight
		if light != null:
			_light_cache.append(light)
	_cache_dirty = false
