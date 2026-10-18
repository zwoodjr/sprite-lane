class_name EventDefs
extends RefCounted

## Lightweight event / quest stubs for solo extraction (see store docs/events-and-quests.md).
## No quest log — toast/banner only when match code opts in.
## Full landmark contracts and zone spawns come later; Hangar meta is the spend surface.

enum Kind { RADIO, WORLD_PULSE, EXTRACT_SIDE }


static func catalog() -> Array[Dictionary]:
	return [
		{
			"id": "radio_scrap_spike",
			"kind": Kind.RADIO,
			"name": "Scrap Spike",
			"toast": "Radio: scrap pile humming near a landmark…",
			"weight": 1.0,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "", "blueprint": false},
			"notes": "MVP stub — toast only until zone markers ship",
		},
		{
			"id": "radio_pad_tip",
			"kind": Kind.RADIO,
			"name": "Pad Heat",
			"toast": "Radio: extract pad running hot — stay sharp when it opens",
			"weight": 1.0,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "", "blueprint": false},
			"notes": "Info-only ping",
		},
		{
			"id": "pulse_herb_bloom",
			"kind": Kind.WORLD_PULSE,
			"name": "Herb Bloom",
			"toast": "Herb Cache bloom — heal drops lean richer for a bit",
			"weight": 0.6,
			"duration_sec": 90.0,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "heal", "blueprint": false},
			"notes": "Deferred: breakable heal-weight bump near Herb Cache",
		},
		{
			"id": "extract_ambush_bounty",
			"kind": Kind.EXTRACT_SIDE,
			"name": "Ambush Bounty",
			"toast": "Clear the pad ambush this window for extract bonus scrap",
			"weight": 0.8,
			"payout": {"bag_scrap": 0, "extract_scrap": 25, "temp_buff": "", "blueprint": false},
			"notes": "Deferred: count ambush kills while extract_open",
		},
		{
			"id": "extract_pet_bond",
			"kind": Kind.EXTRACT_SIDE,
			"name": "Pet Bond",
			"toast": "Extract with your pet alive for a blueprint crumb",
			"weight": 0.5,
			"payout": {"bag_scrap": 0, "extract_scrap": 0, "temp_buff": "", "blueprint": true},
			"notes": "Deferred: award on extract if pet group non-empty",
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


## Cheap debug / smoke stub — pick a radio ping for a match toast.
static func debug_radio_ping(rng: RandomNumberGenerator = null) -> Dictionary:
	var radios := radio_events()
	if radios.is_empty():
		return {}
	if rng == null:
		return radios[randi() % radios.size()].duplicate(true)
	return radios[rng.randi() % radios.size()].duplicate(true)
