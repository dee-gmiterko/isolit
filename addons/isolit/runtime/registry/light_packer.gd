extends RefCounted

## One RGBAF texture row per light, world-space throughout:
##   t0 = type (0 point, 1 directional, 2 spot) | light_mask | falloff | range
##   t1 = world_position.xyz (direction.xyz for directional) | energy
##   t2 = color.rgb | cos_inner
##   t3 = aim_world.xyz | cos_outer          (spot only; zero otherwise)
##   t4 = blend_mode | 0 | 0 | 0             (IsoShaderLibrary.BlendMode: 0 add, 1 subtract, 2 mix, 3 overlay)
##   t5 = shadow slot | 0 | 0 | 0             (slot -1 = no obstruction map)
## Cheap reject fields sit in t0 so the shader can bail after one fetch.

const FrameContext := preload("res://addons/isolit/runtime/registry/frame_context.gd")

const TEXELS_PER_LIGHT := 6

var _texture: ImageTexture
var _dummy: ImageTexture

var _pack_buf: PackedFloat32Array = PackedFloat32Array()
var _pack_img: Image
var _pack_img_count: int = -1


func pack_and_publish(ctx: FrameContext) -> void:
	var visible: Array = ctx.visible
	var dir_count: int = ctx.dir_count
	var count := visible.size()

	var floats_needed := count * TEXELS_PER_LIGHT * 4
	if _pack_buf.size() != floats_needed:
		_pack_buf.resize(floats_needed)
	_pack_buf.fill(0.0)
	for i in count:
		var directional := visible[i] as IsoDirectionalLight
		if directional != null:
			_pack_directional(i, directional)
			continue
		var spot := visible[i] as IsoSpotLight
		if spot != null:
			_pack_spot(i, spot)
			continue
		_pack_point(i, visible[i] as IsoPointLight)
	_upload_pack_buffer(count)

	RenderingServer.global_shader_parameter_set("iso_light_count", count)
	RenderingServer.global_shader_parameter_set("iso_directional_count", dir_count)
	RenderingServer.global_shader_parameter_set("iso_light_data", _texture)


## Zero-light publish: a 1x1 dummy keeps the sampler global valid.
func publish_empty() -> void:
	RenderingServer.global_shader_parameter_set("iso_light_count", 0)
	RenderingServer.global_shader_parameter_set("iso_directional_count", 0)
	RenderingServer.global_shader_parameter_set("iso_light_data", _get_dummy())


func _pack_point(row: int, light: IsoPointLight) -> void:
	var o := row * TEXELS_PER_LIGHT * 4
	const TYPE_POINT := 0.0

	_pack_buf[o + 0] = TYPE_POINT
	_pack_buf[o + 1] = float(light.light_mask)
	_pack_buf[o + 2] = light.falloff
	_pack_buf[o + 3] = light.range

	var wp := light.global_world_position()
	_pack_buf[o + 4] = wp.x
	_pack_buf[o + 5] = wp.y
	_pack_buf[o + 6] = wp.z
	_pack_buf[o + 7] = light.energy

	_pack_buf[o + 8] = light.color.r
	_pack_buf[o + 9] = light.color.g
	_pack_buf[o + 10] = light.color.b

	_pack_buf[o + 16] = float(light.blend_mode)

	_pack_shadow(o, light)


## Texel 1 holds the direction toward the light, negated from the node's `direction`
## (the direction the light travels).
func _pack_directional(row: int, light: IsoDirectionalLight) -> void:
	var dir := light.direction
	if dir.length() > 0.0:
		dir = dir.normalized()

	var o := row * TEXELS_PER_LIGHT * 4
	const TYPE_DIRECTIONAL := 1.0

	_pack_buf[o + 0] = TYPE_DIRECTIONAL
	_pack_buf[o + 1] = float(light.light_mask)

	_pack_buf[o + 4] = -dir.x
	_pack_buf[o + 5] = -dir.y
	_pack_buf[o + 6] = -dir.z
	_pack_buf[o + 7] = light.energy

	_pack_buf[o + 8] = light.color.r
	_pack_buf[o + 9] = light.color.g
	_pack_buf[o + 10] = light.color.b

	_pack_buf[o + 16] = float(light.blend_mode)

	_pack_buf[o + 20] = -1.0


func _pack_spot(row: int, light: IsoSpotLight) -> void:
	var aim := light.aim_world
	if aim.length() > 0.0:
		aim = aim.normalized()

	# Keep inner strictly inside outer so the shader's smoothstep never divides by zero.
	var cos_outer := cos(deg_to_rad(light.spot_angle))
	var cos_inner := cos(deg_to_rad(light.spot_angle * (1.0 - light.spot_softness)))
	if cos_inner <= cos_outer:
		cos_inner = cos_outer + 0.0001

	var o := row * TEXELS_PER_LIGHT * 4
	const TYPE_SPOT := 2.0

	_pack_buf[o + 0] = TYPE_SPOT
	_pack_buf[o + 1] = float(light.light_mask)
	_pack_buf[o + 2] = light.falloff
	_pack_buf[o + 3] = light.range

	var wp := light.global_world_position()
	_pack_buf[o + 4] = wp.x
	_pack_buf[o + 5] = wp.y
	_pack_buf[o + 6] = wp.z
	_pack_buf[o + 7] = light.energy

	_pack_buf[o + 8] = light.color.r
	_pack_buf[o + 9] = light.color.g
	_pack_buf[o + 10] = light.color.b
	_pack_buf[o + 11] = cos_inner

	_pack_buf[o + 12] = aim.x
	_pack_buf[o + 13] = aim.y
	_pack_buf[o + 14] = aim.z
	_pack_buf[o + 15] = cos_outer

	_pack_buf[o + 16] = float(light.blend_mode)

	_pack_shadow(o, light)


func _pack_shadow(o: int, light: IsoPositionalLight) -> void:
	_pack_buf[o + 20] = float(IsoShadowAtlas.slot_of(light))


func _upload_pack_buffer(count: int) -> void:
	var bytes := _pack_buf.to_byte_array()
	if _pack_img == null or _pack_img_count != count:
		_pack_img = Image.create_from_data(TEXELS_PER_LIGHT, count, false, Image.FORMAT_RGBAF, bytes)
		_pack_img_count = count
	else:
		_pack_img.set_data(TEXELS_PER_LIGHT, count, false, Image.FORMAT_RGBAF, bytes)

	if _texture == null or _texture.get_size() != Vector2(TEXELS_PER_LIGHT, count):
		_texture = ImageTexture.create_from_image(_pack_img)
	else:
		_texture.update(_pack_img)

func _get_dummy() -> ImageTexture:
	if _dummy == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBAF)
		img.set_pixel(0, 0, Color(0, 0, 0, 0))
		_dummy = ImageTexture.create_from_image(img)
	return _dummy
