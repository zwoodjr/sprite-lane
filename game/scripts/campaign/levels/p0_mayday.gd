extends RefCounted

## PROLOGUE: Mayday. Helm crashes in the Haze, follows the smoke to an old
## hangar, wins over Noel and holds the door. Teaches move / auto-fire / dash /
## loot / hold / extract. Rook is waiting inside.
## Blind playtest pass: tightened from ~15-20 min to ~5-7 (fewer, closer
## fights, a shorter hold, three med kits on the road, trimmed scenes).
## Skippable for returning players / after a death (level card).

static func def() -> Dictionary:
	return {
		"title": "Mayday",
		"subtitle": "Wisp Two is going down. Walk away from it.",
		"tier": 1,
		"skippable": true,
		"enemy_hp": 0.6,
		"enemy_damage": 0.55,
		"hero": "helm_wisp",
		"pet": "",
		"seed": 1101,
		"bounds": Rect2(-1000, -3100, 2000, 3400),
		"roads": [[Vector2(-40, 300), Vector2(40, -380), Vector2(-90, -1100), Vector2(10, -1700), Vector2(-60, -2300), Vector2(20, -3200)]],
		"sets": [
			["crater_field", -560, -180], ["junk_heap", 580, -260], ["rock_garden", 600, 160],
			["junkyard", -600, -980], ["pole_line", 460, -900], ["pileup", 520, -1500],
			["campsite", -520, -1560], ["junkyard", 560, -2050], ["barricade", -520, -2150],
			["fence_run", 520, -2700], ["rock_garden", -600, -2750], ["junk_heap", -560, -2950],
		],
		"props": [["world/plane_wreck", 190, 40]],
		"fires": [[150, 0, 1.2], [250, 70, 0.8], [120, 90, 0.6]],
		"crates": [[320, -560], [-360, -640], [300, -1180], [-300, -1700], [340, -1900], [-280, -2300]],
		"landmarks": [{"name": "THE HANGAR", "pos": Vector2(0, -2760), "kind": 1}],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["", "The plague came first. Then the war, over whatever medicine was left. Now the Dust rolls over all of it."],
				["helm", "Mayday, mayday, this is Wisp Two. Supply drop, one engine left, and it's thinking about quitting.", "radio"],
				["helm", "Nobody? Great. Love that for me. Taking her down in the Haze.", "radio"],
				["helm", "Okay. Plane's on fire. That's fine. Legs work, pistol works. Rule one of the Dust: don't stand next to the burning thing."],
			],
			"gators": [
				["helm", "Biscuit, we've got company. Big, green, ugly."],
				["helm", "You don't aim out here. Walk, and the pistol finds them. Stay in range and keep moving."],
			],
			"noel_meet": [
				["helm", "Is that... a hangar? A whole hangar? Biscuit, we're rich."],
				["noel", "*low growl*"],
				["helm", "Oh. Hi. You live here, huh? Good guard dog. Nice guard dog."],
				{"speaker": "helm", "prompt": "Okay. Think, Helm.", "choice": [
					{"text": "Offer her your last jerky", "flag": "noel_jerky", "value": true, "then": [
						["noel", "*sniff... sniff... CHOMP*"],
						["helm", "That was dinner. And breakfast. You're welcome."],
					]},
					{"text": "Sit down and wait", "flag": "noel_jerky", "value": false, "then": [
						["helm", "..."],
						["noel", "*the growl fades. She pads over and leans her whole weight on your leg.*"],
						["helm", "Yeah. Me too, buddy. Long day."],
					]},
				]},
				["", "Something howls out in the Dust. A lot of somethings."],
				["helm", "Right. We hold the door. You bite, I shoot. Partners?"],
				["noel", "*BARK*"],
			],
			"outro": [
				["", "Inside: dust sheets, a dead generator, and under a tarp, the bones of an airplane."],
				["helm", "No way. That's a whole airframe. Biscuit, Noel: meet my new plane. She doesn't fly. Yet."],
				["rook", "Your plane's in my spot. Ash Rook. I cleared the road you crashed on."],
				["rook", "That dog doesn't let anybody in. She let you in."],
				{"if": ["noel_jerky", true], "then": [["helm", "I bribed her. With dinner. Helm Wisp, pilot. Between planes."]],
					"else": [["helm", "We had a moment. Helm Wisp, pilot. Between planes."]]},
				["rook", "...Fine. You stay. Don't touch my rack. And get the lights working."],
				["helm", "Deal. Welcome home, Rook. I'll paint us a sign."],
			],
		},
		"objectives": [
			{"type": "reach", "text": "Get clear of the wreck", "hint": "Drag on the left of the screen to move",
				"at": Vector2(0, -430), "r": 100},
			{"type": "kill", "text": "Drive off the gators", "hint": "Keep moving: Helm fires on her own", "count": 6,
				"on_start": [["scene", "gators"]],
				"waves": [{"t": 0, "kinds": "rad_gator", "n": 3, "at": Vector2(60, -700), "r": 110},
					{"t": 5, "kinds": "toxic_scorp", "n": 2, "at": Vector2(-200, -600), "r": 80},
					{"t": 10, "kinds": "rad_gator", "n": 2, "at": Vector2(120, -560), "r": 90}],
				"on_done": [["radio", "helm", "Hah! Still got it. Mostly. Some of it."]]},
			{"type": "collect", "text": "Grab the med kits", "hint": "Follow the arrow and walk over them. Tap DASH to dodge", "icon": "ing_medicine",
				"items": [Vector2(-90, -900), Vector2(110, -1120), Vector2(-60, -1360)],
				"on_start": [["radio", "helm", "Med kits on the road. Somebody packed for a trip they never took."]],
				"waves": [{"t": 2, "kinds": "scrap_hound", "n": 2, "at": Vector2(40, -1050), "r": 90}],
				"trickle": {"every": 6.0, "kinds": "t1", "cap": 4}},
			{"type": "clear", "text": "Clear the scrapyard", "hint": "Machines nesting in the junk. Shoot the dogs first",
				"on_start": [["radio", "helm", "Biscuit, those are war dogs. Somebody forgot to turn them off."]],
				"waves": [{"t": 0, "kinds": "scrap_hound", "n": 3, "at": Vector2(160, -1700), "r": 120},
					{"t": 7, "kinds": ["coil_spider", "scrap_hound"], "n": 3, "at": Vector2(-120, -1850), "r": 110}]},
			{"type": "reach", "text": "Reach the hangar", "hint": "Follow the arrow up the road", "at": Vector2(0, -2420), "r": 120,
				"on_start": [["npc", {"id": "noel", "pet": "noel", "at": Vector2(40, -2560), "label": ""}],
					["radio", "helm", "Smoke on the ridge... no. That's not smoke. That's Dust. Lots of it."]],
				"on_done": [["scene", "noel_meet"], ["pet_join", "noel", "noel"]]},
			{"type": "hold", "text": "Hold the hangar door", "hint": "Stay in the ring. Noel fights with you",
				"at": Vector2(0, -2570), "r": 200, "time": 30,
				"waves": [{"t": 0, "kinds": "t1", "n": 4}, {"t": 7, "kinds": "scrap_hound", "n": 3},
					{"t": 14, "kinds": ["rad_gator", "toxic_scorp"], "n": 4}, {"t": 21, "kinds": "glow_moth", "n": 3}],
				"on_start": [["radio", "helm", "Biscuit, give me eyes! Noel, sic 'em!"]]},
			{"type": "extract", "text": "Get inside", "hint": "Walk onto the glowing pad by the door and stand still for 3 s", "at": Vector2(0, -2700)},
		],
		"rewards": {"scrap": 150, "survivors": ["helm_wisp", "ash_rook"], "pets": ["noel"], "part": "fuselage"},
	}
