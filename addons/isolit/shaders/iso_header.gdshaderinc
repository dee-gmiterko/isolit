// Per-frame light data packed by the registry.
global uniform sampler2D iso_light_data;
global uniform int       iso_light_count;
global uniform int       iso_directional_count;         // directionals occupy rows [0, this)

global uniform vec4      iso_ambient_color : source_color;
global uniform float     iso_ambient_energy;

// Isometric projection, from the isolit/projection/* project settings:
//   screen.x = (world.x - world.y) * (iso_tile_w / 2)
//   screen.y = (world.x + world.y) * (iso_tile_h / 2) - world.z * iso_tile_z
global uniform float     iso_tile_w;
global uniform float     iso_tile_h;
global uniform float     iso_tile_z;

// World-tile light lookup: per-tile header (offset | count into the index list) and
// the flat index list of light rows.
global uniform sampler2D iso_tile_headers;
global uniform sampler2D iso_tile_indices;
global uniform ivec2     iso_tile_origin;               // world tile of header texel (0, 0)
global uniform ivec2     iso_tile_grid;                 // tiles across, tiles down; zero = no grid

// Flat index -> (idx % WIDTH, idx / WIDTH). Must match INDEX_TEX_WIDTH in world_tiles.gd.
const int ISO_INDEX_TEX_WIDTH = 2048;

// Layout must match IsoShadowAtlas.
global uniform sampler2D iso_shadow_atlas;
const int ISO_SHADOW_HALF = 32;
const int ISO_SHADOW_BORDER = 1;
const int ISO_SHADOW_SUB = 3;
const int ISO_SHADOW_SLOT = (2 * ISO_SHADOW_HALF + 1 + 2 * ISO_SHADOW_BORDER) * ISO_SHADOW_SUB;
const int ISO_SHADOW_SLOTS_PER_ROW = 8;

// 0 lit, 1 blocked, indexed by tile offset from the light's tile; each tile is a SUB x SUB block.
// The read is nudged half a sub-texel (+x, +y) so a fragment on a tile's min edge, where the
// visible wall faces sit, samples its own tile instead of the bilinear blend with the neighbour.
float iso_shadow(int slot, vec3 light_pos, vec3 world) {
	vec2 slot_px = vec2(
			float((slot % ISO_SHADOW_SLOTS_PER_ROW) * ISO_SHADOW_SLOT),
			float((slot / ISO_SHADOW_SLOTS_PER_ROW) * ISO_SHADOW_SLOT));
	vec2 local = (world.xy - floor(light_pos.xy) + float(ISO_SHADOW_HALF + ISO_SHADOW_BORDER))
			* float(ISO_SHADOW_SUB) + 0.5;
	local = clamp(local, vec2(0.5), vec2(float(ISO_SHADOW_SLOT) - 0.5));
	vec2 uv = (slot_px + local) / vec2(textureSize(iso_shadow_atlas, 0));
	return texture(iso_shadow_atlas, uv).r;
}

// Constant view direction of the orthographic isometric camera: the null space of the
// projection's linear part. Solving
//   (x - y) * (iso_tile_w/2) = 0,  (x + y) * (iso_tile_h/2) - z * iso_tile_z = 0
// for x=1 gives y=1, z=iso_tile_h/iso_tile_z.
vec3 iso_view_dir() {
	return normalize(vec3(1.0, 1.0, iso_tile_h / iso_tile_z));
}

// Subtract iso_tile_origin for the header texel.
ivec2 iso_world_tile(vec3 world) {
	return ivec2(floor(world.xy));
}

bool iso_tile_in_grid(ivec2 tile) {
	return all(greaterThanEqual(tile, ivec2(0))) && all(lessThan(tile, iso_tile_grid));
}

vec2 iso_world_to_canvas(vec3 world) {
	return vec2(
			(world.x - world.y) * iso_tile_w * 0.5,
			(world.x + world.y) * iso_tile_h * 0.5 - world.z * iso_tile_z);
}

// Inverse of the projection on a fixed-Z plane:
//   with sy = canvas.y + z*iso_tile_z:  x = canvas.x/iso_tile_w + sy/iso_tile_h,
//                                       y = sy/iso_tile_h - canvas.x/iso_tile_w
vec3 iso_canvas_to_world(vec2 canvas_xy, float z) {
	float sy = canvas_xy.y + z * iso_tile_z;
	float u = canvas_xy.x / iso_tile_w;
	float v = sy / iso_tile_h;
	return vec3(u + v, v - u, z);
}

// Inverse on a fixed-X plane: y from canvas.x, then z from canvas.y.
vec3 iso_canvas_to_world_x(vec2 canvas_xy, float x) {
	float y = x - 2.0 * canvas_xy.x / iso_tile_w;
	float z = ((x + y) * iso_tile_h * 0.5 - canvas_xy.y) / iso_tile_z;
	return vec3(x, y, z);
}

// Inverse on a fixed-Y plane: x from canvas.x, then z from canvas.y.
vec3 iso_canvas_to_world_y(vec2 canvas_xy, float y) {
	float x = y + 2.0 * canvas_xy.x / iso_tile_w;
	float z = ((x + y) * iso_tile_h * 0.5 - canvas_xy.y) / iso_tile_z;
	return vec3(x, y, z);
}

// Inverse on the camera-facing plane through `origin`: any point on the view ray, slid
// along the view direction (which moves nothing on canvas) onto that plane.
vec3 iso_canvas_to_world_flat(vec2 canvas_xy, vec3 origin) {
	vec3 v = iso_view_dir();
	vec3 p0 = iso_canvas_to_world(canvas_xy, 0.0);
	return p0 + v * dot(origin - p0, v);
}

// Surface types, matching IsoNode.SurfaceType.
const int ISO_SURFACE_NONE = 0;
const int ISO_SURFACE_FLOOR = 1;
const int ISO_SURFACE_WALL_X = 2;
const int ISO_SURFACE_WALL_Y = 3;
const int ISO_SURFACE_FLAT = 4;

uniform int surface_type = 0;
uniform vec3 origin_world = vec3(0.0);
uniform vec2 origin_canvas = vec2(0.0);

// This fragment's world position: the IsoNode origin, offset by the pixel's canvas
// displacement from the IsoNode along the surface type's plane.
vec3 iso_fragment_world(vec2 canvas_xy) {
	canvas_xy = iso_world_to_canvas(origin_world) + (canvas_xy - origin_canvas);
	if (surface_type == ISO_SURFACE_FLOOR) {
		return iso_canvas_to_world(canvas_xy, origin_world.z);
	}
	if (surface_type == ISO_SURFACE_WALL_X) {
		return iso_canvas_to_world_x(canvas_xy, origin_world.x);
	}
	if (surface_type == ISO_SURFACE_WALL_Y) {
		return iso_canvas_to_world_y(canvas_xy, origin_world.y);
	}
	if (surface_type == ISO_SURFACE_FLAT) {
		return iso_canvas_to_world_flat(canvas_xy, origin_world);
	}
	return origin_world;
}

vec3 iso_surface_normal() {
	if (surface_type == ISO_SURFACE_FLOOR) {
		return vec3(0.0, 0.0, 1.0);
	}
	if (surface_type == ISO_SURFACE_WALL_X) {
		return vec3(1.0, 0.0, 0.0);
	}
	if (surface_type == ISO_SURFACE_WALL_Y) {
		return vec3(0.0, 1.0, 0.0);
	}
	return iso_view_dir();
}

// Iso world-space normal from the drawing node's NORMAL_TEXTURE: R = X, G = Y, B = Z.
vec3 iso_world_normal(vec3 normal_sample) {
	return normalize(normal_sample * 2.0 - 1.0);
}

mat2 iso_normal_xform(vec2 uv_px, vec2 canvas) {
	mat2 duv = mat2(dFdx(uv_px), dFdy(uv_px));
	mat2 dcv = mat2(dFdx(canvas), dFdy(canvas));
	return transpose(duv * inverse(dcv));
}

vec3 iso_rotate_normal(vec3 n, mat2 normal_xform) {
	vec3 V = iso_view_dir();
	vec3 R = normalize(vec3(1.0, -1.0, 0.0));
	vec3 D = -normalize(vec3(0.0, 0.0, 1.0) - V * V.z);
	vec3 c = vec3(dot(n, R), dot(n, D), dot(n, V));
	c.xy = normal_xform * c.xy;
	c = normalize(c);
	return c.x * R + c.y * D + c.z * V;
}

// CanvasTexture.specular_shininess -> Blinn-Phong exponent, Godot's own canvas mapping.
// 1.0 (the default) disables specular.
float iso_specular_exponent(float shininess) {
	return exp2(15.0 * shininess + 1.0) * 0.25;
}

// A light affects this receiver only if (light_mask & receiver_mask) != 0.
uniform int receiver_mask = 1;

varying vec2 v_canvas;

void vertex() {
	v_canvas = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
