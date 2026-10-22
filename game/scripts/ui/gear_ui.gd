class_name GearUi
extends RefCounted

## Shared gear widgets (Gear screen, Hangar stash, prep, results):
##   tile()          item well: rarity frame (colour + rim thickness + tint +
##                   corner gem), the item's own icon, set badge, NEW, lock,
##                   worn-by marker, shimmer on Epic / Legendary
##   rarity_line()   rarity tab (INK on rarity colour) + set chip
##   compare_box()   stat deltas vs the equipped piece + set progress
##   set_overview()  a set's pieces (owned / missing) and its bonuses
##   overlay()       dimmed modal card (returns its VBox; meta "root")

const PORTRAIT := "res://assets/sprites/portraits/%s.png"
## Shimmer: one diagonal band of 4-step alpha sweeping the well (pixel-snapped
## to the 2-px UI texel); Legendary adds a 2-frame rim pulse. Cheap: one
## shared material per rarity, drawn only on Epic / Legendary tiles.
const SHIMMER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float speed = 0.3;
uniform float rim = 0.0;
uniform float texels = 28.0;
void fragment() {
	vec2 uv = floor(UV * texels) / texels;
	float ph = (uv.x + (1.0 - uv.y)) * 0.5;
	float s = fract(TIME * speed) * 2.2 - 0.6;
	float d = abs(ph - s);
	float a = d < 0.035 ? 0.5 : (d < 0.08 ? 0.25 : 0.0);
	float e = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	if (rim > 0.5 && e < 0.12 && e > 0.07 && fract(TIME * 0.9) < 0.5) {
		a = max(a, 0.25);
	}
	COLOR = vec4(tint.rgb, a);
}
"""

static var _mats: Dictionary = {}


static func shimmer_mat(rarity: String) -> ShaderMaterial:
	if _mats.has(rarity):
		return _mats[rarity]
	var sh := Shader.new()
	sh.code = SHIMMER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", Color("fff2c0") if rarity == "legendary" else Color("e9dfc9"))
	m.set_shader_parameter("speed", 0.34 if rarity == "legendary" else 0.22)
	m.set_shader_parameter("rim", 1.0 if rarity == "legendary" else 0.0)
	_mats[rarity] = m
	return m


static func rar(it: Dictionary) -> String:
	return str(it.get("rarity", "common"))


static func color(it: Dictionary) -> Color:
	return IconSet.rarity_color(rar(it))


static func hero_name(h: String) -> String:
	return str(CharacterDefs.get_character(h).get("display_name", h))


## The item well. opts: "worn" (show who wears it, default true), "new"
## (default true), "dim" (empty / unavailable), "shimmer" (default true).
static func tile(it: Dictionary, px: int = 112, opts: Dictionary = {}) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r := rar(it) if not it.is_empty() else "common"
	var well := UiTheme.icon_well(IconSet.item(it) if not it.is_empty() else str(opts.get("icon", "")), r, px)
	well.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(well)
	if it.is_empty():
		well.modulate = Color(1, 1, 1, float(opts.get("empty_alpha", 0.45)))
		return root
	if bool(opts.get("dim", false)):
		well.modulate = Color(0.55, 0.55, 0.55)
	if r in ["epic", "legendary"] and bool(opts.get("shimmer", true)):
		var sh := ColorRect.new()
		sh.material = shimmer_mat(r)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(sh)
	var big := px >= 96
	var sid := str(it.get("set", ""))
	if sid != "":
		var b := set_badge(sid, 32 if big else 24)
		b.position = Vector2(px - b.custom_minimum_size.x - 4, px - b.custom_minimum_size.y - 4)
		root.add_child(b)
	var top_y := 6.0
	if bool(opts.get("new", true)) and bool(it.get("new", false)):
		var nb := _tag("NEW", UiTheme.AMBER)
		nb.name = "NewBadge"
		root.add_child(nb)
		nb.position = Vector2(px - 48, top_y - 2)
		top_y += 26.0
	if bool(it.get("locked", false)):
		var lk := IconSet.rect("ui_lock", 24)
		lk.position = Vector2(px - 30, top_y)
		lk.name = "LockBadge"
		root.add_child(lk)
	if bool(opts.get("worn", true)):
		var by := GameState.equipped_by(int(it.get("uid", -1)))
		if not by.is_empty():
			var wm := worn_marker(str(by[0]), 32 if big else 24)
			wm.position = Vector2(4, px - wm.custom_minimum_size.y - 4)
			root.add_child(wm)
	return root


## Small INK-edged plate with pixel-font text (NEW / E).
static func _tag(t: String, fill: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.head_label(t, UiTheme.T_SMALL, UiTheme.INK)
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


## Set emblem on its set-coloured plate.
static func set_badge(sid: String, px: int = 32) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = GearDefs.set_color(sid)
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var ic := IconSet.rect(IconSet.emblem(sid), 24 if px < 64 else 48)
	ic.position = Vector2((px - ic.custom_minimum_size.x) * 0.5, (px - ic.custom_minimum_size.y) * 0.5)
	p.add_child(ic)
	p.tooltip_text = GearDefs.set_title(sid)
	return p


## Who wears it: their portrait in a teal-edged square.
static func worn_marker(hero: String, px: int = 32) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.INK
	sb.border_color = UiTheme.TEAL
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var tr := TextureRect.new()
	if ResourceLoader.exists(PORTRAIT % hero):
		tr.texture = load(PORTRAIT % hero)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = Vector2(2, 2)
	tr.size = Vector2(px - 4, px - 4)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	return p


## Rarity tab (+ set chip). The word itself is the colour-blind cue; the
## frame's corner gem repeats it as a shape.
static func rarity_line(it: Dictionary, big: bool = false) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab := UiTheme.rarity_tab(str(GearDefs.RARITY_NAME.get(rar(it), rar(it))), rar(it))
	if big:
		(tab.get_child(0) as Label).add_theme_font_size_override("font_size", UiTheme.T_H2)
	h.add_child(tab)
	var sid := str(it.get("set", ""))
	if sid != "":
		h.add_child(UiTheme.chip(GearDefs.set_title(sid), UiTheme.TEXT, GearDefs.set_color(sid)))
	return h


## Stat delta lines vs the piece it would replace: [[text, good]].
static func compare_lines(it: Dictionary, cur: Dictionary) -> Array:
	var out: Array = []
	var kind := str(it.get("kind", ""))
	if kind in ["armor", "accessory"]:
		var a: Dictionary = it.get("stats", {})
		var b: Dictionary = cur.get("stats", {}) if not _inert(cur) else {}
		if _inert(it):
			a = {}
		for s in GearDefs.STAT_LABEL.keys():
			var d := float(a.get(s, 0.0)) - float(b.get(s, 0.0))
			if absf(d) < 0.0005:
				continue
			var ln := str(GearDefs.stat_lines({"stats": {s: absf(d)}})[0])
			if d < 0.0:
				ln = ("-" + ln.substr(1)) if ln.begins_with("+") else (("+" + ln.substr(1)) if ln.begins_with("-") else ln)
			out.append([ln, d > 0.0])
		return out
	var mine := GearDefs.stat_lines(it)
	var theirs := GearDefs.stat_lines(cur) if not cur.is_empty() else PackedStringArray()
	for ln in mine:
		if not str(ln).begins_with("Set:") and not ln in theirs:
			out.append([str(ln), true])
	for ln in theirs:
		if not str(ln).begins_with("Set:") and not ln in mine:
			out.append(["Lose: " + str(ln), false])
	return out


static func _inert(it: Dictionary) -> bool:
	return bool(it.get("needs_heart", false)) and not bool(it.get("charged", false))


## "VS <equipped>" card: deltas (teal up / red down) and set progress.
static func compare_box(it: Dictionary, hero: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sl := GameState.slot_for(int(it.get("uid", -1)), hero)
	if sl == "" and str(it.get("kind", "")) in ["armor", "accessory"]:
		sl = str(it.get("slot", ""))
	var cur: Dictionary = GameState.equipped_items(hero).get(sl, {}) if sl != "" else {}
	var same := int(cur.get("uid", -2)) == int(it.get("uid", -1))
	var head := "WORN BY %s" % hero_name(hero).to_upper() if same else ("VS %s" % str(cur.get("name", "")).to_upper() if not cur.is_empty() else "EMPTY SLOT ON %s" % hero_name(hero).to_upper())
	if sl == "":
		head = "%s CAN'T USE THIS" % hero_name(hero).to_upper()
	var hl := UiTheme.head_label(head, UiTheme.T_H3, UiTheme.TEXT_DIM)
	hl.clip_text = true
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(hl)
	if sl == "":
		return v
	if not same:
		var lines := compare_lines(it, cur)
		if lines.is_empty():
			v.add_child(UiTheme.body_label("Same stats", UiTheme.T_SMALL, UiTheme.TEXT_DIM))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8)
		fl.add_theme_constant_override("v_separation", 8)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ln in lines:
			fl.add_child(UiTheme.chip(("▲ " if bool(ln[1]) else "▼ ") + str(ln[0]), UiTheme.TEAL if bool(ln[1]) else UiTheme.DANGER))
		v.add_child(fl)
	for sp in GameState.set_progress(hero, it):
		var up := int(sp["after"]) >= int(sp["now"])
		var t := "%s  %d/%d → %d/%d" % [GearDefs.set_title(str(sp["set"])), int(sp["now"]), int(sp["total"]), int(sp["after"]), int(sp["total"])]
		if same:
			t = "%s  %d/%d" % [GearDefs.set_title(str(sp["set"])), int(sp["now"]), int(sp["total"])]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(set_badge(str(sp["set"]), 32))
		var l := UiTheme.head_label(t, UiTheme.T_H3, UiTheme.TEAL if up else UiTheme.DANGER)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		v.add_child(row)
		var nxt := next_bonus(str(sp["set"]), int(sp["after"]))
		if nxt != "":
			v.add_child(UiTheme.body_label(nxt, UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	return v


## "Next: (4) Shorter dash cooldown" for a set at n pieces ("" when maxed).
static func next_bonus(sid: String, n: int) -> String:
	var th: Array = GearDefs.set_thresholds(sid)
	var bo: Array = GearDefs.set_bonuses(sid)
	for i in range(th.size()):
		if n < int(th[i]):
			return "Next at %d: %s" % [int(th[i]), str(bo[i])]
	return ""


## A set's pieces (owned / missing) and its bonuses for `hero`.
static func set_overview(sid: String, hero: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	top.add_child(set_badge(sid, 64))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var title := UiTheme.title_label(GearDefs.set_title(sid), UiTheme.T_TITLE, UiTheme.AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(title)
	var worn := int(GameState.worn_set_counts(hero).get(sid, 0))
	var sh := GearDefs.set_hero(sid)
	var sub := "%s wears %d/%d" % [hero_name(hero), worn, GearDefs.set_total(sid)]
	if sh != "":
		sub += "  ·  %s only" % hero_name(sh)
	tv.add_child(UiTheme.body_label(sub, UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	## Pieces: the best owned piece per slot, or the empty slot.
	var grid := GridContainer.new()
	grid.columns = 6 if GearDefs.set_total(sid) > 3 else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var eq := GameState.equipped_items(hero)
	var owned_n := 0
	for sl in GearDefs.set_slots(sid):
		var best: Dictionary = {}
		var e: Dictionary = eq.get(str(sl), {})
		if str(e.get("set", "")) == sid:
			best = e
		else:
			for it in GameState.stash:
				if str(it.get("set", "")) == sid and str(it.get("slot", "")) == str(sl):
					if best.is_empty() or GearDefs.RARITIES.find(rar(it)) > GearDefs.RARITIES.find(rar(best)):
						best = it
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tpx := 96 if grid.columns == 6 else 112
		if best.is_empty():
			cell.add_child(tile({}, tpx, {"icon": IconSet.slot(str(sl)), "empty_alpha": 0.35}))
		else:
			owned_n += 1
			cell.add_child(tile(best, tpx, {"new": false}))
		var cap := UiTheme.head_label(str(GearDefs.SLOT_NAME.get(str(sl), sl)).to_upper() if not best.is_empty() else "MISSING", UiTheme.T_SMALL, UiTheme.TEXT if not best.is_empty() else UiTheme.TEXT_DIM)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(cap)
		grid.add_child(cell)
	v.add_child(UiTheme.body_label("Owned %d/%d pieces" % [owned_n, GearDefs.set_total(sid)], UiTheme.T_SMALL, UiTheme.TEXT_DIM))
	var th: Array = GearDefs.set_thresholds(sid)
	var bo: Array = GearDefs.set_bonuses(sid)
	for i in range(th.size()):
		var on := worn >= int(th[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var pip := UiTheme.pixel_label("%d" % int(th[i]), UiTheme.PX_M, UiTheme.INK)
		var pp := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.TEAL if on else Color("3a3436")
		sb.border_color = UiTheme.INK
		sb.set_border_width_all(2)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		pp.add_theme_stylebox_override("panel", sb)
		if not on:
			pip.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		pp.add_child(pip)
		pp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pp)
		var bl := UiTheme.body_label(str(bo[i]), UiTheme.T_BODY, UiTheme.TEXT if on else UiTheme.TEXT_DIM)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bl)
		v.add_child(row)
	return v


## Dimmed modal with a riveted card. Returns the card's VBox; its "root" meta
## is the node to free.
static func overlay(host: Control, accent: Color = UiTheme.AMBER) -> VBoxContainer:
	var root := Control.new()
	root.name = "GearPopup"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.plate("panel_hi" if accent == UiTheme.AMBER else "panel_steel", 24.0))
	p.custom_minimum_size = Vector2(minf(672.0, host.get_viewport_rect().size.x - 48.0), 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	v.set_meta("root", root)
	## Pop in: a quick scale from 96%.
	p.pivot_offset = Vector2(p.custom_minimum_size.x * 0.5, 200)
	p.scale = Vector2(0.96, 0.96)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return v


## Hold-to-confirm button: fills over `hold` seconds while pressed, then
## calls cb. Letting go early cancels.
static func hold_button(text: String, accent: Color, hold: float, cb: Callable) -> Button:
	var b := UiTheme.big_button(text, accent, 80, 24)
	var fill := ColorRect.new()
	fill.color = Color(1, 0.95, 0.8, 0.35)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2.ZERO
	fill.size = Vector2(0, 80)
	fill.name = "HoldFill"
	b.add_child(fill)
	var st := {"tw": null}
	b.button_down.connect(func() -> void:
		fill.size = Vector2(0, b.size.y)
		var tw := b.create_tween()
		st["tw"] = tw
		tw.tween_property(fill, "size:x", b.size.x, hold)
		tw.tween_callback(func() -> void:
			st["tw"] = null
			cb.call()))
	b.button_up.connect(func() -> void:
		var tw: Tween = st["tw"]
		if tw != null and tw.is_valid():
			tw.kill()
		st["tw"] = null
		fill.size.x = 0.0)
	return b
