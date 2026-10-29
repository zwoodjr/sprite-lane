extends RefCounted

## Tester feedback: screenshot + context block + note, shared from the device.
## Nothing is ever sent to a server: on the web the browser share sheet (or a
## download + clipboard) hands it to the tester; native builds save it under
## user://feedback and copy the text to the clipboard.
##
##   Feedback.open(self)              -- from any menu / screen
##   Feedback.open(self, pause_layer) -- hides that layer for the screenshot

const BuildInfo = preload("res://scripts/build_info.gd")
const SHEET_PATH := "res://scripts/ui/feedback_sheet.gd"
const CATEGORIES: Array[String] = ["BUG", "BALANCE", "LOOKS", "IDEA", "OTHER"]
const LOG_LINES := 20
const SAVE_DIR := "user://feedback"

static var _layer: CanvasLayer = null
static var _opening: bool = false


static func is_open() -> bool:
	return _opening or (_layer != null and is_instance_valid(_layer))


## Pause, grab the frame (with `hide` hidden), then show the sheet on top.
## `on_closed` runs after the sheet is gone and the pause is restored.
static func open(from: Node, hide: Node = null, on_closed: Callable = Callable()) -> void:
	if is_open() or from == null or not from.is_inside_tree():
		return
	_opening = true
	var tree := from.get_tree()
	var was_paused := tree.paused
	tree.paused = true
	TouchInput.clear_sticks()
	var hidden_was := false
	if hide != null and is_instance_valid(hide):
		hidden_was = bool(hide.get("visible"))
		hide.set("visible", false)
	var shot: Image = await capture(tree)
	var ctx := build_context(tree)
	_opening = false
	var layer := CanvasLayer.new()
	layer.name = "FeedbackLayer"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var sheet: Control = Control.new()
	sheet.set_script(load(SHEET_PATH))
	sheet.name = "FeedbackSheet"
	sheet.set("shot", shot)
	sheet.set("ctx", ctx)
	sheet.set("on_close", func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		_layer = null
		if hide != null and is_instance_valid(hide):
			hide.set("visible", hidden_was)
		if is_instance_valid(tree.root):
			tree.paused = was_paused
		TouchInput.clear_sticks()
		if on_closed.is_valid():
			on_closed.call())
	layer.add_child(sheet)
	_layer = layer
	tree.root.add_child(layer)


## Current frame as an Image (null when there is no real renderer).
static func capture(tree: SceneTree) -> Image:
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
		return null
	await RenderingServer.frame_post_draw
	var tex := tree.root.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	return img


## Everything the owner needs to place a report.
static func build_context(tree: SceneTree) -> Dictionary:
	var c := {}
	c["build"] = "v" + BuildInfo.VERSION + " " + BuildInfo.COMMIT + ((" (built %s)" % BuildInfo.BUILT) if BuildInfo.BUILT != "" else "")
	c["time"] = Time.get_datetime_string_from_system(false, true) + "  (UTC " + Time.get_datetime_string_from_system(true, true) + ")"
	var plat := OS.get_name()
	var model := OS.get_model_name()
	if model != "" and model != "GenericDevice":
		plat += " " + model
	if OS.has_feature("web"):
		var ua: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
		if ua != null:
			plat += " | " + str(ua)
	elif OS.has_feature("mobile"):
		plat += " " + OS.get_version()
	c["platform"] = plat
	var vp := tree.root.get_visible_rect().size
	var win := DisplayServer.window_get_size()
	c["screen"] = "%dx%d view, %dx%d window, scale %.2f" % [int(vp.x), int(vp.y), win.x, win.y, DisplayServer.screen_get_scale()]
	var scene := tree.current_scene
	c["scene"] = str(scene.name) if scene != null else "?"
	## Mode / tier / level.
	var m: Dictionary = GameState.get_mode()
	c["mode"] = ("CAMPAIGN" if GameState.in_campaign_run() else str(GameState.play_mode).to_upper()) + " / " + str(m.get("display_name", GameState.selected_mode_id))
	var tier := int(m.get("tier", 0))
	c["tier"] = tier
	if GameState.in_campaign_run() or GameState.campaign_level_id != "":
		c["level"] = "campaign " + str(GameState.campaign_level_id)
	else:
		c["level"] = str(ZoneDefs.zone(tier).get("name", "")) if tier > 0 else "-"
	c["hero"] = "%s (%s)" % [str(GameState.get_character().get("display_name", "")), GameState.selected_character_id]
	c["pet"] = "%s (%s)" % [str(PetDefs.get_pet(GameState.selected_pet_id).get("name", "")), GameState.selected_pet_id]
	var lo := PackedStringArray()
	var eq: Dictionary = GameState.equipped_items()
	for sl in eq.keys():
		var it: Dictionary = eq[sl]
		lo.append("%s: %s%s" % [str(sl), str(it.get("name", "?")), (" [%s]" % str(it.get("rarity"))) if it.has("rarity") else ""])
	if lo.is_empty():
		lo.append("defaults (weapon %s)" % str(GameState.weapon.get("name", GameState.weapon.get("id", "?"))))
	if not GameState.tonic_loadout.is_empty():
		lo.append("tonics: " + ", ".join(PackedStringArray(GameState.tonic_loadout.map(func(x: Variant) -> String: return str(x)))))
	c["loadout"] = "; ".join(lo)
	## The run (if one is live).
	var in_run := scene != null and scene.get("_match_time") != null
	c["in_run"] = in_run
	c["run_level"] = GameState.run_level
	var rt := float(scene.get("_match_time")) if in_run else 0.0
	c["run_time"] = "%d:%02d" % [int(rt) / 60, int(rt) % 60] if in_run else "-"
	var p := tree.get_first_node_in_group("player")
	if p != null and p.get("hp") != null:
		c["hp"] = "%d/%d" % [int(round(float(p.get("hp")))), int(round(float(p.get("max_hp"))))]
	else:
		c["hp"] = "-"
	c["pos"] = "%d, %d" % [int((p as Node2D).global_position.x), int((p as Node2D).global_position.y)] if p is Node2D else "-"
	c["admin"] = "ADMIN RUN" if Admin.run_tainted else ("admin on" if Admin.enabled else "-")
	c["kills"] = GameState.kills
	c["scrap"] = GameState.scrap_found
	c["threat"] = GameState.threat_level
	c["picks"] = ", ".join(PackedStringArray(GameState.run_picks_taken.map(func(x: Variant) -> String: return str(x)))) if in_run and not GameState.run_picks_taken.is_empty() else "-"
	c["fps"] = int(Engine.get_frames_per_second())
	## Settings the tester has changed + text size + handedness.
	var st := PackedStringArray()
	st.append("text %s" % UiTheme.TEXT_SIZE_NAMES[clampi(UiTheme.text_size_index(), 0, UiTheme.TEXT_SIZE_NAMES.size() - 1)])
	st.append("left_hand %s" % str(GameState.settings.get("left_handed", false)))
	for k in GameState.settings.keys():
		if str(k) == "left_handed":
			continue
		st.append("%s %s" % [str(k), str(GameState.settings[k])])
	c["settings"] = ", ".join(st)
	c["log"] = recent_log(LOG_LINES)
	return c


## Last lines of the engine / browser log, when the platform keeps one.
static func recent_log(n: int) -> PackedStringArray:
	var out := PackedStringArray()
	if OS.has_feature("web"):
		install_js()
		var s: Variant = JavaScriptBridge.eval("(window.__wfLog||[]).slice(-%d).join('\\n')" % n, true)
		if s != null and str(s) != "":
			out = str(s).split("\n")
		return out
	var path := "user://logs/godot.log"
	if FileAccess.file_exists(path):
		var lines := FileAccess.get_file_as_string(path).split("\n", false)
		var from := maxi(0, lines.size() - n)
		for i in range(from, lines.size()):
			out.append(lines[i])
	return out


## Plain-text report: the tester's words on top, the context below.
static func report_text(ctx: Dictionary, category: String, fun: int, note: String) -> String:
	var t := PackedStringArray()
	t.append("WANDERER FEEDBACK — %s%s" % [category if category != "" else "OTHER", ("  ·  fun %d/5" % fun) if fun > 0 else ""])
	t.append(note.strip_edges() if note.strip_edges() != "" else "(no note)")
	t.append("")
	t.append("--- context ---")
	for k in ["build", "time", "platform", "screen", "scene", "mode", "tier", "level", "hero", "pet", "loadout",
			"run_level", "run_time", "hp", "pos", "kills", "scrap", "threat", "picks", "fps", "admin", "settings"]:
		if ctx.has(k):
			t.append("%s: %s" % [k, str(ctx[k])])
	var lg: PackedStringArray = ctx.get("log", PackedStringArray())
	t.append("--- last %d log lines ---" % lg.size())
	t.append_array(lg)
	return "\n".join(t)


static func file_stem(ctx: Dictionary) -> String:
	var d := Time.get_datetime_dict_from_system()
	return "wanderer_fb_%04d%02d%02d_%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]


## Native: PNG + TXT into user://feedback, text on the clipboard. Returns the
## folder's OS path ("" on failure).
static func save_native(stem: String, png: PackedByteArray, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var ok := true
	if not png.is_empty():
		var f := FileAccess.open("%s/%s.png" % [SAVE_DIR, stem], FileAccess.WRITE)
		if f:
			f.store_buffer(png)
			f.close()
		else:
			ok = false
	var ft := FileAccess.open("%s/%s.txt" % [SAVE_DIR, stem], FileAccess.WRITE)
	if ft:
		ft.store_string(text)
		ft.close()
	else:
		ok = false
	DisplayServer.clipboard_set(text)
	return ProjectSettings.globalize_path(SAVE_DIR) if ok else ""


## mailto: link (no recipient: the tester picks one) with the report as body.
## Kept short enough for every mail app's URL limit.
static func mailto(text: String) -> String:
	var body := text if text.length() <= 6000 else text.substr(0, 6000) + "\n[...trimmed]"
	var subj := "Wanderer feedback " + BuildInfo.VERSION
	return "mailto:?subject=%s&body=%s" % [subj.uri_encode(), body.uri_encode()]


## --- Web ---------------------------------------------------------------------
## window.wfFeedback: prepare() stores the PNG (base64) + text; arm() hooks the
## browser's own pointerup/touchend so navigator.share runs inside a real user
## gesture (Safari needs that); share() is also callable directly. status is
## polled by the sheet: idle / ready / sharing / shared / shared_text /
## downloaded / cancelled / error:<msg>.
const JS := """
(function(){
if(!window.__wfLog){var L=window.__wfLog=[];['log','warn','error'].forEach(function(k){var o=console[k];console[k]=function(){try{L.push((k==='log'?'':k.toUpperCase()+': ')+Array.prototype.map.call(arguments,String).join(' '));if(L.length>80)L.shift();}catch(e){}return o.apply(console,arguments);};});}
if(window.wfFeedback)return;
var F=window.wfFeedback={status:'idle',b64:'',text:'',name:'wanderer_feedback',armed:false,
prepare:function(b64,text,name){F.b64=b64||'';F.text=text||'';F.name=name||'wanderer_feedback';F.status='ready';return true;},
_blob:function(){if(!F.b64)return null;var bin=atob(F.b64);var u=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);return new Blob([u],{type:'image/png'});},
_download:function(blob){try{var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=F.name+'.png';document.body.appendChild(a);a.click();setTimeout(function(){URL.revokeObjectURL(a.href);a.remove();},4000);return true;}catch(e){return false;}},
_copy:function(){try{if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(F.text).catch(function(){});}}catch(e){}},
_fallback:function(blob,why){var dl=blob?F._download(blob):false;F._copy();
 if(navigator.share){navigator.share({title:'Wanderer feedback',text:F.text}).then(function(){F.status=dl?'shared_text':'shared';},function(e){F.status=(e&&e.name==='AbortError')?(dl?'downloaded':'cancelled'):(dl?'downloaded':'error:'+why);});}
 else{F.status=dl?'downloaded':'error:'+why;}},
share:function(){if(F.status==='sharing')return;F.armed=false;F._unarm();F.status='sharing';var blob=null;
 try{blob=F._blob();
  var file=blob?new File([blob],F.name+'.png',{type:'image/png'}):null;
  if(file&&navigator.share&&navigator.canShare&&navigator.canShare({files:[file]})){
   navigator.share({files:[file],title:'Wanderer feedback',text:F.text}).then(function(){F.status='shared';},function(e){if(e&&e.name==='AbortError'){F.status='cancelled';}else{F._fallback(blob,(e&&e.message)||'share failed');}});
  }else{F._fallback(blob,'no file share');}
 }catch(e){try{F._fallback(blob,e.message||String(e));}catch(e2){F.status='error:'+(e2.message||e2);}}},
_h:function(){if(F.armed)F.share();},
_unarm:function(){['pointerup','touchend','click'].forEach(function(t){window.removeEventListener(t,F._h,true);});},
arm:function(){F.armed=true;F._unarm();['pointerup','touchend','click'].forEach(function(t){window.addEventListener(t,F._h,true);});return true;}
};
})();
"""


static func install_js() -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval(JS, true)
	return true


static func web_prepare(png: PackedByteArray, text: String, stem: String) -> bool:
	if not install_js():
		return false
	var f: JavaScriptObject = JavaScriptBridge.get_interface("wfFeedback")
	if f == null:
		return false
	f.prepare(Marshalls.raw_to_base64(png), text, stem)
	return true


static func web_call(method: String) -> void:
	if not OS.has_feature("web"):
		return
	var f: JavaScriptObject = JavaScriptBridge.get_interface("wfFeedback")
	if f == null:
		return
	if method == "arm":
		f.arm()
	elif method == "share":
		f.share()


static func web_status() -> String:
	if not OS.has_feature("web"):
		return ""
	var s: Variant = JavaScriptBridge.eval("window.wfFeedback ? window.wfFeedback.status : ''", true)
	return str(s) if s != null else ""


## Web note entry: the browser's own prompt brings up the phone keyboard
## reliably (Godot's web text fields don't). Returns null on cancel.
static func web_prompt(title: String, current: String) -> Variant:
	if not OS.has_feature("web"):
		return null
	var w: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if w == null:
		return null
	var r: Variant = w.prompt(title, current)
	return r
