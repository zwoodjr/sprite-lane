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
}

## At-extract bonuses.
const AMBUSH_BOUNTY := {"name": "Ambush Bounty", "radius": 240.0, "per_enemy": 12, "cap": 120}
const PET_BOND := {"name": "Pet Bond", "radius": 170.0, "xp": 10}
## Kennel bond levels from Pet Bond XP: +pet damage per level.
const BOND_XP_PER_LEVEL := 50
const BOND_MAX_LEVEL := 10
const BOND_DAMAGE_PER_LEVEL := 0.03


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
