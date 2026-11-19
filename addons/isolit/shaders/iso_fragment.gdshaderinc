// Albedo, normal and specular come from the drawing node's own CanvasTexture:
// TEXTURE, NORMAL_TEXTURE and SPECULAR_SHININESS (specular_texture * specular_color, .a shininess).
void fragment() {
	mat2 normal_xform = iso_normal_xform(UV * vec2(textureSize(TEXTURE, 0)), v_canvas);
	if (any(greaterThan(textureSize(TEXTURE, 0), ivec2(4)))) {
		vec4  tex_albedo = texture(TEXTURE, UV);
		if (tex_albedo.a <= 0.0) {
			discard;
		}
		vec3  albedo     = tex_albedo.rgb;
		bool  has_normal = textureSize(NORMAL_TEXTURE, 0) == textureSize(TEXTURE, 0);
		vec3  N          = iso_surface_normal();
		if (has_normal) {
			N = iso_rotate_normal(iso_world_normal(texture(NORMAL_TEXTURE, UV).xyz), normal_xform);
		}
		vec4  spec       = SPECULAR_SHININESS;
		vec3  spec_color = spec.rgb;
		float spec_exp   = iso_specular_exponent(spec.a);

		vec3 V = iso_view_dir();

		vec3 frag_world = iso_fragment_world(v_canvas);

		vec3 lit = albedo * iso_ambient_color.rgb * iso_ambient_energy;

		bool tiling_valid = iso_tile_grid.x > 0 && iso_tile_grid.y > 0;

		if (tiling_valid) {
			for (int i = 0; i < iso_directional_count; i++) {
				iso_shade(i, lit, albedo, N, V, frag_world, spec_color, spec_exp);
			}

			ivec2 tile = iso_world_tile(frag_world) - iso_tile_origin;
			if (iso_tile_in_grid(tile)) {
				vec4 header = texelFetch(iso_tile_headers, tile, 0); // offset | count
				int offset = int(round(header.x));
				int count = int(round(header.y));
				for (int j = 0; j < count; j++) {
					int flat_idx = offset + j;
					ivec2 icoord = ivec2(flat_idx % ISO_INDEX_TEX_WIDTH, flat_idx / ISO_INDEX_TEX_WIDTH);
					int li = int(round(texelFetch(iso_tile_indices, icoord, 0).x));
					iso_shade(li, lit, albedo, N, V, frag_world, spec_color, spec_exp);
				}
			}
		} else {
			for (int i = 0; i < iso_light_count; i++) {
				iso_shade(i, lit, albedo, N, V, frag_world, spec_color, spec_exp);
			}
		}

		COLOR = vec4(lit, tex_albedo.a);
	}
}
