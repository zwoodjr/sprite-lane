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


## Player settings + onboarding flags (persisted to user://).
const SAVE_PATH := "user://wanderer_save.json"
const SAVE_VERSION := 4
var settings: Dictionary = {
	"sfx": true,
	"haptics": true,
	"screen_shake": true,
	"stick_scale": 1.0,
	"left_handed": false,
	"show_hints": true,
	"heat_shimmer": false,
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
		"selected_character_id": selected_character_id,
		"selected_pet_id": selected_pet_id,
		"ingredients": ingredients,
		"tonics": tonics,
		"tonic_loadout": tonic_loadout,
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
	var c := camp_cost(id)
	if c < 0 or account_scrap < c:
		return false
	account_scrap -= c
	camp[id] = camp_rank(id) + 1
	save_profile()
	meta_changed.emit()
	return true

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
	return gear_stat("crit")

func crit_damage_bonus() -> float:
	return float(GearDefs.SURVIVOR_SETS["surgeons_coat"]["crit_bonus"]) if has_set("surgeons_coat", 2) else 0.0

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

## Salvage a stash item for scrap (unequips it first).
func salvage(uid: int) -> int:
	var it := stash_item(uid)
	if it.is_empty():
		return 0
	var by := equipped_by(uid)
	if not by.is_empty():
		unequip(str(by[0]), str(by[1]))
	stash.erase(it)
	var v := GearDefs.salvage_value(it)
	account_scrap += v
	save_profile()
	meta_changed.emit()
	return v

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
	boss_loot_bonus += GearDefs.BOSS_LOOT_BONUS
	loot_mult += GearDefs.BOSS_LOOT_BONUS
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
	var lost_med := medicine_carried()
	if lost_med > 0:
		result_unlocks_pending.append("Lost %d medicine in the dust" % lost_med)
	run_pack = {}

## =============================================================================
## Depth Update E1: backpack, medicine, ingredients, tonics, plague exposure.

func pack_capacity() -> int:
	return MedicineDefs.pack_capacity(camp_rank("backpack"))

func pack_weight() -> int:
	var w := 0
	for k in run_pack.keys():
		w += MedicineDefs.weight(str(k)) * int(run_pack[k])
	return w

func pack_has_room(id: String, n: int = 1) -> bool:
	return pack_weight() + MedicineDefs.weight(id) * n <= pack_capacity()

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
	if tonic_fx("carry_free") > 0.0:
		return 1.0
	return MedicineDefs.carry_mult(medicine_carried())

## The plague can smell carried medicine (spawns + plague speed).
func smells_medicine() -> bool:
	return medicine_carried() > 0 and tonic_fx("carry_free") <= 0.0

## Extract: the pack goes home (medicine also pays through bag_value()).
func _bank_pack() -> void:
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
	return int(get_mode().get("tier", 1)) >= MedicineDefs.EXPOSURE_FROM_TIER

## How fast exposure builds for this hero / kit (tonics, Cinder, gear resist).
func exposure_gain_mult() -> float:
	var m := tonic_fx_mult("exposure_mult")
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
	migrated_hangar_v4 = true
	garage_tokens = 0
	successful_extracts = 0
	best_payout = 0
	best_tier_extracted = 0
	total_runs = 0
	save_profile()
	meta_changed.emit()

func get_mode() -> Dictionary:
	return ModeDefs.get_mode(selected_mode_id)

func get_character() -> Dictionary:
	return CharacterDefs.get_character(selected_character_id)

func reset_loadout_to_defaults() -> void:
	armor = LoadoutStubs.default_armor()
	## Kit follows the selected hero — never the old shared Scrap SMG.
	_compute_gear()
	weapon = HangarDefs.apply_station_weapon(selected_character_id,
		LoadoutStubs.weapon_for_character(selected_character_id), station_rank())
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
	return scrap_found * 2 + kills * 5 + medicine_carried() * MedicineDefs.MEDICINE_SCRAP

## Add bag scrap with meta magnet applied.
func add_scrap(amount: int) -> int:
	var gained := maxi(0, int(round(float(amount) * scrap_find_mult() * event_scrap_mult)))
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
	quest_event("kills", 1, {"kind": kind})

## Scavenger's Eye (+ Field Salvager 2) multiplier on kill scrap.
func run_scrap_mult() -> float:
	var m := 1.0 + float(up("scavengers_eye", "scrap", 0.0))
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

func on_extract_success() -> void:
	if run_finished:
		return
	run_finished = true
	extracted = true
	wiped = false
	_clear_result_meta()
	var mode := get_mode()
	## Extract pays the full bag (plus a 100 scrap stipend) × loot multiplier.
	var base := 100 + bag_value()
	payout_this_run = int(
		base * loot_mult * float(mode["payout_mult"]) * extract_payout_mult()
	) + extract_bonus_scrap
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
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func go_mode_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")

func go_character_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func go_how_to_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/how_to_play.tscn")

func go_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

## Gear screen; `from` = "hangar" | "character_select" (where BACK / DONE go).
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
