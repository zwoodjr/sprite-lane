class_name EventDefs
extends RefCounted

## In-run events (brief Part 8): 1–2 per run, announced over Helm's radio with
## a HUD banner. Plus the two at-extract bonuses. All numbers here.

enum Kind { RADIO, WORLD_PULSE, EXTRACT_SIDE }

## How many events a run gets and when they fire (run seconds, before fast-timer scaling).
const EVENTS_PER_RUN := Vector2i(1, 2)
const FIRST_EVENT_AT := Vector2(45.0, 70.0)
const SECOND_EVENT_AT := Vector2(150.0, 200.0)

const IN_RUN := {
	"scrap_spike": {"name": "Scrap Spike", "weight": 1.0,
		"radio": "Helm: Got a scrap pile humming out there — marked it. Everything you pick up in that zone counts double for 30 seconds.",
		"duration": 30.0, "radius": 230.0, "distance": Vector2(380.0, 560.0), "scrap_mult": 2.0},
	"pad_heat": {"name": "Pad Heat", "weight": 0.9,
		"radio": "Helm: Next pads are running hot — they'll open early. Something's sitting on them, though.",
		"open_in": 12.0, "guards": 3},
	"herb_bloom": {"name": "Herb Bloom", "weight": 0.9,
		"radio": "Helm: Herbs are blooming all around you. Grab what you can — Cinder will thank you.",
		"count": 7, "heal": 10.0, "distance": Vector2(140.0, 460.0)},
	"supply_crash": {"name": "Supply Crash", "weight": 0.8,
		"radio": "Helm: A supply crate just came down near you — good stuff inside. Heads up, a pack smelled it too.",
		"distance": Vector2(300.0, 420.0), "min_rarity": "epic", "pack": 5, "pack_kind": "scrap_hound"},
	"dust_surge": {"name": "Dust Surge", "weight": 0.8,
		"radio": "Helm: Dust surge rolling in. You won't see much and they'll hit harder. Hold on for 20 seconds and it's worth it.",
		"duration": 20.0, "enemy_damage": 1.3, "dark": 0.42, "bonus_scrap": 30},
	"elite_hunt": {"name": "Elite Hunt", "weight": 0.7,
		"radio": "Helm: I've got an elite on the scope — marked it for you. Take it down and grab what it drops.",
		"bonus_scrap": 40, "bonus_min_rarity": "rare"},
	## --- Oct 2026 pool (after onboarding: "late": true) -----------------------
	## Every one is a choice: a cost you can dodge or a prize you can skip.
	"toxic_rain": {"name": "Toxic Rain", "weight": 0.8, "late": true,
		"radio": "Helm: Acid rain over you. Get under the shelter I marked — or stay out in it. Everything you kill out there pays half again.",
		"duration": 22.0, "radius": 150.0, "distance": Vector2(180.0, 320.0), "drain": 1.5, "tick": 0.5, "scrap_mult": 1.5},
	"caravan_wreck": {"name": "Caravan Wreck", "weight": 0.8, "late": true,
		"radio": "Helm: A medicine caravan went over out there. Two crates intact — heavy, and the plague will smell them on you.",
		"distance": Vector2(520.0, 760.0), "crates": 2, "scrap": 25},
	"distress_flare": {"name": "Distress Flare", "weight": 0.8, "late": true,
		"radio": "Helm: Someone fired a flare. Reach it in 25 seconds and they'll pay — but that flare's calling everything else too.",
		"duration": 25.0, "radius": 70.0, "distance": Vector2(420.0, 620.0), "wave": 5, "bonus_scrap": 45, "tonics": 2, "heal": 14.0},
	"raider_ambush": {"name": "Raider Ambush", "weight": 0.6, "late": true, "min_tier": 3,
		"radio": "Helm: Raider crew closing on you. Fight them for their kit, or run for it — they won't chase far.",
		"duration": 40.0, "bonus_scrap": 50},
	"helms_wager": {"name": "Helm's Wager", "weight": 0.7, "late": true,
		"radio": "Helm: Dust is heavy here. Stand in the marked spot for 3 seconds: the run pays more, but the Dust smells greed. Your call.",
		"duration": 20.0, "radius": 70.0, "distance": Vector2(150.0, 260.0), "hold": 3.0, "loot": 0.3, "greed": 1},
	"plague_nest": {"name": "Plague Nest", "weight": 0.7, "late": true, "min_tier": 2,
		"radio": "Helm: Plague nest nearby — it'll keep spitting them out till it's dead. Burn it for a good drop, or keep clear.",
		"distance": Vector2(380.0, 560.0), "every": 5.0, "spawn": 2, "kind": "muck_golem", "max": 60.0,
		"bonus_scrap": 40, "bonus_min_rarity": "rare"},
}

## At-extract bonuses.
const AMBUSH_BOUNTY := {"name": "Ambush Bounty", "radius": 240.0, "per_enemy": 12, "cap": 120}
const PET_BOND := {"name": "Pet Bond", "radius": 170.0, "xp": 10}
## Kennel bond levels from Pet Bond XP: +pet damage per level.
const BOND_XP_PER_LEVEL := 50
const BOND_MAX_LEVEL := 10
const BOND_DAMAGE_PER_LEVEL := 0.03


## Events that can roll: "late" ones only once onboarding is done, and only at
## their min tier.
static func pool(late_ok: bool, tier: int) -> Array:
	var out: Array = []
	for k in IN_RUN.keys():
		var d: Dictionary = IN_RUN[k]
		if bool(d.get("late", false)) and not late_ok:
			continue
		if tier < int(d.get("min_tier", 1)):
			continue
		out.append(str(k))
	return out


static func roll_event(rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var total := 0.0
	for k in IN_RUN.keys():
		if not k in exclude:
			total += float(IN_RUN[k]["weight"])
	var r := rng.randf() * total
	for k in IN_RUN.keys():
		if k in exclude:
			continue
		r -= float(IN_RUN[k]["weight"])
		if r <= 0.0:
			return str(k)
	return str(IN_RUN.keys()[0])


static func get_in_run(id: String) -> Dictionary:
	return IN_RUN.get(id, {})


## Legacy catalog shape (smoke test / tools): every event + the extract bonuses.
static func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in IN_RUN.keys():
		out.append({"id": k, "kind": Kind.RADIO, "name": IN_RUN[k]["name"], "toast": IN_RUN[k]["radio"], "weight": IN_RUN[k]["weight"]})
	out.append({"id": "extract_ambush_bounty", "kind": Kind.EXTRACT_SIDE, "name": AMBUSH_BOUNTY["name"], "toast": "", "weight": 0.0})
	out.append({"id": "extract_pet_bond", "kind": Kind.EXTRACT_SIDE, "name": PET_BOND["name"], "toast": "", "weight": 0.0})
	return out


static func get_event(id: String) -> Dictionary:
	for e in catalog():
		if str(e.get("id", "")) == id:
			return e.duplicate(true)
	return {}


static func radio_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in catalog():
		if int(e.get("kind", -1)) == Kind.RADIO:
			out.append(e)
	return out


## Flavour radio chatter early in a run (no gameplay).
const CHATTER: Array = [
	"Helm: Radio check. You're loud and clear, wanderer.",
	"Helm: Dust looks thin today. Don't get comfortable.",
	"Helm: Juno says the generator's purring. Come home in one piece.",
]

static func debug_radio_ping(rng: RandomNumberGenerator = null) -> Dictionary:
	var i := (rng.randi() if rng else randi()) % CHATTER.size()
	return {"id": "chatter", "toast": CHATTER[i]}
