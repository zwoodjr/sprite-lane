extends Node

## Shared touch scrolling for every ScrollContainer in the game (hooked on
## node_added by UiTheme, so new screens get it for free).
##
## - A drag that starts on a button / row still scrolls: past the dead zone the
##   gesture is taken over, the row's press is cancelled (it never fires), and
##   the rest of the drag drives the scroll. A tap (no movement) still fires.
## - The axis is picked from the first movement: a sideways swipe never steals
##   a vertical list, and the nearest ancestor that scrolls that way wins
##   (a hero strip inside a page scrolls sideways, the page up/down).
## - Release keeps the momentum (iOS-like glide), clamped at the ends.
## - A list rebuilt right after a tap inside it (BUY, LOCK, EQUIP...) keeps its
##   scroll position instead of jumping to the top.
## - Vertical lists get bottom padding so the last row clears the home
##   indicator / Xogot toolbar.
## Built-in ScrollContainer drag is disabled (huge dead zone) so the two never
## fight; mouse wheel / trackpad still go to the container.

const DEADZONE := 12.0
## Momentum decay per second (exp) and the stop / cap speeds (px / s).
const FRICTION := 3.2
const MIN_SPEED := 18.0
const MAX_SPEED := 6500.0
const KEEP_AFTER_TAP_MS := 1200
const PAD_NAME := "_TouchScrollPad"

var _down: bool = false
var _start: Vector2 = Vector2.ZERO
var _sc: ScrollContainer = null
var _axis: int = 1
var _samples: Array = []
var _glide: Dictionary = {}
var _tap_at: Dictionary = {}
var _keep: Dictionary = {}
## Last time a drag was taken over (tests read this).
var drags_taken: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is ScrollContainer:
		_setup.call_deferred(n)


func _setup(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc) or sc.has_meta("touch_scroll"):
		return
	sc.set_meta("touch_scroll", true)
	sc.scroll_deadzone = 100000
	sc.child_entered_tree.connect(func(_c: Node) -> void: _content_changed.call_deferred(sc))
	sc.child_exiting_tree.connect(func(_c: Node) -> void: _rebuild_started(sc))
	sc.resized.connect(func() -> void: _pad.call_deferred(sc))
	_hook_content(sc)
	_pad(sc)


func _content(sc: ScrollContainer) -> Control:
	for c in sc.get_children():
		if c is Control and not (c is ScrollBar):
			return c as Control
	return null


func _hook_content(sc: ScrollContainer) -> void:
	var c := _content(sc)
	if c == null or c.has_meta("touch_scroll_content"):
		return
	c.set_meta("touch_scroll_content", true)
	c.child_exiting_tree.connect(func(ch: Node) -> void:
		if ch.name != PAD_NAME:
			_rebuild_started(sc))
	c.child_entered_tree.connect(func(ch: Node) -> void:
		if ch.name != PAD_NAME:
			_content_changed.call_deferred(sc))


func _content_changed(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc):
		return
	_hook_content(sc)
	_pad(sc)


## --- Bottom padding (vertical lists only) ------------------------------------

func _pad(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc) or not sc.is_inside_tree():
		return
	if sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return
	var c := _content(sc)
	if not (c is VBoxContainer):
		return
	var pad := c.get_node_or_null(PAD_NAME) as Control
	if pad == null:
		pad = Control.new()
		pad.name = PAD_NAME
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(pad)
	if pad.get_index() != c.get_child_count() - 1:
		c.move_child(pad, -1)
	## Room for whatever covers the bottom of this list (home bar, toolbar).
	var safe := MobileLayout.control_safe_margin()
	var vis_bottom := safe.position.y + safe.size.y
	var sc_bottom := sc.get_global_rect().end.y
	pad.custom_minimum_size.y = maxf(16.0, sc_bottom - vis_bottom + 24.0)


## --- Keep the scroll position across a rebuild ---------------------------------

func _rebuild_started(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc) or _keep.has(sc):
		return
	var t := int(_tap_at.get(sc, -100000))
	if Time.get_ticks_msec() - t > KEEP_AFTER_TAP_MS:
		return
	_keep[sc] = {"v": sc.scroll_vertical, "h": sc.scroll_horizontal, "frames": 3}


## --- Gesture ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.has_meta("touch_scroll_synthetic"):
		return
	## Real touch also arrives as emulated mouse: drive everything from mouse
	## events, but swallow the raw touch stream while we own a drag.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _sc != null:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			_start = mb.position
			_samples = [[Time.get_ticks_usec(), mb.position]]
			_sc = null
			## A finger on a gliding list stops it (and doesn't tap through).
			var hit := _scroll_at(mb.position)
			if hit != null and _glide.has(hit):
				var fast := absf(float(_glide[hit])) > 300.0
				_glide.erase(hit)
				if fast:
					get_viewport().set_input_as_handled()
					_down = false
			return
		## Release.
		if _sc != null:
			_start_glide()
			_sc = null
			_down = false
			get_viewport().set_input_as_handled()
			return
		if _down:
			## A tap inside a list: a rebuild right after it keeps its place.
			var tsc := _scroll_at(mb.position)
			if tsc != null:
				_tap_at[tsc] = Time.get_ticks_msec()
		_down = false
		return
	if event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_down = false
			return
		_samples.append([Time.get_ticks_usec(), mm.position])
		while _samples.size() > 6:
			_samples.pop_front()
		if _sc == null:
			var d := mm.position - _start
			if d.length() < DEADZONE:
				return
			var axis := 1 if absf(d.y) >= absf(d.x) else 0
			var sc := _claim(mm.position, axis)
			if sc == null:
				## Nothing scrolls this way here: leave the gesture to sliders /
				## text fields, but a button that moved under the finger is no tap.
				_down = false
				var hv := get_viewport().gui_get_hovered_control()
				if hv is BaseButton:
					_cancel_press(mm.position)
				return
			_sc = sc
			_axis = axis
			drags_taken += 1
			_glide.erase(sc)
			_cancel_press(mm.position)
			## Apply the dead-zone travel too, so the list follows the finger.
			_move(sc, -(d.y if axis == 1 else d.x))
		else:
			_move(_sc, -(mm.relative.y if _axis == 1 else mm.relative.x))
		get_viewport().set_input_as_handled()


func _move(sc: ScrollContainer, amount: float) -> void:
	if not is_instance_valid(sc):
		return
	if _axis == 1:
		sc.scroll_vertical = int(round(float(sc.scroll_vertical) + amount))
	else:
		sc.scroll_horizontal = int(round(float(sc.scroll_horizontal) + amount))


## Nearest scroll container under the finger that can move along `axis`.
func _claim(pos: Vector2, axis: int) -> ScrollContainer:
	var cands: Array = []
	for sc in _all():
		var s2 := sc as ScrollContainer
		if s2.get_global_rect().has_point(pos) and _can_scroll(s2, axis):
			cands.append(s2)
	if cands.is_empty():
		return null
	## The control under the finger decides when it sits inside a candidate
	## (nearest ancestor wins: inner strip before outer page).
	var n: Node = get_viewport().gui_get_hovered_control()
	if n != null and (n as Control).get_global_rect().has_point(pos):
		while n != null:
			if n in cands:
				return n as ScrollContainer
			n = n.get_parent()
	## Otherwise the topmost: highest canvas layer, then last drawn.
	var best: ScrollContainer = null
	var best_layer := -100000
	for c in cands:
		var cl := (c as CanvasItem).get_canvas_layer_node()
		var lv := cl.layer if cl != null else 0
		if lv >= best_layer:
			best_layer = lv
			best = c
	return best


func _can_scroll(sc: ScrollContainer, axis: int) -> bool:
	if not sc.is_visible_in_tree():
		return false
	var c := _content(sc)
	if c == null:
		return false
	if axis == 1:
		return sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and c.size.y > sc.size.y + 1.0
	return sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and c.size.x > sc.size.x + 1.0


## Topmost visible scroll container whose rect holds `pos` (fallback hit test).
func _scroll_at(pos: Vector2) -> ScrollContainer:
	var hov := get_viewport().gui_get_hovered_control()
	var n: Node = hov
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	var best: ScrollContainer = null
	for sc in _all():
		if sc.is_visible_in_tree() and sc.get_global_rect().has_point(pos):
			best = sc
	return best


func _all() -> Array:
	var out: Array = []
	_collect(get_tree().root, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is ScrollContainer:
			out.append(c)
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		_collect(c, out)


## The row under the finger saw a press: move "the mouse" off it and release
## there, so it un-presses without firing.
func _cancel_press(_at: Vector2) -> void:
	var far := Vector2(-10000, -10000)
	var mv := InputEventMouseMotion.new()
	mv.position = far
	mv.global_position = far
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	mv.set_meta("touch_scroll_synthetic", true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = far
	up.global_position = far
	up.set_meta("touch_scroll_synthetic", true)
	var vp := get_viewport()
	vp.push_input.call_deferred(mv, true)
	vp.push_input.call_deferred(up, true)


func _start_glide() -> void:
	if _samples.size() < 2 or not is_instance_valid(_sc):
		return
	var a: Array = _samples[0]
	var b: Array = _samples[_samples.size() - 1]
	var dt := float(int(b[0]) - int(a[0])) / 1000000.0
	## Finger held still before lifting: no fling.
	if dt <= 0.0 or Time.get_ticks_usec() - int(b[0]) > 90000:
		return
	dt = maxf(dt, 0.008)
	var dv: Vector2 = (b[1] as Vector2) - (a[1] as Vector2)
	var v := -(dv.y if _axis == 1 else dv.x) / dt
	v = clampf(v, -MAX_SPEED, MAX_SPEED)
	if absf(v) > MIN_SPEED * 4.0:
		_glide[_sc] = v
		_sc.set_meta("touch_scroll_axis", _axis)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	for sc in _glide.keys():
		if not is_instance_valid(sc) or not (sc as ScrollContainer).is_visible_in_tree():
			_glide.erase(sc)
			continue
		var v := float(_glide[sc])
		var s := sc as ScrollContainer
		var ax := int(s.get_meta("touch_scroll_axis", 1))
		var before := s.scroll_vertical if ax == 1 else s.scroll_horizontal
		if ax == 1:
			s.scroll_vertical = int(round(float(s.scroll_vertical) + v * dt))
		else:
			s.scroll_horizontal = int(round(float(s.scroll_horizontal) + v * dt))
		var after := s.scroll_vertical if ax == 1 else s.scroll_horizontal
		v *= exp(-FRICTION * dt)
		## Hit an end (or stopped): done.
		if absf(v) < MIN_SPEED or (after == before and absf(v * dt) >= 1.0):
			_glide.erase(sc)
		else:
			_glide[sc] = v
	for sc in _keep.keys():
		if not is_instance_valid(sc):
			_keep.erase(sc)
			continue
		var k: Dictionary = _keep[sc]
		(sc as ScrollContainer).scroll_vertical = int(k["v"])
		(sc as ScrollContainer).scroll_horizontal = int(k["h"])
		k["frames"] = int(k["frames"]) - 1
		if int(k["frames"]) <= 0:
			_keep.erase(sc)
