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
## Loot v2: Commons auto-salvaged on extract (setting) and stash-full overflow.
var result_auto_salvaged_n: int = 0
var result_auto_salvaged_scrap: int = 0
var result_overflow_n: int = 0
## Rare+ (and set) finds that didn't fit a full stash: held in pending_rewards
## until there's room (never salvaged silently).
var result_held_n: int = 0
## Bank total once every result payout landed (payout, salvage, quest rewards).
## -1 = not snapshotted (the result screen falls back to account_scrap).
var result_scrap_after: int = -1
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
## {part id: true} (ZoneDefs.PLANE_PARTS: the ONE tracker Wander and the
## Campaign both write), Dust Pacts picked for the next run, and run-only zone state.
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
## Rolling backup (the save before the latest) + where an unreadable save is kept.
const SAVE_BAK_PATH := "user://wanderer_save.bak"
const SAVE_DAMAGED_PATH := "user://wanderer_save.damaged.json"
## Live-run snapshot (written while a run is in progress; gone once it ends).
const RUN_PATH := "user://wanderer_run.json"
const LIVE_SNAPSHOT_SEC := 12.0
## "main" | "temp" | "backup" | "fresh" | "reset" — where the profile came from.
var load_source: String = ""
## One-time line for the main menu (save restored from backup, etc.).
var load_notice: String = ""
var _main_save_ok: bool = false
## Live-run marker, saved in the profile while a run is in progress:
## {"id", "mode" wander|campaign, "level", "tier_mode", "hero", "pet", "started"}.
## A marker left over at launch means the app was closed mid-run.
var live_run: Dictionary = {}
## Match bits of a snapshot being resumed (read by the controller's _ready).
var pending_resume: Dictionary = {}
var _live_ctrl: WeakRef = null
var _live_accum: float = 0.0
## Defaults + Settings layout live in SettingsDefs (migrated on load).
var settings: Dictionary = _default_settings()
## A setting changed through set_setting() (already applied live).
signal settings_changed(key: String)
var tutorial_done: bool = false
## One-time v1/v2 → v3 save migration (garage tokens → scrap) already applied.
var migrated_v3: bool = false
var best_payout: int = 0
## Result screen: this extract beat the previous best payout (not saved).
var result_new_best: bool = false
## Highest Dust tier extracted on (unlocks the next one).
var best_tier_extracted: int = 0
## Extracts per tier ({"3": 2, ...}); tiers unlock on ModeDefs.UNLOCK_EXTRACTS.
var tier_extracts: Dictionary = {}
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
## Longest kill chain this run (HUD KillChain; result screen shows it).
var run_best_chain: int = 0
var extracted: bool = false
var wiped: bool = false
## True once this run has been banked (extract / wipe / abandon). Guards double-counting.
var run_finished: bool = false
var result_summary: String = ""
var last_phase_label: String = ""
var run_seed: int = 0
var extract_pad_info: Array = []

## --- Wander extras (DailyDefs / DustModDefs) --------------------------------
## "wander" | "daily" | "campaign" — fixed at begin_run.
var run_kind: String = "wander"
## Daily Run: the calendar day this run belongs to (fixed at begin_run, so a
## run that crosses midnight still counts for the day it started).
var run_daily_date: String = ""
## Weekly Dust modifiers active this run (fixed at begin_run).
var run_dust_mods: Array = []
## Seconds of run time (the match controller keeps it current).
var run_time: float = 0.0
## What put the hero down (the match fills it in; "" while alive).
var run_death_cause: String = ""
## The DAILY button was pressed: the next runs use the day's seed, tier, hero
## and pet until the player leaves for the mode select / hangar / menu.
var daily_armed: bool = false
## The player's own tier / hero / pet, put back when the daily is disarmed.
var _daily_restore: Dictionary = {}
## Opted into the week's Dust modifiers for normal Wander runs (saved).
var weekly_opt_in: bool = false
## Daily board: {date: {score, hero, pet, extracted, kills, seconds, scrap,
## attempts, practice_best, mods}} — the first finished attempt counts.
var daily_runs: Dictionary = {}
## Last RUN_HISTORY_MAX finished Wander / Daily runs, newest first.
var run_history: Array = []
const RUN_HISTORY_MAX := 50
## The finished daily run the result screen shows ({} for other runs).
var last_daily: Dictionary = {}
## Where the Run History screen's BACK goes ("logbook" | "mode_select" | "hangar").
var history_from: String = "logbook"

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
		"tier_extracts": tier_extracts,
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
		"live_run": live_run,
		"weekly_opt_in": weekly_opt_in,
		"daily_runs": daily_runs,
		"run_history": run_history,
	}
	## A daily run borrows the day's tier / hero / pet: save the player's own.
	if daily_armed and not _daily_restore.is_empty():
		data["selected_mode_id"] = str(_daily_restore.get("mode", selected_mode_id))
		data["selected_character_id"] = str(_daily_restore.get("hero", selected_character_id))
		data["selected_pet_id"] = str(_daily_restore.get("pet", selected_pet_id))
	if not _atomic_write(SAVE_PATH, JSON.stringify(data, "\t"), true):
		push_warning("Save failed: %s" % SAVE_PATH)

## Safe save: write a temp file, read it back and parse it, then rename it over
## the real file (atomic on iOS / desktop). With `backup`, the last good save is
## first copied to SAVE_BAK_PATH (also via temp + rename), so a damaged save
## never costs more than one save's worth of progress.
func _atomic_write(path: String, text: String, backup: bool) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if _parse_save(FileAccess.get_file_as_string(tmp)) == null:
		return false
	if backup and _main_save_ok and FileAccess.file_exists(path):
		var bt := SAVE_BAK_PATH + ".tmp"
		if DirAccess.copy_absolute(path, bt) == OK:
			DirAccess.rename_absolute(bt, SAVE_BAK_PATH)
	if DirAccess.rename_absolute(tmp, path) != OK:
		return false
	if path == SAVE_PATH:
		_main_save_ok = true
	return true

## Parsed save dictionary, or null when the text is empty / cut off / not JSON.
func _parse_save(text: String) -> Variant:
	if text.strip_edges() == "":
		return null
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	var v: Variant = j.data
	if typeof(v) != TYPE_DICTIONARY:
		return null
	return v

## Load order: the save, then a finished-but-unrenamed temp, then the rolling
## backup. A damaged save is copied aside and never silently replaced with a
## fresh profile; the profile only starts fresh when no save file exists, or
## (with a notice) when every file is unreadable.
func load_profile() -> void:
	load_source = ""
	_main_save_ok = false
	var found_any := false
	for p in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_BAK_PATH]:
		if not FileAccess.file_exists(p):
			continue
		found_any = true
		var parsed: Variant = _parse_save(FileAccess.get_file_as_string(p))
		if parsed == null:
			push_warning("Save unreadable: %s" % p)
			continue
		apply_save(parsed)
		if p == SAVE_PATH:
			load_source = "main"
			_main_save_ok = true
		else:
			load_source = "temp" if p != SAVE_BAK_PATH else "backup"
			_keep_damaged()
			load_notice = "Your save was damaged, so the last good copy was restored."
			## Rewrite the main save from the recovered profile (the damaged one
			## was kept aside and is never copied over the backup).
			save_profile()
		return
	if found_any:
		_keep_damaged()
		load_source = "reset"
		load_notice = "Your save couldn't be read and no backup was usable. A fresh profile was started; the damaged file was kept."
	else:
		load_source = "fresh"
	migrated_hangar_v4 = true
	_sync_account_level()

## Copy an unreadable save aside (wanderer_save.damaged.json) before anything
## writes over it.
func _keep_damaged() -> void:
	if FileAccess.file_exists(SAVE_PATH) and _parse_save(FileAccess.get_file_as_string(SAVE_PATH)) == null:
		DirAccess.copy_absolute(SAVE_PATH, SAVE_DAMAGED_PATH)

## Loads a parsed save dictionary (any version — missing keys get safe defaults).
func apply_save(d: Dictionary) -> void:
	var saved_settings: Variant = d.get("settings", {})
	if typeof(saved_settings) == TYPE_DICTIONARY:
		var up: Dictionary = (saved_settings as Dictionary).duplicate()
		SettingsDefs.upgrade_keys(up)
		for k in up.keys():
			settings[k] = up[k]
		## The old film grain (default on) became the bible's edge dither,
		## default off: older saves start with it off once.
		if not (saved_settings as Dictionary).has("dither_v1"):
			settings["edge_dither"] = false
	settings["dither_v1"] = true
	SettingsDefs.migrate(settings)
	tutorial_done = bool(d.get("tutorial_done", false))
	live_run = _dict_or_empty(d.get("live_run", {})).duplicate(true)
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
	tier_extracts = {}
	var te: Variant = d.get("tier_extracts", {})
	if te is Dictionary:
		for k in (te as Dictionary).keys():
			var tk := int(str(k))
			if tk >= 1 and tk <= ModeDefs.EXPOSED_TIERS:
				tier_extracts[str(tk)] = maxi(0, int((te as Dictionary)[k]))
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
	_load_extras(d)
	_migrate_hangar_v4()

## Wander extras (old saves: no keys → opt-out, empty board, empty history).
## Entries are cleaned field by field so a hand-edited / partial save can't
## put a wrong type in front of the UI.
func _load_extras(d: Dictionary) -> void:
	weekly_opt_in = bool(d.get("weekly_opt_in", false))
	daily_runs = {}
	var dr := _dict_or_empty(d.get("daily_runs", {}))
	for k in dr.keys():
		var e: Variant = dr[k]
		if typeof(e) != TYPE_DICTIONARY or str(k).length() != 10:
			continue
		daily_runs[str(k)] = _clean_daily(e)
	_prune_daily()
	run_history = []
	var rh: Variant = d.get("run_history", [])
	if typeof(rh) == TYPE_ARRAY:
		for e in (rh as Array):
			if typeof(e) == TYPE_DICTIONARY and run_history.size() < RUN_HISTORY_MAX:
				run_history.append(_clean_history(e))


func _clean_daily(e: Dictionary) -> Dictionary:
	var mods: Array = []
	var raw: Variant = e.get("mods", [])
	if raw is Array:
		for m in raw:
			mods.append(str(m))
	return {
		"date": str(e.get("date", "")), "score": maxi(0, int(e.get("score", 0))), "hero": str(e.get("hero", "")),
		"pet": str(e.get("pet", "")), "extracted": bool(e.get("extracted", false)), "kills": maxi(0, int(e.get("kills", 0))),
		"seconds": maxi(0, int(e.get("seconds", 0))), "scrap": maxi(0, int(e.get("scrap", 0))),
		"attempts": maxi(1, int(e.get("attempts", 1))), "practice_best": maxi(0, int(e.get("practice_best", 0))),
		"mods": mods,
	}


func _clean_history(e: Dictionary) -> Dictionary:
	return {
		"date": str(e.get("date", "")), "kind": str(e.get("kind", "wander")), "tier": clampi(int(e.get("tier", 1)), 1, 10),
		"mode": str(e.get("mode", "")), "hero": str(e.get("hero", "")), "pet": str(e.get("pet", "")),
		"extracted": bool(e.get("extracted", false)), "seconds": maxi(0, int(e.get("seconds", 0))),
		"kills": maxi(0, int(e.get("kills", 0))), "scrap": maxi(0, int(e.get("scrap", 0))),
		"best_item": str(e.get("best_item", "")), "best_rarity": str(e.get("best_rarity", "")),
		"cause": str(e.get("cause", "")), "score": maxi(0, int(e.get("score", 0))),
		"mods": (e.get("mods", []) as Array).duplicate() if e.get("mods", []) is Array else [],
	}


## Keep the daily board to the last DailyDefs.BOARD_DAYS days (by date).
func _prune_daily() -> void:
	var keys: Array = daily_runs.keys()
	keys.sort()
	while keys.size() > DailyDefs.BOARD_DAYS:
		daily_runs.erase(keys.pop_front())

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
			add_plane_part(str(t))
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
	return ZoneDefs.has_twist(zone_tier(), twist) or twist in DustModDefs.twists_of(dust_mods())

func pacts_unlocked() -> bool:
	return best_tier_extracted >= ZoneDefs.PACTS_FROM_TIER

## Active pacts for this run (only once unlocked).
func active_pacts() -> Array:
	if run_kind == "daily" and not in_campaign_run():
		return []
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
	var add := key in DustModDefs.ADD_KEYS
	var v := 0.0 if add else 1.0
	for id in active_pacts():
		var fx: Dictionary = ZoneDefs.pact(str(id)).get("fx", {})
		if fx.has(key):
			v = v + float(fx[key]) if add else v * float(fx[key])
	## Weekly Dust modifiers ride the same keys.
	var dm := DustModDefs.fx_of(dust_mods(), key)
	return v + dm if add else v * dm

## Weekly Dust modifiers on this run (none in the campaign).
func dust_mods() -> Array:
	return [] if in_campaign_run() else run_dust_mods

func dust_mod_on(flag: String) -> bool:
	return DustModDefs.has_flag(dust_mods(), flag)

func dust_loot_bonus() -> float:
	return DustModDefs.loot_bonus(dust_mods())

## Any run rule (pact or weekly modifier) that bends the tier's numbers.
func has_run_rules() -> bool:
	return not active_pacts().is_empty() or not dust_mods().is_empty()

## The week's modifiers as of today (mode select).
func week_mods() -> Array:
	return DustModDefs.for_date(today())

func set_weekly_opt_in(on: bool) -> void:
	weekly_opt_in = on
	save_profile()

func pact_loot_bonus() -> float:
	var b := 0.0
	for id in active_pacts():
		b += float(ZoneDefs.pact(str(id)).get("loot", 0.0))
	return b

func has_tier_clear(hero: String, tier: int) -> bool:
	return bool((tier_clears.get(hero, {}) as Dictionary).get(str(tier), false))

## Parts towards a whole plane (optional extras like the Dust Heart aside).
func plane_part_count() -> int:
	var n := 0
	for k in ZoneDefs.plane_required():
		if plane_parts.has(str(k)):
			n += 1
	return n

func plane_part_total() -> int:
	return ZoneDefs.plane_required().size()

func has_plane_part(id: String) -> bool:
	return plane_parts.has(ZoneDefs.plane_part_id(id))

## Same "PLANE x/y" text everywhere (+ HEART when the core is aboard).
func plane_progress_text() -> String:
	return "%d/%d" % [plane_part_count(), plane_part_total()] + (" +HEART" if plane_parts.has("heart") else "")

## Adds a part by any id (new / old tier / old campaign). True if it was new.
func add_plane_part(key: String) -> bool:
	var id := ZoneDefs.plane_part_id(key)
	if id == "" or plane_parts.has(id):
		return false
	plane_parts[id] = true
	return true

func plane_complete() -> bool:
	return plane_part_count() >= plane_part_total()

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
	if not part.is_empty() and add_plane_part(str(part["id"])):
		result_unlocks_pending.append("Helm's plane: %s recovered (%d/%d)" % [str(part["name"]), plane_part_count(), plane_part_total()])
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
	return maxf(0.45, 1.0 - r) * pact_fx("dash_cd")

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
	return m + pact_fx("move")

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
	claim_pending_rewards()
	save_profile()
	meta_changed.emit()
	return v

## Recently salvaged (newest first): [{item, scrap}], at most SALVAGE_BIN_MAX.
const SALVAGE_BIN_MAX := 30
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
				return [set_order(str(it.get("set", ""))), sl, -r, -uid]
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

## SET sort order: general sets, then survivor sets by hero (the selected
## survivor's first), loose items last.
func set_order(sid: String) -> int:
	if sid == "":
		return 999
	var gi := GearDefs.GENERAL_SETS.keys().find(sid)
	if gi >= 0:
		return gi
	var own := GearDefs.survivor_set_for(selected_character_id)
	if sid == own:
		return 50
	var si := GearDefs.SURVIVOR_SETS.keys().find(sid)
	return 51 + si if si >= 0 else 900

## Distinct pieces (slots) of a set in the stash.
func set_owned(sid: String) -> int:
	var slots := {}
	for it in stash:
		if str(it.get("set", "")) == sid:
			slots[str(it.get("slot", ""))] = true
	return slots.size()

## Items (already in SET order) split into [{"set": sid, "items": [...]}].
func set_groups(items: Array) -> Array:
	var out: Array = []
	for it in items:
		var sid := str(it.get("set", ""))
		if out.is_empty() or str(out[out.size() - 1]["set"]) != sid:
			out.append({"set": sid, "items": []})
		(out[out.size() - 1]["items"] as Array).append(it)
	return out

## Set ids present in the stash, in SET order (filter chip cycle).
func stash_set_ids() -> Array:
	var ids: Array = []
	for it in stash:
		var sid := str(it.get("set", ""))
		if sid != "" and not ids.has(sid):
			ids.append(sid)
	ids.sort_custom(func(a: String, b: String) -> bool: return set_order(a) < set_order(b))
	return ids

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

func auto_salvage_on() -> bool:
	return bool(settings.get("auto_salvage_commons", false))

## Would auto-salvage take this found item? Plain Commons only: never set
## pieces, legendaries, locked items, or a piece that beats what any survivor
## wears in that slot (empty slots don't count).
func auto_salvageable(it: Dictionary) -> bool:
	if str(it.get("rarity", "")) != "common" or str(it.get("set", "")) != "" \
			or str(it.get("legendary", "")) != "" or bool(it.get("locked", false)):
		return false
	var sc := GearDefs.item_score(it)
	for h in loadouts.keys():
		var lo: Dictionary = loadouts[h]
		for sl in lo.keys():
			if not GearDefs.fits(it, str(sl), str(h)):
				continue
			var cur := stash_item(int(lo[sl]))
			if cur.is_empty() or GearDefs.kind_of(cur) != GearDefs.kind_of(it):
				continue
			if GearDefs.kind_of(it) == "mod" and str(cur.get("mod", "")) != str(it.get("mod", "")):
				continue
			if sc > GearDefs.item_score(cur) + 0.001:
				return false
	return true

## Keep priority when the stash can't take everything: rarer first, set
## pieces before loose ones, so overflow salvages Commons before anything rarer.
static func _keep_rank(it: Dictionary) -> int:
	return GearDefs.RARITIES.find(str(it.get("rarity", "common"))) * 2 + (1 if str(it.get("set", "")) != "" else 0)

## May a stash-full overflow salvage this find? Plain Commons only.
static func overflow_salvageable(it: Dictionary) -> bool:
	return str(it.get("rarity", "common")) == "common" and str(it.get("set", "")) == "" \
			and str(it.get("legendary", "")) == ""

## Salvage a found (not yet stashed) item: scrap now, a uid so it can be
## bought back from the bin.
func _salvage_found(it: Dictionary, frac: float) -> int:
	var c := it.duplicate(true)
	c["uid"] = next_uid
	next_uid += 1
	var v := int(round(float(GearDefs.salvage_value(c)) * frac))
	account_scrap += v
	_bin_push(c, v)
	return v

## Extract: found gear → stash, materials banked. Auto-salvage (setting) takes
## plain Commons first. If the stash is still too small, only plain Commons
## are salvaged for room (into the buy-back bin); Rare+ and set pieces are never
## salvaged on overflow: they wait in pending_rewards (the holding area) and
## move in as soon as the stash has space.
func _bank_run_loot() -> void:
	result_found = []
	result_salvaged = 0
	result_auto_salvaged_n = 0
	result_auto_salvaged_scrap = 0
	result_overflow_n = 0
	result_held_n = 0
	var keep: Array = []
	var auto := auto_salvage_on()
	for it in run_loot:
		if auto and auto_salvageable(it):
			result_auto_salvaged_scrap += _salvage_found(it, 1.0)
			result_auto_salvaged_n += 1
		else:
			keep.append(it)
	var room := maxi(0, stash_capacity() - stash.size())
	if keep.size() > room:
		var order := range(keep.size())
		order.sort_custom(func(a: int, b: int) -> bool:
			var ra := _keep_rank(keep[a])
			var rb := _keep_rank(keep[b])
			return ra > rb if ra != rb else a < b)
		var drop := {}
		for i in range(room, order.size()):
			drop[order[i]] = true
		var kept: Array = []
		for i in range(keep.size()):
			if not drop.has(i):
				kept.append(keep[i])
			elif overflow_salvageable(keep[i]):
				result_salvaged += _salvage_found(keep[i], GearDefs.OVERFLOW_SALVAGE)
				result_overflow_n += 1
			else:
				pending_rewards.append(keep[i].duplicate(true))
				result_held_n += 1
		keep = kept
	for it in keep:
		if add_to_stash(it):
			result_found.append(it)
		else:
			pending_rewards.append(it.duplicate(true))
			result_held_n += 1
	for k in run_materials.keys():
		materials[k] = material_count(str(k)) + int(run_materials[k])
		result_unlocks.append("+%d %s" % [int(run_materials[k]), GearDefs.MATERIAL_NAME.get(str(k), str(k))])
	run_loot = []
	run_materials = {}
	_bank_pack()

## Death (balance pass): extracting is still the only way to bank a run's
## gear, but the cost is proportional — found gear is lost except the tier's
## death_keep share (best pieces first), and at most DEATH_KIT_LOSS pieces of the
## worn kit go down with you (never the insured one).
const DEATH_KIT_LOSS := 2
var result_death_kept: Array = []

func _lose_run_loot() -> void:
	result_lost_items = []
	result_death_kept = []
	var order := range(run_loot.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := _keep_rank(run_loot[a])
		var rb := _keep_rank(run_loot[b])
		return ra > rb if ra != rb else a < b)
	var n_keep := int(floor(float(run_loot.size()) * float(get_mode().get("death_keep", 0.1)) + 0.001))
	for i in range(order.size()):
		var it: Dictionary = run_loot[order[i]]
		if i < n_keep and add_to_stash(it):
			result_death_kept.append(it)
		else:
			result_lost_items.append(it.duplicate(true))
	var hero := selected_character_id
	var keep := int(insured.get(hero, -1))
	var eq := equipped_items(hero)
	var at_risk: Array = []
	for sl in eq.keys():
		if int((eq[sl] as Dictionary).get("uid", -1)) != keep:
			at_risk.append(sl)
	at_risk.sort()
	var drng := RandomNumberGenerator.new()
	drng.seed = run_seed * 31 + 7
	for i in range(mini(DEATH_KIT_LOSS, at_risk.size())):
		var j := drng.randi_range(i, at_risk.size() - 1)
		var tmp: Variant = at_risk[i]
		at_risk[i] = at_risk[j]
		at_risk[j] = tmp
		var sl: Variant = at_risk[i]
		var it: Dictionary = eq[sl]
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

## Extracts on `tier` or any harder tier.
func extracts_at_or_above(tier: int) -> int:
	var n := 0
	for k in tier_extracts.keys():
		if int(str(k)) >= tier:
			n += int(tier_extracts[k])
	return n

## Balance pass: a tier counts as cleared (and opens the next one) after
## ModeDefs.unlock_extracts(tier) extracts on it or higher — ~25-35 runs from a
## fresh career to Dustfall instead of ~10.
func _advance_tier_clears() -> void:
	while best_tier_extracted < ModeDefs.EXPOSED_TIERS and \
			extracts_at_or_above(best_tier_extracted + 1) >= ModeDefs.unlock_extracts(best_tier_extracted + 1):
		best_tier_extracted += 1

## Extracts still needed on the top open tier (or higher) to open the next; 0 = all open.
func extracts_to_next_tier() -> int:
	var top := highest_unlocked_tier()
	if top >= ModeDefs.EXPOSED_TIERS:
		return 0
	## Extracts on the top tier count for every tier below it too.
	var need := 0
	for t in range(best_tier_extracted + 1, top + 1):
		need = maxi(need, ModeDefs.unlock_extracts(t) - extracts_at_or_above(t))
	return need

## Each tier unlocks after extracting on the one below (Part 5) — now a few
## times (ModeDefs.UNLOCK_EXTRACTS).
func highest_unlocked_tier() -> int:
	return clampi(maxi(ModeDefs.START_UNLOCKED, best_tier_extracted + 1), 1, ModeDefs.EXPOSED_TIERS)

func is_tier_unlocked(tier: int) -> bool:
	return tier <= highest_unlocked_tier()

## New quests each day.
func refresh_daily() -> void:
	var d := today()
	var t := highest_unlocked_tier()
	if str(daily.get("date", "")) != d or not (daily.get("quests", null) is Array):
		daily = {"date": d, "quests": QuestDefs.roll_daily(d, t), "checked": t}
	elif int(daily.get("checked", -1)) != t:
		## Older saves / changed unlocks: never keep a daily for locked content.
		if not QuestDefs.dailies_unlocked(daily["quests"], QuestDefs.unlocked_context(t)):
			daily = {"date": d, "quests": QuestDefs.roll_daily(d, t)}
		daily["checked"] = t

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

## Gear held for stash room: story Legendaries and stash-full overflow finds.
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

func set_setting(key: String, value: Variant, save: bool = true) -> void:
	settings[key] = value
	SettingsDefs.apply(key)
	settings_changed.emit(key)
	if save:
		save_profile()


static func _default_settings() -> Dictionary:
	var d: Dictionary = SettingsDefs.DEFAULTS.duplicate(true)
	d["sfx"] = true
	d["dither_v1"] = true
	d["settings_v"] = SettingsDefs.VERSION
	return d

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
	tier_extracts = {}
	total_runs = 0
	campaign = _fresh_campaign()
	weekly_opt_in = false
	daily_runs = {}
	run_history = []
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

## `drink_tonics` false = resuming a run whose tonics were already drunk.
func begin_run(drink_tonics: bool = true) -> void:
	threat_level = 0
	windows_skipped = 0
	extract_windows_seen = 0
	loot_mult = 1.0
	scrap_found = 0
	kills = 0
	run_best_chain = 0
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
	run_time = 0.0
	run_death_cause = ""
	last_daily = {}
	run_daily_date = ""
	run_dust_mods = []
	if in_campaign_run():
		run_kind = "campaign"
		daily_armed = false
	elif daily_armed:
		## Daily Run: the day's seed, tier, hero, pet and the week's Dust.
		run_kind = "daily"
		run_daily_date = today()
		run_seed = DailyDefs.seed_for(run_daily_date)
		selected_mode_id = DailyDefs.TIER_ID
		selected_character_id = DailyDefs.hero_for(run_daily_date)
		selected_pet_id = DailyDefs.pet_for(run_daily_date)
		run_dust_mods = DustModDefs.for_date(run_daily_date)
	else:
		run_kind = "wander"
		if weekly_opt_in:
			run_dust_mods = DustModDefs.for_date(today())
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
	if drink_tonics:
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
	result_new_best = false
	result_death_kept = []
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
	result_auto_salvaged_n = 0
	result_auto_salvaged_scrap = 0
	result_overflow_n = 0
	result_held_n = 0
	result_scrap_after = -1

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
	var gained := maxi(0, int(round(float(amount) * total_find_mult() * event_scrap_mult * pact_fx("scrap"))))
	scrap_found += gained
	return gained

## In-run XP → levels → upgrade picker. Does NOT become permanent power.
func add_run_xp(amount: int) -> void:
	if amount <= 0 or extracted or wiped:
		return
	if not dust_mods().is_empty():
		amount = int(round(float(amount) * pact_fx("run_xp")))
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
		base * loot_mult * float(mode["payout_mult"]) * extract_payout_mult() * (1.0 + pact_loot_bonus() + dust_loot_bonus())
	) + extract_bonus_payout()
	if pact_loot_bonus() > 0.0:
		result_unlocks_pending.append("Dust Pacts: payout +%d%%" % int(round(pact_loot_bonus() * 100.0)))
	if dust_loot_bonus() > 0.0:
		result_unlocks_pending.append("Weekly Dust: payout +%d%%" % int(round(dust_loot_bonus() * 100.0)))
	var hauled := int(round(float(base) * loot_mult))
	var best := _best_found(run_loot)
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
	if not in_campaign_run():
		tier_extracts[str(tier_n)] = int(tier_extracts.get(str(tier_n), 0)) + 1
	if tier_n > best_tier_extracted:
		var before := highest_unlocked_tier()
		_advance_tier_clears()
		if highest_unlocked_tier() > before:
			result_unlocks.append("New tier unlocked: %s" % str(ModeDefs.tier_mode(highest_unlocked_tier()).get("display_name", "")))
	result_unlocks.append_array(result_unlocks_pending)
	result_unlocks_pending = PackedStringArray()
	result_summary = "Extracted. +%d scrap banked (×%.1f loot) · run Lv %d · Threat %d" % [
		payout_this_run, loot_mult, run_level, threat_level,
	]
	## First extract counts as a best only if it paid something.
	result_new_best = payout_this_run > best_payout and payout_this_run > 0 and total_runs > 0
	best_payout = maxi(best_payout, payout_this_run)
	total_runs += 1
	_record_run(true, hauled, best)
	## In-run power dies here — only banked scrap/meta remain.
	_reset_run_power_after_end()
	for m in check_milestones():
		result_unlocks.append("Milestone: %s" % str(m["name"]))
	result_scrap_after = account_scrap
	_clear_live_run()
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
	var best := _best_found(run_loot)
	_lose_run_loot()
	result_unlocks.append_array(result_unlocks_pending)
	result_unlocks_pending = PackedStringArray()
	result_lost_keys = PackedStringArray()
	result_kept_keys = PackedStringArray()
	for it in result_lost_items:
		result_lost_keys.append(str(it.get("name", "item")))
	if not kept_item.is_empty():
		result_kept_keys.append(str(kept_item.get("name", "item")))
	for it in result_death_kept:
		result_kept_keys.append(str(it.get("name", "item")))
	result_summary = "Wiped. Kept %d%% of the bag (+%d scrap). Lost %d. Lost gear: %s" % [
		int(round(float(mode.get("death_keep", 0.1)) * 100.0)),
		keep,
		result_scrap_lost,
		", ".join(result_lost_keys) if result_lost_keys.size() else "(nothing)",
	]
	total_runs += 1
	_record_run(false, 0, best)
	_reset_run_power_after_end()
	for m in check_milestones():
		result_unlocks.append("Milestone: %s" % str(m["name"]))
	result_scrap_after = account_scrap
	_clear_live_run()
	save_profile()

## Best piece in a list of found items: {name, rarity} ({} if none).
func _best_found(items: Array) -> Dictionary:
	var best: Dictionary = {}
	var br := -1
	for it in items:
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var r := GearDefs.RARITIES.find(str((it as Dictionary).get("rarity", "common")))
		if r > br:
			br = r
			best = {"name": str((it as Dictionary).get("name", "item")), "rarity": str((it as Dictionary).get("rarity", "common"))}
	return best

## A Wander / Daily run just ended: add it to the run history and, for a
## daily, to the day's board (first finished attempt counts, later ones are
## practice). Campaign levels aren't extraction runs and stay out of it.
func _record_run(did_extract: bool, hauled: int, best: Dictionary, cause: String = "") -> void:
	if in_campaign_run() or run_kind == "campaign":
		return
	var mode := get_mode()
	var secs := int(floor(maxf(run_time, 0.0)))
	var entry := {
		"date": run_daily_date if run_kind == "daily" else today(), "kind": run_kind,
		"tier": int(mode.get("tier", 1)), "mode": str(mode.get("id", "")),
		"hero": selected_character_id, "pet": selected_pet_id, "extracted": did_extract,
		"seconds": secs, "kills": kills, "scrap": hauled if did_extract else 0,
		"best_item": str(best.get("name", "")), "best_rarity": str(best.get("rarity", "")),
		"cause": "" if did_extract else (cause if cause != "" else (run_death_cause if run_death_cause != "" else "Went down in the dust")),
		"score": 0, "mods": run_dust_mods.duplicate(),
	}
	if run_kind == "daily":
		var parts := DailyDefs.score_parts(hauled, kills, run_time, did_extract)
		entry["score"] = int(parts["total"])
		last_daily = _record_daily(entry, parts)
	push_history(entry)

func push_history(entry: Dictionary) -> void:
	run_history.push_front(_clean_history(entry))
	while run_history.size() > RUN_HISTORY_MAX:
		run_history.pop_back()

## Returns what the result screen shows: the breakdown, counted or practice,
## the day's counted score and share text.
func _record_daily(entry: Dictionary, parts: Dictionary) -> Dictionary:
	var date := str(entry["date"])
	var score := int(parts["total"])
	var practice := daily_runs.has(date)
	if practice:
		var d: Dictionary = daily_runs[date]
		d["attempts"] = int(d.get("attempts", 1)) + 1
		d["practice_best"] = maxi(int(d.get("practice_best", 0)), score)
	else:
		daily_runs[date] = _clean_daily({
			"date": date, "score": score, "hero": entry["hero"], "pet": entry["pet"], "extracted": entry["extracted"],
			"kills": entry["kills"], "seconds": entry["seconds"], "scrap": int(parts["scrap"]), "attempts": 1,
			"practice_best": 0, "mods": entry["mods"]})
		_prune_daily()
	var share := entry.duplicate()
	share["practice"] = practice
	return {"date": date, "parts": parts, "practice": practice, "counted": int(daily_runs.get(date, {}).get("score", 0)),
		"share": DailyDefs.share_text(share)}

## The day's board entry ({} if not played yet).
func daily_entry(date: String = "") -> Dictionary:
	return daily_runs.get(today() if date == "" else date, {})

## Totals for the Run History screen.
func history_totals() -> Dictionary:
	var n := run_history.size()
	var ext := 0
	var best_by_hero := {}
	for e in run_history:
		if bool(e.get("extracted", false)):
			ext += 1
		var h := str(e.get("hero", ""))
		var cur: Dictionary = best_by_hero.get(h, {})
		var key := int(e.get("scrap", 0)) + (100000 if bool(e.get("extracted", false)) else 0)
		var ck := int(cur.get("scrap", -1)) + (100000 if bool(cur.get("extracted", false)) else 0)
		if cur.is_empty() or key > ck:
			best_by_hero[h] = e
	return {"runs": n, "extracts": ext, "rate": (float(ext) / float(n)) if n > 0 else 0.0, "best_by_hero": best_by_hero}

func _reset_run_power_after_end() -> void:
	## Permanent power never comes from run levels — clear after banking rewards.
	run_xp = 0
	_reset_run_cards()
	pending_run_choices.clear()
	run_level_paused = false

func timer_scale() -> float:
	return FAST_TIMER_SCALE if fast_timers else 1.0

## DAILY: borrow the day's tier / hero / pet (the player's own come back on
## disarm_daily) and head to the pre-run loadout.
func arm_daily() -> void:
	if not daily_armed:
		_daily_restore = {"mode": selected_mode_id, "hero": selected_character_id, "pet": selected_pet_id}
	daily_armed = true
	var d := today()
	selected_mode_id = DailyDefs.TIER_ID
	selected_character_id = DailyDefs.hero_for(d)
	selected_pet_id = DailyDefs.pet_for(d)
	reset_loadout_to_defaults()

func disarm_daily() -> void:
	if not daily_armed:
		return
	daily_armed = false
	if not _daily_restore.is_empty():
		var m := str(_daily_restore.get("mode", selected_mode_id))
		if ModeDefs.is_exposed(m) and is_tier_unlocked(int(ModeDefs.get_mode(m)["tier"])):
			selected_mode_id = m
		var h := str(_daily_restore.get("hero", selected_character_id))
		if CharacterDefs.is_playable(h):
			selected_character_id = h
		var pid := str(_daily_restore.get("pet", selected_pet_id))
		if PetDefs.is_equipable(pid) and pet_available(pid):
			selected_pet_id = pid
	_daily_restore = {}
	reset_loadout_to_defaults()

func go_daily() -> void:
	leave_campaign_run()
	play_mode = "wander"
	arm_daily()
	go_prep()

## Run History (logbook / mode select / hangar); `tab` = "runs" | "daily".
var history_tab: String = "runs"

func go_run_history(from: String = "logbook", tab: String = "runs") -> void:
	history_from = from
	history_tab = tab
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/run_history.tscn")

func go_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	disarm_daily()
	leave_campaign_run()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func go_mode_select() -> void:
	disarm_daily()
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
	disarm_daily()
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
	return {"v": CAMPAIGN_V, "done": {}, "flags": {}, "roster": [], "pets": [], "last": "", "picks": {}}


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
	_normalize_story_outcomes()
	## Old saves kept campaign plane parts here: merge them into the one
	## tracker (plane_parts, loaded before this). A Dust Heart a destroy
	## ending wrongly handed out stays gone.
	var old_parts: Variant = d.get("parts", [])
	if typeof(old_parts) == TYPE_ARRAY:
		for it in (old_parts as Array):
			if ZoneDefs.plane_part_id(str(it)) == "heart" and not _canon_flag_is("ending", "power"):
				continue
			add_plane_part(str(it))
	if plane_parts.has("heart") and _canon_flag_is("ending", "destroy"):
		plane_parts.erase("heart")
	for key in ["roster", "pets"]:
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


## A replay of a level the story already finished: a "memory". The first
## completion is canonical; a memory pays rewards but never changes who
## lived, who fell, or any story flag. Only RESTART CAMPAIGN rewrites it.
func campaign_memory_run() -> bool:
	return in_campaign_run() and campaign_level_done(campaign_level_id)


## The saved (canonical) story flag, ignoring this attempt's choices.
func campaign_canon_flag(key: String, default: Variant = null) -> Variant:
	return (campaign["flags"] as Dictionary).get(key, default)


func _canon_flag_is(key: String, value: Variant) -> bool:
	var f: Variant = campaign_canon_flag(key, null)
	return f != null and str(f) == str(value)


## Survivors who can fall in the story, keyed by the outcome flag that picks them.
const STORY_FALL_FLAG := "choke_fall"
const STORY_CAN_FALL := ["vesper_thorn", "nyx_caldera"]


## One outcome, one truth: the saved Choke outcome decides who fell (repairs
## saves where replays killed a second survivor or left one fallen while the
## outcome said everyone lived).
func _normalize_story_outcomes() -> void:
	var fl: Dictionary = campaign["flags"]
	if not fl.has(STORY_FALL_FLAG):
		return
	var who := str(fl[STORY_FALL_FLAG])
	for h in STORY_CAN_FALL:
		if str(h) == who:
			fl["fallen_" + str(h)] = true
		else:
			fl.erase("fallen_" + str(h))


## Wipe the story only (Wander progress, gear and Wander-earned plane parts
## stay). The one way to change a finished story.
func restart_campaign() -> void:
	campaign = _fresh_campaign()
	campaign_run_flags = {}
	campaign_result = {}
	## Story-only part: the heart comes back only by choosing it again.
	plane_parts.erase("heart")
	save_profile()


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
	## Memories replay the story as it happened: decided flags are locked.
	if campaign_memory_run() and (campaign["flags"] as Dictionary).has(key):
		return
	campaign_run_flags[key] = value


## Memory runs: the option already chosen for this flag (null = still open).
func campaign_locked_choice(key: String) -> Variant:
	if campaign_memory_run() and (campaign["flags"] as Dictionary).has(key):
		return campaign["flags"][key]
	return null


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
	disarm_daily()
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
	disarm_daily()
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
	## The FIRST completion's choices become the story; replays are memories.
	if first:
		for k in campaign_run_flags.keys():
			campaign["flags"][k] = campaign_run_flags[k]
		for k in (rw.get("flags", {}) as Dictionary).keys():
			campaign["flags"][str(k)] = rw["flags"][k]
		_normalize_story_outcomes()
	else:
		lines.append("A memory: the story stays as it was")
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
		var part := ZoneDefs.plane_part_id(str(rw.get("part", "")))
		var pif: Array = rw.get("part_if", [])
		var part_ok := pif.size() < 2 or _canon_flag_is(str(pif[0]), pif[1])
		if part != "" and part_ok and add_plane_part(part):
			lines.append("Plane part: %s (%s)" % [str(ZoneDefs.PLANE_PARTS[part]["name"]), plane_progress_text()])
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
	_clear_live_run()
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
	_clear_live_run()
	save_profile()
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



## =============================================================================
## LIVE RUN — force-quit safety. A run in progress keeps a marker in the profile
## (saved the moment the match starts) and a snapshot file (RUN_PATH) refreshed
## every LIVE_SNAPSHOT_SEC and whenever the app is backgrounded / closed. Every
## normal end (extract, death, abandon, campaign win / loss / leave) clears both.
## At launch a leftover marker means the app died mid-run: the main menu offers
## RESUME (rebuild the match from the snapshot) or ABANDON (counts as a death:
## equipped gear lost, no scrap, the pack lost).

## Run vars kept in a snapshot, by type: i int, f float, b bool, d dictionary,
## a array, s PackedStringArray. (Typed restore — no Variant guesses.)
const LIVE_RUN_KEYS := {
	"threat_level": "i", "windows_skipped": "i", "extract_windows_seen": "i", "scrap_found": "i",
	"kills": "i", "run_xp": "i", "run_level": "i", "run_rerolls_left": "i", "run_luck_charges": "i",
	"events_done_run": "i", "extract_bonus_scrap": "i", "run_keys": "i", "jobs_done_run": "i",
	"run_seed": "i", "account_xp_this_run": "i",
	"loot_mult": "f", "run_luck": "f", "boss_loot_bonus": "f", "event_scrap_mult": "f",
	"event_enemy_damage": "f", "exposure": "f", "run_filter": "f",
	"run_pack_locked": "b", "run_has_cell": "b",
	"run_mods": "d", "run_ranks": "d", "run_kind_kills": "d", "run_ammo_seen": "d",
	"run_materials": "d", "run_pack": "d", "run_job_rewards": "d",
	"run_picks_taken": "a", "run_loot": "a", "run_tonics": "a",
	"extract_bonus_notes": "s", "result_unlocks_pending": "s",
	"run_time": "f", "run_dust_mods": "a", "run_kind": "t", "run_daily_date": "t",
}


func _process(delta: float) -> void:
	if live_run.is_empty() or run_finished or _live_ctrl == null:
		return
	_live_accum += delta
	if _live_accum >= LIVE_SNAPSHOT_SEC:
		_live_accum = 0.0
		live_run_snapshot()


## Backgrounded (home swipe, call), focus lost or the window closing: snapshot now.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not live_run.is_empty() and not run_finished and _live_ctrl != null:
			live_run_snapshot()


## A match scene is up and running (Wander or Campaign): mark the run live in
## the profile (atomic save — also keeps this run's spent tonics spent) and
## take the first snapshot.
func live_run_begin(ctrl: Node) -> void:
	_live_ctrl = weakref(ctrl)
	_live_accum = 0.0
	var resumes := int(live_run.get("resumes", 0)) if bool(ctrl.get_meta("resumed", false)) else 0
	live_run = {
		"id": run_seed,
		"mode": "campaign" if in_campaign_run() else "wander",
		"level": campaign_level_id if in_campaign_run() else "",
		"tier_mode": selected_mode_id,
		"hero": selected_character_id,
		"pet": selected_pet_id,
		"started": int(Time.get_unix_time_from_system()),
		"resumes": resumes,
		"kind": run_kind,
		"daily_date": run_daily_date,
		"dust_mods": run_dust_mods.duplicate(),
		"restore": _daily_restore.duplicate(),
	}
	save_profile()
	live_run_snapshot()


func has_live_run() -> bool:
	return not live_run.is_empty() or FileAccess.file_exists(RUN_PATH)


## Write the snapshot (run vars + the controller's match bits). Returns success.
func live_run_snapshot() -> bool:
	if live_run.is_empty() or run_finished:
		return false
	var m: Dictionary = {}
	var ctrl: Object = _live_ctrl.get_ref() if _live_ctrl != null else null
	if ctrl != null and is_instance_valid(ctrl) and ctrl.has_method("live_snapshot"):
		var got: Variant = ctrl.call("live_snapshot")
		if typeof(got) == TYPE_DICTIONARY:
			m = got
	var run := {}
	for k in LIVE_RUN_KEYS.keys():
		var v: Variant = get(k)
		if typeof(v) == TYPE_PACKED_STRING_ARRAY:
			v = Array(v)
		run[k] = v
	var snap := {"v": 1, "saved": int(Time.get_unix_time_from_system()), "marker": live_run, "run": run, "match": m}
	return _atomic_write(RUN_PATH, JSON.stringify(snap), false)


## The snapshot on disk, or {} if missing / unreadable.
func read_live_snapshot() -> Dictionary:
	if not FileAccess.file_exists(RUN_PATH):
		return {}
	var v: Variant = _parse_save(FileAccess.get_file_as_string(RUN_PATH))
	if v == null:
		return {}
	var d: Dictionary = v
	if typeof(d.get("marker", null)) != TYPE_DICTIONARY or typeof(d.get("run", null)) != TYPE_DICTIONARY:
		return {}
	return d


## What the resume prompt shows: marker fields + snapshot run level / time.
func live_run_info() -> Dictionary:
	var snap := read_live_snapshot()
	var mk: Dictionary = live_run.duplicate()
	if mk.is_empty():
		mk = _dict_or_empty(snap.get("marker", {}))
	var info := mk.duplicate()
	info["ok"] = not snap.is_empty()
	var run := _dict_or_empty(snap.get("run", {}))
	var m := _dict_or_empty(snap.get("match", {}))
	info["run_level"] = int(run.get("run_level", 1))
	info["time"] = float(m.get("match_time", m.get("level_time", 0.0)))
	info["hp"] = float(m.get("hp", 0.0))
	info["max_hp"] = float(m.get("max_hp", 0.0))
	var hero := str(mk.get("hero", ""))
	var lost: Array = []
	if hero != "" and str(mk.get("mode", "")) != "campaign":
		var keep := int(insured.get(hero, -1))
		var eq := equipped_items(hero)
		for sl in eq.keys():
			if int((eq[sl] as Dictionary).get("uid", -1)) != keep:
				lost.append(str((eq[sl] as Dictionary).get("name", "item")))
	info["at_risk"] = lost
	info["kept"] = str(stash_item(int(insured.get(hero, -1))).get("name", "")) if hero != "" else ""
	return info


func _clear_live_run() -> void:
	live_run = {}
	_live_ctrl = null
	_live_accum = 0.0
	pending_resume = {}
	for p in [RUN_PATH, RUN_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## ABANDON (or a resume that can't be rebuilt): counts as a death. The equipped
## loadout is lost (the insured item stays, as on any death), no scrap comes
## home, and the pack is lost (Pack Lock doesn't apply — the run never ended).
## Returns {"hero", "lost": [names], "kept": name}.
func abandon_live_run() -> Dictionary:
	var mk: Dictionary = live_run.duplicate()
	if mk.is_empty():
		mk = _dict_or_empty(read_live_snapshot().get("marker", {}))
	var hero := str(mk.get("hero", ""))
	if hero == "":
		hero = selected_character_id
	var keep := int(insured.get(hero, -1))
	var lost: Array = []
	## Campaign: matches a campaign death — the run is lost, gear is kept.
	var eq: Dictionary = {} if str(mk.get("mode", "")) == "campaign" else equipped_items(hero)
	for sl in eq.keys():
		var it: Dictionary = eq[sl]
		if int(it.get("uid", -1)) == keep:
			continue
		lost.append(str(it.get("name", "item")))
		stash.erase(it)
		loadout_of(hero).erase(sl)
	run_pack = {}
	run_loot = []
	run_materials = {}
	total_runs += 1
	if str(mk.get("mode", "")) != "campaign":
		_record_abandoned(mk)
	_clear_live_run()
	reset_loadout_to_defaults()
	save_profile()
	return {"hero": hero, "lost": lost, "kept": str(stash_item(keep).get("name", ""))}


## A run abandoned from the RUN INTERRUPTED prompt: a death in the history
## (and the day's counted daily, score 0, if it was the first attempt).
func _record_abandoned(mk: Dictionary) -> void:
	var kind := str(mk.get("kind", "wander"))
	var date := str(mk.get("daily_date", today()))
	var tm := ModeDefs.get_mode(str(mk.get("tier_mode", selected_mode_id)))
	var info := read_live_snapshot()
	var run := _dict_or_empty(info.get("run", {}))
	var mods: Array = mk.get("dust_mods", []) if mk.get("dust_mods", []) is Array else []
	var entry := {"date": date if kind == "daily" else today(), "kind": kind, "tier": int(tm.get("tier", 1)), "mode": str(tm.get("id", "")),
		"hero": str(mk.get("hero", "")), "pet": str(mk.get("pet", "")), "extracted": false,
		"seconds": int(float(run.get("run_time", 0.0))), "kills": int(run.get("kills", 0)), "scrap": 0,
		"best_item": "", "best_rarity": "", "cause": "Abandoned", "score": 0, "mods": mods}
	if kind == "daily":
		_record_daily(entry, DailyDefs.score_parts(0, int(entry["kills"]), float(entry["seconds"]), false))
	push_history(entry)


## RESUME: rebuild the run from the snapshot and return the scene to load
## ("" = it couldn't be rebuilt; the run was abandoned instead). The match
## restarts its current phase / window (campaign: the level) with the hero at
## the snapshot's run level, cards, pack, finds and health.
func prepare_resume() -> String:
	var snap := read_live_snapshot()
	var mk := _dict_or_empty(snap.get("marker", {}))
	var hero := str(mk.get("hero", ""))
	var mode := str(mk.get("mode", ""))
	var lvl := str(mk.get("level", ""))
	var ok := not snap.is_empty() and CharacterDefs.is_playable(hero)
	if ok and mode == "campaign":
		ok = CampaignDefs.is_playable(lvl)
	elif ok:
		ok = mode == "wander"
	if not ok:
		abandon_live_run()
		return ""
	var scene := "res://scenes/match/match.tscn"
	if mode == "campaign":
		leave_campaign_run()
		if not prepare_campaign_level(lvl, hero):
			abandon_live_run()
			return ""
		scene = CampaignDefs.MATCH_SCENE
	else:
		leave_campaign_run()
		play_mode = "wander"
		var tm := str(mk.get("tier_mode", selected_mode_id))
		if not ModeDefs.get_mode(tm).is_empty():
			selected_mode_id = tm
		selected_character_id = hero
		var pid := str(mk.get("pet", selected_pet_id))
		if PetDefs.is_equipable(pid) and pet_available(pid):
			selected_pet_id = pid
		get_tree().paused = false
		Engine.time_scale = 1.0
		TouchInput.clear_sticks()
		begin_run(false)
	_apply_run_state(_dict_or_empty(snap.get("run", {})))
	if run_kind == "daily" and mode != "campaign":
		daily_armed = true
		_daily_restore = _dict_or_empty(mk.get("restore", {}))
	run_finished = false
	extracted = false
	wiped = false
	pending_run_choices.clear()
	run_level_paused = false
	if mode == "campaign":
		## The level restarts, so this attempt's choices are made again.
		campaign_run_flags = {}
	live_run = mk
	live_run["resumes"] = int(mk.get("resumes", 0)) + 1
	pending_resume = _dict_or_empty(snap.get("match", {}))
	pending_resume["_resume"] = true
	loadout_changed.emit()
	run_xp_changed.emit(run_xp, run_level)
	return scene


func resume_live_run() -> bool:
	var scene := prepare_resume()
	if scene == "":
		return false
	get_tree().change_scene_to_file(scene)
	return true


## The controller takes the match bits once ({} = a fresh run).
func take_pending_resume() -> Dictionary:
	var r := pending_resume
	pending_resume = {}
	return r


func _apply_run_state(r: Dictionary) -> void:
	for k in LIVE_RUN_KEYS.keys():
		if not r.has(k):
			continue
		var v: Variant = r[k]
		match str(LIVE_RUN_KEYS[k]):
			"i":
				if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
					set(k, int(v))
			"f":
				if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
					set(k, float(v))
			"b":
				if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
					set(k, bool(v))
			"d":
				if typeof(v) == TYPE_DICTIONARY:
					set(k, _whole_numbers(v))
			"a":
				if typeof(v) == TYPE_ARRAY:
					set(k, (v as Array).duplicate(true))
			"t":
				if typeof(v) == TYPE_STRING:
					set(k, str(v))
			"s":
				if typeof(v) == TYPE_ARRAY:
					var ps := PackedStringArray()
					for x in (v as Array):
						ps.append(str(x))
					set(k, ps)
	if run_seed == 0:
		run_seed = 1


## JSON brings every number back as a float: whole ones become ints again
## (counts, ranks), fractions stay (run_mods).
func _whole_numbers(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		var v: Variant = d[k]
		if typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)) and absf(float(v)) < 1e9 and str(k) not in _fresh_run_mods():
			v = int(v)
		out[str(k)] = v
	return out
