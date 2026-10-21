extends Node

## Pooled pixel-VFX player (style bible §5). Owned by the Juice autoload
## (Juice.fx / fx_impact / fx_explosion / fx_death / decal / status_fx / px_loop).
## Art: assets/sprites/fx/px/<id>.png strips + fx_px.json (tools/gen_fx_px.py).
## Every sprite draws at UnitAnim.TEXEL (1 texel = 1 design px), never rotated:
## directional strips ("<id>@0..4") are mirrored with flip_h / flip_v instead.
## Cheap on iPhone: one shared AnimatedSprite2D pool (cap FX_CAP), a decal pool
## (cap DECAL_CAP), per-kind throttles, SpriteFrames built once per id.

const DIR := "res://assets/sprites/fx/px/"
const FX_CAP := 120
const DECAL_CAP := 28
## Impacts allowed per IMPACT_WINDOW seconds (a blade storm on a horde).
const IMPACT_MAX := 8
const IMPACT_WINDOW := 0.1
const ALPHA_STEPS := [1.0, 0.75, 0.5, 0.25]

var _man: Dictionary = {}
var _frames: Dictionary = {}
var _layer: Node2D
var _pool: Array[AnimatedSprite2D] = []
var _live: Array[Dictionary] = []
var _decals: Array[Dictionary] = []
var _impact_t: float = 0.0
var _impact_n: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var f := FileAccess.open(DIR + "fx_px.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_man = d


func has(id: String) -> bool:
	return _man.has(id) or _man.has(id + "@0")


func info(id: String) -> Dictionary:
	return _man.get(id, _man.get(id + "@0", {}))


## SpriteFrames for one strip (cached; animation "default").
func sprite_frames(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var m: Dictionary = _man.get(id, {})
	var path := DIR + id + ".png"
	if m.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", bool(m.get("loop", false)))
	sf.set_animation_speed("default", float(m.get("fps", 12)))
	var n := int(m.get("n", 1))
	var w := int(m.get("w", tex.get_width()))
	for i in range(n):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * w, 0, w, int(m.get("h", tex.get_height())))
		sf.add_frame("default", at)
	_frames[id] = sf
	return sf


## Pick the mirrored base strip for a direction: [id@k, flip_h, flip_v].
func dir_variant(id: String, dir: Vector2) -> Array:
	if not _man.has(id + "@0"):
		return [id, false, false]
	var a := fposmod(rad_to_deg(dir.angle()), 360.0)
	var k := int(round(a / 22.5)) % 16
	var b := k * 22.5
	if b <= 90.0:
		return ["%s@%d" % [id, int(b / 22.5)], false, false]
	if b <= 180.0:
		return ["%s@%d" % [id, int((180.0 - b) / 22.5)], true, false]
	if b <= 270.0:
		return ["%s@%d" % [id, int((b - 180.0) / 22.5)], true, true]
	return ["%s@%d" % [id, int((360.0 - b) / 22.5)], false, true]


## Configure an AnimatedSprite2D for strip `id` (anchor, flips, texel scale).
func dress(s: AnimatedSprite2D, id: String, fh: bool = false, fv: bool = false, k: float = 1.0) -> bool:
	var sf := sprite_frames(id)
	if sf == null:
		return false
	var m: Dictionary = _man[id]
	s.sprite_frames = sf
	s.animation = "default"
	s.frame = 0
	s.centered = true
	s.flip_h = fh
	s.flip_v = fv
	var off := Vector2(float(m["w"]) * 0.5 - float(m["ox"]), float(m["h"]) * 0.5 - float(m["oy"]))
	if fh:
		off.x = -off.x
	if fv:
		off.y = -off.y
	s.offset = off
	s.scale = Vector2.ONE * UnitAnim.TEXEL * k
	s.z_index = int(m.get("z", 5))
	s.z_as_relative = false
	s.modulate = Color.WHITE
	if bool(m.get("add", false)):
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = add
	else:
		s.material = null
	return true


func _ensure_layer() -> Node2D:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return null
	if _layer != null and is_instance_valid(_layer) and _layer.get_parent() == scene:
		return _layer
	_layer = Node2D.new()
	_layer.name = "PxFxLayer"
	scene.add_child(_layer)
	_pool.clear()
	_live.clear()
	_decals.clear()
	return _layer


func _take() -> AnimatedSprite2D:
	for s in _pool:
		if not s.visible:
			return s
	if _pool.size() < FX_CAP:
		var s := AnimatedSprite2D.new()
		s.visible = false
		s.animation_finished.connect(_on_done.bind(s))
		_layer.add_child(s)
		_pool.append(s)
		return s
	return null


func _on_done(s: AnimatedSprite2D) -> void:
	if not is_instance_valid(s):
		return
	s.visible = false
	s.stop()
	for i in range(_live.size() - 1, -1, -1):
		if is_same(_live[i]["s"], s):
			_live.remove_at(i)


## Play strip `id` once at world `pos`. opts: dir (Vector2, directional strips),
## follow (Node2D; sticks at its offset), k (scale, keep 1 unless forced),
## z, tint (Color), speed (fps mult).
func play(id: String, pos: Vector2, opts: Dictionary = {}) -> AnimatedSprite2D:
	if _ensure_layer() == null:
		return null
	var v := [id, false, false]
	if opts.has("dir"):
		v = dir_variant(id, opts["dir"])
	if not _man.has(v[0]):
		return null
	var s := _take()
	if s == null:
		return null
	if not dress(s, v[0], v[1], v[2], float(opts.get("k", 1.0))):
		return null
	if opts.has("z"):
		s.z_index = int(opts["z"])
	if opts.has("tint"):
		s.modulate = opts["tint"]
	s.global_position = pos
	s.speed_scale = float(opts.get("speed", 1.0))
	s.visible = true
	s.play("default")
	var e := {"s": s, "t": 0.0}
	var fol: Variant = opts.get("follow")
	if fol is Node2D and is_instance_valid(fol):
		e["follow"] = weakref(fol)
		e["off"] = pos - (fol as Node2D).global_position
	_live.append(e)
	return s


func _process(delta: float) -> void:
	if _layer == null or not is_instance_valid(_layer):
		if not _live.is_empty() or not _decals.is_empty() or not _pool.is_empty():
			_live.clear()
			_decals.clear()
			_pool.clear()
		return
	_impact_t -= delta
	if _impact_t <= 0.0:
		_impact_t = IMPACT_WINDOW
		_impact_n = 0
	for i in range(_live.size() - 1, -1, -1):
		var e: Dictionary = _live[i]
		if not is_instance_valid(e["s"]):
			_live.remove_at(i)
			continue
		var s: AnimatedSprite2D = e["s"]
		e["t"] = float(e["t"]) + delta
		if e.has("follow"):
			var n: Node2D = (e["follow"] as WeakRef).get_ref()
			if n != null and is_instance_valid(n) and n.is_inside_tree():
				s.global_position = n.global_position + (e["off"] as Vector2)
	_tick_decals(delta)


## --- impacts / explosions / deaths ------------------------------------------

## Material impact: "plague" | "machine" | "raider" | "ground" | "spark" | fire/shock/frost.
func impact(pos: Vector2, material: String) -> void:
	if _impact_n >= IMPACT_MAX:
		return
	_impact_n += 1
	var id: String = {
		"plague": "hit_flesh", "flesh": "hit_flesh", "machine": "hit_machine", "raider": "hit_raider",
		"ground": "hit_dust", "prop": "hit_dust", "fire": "hit_fire", "incendiary": "hit_fire",
		"shock": "hit_shock", "frost": "hit_frost", "explosive": "ex_tiny",
	}.get(material, "hit_spark")
	play(id, pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)))


## Fire blast sized by radius: tiny / small / big, plus a scorch decal.
func explosion(pos: Vector2, radius: float, scorch: bool = true) -> void:
	var id := "ex_tiny" if radius < 45.0 else ("ex_small" if radius < 110.0 else "ex_big")
	play(id, pos)
	if scorch:
		decal("dc_scorch" if radius < 110.0 else "dc_scorch_big", pos + Vector2(0, 6))


## Ground slam (maul, quarry slam, rush end): dust shockwave + crack decal.
func slam(pos: Vector2) -> void:
	play("ex_slam", pos)
	decal("dc_crack", pos)


## Faction death pop + its lingering decal. big = elites / brutes / bosses.
func death(pos: Vector2, faction: String, big: bool = false) -> void:
	var k := 1.0
	match faction:
		"machine":
			play("die_machine", pos + Vector2(0, -8), {"k": k})
			decal("dc_scrap", pos + Vector2(0, 10))
			if big:
				play("ex_small", pos + Vector2(0, -12))
		"raider":
			play("die_raider", pos + Vector2(0, -4))
			decal("dc_splat_blood", pos + Vector2(0, 10))
		_:
			play("die_plague", pos + Vector2(0, -8))
			decal("dc_splat_plague", pos + Vector2(0, 10))
			if big:
				play("ex_plague", pos + Vector2(0, -10))


## --- decals ----------------------------------------------------------------

## Flat ground decal that lingers `life` s, then fades out in 4 alpha steps.
func decal(id: String, pos: Vector2, life: float = 5.0) -> void:
	if _ensure_layer() == null or not _man.has(id):
		return
	var e: Dictionary
	var s: AnimatedSprite2D
	if _decals.size() >= DECAL_CAP and is_instance_valid(_decals[0]["s"]):
		e = _decals.pop_front()
		s = e["s"]
	else:
		s = AnimatedSprite2D.new()
		_layer.add_child(s)
		e = {"s": s}
	if not dress(s, id, randf() < 0.5, false):
		return
	s.global_position = pos
	s.z_index = -4
	s.visible = true
	e["t"] = 0.0
	e["life"] = life
	_decals.append(e)


func _tick_decals(delta: float) -> void:
	for i in range(_decals.size() - 1, -1, -1):
		var e: Dictionary = _decals[i]
		if not is_instance_valid(e["s"]):
			_decals.remove_at(i)
			continue
		var s: AnimatedSprite2D = e["s"]
		e["t"] = float(e["t"]) + delta
		var left := float(e["life"]) - float(e["t"])
		if left <= 0.0:
			s.queue_free()
			_decals.remove_at(i)
			continue
		## Last 1.2 s: four hard alpha steps (no smooth fade).
		var step := clampi(int((1.2 - left) / 0.3), 0, 3) if left < 1.2 else 0
		s.modulate.a = ALPHA_STEPS[step]


## --- loops attached to a node (status, sparkles, beams) ---------------------

## A looping strip as a child of `parent` (follows it, frees with it).
func loop_on(parent: Node, id: String, local_pos: Vector2 = Vector2.ZERO, name_: String = "") -> AnimatedSprite2D:
	if parent == null or not _man.has(id):
		return null
	var s := AnimatedSprite2D.new()
	if name_ != "":
		s.name = name_
	if not dress(s, id):
		return null
	s.z_as_relative = true
	s.position = local_pos
	parent.add_child(s)
	s.play("default")
	return s


## Status overlay above a unit: shows the top status of `ids` (burn > poison >
## stun > slow), hides when none. One child sprite per unit, swapped in place.
const STATUS_FX := {"burn": "st_burn", "poison": "st_poison", "stun": "st_stun", "slow": "st_slow"}
const STATUS_PRIO := ["stun", "burn", "poison", "slow"]


func status(unit: Node2D, ids: Dictionary, head_y: float) -> void:
	if unit == null:
		return
	var want := ""
	for id in STATUS_PRIO:
		if ids.has(id):
			want = STATUS_FX[id]
			break
	var cur: AnimatedSprite2D = unit.get_node_or_null("PxStatus")
	if want == "":
		if cur:
			cur.visible = false
		return
	if cur == null:
		cur = loop_on(unit, want, Vector2(0, head_y), "PxStatus")
		if cur == null:
			return
		cur.z_index = 4
	elif not cur.visible or str(cur.get_meta("fx", "")) != want:
		dress(cur, want)
		cur.z_as_relative = true
		cur.z_index = 4
		cur.position = Vector2(0, head_y)
		cur.visible = true
		cur.play("default")
	cur.set_meta("fx", want)
