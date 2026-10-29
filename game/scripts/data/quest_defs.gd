class_name QuestDefs
extends RefCounted

## Logbook (brief Part 8): daily quests, survivor story chains, camp milestones.
## Progress events (GameState.quest_event): kills, kills_kind, extract,
## extract_tier, extract_mult, ability, gear, event, elite.

## ---------------------------------------------------------------- daily
const DAILY_COUNT := 3
## Pool: type, needs (one is picked), reward per need, label.
const DAILY_POOL: Array = [
	{"type": "kills", "needs": [60, 100, 150], "rewards": [60, 90, 130], "label": "Kill %d enemies"},
	{"type": "kills_kind", "needs": [15, 25], "rewards": [70, 110], "label": "Kill %d %s",
		"kinds": ["scrap_hound", "rad_gator", "toxic_scorp", "glow_moth", "coil_spider", "rad_bat"]},
	{"type": "extract", "needs": [2, 3], "rewards": [80, 120], "label": "Extract %d times"},
	{"type": "extract_tier", "needs": [1], "rewards": [100], "label": "Extract on %s"},
	{"type": "extract_mult", "needs": [1], "rewards": [90], "label": "Extract at ×%.1f loot or more", "mults": [1.5, 2.0]},
	{"type": "gear", "needs": [2, 4], "rewards": [70, 120], "label": "Find %d pieces of gear"},
	{"type": "event", "needs": [1, 2], "rewards": [60, 100], "label": "Complete %d radio events"},
	{"type": "elite", "needs": [1], "rewards": [140], "label": "Kill an elite or boss", "min_tier": ModeDefs.ELITE_FROM_TIER},
]
## A pool entry may also carry "hero" / "pet" / "zone" (tier) requirements;
## roll_daily only offers what the player has unlocked (daily_is_unlocked).

## ---------------------------------------------------------------- stories
## Five steps per survivor (same objectives, their own words). The last step
## pays out their named Legendary weapon.
const STORY_STEPS: Array = [
	{"type": "extract", "need": 1, "reward": 60, "label": "Extract once"},
	{"type": "kills", "need": 80, "reward": 90, "label": "Kill 80 enemies"},
	{"type": "ability", "need": 25, "reward": 120, "label": "Use your ability 25 times"},
	{"type": "event", "need": 2, "reward": 150, "label": "Complete 2 radio events"},
	{"type": "extract_mult", "need": 1, "mult": 2.5, "reward": 0, "label": "Extract at ×2.5 loot or more"},
]
const STORIES := {
	"ash_rook": {"title": "The Last Shift", "legendary": "last_shift", "lore": [
		"Before the war, Rook cleared rubble so the convoys could roll. She liked the work. Honest weight.",
		"Her crew called her Foreman. Six of them. She still counts to six before she goes through a door.",
		"The collapse came at shift change. She heard it start and could not get them out.",
		"Now she goes in first, every time. Somebody has to hold the ceiling up.",
		"She welded their tags to an old launcher and called it Last Shift. It still burns hot."]},
	"vesper_thorn": {"title": "The Bell Tower", "legendary": "bellwether", "lore": [
		"Vesper shot for the army from a long way off. She never saw a single face.",
		"When the war ended she kept walking, because stopping meant thinking.",
		"She ended up in a bell tower with no food and a rifle with no rounds.",
		"Rook climbed up, sat down, and said nothing for an hour. Then she shared her bread.",
		"Vesper strung the tower's last bell to her rifle. Bellwether rings for the ones she missed."]},
	"pebble": {"title": "Gravedigger", "legendary": "gravedigger", "lore": [
		"Pebble worked the quarry. Hands like shovels, a laugh you could hear across the pit.",
		"When the plague came, she carried the sick out of the city. Two at a time.",
		"She carried the ones who didn't make it, too. Somebody had to dig.",
		"The hangar kids named her Pebble as a joke. She kept it because it made them laugh.",
		"Her maul is the shovel she used. Gravedigger, she calls it. It never forgets a hit."]},
	"bolt_juno": {"title": "Live Line", "legendary": "live_line", "lore": [
		"Juno was an electrician's apprentice when the lights started going out.",
		"His boss left. Juno didn't. He kept one city block lit through the whole plague.",
		"He talked to the transformers to stay awake. He still talks too much.",
		"He wired his own gauntlet from the block's last breaker. It bites.",
		"Live Line, he named it. The hangar generator runs because Juno won't let it stop."]},
	"sister_cinder": {"title": "The Censer", "legendary": "censer", "lore": [
		"Sister Cinder ran a field hospital in a cathedral when the plague came.",
		"Raiders came for the medicine. She told them to wait in the nave.",
		"She burned it down with the medicine inside rather than let them take it from the sick.",
		"Now she brews tonics in the hangar. Warm hands, steel underneath.",
		"Her rifle carries the cathedral's last censer. Its smoke still heals."]},
	"quill_marrow": {"title": "Bonesaw", "legendary": "bonesaw", "lore": [
		"Quill was a war medic who ran out of patients and started asking questions.",
		"She took the dead apart to understand the plague. Carefully. Respectfully. Mostly.",
		"Her notebook has every creature she has ever opened. Hundreds of pages.",
		"She knows where everything is soft. It makes the others a little nervous.",
		"Bonesaw finds the weak spot every time. She drew the map herself."]},
	"nyx_caldera": {"title": "Twin Debts", "legendary": "twin_debts", "lore": [
		"Nyx ran medicine across the war lines at night and sold to both sides.",
		"She always knew a back way out. Except once.",
		"Cinder pulled her off a raider's hook and stitched her up without asking a thing.",
		"Nyx will not admit she owes her. She just never leaves the hangar for long.",
		"Twin Debts: one blade for what she owes, one for what she's owed."]},
	"helm_wisp": {"title": "Mayday", "legendary": "mayday", "lore": [
		"Helm flew supply drops over the war zone. Low and fast, singing the whole way.",
		"She was shot down near an old airfield. The crash is how the others found the hangar.",
		"She built her first drone out of the wreck's instruments. It follows her like a gull.",
		"She swears she'll get a plane flying again. Nobody laughs anymore.",
		"Mayday is her old flare pistol, rebuilt. When she calls, the drones come home."]},
}

## ---------------------------------------------------------------- milestones
## Long goals; each unlocks a hangar cosmetic layer (assets/sprites/hangar/cosmetic_<id>.png)
## or a trophy. check = how GameState decides it's done.
const MILESTONES: Array = [
	{"id": "max_generator", "name": "Max the Generator", "desc": "Generator at max rank", "check": "camp_rank", "key": "generator", "need": 3, "cosmetic": "banner"},
	{"id": "stations_3", "name": "Every Corner Lit", "desc": "Every survivor station at rank 3+", "check": "stations_min", "need": 3, "cosmetic": "campfire"},
	{"id": "full_kennel", "name": "Good Dogs", "desc": "All three dogs at kennel rank 3", "check": "kennel_min", "need": 3, "cosmetic": "toys"},
	{"id": "extracts_25", "name": "Seasoned Crew", "desc": "Extract 25 times", "check": "extracts", "need": 25, "cosmetic": "flag"},
	{"id": "first_legendary", "name": "Storied Steel", "desc": "Own a Legendary weapon", "check": "legendary", "need": 1, "cosmetic": "case"},
	{"id": "kill_dread_naught", "name": "Scrap the Dread Naught", "desc": "Kill a Dread Naught", "check": "trophy", "key": "dread_naught", "need": 1, "cosmetic": ""},
	{"id": "kill_mutant_overlord", "name": "Fell the Overlord", "desc": "Kill a Mutant Overlord", "check": "trophy", "key": "mutant_overlord", "need": 1, "cosmetic": ""},
]


static func story(hero: String) -> Dictionary:
	return STORIES.get(hero, {})


static func milestone(id: String) -> Dictionary:
	for m in MILESTONES:
		if str(m["id"]) == id:
			return m
	return {}


## What the player can reach today: highest tier, heroes, pets, zone tiers and
## the mob kinds that spawn there. `max_tier` < 1 = read it from GameState.
static func unlocked_context(max_tier: int = 0) -> Dictionary:
	var t := max_tier if max_tier >= 1 else GameState.highest_unlocked_tier()
	var heroes: Array = []
	for h in CharacterDefs.PLAYABLE_IDS:
		if not GameState.has_method("hero_unlocked") or bool(GameState.call("hero_unlocked", h)):
			heroes.append(str(h))
	var pets: Array = []
	for p in PetDefs.all_pets():
		if GameState.pet_available(str(p["id"])):
			pets.append(str(p["id"]))
	## Every tier spawns the T1 pool (match_controller._roll_enemy_kind).
	var kinds: Array = []
	for k in EnemyDefs.ids_for_tier(1):
		kinds.append(str(k))
	return {"max_tier": t, "heroes": heroes, "pets": pets, "kinds": kinds}


## Does a rolled daily (or a pool entry) only ask for unlocked content?
static func daily_is_unlocked(q: Dictionary, ctx: Dictionary) -> bool:
	var t := int(ctx.get("max_tier", 1))
	if int(q.get("min_tier", 1)) > t or int(q.get("tier", 1)) > t or int(q.get("zone", 1)) > t:
		return false
	if str(q.get("type", "")) == "elite" and t < ModeDefs.ELITE_FROM_TIER:
		return false
	if q.has("hero") and not (str(q["hero"]) in (ctx.get("heroes", []) as Array)):
		return false
	if q.has("pet") and not (str(q["pet"]) in (ctx.get("pets", []) as Array)):
		return false
	if q.has("kind") and ctx.has("kinds") and not (str(q["kind"]) in (ctx["kinds"] as Array)):
		return false
	return true


static func dailies_unlocked(qs: Array, ctx: Dictionary) -> bool:
	for q in qs:
		if typeof(q) != TYPE_DICTIONARY or not daily_is_unlocked(q, ctx):
			return false
	return true


## The day's three quests (deterministic from the date and what's unlocked).
static func roll_daily(date: String, max_tier: int, ctx: Dictionary = {}) -> Array:
	if ctx.is_empty():
		ctx = unlocked_context(max_tier)
	max_tier = int(ctx.get("max_tier", max_tier))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var pool: Array = []
	for q in DAILY_POOL:
		if daily_is_unlocked(q, ctx):
			pool.append(q)
	var out: Array = []
	while out.size() < DAILY_COUNT and not pool.is_empty():
		var q: Dictionary = pool[rng.randi() % pool.size()]
		pool.erase(q)
		var i := rng.randi() % (q["needs"] as Array).size()
		var need := int(q["needs"][i])
		var d := {"type": str(q["type"]), "need": need, "have": 0, "reward": int(q["rewards"][i]), "claimed": false}
		match str(q["type"]):
			"kills_kind":
				var kinds: Array = []
				for kk in q["kinds"]:
					if not ctx.has("kinds") or str(kk) in (ctx["kinds"] as Array):
						kinds.append(kk)
				if kinds.is_empty():
					kinds = q["kinds"]
				var kind: String = kinds[rng.randi() % kinds.size()]
				d["kind"] = kind
				d["label"] = str(q["label"]) % [need, str(EnemyDefs.get_kind(kind).get("display_name", kind))]
			"extract_tier":
				var t := rng.randi_range(1, max_tier)
				d["tier"] = t
				d["label"] = str(q["label"]) % str(ModeDefs.tier_mode(t).get("display_name", "Haze"))
			"extract_mult":
				var mu := float(q["mults"][rng.randi() % (q["mults"] as Array).size()])
				d["mult"] = mu
				d["label"] = str(q["label"]) % mu
			"elite":
				d["label"] = str(q["label"])
			_:
				d["label"] = str(q["label"]) % need
		out.append(d)
	return out


## Does a progress event count toward a quest? Returns how much to add.
static func progress_amount(q: Dictionary, type: String, amount: int, ctx: Dictionary) -> int:
	var qt := str(q.get("type", ""))
	if qt == "kills_kind":
		return amount if type == "kills" and str(ctx.get("kind", "")) == str(q.get("kind", "")) else 0
	if qt == "extract_tier":
		return 1 if type == "extract" and int(ctx.get("tier", 0)) >= int(q.get("tier", 1)) else 0
	if qt == "extract_mult":
		return 1 if type == "extract" and float(ctx.get("mult", 0.0)) >= float(q.get("mult", 2.0)) - 0.001 else 0
	return amount if qt == type else 0
