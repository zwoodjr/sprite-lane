shader_type canvas_item;

// Wasteland floor, baked once per 512 px chunk (SubViewport, see
// WastelandChunk) in WORLD space so everything runs
// continuously across chunk borders. Mirrors GroundField (CPU) exactly:
//  - biome zones (cracked earth / sand drifts / darker scrub / rubble) picked
//    per pixel from seeded value noise, with Bayer-dithered borders
//  - dried riverbeds along a noise isoline, with darker banks
//  - roads from the chunk's road segments: cracked asphalt, crumbling edges,
//    faded centre dashes, potholes
// Every texture is sampled in one of two frames (straight / rotated) chosen by
// low-frequency noise, so the 512 px period never reads as a grid.

uniform sampler2D tex_earth : repeat_enable, filter_nearest;
uniform sampler2D tex_sand : repeat_enable, filter_nearest;
uniform sampler2D tex_scrub : repeat_enable, filter_nearest;
uniform sampler2D tex_rubble : repeat_enable, filter_nearest;
uniform sampler2D tex_river : repeat_enable, filter_nearest;
uniform sampler2D tex_asphalt : repeat_enable, filter_nearest;
uniform vec2 seed_off = vec2(0.0);
uniform vec2 chunk_origin = vec2(0.0);
uniform int road_count = 0;
uniform vec4 road_seg[8];
uniform float road_off[8];
uniform float road_half = 26.0;
// World px per baked pixel (UnitAnim.TEXEL): the chunk bakes at native
// density, so one tile texel = one bake pixel = one screen pixel.
uniform float texel = 0.7407407;

varying vec2 world;
varying vec2 bpx;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float bayer4(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	int i = q.x + q.y * 4;
	// 4x4 ordered-dither matrix, row-major.
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

vec4 tex_frame(sampler2D t, vec2 p, bool alt, float period) {
	float per = period * texel;
	vec2 uv = alt ? vec2(p.y, -p.x) / per + vec2(0.37, 0.61) : p / per;
	return texture(t, uv);
}

void vertex() {
	bpx = VERTEX;
	world = chunk_origin + VERTEX * texel;
}

void fragment() {
	vec2 p = world;
	float dz = bayer4(floor(bpx));
	bool alt = vnoise(p / 640.0 + seed_off * 1.7) + dz * 0.02 > 0.5;

	// --- biome zones
	float wq = (vnoise(p / 350.0 + seed_off + 91.0) - 0.5) * 320.0;
	vec2 pw = p + vec2(wq, -wq);
	float m = vnoise(pw / 1300.0 + seed_off);
	float n = vnoise(pw / 1100.0 + seed_off.yx + 57.0);
	vec4 col = tex_frame(tex_earth, p, alt, 512.0);
	if (n + dz * 0.06 > 0.69) {
		col = tex_frame(tex_rubble, p, alt, 512.0);
	} else if (m + dz * 0.06 > 0.64) {
		col = tex_frame(tex_sand, p, alt, 512.0);
	} else if (m + dz * 0.06 < 0.32) {
		col = tex_frame(tex_scrub, p, alt, 512.0);
	}

	// --- dried riverbeds (only in regions where the gate field allows)
	float gate = vnoise(p / 2400.0 + seed_off.yx * 0.9 + 13.0);
	if (gate > 0.58) {
		float r = vnoise(p / 1100.0 + seed_off * 0.7 + 200.0) * 0.85 + vnoise(p / 300.0 + seed_off + 31.0) * 0.15;
		float w = abs(r - 0.5) + dz * 0.008;
		float width = 0.02 * smoothstep(0.58, 0.65, gate);
		if (w < width) {
			col = tex_frame(tex_river, p, alt, 512.0);
		} else if (w < width + 0.006) {
			col.rgb *= 0.86;
		}
	}

	// --- roads
	for (int k = 0; k < 8; k++) {
		if (k >= road_count) break;
		vec2 a = road_seg[k].xy;
		vec2 b = road_seg[k].zw;
		vec2 ab = b - a;
		float len = length(ab);
		vec2 dir = ab / len;
		float t = clamp(dot(p - a, dir), 0.0, len);
		vec2 nrm = vec2(-dir.y, dir.x);
		float side = dot(p - a, nrm);
		float dist = length(p - (a + dir * t));
		float along = road_off[k] + t;
		float hw = road_half + (hash12(vec2(floor(along / 7.0), 3.0) + seed_off) - 0.5) * 4.0;
		if (dist < hw + 3.0) {
			if (dist > hw) {
				col.rgb *= 0.82; // crumbled shoulder
			} else if (dist > hw - 5.0 && hash12(floor(p / 2.0) + seed_off) > 0.55) {
				col.rgb *= 0.9; // ragged asphalt edge lets dirt through
			} else {
				col = tex_frame(tex_asphalt, p, alt, 256.0);
				// faded centre dashes
				float cell = floor(along / 52.0);
				float fade = hash12(vec2(cell, 9.0) + seed_off);
				if (abs(side) < 1.6 && fract(along / 52.0) < 0.5 && fade > 0.25) {
					col.rgb = mix(col.rgb, vec3(0.50, 0.44, 0.29), 0.45 + fade * 0.25);
				}
				// worn edge line
				if (dist > hw - 9.0 && dist < hw - 7.4 && hash12(vec2(floor(along / 23.0), side > 0.0 ? 5.0 : 6.0) + seed_off) > 0.35) {
					col.rgb = mix(col.rgb, vec3(0.42, 0.40, 0.36), 0.5);
				}
				// potholes: one candidate per 110 px of road
				float pc = floor(along / 110.0);
				float h = hash12(vec2(pc, float(k) + 17.0) + seed_off);
				if (h > 0.5) {
					float pa = (pc + 0.25 + 0.5 * hash12(vec2(pc, 41.0) + seed_off)) * 110.0;
					float ps = (hash12(vec2(pc, 43.0) + seed_off) - 0.5) * hw * 1.1;
					float pr = 5.0 + 6.0 * hash12(vec2(pc, 47.0) + seed_off);
					vec2 q = vec2(along - pa, side - ps) / vec2(pr * 1.35, pr);
					float qd = length(q);
					if (qd < 1.0) {
						// light from top-left: inner top-left wall in shadow
						float lit = dot(normalize(q + 0.001), vec2(0.7, 0.7));
						col.rgb = qd > 0.72 ? (lit > 0.0 ? vec3(0.33, 0.31, 0.29) : vec3(0.15, 0.13, 0.12)) : vec3(0.19, 0.17, 0.15);
					} else if (qd < 1.25) {
						col.rgb *= 0.86;
					}
				}
			}
		}
	}

	// gentle large-scale value drift (±4%)
	float drift = vnoise(p / 380.0 + seed_off * 1.3 + 7.0);
	col.rgb *= 0.96 + drift * 0.08;
	COLOR = vec4(col.rgb, 1.0);
}
