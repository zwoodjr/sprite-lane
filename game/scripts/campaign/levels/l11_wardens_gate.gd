extends RefCounted

## CHAPTER 3 · 11 — The Warden's Gate. The last wall before Dustfall, and the
## thing that guards it: the Dust Warden, a war machine the plague made holy.
## Mother Vane is here too. Whether she stands with you or against you
## depends on what you did at the Pit.

static func def() -> Dictionary:
	return {
		"title": "The Warden's Gate",
		"subtitle": "One wall left between the camp and the heart of the Dust.",
		"tier": 9,
		"enemy_hp": 1.3,
		"enemy_damage": 1.1,
		"heroes": [],
		"seed": 4311,
		"bounds": Rect2(-1400, -3200, 2800, 3500),
		"roads": [[Vector2(0, 320), Vector2(60, -900), Vector2(-40, -1900), Vector2(0, -3300)]],
		"sets": [
			["slab_field", -640, -350], ["rubble_heap", 640, -400], ["crater_field", -660, -1050],
			["slab_field", 660, -1150], ["rubble_heap", -640, -1750], ["crater_field", 660, -1850],
			["slab_field", -660, -2700], ["slab_field", 660, -2750],
		],
		"props": [["wall_ruin_b", -360, -2560], ["wall_ruin", -560, -2540], ["wall_ruin_b", 360, -2560], ["wall_ruin", 560, -2540],
			["ruin_pillar", -180, -2580], ["ruin_pillar", 180, -2580], ["dust_spire", -420, -2250], ["dust_spire", 440, -2200],
			["guard_post", -300, -1300]],
		"fires": [[0, -2400, 1.0], [-200, -1200, 0.7]],
		"crates": [[300, -600], [-320, -900], [320, -1500], [-300, -2000]],
		"clear": [[0, -1300, 260], [0, -2250, 280]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["", "The Warden's Gate: a wall of slab and rebar a hundred feet high, and one way through."],
				["juno", "The lock's a military shear-bolt. I can cut it. I need a minute. Maybe two. Probably two."],
				["quill", "And something is standing in front of it. Something big, and holy, and very patient."],
				["helm", "Whatever happens past this wall, you all come back through it. That's an order. I'm the pilot, I get to give orders.", "radio"],
			],
			"vane_ally": [
				["", "Engines. Red rags. A raider crew rolls up out of the crater."],
				["vane", "Hangar folk. Told you I'd remember the day you let me walk."],
				["vane", "The Dust took half my crew since. I'm done running from it. You're going in? We're holding the door."],
				{"if": ["shared_medicine", true], "then": [["vane", "And tell the nun: the quarantine camp patched up my people. Tell her... thanks. Don't make it weird."]]},
				["{hero}", "Glad you came, Vane."],
				["vane", "Don't be glad. Be fast."],
			],
			"vane_enemy": [
				["", "Engines. Red rags. A raider crew rolls up out of the crater."],
				["vane", "You left me in the Dust. The Dust didn't want me. Funny, that."],
				["vane", "Whatever's past that gate, it's MINE. Medicine, power, the lot. Get out of my way."],
				["{hero}", "Vane, there's nothing past it but the thing that's killing all of us."],
				["vane", "Then I'll kill it after I kill you."],
			],
			"vane_after": [
				["vane", "...Fine. FINE. Go in. Go die in there. Better you than me."],
				["", "She limps back to her trucks. She doesn't look back. The crew follows her."],
			],
			"warden": [
				["", "The gate's shadow stirs. The Warden unfolds: armour plate, plague bloom, and a glow like a church window."],
				["quill", "That's the Dust Warden. It guards the heart. Whatever the plague was, it worships what comes next."],
				["juno", "I am NOT cutting a lock with that thing watching. Somebody please make it stop watching."],
			],
			"outro": [
				["", "The shear-bolt snaps. The gate groans open. Beyond it, the world is amber."],
				{"if": ["vane_spared", true], "then": [["vane", "Door's yours. We'll hold the road behind you. Come back out, hangar folk."]]},
				["helm", "That's Dustfall. That's the heart. Everyone, check your gear. And each other.", "radio"],
			],
		},
		"objectives": [
			{"type": "reach", "text": "Cross the crater to the gate", "at": Vector2(0, -1300), "r": 150,
				"waves": [{"t": 3, "kinds": ["ash_wraiths", "t2"], "n": 4}, {"t": 13, "kinds": "swarm", "n": 7}, {"t": 23, "kinds": "t2", "n": 3}],
				"trickle": {"every": 4.5, "kinds": ["plague", "swarm"], "cap": 9},
				"on_done": [["if", ["vane_spared", true], [["scene", "vane_ally"],
					["npc", {"id": "vane", "enemy": "raider_captain", "at": Vector2(-180, -1220), "label": "MOTHER VANE", "ally": true}],
					["npc", {"id": "grunt1", "enemy": "raider_grunt", "at": Vector2(160, -1240), "label": "", "ally": true}],
					["npc", {"id": "grunt2", "enemy": "raider_grunt", "at": Vector2(60, -1150), "label": "", "ally": true}],
					["npc_mode", "vane", "ally"], ["npc_mode", "grunt1", "ally"], ["npc_mode", "grunt2", "ally"]],
					[["scene", "vane_enemy"]]]]},
			{"type": "boss", "text": "Stop Mother Vane", "hint": "She's angrier this time. Mind the fire",
				"if_flag": ["vane_spared", false],
				"boss": {"kind": "raider_captain", "name": "Mother Vane", "epithet": "left to the Dust, and back", "at": Vector2(0, -1650), "hp": 1.6, "brain": "vane", "pref": 80},
				"on_done": [["clear_enemies"], ["scene", "vane_after"]]},
			{"type": "defend", "text": "Hold while Juno cuts the lock", "hint": "Keep them off the gate",
				"at": Vector2(0, -2250), "r": 270, "time": 55, "hp": 280, "fail": "The gate jammed. Juno had to run.",
				"on_start": [["if", ["vane_spared", true], [["npc_mode", "vane", "goto", Vector2(-150, -2180)], ["npc_mode", "grunt1", "goto", Vector2(170, -2200)],
					["npc_mode", "grunt2", "goto", Vector2(40, -2080)], ["radio", "vane", "Crew! Ring the gate! Nobody gets past us!"]]]],
				"waves": [{"t": 0, "kinds": "plague", "n": 7}, {"t": 9, "kinds": ["ash_wraiths", "swarm"], "n": 7}, {"t": 18, "kinds": "t2", "n": 3},
					{"t": 27, "kinds": "plague", "n": 8}, {"t": 36, "kinds": ["ash_wraiths", "apocalypse_wraith"], "n": 3}, {"t": 45, "kinds": "swarm", "n": 9}],
				"trickle": {"every": 3.0, "kinds": ["plague", "swarm"], "cap": 14},
				"on_done": [["clear_enemies"], ["scene", "warden"]]},
			{"type": "boss", "text": "Bring down the Dust Warden", "hint": "Get out of the pulse ring when it glows",
				"boss": {"kind": "dust_warden", "name": "The Dust Warden", "epithet": "keeper of the gate", "at": Vector2(0, -2500), "hp": 2.4},
				"trickle": {"every": 7.0, "kinds": "swarm", "cap": 6}},
			{"type": "extract", "text": "Through the Warden's Gate", "at": Vector2(0, -2600)},
		],
		"rewards": {"scrap": 380},
	}
