class_name HangarDefs
extends RefCounted

## The Hangar (brief Part 2 + Part 6). Three layers of permanent upgrades bought
## with banked scrap, plus the stash. Ranks live in GameState.camp (id -> rank).
##   shared   — Generator, Radio Tower, Scrap Press, Ammo Bench (3 big ranks)
##   station  — one per survivor, "station_<hero id>" (3 big ranks: weapon + trick)
##   kennel   — one per dog, "kennel_<pet id>" (3 ranks)
##   stash    — "stash" (5 ranks of +40 slots; 80 → 280)
##   pack     — "backpack" (3 ranks of carry room, MedicineDefs)
## Every tuning number lives here. Arrays indexed by rank (index 0 = not bought).

## Hangar v5 (Oct 2026): shared + station upgrades went from 5 small ranks to
## 3 big, felt ones (same total price). Old ranks merge pairwise
## (V5_RANK_MAP); anything a save paid beyond its merged rank is refunded.
## Bunker economy v6 (Oct 2026): priced against measured payouts (bot, leave at
## window 2: Haze ~180, Smog ~400, Blight ~670, Shroud ~1.2k, Blackout ~1.6k,
## Dustfall ~2k after the top-tier trim). Whole bunker ~90k = roughly 45-60 runs;
## the cheapest open rank is always ~1-3 runs of your current tier away.
## Rank 2 opens after a Smog extract, rank 3 after Shroud (RANK_GATE).
const SHARED_PRICES: Array = [400, 1600, 4800]
const STATION_PRICES: Array = [250, 1100, 3300]
## v5 prices: only for migrating v4 saves (refund math), never for buying.
const V5_SHARED_PRICES: Array = [250, 900, 2100]
const V5_STATION_PRICES: Array = [200, 700, 1580]
const V4_SHARED_PRICES: Array = [100, 250, 500, 900, 1500]
const V4_STATION_PRICES: Array = [80, 200, 400, 700, 1100]
const V5_RANK_MAP: Array = [0, 1, 1, 2, 2, 3]
## Hangar art was painted for 5 stages; rank r shows stages up to ART_STAGE[r].
const ART_STAGE: Array = [0, 1, 3, 5]
const KENNEL_PRICES: Array = [200, 650, 1600]
const STASH_PRICES: Array = [300, 700, 1300, 2200, 3500]
## Tier you must have extracted from before buying rank i+1 (0 = open).
const RANK_GATE: Array = [0, 3, 6]
const STASH_GATE: Array = [0, 2, 4, 6, 8]

const STASH_BASE_SLOTS := 80
const STASH_SLOTS_PER_RANK := 40

const SHARED_IDS: Array = ["generator", "radio_tower", "scrap_press", "ammo_bench"]
## Insurance Locker (one-time buy): unlocks the INSURE button on worn gear.
const INSURANCE_ID := "insurance"
const INSURANCE_PRICES: Array = [400]

## Shared camp upgrades. Values by rank (0..5).
const SHARED := {
	"generator": {
		"name": "Generator", "icon": "GEN",
		"blurb": "Juno keeps it humming. Lights the hangar and toughens everyone.",
		"hp": [0, 16, 32, 50],
		"desc": "+%d max HP for every survivor",
	},
	"radio_tower": {
		"name": "Radio Tower", "icon": "RADIO",
		"blurb": "Helm's patched mast. Hears the pads before they open.",
		"reveal": [0.0, 5.0, 10.0, 15.0],
		"desc": "Extract pads revealed %ds earlier",
	},
	"scrap_press": {
		"name": "Scrap Press", "icon": "PRESS",
		"blurb": "Crushes loose junk into something worth banking.",
		"scrap": [0.0, 0.12, 0.25, 0.4],
		"desc": "+%d%% scrap from every run",
	},
	"ammo_bench": {
		"name": "Ammo Bench", "icon": "AMMO",
		"blurb": "Special-ammo cans start turning up in the wastes for everyone.",
		## Special ammo types that can drop as pickups (Helm's Supply Drop ignores this).
		"types": [[], ["incendiary", "frost"], ["incendiary", "frost", "shock"],
			["incendiary", "frost", "shock", "explosive"]],
		"duration": [0.0, 0.0, 3.0, 7.0],
		"odds": [0.0, 1.0, 1.25, 2.0],
	},
}

## Survivor stations: shared curves + per-hero ability keys that scale.
const STATION_WEAPON_DAMAGE: Array = [0.0, 0.1, 0.2, 0.32]
const STATION_ABILITY_CD: Array = [1.0, 0.93, 0.87, 0.8]
const STATION_ABILITY_POWER: Array = [1.0, 1.12, 1.27, 1.45]

const STATIONS := {
	"ash_rook": {"name": "Rook's Weapon Rack", "power_keys": ["ram_damage", "ram_radius"],
		"add_keys": {"duration": [0.0, 0.0, 0.5, 1.0]},
		"notes": ["Oiled rails, shaped shells", "Longer RUSH, reinforced ram plate", "Rush lasts even longer"]},
	"vesper_thorn": {"name": "Vesper's Bell Loft", "power_keys": ["vial_mult", "cloud_dps", "coat_time"],
		"notes": ["Clean bore, stronger vial mix", "Bigger poison cloud, longer coating", "Master tincture"]},
	"pebble": {"name": "Pebble's Anvil", "power_keys": ["damage_mult", "radius", "stun"],
		"notes": ["Re-forged maul, wider slam", "Longer stun, heavier swing", "Quake slam"]},
	"bolt_juno": {"name": "Juno's Wiring Bench", "power_keys": ["damage_mult", "stun"],
		"add_keys": {"chain": [0, 0, 1, 2]},
		"notes": ["Fresh coils, hotter Overload", "+1 arc jump, longer stun", "+2 arc jumps"]},
	"sister_cinder": {"name": "Cinder's Medicine Table", "power_keys": ["heal"],
		"notes": ["Re-wrapped stock, second tonic slot", "Stronger draught, brews two at a time", "Cathedral recipe"]},
	"quill_marrow": {"name": "Quill's Dissection Table", "power_keys": ["damage_mult", "mark_time"],
		"notes": ["Honed bayonet, longer marks", "Deeper lunge, sharper notes", "Surgeon's eye"]},
	"nyx_caldera": {"name": "Nyx's Smuggler Crates", "power_keys": ["damage_mult", "hit_radius"],
		"notes": ["Balanced blades, wider rush", "Quicker rush, keener edges", "Night-runner kit"]},
	"helm_wisp": {"name": "Helm's Drone Workbench", "power_keys": ["temp_time", "overclock_time"],
		"add_keys": {"temp_drones": [0, 0, 1, 1]},
		"drone_damage": [1.0, 1.12, 1.27, 1.45],
		"notes": ["Sidearm tune-up, drone servos", "+1 called drone, overclock coils", "Squadron firmware"]},
}

## Kennel: per-dog rank overrides merged onto PetDefs (index = rank 0..3).
const KENNEL := {
	"noel": {
		"name": "Noel", "blurb": "Rampage lasts longer and hits harder; top rank chains to the next attacker.",
		"rampage_aoe_damage": [26.0, 32.0, 38.0, 46.0],
		"rampage_linger": [0.0, 1.0, 2.0, 3.0],
		"rampage_chain": [0, 0, 0, 2],
		"rank_text": ["", "Rampage +25% damage, lingers 1s", "+45% damage, lingers 2s", "+75% damage, chains to 2 more attackers"],
	},
	"bentley": {
		"name": "Bentley", "blurb": "Bark reaches farther and briefly stuns; gifts get better.",
		"bark_radius": [200.0, 250.0, 300.0, 360.0],
		"bark_stun": [0.0, 0.4, 0.6, 0.9],
		"gift_good": [0.2, 0.28, 0.36, 0.48],
		"gift_great": [0.04, 0.08, 0.12, 0.18],
		"rank_text": ["", "Bark reaches farther, 0.4s stun", "Bigger bark, 0.6s stun, better gifts", "Huge bark, 0.9s stun, best gifts"],
	},
	"lillie": {
		"name": "Lillie", "blurb": "Builds to her full design: damage trail, then a fierce blast on contact.",
		"ram_impact_damage": [40.0, 50.0, 56.0, 64.0],
		"ram_trail": [0, 0, 1, 1],
		"ram_blast": [0, 0, 0, 1],
		"rank_text": ["", "Headbutt +25% damage", "Charge leaves a damage trail", "Fierce AoE blast on contact"],
	},
	## Depth E6 mech pets (bays open once the mech is built in the Workshop).
	"mech_hound": {
		"name": "Mech Hound", "blurb": "Harder pounces, longer shock chains.",
		"ram_impact_damage": [30.0, 38.0, 44.0, 54.0],
		"shock_chain": [2, 3, 4, 6],
		"ram_cooldown": [5.0, 4.5, 4.0, 3.4],
		"rank_text": ["", "Pounce +25%, shock chains to 3", "Faster pounces, chains to 4", "Pounce +80%, chains to 6"],
	},
	"drone_bat": {
		"name": "Drone Bat", "blurb": "More shots per strafe, harder marks.",
		"strafe_shots": [4, 5, 6, 8],
		"strafe_damage": [7.0, 8.0, 9.0, 11.0],
		"strafe_mark_mult": [1.15, 1.18, 1.22, 1.28],
		"rank_text": ["", "5 shots per strafe", "6 shots, marks +22%", "8 shots, marks +28%"],
	},
	"rust_mule": {
		"name": "Rust Mule", "blurb": "Bigger shells, more to carry.",
		"mortar_damage": [34.0, 42.0, 50.0, 62.0],
		"mortar_radius": [90.0, 100.0, 110.0, 125.0],
		"pack_bonus": [2, 2, 3, 3],
		"rank_text": ["", "Shells +25% damage", "Bigger shells, +3 pack room", "Shells +80%, widest blast"],
	},
}

## Old flat %-stat Hangar (save v3). Only used to refund old spend: id -> [cost, step, curve].
const LEGACY := {
	"starting_hp": [90, 55, 1.35], "endurance": [80, 48, 1.38], "scrap_find": [75, 50, 1.4],
	"loot_quality": [95, 58, 1.4], "starting_damage": [110, 65, 1.4], "crit_chance": [100, 60, 1.42],
	"crit_damage": [115, 68, 1.42], "aoe_damage": [105, 62, 1.4], "dodge": [100, 60, 1.45],
	"block": [110, 65, 1.45], "move_speed": [85, 50, 1.38], "pickup_radius": [70, 42, 1.35],
	"pet_power": [100, 60, 1.4], "dash_cooldown": [85, 50, 1.35], "extract_grace": [125, 75, 1.45],
	"extract_payout": [120, 70, 1.45], "hangar_notes": [60, 40, 1.2], "insurance_slot": [200, 120, 1.5],
}


static func station_id(hero_id: String) -> String:
	return "station_" + hero_id


static func kennel_id(pet_id: String) -> String:
	return "kennel_" + pet_id


## "shared" | "station" | "kennel" | "stash" | "".
static func layer_of(id: String) -> String:
	if id in SHARED_IDS:
		return "shared"
	if id.begins_with("station_") and STATIONS.has(id.substr(8)):
		return "station"
	if id.begins_with("kennel_") and KENNEL.has(id.substr(7)):
		return "kennel"
	if id == "stash":
		return "stash"
	if id == "backpack":
		return "pack"
	if id == INSURANCE_ID:
		return "insure"
	return ""


static func prices(id: String) -> Array:
	match layer_of(id):
		"shared":
			return SHARED_PRICES
		"station":
			return STATION_PRICES
		"kennel":
			return KENNEL_PRICES
		"stash":
			return STASH_PRICES
		"pack":
			return MedicineDefs.PACK_PRICES
		"insure":
			return INSURANCE_PRICES
	return []


static func max_rank(id: String) -> int:
	return prices(id).size()


## Tier that must be extracted before buying rank `rank`+1 (0 = no gate).
static func gate_tier(id: String, rank: int) -> int:
	match layer_of(id):
		"shared", "station", "kennel", "pack":
			return int(RANK_GATE[clampi(rank, 0, RANK_GATE.size() - 1)])
		"stash":
			return int(STASH_GATE[clampi(rank, 0, STASH_GATE.size() - 1)])
	return 0


## Price of the next rank, or -1 when maxed / unknown.
static func cost(id: String, rank: int) -> int:
	var p := prices(id)
	if rank < 0 or rank >= p.size():
		return -1
	return int(p[rank])


static func display_name(id: String) -> String:
	match layer_of(id):
		"shared":
			return str(SHARED[id]["name"])
		"station":
			return str(STATIONS[id.substr(8)]["name"])
		"kennel":
			return "Kennel: %s" % str(KENNEL[id.substr(7)]["name"])
		"stash":
			return "Stash Lockbox"
		"pack":
			return "Field Backpack"
		"insure":
			return "Insurance Locker"
	return id


## What the given rank does (rank >= 1), one short line.
static func rank_text(id: String, rank: int) -> String:
	var r := clampi(rank, 0, max_rank(id))
	match layer_of(id):
		"shared":
			var d: Dictionary = SHARED[id]
			match id:
				"generator":
					return d["desc"] % int(d["hp"][r])
				"radio_tower":
					return d["desc"] % int(d["reveal"][r])
				"scrap_press":
					return d["desc"] % int(round(float(d["scrap"][r]) * 100.0))
				"ammo_bench":
					if r <= 0:
						return "No special-ammo pickups"
					var t: Array = d["types"][r]
					var s := "Ammo pickups: %s" % ", ".join(PackedStringArray(t))
					if float(d["duration"][r]) > 0.0:
						s += " · +%ds" % int(d["duration"][r])
					if float(d["odds"][r]) > 1.0:
						s += " · ×%.2f odds" % float(d["odds"][r])
					return s
		"station":
			var hero := id.substr(8)
			var st: Dictionary = STATIONS[hero]
			var notes: Array = st.get("notes", [])
			var note := str(notes[r - 1]) + ": " if r >= 1 and r <= notes.size() else ""
			return "%s+%d%% weapon dmg · −%d%% ability cooldown · +%d%% ability power" % [
				note, int(round(float(STATION_WEAPON_DAMAGE[r]) * 100.0)),
				int(round((1.0 - float(STATION_ABILITY_CD[r])) * 100.0)),
				int(round((float(STATION_ABILITY_POWER[r]) - 1.0) * 100.0))]
		"kennel":
			var k: Dictionary = KENNEL[id.substr(7)]
			return str((k["rank_text"] as Array)[r])
		"stash":
			return "%d stash slots" % stash_slots(r)
		"pack":
			return "Carry %d in a run (medicine weighs %d)" % [MedicineDefs.pack_capacity(r), MedicineDefs.MEDICINE_WEIGHT]
		"insure":
			return "Insure 1 worn piece per survivor: it comes home even if you die"
	return ""


static func blurb(id: String) -> String:
	match layer_of(id):
		"shared":
			return str(SHARED[id]["blurb"])
		"station":
			return "This survivor's corner. Each rank upgrades their weapon and signature trick."
		"kennel":
			return str(KENNEL[id.substr(7)]["blurb"])
		"stash":
			return "Shared lockbox for gear you extract with."
		"pack":
			return "More room for ingredients and medicine on the way home."
		"insure":
			return "A welded lockbox Helm drops with you. One piece of gear always comes back."
	return ""


## v4 (5-rank) → v5 (3-rank): [new rank, scrap to refund] for an old rank.
static func v5_migrate(id: String, old_rank: int) -> Array:
	var lay := layer_of(id)
	if lay != "shared" and lay != "station":
		return [old_rank, 0]
	var old_p: Array = V4_SHARED_PRICES if lay == "shared" else V4_STATION_PRICES
	var new_p: Array = V5_SHARED_PRICES if lay == "shared" else V5_STATION_PRICES
	var r := clampi(old_rank, 0, old_p.size())
	var n := int(V5_RANK_MAP[r])
	var paid := 0
	for i in range(r):
		paid += int(old_p[i])
	var worth := 0
	for i in range(n):
		worth += int(new_p[i])
	return [n, maxi(0, paid - worth)]


## Hangar art stage shown for a rank (shared / station art has 5 stages).
static func art_stage(id: String, rank: int) -> int:
	var lay := layer_of(id)
	if lay == "shared" or lay == "station":
		return int(ART_STAGE[clampi(rank, 0, ART_STAGE.size() - 1)])
	return rank


static func stash_slots(rank: int) -> int:
	return STASH_BASE_SLOTS + STASH_SLOTS_PER_RANK * clampi(rank, 0, STASH_PRICES.size())


static func shared_val(id: String, key: String, rank: int, default: Variant = 0.0) -> Variant:
	if not SHARED.has(id):
		return default
	var arr: Variant = (SHARED[id] as Dictionary).get(key, null)
	if not (arr is Array) or (arr as Array).is_empty():
		return default
	return (arr as Array)[clampi(rank, 0, (arr as Array).size() - 1)]


## Ability dict for a hero with its station rank applied (cooldown, power, adds).
static func apply_station_ability(hero_id: String, ability: Dictionary, rank: int) -> Dictionary:
	var a := ability.duplicate(true)
	if rank <= 0 or a.is_empty() or not STATIONS.has(hero_id):
		return a
	var r := clampi(rank, 0, STATION_PRICES.size())
	var st: Dictionary = STATIONS[hero_id]
	if a.has("cooldown"):
		a["cooldown"] = float(a["cooldown"]) * float(STATION_ABILITY_CD[r])
	var p := float(STATION_ABILITY_POWER[r])
	for k in st.get("power_keys", []):
		if a.has(k):
			a[k] = float(a[k]) * p
	var adds: Dictionary = st.get("add_keys", {})
	for k in adds.keys():
		var arr: Array = adds[k]
		var cur: Variant = a.get(k, 0)
		if cur is int:
			a[k] = int(cur) + int(arr[r])
		else:
			a[k] = float(cur) + float(arr[r])
	return a


static func station_weapon_damage(rank: int) -> float:
	return float(STATION_WEAPON_DAMAGE[clampi(rank, 0, STATION_PRICES.size())])


## Weapon dict tweaks from the station (Helm's drones scale with her bench).
static func apply_station_weapon(hero_id: String, weapon: Dictionary, rank: int) -> Dictionary:
	var w := weapon.duplicate(true)
	if rank <= 0 or not STATIONS.has(hero_id):
		return w
	var st: Dictionary = STATIONS[hero_id]
	if st.has("drone_damage") and w.has("drone_damage"):
		w["drone_damage"] = float(w["drone_damage"]) * float((st["drone_damage"] as Array)[clampi(rank, 0, STATION_PRICES.size())])
	return w


## Pet def with kennel rank overrides merged in (rank 0 = the base values here).
static func apply_kennel(pet: Dictionary, rank: int) -> Dictionary:
	var p := pet.duplicate(true)
	var id := str(p.get("id", ""))
	if not KENNEL.has(id):
		return p
	var r := clampi(rank, 0, KENNEL_PRICES.size())
	var k: Dictionary = KENNEL[id]
	for key in k.keys():
		if key in ["name", "blurb", "rank_text"]:
			continue
		var arr: Variant = k[key]
		if arr is Array:
			p[key] = (arr as Array)[r]
	p["kennel_rank"] = r
	return p


## Scrap refunded for an old (v3) flat Hangar: everything that was spent on it.
static func legacy_refund(meta: Dictionary) -> int:
	var total := 0
	for id in meta.keys():
		var row: Variant = LEGACY.get(str(id), null)
		if not (row is Array):
			continue
		var rank := maxi(0, int(meta[id]))
		for r in range(rank):
			var base := float(row[0]) + float(row[1]) * float(r)
			if float(row[2]) > 1.001 and r > 0:
				base *= pow(float(row[2]), float(r))
			total += maxi(1, int(round(base)))
	return total


## Every purchasable id, in display order per layer.
static func ids_for(layer: String) -> Array:
	match layer:
		"shared":
			return SHARED_IDS.duplicate()
		"station":
			var out: Array = []
			for h in CharacterDefs.PLAYABLE_IDS:
				out.append(station_id(h))
			return out
		"kennel":
			return [kennel_id("noel"), kennel_id("bentley"), kennel_id("lillie"),
				kennel_id("mech_hound"), kennel_id("drone_bat"), kennel_id("rust_mule")]
		"stash":
			return ["stash"]
		"pack":
			return ["backpack"]
		"insure":
			return [INSURANCE_ID]
	return []


static func all_ids() -> Array:
	return ids_for("shared") + ids_for("station") + ids_for("kennel") + ids_for("stash") + ids_for("pack") + ids_for("insure")


## Total scrap to max everything (sanity: ~45k per the brief).
static func full_max_cost() -> int:
	var total := 0
	for id in all_ids():
		for c in prices(id):
			total += int(c)
	return total
