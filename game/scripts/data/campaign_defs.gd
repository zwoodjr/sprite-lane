class_name CampaignDefs
extends RefCounted

## CAMPAIGN — Act One: The Long Dust. Chapters, level order, speakers, plane
## parts. Each level lives in its own defs file (scripts/campaign/levels/*.gd,
## `static func def() -> Dictionary`). Level def keys:
##
##   id, title, subtitle            card text
##   tier                           zone the map is built from (ground, props, mobs)
##   enemy_hp, enemy_damage         enemy strength (multipliers)
##   hero                           forced hero id, or
##   heroes                         [] = anyone the story has met (minus the fallen)
##   pet                            forced dog ("" = none); omit = player's dog
##   seed                           ground / scatter seed (fixed: same map every time)
##   bounds                         Rect2 of the playable map (the hero starts at 0,0)
##   roads                          [[Vector2, ...]] polylines (asphalt + convoys)
##   sets                           [[set_name, x, y]] hand-placed set pieces (wasteland SETS)
##   props                          [[kind, x, y]] single props; "world/<name>" = landmark art
##   crates                         [[x, y]] breakable supply crates
##   fires                          [[x, y, size]] camp fires / burning wreckage (light pools)
##   clear                          [[x, y, r]] kept free of scatter
##   landmarks                      [{name, pos, kind 0-3}] labelled landmark rooms + minimap
##   scenes                         {id: [line, ...]} story scenes (see story_panel.gd)
##   intro / outro                  scene ids played before / after the level
##   objectives                     ordered objective list (see objective_runner.gd)
##   triggers                       [{at, r, do: [actions]}] area triggers
##   rewards                        {scrap, survivors, pets, part, camp: {id: rank}, flags}

const MATCH_SCENE := "res://scenes/match/campaign_match.tscn"
const LEVEL_DIR := "res://scripts/campaign/levels/%s.gd"
## Replaying a cleared level pays this share of its scrap reward.
const REPLAY_SCRAP := 0.25

const CHAPTERS := [
	{"id": "prologue", "num": 0, "tag": "PROLOGUE", "name": "Mayday", "levels": ["p0_mayday"],
		"ground": ["433428", "5b4a3b", "685645", "7e6953"]},
	{"id": "ch1", "num": 1, "tag": "CHAPTER 1", "name": "Embers",
		"levels": ["l01_rubble_run", "l02_bell_tower", "l03_lights_out", "l04_cathedral"],
		"ground": ["34363f", "494e5a", "54596a", "676d7b"]},
	{"id": "ch2", "num": 2, "tag": "CHAPTER 2", "name": "The Long Dust",
		"levels": ["l05_field_notes", "l06_smugglers_road", "l07_mother_vane", "l08_dead_signal"],
		"ground": ["4a3028", "67453a", "755244", "896555"]},
	{"id": "ch3", "num": 3, "tag": "CHAPTER 3", "name": "Heart of the Dust",
		"levels": ["l09_quarantine", "l10_choke", "l11_wardens_gate", "l12_dustfall"],
		"ground": ["502f1b", "6b452e", "775038", "8a6549"]},
	{"id": "epilogue", "num": 4, "tag": "EPILOGUE", "name": "Wheels Up", "levels": ["e0_wheels_up"],
		"ground": ["3a3634", "534c49", "5f5854", "726c67"]},
]

const ORDER := [
	"p0_mayday",
	"l01_rubble_run", "l02_bell_tower", "l03_lights_out", "l04_cathedral",
	"l05_field_notes", "l06_smugglers_road", "l07_mother_vane", "l08_dead_signal",
	"l09_quarantine", "l10_choke", "l11_wardens_gate", "l12_dustfall",
	"e0_wheels_up",
]

## Map-card names for levels whose defs are not in yet ("coming soon").
const TITLES := {
	"p0_mayday": "Mayday", "l01_rubble_run": "Rubble Run", "l02_bell_tower": "The Bell Tower",
	"l03_lights_out": "Lights Out", "l04_cathedral": "Cathedral of Ash", "l05_field_notes": "Field Notes",
	"l06_smugglers_road": "Smuggler's Road", "l07_mother_vane": "Mother Vane", "l08_dead_signal": "Dead Signal",
	"l09_quarantine": "Quarantine", "l10_choke": "Choke", "l11_wardens_gate": "The Warden's Gate",
	"l12_dustfall": "Dustfall", "e0_wheels_up": "Wheels Up",
}

## Helm's plane, one salvaged part at a time (campaign only).
const PLANE_PARTS := {
	"frame": {"name": "Airframe", "icon": "tab_camp"},
	"battery": {"name": "Battery", "icon": "camp_generator"},
	"fuel": {"name": "Fuel Tanks", "icon": "camp_ammo_bench"},
	"engine": {"name": "Engine", "icon": "mat_salvage_core"},
	"heart": {"name": "Dust Heart", "icon": "mat_dust_heart"},
}
const PLANE_ORDER := ["frame", "battery", "fuel", "engine", "heart"]

## Who talks. `portrait` = 192 px painted bust; `radio` = speaks over the
## radio by default (CRT frame, static).
const P := "res://assets/sprites/portraits/%s.png"
const SPEAKERS := {
	"helm": {"name": "Helm", "portrait": "helm_wisp", "color": "e8c972"},
	"rook": {"name": "Rook", "portrait": "ash_rook", "color": "d98a45"},
	"vesper": {"name": "Vesper", "portrait": "vesper_thorn", "color": "9ccf3e"},
	"pebble": {"name": "Pebble", "portrait": "pebble", "color": "c8b08a"},
	"juno": {"name": "Juno", "portrait": "bolt_juno", "color": "5cd2c0"},
	"cinder": {"name": "Sister Cinder", "portrait": "sister_cinder", "color": "ffc040"},
	"quill": {"name": "Quill", "portrait": "quill_marrow", "color": "c08aa0"},
	"nyx": {"name": "Nyx", "portrait": "nyx_caldera", "color": "9aa8ad"},
	"noel": {"name": "Noel", "portrait": "pet_noel", "color": "e9dfc9"},
	"bentley": {"name": "Bentley", "portrait": "pet_bentley", "color": "c8b08a"},
	"lillie": {"name": "Lillie", "portrait": "pet_lillie", "color": "e9dfc9"},
	"vane": {"name": "Mother Vane", "portrait": "mother_vane", "color": "ff4836"},
	"raider": {"name": "Raider", "portrait": "raider", "color": "ad5a2a"},
	"beacon": {"name": "Beacon", "portrait": "", "color": "ff4836", "radio": true},
	"dust": {"name": "???", "portrait": "", "color": "fff2c0"},
}
const HERO_SPEAKER := {
	"helm_wisp": "helm", "ash_rook": "rook", "vesper_thorn": "vesper", "pebble": "pebble",
	"bolt_juno": "juno", "sister_cinder": "cinder", "quill_marrow": "quill", "nyx_caldera": "nyx",
}

static var _cache: Dictionary = {}


static func has_level(id: String) -> bool:
	return id in ORDER


## A level is playable once its defs file exists.
static func is_playable(id: String) -> bool:
	return has_level(id) and ResourceLoader.exists(LEVEL_DIR % id)


static func level(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var d := {}
	if is_playable(id):
		var scr: Script = load(LEVEL_DIR % id)
		if scr:
			d = scr.call("def")
			d["id"] = id
	if d.is_empty():
		d = {"id": id, "title": str(TITLES.get(id, id)), "subtitle": "Coming soon", "tier": 1}
	d["chapter"] = chapter_of(id)
	_cache[id] = d
	return d


static func chapter_of(id: String) -> Dictionary:
	for c in CHAPTERS:
		if id in (c["levels"] as Array):
			return c
	return CHAPTERS[0]


static func index_of(id: String) -> int:
	return ORDER.find(id)


static func next_level(id: String) -> String:
	var i := ORDER.find(id)
	if i < 0 or i + 1 >= ORDER.size():
		return ""
	return str(ORDER[i + 1])


## "01".."12" for levels, "P" prologue, "E" epilogue.
static func number_tag(id: String) -> String:
	if id.begins_with("p"):
		return "P"
	if id.begins_with("e"):
		return "E"
	return id.substr(1, 2)


static func speaker(id: String) -> Dictionary:
	var s: Dictionary = SPEAKERS.get(id, {"name": id.capitalize(), "portrait": "", "color": "e9dfc9"})
	return s


static func portrait_path(id: String) -> String:
	var p := str(speaker(id).get("portrait", ""))
	if p == "":
		return ""
	var path := P % p
	return path if ResourceLoader.exists(path) else ""


static func hero_speaker(hero: String) -> String:
	return str(HERO_SPEAKER.get(hero, "helm"))
