extends RefCounted

## CHAPTER 2 · 8 — Dead Signal. A military beacon has been repeating the same
## coded burst since the war. Juno thinks it's on a base with a working plane
## engine. Power it up, hear what it says, and wake what's guarding it.

static func def() -> Dictionary:
	return {
		"title": "Dead Signal",
		"subtitle": "A beacon that never stopped talking. Something still answers it.",
		"tier": 8,
		"enemy_hp": 1.15,
		"enemy_damage": 1.0,
		"heroes": [],
		"seed": 3408,
		"bounds": Rect2(-1400, -3400, 2800, 3700),
		"roads": [[Vector2(0, 320), Vector2(60, -900), Vector2(-60, -1800), Vector2(40, -2700), Vector2(0, -3500)]],
		"sets": [
			["base_post", -640, -350], ["sandbag_nest", 640, -400], ["tank_hulk", -660, -1050],
			["base_post", 660, -1100], ["sandbag_nest", -640, -1700], ["tank_hulk", 680, -1800],
			["base_post", -660, -2500], ["tank_hulk", 660, -2550], ["sandbag_nest", -620, -3150], ["base_post", 640, -3150],
		],
		"props": [["world/relay", 0, -1980], ["bunker", -520, -1380], ["bunker", 560, -1460], ["bunker", -60, -2700],
			["guard_post", 300, -2060], ["guard_post", -300, -2060], ["world/plane_wreck", 260, -2950]],
		"fires": [[200, -2900, 1.1]],
		"crates": [[300, -600], [-300, -900], [320, -1300], [-340, -2200], [300, -2400]],
		"clear": [[0, -1900, 260], [-520, -1300, 120], [560, -1380, 120], [-60, -2620, 120]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["juno", "Okay, so the burst repeats every forty seconds, it's encrypted with a military rolling key, and the key is—get this—the DATE."],
				["helm", "Juno. Short version.", "radio"],
				["juno", "Short version: dead base, live beacon, real hangar, and maybe, MAYBE, an engine that fits your plane."],
				["helm", "Then that's where we're going.", "radio"],
				["juno", "The beacon's battery died years ago. It runs on salvaged cells now. Three bunkers, three cells. Bring them to the mast."],
				["vesper", "Machines patrol that base. Old ones. They don't sleep."],
			],
			"message": [
				["beacon", "...STANDING ORDER SEVEN. ALL UNITS. HOLD THE LINE AGAINST THE DUST."],
				["beacon", "THE DUST IS NOT WEATHER. IT IS AN ORGANISM. DO NOT LET IT REACH THE CITIES. REPEAT. HOLD THE LINE."],
				["helm", "...Hold the line against the Dust. Not against people. The machines were never fighting us.", "radio"],
				["quill", "They were fighting IT. We just kept walking into the middle.", "radio"],
				["beacon", "UNIT SEVEN: INTRUDERS AT THE MAST. ENGAGE."],
				["juno", "Oh no. Oh no, that's the big one. That's the BIG one. Unit Seven is a SIEGE ENGINE."],
			],
			"engine": [
				["", "Under the wing of a gutted transport: a radial engine, wrapped in oilcloth. Somebody meant to come back for it."],
				["helm", "Is that... Juno, is that what I think it is?", "radio"],
				["juno", "Nine cylinders of yes. Bring it home. Gently. GENTLY. It's older than both of us put together."],
			],
			"outro": [
				["helm", "It fits. It FITS. Juno, it fits!", "radio"],
				["juno", "Of course it fits, I measured it four times! Five. I measured it five times."],
				["rook", "Machines weren't the enemy. All this time."],
				["quill", "They were the immune system. And they're losing. The Dust has a heart, and we know which way it is now."],
				["helm", "Then the plane flies by the end of the season. And we go see that heart from above.", "radio"],
			],
		},
		"triggers": [
			{"at": Vector2(0, -700), "r": 220, "do": [["radio", "juno", "Hear that? Every forty seconds. BEEP-beep-beep. It's been saying the same thing for nine years."]]},
			{"at": Vector2(200, -2700), "r": 240, "do": [["radio", "juno", "That transport! Under the wing! Helm, that's an ENGINE cowling!"]]},
		],
		"objectives": [
			{"type": "reach", "text": "Find the beacon mast", "hint": "North, past the old checkpoints",
				"at": Vector2(0, -1250), "r": 140,
				"waves": [{"t": 3, "kinds": "machine", "n": 4}, {"t": 13, "kinds": "machine", "n": 4}, {"t": 22, "kinds": "iron_horse", "n": 1}],
				"trickle": {"every": 5.0, "kinds": "machine", "cap": 7}},
			{"type": "carry", "text": "Bring three power cells", "hint": "One cell per bunker. Heavy. The patrols want them back",
				"carry": {"from": [Vector2(-500, -1270), Vector2(540, -1370), Vector2(-60, -2620)], "to": Vector2(0, -1880), "slow": 0.62,
					"icon": "mat_salvage_core", "pickup_toast": "Power cell. Heavy.", "carry_hint": "To the beacon mast. Heavy: you're slower"},
				"trickle": {"every": 3.2, "kinds": "machine", "cap": 11},
				"waves": [{"t": 15, "kinds": ["coil_spider", "scrap_hound"], "n": 5}, {"t": 35, "kinds": "fusion_golem", "n": 1}, {"t": 50, "kinds": "machine", "n": 6}]},
			{"type": "defend", "text": "Hold the mast while it decodes", "hint": "Forty seconds a burst. Keep them off the mast",
				"at": Vector2(0, -1900), "r": 260, "time": 55, "hp": 240, "fail": "The mast went dark. The signal's gone.",
				"waves": [{"t": 0, "kinds": "machine", "n": 6}, {"t": 9, "kinds": ["iron_horse", "scrap_hound"], "n": 4},
					{"t": 18, "kinds": "machine", "n": 6}, {"t": 28, "kinds": ["mech_wyrm", "coil_spider"], "n": 3},
					{"t": 38, "kinds": "machine", "n": 7}, {"t": 46, "kinds": "cyber_juggernaut", "n": 1}],
				"trickle": {"every": 3.0, "kinds": "machine", "cap": 12},
				"on_done": [["clear_enemies"], ["scene", "message"]]},
			{"type": "boss", "text": "Stop Unit Seven", "hint": "Get close: its guns can't track you there. Then get out",
				"boss": {"kind": "dread_naught", "name": "Unit Seven", "epithet": "the Dread Naught, still holding the line", "at": Vector2(0, -2450), "hp": 2.0, "brain": "dread_naught"}},
			{"type": "collect", "text": "Salvage the engine", "hint": "Under the transport's wing", "icon": "mat_salvage_core",
				"items": [Vector2(200, -2840)], "on_done": [["scene", "engine"]]},
			{"type": "extract", "text": "Haul it home", "at": Vector2(0, -1500),
				"waves": [{"t": 4, "kinds": "machine", "n": 5}]},
		],
		"rewards": {"scrap": 320, "part": "engine", "camp": {"radio_tower": 1}},
	}
