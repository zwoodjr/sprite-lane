extends Node2D

## Art QA sheet: poses every hero / pet / mob from its strips through UnitAnim
## at in-game world scale and marks the anchors the code uses:
##   green line = feet (unit origin + feet_y), red dot = weapon tip / attack
##   origin of the shown frame, blue ring = body radius, cyan = facing flip.
## Usage (needs a display / xvfb):
##   godot --path game --rendering-method gl_compatibility \
##     res://tools/anim_gallery.tscn -- /tmp/out.png [heroes|mobs|pets]

var _out := "/tmp/anim_gallery.png"
var _set := "heroes"
var _marks: Array = [] ## [pos, color, radius, kind]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	if a.size() > 1:
		_set = a[1]
	RenderingServer.set_default_clear_color(Color(0.42, 0.33, 0.24))
	var cam := Camera2D.new()
	add_child(cam)
	match _set:
		"mobs":
			_build_mobs(cam)
		"pets":
			_build_pets(cam)
		_:
			_build_heroes(cam)
	queue_redraw()
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("GALLERY_SAVED ", _out)
	get_tree().quit()


func _unit(prefix: String, world_px: float, feet: float, at: Vector2, state: String, frame: int, left: bool) -> UnitAnim:
	var spr := Sprite2D.new()
	spr.position = at
	var holder := Node2D.new()
	holder.position = at
	add_child(holder)
	holder.add_child(spr)
	spr.position = Vector2.ZERO
	var an := UnitAnim.new()
	an.setup(spr, prefix, world_px, feet)
	an.set_facing(left)
	an.play(state)
	an.tick(0.0)
	## Jump straight to the frame (play() shows frame 0).
	an._show(clampi(frame, 0, an.frame_count(state) - 1), false)
	_marks.append([at + Vector2(0, feet), Color(0.2, 1.0, 0.3), 14.0, "feet"])
	return an


func _build_heroes(cam: Camera2D) -> void:
	cam.zoom = Vector2(3.2, 3.2)
	var ids := ["ash_rook", "vesper_thorn", "pebble", "bolt_juno", "sister_cinder", "quill_marrow", "nyx_caldera", "helm_wisp"]
	for i in range(ids.size()):
		var id: String = ids[i]
		var prefix := "res://assets/sprites/characters/%s/%s" % [id, id]
		var js := UnitAnim.load_json(prefix + "_weapon.json")
		var hf: int = int(((js.get("hit_frames", {}) as Dictionary).get("attack", [0]) as Array)[0])
		for side in range(2):
			var left := side == 1
			var pos := Vector2(-105 + (i % 4) * 70, -90 + ((i / 4) + side * 2) * 64)
			var an := _unit(prefix, 56.0, 20.0, pos, "attack", hf, left)
			var st: Array = (js.get("states", {}) as Dictionary).get("attack", [])
			if not st.is_empty():
				var e: Dictionary = st[hf]
				var tip: Array = e["tip"]
				_marks.append([pos + an.frame_to_local(Vector2(tip[0], tip[1])), Color(1, 0.1, 0.1), 1.6, "dot"])
				var d := an.angle_to_dir(float(e.get("angle", 0.0)))
				_marks.append([pos + an.frame_to_local(Vector2(tip[0], tip[1])), Color(1, 0.9, 0.1), 8.0, "ray", d])
			_marks.append([pos, Color(0.3, 0.6, 1.0), 14.0, "ring"])


func _build_mobs(cam: Camera2D) -> void:
	cam.zoom = Vector2(1.45, 1.45)
	var i := 0
	for k in EnemyDefs.all_kinds():
		var prefix := str(k["anim"])
		var st := UnitAnim.load_states(prefix)
		var fs := (st["idle"]["tex"] as Texture2D).get_height()
		var bs := clampf(float(k["scale"]), 0.85, 1.4)
		if fs >= 256:
			bs = 2.05
		elif fs >= 192:
			bs = 1.5
		var pos := Vector2(-200 + (i % 6) * 80, -300 + (i / 6) * 120)
		var js := UnitAnim.load_json(prefix + "_attack.json")
		var hf: int = int((js.get("hit_frames", [1]) as Array)[0])
		var an := _unit(prefix, 64.0 * bs, 16.0 * bs, pos, "attack", hf, i % 2 == 1)
		var org: Array = js.get("origin", [])
		if not org.is_empty():
			var o: Array = org[mini(hf, org.size() - 1)]
			_marks.append([pos + an.frame_to_local(Vector2(o[0], o[1])), Color(1, 0.1, 0.1), 2.5, "dot"])
		_marks.append([pos, Color(0.3, 0.6, 1.0), 16.0 * bs, "ring"])
		i += 1
	## Player-size reference
	_unit("res://assets/sprites/characters/ash_rook/ash_rook", 56.0, 20.0, Vector2(-200 + 5 * 80, -300 + 4 * 120), "idle", 0, false)


func _build_pets(cam: Camera2D) -> void:
	cam.zoom = Vector2(3.0, 3.0)
	var rows := [["noel", ["idle", "walk", "sit", "attack", "rampage"]], ["bentley", ["idle", "walk", "sit", "bark", "drop"]], ["lillie", ["idle", "walk", "attack", "charge", "impact"]]]
	for r in range(rows.size()):
		var id: String = rows[r][0]
		var sts: Array = rows[r][1]
		for c in range(sts.size()):
			var pos := Vector2(-100 + c * 48, -50 + r * 50)
			_unit("res://assets/sprites/pets/%s/%s" % [id, id], 58.0, 12.0, pos, sts[c], 1, c % 2 == 1)
	_unit("res://assets/sprites/characters/sister_cinder/sister_cinder", 56.0, 20.0, Vector2(140, 0), "idle", 0, true)


func _draw() -> void:
	for m in _marks:
		var p: Vector2 = m[0]
		match str(m[3]):
			"feet":
				draw_line(p - Vector2(m[2], 0), p + Vector2(m[2], 0), m[1], 0.6)
			"dot":
				draw_circle(p, m[2], m[1])
			"ring":
				draw_arc(p, m[2], 0, TAU, 24, m[1], 0.5)
			"ray":
				draw_line(p, p + (m[4] as Vector2) * m[2], m[1], 0.5)
