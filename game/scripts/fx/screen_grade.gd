extends CanvasLayer

## Visual tier colour grade for the match world (under the HUD, which lives on
## layer 10): per-zone cool shadows / warm highlights, stronger value contrast,
## a slight desaturation so loot / telegraph / hero accents pop, a soft
## vignette, or (Settings → Edge dither, default off) a static pixel-checker
## dither vignette instead. The bible bans noise, so there is no film grain:
## the setting key is "edge_dither" (saves with the old "film_grain" key are
## migrated by SettingsDefs.upgrade_keys).
## One full-screen pass over the screen texture — fine on iPhone.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 cool = vec3(0.80, 0.84, 0.96);
uniform vec3 warm = vec3(1.08, 0.97, 0.84);
uniform float contrast = 1.16;
uniform float pivot = 0.46;
uniform float sat = 0.88;
uniform float vignette = 0.62;
uniform float dither = 0.0;
uniform float lift = 0.0;
uniform float gamma = 1.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c *= mix(cool, warm, clamp(l * 1.6, 0.0, 1.0));
	c = (c - pivot) * contrast + pivot + lift;
	vec2 d = (SCREEN_UV - vec2(0.5, 0.46)) * vec2(1.25, 1.0);
	float v = smoothstep(0.30, 0.82, length(d));
	if (dither > 0.0) {
		// Static 2-design-px checker cells, 2 hard steps toward the corners
		// (no noise, no animation, no soft gradient).
		float cell = max(1.0, floor((1.0 / SCREEN_PIXEL_SIZE.x) / 360.0));
		vec2 q = floor(FRAGCOORD.xy / cell);
		bool chk = mod(q.x + q.y, 2.0) < 1.0;
		float dk = 0.0;
		if (v > 0.82) { dk = 1.0; } else if (v > 0.5 && chk) { dk = 1.0; }
		c *= 1.0 - dither * dk;
	} else {
		c *= 1.0 - vignette * v * v;
	}
	COLOR = vec4(pow(clamp(c, 0.0, 1.0), vec3(gamma)), 1.0);
}
"""

## Cheap path (no screen read): after the audit pass the grade is just a ~10%
## tint + soft vignette (+ optional dither), which a multiply blend can draw
## without copying the back buffer — a full-screen copy + read every frame is
## one of the costliest things a tile GPU (iPhone) can do. The luminance split
## (cool shadows / warm highlights) is folded to its midpoint (<= 1, since a
## multiply can't brighten); the screen-read shader stays for Brightness != 1.
const SHADER_MUL := """
shader_type canvas_item;
render_mode blend_mul;
uniform vec3 cool = vec3(0.80, 0.84, 0.96);
uniform vec3 warm = vec3(1.08, 0.97, 0.84);
uniform float vignette = 0.62;
uniform float dither = 0.0;

void fragment() {
	vec3 c = min(mix(cool, warm, 0.5), vec3(1.0));
	vec2 d = (SCREEN_UV - vec2(0.5, 0.46)) * vec2(1.25, 1.0);
	float v = smoothstep(0.30, 0.82, length(d));
	if (dither > 0.0) {
		float cell = max(1.0, floor((1.0 / SCREEN_PIXEL_SIZE.x) / 360.0));
		vec2 q = floor(FRAGCOORD.xy / cell);
		bool chk = mod(q.x + q.y, 2.0) < 1.0;
		float dk = 0.0;
		if (v > 0.82) { dk = 1.0; } else if (v > 0.5 && chk) { dk = 1.0; }
		c *= 1.0 - dither * dk;
	} else {
		c *= 1.0 - vignette * v * v;
	}
	COLOR = vec4(c, 1.0);
}
"""

## Default look (The Haze / The Drift) and per-zone overrides (ZoneDefs id).
const LOOK := {"cool": Vector3(0.80, 0.84, 0.96), "warm": Vector3(1.08, 0.97, 0.84), "contrast": 1.16,
	"pivot": 0.46, "sat": 0.88, "vignette": 0.62, "lift": 0.0}
const ZONE_LOOK := {
	"smog": {"cool": Vector3(0.82, 0.84, 0.90), "warm": Vector3(1.06, 0.98, 0.86), "sat": 0.8},
	"pall": {"cool": Vector3(0.74, 0.82, 1.04), "warm": Vector3(1.04, 0.98, 0.90), "contrast": 1.08, "vignette": 0.45, "lift": 0.02},
	"blight": {"cool": Vector3(0.78, 0.88, 0.86), "warm": Vector3(1.02, 1.04, 0.86)},
	"shroud": {"cool": Vector3(0.80, 0.80, 0.94), "warm": Vector3(1.10, 0.94, 0.82), "sat": 0.84},
	"choke": {"cool": Vector3(0.80, 0.86, 0.84), "warm": Vector3(1.04, 1.04, 0.80)},
	"blackout": {"cool": Vector3(0.80, 0.85, 0.92), "warm": Vector3(1.04, 1.0, 0.86)},
	"deadfall": {"cool": Vector3(0.80, 0.82, 0.94), "warm": Vector3(1.06, 0.96, 0.88), "sat": 0.8},
	"dustfall": {"cool": Vector3(0.84, 0.80, 0.92), "warm": Vector3(1.10, 0.96, 0.80), "contrast": 1.12},
}
## Edge dither darkening per dithered cell (INK-ward, ~15%).
const DITHER := 0.16
## Share of the per-zone split-tone kept (1 = full wash). Style bible 2.1:
## zone tint <= 10%, no full-screen washes; the ground is authored in each
## zone's own palette and mood comes from light pools.
const WASH := 0.1
const PIVOT := 0.36

var _mat: ShaderMaterial
var _grain_on: bool = false
var _gamma: float = 1.0
var _sh_full: Shader
var _sh_mul: Shader
var _look: Dictionary = {}


func _ready() -> void:
	layer = 1
	var rect := ColorRect.new()
	rect.name = "Grade"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sh_full = Shader.new()
	_sh_full.code = SHADER
	_sh_mul = Shader.new()
	_sh_mul.code = SHADER_MUL
	_mat = ShaderMaterial.new()
	_mat.shader = _sh_mul
	rect.material = _mat
	add_child(rect)
	var look := LOOK.duplicate()
	var zid := str(ZoneDefs.zone(GameState.zone_tier()).get("id", "haze"))
	look.merge(ZONE_LOOK.get(zid, {}), true)
	## Audit value pass: the zone colour wash and vignette are cut ~50% (hue on
	## accents, not as a full-screen soup) and contrast pivots lower so the
	## mid-value ground isn't crushed toward black.
	for k in ["cool", "warm"]:
		look[k] = Vector3.ONE.lerp(look[k], WASH)
	look["vignette"] = float(look["vignette"]) * 0.5
	## Palette-true: no global contrast / saturation curve over the bible palette.
	look["contrast"] = 1.0
	look["sat"] = 1.0
	look["lift"] = 0.0
	look["pivot"] = PIVOT
	_look = look
	_gamma = SettingsDefs.gamma()
	_pick_shader()


## Screen-read shader only when Brightness is moved off 1.0.
func _pick_shader() -> void:
	var want := _sh_full if absf(_gamma - 1.0) > 0.001 else _sh_mul
	if _mat.shader != want:
		_mat.shader = want
	for k in _look:
		var v: Variant = _look[k]
		_mat.set_shader_parameter(k, v)
	_mat.set_shader_parameter("gamma", _gamma)
	_apply_grain()


func _process(_delta: float) -> void:
	if bool(GameState.settings.get("edge_dither", false)) != _grain_on:
		_apply_grain()
	## Settings > Brightness (gamma on the world, under the HUD).
	var g := SettingsDefs.gamma()
	if absf(g - _gamma) > 0.001:
		_gamma = g
		_pick_shader()


func gamma_value() -> float:
	return _gamma


func _apply_grain() -> void:
	_grain_on = bool(GameState.settings.get("edge_dither", false))
	_mat.set_shader_parameter("dither", DITHER if _grain_on else 0.0)
