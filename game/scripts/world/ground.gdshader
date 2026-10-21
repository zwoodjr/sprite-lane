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
// Style bible 2.2: the zone's 4 ground colours (crack / base / mid / speck).
// Every tile is authored in exactly these, and every shading step below
// (banks, shoulders, potholes, rims) moves one step down this ramp, so the
// floor never leaves the zone palette.
uniform vec3 zc0 = vec3(0.263, 0.204, 0.157);
uniform vec3 zc1 = vec3(0.357, 0.290, 0.231);
uniform vec3 zc2 = vec3(0.408, 0.337, 0.271);
uniform vec3 zc3 = vec3(0.494, 0.412, 0.325);

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

// Two frames per texture (straight / offset) so the period never reads as a
// grid. No rotation or flip: tiles are lit top-left and must stay that way.
vec4 tex_frame(sampler2D t, vec2 p, bool alt, float period) {
	float per = period * texel;
	vec2 uv = p / per + (alt ? vec2(0.37, 0.61) : vec2(0.0));
	return texture(t, uv);
}

// One step darker on the zone ramp (speck -> mid -> base -> crack).
vec3 step_down(vec3 c) {
	float d0 = distance(c, zc0);
	float d1 = distance(c, zc1);
	float d2 = distance(c, zc2);
	float d3 = distance(c, zc3);
	if (d3 <= d0 && d3 <= d1 && d3 <= d2) return zc2;
	if (d2 <= d0 && d2 <= d1) return zc1;
	return zc0;
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
	// Visual tier: patches BLEND into each other (ragged painted edges from a
	// fine noise + dither) instead of hard cuts; rubble patches get a soft
	// darker rim so they sit in the earth like the mockup's blended rubble.
	float e = dz * 0.03 + (vnoise(p / 23.0 + seed_off * 3.1) - 0.5) * 0.045;
	float ws = smoothstep(0.625, 0.66, m + e);
	float wc = 1.0 - smoothstep(0.30, 0.335, m + e);
	float wr = smoothstep(0.672, 0.705, n + e);
	// Patches meet in an ordered-dither band (palette pixels only, no blends).
	float th = dz + 0.5;
	vec4 col = tex_frame(tex_earth, p, alt, 256.0);
	if (ws > th) col = tex_frame(tex_sand, p, alt, 256.0);
	if (wc > th) col = tex_frame(tex_scrub, p, alt, 256.0);
	if (wr > th) col = tex_frame(tex_rubble, p, alt, 256.0);
	if (wr > 0.02 && wr < 0.98 && (1.0 - abs(wr * 2.0 - 1.0)) > th + 0.35) col.rgb = step_down(col.rgb);

	// --- dried riverbeds (only in regions where the gate field allows)
	float gate = vnoise(p / 2400.0 + seed_off.yx * 0.9 + 13.0);
	if (gate > 0.58) {
		float r = vnoise(p / 1100.0 + seed_off * 0.7 + 200.0) * 0.85 + vnoise(p / 300.0 + seed_off + 31.0) * 0.15;
		float w = abs(r - 0.5) + dz * 0.003 + e * 0.05;
		float width = 0.02 * smoothstep(0.58, 0.65, gate);
		// soft painted bank: the riverbed fades in, a shaded lip runs along it
		float kr = 1.0 - smoothstep(width - 0.003, width + 0.001, w);
		if (kr > th) col = tex_frame(tex_river, p, alt, 256.0);
		// a narrow shaded bank lip (dithered 2-3 px), not a wide dark smear
		float bank = (1.0 - smoothstep(width, width + 0.0025, w)) * (1.0 - kr);
		if (bank > th) col.rgb = step_down(col.rgb);
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
				col.rgb = step_down(col.rgb); // crumbled shoulder
			} else if (dist > hw - 5.0 && hash12(floor(p / 2.0) + seed_off) > 0.55) {
				// ragged asphalt edge lets the dirt through
			} else {
				col = tex_frame(tex_asphalt, p, alt, 256.0);
				// faded centre dashes
				float cell = floor(along / 80.0);
				float fade = hash12(vec2(cell, 9.0) + seed_off);
				float wob = (hash12(floor(vec2(along / 3.0, side)) + seed_off) - 0.5) * 0.5;
				if (abs(side) < 2.2 + wob && fract(along / 80.0) < 0.45 && fade > 0.22) {
					if (fade > 0.55 || th < 0.5) col.rgb = zc3;
				}
				// worn edge line
				if (dist > hw - 12.0 && dist < hw - 10.0 && hash12(vec2(floor(along / 23.0), side > 0.0 ? 5.0 : 6.0) + seed_off) > 0.35) {
					if (th < 0.6) col.rgb = zc2;
				}
				// potholes: one candidate per 110 px of road
				float pc = floor(along / 150.0);
				float h = hash12(vec2(pc, float(k) + 17.0) + seed_off);
				if (h > 0.5) {
					float pa = (pc + 0.25 + 0.5 * hash12(vec2(pc, 41.0) + seed_off)) * 150.0;
					float ps = (hash12(vec2(pc, 43.0) + seed_off) - 0.5) * hw * 1.1;
					float pr = 7.0 + 8.0 * hash12(vec2(pc, 47.0) + seed_off);
					vec2 q = vec2(along - pa, side - ps) / vec2(pr * 1.35, pr);
					float qd = length(q);
					if (qd < 1.0) {
						// light from top-left: inner top-left wall in shadow
						float lit = dot(normalize(q + 0.001), vec2(0.7, 0.7));
						col.rgb = qd > 0.72 ? (lit > 0.0 ? zc3 : zc0) : (qd > 0.5 ? zc1 : zc0);
					} else if (qd < 1.25) {
						col.rgb = step_down(col.rgb);
					}
				}
			}
		}
	}

	COLOR = vec4(col.rgb, 1.0);
}
