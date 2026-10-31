class_name IconSet
extends RefCounted

## The one icon set (style bible §6.5), made by tools/gen_icons.py:
##   assets/sprites/icons/set/48/<id>.png  cards, gear slots, ability buttons
##   assets/sprites/icons/set/24/<id>.png  rows, chips, HUD
## Icons are pixel art: always shown at an integer scale with nearest filter.
## Ids: slot_<slot> · mod_<mod> · style_<hero>_<style> · ab_<hero>_<a|b> ·
## quirk_<id> · tonic_<id> · ing_<id> · up_<upgrade> · rec_<recipe> ·
## ammo_<id> · mat_<id> · cur_<scrap|xp|level|extract> · camp_<id> ·
## tab_<id> · set_<id> · hud_<id>.

const DIR := "res://assets/sprites/icons/set/"
const RARITY_COLOR := {
	"common": Color("8f877e"), "uncommon": Color("8f877e"), "rare": Color("5cd2c0"),
	"epic": Color("c08aa0"), "legendary": Color("ffc040"), "evolution": Color("ffc040"),
}

static var _cache: Dictionary = {}


static func path(id: String, big: bool = true) -> String:
	return "%s%d/%s.png" % [DIR, 48 if big else 24, id]


static func has(id: String) -> bool:
	return ResourceLoader.exists(path(id, true))


static func tex(id: String, big: bool = true) -> Texture2D:
	var p := path(id, big)
	if _cache.has(p):
		return _cache[p]
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_cache[p] = t
	return t


## TextureRect showing the icon at `px` design px (rounded to an integer
## multiple of the source size; the 24-px art is used below 64 px).
static func rect(id: String, px: int = 96) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(id, px >= 64)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED if r.texture == null else TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func frame(rarity: String) -> Texture2D:
	var r := rarity if rarity in ["common", "rare", "epic", "legendary"] else ("legendary" if rarity == "evolution" else "common")
	var p := DIR + "frame_%s.png" % r
	if _cache.has(p):
		return _cache[p]
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_cache[p] = t
	return t


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLOR.get(rarity, RARITY_COLOR["common"])


## --- id helpers ------------------------------------------------------------

static func slot(slot_id: String) -> String:
	return "slot_" + slot_id


static func style(hero: String, sid: String) -> String:
	return "style_%s_%s" % [hero, sid]


static func ability(hero: String, version: String = "a") -> String:
	return "ab_%s_%s" % [hero, "b" if version == "b" else "a"]


static func upgrade(u: Dictionary) -> String:
	var id := str(u.get("id", ""))
	if bool(u.get("evolution", false)) and has("rec_" + id):
		return "rec_" + id
	if has("up_" + id):
		return "up_" + id
	if has("rec_" + id):
		return "rec_" + id
	return "up_piercing"


## Icon for a gear item: one per mod, weapon variant, named Legendary and
## armour / accessory look (gear_<slot>_<noun>); slot art as the fallback.
static func item(it: Dictionary) -> String:
	var kind := str(it.get("kind", ""))
	if kind == "petgear":
		return str(it.get("icon_id", "gear_charm_2"))
	if kind == "mod" and has("mod_" + str(it.get("mod", ""))):
		return "mod_" + str(it.get("mod", ""))
	if kind == "weapon":
		var hero := str(it.get("hero", ""))
		var leg := str(it.get("legendary", ""))
		if leg != "" and has("leg_" + leg):
			return "leg_" + leg
		var wid := "wpn_%s_%s" % [hero, str(it.get("variant", ""))]
		if has(wid):
			return wid
		var styles: Array = KitDefs.styles(hero) if hero != "" else []
		if not styles.is_empty():
			return style(hero, str(styles[0]["id"]))
		return "slot_weapon"
	var sl := str(it.get("slot", ""))
	## Painted per-piece art: tier-exclusive Legendaries, then matched set pieces.
	var ex := str(it.get("exclusive", ""))
	if ex != "" and has("tleg_" + ex):
		return "tleg_" + ex
	var sid := str(it.get("set", ""))
	if sid != "" and has("gset_%s_%s" % [sid, sl]):
		return "gset_%s_%s" % [sid, sl]
	var gid := "gear_%s_%d" % [sl, GearDefs.noun_index(it)]
	if has(gid):
		return gid
	if has("slot_" + sl):
		return "slot_" + sl
	return "slot_charm"


## Set emblem icon id.
static func emblem(set_id: String) -> String:
	return "emb_" + set_id


## Ingredients / tonics / materials share one lookup.
static func stuff(id: String) -> String:
	for pre in ["ing_", "tonic_", "mat_", "ammo_", "cur_"]:
		if has(pre + id):
			return pre + id
	return "cur_scrap"


## Icon for a pack / pouch / tonic id: the set icon when one exists, else the
## item's own art (MedicineDefs). Always nearest-filtered at `px`.
static func stuff_rect(id: String, px: int = 48) -> TextureRect:
	for pre in ["ing_", "tonic_", "mat_", "ammo_", "cur_"]:
		if has(pre + id):
			return rect(pre + id, px)
	var r := rect("", px)
	var p := MedicineDefs.icon_path(id)
	if ResourceLoader.exists(p):
		r.texture = load(p)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r
