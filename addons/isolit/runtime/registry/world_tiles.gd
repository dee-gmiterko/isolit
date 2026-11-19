extends RefCounted

## Bins each positional light into the world tiles (1x1 world xy cells) its range disc
## touches and publishes a per-tile header (offset | count) plus a flat index list.

const FrameContext := preload("res://addons/isolit/runtime/registry/frame_context.gd")

# Must match ISO_INDEX_TEX_WIDTH in iso_header.gdshaderinc.
const INDEX_TEX_WIDTH := 2048

# Slack in world units for CPU/GPU float disagreement at a reach's exact boundary.
const BIN_PAD := 0.01

# 512 x 512 tiles. Past it the grid is withheld and the shader loops every light.
const MAX_TILES := 262144

var _tile_header_tex: ImageTexture
var _tile_index_tex: ImageTexture
var _warned_oversize := false

var _tile_counts: PackedInt32Array = PackedInt32Array()
var _pair_tiles: PackedInt32Array = PackedInt32Array()
var _pair_rows: PackedInt32Array = PackedInt32Array()
var _header_buf: PackedFloat32Array = PackedFloat32Array()
var _index_buf: PackedFloat32Array = PackedFloat32Array()
var _header_img: Image
var _index_img: Image


## Size the grid to every positional light's full xy reach; a zero grid means nothing is binned.
func compute_grid(ctx: FrameContext) -> void:
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for l in ctx.positional:
		var light := l as IsoPositionalLight
		var c := light.global_world_position()
		var r: float = light.range + BIN_PAD
		min_x = minf(min_x, c.x - r)
		min_y = minf(min_y, c.y - r)
		max_x = maxf(max_x, c.x + r)
		max_y = maxf(max_y, c.y + r)
	if min_x > max_x or min_y > max_y:
		ctx.tile_origin = Vector2i.ZERO
		ctx.tile_grid = Vector2i.ZERO
		return
	var ox := int(floor(min_x))
	var oy := int(floor(min_y))
	var grid := Vector2i(int(floor(max_x)) - ox + 1, int(floor(max_y)) - oy + 1)
	if grid.x * grid.y > MAX_TILES:
		if not _warned_oversize:
			_warned_oversize = true
			push_warning("IsoLit: light world extent %s tiles exceeds the %d-tile grid cap; lights are shaded unbinned this frame." % [grid, MAX_TILES])
		ctx.tile_origin = Vector2i.ZERO
		ctx.tile_grid = Vector2i.ZERO
		return
	_warned_oversize = false
	ctx.tile_origin = Vector2i(ox, oy)
	ctx.tile_grid = grid


func build_and_publish(ctx: FrameContext) -> void:
	var positional: Array = ctx.positional
	var dir_count: int = ctx.dir_count
	var grid: Vector2i = ctx.tile_grid
	if grid.x <= 0 or grid.y <= 0:
		publish_empty()
		return
	var origin: Vector2i = ctx.tile_origin
	var tiles_x := grid.x
	var tiles_y := grid.y
	var tile_count := tiles_x * tiles_y

	# Gather (tile, light-row) pairs, then counting-sort them into contiguous per-tile runs.
	if _tile_counts.size() != tile_count:
		_tile_counts.resize(tile_count)
	_tile_counts.fill(0)
	_pair_tiles.clear()
	_pair_rows.clear()

	for i in positional.size():
		var light := positional[i] as IsoPositionalLight
		var c := light.global_world_position()
		var cx: float = c.x - float(origin.x)
		var cy: float = c.y - float(origin.y)
		var reach: float = light.range + BIN_PAD
		var reach_sq := reach * reach

		# Per tile row, sqrt(r^2 - dy^2) with dy = the row band's closest approach gives
		# the exact tile span.
		var ty0 := clampi(int(floor(cy - reach)), 0, tiles_y - 1)
		var ty1 := clampi(int(floor(cy + reach)), 0, tiles_y - 1)

		for ty in range(ty0, ty1 + 1):
			var y0 := float(ty)
			var y1 := y0 + 1.0
			var dy := cy - clampf(cy, y0, y1)
			var rem := reach_sq - dy * dy
			if rem < 0.0:
				continue
			var half := sqrt(rem)
			var tx0 := clampi(int(floor(cx - half)), 0, tiles_x - 1)
			var tx1 := clampi(int(floor(cx + half)), 0, tiles_x - 1)
			var row_base := ty * tiles_x
			for tx in range(tx0, tx1 + 1):
				_pair_tiles.push_back(row_base + tx)
				_pair_rows.push_back(dir_count + i)
				_tile_counts[row_base + tx] += 1

	var total_indices := _pair_tiles.size()
	var idx_rows := int(ceil(float(maxi(total_indices, 1)) / float(INDEX_TEX_WIDTH)))

	var header_floats := tile_count * 4
	if _header_buf.size() != header_floats:
		_header_buf.resize(header_floats)
	_header_buf.fill(0.0)
	var index_floats := INDEX_TEX_WIDTH * idx_rows * 4
	if _index_buf.size() != index_floats:
		_index_buf.resize(index_floats)

	# Prefix-sum counts into start offsets; _tile_counts becomes the scatter cursor.
	var offset := 0
	for t in tile_count:
		var cnt := _tile_counts[t]
		_header_buf[t * 4] = float(offset)
		_header_buf[t * 4 + 1] = float(cnt)
		_tile_counts[t] = offset
		offset += cnt

	for p in total_indices:
		var slot := _tile_counts[_pair_tiles[p]]
		_tile_counts[_pair_tiles[p]] = slot + 1
		_index_buf[slot * 4] = float(_pair_rows[p])

	_upload_tile_textures(tiles_x, tiles_y, idx_rows)

	RenderingServer.global_shader_parameter_set("iso_tile_origin", origin)
	RenderingServer.global_shader_parameter_set("iso_tile_grid", grid)
	RenderingServer.global_shader_parameter_set("iso_tile_headers", _tile_header_tex)
	RenderingServer.global_shader_parameter_set("iso_tile_indices", _tile_index_tex)

func _upload_tile_textures(tiles_x: int, tiles_y: int, idx_rows: int) -> void:
	var header_bytes := _header_buf.to_byte_array()
	if _header_img == null or _header_img.get_width() != tiles_x or _header_img.get_height() != tiles_y:
		_header_img = Image.create_from_data(tiles_x, tiles_y, false, Image.FORMAT_RGBAF, header_bytes)
	else:
		_header_img.set_data(tiles_x, tiles_y, false, Image.FORMAT_RGBAF, header_bytes)
	if _tile_header_tex == null or _tile_header_tex.get_size() != Vector2(_header_img.get_size()):
		_tile_header_tex = ImageTexture.create_from_image(_header_img)
	else:
		_tile_header_tex.update(_header_img)

	var index_bytes := _index_buf.to_byte_array()
	if _index_img == null or _index_img.get_height() != idx_rows:
		_index_img = Image.create_from_data(INDEX_TEX_WIDTH, idx_rows, false, Image.FORMAT_RGBAF, index_bytes)
	else:
		_index_img.set_data(INDEX_TEX_WIDTH, idx_rows, false, Image.FORMAT_RGBAF, index_bytes)
	if _tile_index_tex == null or _tile_index_tex.get_size() != Vector2(_index_img.get_size()):
		_tile_index_tex = ImageTexture.create_from_image(_index_img)
	else:
		_tile_index_tex.update(_index_img)

## Zero grid: the shader loops every light row directly. Samplers stay bound to a valid 1x1.
func publish_empty() -> void:
	var header_img := Image.create(1, 1, false, Image.FORMAT_RGBAF)
	header_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var index_img := Image.create(INDEX_TEX_WIDTH, 1, false, Image.FORMAT_RGBAF)

	_tile_header_tex = _make_or_update(_tile_header_tex, header_img)
	_tile_index_tex = _make_or_update(_tile_index_tex, index_img)

	RenderingServer.global_shader_parameter_set("iso_tile_origin", Vector2i.ZERO)
	RenderingServer.global_shader_parameter_set("iso_tile_grid", Vector2i.ZERO)
	RenderingServer.global_shader_parameter_set("iso_tile_headers", _tile_header_tex)
	RenderingServer.global_shader_parameter_set("iso_tile_indices", _tile_index_tex)

# ImageTexture.get_size() is Vector2 while Image.get_size() is Vector2i.
func _make_or_update(tex: ImageTexture, img: Image) -> ImageTexture:
	if tex == null or tex.get_size() != Vector2(img.get_size()):
		return ImageTexture.create_from_image(img)
	tex.update(img)
	return tex
