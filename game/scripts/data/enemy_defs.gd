class_name EnemyDefs
extends RefCounted

## Sheet-locked mob roster. Look = crop/port only; names = Wanderer labels.
## Combat archetype maps onto existing raider / charger / brute behaviors.

const TIER_NORMAL := 1
const TIER_MID := 2
const TIER_FINAL := 3
## Mechanical mobs — Bolt Juno's Short Circuit hits these hardest.
const MACHINE_IDS := ["iron_horse", "coil_spider", "scrap_hound", "fusion_golem", "dread_naught", "mech_wyrm", "mech_wyrm_b", "cyber_juggernaut"]


## Elite / boss roles (Part 3). These kinds never come from the random pools;
## the match spawns them on the tier's elite / boss schedule (ModeDefs).
const ROLE_KINDS := {"cyber_juggernaut": "elite", "dread_naught": "boss", "mutant_overlord": "boss"}
const ELITE_KINDS: Array = ["cyber_juggernaut"]
const BOSS_KINDS: Array = ["dread_naught", "mutant_overlord"]
## Stat multipliers on top of the tier's enemy strength.
const ROLE_STATS := {
	"elite": {"hp": 2.2, "damage": 1.25, "speed": 1.0, "tier": 2},
	"boss": {"hp": 5.0, "damage": 1.4, "speed": 0.9, "tier": 3},
}


static func all_kinds() -> Array[Dictionary]:
	return [
		## --- Tier 1 (normal) ---
		_k("rad_gator", "Rad-Gator", 1, "raider", 48.0, 110.0, 9.0, 1.05),
		_k("toxic_scorp", "Toxic Scorp", 1, "charger", 32.0, 165.0, 12.0, 1.0),
		_k("glow_moth", "Glow-Moth", 1, "raider", 28.0, 140.0, 7.0, 0.95),
		_k("scrap_hound", "Scrap-Hound", 1, "charger", 26.0, 180.0, 11.0, 0.95),
		_k("dune_stalker", "Dune-Stalker", 1, "raider", 36.0, 120.0, 8.0, 1.0),
		_k("coil_spider", "Coil-Spider", 1, "charger", 30.0, 160.0, 10.0, 0.95),
		_k("rad_bat", "Rad-Bat", 1, "raider", 22.0, 155.0, 6.0, 0.9),
		_k("iron_horse", "Iron-Horse", 1, "charger", 44.0, 150.0, 13.0, 1.1),
		_k("chimera_rat", "Chimera-Rat", 1, "raider", 34.0, 130.0, 8.0, 1.0),
		_k("muck_golem", "Muck-Golem", 1, "brute", 70.0, 80.0, 8.0, 1.15),
		_k("scav_bear_cub", "Scav-Bear Cub", 1, "charger", 38.0, 145.0, 12.0, 1.0),
		_k("ash_singer", "Ash-Singer", 1, "raider", 30.0, 125.0, 7.0, 0.95),
		## --- Tier 2 (mid / TL pressure) ---
		_k("scav_bear", "Scav-Bear", 2, "brute", 150.0, 85.0, 12.0, 1.25),
		_k("dune_serpent", "Dune-Serpent", 2, "charger", 90.0, 150.0, 14.0, 1.2),
		_k("fusion_golem", "Fusion-Golem", 2, "brute", 180.0, 65.0, 11.0, 1.35),
		_k("scorpion_king", "Scorpion King", 2, "charger", 110.0, 140.0, 15.0, 1.2),
		_k("dread_naught", "Dread-Naught", 2, "brute", 200.0, 75.0, 14.0, 1.4),
		_k("glow_moth_queen", "Glow-Moth Queen", 2, "raider", 100.0, 130.0, 12.0, 1.15),
		_k("mech_wyrm", "Mech-Wyrm", 2, "charger", 120.0, 135.0, 15.0, 1.25),
		_k("mech_wyrm_b", "Mech-Wyrm", 2, "brute", 140.0, 100.0, 13.0, 1.3),
		_k("geist_alpha", "Geist-Alpha", 2, "raider", 95.0, 125.0, 11.0, 1.15),
		## --- Tier 3 (last extract / round final) ---
		_k("ash_wraiths", "Ash-Wraiths", 3, "raider", 160.0, 130.0, 14.0, 1.35),
		_k("mutant_overlord", "Mutant Overlord", 3, "brute", 320.0, 70.0, 18.0, 1.7),
		_k("cyber_juggernaut", "Cyber-Juggernaut", 3, "brute", 300.0, 80.0, 16.0, 1.65),
		_k("void_spider", "Void-Spider", 3, "charger", 220.0, 145.0, 17.0, 1.5),
		_k("wasteland_god_entity", "Wasteland God-Entity", 3, "brute", 360.0, 60.0, 20.0, 1.8),
		_k("apocalypse_wraith", "Apocalypse Wraith", 3, "raider", 240.0, 120.0, 16.0, 1.55),
	]


static func ids_for_tier(tier: int) -> Array[String]:
	var out: Array[String] = []
	for k in all_kinds():
		if int(k["tier"]) == tier and not ROLE_KINDS.has(str(k["id"])):
			out.append(str(k["id"]))
	return out


static func get_kind(id: String) -> Dictionary:
	for k in all_kinds():
		if str(k["id"]) == id:
			return k.duplicate(true)
	## Fallback
	return all_kinds()[0].duplicate(true)


static func combat_kinds_table() -> Dictionary:
	## Flattened table for Enemy.KINDS merge — preserves behavior keys.
	var table: Dictionary = {}
	for k in all_kinds():
		var arch: String = str(k["archetype"])
		var base := _archetype_base(arch)
		var entry := base.duplicate(true)
		entry["hp"] = float(k["hp"])
		entry["speed"] = float(k["speed"])
		entry["damage"] = float(k["damage"])
		entry["scale"] = float(k["scale"])
		entry["sprite"] = str(k["sprite"])
		entry["anim"] = str(k["anim"])
		entry["display_name"] = str(k["display_name"])
		entry["tier"] = int(k["tier"])
		entry["archetype"] = arch
		entry["scrap"] = k["scrap"]
		entry["xp"] = int(k["xp"])
		table[str(k["id"])] = entry
	## Keep legacy ids pointing at early T1 stand-ins so old scenes still boot.
	table["raider"] = table["rad_gator"].duplicate(true)
	table["charger"] = table["scrap_hound"].duplicate(true)
	table["brute"] = table["muck_golem"].duplicate(true)
	return table


static func _archetype_base(arch: String) -> Dictionary:
	match arch:
		"charger":
			return {
				"range": 140.0, "pref": 0.0, "cooldown": 1.6, "windup": 0.45,
				"tint": Color(1, 1, 1), "scrap": Vector2i(1, 3), "xp": 4,
			}
		"brute":
			return {
				"range": 330.0, "pref": 230.0, "cooldown": 2.0, "windup": 0.6,
				"tint": Color(1, 1, 1), "scrap": Vector2i(3, 7), "xp": 10,
			}
		_:
			return {
				"range": 300.0, "pref": 190.0, "cooldown": 1.3, "windup": 0.38,
				"tint": Color(1, 1, 1), "scrap": Vector2i(1, 3), "xp": 3,
			}


static func _k(
	id: String, display: String, tier: int, archetype: String,
	hp: float, speed: float, damage: float, scale: float
) -> Dictionary:
	var scrap := Vector2i(1, 3)
	var xp := 3
	if tier == 2:
		scrap = Vector2i(3, 6)
		xp = 8
	elif tier == 3:
		scrap = Vector2i(6, 12)
		xp = 18
	return {
		"id": id,
		"display_name": display,
		"tier": tier,
		"archetype": archetype,
		"hp": hp,
		"speed": speed,
		"damage": damage,
		"scale": scale,
		"sprite": "res://assets/sprites/enemies/%s/%s_idle.png" % [id, id],
		"anim": "res://assets/sprites/enemies/%s/%s" % [id, id],
		"scrap": scrap,
		"xp": xp,
	}
