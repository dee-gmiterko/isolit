extends RefCounted

var _materials: Dictionary = {}   # config key -> ShaderMaterial
var _used: Dictionary = {}        # config keys touched by the current walk
var _dirty: bool = true
var _seen_version: int = -1
var _shader: Shader


func mark_receivers_dirty() -> void:
	_dirty = true


func apply(root: Node) -> void:
	if root == null:
		return
	if not _dirty and _seen_version == IsoNode.version:
		return
	_dirty = false
	_seen_version = IsoNode.version
	if _shader == null:
		_shader = load(IsoShaderLibrary.ENTRY_PATH)
	_used.clear()
	_walk(root, Vector3.ZERO, false)
	for key in _materials.keys():
		if not _used.has(key):
			_materials.erase(key)


func _walk(node: Node, origin: Vector3, under_iso: bool) -> void:
	var iso := node as IsoNode
	if iso != null:
		origin += iso.world_position
		var mat := _acquire(iso, origin)
		if iso.material != mat:
			iso.material = mat
		if iso.use_parent_material:
			iso.use_parent_material = false
		under_iso = true
	elif under_iso:
		var ci := node as CanvasItem
		if ci != null:
			var own := ci.material as ShaderMaterial
			if ci.material == null or (own != null and IsoShaderLibrary.is_receiver(own.shader)):
				if ci.material != null:
					ci.material = null
				if not ci.use_parent_material:
					ci.use_parent_material = true
	for child in node.get_children():
		_walk(child, origin, under_iso)

func _acquire(iso: IsoNode, origin: Vector3) -> ShaderMaterial:
	var canvas := iso.global_position
	var key := iso.config_key(origin, canvas)
	_used[key] = true
	var mat: ShaderMaterial = _materials.get(key)
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = _shader
		iso.apply_config(mat, origin, canvas)
		_materials[key] = mat
	return mat
