class_name Progression
extends RefCounted

## Dual-track progression (MVP):
##   A) In-run levels — kill/stay XP → loadout picks; RESETS every deploy.
##   B) Meta scrap — banked on extract; spent in Hangar on permanent upgrades.
## Account XP is soft prestige only (gates a few Hangar tiers); scrap is the fuel.

## --- In-run level curve (fast) ---
## L1→2: 20 · L2→3: 29 · L3→4: 38 · … (many small picks — Phase 4 cards)
const RUN_XP_BASE := 20
const RUN_XP_STEP := 9
const RUN_LEVEL_CAP := 20

## --- Soft account prestige (not spend power) ---
const ACCOUNT_XP_BASE := 120
const ACCOUNT_XP_STEP := 60
const EXTRACT_ACCOUNT_XP := 25
const WIPE_ACCOUNT_XP_FLOOR := 8

## Loadout / stash UI not shipped — hide insurance buy CTA until it exists.
const LOADOUT_UI_SHIPPED := false


static func run_xp_to_next(level: int) -> int:
	var lv := clampi(level, 1, RUN_LEVEL_CAP)
	return RUN_XP_BASE + (lv - 1) * RUN_XP_STEP


static func run_progress(run_xp: int, run_level: int) -> Dictionary:
	if run_level >= RUN_LEVEL_CAP:
		return {"level": run_level, "into": 0, "need": 1, "ratio": 1.0, "capped": true}
	var need := run_xp_to_next(run_level)
	## run_xp is XP earned toward the *next* level (resets on level-up).
	return {
		"level": run_level,
		"into": run_xp,
		"need": need,
		"ratio": clampf(float(run_xp) / float(need), 0.0, 1.0),
		"capped": false,
	}


static func account_xp_to_next(level: int) -> int:
	var lv := maxi(1, level)
	return ACCOUNT_XP_BASE + (lv - 1) * ACCOUNT_XP_STEP


static func account_progress(total_xp: int) -> Dictionary:
	var xp := maxi(0, total_xp)
	var level := 1
	while xp >= account_xp_to_next(level):
		xp -= account_xp_to_next(level)
		level += 1
	var need := account_xp_to_next(level)
	return {
		"level": level,
		"into": xp,
		"need": need,
		"ratio": clampf(float(xp) / float(need), 0.0, 1.0),
	}


static func account_level_from_xp(total_xp: int) -> int:
	return int(account_progress(total_xp)["level"])


static func award_extract_account_xp(kills: int, tl_payout: float, mode_payout: float) -> int:
	## Soft prestige only — small vs scrap payout.
	var raw := EXTRACT_ACCOUNT_XP + kills * 2
	return maxi(1, int(float(raw) * tl_payout * mode_payout))


static func award_wipe_account_xp(kills: int, mode_payout: float) -> int:
	return maxi(WIPE_ACCOUNT_XP_FLOOR + kills, int(float(WIPE_ACCOUNT_XP_FLOOR + kills) * mode_payout))


## In-run upgrade cards (temporary — gone on extract/wipe). Definitions and
## numbers live in UpgradeDefs; ranks owned are in GameState.run_ranks.
static func run_upgrade_pool() -> Array:
	return UpgradeDefs.all()


## True when this card can still be offered to the current hero.
static func can_offer(u: Dictionary) -> bool:
	if bool(u.get("evolution", false)):
		return recipe_ready(u)
	var hero := GameState.selected_character_id if GameState else ""
	if u.has("hero") and str(u["hero"]) != hero:
		return false
	var melee := GameState != null and GameState.weapon.has("melee")
	if bool(u.get("ranged_only", false)) and melee:
		return false
	var rank := GameState.run_rank(str(u["id"])) if GameState else 0
	if rank >= int(u.get("max_rank", 1)):
		return false
	## Drone cards stop once Helm's rig is full (4 drones).
	if hero == CharacterDefs.HELM_WISP_ID and str(u["id"]) in ["squadron", "scrap_drone"] and GameState:
		var w := GameState.weapon
		var have := int(w.get("drone_count", 0)) + GameState.run_rank("squadron") + GameState.run_rank("scrap_drone")
		if have >= int(w.get("drone_max", 4)):
			return false
	return true


## Depth E3: an evolution is ready when its base is at max rank and the partner
## is owned (or, for "ammo:shock", Shock ammo was picked up this run).
static func recipe_ready(c: Dictionary) -> bool:
	if GameState == null:
		return false
	var hero := GameState.selected_character_id
	if c.has("hero") and str(c["hero"]) != hero:
		return false
	if GameState.run_rank(str(c["id"])) > 0:
		return false
	var needs: Array = c.get("needs", [])
	if needs.size() < 2:
		return false
	var base := UpgradeDefs.get_def(str(needs[0]))
	if base.is_empty() or GameState.run_rank(str(needs[0])) < int(base.get("max_rank", 1)):
		return false
	var partner := str(needs[1])
	if partner.begins_with("ammo:"):
		return bool(GameState.run_ammo_seen.get(partner.substr(5), false))
	return GameState.run_rank(partner) > 0


static func ready_recipes() -> Array:
	var out: Array = []
	for c in RecipeDefs.all():
		if recipe_ready(c):
			out.append(c)
	return out


## Weighted roll of `count` distinct cards. luck > 1 boosts rare / epic odds
## (Lucky Vial). `exclude` ids are skipped (e.g. the cards being rerolled away).
static func roll_run_choices(count: int = UpgradeDefs.CHOICES_PER_LEVEL, exclude: Array = [], luck: float = 1.0, rng: RandomNumberGenerator = null) -> Array:
	var avail: Array = []
	var weights: Array = []
	for u in UpgradeDefs.all():
		if str(u["id"]) in exclude or not can_offer(u):
			continue
		var r := str(u.get("rarity", "common"))
		var w := float(UpgradeDefs.RARITY_WEIGHT.get(r, 10.0))
		if r == "rare":
			w *= luck
		elif r == "epic":
			w *= luck * 1.4
		if u.has("hero"):
			w *= UpgradeDefs.CLASS_WEIGHT_MULT
		if GameState and GameState.run_rank(str(u["id"])) > 0:
			w *= UpgradeDefs.OWNED_WEIGHT_MULT
		avail.append(u)
		weights.append(w)
	var out: Array = []
	while out.size() < count and not avail.is_empty():
		var total := 0.0
		for w in weights:
			total += float(w)
		var roll := (rng.randf() if rng else randf()) * total
		var i := 0
		while i < avail.size() - 1 and roll > float(weights[i]):
			roll -= float(weights[i])
			i += 1
		out.append(avail[i])
		avail.remove_at(i)
		weights.remove_at(i)
	## An evolution that is ready always takes a slot (the build's payoff).
	if RecipeDefs.GUARANTEE_SLOT:
		var evos := ready_recipes()
		if not evos.is_empty():
			var evo: Dictionary = evos[(rng.randi() if rng else randi()) % evos.size()]
			if out.size() >= count and count > 0:
				out[out.size() - 1] = evo
			else:
				out.append(evo)
	## Too few new cards (late run) — refill from excluded ones so there are 3.
	if out.size() < count and not exclude.is_empty():
		for u in UpgradeDefs.all():
			if out.size() >= count:
				break
			if str(u["id"]) in exclude and can_offer(u) and not out.has(u):
				out.append(u)
	return out


## Meta Hangar: see HangarDefs (shared camp upgrades, survivor stations,
## kennel, stash). The old flat %-stat list was retired in save v4 and refunded.
