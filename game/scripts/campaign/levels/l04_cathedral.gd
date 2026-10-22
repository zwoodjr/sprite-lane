extends RefCounted

## CHAPTER 1 · 4 — Cathedral of Ash. Sister Cinder walks back into the field
## hospital she burned to keep raiders off her patients' medicine. The cache
## is still in the crypt. The marsh gators nest in the nave now, and their
## mother is waiting.

static func def() -> Dictionary:
	return {
		"title": "Cathedral of Ash",
		"subtitle": "She burned it down to save the medicine. Now she has to carry it out.",
		"tier": 9,
		"enemy_hp": 0.95,
		"enemy_damage": 0.85,
		"hero": "sister_cinder",
		"seed": 2504,
		"bounds": Rect2(-1250, -3300, 2500, 3600),
		"roads": [[Vector2(-100, 320), Vector2(40, -700), Vector2(-60, -1350)]],
		"sets": [
			["slab_field", -560, -300], ["rubble_heap", 600, -200], ["ruin_house", -600, -900],
			["slab_field", 600, -950], ["crater_field", -640, -1500], ["rubble_heap", 640, -1650],
			["ruin_house", -700, -2900], ["slab_field", 700, -2950],
		],
		"props": [
			["ruin_pillar", -260, -1950], ["ruin_pillar", 260, -1950], ["ruin_pillar", -260, -2250], ["ruin_pillar", 260, -2250],
			["ruin_pillar", -260, -2550], ["ruin_pillar", 260, -2550], ["wall_ruin", -420, -2780], ["wall_ruin_b", 0, -2860],
			["wall_ruin", 420, -2780], ["wall_collapsed", -470, -2100], ["wall_collapsed", 480, -2400],
			["veh_pickup_0", 140, -1380], ["world/field_tent", -320, -1250],
		],
		"fires": [[-180, -2050, 0.9], [200, -2350, 0.8], [-150, -2650, 0.7], [320, -1980, 0.6], [-60, -1290, 0.7]],
		"crates": [[300, -500], [-300, -700], [320, -1100], [-380, -1750]],
		"clear": [[0, -2300, 260]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["cinder", "I swore I'd never walk this road again."],
				["helm", "Sister, you don't have to. We can find medicine somewhere else.", "radio"],
				["cinder", "There is no somewhere else, child. I hid the last of it in the crypt the night the raiders came."],
				["cinder", "Forty patients. I gave every one of them a dose and a candle, and I gave the raiders fire."],
				["cinder", "Some of those doses are still down there. They're owed to someone. I'll see they get there."],
				["helm", "Then I'm on the radio the whole way. And the dogs say hi.", "radio"],
			],
			"nave": [
				["cinder", "The nave. The pews were beds. I can still smell the smoke."],
				["cinder", "...And gators. Of course. The marsh came in when the roof went."],
			],
			"crypt": [
				["cinder", "The crypt stairs. Still sealed. Good. Still mine."],
				["cinder", "Three crates. They're heavy and I'm old. Keep the beasts off me, Lord, and I'll keep moving."],
			],
			"mother": [
				["", "The floor of the nave heaves. Something vast rises out of the black water under the altar."],
				["cinder", "So you're the one who's been feeding on my dead."],
				["helm", "Sister, that thing is the size of my PLANE. Those sacs on its back are moving.", "radio"],
				["cinder", "A mother guarding her brood. I understand her. I'm going to kill her anyway."],
			],
			"after": [
				["cinder", "Rest now. Whatever you were before the plague, rest."],
				["cinder", "Helm. These doses. There's a quarantine camp down the south road. They had nothing when I last passed."],
				{"speaker": "cinder", "prompt": "Half for them? Or every dose comes home to our own?", "choice": [
					{"text": "Leave half for the camp", "flag": "shared_medicine", "value": true, "then": [
						["cinder", "Then half it is. Mercy isn't a thing you can store in a crate. You have to spend it."],
					]},
					{"text": "Bring it all home", "flag": "shared_medicine", "value": false, "then": [
						["cinder", "...Our own first. I don't love it. I'll pray on it tonight."],
					]},
				]},
			],
			"outro": [
				["cinder", "Put the kettle on, Helm. A real kettle, mind."],
				["helm", "We don't have a real kettle. We have a helmet with a hole patched.", "radio"],
				["cinder", "Then that. I'll set up a table by the door. Herbs, Dust shards, gland-water. I can brew."],
				["quill", "...Interesting woman.", "radio"],
				["helm", "Who said that? Who's on my channel? Is everybody on my channel?!", "radio"],
				["", "Static. Then nothing."],
			],
		},
		"objectives": [
			{"type": "reach", "text": "Walk back to the cathedral", "at": Vector2(0, -1350), "r": 130,
				"waves": [{"t": 3, "kinds": ["rad_gator", "toxic_scorp"], "n": 5}, {"t": 14, "kinds": "glow_moth", "n": 3}],
				"trickle": {"every": 5.0, "kinds": "plague", "cap": 7}},
			{"type": "clear", "text": "Clear the nave", "hint": "Gators in the pews. Burn them out",
				"on_start": [["scene", "nave"]],
				"waves": [{"t": 0, "kinds": "rad_gator", "n": 5, "at": Vector2(0, -2100), "r": 200},
					{"t": 7, "kinds": ["toxic_scorp", "glow_moth"], "n": 5, "at": Vector2(0, -2300), "r": 220},
					{"t": 15, "kinds": ["rad_gator", "chimera_rat"], "n": 6}, {"t": 22, "kinds": "scav_bear", "n": 1, "at": Vector2(0, -2500), "r": 60},
					{"t": 30, "kinds": ["toxic_scorp", "rad_gator"], "n": 6}]},
			{"type": "hold", "text": "Light the candles", "hint": "Forty candles for forty patients. Hold the altar",
				"at": Vector2(0, -2450), "r": 170, "time": 30,
				"on_start": [["radio", "cinder", "One for each of them. Watch my back while I light them."]],
				"waves": [{"t": 0, "kinds": "glow_moth", "n": 4}, {"t": 8, "kinds": ["rad_gator", "toxic_scorp"], "n": 5},
					{"t": 16, "kinds": "chimera_rat", "n": 5}, {"t": 23, "kinds": "glow_moth_queen", "n": 1}],
				"on_done": [["radio", "cinder", "There. Now they can see their way home."]]},
			{"type": "carry", "text": "Carry the medicine out", "hint": "Crypt to the truck, one crate at a time",
				"on_start": [["scene", "crypt"]],
				"carry": {"from": [Vector2(-160, -2620), Vector2(0, -2700), Vector2(160, -2620)], "to": Vector2(100, -1450), "slow": 0.6,
					"icon": "ing_medicine", "pickup_toast": "Medicine crate. Heavy.", "carry_hint": "To the truck. Heavy: you're slower. The plague can smell it"},
				"trickle": {"every": 3.2, "kinds": "plague", "cap": 10},
				"waves": [{"t": 20, "kinds": "rad_gator", "n": 4}, {"t": 45, "kinds": ["toxic_scorp", "rad_gator"], "n": 5}]},
			{"type": "boss", "text": "Kill the Matriarch", "hint": "Dodge the spit. Watch the ground for bile",
				"on_start": [["clear_enemies"], ["scene", "mother"]],
				"boss": {"kind": "rad_gator_matriarch", "name": "Rad Gator Matriarch", "epithet": "mother of the marsh", "at": Vector2(0, -2300), "hp": 2.4, "brain": "matriarch"},
				"on_done": [["scene", "after"]]},
			{"type": "extract", "text": "Drive the medicine home", "at": Vector2(60, -1500)},
		],
		"rewards": {"scrap": 260, "survivors": ["sister_cinder"], "flags": {"brewing": true}},
	}
