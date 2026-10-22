extends RefCounted

## CHAPTER 1 · 2 — The Bell Tower. Vesper, half-starved, alone in a bell tower
## for years. Tonight a stranger with a rocket launcher walks into her sights
## with a war walker on her heels. Stay or go.

static func def() -> Dictionary:
	return {
		"title": "The Bell Tower",
		"subtitle": "Every night for three years, someone rang the bell in the dead city.",
		"tier": 4,
		"enemy_hp": 0.85,
		"enemy_damage": 0.75,
		"hero": "vesper_thorn",
		"seed": 2302,
		"bounds": Rect2(-1300, -1500, 2600, 2700),
		"roads": [[Vector2(-1400, 200), Vector2(-400, 120), Vector2(300, -200), Vector2(1400, -420)]],
		"sets": [
			["street_block", -620, -620], ["ruin_house", 640, -760], ["lamp_car", -660, 420],
			["street_block", 700, 380], ["rubble_heap", -900, -1100], ["ruin_house", 900, -1180],
			["slab_field", 0, 860], ["barricade", -950, 900], ["lamp_car", 980, 950],
		],
		"props": [["world/watch_tower", 0, -200], ["street_lamp", -150, 60], ["street_lamp", 170, 40]],
		"fires": [[-60, 120, 0.7]],
		"crates": [[-380, 260], [420, -300], [-500, -350], [360, 620]],
		"clear": [[0, 0, 200]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["", "The dead city. A bell tower with no bell-ringer left. Except one."],
				["vesper", "Day one thousand and something. Ate the last tin yesterday. Or the day before."],
				["vesper", "Movement. North road. One person. Big launcher. Running."],
				["vesper", "...And a walker behind her. Old war model. She won't outrun it."],
				["vesper", "Not my problem."],
				["vesper", "..."],
				["vesper", "Fine."],
			],
			"meet": [
				["rook", "You. Up in the tower. That was you shooting?"],
				["vesper", "You were losing."],
				["rook", "I was winning slowly. Ash Rook. You the one ringing that bell every night?"],
				{"speaker": "rook", "prompt": "Why ring it? Half the Dust can hear that thing.", "choice": [
					{"text": "So someone would find me", "flag": "vesper_open", "value": true, "then": [
						["vesper", "So someone would come. Nobody did. Until you. You took your time."],
						["rook", "Took me three years to find the road. Sorry."],
					]},
					{"text": "To keep them away", "flag": "vesper_open", "value": false, "then": [
						["vesper", "It scares the small ones off. The big ones come anyway. I shoot those."],
						["rook", "Lonely way to live."],
						["vesper", "It's a way to live."],
					]},
				]},
				["", "The ground shudders. Something heavy is still coming down the north road."],
				["rook", "That walker followed me. Can you drop it?"],
				["vesper", "Stand back and don't get in my line."],
			],
			"stay_go": [
				["rook", "There's a hangar east of here. Roof, food, a pilot who won't shut up. Come with me."],
				["vesper", "There's a cache under the bell. Three years of scavenging. Ringing it brings everything for a mile."],
				{"speaker": "vesper", "prompt": "Leave it? Or ring the bell one last time and take it with us?", "choice": [
					{"text": "Go now", "flag": "l2_stayed", "value": false, "then": [
						["vesper", "...It's only stuff. Let's go before I change my mind."],
					]},
					{"text": "Stay. Ring the bell", "flag": "l2_stayed", "value": true, "then": [
						["rook", "Ha. Now we're talking. Ring it. I'll hold the door."],
						["vesper", "Last time. Make it loud."],
					]},
				]},
			],
			"outro": [
				["helm", "Rook, who's that behind you? Hello! Welcome! Do you like soup? We have one soup.", "radio"],
				["vesper", "Is she always like this?"],
				["rook", "Worse at breakfast."],
				{"if": ["l2_stayed", true], "then": [["helm", "And you brought... oh, that's a lot of ammo. Marry me.", "radio"],
					["vesper", "No."]], "else": [["helm", "Travelling light, huh? Smart. Everything here is held together with hope anyway.", "radio"]]},
				["vesper", "Vesper. Vesper Thorn. I'll take the roof. I like to see things coming."],
			],
		},
		"objectives": [
			{"type": "defend", "text": "Cover the stranger", "hint": "Keep the pack off her. Stay in the ring",
				"at": Vector2(40, -500), "r": 300, "time": 55, "hp": 200, "fail": "The stranger went down. Nobody rings for her.",
				"on_start": [["npc", {"id": "rook", "hero": "ash_rook", "at": Vector2(40, -520), "label": "STRANGER", "ally": true}],
					["npc_mode", "rook", "ally"]],
				"waves": [{"t": 0, "kinds": "scrap_hound", "n": 4, "at": Vector2(60, -900), "r": 160},
					{"t": 8, "kinds": "t1", "n": 5}, {"t": 16, "kinds": ["scav_bear_cub", "scrap_hound"], "n": 5},
					{"t": 25, "kinds": "swarm", "n": 6}, {"t": 32, "kinds": "scav_bear", "n": 1},
					{"t": 40, "kinds": "scrap_hound", "n": 5}, {"t": 47, "kinds": ["scav_bear_cub", "t1"], "n": 5}]},
			{"type": "talk", "text": "Talk to the stranger", "npc": "rook", "r": 110,
				"on_done": [["scene", "meet"], ["npc_label", "rook", "ROOK"]]},
			{"type": "boss", "text": "Bring down the war walker", "hint": "It shields its front. Circle it",
				"boss": {"kind": "cyber_juggernaut", "role": "elite", "name": "War Walker", "epithet": "still marching to a war that ended", "at": Vector2(0, -1150), "hp": 3.5},
				"trickle": {"every": 6.0, "kinds": "scrap_hound", "cap": 6},
				"on_done": [["radio", "rook", "Nice shot. Nice ALL the shots. You eat today. That's an order."]]},
			{"type": "kill", "text": "Clear the square", "hint": "The walker's noise drew the scavengers", "count": 14,
				"waves": [{"t": 0, "kinds": "t1", "n": 6}, {"t": 8, "kinds": "swarm", "n": 6}, {"t": 16, "kinds": ["scav_bear_cub", "dune_stalker"], "n": 5}]},
			{"type": "collect", "text": "Grab your kit", "hint": "Three years of your life, scattered round the tower", "icon": "ing_dust_shard",
				"items": [Vector2(-460, 160), Vector2(520, 220), Vector2(-60, 560)],
				"on_done": [["scene", "stay_go"]]},
			{"type": "hold", "text": "Ring the bell", "hint": "Hold the tower. Everything for a mile is coming",
				"if_flag": ["l2_stayed", true], "at": Vector2(0, 40), "r": 180, "time": 45,
				"on_start": [["shake", 0.5], ["radio", "rook", "That's LOUD. Here they come!"]],
				"waves": [{"t": 0, "kinds": "t1", "n": 6}, {"t": 7, "kinds": "swarm", "n": 8}, {"t": 14, "kinds": "t2", "n": 2},
					{"t": 20, "kinds": "t1", "n": 6}, {"t": 27, "kinds": ["scav_bear", "dune_serpent"], "n": 2},
					{"t": 34, "kinds": "swarm", "n": 8}, {"t": 39, "kinds": "t2", "n": 2}],
				"on_done": [["scrap", 140], ["flag", "rang_bell", true]]},
			{"type": "extract", "text": "Leave with Rook", "at": Vector2(-60, -760),
				"on_start": [["npc_mode", "rook", "goto", Vector2(-60, -700)]]},
		],
		"rewards": {"scrap": 200, "survivors": ["vesper_thorn"]},
	}
