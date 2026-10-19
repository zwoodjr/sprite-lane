class_name RadioDefs
extends RefCounted

## Depth Update E4 — Helm's radio jobs, camp cameos, the Dust Warden and the
## stay-or-go stakes. All tuning here.
##   Contracts (1–2 per run): bounty an elite, recover a medicine cache, hold
##   Juno's relay, escort Pebble and a sick survivor out, retrieve a black box.
##   Services (1–2 per run): Cinder's field tent, Nyx's black market (at an
##   extract window), Vesper's overwatch, Rook's vault, Helm's care package.
##   Every job is run by a survivor you are NOT playing; helping them moves
##   their story on (CAMEO_STORY_SHARE of their current chapter).

const CONTRACTS_PER_RUN := Vector2i(1, 2)
const CONTRACT_AT: Array = [Vector2(55.0, 80.0), Vector2(165.0, 215.0)]
const SERVICES_PER_RUN := Vector2i(1, 2)
const SERVICE_AT: Array = [Vector2(30.0, 50.0), Vector2(115.0, 150.0)]
## A cameo help moves that survivor's current story chapter this far (share of its need).
const CAMEO_STORY_SHARE := 0.34
const NPC_WORLD := 56.0
const NPC_FEET := 20.0
const MAP_COLOR := Color(0.55, 1.0, 0.6)

const JOBS := {
	## ---------------- contracts ----------------
	"bounty": {"kind": "contract", "giver": "quill_marrow", "name": "Quill's Bounty", "min_tier": 3,
		"radio": "Helm: Quill's posted a bounty on an elite — she wants the specimen. Marked it for you.",
		"reward_scrap": 60, "reward": {"dust_shard": 2}},
	"medicine_cache": {"kind": "contract", "giver": "nyx_caldera", "name": "Medicine Cache",
		"radio": "Helm: Nyx says she stashed medicine out there before the war got bad. Something's sitting on it.",
		"distance": Vector2(520.0, 780.0), "crates": 2, "guards": 4, "radius": 70.0, "reward_scrap": 40, "reward": {}},
	"defend_relay": {"kind": "contract", "giver": "bolt_juno", "name": "Juno's Relay",
		"radio": "Helm: Juno's patching a relay so I can hear you further out. Keep him alive for 30 seconds!",
		"distance": Vector2(420.0, 640.0), "hold": 30.0, "radius": 120.0, "wave_every": 4.0, "wave": 2, "give_up": 120.0,
		"reward_scrap": 70, "reward": {"machine_oil": 2}},
	"rescue": {"kind": "contract", "giver": "pebble", "name": "Carry Them Out",
		"radio": "Helm: Pebble found someone sick out there and won't leave them. Walk her to a pad and get them home.",
		"distance": Vector2(480.0, 720.0), "follow_speed": 165.0, "near": 230.0, "reward_scrap": 90, "reward": {"herb": 3}},
	"black_box": {"kind": "contract", "giver": "helm_wisp", "name": "Black Box",
		"radio": "Helm: There's a plane down out there. I need its black box — hold still by the wreck to pry it loose.",
		"distance": Vector2(560.0, 820.0), "channel": 3.0, "radius": 70.0, "reward_scrap": 80, "reward": {"dust_shard": 1}},
	## ---------------- services ----------------
	"field_tent": {"kind": "service", "giver": "sister_cinder", "name": "Cinder's Field Tent",
		"radio": "Helm: Cinder's pitched a field tent nearby. Get patched up — she'll burn the plague out of you too.",
		"distance": Vector2(360.0, 560.0), "radius": 80.0, "heal_frac": 1.0, "cleanse": 100.0, "life": 70.0},
	"black_market": {"kind": "service", "giver": "nyx_caldera", "name": "Nyx's Black Market", "at_window": true,
		"radio": "Helm: Nyx is trading by the pads. Bring scrap — she doesn't take promises.",
		"radius": 80.0, "offset": 120.0},
	"overwatch": {"kind": "service", "giver": "vesper_thorn", "name": "Vesper's Overwatch",
		"radio": "Helm: Vesper's up a tower near you. She'll take the big ones while you stay close.",
		"distance": Vector2(260.0, 420.0), "life": 50.0, "every": 2.4, "damage": 90.0, "range": 680.0},
	"vault": {"kind": "service", "giver": "ash_rook", "name": "Rook's Vault",
		"radio": "Helm: Rook found a sealed vault and brought charges. Cover her while the fuse burns!",
		"distance": Vector2(420.0, 640.0), "radius": 100.0, "fuse": 4.0, "guards": 3, "scrap": 30, "min_rarity": "rare"},
	"care_package": {"kind": "service", "giver": "helm_wisp", "name": "Helm's Care Package",
		"radio": "Helm: Care package incoming! My drone's dropping it right on you.", "tonics": 3, "heal": 12.0},
}

## Nyx's black market (run scrap = the bag's scrap).
const MARKET := [
	{"id": "medkit", "name": "Field Medkit", "desc": "Heal 60% now", "cost": 25, "heal_frac": 0.6},
	{"id": "ammo", "name": "Special Ammo", "desc": "A can of special rounds", "cost": 30},
	{"id": "lock", "name": "Pack Lock", "desc": "Keep your pack even if you go down", "cost": 45},
	{"id": "reroll", "name": "Marked Deck", "desc": "+1 level-up reroll", "cost": 35},
]

## --- Dust Warden ----------------------------------------------------------------
## Spawns on the pads when the last window opens. Below WARDEN_BOSS_TIER it fights
## as an elite; from there it is a real boss with the Dust pulse.
const WARDEN_KIND := "dust_warden"
const WARDEN_BOSS_TIER := 5
const WARDEN_PULSE_EVERY := 6.5
const WARDEN_PULSE_WINDUP := 1.1
const WARDEN_PULSE_RADIUS := 170.0
const WARDEN_PULSE_DAMAGE := 22.0

## --- Stay-or-go stakes ------------------------------------------------------------
## From window 2 on, each window shows what staying brings next.
const STAKES_FROM_WINDOW := 2
const STAKES := {
	"elite_pair": {"label": "elite pair", "min_tier": 1},
	"raider_crew": {"label": "raider crew", "min_tier": 3},
	"boss": {"label": "a boss", "min_tier": 5},
	"swarm": {"label": "a swarm", "min_tier": 1, "count": 9},
	"plague_fog": {"label": "plague fog", "min_tier": 5, "zones": 3},
}


static func job(id: String) -> Dictionary:
	return JOBS.get(id, {})


## Jobs of a kind whose giver isn't the hero being played (and open at this tier).
static func jobs_for(kind: String, hero: String, tier: int = 10) -> Array:
	var out: Array = []
	for k in JOBS.keys():
		var j: Dictionary = JOBS[k]
		if str(j["kind"]) == kind and str(j["giver"]) != hero and tier >= int(j.get("min_tier", 1)):
			out.append(str(k))
	return out


static func stakes_for(tier: int) -> Array:
	var out: Array = []
	for k in STAKES.keys():
		if tier >= int(STAKES[k]["min_tier"]):
			out.append(str(k))
	return out
