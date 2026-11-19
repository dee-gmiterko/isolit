// Applies light row `i` into `lit` using the blend mode in texel 4. Texel layout (see light_packer.gd):
//   t0 = type (0 point, 1 directional, 2 spot) | light_mask | falloff | range
//   t1 = world_position.xyz (direction.xyz for directional) | energy
//   t2 = color.rgb | cos_inner
//   t3 = aim_world.xyz | cos_outer
//   t4 = blend_mode (0 add, 1 subtract, 2 mix, 3 overlay) | 0 | 0 | 0
//   t5 = shadow slot (-1 none) | 0 | 0 | 0
void iso_shade(int i, inout vec3 lit, vec3 albedo, vec3 N, vec3 V, vec3 frag_world,
		vec3 spec_color, float spec_exp) {
	vec4 t0 = texelFetch(iso_light_data, ivec2(0, i), 0);

	int type = int(round(t0.x));
	bool is_directional = type == 1;
	bool is_spot = type == 2;
	int light_mask = int(round(t0.y));
	float falloff = t0.z;
	float range = t0.w;

	if ((light_mask & receiver_mask) == 0) {
		return;
	}

	vec4 t1 = texelFetch(iso_light_data, ivec2(1, i), 0);
	float energy = t1.w;

	vec3 Ldir;
	float atten;

	if (is_directional) {
		// t1.xyz is the world-space direction toward the light.
		Ldir = t1.xyz;
		atten = 1.0;
	} else {
		vec3 L = t1.xyz - frag_world;
		float dist = length(L);
		if (dist > range) {
			return;
		}
		Ldir = (dist > 0.0001) ? (L / dist) : vec3(0.0, 0.0, 1.0);
		atten = pow(clamp(1.0 - dist / range, 0.0, 1.0), falloff);

		if (is_spot) {
			vec4 t3 = texelFetch(iso_light_data, ivec2(3, i), 0);
			vec4 t2c = texelFetch(iso_light_data, ivec2(2, i), 0);
			float cone = smoothstep(t3.w, t2c.w, dot(t3.xyz, -Ldir));
			atten *= cone;
		}
	}

	if (atten <= 0.0) {
		return;
	}

	if (!is_directional) {
		vec4 t5 = texelFetch(iso_light_data, ivec2(5, i), 0);
		int slot = int(round(t5.x));
		if (slot >= 0) {
			atten *= 1.0 - iso_shadow(slot, t1.xyz, frag_world);
			if (atten <= 0.0) {
				return;
			}
		}
	}

	vec4 t2 = texelFetch(iso_light_data, ivec2(2, i), 0);
	vec3 light_color = t2.rgb;

	float ndotl = max(dot(N, Ldir), 0.0);

	vec3 diffuse = albedo * light_color * energy * ndotl * atten;

	// Blinn-Phong, tinted by light_color so highlights take the light's hue.
	vec3 H = normalize(Ldir + V);
	vec3 specular = light_color * energy * atten * spec_color
			* pow(max(dot(N, H), 0.0), spec_exp);

	vec3 contrib = diffuse + specular;

	vec4 t4 = texelFetch(iso_light_data, ivec2(4, i), 0);
	int blend_mode = int(round(t4.x));

	if (blend_mode == 1) {
		lit = max(lit - contrib, vec3(0.0));
	} else if (blend_mode == 2) {
		float w = clamp(atten * ndotl, 0.0, 1.0);
		lit = mix(lit, albedo * light_color * energy, w);
	} else if (blend_mode == 3) {
		// Per-channel overlay of the contribution onto the current color, weighted by the light's reach.
		vec3 b = clamp(contrib, 0.0, 1.0);
		vec3 a = clamp(lit, 0.0, 1.0);
		vec3 lo = 2.0 * a * b;
		vec3 hi = 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
		vec3 overlay = mix(hi, lo, step(a, vec3(0.5)));
		lit = mix(lit, overlay, clamp(atten * ndotl, 0.0, 1.0));
	} else {
		lit += contrib;
	}
}
