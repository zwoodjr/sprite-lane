class_name EventDefs
extends RefCounted

## In-run events + extract-side bonuses (Master Brief Part 8).

enum Kind { RADIO, WORLD_PULSE, EXTRACT_SIDE }


static func catalog() -> Array[Dictionary]:
	return [
		{
			"id": "radio_scrap_spike",
			"kind": Kind.RADIO,
			"name": "Scrap Spike",
			"toast": "Helm on radio: scrap pile humming near a landmark — double scrap zone!",
			"weight": 1.0,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "scrap_spike"},
		},
		{
			"id": "radio_pad_tip",
			"kind": Kind.RADIO,
			"name": "Pad Heat",
			"toast": "Pads running hot — next window opens early. Expect company.",
			"weight": 1.0,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": ""},
		},
		{
			"id": "pulse_herb_bloom",
			"kind": Kind.WORLD_PULSE,
			"name": "Herb Bloom",
			"toast": "Herb bloom — healing herbs sprouting across the dust.",
			"weight": 0.8,
			"duration_sec": 90.0,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "heal"},
		},
		{
			"id": "supply_crash",
			"kind": Kind.WORLD_PULSE,
			"name": "Supply Crash",
			"toast": "Crate down! Epic-or-better inside — a pack is hunting you for it.",
			"weight": 0.7,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "supply"},
		},
		{
			"id": "dust_surge",
			"kind": Kind.WORLD_PULSE,
			"name": "Dust Surge",
			"toast": "Dust Surge — visibility drops, enemies hit harder. Survive for a bonus.",
			"weight": 0.6,
			"duration_sec": 20.0,
			"payout": {"bag_scrap": 15, "extract_scrap": 0, "temp_buff": ""},
		},
		{
			"id": "elite_hunt",
			"kind": Kind.RADIO,
			"name": "Elite Hunt",
			"toast": "Elite marked on the map — kill it for the reward.",
			"weight": 0.7,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": ""},
		},
		{
			"id": "extract_ambush_bounty",
			"kind": Kind.EXTRACT_SIDE,
			"name": "Ambush Bounty",
			"toast": "Extract while enemies are on the pad for bonus scrap.",
			"weight": 0.8,
			"payout": {"bag_scrap": 0, "extract_scrap": 25, "temp_buff": ""},
		},
		{
			"id": "extract_pet_bond",
			"kind": Kind.EXTRACT_SIDE,
			"name": "Pet Bond",
			"toast": "Extract with your pet close by for kennel XP.",
			"weight": 0.5,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "kennel_xp"},
		},
	]


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


static func in_run_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in catalog():
		var k := int(e.get("kind", -1))
		if k == Kind.RADIO or k == Kind.WORLD_PULSE:
			out.append(e)
	return out


static func debug_radio_ping(rng: RandomNumberGenerator = null) -> Dictionary:
	var radios := radio_events()
	if radios.is_empty():
		return {}
	if rng == null:
		return radios[randi() % radios.size()].duplicate(true)
	return radios[rng.randi() % radios.size()].duplicate(true)


static func roll_in_run_event(rng: RandomNumberGenerator = null) -> Dictionary:
	var pool := in_run_events()
	if pool.is_empty():
		return {}
	## Weight-aware pick.
	var total := 0.0
	for e in pool:
		total += float(e.get("weight", 1.0))
	var r := (rng.randf() if rng else randf()) * total
	var acc := 0.0
	for e in pool:
		acc += float(e.get("weight", 1.0))
		if r <= acc:
			return e.duplicate(true)
	return pool.back().duplicate(true)
