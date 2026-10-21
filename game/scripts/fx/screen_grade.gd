extends CanvasLayer

## Visual tier colour grade for the match world (under the HUD, which lives on
## layer 10): per-zone cool shadows / warm highlights, stronger value contrast,
## a slight desaturation so loot / telegraph / hero accents pop, a soft
## vignette and optional film grain (Settings → Film grain).
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
uniform float grain = 0.0;
uniform float lift = 0.0;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c *= mix(cool, warm, clamp(l * 1.6, 0.0, 1.0));
	c = (c - pivot) * contrast + pivot + lift;
	vec2 d = (SCREEN_UV - vec2(0.5, 0.46)) * vec2(1.25, 1.0);
	float v = smoothstep(0.30, 0.82, length(d));
	c *= 1.0 - vignette * v * v;
	if (grain > 0.0) {
		float n = h21(floor(FRAGCOORD.xy) + floor(TIME * 24.0) * 17.0);
		c += (n - 0.5) * grain;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
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
const GRAIN := 0.035
## Share of the per-zone split-tone kept (1 = full wash).
const WASH := 0.5
const PIVOT := 0.36

var _mat: ShaderMaterial
var _grain_on: bool = true


func _ready() -> void:
	layer = 1
	var rect := ColorRect.new()
	rect.name = "Grade"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
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
	look["contrast"] = 1.0 + (float(look["contrast"]) - 1.0) * 0.6
	look["pivot"] = PIVOT
	for k in look:
		var v: Variant = look[k]
		_mat.set_shader_parameter(k, v)
	_apply_grain()


func _process(_delta: float) -> void:
	if bool(GameState.settings.get("film_grain", true)) != _grain_on:
		_apply_grain()


func _apply_grain() -> void:
	_grain_on = bool(GameState.settings.get("film_grain", true))
	_mat.set_shader_parameter("grain", GRAIN if _grain_on else 0.0)
