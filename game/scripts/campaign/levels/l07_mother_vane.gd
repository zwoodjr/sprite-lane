extends RefCounted

## CHAPTER 2 · 7 — Mother Vane. In the night a raider captain burned the
## hangar's west wall and took Bentley and Lillie as a ransom for the camp's
## medicine. Noel tracks them. Whoever goes, goes angry.

static func def() -> Dictionary:
	return {
		"title": "Mother Vane",
		"subtitle": "They burned the wall. They took the dogs. Go get them back.",
		"tier": 6,
		"enemy_hp": 1.35,
		"enemy_damage": 1.5,
		"heroes": [],
		"pet": "noel",
		"seed": 3307,
		"bounds": Rect2(-1300, -3400, 2600, 3700),
		"roads": [[Vector2(-300, 320), Vector2(-100, -700), Vector2(150, -1500), Vector2(0, -2400)]],
		"sets": [
			["barricade", -620, -300], ["junk_heap", 620, -350], ["totem_post", -640, -950],
			["raider_camp", 640, -1050], ["raider_camp", -640, -1650], ["drum_dump", 620, -1750],
			["totem_post", -640, -2300], ["raider_camp", 660, -2450], ["barricade", -620, -3050], ["totem_post", 640, -3100],
		],
		"props": [["spike_barricade", -260, -1980], ["spike_barricade", 260, -1980], ["raider_totem", -120, -2700],
			["raider_totem", 140, -2720], ["veh_school_bus_1", -420, -2580], ["veh_moto_1", 380, -2550],
			["crate_stack", -420, -1250], ["crate_stack", 420, -2150]],
		"fires": [[0, -2560, 1.3], [-300, -2100, 0.8], [320, -2300, 0.8], [-200, -1200, 0.7]],
		"crates": [[280, -500], [-300, -800], [300, -1350], [-320, -1900]],
		"clear": [[0, -2560, 280], [-300, -1250, 120], [320, -2150, 120]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["", "The west wall is still smoking. Pebble is holding the door shut with her back."],
				["helm", "They came at three. Fire bottles over the wall. Six of them, maybe eight.", "radio"],
				["vane", "Hangar folk! You've got medicine and I've got two very loud dogs. Bring the medicine to the Pit and you get them back. Mostly.", "radio"],
				["helm", "That's Mother Vane. She runs the biggest crew this side of the Dust.", "radio"],
				{"if": ["nyx_sold_road", true], "then": [["nyx", "...She came in by the back road. My road. This is on me."]],
					"else": [["nyx", "Nobody knew the way in. Somebody sold her a map. When I find out who..."]]},
				["noel", "*a growl so low you feel it in your boots. She's already got the scent.*"],
				["{hero}", "Nobody's paying her. We're going to get them."],
				["helm", "Noel knows the way. Bring them home. Bring YOU home.", "radio"],
			],
			"bentley": [
				["bentley", "*yips! yips! hyena-cackles at the raiders like he won*"],
				["helm", "BENTLEY! Oh thank god. Get him out of there!", "radio"],
			],
			"lillie": [
				["lillie", "*hits the cage door with her head once. The cage door gives up.*"],
				["noel", "*licks Lillie's face, then immediately goes back to growling at everything*"],
			],
			"vane_meet": [
				["vane", "You came yourself. Brave. Stupid. Same thing out here."],
				["vane", "You know what medicine's worth now? My crew's coughing blood. Yours eats soup and paints signs."],
				["vane", "Fine. We do it the old way."],
			],
			"vane_down": [
				["vane", "...Go on, then. Finish it. I would."],
				["vane", "Just know my crew's still sick. Somebody else will come for your medicine. Somebody worse."],
				{"speaker": "vane", "prompt": "Mother Vane is down. What now?", "choice": [
					{"text": "Let her go", "flag": "vane_spared", "value": true, "then": [
						["{hero}", "Get up. Take your crew and go. Don't come near our wall again."],
						["vane", "...You'd let me walk. Huh. I'll remember that. Not sure yet if that's a threat."],
						{"if": ["shared_medicine", true], "then": [["cinder", "Vane. There's a quarantine camp on the south road. They have medicine because we shared it. Ask them.", "radio"],
							["vane", "...A nun on the radio. Of course there is."]]},
					]},
					{"text": "Leave her to the Dust", "flag": "vane_spared", "value": false, "then": [
						["{hero}", "You burned our home. The Dust can have you."],
						["vane", "Ha. It already does. It always did."],
					]},
				]},
			],
			"outro": [
				["", "Bentley and Lillie hit the hangar door at full speed. Pebble goes down under both of them and doesn't mind."],
				["pebble", "Hello. Hello! You're filthy. You're perfect."],
				["helm", "We'll rebuild the wall. Thicker. With a door that locks.", "radio"],
				["rook", "With a door that bites. I'll put spikes on it."],
				{"if": ["vane_spared", true], "then": [["vesper", "You let her live. She'll be back."], ["{hero}", "Maybe. Maybe not as an enemy."]],
					"else": [["vesper", "That's one less crew. Still plenty out there."]]},
			],
		},
		"objectives": [
			{"type": "reach", "text": "Follow Noel to the Pit", "hint": "Tire tracks lead north. Raiders on the road",
				"at": Vector2(-60, -1150), "r": 140,
				"waves": [{"t": 2, "kinds": "raider", "n": 4}, {"t": 12, "kinds": "raider", "n": 4}, {"t": 20, "kinds": "raider_brute", "n": 1}],
				"trickle": {"every": 5.0, "kinds": "t1", "cap": 7}},
			{"type": "clear", "text": "Break the outer camp", "hint": "Brutes first. Grunts scatter without them",
				"waves": [{"t": 0, "kinds": "raider", "n": 6, "at": Vector2(0, -1500), "r": 260},
					{"t": 10, "kinds": ["raider_brute", "raider_grunt"], "n": 4}, {"t": 20, "kinds": "raider", "n": 6},
					{"t": 28, "kinds": "raider_brute", "n": 2}]},
			{"type": "hold", "text": "Free Bentley", "hint": "Break the cage. Hold still",
				"at": Vector2(-300, -1250), "r": 110, "time": 10,
				"waves": [{"t": 0, "kinds": "raider", "n": 4}],
				"on_done": [["npc", {"id": "bentley", "pet": "bentley", "at": Vector2(-300, -1280), "mode": "follow", "speed": 220}], ["scene", "bentley"]]},
			{"type": "hold", "text": "Free Lillie", "hint": "Second cage, past the fires",
				"at": Vector2(320, -2150), "r": 110, "time": 10,
				"waves": [{"t": 0, "kinds": "raider", "n": 5}, {"t": 6, "kinds": "raider_brute", "n": 1}],
				"on_done": [["npc", {"id": "lillie", "pet": "lillie", "at": Vector2(320, -2180), "mode": "follow", "speed": 220}], ["scene", "lillie"]]},
			{"type": "boss", "text": "Beat Mother Vane", "hint": "Don't stand in her fire. Her crew comes when she shouts",
				"on_start": [["scene", "vane_meet"]],
				"boss": {"kind": "raider_captain", "name": "Mother Vane", "epithet": "captain of the Pit", "at": Vector2(0, -2620), "hp": 1.3, "brain": "vane", "pref": 80},
				"on_done": [["clear_enemies"], ["scene", "vane_down"]]},
			{"type": "extract", "text": "Bring the dogs home", "at": Vector2(-100, -900)},
		],
		"rewards": {"scrap": 300},
	}
