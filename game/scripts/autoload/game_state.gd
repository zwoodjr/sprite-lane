extends Node

## Persistent run / meta state for the MVP vertical slice.
## Dual track:
##   A) In-run levels + loadout picks (reset every deploy)
##   B) Meta scrap → Hangar permanent upgrades (survive wipe)

signal run_reset
signal loadout_changed
signal run_xp_changed(run_xp: int, run_level: int)
signal run_level_up(new_level: int, choices: Array)
signal meta_changed

var selected_mode_id: String = ModeDefs.EASY_ID
var selected_character_id: String = CharacterDefs.ROOK_ID
var selected_pet_id: String = PetDefs.NOEL_ID

## Dev-only: compress phase timers for quick playtests (default off).
var fast_timers: bool = false
## Debug flag: shows dev toggles (quick-test timers) in menus. Off for players;
## flip here or launch with `-- --dev` to get them back.
var dev_tools: bool = false
const FAST_TIMER_SCALE := 0.12

## Classic insurance stub — slots from mode + meta; marks brought-in items.
var insured_slots: Array[String] = []

## --- Meta (survives wipe) ---
## Scrap is the permanent upgrade fuel. Account XP = soft prestige only.
var account_scrap: int = 0
var account_xp: int = 0
var account_level: int = 1
var meta_upgrades: Dictionary = {} ## v3 flat Hangar (retired; refunded on load)
## Hangar v4: HangarDefs id -> rank (shared / stations / kennel / stash).
var camp: Dictionary = {}
## Shared lockbox of extracted gear (Phase B items). Capacity: stash_capacity().
var stash: Array = []
## --- Gear (Phase B) ---
## Per survivor: loadout slot -> item uid (GearDefs.LOADOUT_SLOTS).
var loadouts: Dictionary = {}
## Per survivor: the one insured item uid (kept even on death).
var insured: Dictionary = {}
var next_uid: int = 1
## Banked boss materials: salvage_core / dust_heart -> count.
var materials: Dictionary = {}
## Derived for the current deploy (see _compute_gear): stats, set counts, legendary.
var gear: Dictionary = {}
## Found this run (kept only on extract) + boss bonus to the loot multiplier.
var run_loot: Array = []
var run_materials: Dictionary = {}
var boss_loot_bonus: float = 0.0
var result_found: Array = []
var result_lost_items: Array = []
var result_salvaged: int = 0
## Unlock lines raised mid-run (trophies), shown on the result screen.
var result_unlocks_pending: PackedStringArray = []
## --- Logbook (Phase C) ---
## {"date": "YYYY-MM-DD", "quests": [...]} — refreshed each day (QuestDefs.roll_daily).
var daily: Dictionary = {}
## Survivor stories: hero -> {"step": 0..5, "have": progress on the current step}.
var stories: Dictionary = {}
## Camp milestones done: id -> true (cosmetics / trophies in the hangar).
var milestones: Dictionary = {}
## Pet Bond XP per dog (EventDefs.PET_BOND / BOND_*).
var kennel_bond: Dictionary = {}
## Story Legendaries waiting for stash room.
var pending_rewards: Array = []
## In-run event state (reset every deploy).
var event_scrap_mult: float = 1.0
var event_enemy_damage: float = 1.0
var events_done_run: int = 0
var extract_bonus_scrap: int = 0
var extract_bonus_notes: PackedStringArray = []
## First boss kills: boss kind -> true. Trophies show over the hangar door.
var trophies: Dictionary = {}
## One-time v3 → v4 Hangar migration done (old spend refunded as scrap).
var migrated_hangar_v4: bool = false
## Shown once on the Hangar screen (e.g. the refund note). Not saved.
var hangar_notice: String = ""
var garage_tokens: int = 0
var successful_extracts: int = 0
## --- Depth Update E1: medicine & plague (MedicineDefs) ---
## Banked ingredients (+ "medicine") -> count; brewed tonic stock; tonics to drink on deploy.
var ingredients: Dictionary = {}
var tonics: Dictionary = {}
var tonic_loadout: Array = []
## In-run: carried ingredients / medicine (banked on extract), tonics drunk, exposure.
var run_pack: Dictionary = {}
var run_tonics: Array = []
var exposure: float = 0.0
## --- Depth E3: Quill's Field Notes (kills per kind, kept) + found lore pages ---
var bestiary: Dictionary = {}
var lore_pages: Dictionary = {}
## --- Depth E4: radio jobs (in-run) ---
## Nyx's Pack Lock: the pack survives a death this run.
var run_pack_locked: bool = false
## --- Depth E5: per-survivor kit (KitDefs): {"style", "ability" a|b, "quirk"} ---
var kit: Dictionary = {}
## Depth E6: mech pets rebuilt in the Workshop ({pet id: true}).
var mechs_built: Dictionary = {}
## Depth E7: tier-clear trophies {hero: {"<tier>": true}}, Helm's plane parts
## {"<tier>": true}, Dust Pacts picked for the next run, and run-only zone state.
var tier_clears: Dictionary = {}
var plane_parts: Dictionary = {}
var pacts: Array = []
var run_keys: int = 0
var run_filter: float = 100.0
var run_has_cell: bool = false
## Contract rewards waiting for extract: ingredients -> count.
var run_job_rewards: Dictionary = {}
var jobs_done_run: int = 0


## Player settings + onboarding flags (persisted to user://).
const SAVE_PATH := "user://wanderer_save.json"
const SAVE_VERSION := 4
var settings: Dictionary = {
	"sfx": true,
	"mute": false,
	"vol_master": 1.0,
	"vol_music": 0.7,
	"vol_sfx": 1.0,
	"vol_ambience": 0.8,
	"vol_ui": 0.8,
	"haptics": true,
	"screen_shake": true,
	"stick_scale": 1.0,
	"left_handed": false,
	"show_hints": true,
	"heat_shimmer": false,
	## Edge dither vignette (bible: no noise / film grain). Off by default.
	"film_grain": false,
	"dither_v1": true,
}
var tutorial_done: bool = false
## One-time v1/v2 → v3 save migration (garage tokens → scrap) already applied.
var migrated_v3: bool = false
var best_payout: int = 0
## Highest Dust tier extracted on (unlocks the next one).
var best_tier_extracted: int = 0
var total_runs: int = 0

## Deployed loadout (copied at deploy).
var armor: Dictionary = {}
var weapon: Dictionary = {}
var pet: Dictionary = {}

## --- In-run (resets every deploy) ---
var threat_level: int = 0
var windows_skipped: int = 0
var extract_windows_seen: int = 0
## Stay-or-go loot multiplier (×1.0 +0.1 / 30 s, capped per tier). Pays on extract.
var loot_mult: float = 1.0
var scrap_found: int = 0
var kills: int = 0
var extracted: bool = false
var wiped: bool = false
## True once this run has been banked (extract / wipe / abandon). Guards double-counting.
var run_finished: bool = false
var result_summary: String = ""
var last_phase_label: String = ""
var run_seed: int = 0
var extract_pad_info: Array = []

## In-run leveling (temporary power)
var run_xp: int = 0 ## toward next run level
var run_level: int = 1
var run_mods: Dictionary = _fresh_run_mods()
var run_picks_taken: Array = [] ## upgrade ids chosen this run
## Phase 4 cards: id -> rank owned this run (see UpgradeDefs).
var run_ranks: Dictionary = {}
var run_rerolls_left: int = 2
var run_luck_charges: int = 0 ## Lucky Vial: level-ups left with better odds
var run_luck: float = 1.0
## Field Notes: kills per enemy kind this run.
var run_kind_kills: Dictionary = {}
## Depth E3: special ammo types picked up this run (Arc Storm needs Shock).
var run_ammo_seen: Dictionary = {}
var pending_run_choices: Array = []
var run_level_paused: bool = false

## Soft account XP earned this run (prestige, not power)
var account_xp_this_run: int = 0
var payout_this_run: int = 0

## Result-screen build-up (transient)
var result_scrap_before: int = 0
var result_scrap_banked: int = 0
var result_scrap_lost: int = 0
var result_account_xp_before: int = 0
var result_account_level_before: int = 1
var result_levels_gained: int = 0 ## account soft levels
var result_run_level_reached: int = 1
var result_lost_keys: PackedStringArray = []
var result_kept_keys: PackedStringArray = []
var result_unlocks: PackedStringArray = []

func _ready() -> void:
	if "--dev" in OS.get_cmdline_user_args():
		dev_tools = true
	load_profile()
	reset_loadout_to_defaults()

func save_profile() -> void:
	_sync_account_level()
	var data := {
		"version": SAVE_VERSION,
		"settings": settings,
		"tutorial_done": tutorial_done,
		"migrated_v3": migrated_v3,
		"account_scrap": account_scrap,
		"account_xp": account_xp,
		"account_level": account_level,
		"meta_upgrades": meta_upgrades,
		"camp": camp,
		"stash": stash,
		"trophies": trophies,
		"loadouts": loadouts,
		"insured": insured,
		"salvage_bin": salvage_bin,
		"next_uid": next_uid,
		"materials": materials,
		"daily": daily,
		"stories": stories,
		"milestones": milestones,
		"kennel_bond": kennel_bond,
		"pending_rewards": pending_rewards,
		"migrated_hangar_v4": migrated_hangar_v4,
		"garage_tokens": garage_tokens,
		"successful_extracts": successful_extracts,
		"best_payout": best_payout,
		"best_tier_extracted": best_tier_extracted,
		"total_runs": total_runs,
		"selected_mode_id": selected_mode_id,
		"selected_character_id": _wander_hero if in_campaign_run() and _wander_hero != "" else selected_character_id,
		"selected_pet_id": _wander_pet if in_campaign_run() and _wander_pet != "" else selected_pet_id,
		"ingredients": ingredients,
		"tonics": tonics,
		"tonic_loadout": tonic_loadout,
		"bestiary": bestiary,
		"lore_pages": lore_pages,
		"kit": kit,
		"mechs_built": mechs_built,
		"tier_clears": tier_clears,
		"plane_parts": plane_parts,
		"pacts": pacts,
		"campaign": campaign,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		migrated_hangar_v4 = true
		_sync_account_level()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	apply_save(parsed)

## Loads a parsed save dictionary (any version — missing keys get safe defaults).
func apply_save(d: Dictionary) -> void:
	var saved_settings: Variant = d.get("settings", {})
	if typeof(saved_settings) == TYPE_DICTIONARY:
		for k in (saved_settings as Dictionary).keys():
			settings[k] = saved_settings[k]
		## The old film grain (default on) became the bible's edge dither,
		## default off: older saves start with it off once.
		if not (saved_settings as Dictionary).has("dither_v1"):
			settings["film_grain"] = false
	settings["dither_v1"] = true
	tutorial_done = bool(d.get("tutorial_done", false))
	account_scrap = int(d.get("account_scrap", 0))
	## Migrate v1/v2: old saves had account_xp as pseudo-power; keep XP, prefer scrap.
	account_xp = int(d.get("account_xp", 0))
	migrated_v3 = bool(d.get("migrated_v3", false))
	if not migrated_v3:
		## One-time soft migrate: leftover garage tokens → a bit of scrap. Never repeats,
		## so spending to 0 scrap can't re-mint free scrap on the next launch.
		if account_scrap <= 0 and int(d.get("version", 0)) < SAVE_VERSION and d.has("garage_tokens"):
			account_scrap = int(d.get("garage_tokens", 0)) * 10
		migrated_v3 = true
	var mu: Variant = d.get("meta_upgrades", {})
	if typeof(mu) == TYPE_DICTIONARY:
		meta_upgrades = (mu as Dictionary).duplicate()
	var cp: Variant = d.get("camp", {})
	camp = {}
	if typeof(cp) == TYPE_DICTIONARY:
		for k in (cp as Dictionary).keys():
			var id := str(k)
			if HangarDefs.layer_of(id) != "":
				camp[id] = clampi(int((cp as Dictionary)[k]), 0, HangarDefs.max_rank(id))
	var st: Variant = d.get("stash", [])
	stash = []
	if typeof(st) == TYPE_ARRAY:
		for it in (st as Array):
			if typeof(it) == TYPE_DICTIONARY:
				stash.append(it)
	migrated_hangar_v4 = bool(d.get("migrated_hangar_v4", false))
	var lo: Variant = d.get("loadouts", {})
	loadouts = {}
	if typeof(lo) == TYPE_DICTIONARY:
		for h in (lo as Dictionary).keys():
			var slots: Variant = (lo as Dictionary)[h]
			if typeof(slots) != TYPE_DICTIONARY:
				continue
			var clean := {}
			for sl in (slots as Dictionary).keys():
				if str(sl) in GearDefs.LOADOUT_SLOTS:
					clean[str(sl)] = int((slots as Dictionary)[sl])
			loadouts[str(h)] = clean
	var ins: Variant = d.get("insured", {})
	insured = {}
	if typeof(ins) == TYPE_DICTIONARY:
		for h in (ins as Dictionary).keys():
			insured[str(h)] = int((ins as Dictionary)[h])
	var bin: Variant = d.get("salvage_bin", [])
	salvage_bin = []
	if typeof(bin) == TYPE_ARRAY:
		for e in (bin as Array):
			if typeof(e) == TYPE_DICTIONARY and typeof((e as Dictionary).get("item", null)) == TYPE_DICTIONARY:
				salvage_bin.append({"item": e["item"], "scrap": maxi(0, int(e.get("scrap", 0)))})
	var mats: Variant = d.get("materials", {})
	materials = {}
	if typeof(mats) == TYPE_DICTIONARY:
		for k in (mats as Dictionary).keys():
			materials[str(k)] = maxi(0, int((mats as Dictionary)[k]))
	next_uid = maxi(1, int(d.get("next_uid", 1)))
	for it in stash:
		it["uid"] = int(it.get("uid", 0))
		if int(it["uid"]) <= 0:
			it["uid"] = next_uid
		next_uid = maxi(next_uid, int(it["uid"]) + 1)
	for e in salvage_bin:
		var bi: Dictionary = e["item"]
		bi["uid"] = int(bi.get("uid", 0))
		next_uid = maxi(next_uid, int(bi["uid"]) + 1)
	daily = _dict_or_empty(d.get("daily", {}))
	if not (daily.get("quests", null) is Array):
		daily = {}
	stories = {}
	var st_raw := _dict_or_empty(d.get("stories", {}))
	for h in st_raw.keys():
		var e: Variant = st_raw[h]
		if typeof(e) == TYPE_DICTIONARY:
			stories[str(h)] = {"step": clampi(int((e as Dictionary).get("step", 0)), 0, QuestDefs.STORY_STEPS.size()),
				"have": maxi(0, int((e as Dictionary).get("have", 0)))}
	milestones = _dict_or_empty(d.get("milestones", {}))
	kennel_bond = {}
	var kb := _dict_or_empty(d.get("kennel_bond", {}))
	for k in kb.keys():
		kennel_bond[str(k)] = maxi(0, int(kb[k]))
	var pr: Variant = d.get("pending_rewards", [])
	pending_rewards = []
	if typeof(pr) == TYPE_ARRAY:
		for it in (pr as Array):
			if typeof(it) == TYPE_DICTIONARY:
				pending_rewards.append(it)
	var tr: Variant = d.get("trophies", {})
	trophies = (tr as Dictionary).duplicate() if typeof(tr) == TYPE_DICTIONARY else {}
	garage_tokens = int(d.get("garage_tokens", 0))
	successful_extracts = int(d.get("successful_extracts", 0))
	best_payout = int(d.get("best_payout", 0))
	## Old saves: missing key = 0 (tiers 1–2 are always open).
	best_tier_extracted = clampi(int(d.get("best_tier_extracted", 0)), 0, ModeDefs.EXPOSED_TIERS)
	total_runs = int(d.get("total_runs", 0))
	_sync_account_level()
	var mode_id := str(d.get("selected_mode_id", selected_mode_id))
	mode_id = ModeDefs.canonical_id(mode_id)
	if ModeDefs.is_exposed(mode_id) and is_tier_unlocked(int(ModeDefs.get_mode(mode_id)["tier"])):
		selected_mode_id = mode_id
	var char_id := str(d.get("selected_character_id", selected_character_id))
	if char_id == "rook_vex":
		char_id = CharacterDefs.ASH_ROOK_ID
	if CharacterDefs.is_playable(char_id):
		selected_character_id = char_id
	var pet_id := str(d.get("selected_pet_id", selected_pet_id))
	if PetDefs.is_equipable(pet_id):
		selected_pet_id = pet_id
	_load_depth(d)
	_load_campaign(d.get("campaign", {}))
	_migrate_hangar_v4()

## Depth Update keys (old saves: all missing → empty, safe defaults).
func _load_depth(d: Dictionary) -> void:
	ingredients = _count_dict(d.get("ingredients", {}), MedicineDefs.INGREDIENTS.keys())
	tonics = _count_dict(d.get("tonics", {}), MedicineDefs.TONICS.keys())
	tonic_loadout = []
	var tl: Variant = d.get("tonic_loadout", [])
	if typeof(tl) == TYPE_ARRAY:
		for t in (tl as Array):
			var tid := str(t)
			if MedicineDefs.TONICS.has(tid) and not tid in tonic_loadout:
				tonic_loadout.append(tid)
	bestiary = {}
	var bs: Variant = d.get("bestiary", {})
	if typeof(bs) == TYPE_DICTIONARY:
		for k in (bs as Dictionary).keys():
			var n := maxi(0, int((bs as Dictionary)[k]))
			if n > 0:
				bestiary[str(k)] = n
	kit = {}
	var kt: Variant = d.get("kit", {})
	if typeof(kt) == TYPE_DICTIONARY:
		for h in (kt as Dictionary).keys():
			var e: Variant = (kt as Dictionary)[h]
			if not CharacterDefs.is_playable(str(h)) or typeof(e) != TYPE_DICTIONARY:
				continue
			var ed: Dictionary = e
			var clean := {"style": str(KitDefs.styles(str(h))[0]["id"]), "ability": "a", "quirk": ""}
			if not KitDefs.style(str(h), str(ed.get("style", ""))).is_empty() and str(KitDefs.style(str(h), str(ed.get("style", "")))["id"]) == str(ed.get("style", "")):
				clean["style"] = str(ed["style"])
			if str(ed.get("ability", "a")) == "b":
				clean["ability"] = "b"
			if str(ed.get("quirk", "")) in KitDefs.quirks(str(h)):
				clean["quirk"] = str(ed["quirk"])
			kit[str(h)] = clean
	tier_clears = {}
	var tc: Variant = d.get("tier_clears", {})
	if typeof(tc) == TYPE_DICTIONARY:
		for h in (tc as Dictionary).keys():
			var row: Variant = (tc as Dictionary)[h]
			if not CharacterDefs.is_playable(str(h)) or typeof(row) != TYPE_DICTIONARY:
				continue
			var clean := {}
			for t in (row as Dictionary).keys():
				var tn := int(str(t))
				if tn >= ZoneDefs.TROPHY_FROM_TIER and tn <= ModeDefs.EXPOSED_TIERS:
					clean[str(tn)] = true
			if not clean.is_empty():
				tier_clears[str(h)] = clean
	plane_parts = {}
	var pp: Variant = d.get("plane_parts", {})
	if typeof(pp) == TYPE_DICTIONARY:
		for t in (pp as Dictionary).keys():
			if not ZoneDefs.plane_part(int(str(t))).is_empty():
				plane_parts[str(int(str(t)))] = true
	pacts = []
	var pc: Variant = d.get("pacts", [])
	if typeof(pc) == TYPE_ARRAY:
		for k in (pc as Array):
			if not ZoneDefs.pact(str(k)).is_empty() and not str(k) in pacts:
				pacts.append(str(k))
	mechs_built = {}
	var mb: Variant = d.get("mechs_built", {})
	if typeof(mb) == TYPE_DICTIONARY:
		for k in (mb as Dictionary).keys():
			if PetDefs.is_mech(str(k)) and bool((mb as Dictionary)[k]):
				mechs_built[str(k)] = true
	if not pet_available(selected_pet_id):
		selected_pet_id = PetDefs.default_id()
	lore_pages = {}
	var lp: Variant = d.get("lore_pages", {})
	if typeof(lp) == TYPE_DICTIONARY:
		for k in (lp as Dictionary).keys():
			if not BestiaryDefs.page(str(k)).is_empty():
				lore_pages[str(k)] = true

## {id: int >= 0} keeping only known ids.
func _count_dict(v: Variant, known: Array) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in (v as Dictionary).keys():
		var id := str(k)
		if id in known:
			var n := maxi(0, int((v as Dictionary)[k]))
			if n > 0:
				out[id] = n
	return out

func _dict_or_empty(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate(true) if typeof(v) == TYPE_DICTIONARY else {}

## v3 flat %-stat Hangar → v4 camp: refund every scrap spent on the old list once.
func _migrate_hangar_v4() -> void:
	if migrated_hangar_v4:
		return
	migrated_hangar_v4 = true
	var refund := HangarDefs.legacy_refund(meta_upgrades)
	meta_upgrades.clear()
	if refund > 0:
		account_scrap += refund
		hangar_notice = "The Hangar was rebuilt. Your old upgrades were refunded: +%d scrap." % refund
	save_profile()

func _sync_account_level() -> void:
	account_level = Progression.account_level_from_xp(account_xp)

func account_bar_state() -> Dictionary:
	return Progression.account_progress(account_xp)

func run_bar_state() -> Dictionary:
	return Progression.run_progress(run_xp, run_level)

func meta_rank(id: String) -> int:
	return camp_rank(id)

## --- Hangar (camp) ranks: HangarDefs ids -> rank -------------------------
func camp_rank(id: String) -> int:
	return int(camp.get(id, 0))

func station_rank(hero_id: String = "") -> int:
	return camp_rank(HangarDefs.station_id(hero_id if hero_id != "" else selected_character_id))

func kennel_rank(pet_id: String = "") -> int:
	return camp_rank(HangarDefs.kennel_id(pet_id if pet_id != "" else selected_pet_id))

func has_trophy(boss: String) -> bool:
	return bool(trophies.get(boss, false))

func stash_capacity() -> int:
	return HangarDefs.stash_slots(camp_rank("stash"))

## Next-rank price for a Hangar id (-1 = maxed / unknown).
func camp_cost(id: String) -> int:
	return HangarDefs.cost(id, camp_rank(id))

func try_buy_camp(id: String) -> bool:
	if HangarDefs.layer_of(id) == "":
		return false
	## A mech's bay only opens once it is built.
	if id.begins_with("kennel_") and not pet_available(id.substr(7)):
		return false
	var c := camp_cost(id)
	if c < 0 or account_scrap < c:
		return false
	account_scrap -= c
	camp[id] = camp_rank(id) + 1
	save_profile()
	meta_changed.emit()
	return true

## =============================================================================
## Depth E6: Workshop — mech pets rebuilt from Salvage Cores.

func pet_available(pet_id: String) -> bool:
	if PetDefs.is_mech(pet_id):
		return mechs_built.has(pet_id)
	return PetDefs.is_equipable(pet_id)

## Cores banked from the pouch (E6 kill drops) plus the older boss-material cores.
func salvage_cores() -> int:
	return int(ingredients.get("salvage_core", 0)) + material_count("salvage_core")

func can_build_mech(pet_id: String) -> bool:
	if not PetDefs.is_mech(pet_id) or mechs_built.has(pet_id):
		return false
	var d := PetDefs.get_pet(pet_id)
	return salvage_cores() >= int(d["build_cores"]) and account_scrap >= int(d["build_scrap"])

func build_mech(pet_id: String) -> bool:
	if not can_build_mech(pet_id):
		return false
	var d := PetDefs.get_pet(pet_id)
	var need := int(d["build_cores"])
	var from_pouch := mini(need, int(ingredients.get("salvage_core", 0)))
	ingredients["salvage_core"] = int(ingredients.get("salvage_core", 0)) - from_pouch
	materials["salvage_core"] = material_count("salvage_core") - (need - from_pouch)
	account_scrap -= int(d["build_scrap"])
	mechs_built[pet_id] = true
	save_profile()
	meta_changed.emit()
	return true

## =============================================================================
## Depth E7: zones, Dust Pacts, tier trophies, Helm's plane, exclusive loot.

func zone_tier() -> int:
	return int(get_mode().get("tier", 1))

func twist_on(twist: String) -> bool:
	## Campaign levels are handcrafted: no zone twists.
	if in_campaign_run():
		return false
	return ZoneDefs.has_twist(zone_tier(), twist)

func pacts_unlocked() -> bool:
	return best_tier_extracted >= ZoneDefs.PACTS_FROM_TIER

## Active pacts for this run (only once unlocked).
func active_pacts() -> Array:
	return pacts if pacts_unlocked() else []

func toggle_pact(id: String) -> bool:
	if ZoneDefs.pact(id).is_empty() or not pacts_unlocked():
		return false
	if id in pacts:
		pacts.erase(id)
	else:
		pacts.append(id)
	save_profile()
	return true

## Multiplicative pact effect (1.0 = none); "window" is additive seconds.
func pact_fx(key: String) -> float:
	var add := key in ["window", "no_tonics", "window_elite"]
	var v := 0.0 if add else 1.0
	for id in active_pacts():
		var fx: Dictionary = ZoneDefs.pact(str(id)).get("fx", {})
		if fx.has(key):
			v = v + float(fx[key]) if add else v * float(fx[key])
	return v

func pact_loot_bonus() -> float:
	var b := 0.0
	for id in active_pacts():
		b += float(ZoneDefs.pact(str(id)).get("loot", 0.0))
	return b

func has_tier_clear(hero: String, tier: int) -> bool:
	return bool((tier_clears.get(hero, {}) as Dictionary).get(str(tier), false))

func plane_part_count() -> int:
	return plane_parts.size()

func plane_complete() -> bool:
	return plane_parts.size() >= ZoneDefs.PLANE_PARTS.size()

## Extract on tier >= 3: the survivor's trophy for that tier, and the first
## clear of the tier sends a plane part home.
func _record_tier_clear(tier: int) -> void:
	if tier < ZoneDefs.TROPHY_FROM_TIER:
		return
	var hero := selected_character_id
	if not has_tier_clear(hero, tier):
		var row: Dictionary = tier_clears.get(hero, {})
		row[str(tier)] = true
		tier_clears[hero] = row
		result_unlocks_pending.append("Trophy: %s cleared %s" % [str(get_character().get("display_name", hero)), str(ZoneDefs.zone(tier)["name"])])
	var part := ZoneDefs.plane_part(tier)
	if not part.is_empty() and not plane_parts.has(str(tier)):
		plane_parts[str(tier)] = true
		result_unlocks_pending.append("Helm's plane: %s recovered (%d/%d)" % [str(part["name"]), plane_parts.size(), ZoneDefs.PLANE_PARTS.size()])
		if plane_complete():
			result_unlocks_pending.append("Helm's plane is whole — new bases beyond the Dust are in reach")
			hangar_notice = "Helm's plane is whole. Somewhere past the Dust, new bases are waiting."

## A tier-exclusive legendary (ZoneDefs.EXCLUSIVE), or {} for tiers without one.
func make_exclusive(tier: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var ex := ZoneDefs.exclusive(tier)
	if ex.is_empty():
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var it := GearDefs.make_gear(str(ex["slot"]), "legendary", rng)
	var st: Dictionary = it["stats"]
	for k in (ex["stats"] as Dictionary).keys():
		st[k] = float(st.get(k, 0.0)) + float(ex["stats"][k])
	it["stats"] = st
	it["name"] = str(ex["name"])
	it["exclusive"] = str(ex["id"])
	it["exclusive_tier"] = tier
	it["set"] = ""
	it.erase("needs_heart")
	it.erase("charged")
	return it

## Old name kept for scripts / tests that still call it.
func try_buy_hangar(entry_id: String) -> bool:
	return try_buy_camp(entry_id)

## Generator + gear + Quarry Plate (2).
func starting_hp_bonus() -> float:
	var hp_b := float(HangarDefs.shared_val("generator", "hp", camp_rank("generator"), 0)) + gear_stat("max_hp")
	if has_set("quarry_plate", 2):
		hp_b += float(GearDefs.SURVIVOR_SETS["quarry_plate"]["max_hp"])
	return hp_b

## Scrap Press + gear: more scrap per run.
func scrap_find_mult() -> float:
	return 1.0 + float(HangarDefs.shared_val("scrap_press", "scrap", camp_rank("scrap_press"), 0.0)) + gear_stat("scrap")

## Radio Tower: seconds earlier the next pads are revealed.
func pad_reveal_bonus() -> float:
	return float(HangarDefs.shared_val("radio_tower", "reveal", camp_rank("radio_tower"), 0.0))

func pad_ping_lead() -> float:
	return ModeDefs.PING_LEAD + pad_reveal_bonus()

## Ammo Bench: rank 1 lets special-ammo pickups drop for everyone.
func ammo_pickups_enabled() -> bool:
	return camp_rank("ammo_bench") >= 1

func ammo_pickup_types() -> Array:
	return HangarDefs.shared_val("ammo_bench", "types", camp_rank("ammo_bench"), [])

func ammo_duration_bonus() -> float:
	return float(HangarDefs.shared_val("ammo_bench", "duration", camp_rank("ammo_bench"), 0.0))

func ammo_odds_mult() -> float:
	return float(HangarDefs.shared_val("ammo_bench", "odds", camp_rank("ammo_bench"), 0.0))

## Survivor station + gear damage for the selected hero.
func starting_damage_bonus() -> float:
	return HangarDefs.station_weapon_damage(station_rank()) + gear_stat("damage")

## Ability dict for the selected hero with its station + survivor set applied.
func hero_ability() -> Dictionary:
	var a := HangarDefs.apply_station_ability(selected_character_id, get_character().get("ability", {}), station_rank())
	## Depth E5: the chosen ability version (B unlocks at the station).
	if kit_ability(selected_character_id) == "b":
		a = KitDefs.apply_ability(a, selected_character_id, "b")
	var ss: Dictionary = GearDefs.SURVIVOR_SETS
	if has_set("foremans_kit", 2) and a.has("cooldown"):
		a["cooldown"] = float(a["cooldown"]) * float(ss["foremans_kit"]["ability_cd"])
	if has_set("bell_ringers_shroud", 2):
		for k in ["coat_time", "cloud_time"]:
			if a.has(k):
				a[k] = float(a[k]) * float(ss["bell_ringers_shroud"]["ability_time"])
	if has_set("linemans_rig", 2) and a.has("stun"):
		a["stun"] = float(a["stun"]) * float(ss["linemans_rig"]["stun_mult"])
	if has_set("cathedral_vestments", 2) and a.has("heal"):
		a["heal"] = float(a["heal"]) * float(ss["cathedral_vestments"]["heal_mult"])
	if has_set("surgeons_coat", 2) and a.has("mark_mult"):
		a["mark_mult"] = float(a["mark_mult"]) * float(ss["surgeons_coat"]["mark_mult"])
	if has_set("foremans_kit", 3):
		a["charges"] = int(ss["foremans_kit"]["charges"])
	return a

## Gear-fed stats (retired v3 Hangar stats stay neutral).
func insurance_bonus_slots() -> int:
	return 0

func dash_cooldown_mult() -> float:
	var r := gear_stat("dash_cd")
	if has_set("night_runner", 4):
		r += float(GearDefs.GENERAL_SETS["night_runner"]["dash_cd"])
	if has_set("smugglers_wraps", 2):
		r += float(GearDefs.SURVIVOR_SETS["smugglers_wraps"]["dash_cd"])
	return maxf(0.45, 1.0 - r)

## Field Salvager (6): extract bonus per set piece worn.
func extract_payout_mult() -> float:
	if has_set("field_salvager", 6):
		return 1.0 + float(GearDefs.GENERAL_SETS["field_salvager"]["extract_per_piece"]) * float(set_count("field_salvager"))
	return 1.0

func endurance_iframe_mult() -> float:
	return 1.0

func crit_chance() -> float:
	return gear_stat("crit") + float(up("deadeye", "crit", 0.0))

func crit_damage_bonus() -> float:
	return (float(GearDefs.SURVIVOR_SETS["surgeons_coat"]["crit_bonus"]) if has_set("surgeons_coat", 2) else 0.0) \
		+ float(up("deadeye", "crit_damage", 0.0))

func aoe_damage_mult() -> float:
	return 1.0

func dodge_chance() -> float:
	return 0.0

func block_chance() -> float:
	return 0.0

func move_speed_bonus() -> float:
	var m := gear_stat("move")
	if has_set("night_runner", 2):
		m += float(GearDefs.GENERAL_SETS["night_runner"]["move"])
	return m

func pickup_radius_bonus() -> float:
	return gear_stat("pickup")

## Pet Bond levels (extracting with the dog close by) add pet damage.
func pet_power_mult() -> float:
	return 1.0 + EventDefs.BOND_DAMAGE_PER_LEVEL * float(bond_level(selected_pet_id))

func bond_level(pet_id: String) -> int:
	return mini(EventDefs.BOND_MAX_LEVEL, int(kennel_bond.get(pet_id, 0)) / EventDefs.BOND_XP_PER_LEVEL)

func loot_quality_bonus() -> float:
	return 0.0

func extract_grace_sec() -> float:
	return 0.0

## =============================================================================
## Gear: stash items, per-survivor loadouts, insurance, materials.

## Adds an item to the stash (assigns a uid). False when the stash is full.
func add_to_stash(item: Dictionary) -> bool:
	if stash.size() >= stash_capacity():
		return false
	var it := item.duplicate(true)
	it["uid"] = next_uid
	next_uid += 1
	it["new"] = true
	stash.append(it)
	return true

func stash_item(uid: int) -> Dictionary:
	for it in stash:
		if int(it.get("uid", -1)) == uid:
			return it
	return {}

func loadout_of(hero: String = "") -> Dictionary:
	var h := hero if hero != "" else selected_character_id
	if not loadouts.has(h):
		loadouts[h] = {}
	return loadouts[h]

## slot -> item for a survivor (missing / stale uids are skipped).
func equipped_items(hero: String = "") -> Dictionary:
	var out := {}
	var lo := loadout_of(hero)
	for sl in lo.keys():
		var it := stash_item(int(lo[sl]))
		if not it.is_empty():
			out[str(sl)] = it
	return out

## Which survivor (if any) has this item equipped, and in which slot.
func equipped_by(uid: int) -> Array:
	for h in loadouts.keys():
		var lo: Dictionary = loadouts[h]
		for sl in lo.keys():
			if int(lo[sl]) == uid:
				return [str(h), str(sl)]
	return []

## Equip a stash item; it leaves any other survivor / slot it was in.
func equip(hero: String, slot: String, uid: int) -> bool:
	var it := stash_item(uid)
	if it.is_empty() or not GearDefs.fits(it, slot, hero):
		return false
	var prev := equipped_by(uid)
	if not prev.is_empty():
		(loadouts[prev[0]] as Dictionary).erase(prev[1])
		if int(insured.get(prev[0], -1)) == uid and str(prev[0]) != hero:
			insured.erase(prev[0])
	loadout_of(hero)[slot] = uid
	it.erase("new")
	save_profile()
	return true

## Slot an item would go in for this survivor ("" if it can't be worn).
func slot_for(uid: int, hero: String = "") -> String:
	var h := hero if hero != "" else selected_character_id
	var it := stash_item(uid)
	if it.is_empty():
		return ""
	var kind := str(it.get("kind", ""))
	if kind == "weapon":
		return "weapon" if GearDefs.fits(it, "weapon", h) else ""
	if kind == "mod":
		if not GearDefs.fits(it, "mod1", h):
			return ""
		var lo := loadout_of(h)
		return "mod2" if lo.has("mod1") and not lo.has("mod2") else "mod1"
	var sl := str(it.get("slot", ""))
	return sl if sl != "" and GearDefs.fits(it, sl, h) else ""

## One-tap equip onto a survivor (defaults to the selected one).
func quick_equip(uid: int, hero: String = "") -> bool:
	var h := hero if hero != "" else selected_character_id
	var sl := slot_for(uid, h)
	return sl != "" and equip(h, sl, uid)

func unequip(hero: String, slot: String) -> void:
	var lo := loadout_of(hero)
	if lo.has(slot):
		if int(insured.get(hero, -1)) == int(lo[slot]):
			insured.erase(hero)
		lo.erase(slot)
		save_profile()

## Insure one equipped item for this survivor (uid -1 clears).
func set_insured(hero: String, uid: int) -> bool:
	if uid < 0:
		insured.erase(hero)
		save_profile()
		return true
	var by := equipped_by(uid)
	if by.is_empty() or str(by[0]) != hero:
		return false
	insured[hero] = uid
	save_profile()
	return true

func is_insured(uid: int) -> bool:
	for h in insured.keys():
		if int(insured[h]) == uid:
			return true
	return false

## Salvage a stash item for scrap (unequips it first). Locked items refuse.
## Every salvage lands in the buy-back bin (see buy_back).
func salvage(uid: int) -> int:
	var it := stash_item(uid)
	if it.is_empty() or bool(it.get("locked", false)):
		return 0
	var by := equipped_by(uid)
	if not by.is_empty():
		unequip(str(by[0]), str(by[1]))
	stash.erase(it)
	var v := GearDefs.salvage_value(it)
	account_scrap += v
	_bin_push(it, v)
	save_profile()
	meta_changed.emit()
	return v

## Recently salvaged (newest first): [{item, scrap}], at most SALVAGE_BIN_MAX.
const SALVAGE_BIN_MAX := 10
var salvage_bin: Array = []

## A full bin drops its oldest Common first, so a pile of bulk-salvaged
## commons never pushes a mistaken Legendary out of reach.
func _bin_push(it: Dictionary, scrap: int) -> void:
	var e := {"item": it.duplicate(true), "scrap": scrap}
	(e["item"] as Dictionary).erase("new")
	salvage_bin.push_front(e)
	while salvage_bin.size() > SALVAGE_BIN_MAX:
		var drop := -1
		for i in range(salvage_bin.size() - 1, -1, -1):
			var bi: Dictionary = salvage_bin[i]["item"]
			if str(bi.get("rarity", "common")) == "common" and str(bi.get("set", "")) == "":
				drop = i
				break
		salvage_bin.remove_at(drop if drop >= 0 else salvage_bin.size() - 1)

## Buy a salvaged item back for the scrap it paid. False without the scrap or room.
func buy_back(uid: int) -> bool:
	for i in range(salvage_bin.size()):
		var e: Dictionary = salvage_bin[i]
		var it: Dictionary = e["item"]
		if int(it.get("uid", -1)) != uid:
			continue
		var cost := int(e["scrap"])
		if account_scrap < cost or stash.size() >= stash_capacity() or not stash_item(uid).is_empty():
			return false
		account_scrap -= cost
		stash.append(it.duplicate(true))
		salvage_bin.remove_at(i)
		save_profile()
		meta_changed.emit()
		return true
	return false

## Can this item go in a bulk "salvage all commons"? Never locked, set,
## Epic / Legendary, worn or insured gear.
func bulk_salvageable(it: Dictionary) -> bool:
	var uid := int(it.get("uid", -1))
	return str(it.get("rarity", "")) == "common" and str(it.get("set", "")) == "" \
		and not bool(it.get("locked", false)) and str(it.get("legendary", "")) == "" \
		and equipped_by(uid).is_empty() and not is_insured(uid)

func bulk_salvage_preview() -> Array:
	var out: Array = []
	for it in stash:
		if bulk_salvageable(it):
			out.append(it)
	return out

## Salvage every bulk-safe Common. Returns {"count", "scrap"}.
func salvage_commons() -> Dictionary:
	var n := 0
	var total := 0
	for it in bulk_salvage_preview():
		var v := salvage(int(it["uid"]))
		if v > 0:
			n += 1
			total += v
	return {"count": n, "scrap": total}

func toggle_lock(uid: int) -> bool:
	var it := stash_item(uid)
	if it.is_empty():
		return false
	it["locked"] = not bool(it.get("locked", false))
	save_profile()
	return bool(it["locked"])

func is_locked(uid: int) -> bool:
	return bool(stash_item(uid).get("locked", false))

## Clears the NEW badge (inspected, previewed or equipped).
func mark_seen(uid: int) -> void:
	var it := stash_item(uid)
	if bool(it.get("new", false)):
		it.erase("new")

func new_count() -> int:
	var n := 0
	for it in stash:
		if bool(it.get("new", false)):
			n += 1
	return n

## Sorted + filtered stash. sort: rarity | slot | set | newest.
## filters: {"group": weapon|mod|armor|accessory|<slot>, "set": "any"|<set id>,
##   "rarity": <rarity>, "fits": <hero>} (missing / "" = no filter).
func stash_view(sort: String = "rarity", filters: Dictionary = {}) -> Array:
	var out: Array = []
	var g := str(filters.get("group", ""))
	var fs := str(filters.get("set", ""))
	var fr := str(filters.get("rarity", ""))
	var fh := str(filters.get("fits", ""))
	for it in stash:
		if g != "" and GearDefs.kind_of(it) != g and str(it.get("slot", "")) != g:
			continue
		if fs == "any" and str(it.get("set", "")) == "":
			continue
		if fs != "" and fs != "any" and str(it.get("set", "")) != fs:
			continue
		if fr != "" and str(it.get("rarity", "")) != fr:
			continue
		if fh != "" and slot_for(int(it.get("uid", -1)), fh) == "":
			continue
		out.append(it)
	var key := func(it: Dictionary) -> Array:
		var r := GearDefs.RARITIES.find(str(it.get("rarity", "common")))
		var sl := GearDefs.LOADOUT_SLOTS.find(str(it.get("slot", "")))
		if str(it.get("kind", "")) == "weapon":
			sl = 0
		elif str(it.get("kind", "")) == "mod":
			sl = 1
		var uid := int(it.get("uid", 0))
		match sort:
			"slot":
				return [sl, -r, -uid]
			"set":
				return [0 if str(it.get("set", "")) != "" else 1, str(it.get("set", "")), sl, -r, -uid]
			"newest":
				return [-uid]
		return [-r, sl, -uid]
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka: Array = key.call(a)
		var kb: Array = key.call(b)
		for i in range(ka.size()):
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	return out

## Set pieces this survivor wears, per set id (ignores Inert vials like _compute_gear).
func worn_set_counts(hero: String) -> Dictionary:
	var out := {}
	var eq := equipped_items(hero)
	for sl in eq.keys():
		var it: Dictionary = eq[sl]
		if not GearDefs.fits(it, str(sl), hero) or str(sl) in ["weapon", "mod1", "mod2"]:
			continue
		var sid := str(it.get("set", ""))
		if sid != "":
			out[sid] = int(out.get(sid, 0)) + 1
	return out

## Set progress if `it` went into its slot on `hero`: [{set, now, after, total}]
## for the item's set (up) and the replaced piece's set (down).
func set_progress(hero: String, it: Dictionary) -> Array:
	var out: Array = []
	var sl := slot_for(int(it.get("uid", -1)), hero)
	if sl == "":
		sl = str(it.get("slot", ""))
	var cur: Dictionary = equipped_items(hero).get(sl, {})
	if int(cur.get("uid", -2)) == int(it.get("uid", -1)):
		cur = {}
	var counts := worn_set_counts(hero)
	var sid := str(it.get("set", ""))
	var old := str(cur.get("set", ""))
	var worn := equipped_by(int(it.get("uid", -1)))
	var on_hero := not worn.is_empty() and str(worn[0]) == hero
	if sid != "":
		var now := int(counts.get(sid, 0))
		var after := now if on_hero or old == sid else now + 1
		out.append({"set": sid, "now": now, "after": after, "total": GearDefs.set_total(sid)})
	if old != "" and old != sid and not on_hero:
		var n2 := int(counts.get(old, 0))
		out.append({"set": old, "now": n2, "after": n2 - 1, "total": GearDefs.set_total(old)})
	return out

func material_count(id: String) -> int:
	return int(materials.get(id, 0))

## Awaken an Epic+ Vial with a Dust Heart.
func charge_vial(uid: int) -> bool:
	var it := stash_item(uid)
	if it.is_empty() or not bool(it.get("needs_heart", false)) or bool(it.get("charged", false)):
		return false
	if material_count("dust_heart") <= 0:
		return false
	materials["dust_heart"] = material_count("dust_heart") - 1
	it["charged"] = true
	save_profile()
	return true

## Totals for the current survivor's loadout (called on every deploy / loadout reset).
func _compute_gear() -> void:
	var stats := {}
	var sets := {}
	var mods: Array = []
	var witem: Dictionary = {}
	var vial_resist := 0.0
	var hero := selected_character_id
	var eq := equipped_items(hero)
	for sl in eq.keys():
		var it: Dictionary = eq[sl]
		if not GearDefs.fits(it, str(sl), hero):
			continue
		if str(sl) == "weapon":
			witem = it
			continue
		if str(sl) in ["mod1", "mod2"]:
			mods.append(it)
			continue
		if bool(it.get("needs_heart", false)) and not bool(it.get("charged", false)):
			continue
		var st: Dictionary = it.get("stats", {})
		for k in st.keys():
			stats[k] = float(stats.get(k, 0.0)) + float(st[k])
		if str(sl) == "vial":
			vial_resist += float(st.get("resist", 0.0)) + (0.1 if bool(it.get("charged", false)) else 0.0)
		var sid := str(it.get("set", ""))
		if sid != "":
			sets[sid] = int(sets.get(sid, 0)) + 1
	for k in stats.keys():
		if GearDefs.STAT_CAP.has(k):
			stats[k] = minf(float(stats[k]), float(GearDefs.STAT_CAP[k]))
	gear = {"stats": stats, "sets": sets, "mods": mods, "weapon_item": witem,
		"legendary": str(witem.get("legendary", "")), "vial_resist": vial_resist}

func gear_stat(id: String) -> float:
	var st: Variant = gear.get("stats", {})
	return float((st as Dictionary).get(id, 0.0)) if st is Dictionary else 0.0

func set_count(set_id: String) -> int:
	var sets: Variant = gear.get("sets", {})
	return int((sets as Dictionary).get(set_id, 0)) if sets is Dictionary else 0

## General sets count any wearer; survivor sets only on their survivor.
func has_set(set_id: String, pieces: int) -> bool:
	if GearDefs.SURVIVOR_SETS.has(set_id) and str(GearDefs.SURVIVOR_SETS[set_id]["hero"]) != selected_character_id:
		return false
	return set_count(set_id) >= pieces

func gear_legendary() -> String:
	return str(gear.get("legendary", ""))

func gear_luck() -> float:
	var l := gear_stat("luck")
	if has_set("field_salvager", 4):
		l += float(GearDefs.GENERAL_SETS["field_salvager"]["drop_luck"])
	return l

## In-run pickups: gear (kept on extract), materials, boss bonus + trophy.
func add_run_loot(item: Dictionary) -> void:
	run_loot.append(item.duplicate(true))
	quest_event("gear", 1)

func add_run_material(id: String, n: int) -> void:
	run_materials[id] = int(run_materials.get(id, 0)) + n

func on_boss_killed(kind: String) -> void:
	var add := clampf(GearDefs.BOSS_LOOT_BONUS_CAP - boss_loot_bonus, 0.0, GearDefs.BOSS_LOOT_BONUS)
	boss_loot_bonus += add
	loot_mult += add
	if not has_trophy(kind):
		trophies[kind] = true
		result_unlocks_pending.append("Trophy: first %s kill" % EnemyDefs.get_kind(kind).get("display_name", kind))

## Extract: found gear → stash (overflow salvaged), materials banked.
func _bank_run_loot() -> void:
	result_found = []
	result_salvaged = 0
	for it in run_loot:
		if add_to_stash(it):
			result_found.append(it)
		else:
			var v := int(round(float(GearDefs.salvage_value(it)) * GearDefs.OVERFLOW_SALVAGE))
			account_scrap += v
			result_salvaged += v
	for k in run_materials.keys():
		materials[k] = material_count(str(k)) + int(run_materials[k])
		result_unlocks.append("+%d %s" % [int(run_materials[k]), GearDefs.MATERIAL_NAME.get(str(k), str(k))])
	run_loot = []
	run_materials = {}
	_bank_pack()

## Death: found gear and brought-in gear are lost, except the insured item.
func _lose_run_loot() -> void:
	result_lost_items = run_loot.duplicate(true)
	var hero := selected_character_id
	var keep := int(insured.get(hero, -1))
	var eq := equipped_items(hero)
	for sl in eq.keys():
		var it: Dictionary = eq[sl]
		if int(it.get("uid", -1)) == keep:
			continue
		result_lost_items.append(it.duplicate(true))
		stash.erase(it)
		loadout_of(hero).erase(sl)
	run_loot = []
	run_materials = {}
	if run_pack_locked and not run_pack.is_empty():
		## Nyx's Pack Lock: the pack makes it home anyway.
		result_unlocks_pending.append("Pack Lock held — your pack made it home")
		_bank_pack_into_pending()
		return
	var lost_med := medicine_carried()
	if lost_med > 0:
		result_unlocks_pending.append("Lost %d medicine in the dust" % lost_med)
	run_pack = {}

func _bank_pack_into_pending() -> void:
	for k in run_pack.keys():
		ingredients[str(k)] = int(ingredients.get(str(k), 0)) + int(run_pack[k])
		result_unlocks_pending.append("+%d %s" % [int(run_pack[k]), MedicineDefs.item_name(str(k))])
	run_pack = {}

## =============================================================================
## Depth Update E1: backpack, medicine, ingredients, tonics, plague exposure.

func pack_capacity() -> int:
	return MedicineDefs.pack_capacity(camp_rank("backpack")) + int(quirk_fx("pack")) + int(pet.get("pack_bonus", 0))

func pack_weight() -> int:
	var w := 0
	for k in run_pack.keys():
		w += MedicineDefs.weight(str(k)) * int(run_pack[k])
	return w

func pack_has_room(id: String, n: int = 1) -> bool:
	return pack_weight() + MedicineDefs.weight(id) * n <= pack_capacity()

## Weightless ingredient pouch counts (id -> n) carried this run.
func pouch() -> Dictionary:
	var out := {}
	for k in run_pack.keys():
		if MedicineDefs.is_pouch(str(k)):
			out[str(k)] = int(run_pack[k])
	return out

func pack_count(id: String) -> int:
	return int(run_pack.get(id, 0))

## Into the backpack (false = no room).
func add_to_pack(id: String, n: int = 1) -> bool:
	if n <= 0 or not MedicineDefs.INGREDIENTS.has(id) or not pack_has_room(id, n):
		return false
	run_pack[id] = pack_count(id) + n
	if id == "medicine":
		quest_event("medicine", n)
	return true

func drop_from_pack(id: String, n: int = 1) -> bool:
	if pack_count(id) < n or n <= 0:
		return false
	run_pack[id] = pack_count(id) - n
	if int(run_pack[id]) <= 0:
		run_pack.erase(id)
	return true

func medicine_carried() -> int:
	return pack_count("medicine")

## Medicine slows you unless a Saint's Tincture was drunk.
func carry_speed_mult() -> float:
	## Campaign rescue / carry objectives: a patient or a crate on your back.
	if in_campaign_run() and campaign_carry_slow < 1.0:
		return campaign_carry_slow
	if tonic_fx("carry_free") > 0.0:
		return 1.0
	return MedicineDefs.carry_mult(medicine_carried())

## The plague can smell carried medicine (spawns + plague speed).
func smells_medicine() -> bool:
	return medicine_carried() > 0 and tonic_fx("carry_free") <= 0.0

## Extract: the pack goes home (medicine also pays through bag_value()).
func _bank_pack() -> void:
	## Contract rewards ride home with the pack.
	for k in run_job_rewards.keys():
		run_pack[k] = int(run_pack.get(k, 0)) + int(run_job_rewards[k])
	run_job_rewards = {}
	for k in run_pack.keys():
		var id := str(k)
		var n := int(run_pack[k])
		if n <= 0:
			continue
		ingredients[id] = int(ingredients.get(id, 0)) + n
		result_unlocks.append("+%d %s" % [n, MedicineDefs.item_name(id)])
	run_pack = {}

func ingredient_count(id: String) -> int:
	return int(ingredients.get(id, 0))

func tonic_count(id: String) -> int:
	return int(tonics.get(id, 0))

func tonic_slot_count() -> int:
	return MedicineDefs.tonic_slots(station_rank(CharacterDefs.CINDER_ID))

func can_brew(tid: String) -> bool:
	var r: Dictionary = (MedicineDefs.TONICS.get(tid, {}) as Dictionary).get("recipe", {})
	if r.is_empty():
		return false
	for k in r.keys():
		if ingredient_count(str(k)) < int(r[k]):
			return false
	return true

## Brew one batch at the Apothecary (Cinder's rank 4+ brews two).
func brew(tid: String) -> bool:
	if not can_brew(tid):
		return false
	var r: Dictionary = MedicineDefs.TONICS[tid]["recipe"]
	for k in r.keys():
		ingredients[str(k)] = ingredient_count(str(k)) - int(r[k])
		if int(ingredients[str(k)]) <= 0:
			ingredients.erase(str(k))
	tonics[tid] = tonic_count(tid) + MedicineDefs.brew_yield(station_rank(CharacterDefs.CINDER_ID))
	save_profile()
	meta_changed.emit()
	return true

## Put a tonic in (or take it out of) the slots for the next deploy.
func toggle_tonic(tid: String) -> bool:
	if tid in tonic_loadout:
		tonic_loadout.erase(tid)
		save_profile()
		return true
	if not MedicineDefs.TONICS.has(tid) or tonic_count(tid) <= 0:
		return false
	while tonic_loadout.size() >= tonic_slot_count():
		tonic_loadout.pop_front()
	tonic_loadout.append(tid)
	save_profile()
	return true

## On deploy: every slotted tonic in stock is drunk (stock −1) for this run.
func _drink_tonics() -> void:
	run_tonics = []
	## Campaign levels never spend the Wander tonic stock.
	if in_campaign_run():
		return
	var slots := tonic_slot_count()
	for tid in tonic_loadout.duplicate():
		if run_tonics.size() >= slots:
			break
		if tonic_count(str(tid)) <= 0:
			continue
		tonics[str(tid)] = tonic_count(str(tid)) - 1
		if int(tonics[str(tid)]) <= 0:
			tonics.erase(str(tid))
		run_tonics.append(str(tid))
	## Empty slots stay empty once the stock runs out.
	for tid in tonic_loadout.duplicate():
		if tonic_count(str(tid)) <= 0:
			tonic_loadout.erase(tid)

## Sum of a tonic effect over the tonics drunk this run.
func tonic_fx(key: String) -> float:
	var t := 0.0
	for tid in run_tonics:
		t += float(((MedicineDefs.TONICS.get(str(tid), {}) as Dictionary).get("fx", {}) as Dictionary).get(key, 0.0))
	return t

## Product of a multiplier effect (1.0 when none).
func tonic_fx_mult(key: String) -> float:
	var m := 1.0
	for tid in run_tonics:
		var fx: Dictionary = (MedicineDefs.TONICS.get(str(tid), {}) as Dictionary).get("fx", {})
		if fx.has(key):
			m *= float(fx[key])
	return m

func exposure_active() -> bool:
	if in_campaign_run():
		return false
	return int(get_mode().get("tier", 1)) >= MedicineDefs.EXPOSURE_FROM_TIER

## How fast exposure builds for this hero / kit (tonics, Cinder, gear resist).
func exposure_gain_mult() -> float:
	var m := tonic_fx_mult("exposure_mult")
	if quirk_fx("exposure_mult") > 0.0:
		m *= quirk_fx("exposure_mult")
	if selected_character_id == CharacterDefs.CINDER_ID:
		m *= MedicineDefs.CINDER_EXPOSURE_MULT
	## Vials (a charged one counts extra) and the Plague Doctor set.
	var vr := float(gear.get("vial_resist", 0.0)) + (0.25 if has_set("plague_doctor", 2) else 0.0)
	m *= 1.0 - minf(vr * 2.0, MedicineDefs.GEAR_RESIST_CAP)
	return m

func add_exposure(v: float) -> void:
	if not exposure_active() or run_finished:
		return
	exposure = clampf(exposure + v * exposure_gain_mult(), 0.0, MedicineDefs.EXPOSURE_MAX)

func cleanse_exposure(v: float) -> void:
	exposure = maxf(0.0, exposure - v)

## =============================================================================
## Logbook: daily quests, survivor stories, camp milestones, Pet Bond.

func today() -> String:
	return Time.get_date_string_from_system()

## Each tier unlocks after extracting on the one below (Part 5).
func highest_unlocked_tier() -> int:
	return clampi(maxi(ModeDefs.START_UNLOCKED, best_tier_extracted + 1), 1, ModeDefs.EXPOSED_TIERS)

func is_tier_unlocked(tier: int) -> bool:
	return tier <= highest_unlocked_tier()

## New quests each day.
func refresh_daily() -> void:
	var d := today()
	if str(daily.get("date", "")) != d or not (daily.get("quests", null) is Array):
		daily = {"date": d, "quests": QuestDefs.roll_daily(d, highest_unlocked_tier())}

func daily_quests() -> Array:
	refresh_daily()
	return daily["quests"]

func claim_daily(i: int) -> int:
	var qs := daily_quests()
	if i < 0 or i >= qs.size():
		return 0
	var q: Dictionary = qs[i]
	if bool(q.get("claimed", false)) or int(q.get("have", 0)) < int(q.get("need", 1)):
		return 0
	q["claimed"] = true
	var r := int(q.get("reward", 0))
	account_scrap += r
	save_profile()
	meta_changed.emit()
	return r

func story_state(hero: String) -> Dictionary:
	if not stories.has(hero):
		stories[hero] = {"step": 0, "have": 0}
	return stories[hero]

## Progress for dailies and the current survivor's story.
func quest_event(type: String, amount: int = 1, ctx: Dictionary = {}) -> void:
	for q in daily_quests():
		if bool(q.get("claimed", false)) or int(q.get("have", 0)) >= int(q.get("need", 1)):
			continue
		var add := QuestDefs.progress_amount(q, type, amount, ctx)
		if add > 0:
			q["have"] = mini(int(q["need"]), int(q.get("have", 0)) + add)
			if int(q["have"]) >= int(q["need"]):
				result_unlocks_pending.append("Daily done: %s" % str(q.get("label", "")))
	var hero := selected_character_id
	if not QuestDefs.STORIES.has(hero):
		return
	var st := story_state(hero)
	var step := int(st["step"])
	if step >= QuestDefs.STORY_STEPS.size():
		return
	var sd: Dictionary = QuestDefs.STORY_STEPS[step]
	var gain := QuestDefs.progress_amount(sd, type, amount, ctx)
	if gain <= 0:
		return
	st["have"] = int(st["have"]) + gain
	if int(st["have"]) >= int(sd["need"]):
		_complete_story_step(hero)

func _complete_story_step(hero: String) -> void:
	var st := story_state(hero)
	var step := int(st["step"])
	var sd: Dictionary = QuestDefs.STORY_STEPS[step]
	st["step"] = step + 1
	st["have"] = 0
	account_scrap += int(sd.get("reward", 0))
	var story := QuestDefs.story(hero)
	result_unlocks_pending.append("%s — chapter %d" % [str(story.get("title", "Story")), step + 1])
	if int(st["step"]) >= QuestDefs.STORY_STEPS.size():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var w := GearDefs.make_weapon(hero, "legendary", rng)
		if not add_to_stash(w):
			pending_rewards.append(w)
		result_unlocks_pending.append("Legendary earned: %s" % str(w.get("name", "")))

## Story Legendaries that waited for stash space.
func claim_pending_rewards() -> int:
	var n := 0
	while not pending_rewards.is_empty() and stash.size() < stash_capacity():
		add_to_stash(pending_rewards.pop_front())
		n += 1
	if n > 0:
		save_profile()
	return n

func add_bond(pet_id: String, xp: int) -> void:
	kennel_bond[pet_id] = int(kennel_bond.get(pet_id, 0)) + xp

## Marks newly reached milestones; returns them.
func check_milestones() -> Array:
	var out: Array = []
	for m in QuestDefs.MILESTONES:
		var id := str(m["id"])
		if bool(milestones.get(id, false)):
			continue
		if _milestone_progress(m) >= int(m["need"]):
			milestones[id] = true
			out.append(m)
	return out

func _milestone_progress(m: Dictionary) -> int:
	match str(m["check"]):
		"camp_rank":
			return camp_rank(str(m["key"]))
		"stations_min":
			var lo := 99
			for h in CharacterDefs.PLAYABLE_IDS:
				lo = mini(lo, station_rank(h))
			return lo
		"kennel_min":
			return mini(kennel_rank("noel"), mini(kennel_rank("bentley"), kennel_rank("lillie")))
		"extracts":
			return successful_extracts
		"legendary":
			for it in stash:
				if str(it.get("legendary", "")) != "":
					return 1
			return 0
		"trophy":
			return 1 if has_trophy(str(m["key"])) else 0
	return 0

func milestone_progress(id: String) -> int:
	return _milestone_progress(QuestDefs.milestone(id))

func has_cosmetic(c: String) -> bool:
	for m in QuestDefs.MILESTONES:
		if str(m.get("cosmetic", "")) == c and bool(milestones.get(str(m["id"]), false)):
			return true
	return false

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_profile()

func reset_profile() -> void:
	tutorial_done = false
	migrated_v3 = true
	account_scrap = 0
	account_xp = 0
	account_level = 1
	meta_upgrades.clear()
	camp.clear()
	stash.clear()
	salvage_bin.clear()
	trophies.clear()
	loadouts.clear()
	insured.clear()
	materials.clear()
	daily.clear()
	stories.clear()
	milestones.clear()
	kennel_bond.clear()
	pending_rewards.clear()
	ingredients.clear()
	tonics.clear()
	tonic_loadout.clear()
	bestiary.clear()
	lore_pages.clear()
	kit.clear()
	migrated_hangar_v4 = true
	garage_tokens = 0
	successful_extracts = 0
	best_payout = 0
	best_tier_extracted = 0
	total_runs = 0
	campaign = _fresh_campaign()
	save_profile()
	meta_changed.emit()

func get_mode() -> Dictionary:
	if in_campaign_run():
		return _campaign_mode()
	return ModeDefs.get_mode(selected_mode_id)

func get_character() -> Dictionary:
	return CharacterDefs.get_character(selected_character_id)

func reset_loadout_to_defaults() -> void:
	armor = LoadoutStubs.default_armor()
	## Kit follows the selected hero — never the old shared Scrap SMG.
	_compute_gear()
	weapon = HangarDefs.apply_station_weapon(selected_character_id,
		LoadoutStubs.weapon_for_character(selected_character_id), station_rank())
	weapon = KitDefs.apply_style(weapon, selected_character_id, kit_style(selected_character_id))
	weapon = GearDefs.apply_weapon(weapon, gear.get("weapon_item", {}), gear.get("mods", []))
	pet = HangarDefs.apply_kennel(LoadoutStubs.default_pet(selected_pet_id), kennel_rank())
	insured_slots.clear()
	var slots: int = int(get_mode().get("insurance_slots", 2)) + insurance_bonus_slots()
	slots = mini(slots, 3)
	if slots >= 1:
		insured_slots.append("weapon")
	if slots >= 2:
		insured_slots.append("pet")
	if slots >= 3:
		insured_slots.append("armor")
	loadout_changed.emit()

func begin_run() -> void:
	threat_level = 0
	windows_skipped = 0
	extract_windows_seen = 0
	loot_mult = 1.0
	scrap_found = 0
	kills = 0
	extracted = false
	wiped = false
	run_finished = false
	result_summary = ""
	last_phase_label = ""
	account_xp_this_run = 0
	payout_this_run = 0
	run_seed = int(Time.get_unix_time_from_system()) ^ (randi() << 1) ^ Time.get_ticks_msec()
	if run_seed == 0:
		run_seed = 1
	extract_pad_info = []
	run_loot = []
	run_materials = {}
	boss_loot_bonus = 0.0
	result_unlocks_pending = PackedStringArray()
	event_scrap_mult = 1.0
	event_enemy_damage = 1.0
	events_done_run = 0
	extract_bonus_scrap = 0
	extract_bonus_notes = PackedStringArray()
	run_pack = {}
	exposure = 0.0
	run_pack_locked = false
	run_job_rewards = {}
	run_keys = 0
	run_filter = 100.0
	run_has_cell = false
	jobs_done_run = 0
	_drink_tonics()
	## Reset in-run track completely.
	run_xp = 0
	run_level = 1
	_reset_run_cards()
	pending_run_choices.clear()
	run_level_paused = false
	_clear_result_meta()
	reset_loadout_to_defaults()
	run_reset.emit()
	run_xp_changed.emit(run_xp, run_level)

func _clear_result_meta() -> void:
	result_scrap_before = 0
	result_scrap_banked = 0
	result_scrap_lost = 0
	result_account_xp_before = 0
	result_account_level_before = 1
	result_levels_gained = 0
	result_run_level_reached = 1
	result_lost_keys = PackedStringArray()
	result_kept_keys = PackedStringArray()
	result_unlocks = PackedStringArray()
	result_found = []
	result_lost_items = []
	result_salvaged = 0

func on_window_skipped() -> void:
	windows_skipped += 1

## Called every frame by the match: multiplier from run time, Threat follows it.
func set_loot_mult(mult: float) -> void:
	loot_mult = mult + boss_loot_bonus
	threat_level = ModeDefs.threat_for_mult(mult)

## What the bag is worth right now (before the multiplier).
func bag_value() -> int:
	return int(round(ModeDefs.bag_curve(float(bag_raw()))))

## The bag before diminishing returns.
func bag_raw() -> int:
	return int(round(float(scrap_found) * ModeDefs.BAG_SCRAP_VALUE + float(kills) * ModeDefs.BAG_KILL_VALUE)) \
		+ medicine_carried() * MedicineDefs.MEDICINE_SCRAP

## Every find bonus (meta Scrap Press + gear, run Scavenger's Eye / Fortune /
## quirk / Field Salvager) adds up once, capped — no multiplicative stacking.
func total_find_mult() -> float:
	return minf(ModeDefs.FIND_MULT_CAP, scrap_find_mult() + run_scrap_mult() - 1.0)

## Add bag scrap with every find bonus applied.
func add_scrap(amount: int) -> int:
	var gained := maxi(0, int(round(float(amount) * total_find_mult() * event_scrap_mult)))
	scrap_found += gained
	return gained

## In-run XP → levels → upgrade picker. Does NOT become permanent power.
func add_run_xp(amount: int) -> void:
	if amount <= 0 or extracted or wiped:
		return
	if run_level >= Progression.RUN_LEVEL_CAP:
		run_xp_changed.emit(run_xp, run_level)
		return
	run_xp += amount
	var leveled := false
	while run_level < Progression.RUN_LEVEL_CAP and run_xp >= Progression.run_xp_to_next(run_level):
		run_xp -= Progression.run_xp_to_next(run_level)
		run_level += 1
		leveled = true
		var choices := Progression.roll_run_choices(UpgradeDefs.CHOICES_PER_LEVEL, [], consume_luck())
		pending_run_choices = choices
		run_level_paused = true
		run_level_up.emit(run_level, choices)
		## One pick UI per level; break so player chooses before next threshold.
		break
	run_xp_changed.emit(run_xp, run_level)
	if not leveled and run_level >= Progression.RUN_LEVEL_CAP:
		run_xp = 0

func apply_run_upgrade(upgrade: Dictionary) -> void:
	var stat := str(upgrade.get("stat", ""))
	var add := float(upgrade.get("add", 0.0))
	if run_mods.has(stat):
		run_mods[stat] = float(run_mods[stat]) + add
	var uid := str(upgrade.get("id", ""))
	if uid != "":
		run_ranks[uid] = mini(run_rank(uid) + 1, int(upgrade.get("max_rank", 3)))
		if uid not in run_picks_taken:
			run_picks_taken.append(uid)
		if uid == "lucky_vial":
			run_luck_charges = int(UpgradeDefs.val(uid, "charges", run_rank(uid), 0))
			run_luck = float(UpgradeDefs.val(uid, "luck", run_rank(uid), 1.0))
	pending_run_choices.clear()
	run_level_paused = false
	loadout_changed.emit()

func run_rank(id: String) -> int:
	return int(run_ranks.get(id, 0))

## Shorthand: an upgrade's value at the rank owned this run.
func up(id: String, key: String, default: Variant = 0.0) -> Variant:
	return UpgradeDefs.val(id, key, run_rank(id), default)

## Lucky Vial: returns the luck multiplier for this level-up (uses a charge).
func consume_luck() -> float:
	var charm := 1.0 + gear_stat("luck")
	if run_luck_charges <= 0:
		return charm
	run_luck_charges -= 1
	return run_luck * charm

func use_reroll() -> bool:
	if run_rerolls_left <= 0:
		return false
	run_rerolls_left -= 1
	return true

func note_kill(kind: String) -> void:
	run_kind_kills[kind] = int(run_kind_kills.get(kind, 0)) + 1
	var before := BestiaryDefs.stage_for(bestiary_kills(kind))
	bestiary[kind] = bestiary_kills(kind) + 1
	var after := BestiaryDefs.stage_for(bestiary_kills(kind))
	if after > before:
		result_unlocks_pending.append("Field Notes: %s — %s" % [str(EnemyDefs.get_kind(kind).get("display_name", kind)), str(BestiaryDefs.STAGE_NAME[after])])
	quest_event("kills", 1, {"kind": kind})

## Scavenger's Eye (+ Field Salvager 2) multiplier on kill scrap.
func run_scrap_mult() -> float:
	var m := 1.0 + float(up("scavengers_eye", "scrap", 0.0)) + float(up("fortune", "scrap", 0.0)) + quirk_fx("scrap")
	if has_set("field_salvager", 2):
		m += float(GearDefs.GENERAL_SETS["field_salvager"]["scrap"])
	return m

static func _fresh_run_mods() -> Dictionary:
	return {"damage": 0.0, "firerate": 0.0, "max_hp": 0.0, "move": 0.0, "mag": 0.0, "ability_cd": 0.0}

func _reset_run_cards() -> void:
	run_mods = _fresh_run_mods()
	run_picks_taken.clear()
	run_ranks.clear()
	run_rerolls_left = UpgradeDefs.REROLLS_PER_RUN
	run_luck_charges = 0
	run_luck = 1.0
	run_kind_kills.clear()
	run_ammo_seen.clear()

## A camp survivor's cameo was helped: their story moves on (a share of the chapter).
func cameo_help(hero: String) -> void:
	if not QuestDefs.STORIES.has(hero):
		return
	var st := story_state(hero)
	var step := int(st["step"])
	if step >= QuestDefs.STORY_STEPS.size():
		return
	var need := int(QuestDefs.STORY_STEPS[step]["need"])
	st["have"] = int(st["have"]) + maxi(1, int(ceil(float(need) * RadioDefs.CAMEO_STORY_SHARE)))
	result_unlocks_pending.append("%s's story moves on" % str(CharacterDefs.get_character(hero).get("display_name", hero)))
	if int(st["have"]) >= need:
		_complete_story_step(hero)

func add_job_reward(scrap: int, items: Dictionary) -> void:
	extract_bonus_scrap += scrap
	for k in items.keys():
		run_job_rewards[str(k)] = int(run_job_rewards.get(str(k), 0)) + int(items[k])
	jobs_done_run += 1
	quest_event("event")

func bestiary_kills(kind: String) -> int:
	return int(bestiary.get(kind, 0))

## Field Notes weak-spot bonus against a kind (kept across runs).
func bestiary_bonus(kind: String) -> float:
	return BestiaryDefs.damage_bonus(bestiary_kills(kind))

## A hidden lore page: kept at once (no need to extract). False if already found.
func find_page(id: String) -> bool:
	if lore_pages.has(id) or BestiaryDefs.page(id).is_empty():
		return false
	lore_pages[id] = true
	result_unlocks_pending.append("Lore page: %s" % str(BestiaryDefs.page(id)["title"]))
	save_profile()
	return true

func missing_pages() -> Array:
	var out: Array = []
	for p in BestiaryDefs.PAGES:
		if not lore_pages.has(str(p["id"])):
			out.append(str(p["id"]))
	return out

## =============================================================================
## Depth E5: loadout kit (weapon style, ability version, quirk) per survivor.

func kit_of(hero: String) -> Dictionary:
	if not kit.has(hero):
		var st: Array = KitDefs.styles(hero)
		kit[hero] = {"style": str(st[0]["id"]) if not st.is_empty() else "", "ability": "a", "quirk": ""}
	return kit[hero]

func kit_style(hero: String) -> String:
	var sid := str(kit_of(hero)["style"])
	## A style above the station rank (e.g. after a reset) falls back to the first.
	if not KitDefs.style_unlocked(hero, sid, station_rank(hero)):
		return str(KitDefs.styles(hero)[0]["id"])
	return sid

func kit_ability(hero: String) -> String:
	if station_rank(hero) < KitDefs.ABILITY_B_RANK:
		return "a"
	return str(kit_of(hero)["ability"])

func kit_quirk(hero: String) -> String:
	return str(kit_of(hero)["quirk"])

func set_style(hero: String, sid: String) -> bool:
	if not KitDefs.style_unlocked(hero, sid, station_rank(hero)) or str(KitDefs.style(hero, sid).get("id", "")) != sid:
		return false
	kit_of(hero)["style"] = sid
	_after_kit(hero)
	return true

func set_ability_version(hero: String, v: String) -> bool:
	if v == "b" and station_rank(hero) < KitDefs.ABILITY_B_RANK:
		return false
	kit_of(hero)["ability"] = "b" if v == "b" else "a"
	_after_kit(hero)
	return true

func set_quirk(hero: String, q: String) -> bool:
	if q != "" and not q in KitDefs.quirks(hero):
		return false
	kit_of(hero)["quirk"] = q
	_after_kit(hero)
	return true

func _after_kit(hero: String) -> void:
	if hero == selected_character_id:
		reset_loadout_to_defaults()
	save_profile()

## Quirk effect for the survivor being played (0 when none).
func quirk_fx(key: String) -> float:
	var q := KitDefs.quirk(kit_quirk(selected_character_id))
	if q.is_empty():
		return 0.0
	if bool(q.get("ranged", false)) and weapon.has("melee"):
		return 0.0
	return float((q.get("fx", {}) as Dictionary).get(key, 0.0))

## An evolution (RecipeDefs) owned this run.
func has_evo(id: String) -> bool:
	return run_rank(id) > 0

## Flat extract bonuses (radio jobs, Ambush Bounty) as paid on this tier.
func extract_bonus_payout() -> int:
	return int(round(float(extract_bonus_scrap) * float(get_mode()["payout_mult"]) * ModeDefs.BONUS_SCALE))

func on_extract_success() -> void:
	if run_finished:
		return
	run_finished = true
	extracted = true
	wiped = false
	_clear_result_meta()
	var mode := get_mode()
	## Extract pays the full bag (plus a small stipend) × loot multiplier × tier
	## payout; flat bonuses (jobs, Ambush Bounty) scale with the tier (ModeDefs).
	var base := ModeDefs.BAG_STIPEND + bag_value()
	payout_this_run = int(
		base * loot_mult * float(mode["payout_mult"]) * extract_payout_mult() * (1.0 + pact_loot_bonus())
	) + extract_bonus_payout()
	if pact_loot_bonus() > 0.0:
		result_unlocks_pending.append("Dust Pacts: payout +%d%%" % int(round(pact_loot_bonus() * 100.0)))
	_record_tier_clear(int(mode.get("tier", 1)))
	result_scrap_before = account_scrap
	account_scrap += payout_this_run
	result_scrap_banked = payout_this_run
	result_scrap_lost = 0
	garage_tokens += maxi(1, payout_this_run / 50)
	## Soft prestige XP (not spend power).
	result_account_xp_before = account_xp
	result_account_level_before = account_level
	account_xp_this_run = Progression.award_extract_account_xp(
		kills, loot_mult, float(mode["payout_mult"])
	)
	account_xp += account_xp_this_run
	var new_lv := Progression.account_level_from_xp(account_xp)
	result_levels_gained = maxi(0, new_lv - result_account_level_before)
	_sync_account_level()
	result_run_level_reached = run_level
	successful_extracts += 1
	if result_levels_gained > 0:
		result_unlocks.append("Account prestige Lv %d (Hangar gates)" % account_level)
	_bank_run_loot()
	result_unlocks.append_array(extract_bonus_notes)
	quest_event("extract", 1, {"tier": int(mode.get("tier", 1)), "mult": loot_mult})
	var tier_n := int(mode.get("tier", 1))
	if tier_n > best_tier_extracted:
		var before := highest_unlocked_tier()
		best_tier_extracted = tier_n
		if highest_unlocked_tier() > before:
			result_unlocks.append("New tier unlocked: %s" % str(ModeDefs.tier_mode(highest_unlocked_tier()).get("display_name", "")))
	result_unlocks.append_array(result_unlocks_pending)
	result_unlocks_pending = PackedStringArray()
	result_summary = "Extracted. +%d scrap banked (×%.1f loot) · run Lv %d · Threat %d" % [
		payout_this_run, loot_mult, run_level, threat_level,
	]
	best_payout = maxi(best_payout, payout_this_run)
	total_runs += 1
	## In-run power dies here — only banked scrap/meta remain.
	_reset_run_power_after_end()
	for m in check_milestones():
		result_unlocks.append("Milestone: %s" % str(m["name"]))
	save_profile()

func on_wipe() -> void:
	if run_finished:
		return
	run_finished = true
	extracted = false
	wiped = true
	_clear_result_meta()
	var mode := get_mode()
	result_scrap_before = account_scrap
	## Death keeps a slice of the carried bag (Haze 10%, Drift 15%), no multiplier.
	var keep := int(round(float(bag_value()) * float(mode.get("death_keep", 0.1))))
	account_scrap += keep
	result_scrap_banked = keep
	result_scrap_lost = maxi(0, bag_value() - keep)
	result_account_xp_before = account_xp
	result_account_level_before = account_level
	account_xp_this_run = Progression.award_wipe_account_xp(kills, float(mode["payout_mult"]))
	account_xp += account_xp_this_run
	var new_lv := Progression.account_level_from_xp(account_xp)
	result_levels_gained = maxi(0, new_lv - result_account_level_before)
	_sync_account_level()
	result_run_level_reached = run_level
	payout_this_run = keep
	if result_levels_gained > 0:
		result_unlocks.append("Account prestige Lv %d" % account_level)
	var kept_item := stash_item(int(insured.get(selected_character_id, -1)))
	_lose_run_loot()
	result_unlocks.append_array(result_unlocks_pending)
	result_unlocks_pending = PackedStringArray()
	result_lost_keys = PackedStringArray()
	result_kept_keys = PackedStringArray()
	for it in result_lost_items:
		result_lost_keys.append(str(it.get("name", "item")))
	if not kept_item.is_empty():
		result_kept_keys.append(str(kept_item.get("name", "item")))
	result_summary = "Wiped. Kept %d%% of the bag (+%d scrap). Lost %d. Lost gear: %s" % [
		int(round(float(mode.get("death_keep", 0.1)) * 100.0)),
		keep,
		result_scrap_lost,
		", ".join(result_lost_keys) if result_lost_keys.size() else "(nothing)",
	]
	total_runs += 1
	_reset_run_power_after_end()
	for m in check_milestones():
		result_unlocks.append("Milestone: %s" % str(m["name"]))
	save_profile()

func _reset_run_power_after_end() -> void:
	## Permanent power never comes from run levels — clear after banking rewards.
	run_xp = 0
	_reset_run_cards()
	pending_run_choices.clear()
	run_level_paused = false

func timer_scale() -> float:
	return FAST_TIMER_SCALE if fast_timers else 1.0

func go_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	leave_campaign_run()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func go_mode_select() -> void:
	leave_campaign_run()
	play_mode = "wander"
	get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")

func go_character_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

## Pre-run LOADOUT (style / ability / quirk / tonics) between select and the match.
func go_prep() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/prep.tscn")

func go_how_to_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/how_to_play.tscn")

func go_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

## Gear screen; `from` = "hangar" | "character_select" | "prep" (where BACK / DONE go).
var loadout_from: String = "hangar"

func go_loadout(from: String = "hangar") -> void:
	loadout_from = from
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/loadout.tscn")

func go_logbook() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/logbook.tscn")

func go_hangar() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	leave_campaign_run()
	get_tree().change_scene_to_file("res://scenes/ui/hangar.tscn")

func go_match() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	save_profile()
	begin_run()
	get_tree().change_scene_to_file("res://scenes/match/match.tscn")

func go_result() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	TouchInput.clear_sticks()
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")


## =============================================================================
## CAMPAIGN — Act One: The Long Dust (scripts/data/campaign_defs.gd).
## Wander (the endless extraction runs) is untouched: the campaign keeps its own
## progress under "campaign" in the save and only ever ADDS to the shared camp
## (hangar features the story introduces, scrap, gear). Old saves load with a
## fresh campaign.

const CAMPAIGN_V := 1
var campaign: Dictionary = _fresh_campaign()
## "wander" | "campaign": which mode the current run belongs to (never saved).
var play_mode: String = "wander"
var campaign_level_id: String = ""
## Choices made during the current attempt; committed only when it succeeds.
var campaign_run_flags: Dictionary = {}
## Tests / bots: story scenes and cards advance on their own. The outro /
## fail cards only pick (and change scene) with campaign_autoplay_exit.
var campaign_autoplay: bool = false
var campaign_autoplay_exit: bool = false
## Speed multiplier while carrying something in a campaign level (1 = free).
var campaign_carry_slow: float = 1.0
## Level-end summary for the outro card.
var campaign_result: Dictionary = {}
var _wander_hero: String = ""
var _wander_pet: String = ""
var _campaign_mode_cache: Dictionary = {}
var _campaign_mode_for: String = ""


func _fresh_campaign() -> Dictionary:
	return {"v": CAMPAIGN_V, "done": {}, "flags": {}, "roster": [], "pets": [], "parts": [], "last": "", "picks": {}}


## Sanitised load: unknown levels / heroes / pets dropped, wrong types ignored.
func _load_campaign(v: Variant) -> void:
	campaign = _fresh_campaign()
	if typeof(v) != TYPE_DICTIONARY:
		return
	var d: Dictionary = v
	var done := _dict_or_empty(d.get("done", {}))
	for k in done.keys():
		if CampaignDefs.has_level(str(k)) and typeof(done[k]) == TYPE_DICTIONARY:
			var e: Dictionary = done[k]
			campaign["done"][str(k)] = {"best": maxf(0.0, float(e.get("best", 0.0))), "runs": maxi(1, int(e.get("runs", 1)))}
	var fl := _dict_or_empty(d.get("flags", {}))
	for k in fl.keys():
		var fv: Variant = fl[k]
		if typeof(fv) == TYPE_FLOAT and float(fv) == floorf(float(fv)):
			fv = int(fv)
		if typeof(fv) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
			campaign["flags"][str(k)] = fv
	for key in ["roster", "pets", "parts"]:
		var arr: Variant = d.get(key, [])
		if typeof(arr) != TYPE_ARRAY:
			continue
		for it in (arr as Array):
			var id := str(it)
			var ok := false
			match key:
				"roster":
					ok = CharacterDefs.is_playable(id)
				"pets":
					ok = PetDefs.is_equipable(id)
				"parts":
					ok = CampaignDefs.PLANE_PARTS.has(id)
			if ok and not id in (campaign[key] as Array):
				(campaign[key] as Array).append(id)
	var last := str(d.get("last", ""))
	if CampaignDefs.has_level(last):
		campaign["last"] = last
	var pk := _dict_or_empty(d.get("picks", {}))
	for k in pk.keys():
		if CampaignDefs.has_level(str(k)) and CharacterDefs.is_playable(str(pk[k])):
			campaign["picks"][str(k)] = str(pk[k])


func in_campaign_run() -> bool:
	return play_mode == "campaign" and campaign_level_id != ""


func campaign_level() -> Dictionary:
	return CampaignDefs.level(campaign_level_id)


## The run's "mode" in a campaign level: the zone tier's table (visuals,
## pacing numbers) with the level's own enemy strength.
func _campaign_mode() -> Dictionary:
	if _campaign_mode_for == campaign_level_id and not _campaign_mode_cache.is_empty():
		return _campaign_mode_cache
	var lv := campaign_level()
	var m := ModeDefs.tier_mode(int(lv.get("tier", 1)))
	m["id"] = "campaign"
	m["display_name"] = str(lv.get("title", "Campaign"))
	m["enemy_hp"] = float(lv.get("enemy_hp", 1.0))
	m["enemy_damage"] = float(lv.get("enemy_damage", 1.0))
	m["spawn_density"] = 1.0
	_campaign_mode_cache = m
	_campaign_mode_for = campaign_level_id
	return m


## Flag lookup: this attempt's choices first, then the saved story.
func campaign_flag(key: String, default: Variant = null) -> Variant:
	if campaign_run_flags.has(key):
		return campaign_run_flags[key]
	return (campaign["flags"] as Dictionary).get(key, default)


func set_campaign_flag(key: String, value: Variant) -> void:
	campaign_run_flags[key] = value


## Does the flag match? A bare key (value null) means "set and truthy".
func campaign_flag_is(key: String, value: Variant = null) -> bool:
	var f: Variant = campaign_flag(key, null)
	if value == null:
		return f != null and bool(f) if typeof(f) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else f != null and str(f) != ""
	if f == null:
		return false
	if typeof(value) == TYPE_STRING or typeof(f) == TYPE_STRING:
		return str(f) == str(value)
	return f == value


func campaign_level_done(id: String) -> bool:
	return (campaign["done"] as Dictionary).has(id)


## The first level is always open; each next one after the one before it.
func campaign_level_unlocked(id: String) -> bool:
	if not CampaignDefs.is_playable(id):
		return false
	var i := CampaignDefs.ORDER.find(id)
	if i <= 0:
		return i == 0
	return campaign_level_done(str(CampaignDefs.ORDER[i - 1]))


func campaign_done_count() -> int:
	return (campaign["done"] as Dictionary).size()


## The level the PLAY button continues with (first not done, else the last).
func campaign_next_level() -> String:
	for id in CampaignDefs.ORDER:
		if CampaignDefs.is_playable(str(id)) and not campaign_level_done(str(id)):
			return str(id)
	return str(campaign.get("last", CampaignDefs.ORDER[0])) if str(campaign.get("last", "")) != "" else str(CampaignDefs.ORDER[0])


func campaign_fallen(hero: String) -> bool:
	return campaign_flag_is("fallen_" + hero)


func campaign_has_survivor(hero: String) -> bool:
	return hero in (campaign["roster"] as Array) and not campaign_fallen(hero)


func campaign_roster() -> Array:
	var out: Array = []
	for h in CharacterDefs.PLAYABLE_IDS:
		if campaign_has_survivor(str(h)):
			out.append(str(h))
	return out


## Heroes the player may take into a level (forced hero = just that one).
func campaign_heroes_for(id: String) -> Array:
	var lv := CampaignDefs.level(id)
	if str(lv.get("hero", "")) != "":
		return [str(lv["hero"])]
	var allowed: Array = lv.get("heroes", [])
	var out: Array = []
	for h in campaign_roster():
		if allowed.is_empty() or h in allowed:
			out.append(h)
	if out.is_empty():
		out.append(CharacterDefs.HELM_WISP_ID)
	return out


func campaign_pick_for(id: String) -> String:
	var opts := campaign_heroes_for(id)
	var p := str((campaign["picks"] as Dictionary).get(id, ""))
	if p in opts:
		return p
	return str(opts[0])


## The dog that comes along: forced by the level ("" = none), else the
## player's Wander pick if the story has met that dog, else the first met.
func campaign_pet_for(id: String) -> String:
	var lv := CampaignDefs.level(id)
	if lv.has("pet"):
		return str(lv["pet"])
	var pets: Array = campaign["pets"]
	var want := _wander_pet if _wander_pet != "" else selected_pet_id
	if want in pets:
		return want
	return str(pets[0]) if not pets.is_empty() else ""


func campaign_set_pick(id: String, hero: String) -> void:
	if hero in campaign_heroes_for(id):
		campaign["picks"][id] = hero
		save_profile()


## Leaving a campaign level (to a menu): the Wander hero / pet come back.
func leave_campaign_run() -> void:
	if play_mode != "campaign":
		return
	if _wander_hero != "":
		selected_character_id = _wander_hero
	if _wander_pet != "":
		selected_pet_id = _wander_pet
	_wander_hero = ""
	_wander_pet = ""
	play_mode = "wander"
	campaign_level_id = ""
	campaign_run_flags = {}
	campaign_carry_slow = 1.0
	_campaign_mode_cache = {}
	reset_loadout_to_defaults()


## Start (or retry) a campaign level as `hero` ("" = the remembered pick).
func go_campaign_level(id: String, hero: String = "") -> void:
	if not prepare_campaign_level(id, hero):
		return
	get_tree().change_scene_to_file(CampaignDefs.MATCH_SCENE)


## Everything a level needs before its scene loads (tests instantiate the
## scene themselves after this).
func prepare_campaign_level(id: String, hero: String = "") -> bool:
	if not CampaignDefs.is_playable(id):
		return false
	if play_mode != "campaign" or _wander_hero == "":
		_wander_hero = selected_character_id
		_wander_pet = selected_pet_id
	play_mode = "campaign"
	campaign_level_id = id
	_campaign_mode_cache = {}
	campaign_run_flags = {}
	campaign_result = {}
	campaign_carry_slow = 1.0
	var h := hero if hero in campaign_heroes_for(id) else campaign_pick_for(id)
	selected_character_id = h
	var pid := campaign_pet_for(id)
	if pid != "":
		selected_pet_id = pid
	get_tree().paused = false
	Engine.time_scale = 1.0
	TouchInput.clear_sticks()
	begin_run()
	if pid == "":
		pet["active"] = false
	return true


func go_mode_choice() -> void:
	get_tree().paused = false
	leave_campaign_run()
	get_tree().change_scene_to_file("res://scenes/ui/mode_choice.tscn")


func go_campaign_map() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	leave_campaign_run()
	TouchInput.clear_sticks()
	get_tree().change_scene_to_file("res://scenes/ui/campaign_map.tscn")


## Level won (the hero extracted): scrap found + the level's reward, gear to
## the stash, first-clear story rewards (survivors, dogs, plane parts, hangar
## features), choices committed. Returns the outro summary.
func complete_campaign_level(time_s: float) -> Dictionary:
	if run_finished:
		return campaign_result
	run_finished = true
	extracted = true
	wiped = false
	_clear_result_meta()
	var id := campaign_level_id
	var lv := campaign_level()
	var first := not campaign_level_done(id)
	var rw: Dictionary = lv.get("rewards", {})
	var lines := PackedStringArray()
	## Choices made this attempt become the story.
	for k in campaign_run_flags.keys():
		campaign["flags"][k] = campaign_run_flags[k]
	for k in (rw.get("flags", {}) as Dictionary).keys():
		campaign["flags"][str(k)] = rw["flags"][k]
	campaign_run_flags = {}
	var prev: Dictionary = (campaign["done"] as Dictionary).get(id, {})
	var best := float(prev.get("best", 0.0))
	campaign["done"][id] = {"best": time_s if best <= 0.0 else minf(best, time_s), "runs": int(prev.get("runs", 0)) + 1}
	var base := int(rw.get("scrap", 100))
	var paid := bag_value() + (base if first else int(round(base * CampaignDefs.REPLAY_SCRAP)))
	result_scrap_before = account_scrap
	account_scrap += paid
	payout_this_run = paid
	result_scrap_banked = paid
	lines.append("+%d scrap" % paid)
	result_account_xp_before = account_xp
	account_xp_this_run = Progression.award_extract_account_xp(kills, 1.0, 1.0)
	account_xp += account_xp_this_run
	_sync_account_level()
	var joined: Array = []
	var dogs: Array = []
	if first:
		for h in rw.get("survivors", []):
			if CharacterDefs.is_playable(str(h)) and not str(h) in (campaign["roster"] as Array):
				campaign["roster"].append(str(h))
				joined.append(str(h))
				lines.append("%s joins the camp" % str(CharacterDefs.get_character(str(h)).get("display_name", h)))
		for p in rw.get("pets", []):
			if PetDefs.is_equipable(str(p)) and not str(p) in (campaign["pets"] as Array):
				campaign["pets"].append(str(p))
				dogs.append(str(p))
				lines.append("%s is home" % str(PetDefs.get_pet(str(p)).get("name", p)))
		var part := str(rw.get("part", ""))
		if part != "" and CampaignDefs.PLANE_PARTS.has(part) and not part in (campaign["parts"] as Array):
			campaign["parts"].append(part)
			lines.append("Plane part: %s" % str(CampaignDefs.PLANE_PARTS[part]["name"]))
		## Hangar features the story introduces: a floor, never a refund.
		var cp: Dictionary = rw.get("camp", {})
		for k in cp.keys():
			var want := int(cp[k])
			if HangarDefs.layer_of(str(k)) != "" and camp_rank(str(k)) < want:
				camp[str(k)] = want
				lines.append("Hangar: %s rank %d" % [str(HangarDefs.SHARED.get(str(k), {}).get("name", k)), want])
	## Survivors always in the camp from the start of the story.
	_bank_run_loot()
	for it in result_found:
		lines.append("Gear: %s" % str(it.get("name", "item")))
	var nxt := CampaignDefs.next_level(id)
	campaign["last"] = nxt if nxt != "" else id
	result_summary = "%s complete" % str(lv.get("title", ""))
	_reset_run_power_after_end()
	campaign_result = {"id": id, "won": true, "first": first, "time": time_s, "scrap": paid,
		"lines": lines, "joined": joined, "pets": dogs, "next": nxt}
	quest_event("extract", 1, {"tier": int(lv.get("tier", 1)), "mult": 1.0})
	save_profile()
	return campaign_result


## Level lost: nothing is banked or lost (gear and the pack stay home safe);
## this attempt's choices are forgotten so a retry can choose again.
func fail_campaign_level(reason: String) -> Dictionary:
	if run_finished:
		return campaign_result
	run_finished = true
	wiped = true
	extracted = false
	_clear_result_meta()
	campaign_run_flags = {}
	run_loot = []
	run_materials = {}
	run_pack = {}
	_reset_run_power_after_end()
	campaign_result = {"id": campaign_level_id, "won": false, "reason": reason, "lines": PackedStringArray()}
	return campaign_result


## Admin / tests: mark levels done up to (not including) `id`, with a roster.
func campaign_debug_unlock_to(id: String) -> void:
	for lid in CampaignDefs.ORDER:
		if str(lid) == id:
			break
		if not campaign_level_done(str(lid)):
			campaign["done"][str(lid)] = {"best": 0.0, "runs": 1}
		var rw: Dictionary = CampaignDefs.level(str(lid)).get("rewards", {})
		for h in rw.get("survivors", []):
			if not str(h) in (campaign["roster"] as Array):
				campaign["roster"].append(str(h))
		for p in rw.get("pets", []):
			if not str(p) in (campaign["pets"] as Array):
				campaign["pets"].append(str(p))
	save_profile()
