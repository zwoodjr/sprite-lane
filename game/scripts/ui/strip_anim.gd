class_name StripAnim
extends TextureRect

## Plays a square-frame animation strip (e.g. a hero's _idle.png) inside UI.
## Frames are the strip height wide. Nearest filter keeps the paint crisp.

var fps: float = 8.0
## false = play once and hold the last frame (e.g. a death strip).
var loop: bool = true
## With loop off: frame to stop on (-1 = last). Death strips fade out at the end.
var end_frame: int = -1
var _atlas: AtlasTexture
var _frames: int = 1
var _t: float = 0.0
var _frame: int = -1


static func make(path: String, px: float, p_fps: float = 8.0) -> StripAnim:
	var s := StripAnim.new()
	s.fps = p_fps
	s.custom_minimum_size = Vector2(px, px)
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.set_strip(path)
	return s


func set_strip(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		texture = null
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	var h := float(tex.get_height())
	_frames = maxi(1, int(round(float(tex.get_width()) / h)))
	## Units with a per-state fps sidecar (<prefix>_anim.json) play at their own rate.
	var cut := path.rfind("_")
	if cut > 0 and path.ends_with(".png"):
		var side := UnitAnim.load_json(path.substr(0, cut) + "_anim.json")
		var st := path.substr(cut + 1).trim_suffix(".png")
		var f: Dictionary = side.get("fps", {})
		if f.has(st):
			fps = float(f[st])
	_atlas = AtlasTexture.new()
	_atlas.atlas = tex
	_atlas.region = Rect2(0, 0, h, h)
	texture = _atlas
	_frame = 0
	_t = 0.0


func _process(delta: float) -> void:
	if _atlas == null or _frames <= 1:
		return
	_t += delta
	var f := int(_t * fps)
	var last := _frames - 1 if end_frame < 0 else mini(end_frame, _frames - 1)
	f = f % _frames if loop else mini(f, last)
	if f != _frame:
		_frame = f
		var h := _atlas.region.size.y
		_atlas.region = Rect2(h * f, 0, h, h)
