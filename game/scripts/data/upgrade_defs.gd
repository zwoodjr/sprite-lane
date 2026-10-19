class_name UpgradeDefs
extends RefCounted

## In-run upgrade cards (Phase 4). Every number lives here; player / enemy /
## FX scripts read them with UpgradeDefs.val(id, key, rank).
##
## Card fields:
##   id, name, rarity (common / uncommon / rare / epic), tags (see TAGS)
##   max_rank        — each pick adds one rank (2–3)
##   ranks           — per-rank values (rank N reads ranks[N-1]; totals, not deltas)
##   desc            — per-rank effect text (ranged heroes)
##   desc_melee      — per-rank text for melee heroes (the melee adaptation)
##   hero            — class-exclusive: only offered to that hero
##   stat / add      — simple stat cards: GameState.run_mods[stat] += add per rank
##   combos          — upgrade ids it works with (shown on the card as a hint)
##   ranged_only     — never offered to melee heroes

const TAGS := ["Bullet", "Melee", "Deployable", "Elemental", "Movement", "Defense", "Economy", "Class"]

const RARITY_WEIGHT := {"common": 50.0, "uncommon": 30.0, "rare": 15.0, "epic": 6.0}
const RARITY_COLOR := {
	"common": Color(0.78, 0.72, 0.62),
	"uncommon": Color(0.42, 0.85, 0.48),
	"rare": Color(0.40, 0.66, 1.0),
	"epic": Color(0.78, 0.48, 1.0),
}
## Class cards show up a bit more often so each hero's build has an identity.
const CLASS_WEIGHT_MULT := 1.6
## A card that continues a path you already own is a little more likely.
const OWNED_WEIGHT_MULT := 1.3
const CHOICES_PER_LEVEL := 3
const REROLLS_PER_RUN := 2

## Special ammo (timed, ~15 s). Sources: rare kill drops, crates, Helm's Supply Drop.
const AMMO_DURATION := 15.0
const AMMO := {
	"incendiary": {"name": "Incendiary", "color": Color(1.0, 0.55, 0.2), "burn_dps": 9.0, "burn_time": 3.0,
		"bullet": "res://assets/sprites/fx/bullet_incendiary.png", "pickup": "res://assets/sprites/pickups/ammo_incendiary.png"},
	"shock": {"name": "Shock", "color": Color(0.45, 0.75, 1.0), "stun_chance": 0.35, "stun_time": 0.7,
		"bullet": "res://assets/sprites/fx/bullet_shock.png", "pickup": "res://assets/sprites/pickups/ammo_shock.png"},
	"explosive": {"name": "Explosive", "color": Color(1.0, 0.4, 0.25), "blast_radius": 58.0, "blast_mult": 0.5,
		"bullet": "res://assets/sprites/fx/bullet_explosive.png", "pickup": "res://assets/sprites/pickups/ammo_explosive.png"},
	"frost": {"name": "Frost", "color": Color(0.6, 0.9, 1.0), "slow_mult": 0.5, "slow_time": 2.5,
		"bullet": "res://assets/sprites/fx/bullet_frost.png", "pickup": "res://assets/sprites/pickups/ammo_frost.png"},
}
## Kill drop chance for a special-ammo pickup by tier (normal / elite / boss).
const AMMO_DROP_CHANCE := [0.012, 0.06, 0.3]
## Crate (breakable) buff rolls that become special ammo instead.
const AMMO_CRATE_SHARE := 0.3

## Supply Drop: the first crate comes early so the pick pays off right away.
const SUPPLY_FIRST_DROP := 8.0
const CRATE_PICK_R := 30.0
const CRATE_LIFE := 30.0
## Spore mine arming time / trigger distance; orbit blade hit cooldown / size.
const MINE_ARM_TIME := 0.45
const MINE_TRIGGER_R := 34.0
const BLADE_HIT_CD := 0.45
const BLADE_HIT_R := 14.0
## Burn It Down can't re-trigger faster than this (lifesteal / puddle ticks).
const BURN_IT_DOWN_CD := 1.5

## Status effects applied to enemies (shared by upgrades, ammo and abilities).
const POISON_TICK := 0.5
const MARK_TINT := Color(1.0, 0.55, 0.85)


static func all() -> Array:
	return [
		## ---------------- Simple stat cards (common) ----------------
		{"id": "harder_hit", "name": "Harder Hit", "rarity": "common", "tags": ["Bullet", "Melee"],
			"max_rank": 3, "stat": "damage", "add": 0.15, "ranks": [{}, {}, {}],
			"desc": ["+15% weapon damage", "+30% weapon damage", "+45% weapon damage"],
			"combos": ["split_shot", "marked"]},
		{"id": "quick_mag", "name": "Quick Hands", "rarity": "common", "tags": ["Bullet", "Melee"],
			"max_rank": 3, "stat": "firerate", "add": 0.15, "ranks": [{}, {}, {}],
			"desc": ["+15% fire rate", "+30% fire rate", "+45% fire rate"],
			"desc_melee": ["+15% swing speed", "+30% swing speed", "+45% swing speed"],
			"combos": ["split_shot", "dust_rounds"]},
		{"id": "thick_plate", "name": "Thick Plate", "rarity": "common", "tags": ["Defense"],
			"max_rank": 3, "stat": "max_hp", "add": 25.0, "ranks": [{}, {}, {}],
			"desc": ["+25 max HP (heals the gain)", "+50 max HP", "+75 max HP"],
			"combos": ["iron_tonic", "unbreakable"]},
		{"id": "dust_runner", "name": "Dust Runner", "rarity": "common", "tags": ["Movement"],
			"max_rank": 2, "stat": "move", "add": 0.10, "ranks": [{}, {}],
			"desc": ["+10% move speed", "+20% move speed"],
			"combos": ["spore_mines", "firewalk"]},
		{"id": "deep_mag", "name": "Deep Mag", "rarity": "common", "tags": ["Bullet"], "ranged_only": true,
			"max_rank": 2, "stat": "mag", "add": 4.0, "ranks": [{}, {}],
			"desc": ["+4 mag size", "+8 mag size"],
			"combos": ["split_shot", "bell_tower"]},
		{"id": "cool_head", "name": "Cool Head", "rarity": "common", "tags": ["Class"],
			"max_rank": 3, "stat": "ability_cd", "add": 0.15, "ranks": [{}, {}, {}],
			"desc": ["−15% ability cooldown", "−30% ability cooldown", "−45% ability cooldown"],
			"combos": ["aftershock", "live_wire", "sanctuary"]},

		## ---------------- Shared pool ----------------
		{"id": "ricochet", "name": "Ricochet Rounds", "rarity": "uncommon", "tags": ["Bullet", "Melee"],
			"max_rank": 3,
			"ranks": [{"bounces": 1, "mult": 0.6, "range": 220.0}, {"bounces": 2, "mult": 0.65, "range": 240.0}, {"bounces": 3, "mult": 0.75, "range": 260.0}],
			"desc": ["Shots bounce to 1 more enemy (60% dmg)", "Bounce to 2 more enemies (65%)", "Bounce to 3 more enemies (75%)"],
			"desc_melee": ["Swings arc to 1 nearby enemy (60% dmg)", "Arc to 2 nearby enemies (65%)", "Arc to 3 nearby enemies (75%)"],
			"combos": ["dust_rounds", "marked", "piercing"]},
		{"id": "split_shot", "name": "Split Shot", "rarity": "uncommon", "tags": ["Bullet", "Melee"],
			"max_rank": 3,
			"ranks": [{"every": 3, "count": 3, "spread_deg": 12.0, "slash_mult": 0.6}, {"every": 2, "count": 3, "spread_deg": 12.0, "slash_mult": 0.7}, {"every": 2, "count": 5, "spread_deg": 10.0, "slash_mult": 0.9}],
			"desc": ["Every 3rd shot fires three", "Every 2nd shot fires three", "Every 2nd shot fires five"],
			"desc_melee": ["Every 3rd swing adds a second slash (60%)", "Every 2nd swing adds a second slash (70%)", "Every 2nd swing: second slash at 90%"],
			"combos": ["piercing", "ricochet", "quick_mag"]},
		{"id": "dust_rounds", "name": "Dust Rounds", "rarity": "uncommon", "tags": ["Bullet", "Melee", "Elemental"],
			"max_rank": 3,
			"ranks": [{"dps": 4.0, "time": 3.0}, {"dps": 7.0, "time": 3.5}, {"dps": 11.0, "time": 4.0}],
			"desc": ["Hits poison: 4 dmg/s for 3s", "Poison: 7 dmg/s for 3.5s", "Poison: 11 dmg/s for 4s"],
			"combos": ["ricochet", "orbit_blades", "spore_mines"]},
		{"id": "piercing", "name": "Piercing Slugs", "rarity": "uncommon", "tags": ["Bullet", "Melee"],
			"max_rank": 3,
			"ranks": [{"pierce": 1, "falloff": 0.8, "reach": 0.25}, {"pierce": 2, "falloff": 0.85, "reach": 0.4}, {"pierce": 3, "falloff": 0.9, "reach": 0.55}],
			"desc": ["Shots pass through 1 enemy", "Pass through 2 enemies", "Pass through 3 enemies, less falloff"],
			"desc_melee": ["+25% swing arc & reach", "+40% swing arc & reach", "+55% swing arc & reach"],
			"combos": ["split_shot", "ricochet"]},
		{"id": "scrap_drone", "name": "Scrap Drone", "rarity": "rare", "tags": ["Deployable"],
			"max_rank": 2,
			"ranks": [{"drones": 1}, {"drones": 2}],
			"drone": {"drone_range": 360.0, "drone_interval": 1.0, "drone_damage": 7.0},
			"desc": ["A drone flies with you and shoots", "A second drone joins"],
			"desc_helm": ["+1 of your drones (max 4)", "+1 more drone (max 4)"],
			"combos": ["wingman", "dust_rounds", "squadron"]},
		{"id": "spore_mines", "name": "Spore Mines", "rarity": "uncommon", "tags": ["Deployable", "Elemental"],
			"max_rank": 3,
			"ranks": [{"every_px": 150.0, "damage": 22.0, "radius": 70.0, "max_alive": 5, "life": 14.0},
				{"every_px": 120.0, "damage": 30.0, "radius": 78.0, "max_alive": 7, "life": 14.0},
				{"every_px": 95.0, "damage": 40.0, "radius": 86.0, "max_alive": 9, "life": 14.0}],
			"desc": ["Drop a spore mine every few steps (22 dmg)", "Mines drop more often, 30 dmg", "Even more mines, 40 dmg, bigger burst"],
			"combos": ["dust_rounds", "dust_runner"]},
		{"id": "orbit_blades", "name": "Orbiting Blades", "rarity": "rare", "tags": ["Deployable", "Melee"],
			"max_rank": 3,
			"ranks": [{"count": 2, "damage": 9.0, "radius": 62.0, "spin": 3.4}, {"count": 3, "damage": 12.0, "radius": 68.0, "spin": 3.8}, {"count": 4, "damage": 15.0, "radius": 74.0, "spin": 4.2}],
			"desc": ["2 scrap blades circle you", "3 blades, harder hits", "4 blades, wider orbit"],
			"combos": ["dust_rounds", "rubble_wall"]},
		{"id": "firewalk", "name": "Firewalk", "rarity": "uncommon", "tags": ["Movement", "Elemental"],
			"max_rank": 3,
			"ranks": [{"dps": 14.0, "time": 2.5, "radius": 30.0}, {"dps": 20.0, "time": 3.0, "radius": 34.0}, {"dps": 28.0, "time": 3.5, "radius": 38.0}],
			"desc": ["Dashing leaves a fire trail (14 dmg/s)", "Fire trail 20 dmg/s, lasts longer", "Fire trail 28 dmg/s, wider"],
			"combos": ["second_wind", "back_way_out"]},
		{"id": "second_wind", "name": "Second Wind", "rarity": "common", "tags": ["Movement", "Defense"],
			"max_rank": 3,
			"ranks": [{"heal": 4.0}, {"heal": 7.0}, {"heal": 10.0}],
			"desc": ["Dashing heals 4 HP", "Dashing heals 7 HP", "Dashing heals 10 HP"],
			"combos": ["firewalk", "burn_it_down"]},
		{"id": "iron_tonic", "name": "Iron Tonic", "rarity": "rare", "tags": ["Defense"],
			"max_rank": 3,
			"ranks": [{"recharge": 14.0}, {"recharge": 10.0}, {"recharge": 7.0}],
			"desc": ["A shield blocks one hit, recharges in 14s", "Shield recharges in 10s", "Shield recharges in 7s"],
			"combos": ["thick_plate", "unbreakable"]},
		{"id": "scavengers_eye", "name": "Scavenger's Eye", "rarity": "common", "tags": ["Economy"],
			"max_rank": 3,
			"ranks": [{"scrap": 0.25}, {"scrap": 0.5}, {"scrap": 0.8}],
			"desc": ["+25% scrap from kills", "+50% scrap from kills", "+80% scrap from kills"],
			"combos": ["lucky_vial"]},
		{"id": "lucky_vial", "name": "Lucky Vial", "rarity": "uncommon", "tags": ["Economy"],
			"max_rank": 2,
			"ranks": [{"charges": 2, "luck": 2.5}, {"charges": 3, "luck": 3.5}],
			"desc": ["Next 2 level-ups: better odds on rare cards", "Next 3 level-ups: much better odds"],
			"combos": ["scavengers_eye"]},

		## ---------------- Class-exclusive ----------------
		## Ash Rook
		{"id": "aftershock", "name": "Aftershock", "rarity": "rare", "tags": ["Class", "Elemental"], "hero": CharacterDefs.ASH_ROOK_ID,
			"max_rank": 3,
			"ranks": [{"damage": 45.0, "radius": 120.0}, {"damage": 70.0, "radius": 140.0}, {"damage": 100.0, "radius": 165.0}],
			"desc": ["RUSH ends in an explosion (45 dmg)", "Bigger blast (70 dmg)", "Huge blast (100 dmg)"],
			"combos": ["cool_head", "rubble_wall"]},
		{"id": "rubble_wall", "name": "Rubble Wall", "rarity": "uncommon", "tags": ["Class"], "hero": CharacterDefs.ASH_ROOK_ID,
			"max_rank": 3,
			"ranks": [{"damage": 14.0, "radius": 46.0}, {"damage": 22.0, "radius": 52.0}, {"damage": 32.0, "radius": 58.0}],
			"desc": ["Knocked-back enemies smash into others (14 dmg)", "Smash for 22 dmg", "Smash for 32 dmg, wider"],
			"combos": ["aftershock", "orbit_blades"]},
		## Vesper Thorn
		{"id": "bell_tower", "name": "Bell Tower", "rarity": "rare", "tags": ["Class", "Bullet"], "hero": CharacterDefs.VESPER_THORN_ID,
			"max_rank": 3,
			"ranks": [{"per_sec": 0.35, "cap": 0.7}, {"per_sec": 0.5, "cap": 1.0}, {"per_sec": 0.7, "cap": 1.4}],
			"desc": ["Standing still charges shots (up to +70%)", "Charge faster, up to +100%", "Charge up to +140%"],
			"combos": ["marked", "deep_mag"]},
		{"id": "marked", "name": "Marked", "rarity": "rare", "tags": ["Class"], "hero": CharacterDefs.VESPER_THORN_ID,
			"max_rank": 3,
			"ranks": [{"mult": 1.15, "time": 3.0}, {"mult": 1.25, "time": 3.5}, {"mult": 1.35, "time": 4.0}],
			"desc": ["Your hits mark: +15% damage from all sources", "Marked take +25%", "Marked take +35%, lasts 4s"],
			"combos": ["bell_tower", "ricochet", "scrap_drone"]},
		## Pebble
		{"id": "unbreakable", "name": "Unbreakable", "rarity": "uncommon", "tags": ["Class", "Defense"], "hero": CharacterDefs.PEBBLE_ID,
			"max_rank": 3,
			"ranks": [{"reduce": 0.2}, {"reduce": 0.3}, {"reduce": 0.4}],
			"desc": ["Below half HP: take 20% less damage", "Below half HP: 30% less", "Below half HP: 40% less"],
			"combos": ["thick_plate", "iron_tonic"]},
		{"id": "quarry_slam", "name": "Quarry Slam", "rarity": "rare", "tags": ["Class", "Melee"], "hero": CharacterDefs.PEBBLE_ID,
			"max_rank": 3,
			"ranks": [{"every": 4, "radius": 110.0, "stun": 0.8, "mult": 0.5}, {"every": 4, "radius": 125.0, "stun": 1.1, "mult": 0.7}, {"every": 3, "radius": 140.0, "stun": 1.4, "mult": 0.9}],
			"desc": ["Every 4th swing slams: stuns nearby", "Wider slam, 1.1s stun", "Every 3rd swing, 1.4s stun"],
			"combos": ["split_shot", "orbit_blades"]},
		## Bolt Juno
		{"id": "live_wire", "name": "Live Wire", "rarity": "rare", "tags": ["Class", "Elemental"], "hero": CharacterDefs.BOLT_JUNO_ID,
			"max_rank": 3,
			"ranks": [{"extra": 2}, {"extra": 4}, {"extra": 6}],
			"desc": ["OVERLOAD chains to 2 more enemies", "Chains to 4 more", "Chains to 6 more"],
			"combos": ["short_circuit", "cool_head"]},
		{"id": "short_circuit", "name": "Short Circuit", "rarity": "uncommon", "tags": ["Class", "Elemental"], "hero": CharacterDefs.BOLT_JUNO_ID,
			"max_rank": 3,
			"ranks": [{"machine": 2.0, "other": 1.0}, {"machine": 2.0, "other": 1.3}, {"machine": 2.5, "other": 1.5}],
			"desc": ["Stunned machines take double damage", "…and other stunned foes +30%", "Machines ×2.5, others +50%"],
			"combos": ["live_wire"]},
		## Sister Cinder
		{"id": "sanctuary", "name": "Sanctuary", "rarity": "rare", "tags": ["Class", "Deployable"], "hero": CharacterDefs.CINDER_ID,
			"max_rank": 3,
			"ranks": [{"hps": 6.0, "time": 4.0, "radius": 72.0}, {"hps": 9.0, "time": 5.0, "radius": 80.0}, {"hps": 13.0, "time": 6.0, "radius": 90.0}],
			"desc": ["HEAL leaves a healing puddle (6 HP/s)", "Puddle 9 HP/s, lasts 5s", "Puddle 13 HP/s, lasts 6s"],
			"combos": ["burn_it_down", "cool_head"]},
		{"id": "burn_it_down", "name": "Burn It Down", "rarity": "rare", "tags": ["Class", "Elemental"], "hero": CharacterDefs.CINDER_ID,
			"max_rank": 3,
			"ranks": [{"radius": 120.0, "dps": 10.0, "time": 3.0, "below": 0.7}, {"radius": 145.0, "dps": 15.0, "time": 3.0, "below": 0.75}, {"radius": 170.0, "dps": 22.0, "time": 3.5, "below": 0.8}],
			"desc": ["Healing while hurt ignites nearby foes", "Bigger ring, hotter burn", "Huge ring, 22 dmg/s burn"],
			"combos": ["sanctuary", "second_wind"]},
		## Quill Marrow
		{"id": "field_notes", "name": "Field Notes", "rarity": "uncommon", "tags": ["Class"], "hero": CharacterDefs.QUILL_MARROW_ID,
			"max_rank": 3,
			"ranks": [{"per_kill": 0.02, "cap": 0.3}, {"per_kill": 0.03, "cap": 0.45}, {"per_kill": 0.04, "cap": 0.6}],
			"desc": ["Each kill of a type: +2% dmg vs it (max 30%)", "+3% per kill (max 45%)", "+4% per kill (max 60%)"],
			"combos": ["bayonet"]},
		{"id": "bayonet", "name": "Bayonet", "rarity": "rare", "tags": ["Class", "Melee", "Defense"], "hero": CharacterDefs.QUILL_MARROW_ID,
			"max_rank": 3,
			"ranks": [{"radius": 44.0, "every": 0.6, "mult": 0.6}, {"radius": 48.0, "every": 0.45, "mult": 0.7}, {"radius": 54.0, "every": 0.32, "mult": 0.8}],
			"desc": ["Enemies too close get stabbed automatically", "Stab faster", "Stab very fast, harder"],
			"combos": ["field_notes", "dust_rounds"]},
		## Nyx Caldera
		{"id": "back_way_out", "name": "Back Way Out", "rarity": "rare", "tags": ["Class", "Movement"], "hero": CharacterDefs.NYX_CALDERA_ID,
			"max_rank": 3,
			"ranks": [{"time": 1.0}, {"time": 1.5}, {"time": 2.0}],
			"desc": ["Dashing makes you invisible for 1s", "Invisible 1.5s", "Invisible 2s"],
			"combos": ["double_cross", "firewalk"]},
		{"id": "double_cross", "name": "Double Cross", "rarity": "rare", "tags": ["Class", "Melee"], "hero": CharacterDefs.NYX_CALDERA_ID,
			"max_rank": 3,
			"ranks": [{"mult": 3.0, "cone_deg": 90.0}, {"mult": 3.0, "cone_deg": 140.0}, {"mult": 3.5, "cone_deg": 160.0}],
			"desc": ["Hits from behind deal triple damage", "Wider 'behind' angle", "Behind hits ×3.5"],
			"combos": ["back_way_out"]},
		## Helm Wisp
		{"id": "wingman", "name": "Wingman", "rarity": "uncommon", "tags": ["Class", "Deployable"], "hero": CharacterDefs.HELM_WISP_ID,
			"max_rank": 3,
			"ranks": [{"firerate": 0.3}, {"firerate": 0.6}, {"firerate": 0.9}],
			"desc": ["All drones fire 30% faster", "Drones fire 60% faster", "Drones fire 90% faster"],
			"combos": ["squadron", "scrap_drone"]},
		{"id": "supply_drop", "name": "Supply Drop", "rarity": "rare", "tags": ["Class", "Economy"], "hero": CharacterDefs.HELM_WISP_ID,
			"max_rank": 3,
			"ranks": [{"every": 40.0}, {"every": 30.0}, {"every": 22.0}],
			"desc": ["A crate of special ammo drops every 40s", "Every 30s", "Every 22s"],
			"combos": ["wingman"]},
		{"id": "squadron", "name": "Squadron", "rarity": "epic", "tags": ["Class", "Deployable"], "hero": CharacterDefs.HELM_WISP_ID,
			"max_rank": 2,
			"ranks": [{"drones": 1}, {"drones": 2}],
			"desc": ["+1 drone (max 4 total)", "+1 more drone (max 4 total)"],
			"combos": ["wingman", "scrap_drone"]},
	]


static var _by_id: Dictionary = {}


static func get_def(id: String) -> Dictionary:
	if _by_id.is_empty():
		for u in all():
			_by_id[str(u["id"])] = u
	return _by_id.get(id, {})


## Value for an upgrade at a rank (rank 0 → default).
static func val(id: String, key: String, rank: int, default: Variant = 0.0) -> Variant:
	if rank <= 0:
		return default
	var d := get_def(id)
	var ranks: Array = d.get("ranks", [])
	if ranks.is_empty():
		return default
	return (ranks[clampi(rank, 1, ranks.size()) - 1] as Dictionary).get(key, default)


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLOR.get(rarity, RARITY_COLOR["common"])


## Per-rank text for this hero (melee / Helm adaptations).
static func rank_text(u: Dictionary, rank: int, melee: bool, hero: String) -> String:
	var key := "desc"
	if hero == CharacterDefs.HELM_WISP_ID and u.has("desc_helm"):
		key = "desc_helm"
	elif melee and u.has("desc_melee"):
		key = "desc_melee"
	var arr: Array = u.get(key, u.get("desc", []))
	if arr.is_empty():
		return ""
	return str(arr[clampi(rank, 1, arr.size()) - 1])
