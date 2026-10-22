extends RefCounted

## CHAPTER 3 · 10 — Choke. The road to the Warden's Gate runs through an old
## chemical works. A Dust surge drops the whole team in the gas. Pebble, the
## biggest of them, carries them out one at a time. Not everyone may make it:
## who stays behind depends on what the story has made of them.
##   Vesper never opened up (L2)       -> she stays on the catwalk to cover.
##   else Nyx sold the back road (L6)  -> the raiders who bought it come for her.
##   else                              -> nobody. Not today.

static func def() -> Dictionary:
	return {
		"title": "Choke",
		"subtitle": "The gas comes up out of the Works. Pebble is the only one still standing.",
		"tier": 7,
		"enemy_hp": 1.25,
		"enemy_damage": 1.05,
		"hero": "pebble",
		"seed": 4210,
		"bounds": Rect2(-1300, -3300, 2600, 3600),
		"roads": [[Vector2(-100, 320), Vector2(40, -800), Vector2(-60, -1700), Vector2(80, -2600), Vector2(0, -3400)]],
		"sets": [
			["vat_bank", -620, -350], ["pipe_run", 640, -420], ["vat_single", -640, -1000],
			["vat_bank", 660, -1100], ["drum_dump", -620, -1700], ["pipe_run", 640, -1800],
			["vat_bank", -660, -2450], ["vat_single", 640, -2500], ["pipe_run", -620, -3050], ["drum_dump", 640, -3100],
		],
		"props": [["chem_vat", -280, -1400], ["chem_vat", 300, -1500], ["pipe_rack", 0, -2050], ["veh_humvee_1", -300, -330]],
		"fires": [[160, -2300, 0.7]],
		"crates": [[320, -600], [-340, -900], [320, -1300], [-320, -2200], [320, -2600]],
		"clear": [[-60, -300, 160], [-360, -1180, 120], [380, -1720, 120], [0, -2400, 140], [0, -2700, 240]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["", "Choke Works. Half a mile of rusted vats between the quarantine and the Warden's Gate."],
				["quill", "Masks on. The vats still breathe. Don't breathe with them."],
				["juno", "Pressure gauges are spinning. Like, SPINNING. That's not a normal amount of spinning."],
				["", "The ground shudders. Every valve in the Works blows at once. Amber gas rolls over the catwalks."],
				["rook", "Down! Everybody down!"],
				["pebble", "...Hello? Rook? Rook! Everyone's lying down. Why is everyone lying down?"],
				["helm", "Pebble, the gas didn't touch you? You're the biggest lungs in the Dust. Get them out. One at a time.", "radio"],
				["pebble", "I carried people out of the city when the plague came. I can carry my family out of a little gas."],
			],
			"vesper_stays": [
				["vesper", "Pebble. Put me down. I can walk. Barely. Enough."],
				["pebble", "You can't. Your legs are shaking."],
				["vesper", "My hands aren't. The catwalk has a line on the whole yard. Somebody covers the truck or nobody leaves."],
				["pebble", "Then we all stay."],
				["vesper", "No. I spent three years alone in a tower so I wouldn't have to need anyone. Let me need you. Go."],
				["vesper", "Tell Rook... tell her she took her time. Tell her I'm glad she did."],
			],
			"nyx_goes": [
				["", "Engines on the north road. Red rags on the bumpers. The crew that bought the back road has followed it here."],
				["nyx", "That's the crew I sold the road to. They didn't come for the medicine. They came for me."],
				["pebble", "Nyx, you can barely stand."],
				["nyx", "I can run. Running's the one thing I've never been bad at. I'll pull them west. You take everybody east."],
				["nyx", "And Pebble? Tell the Sister I'm square with her now. Tell her I'm sorry it took so long."],
			],
			"nobody": [
				["vesper", "Pebble. I can walk. Let me cover the yard from the catwalk."],
				["pebble", "No. Nobody stays. Not one of us. Hold on to my neck."],
				["vesper", "...Fine. I trust you. That's a new one for me."],
				["nyx", "And I'm not selling anybody anything ever again. Carry me too, big girl. I'm very light."],
			],
			"outro": [
				["", "The truck rolls out of the Works with everyone it has left."],
				{"if": ["choke_fall", "vesper_thorn"], "then": [
					["rook", "...Where's Vesper."],
					["pebble", "On the catwalk. She said you took your time. She said she was glad."],
					["rook", "..."],
					["rook", "Drive."]]},
				{"if": ["choke_fall", "nyx_caldera"], "then": [
					["cinder", "Where is Nyx?"],
					["pebble", "She ran west. She said she's square with you now. She said sorry."],
					["cinder", "Silly girl. She never owed me anything."]]},
				{"if": ["choke_fall", "none"], "then": [
					["helm", "Everyone? You got EVERYONE?", "radio"],
					["pebble", "Everyone. I counted twice. Then a third time, because Juno kept talking and I lost count."],
					["juno", "In my defence, I was very grateful."]]},
				["helm", "The Warden's Gate is past the crater. Then Dustfall. Then it's over. One way or the other.", "radio"],
			],
		},
		"objectives": [
			{"type": "reach", "text": "Into the Works", "at": Vector2(0, -1000), "r": 140,
				"on_start": [["if", ["vesper_open", false], [["flag", "choke_fall", "vesper_thorn"]],
					[["if", ["nyx_sold_road", true], [["flag", "choke_fall", "nyx_caldera"]], [["flag", "choke_fall", "none"]]]]]],
				"waves": [{"t": 3, "kinds": "plague", "n": 5}, {"t": 12, "kinds": "swarm", "n": 6}, {"t": 22, "kinds": "plague", "n": 5}],
				"on_done": [["hazard", "spore", Vector2(-360, -1180), 110.0, 90.0, 3.0], ["hazard", "spore", Vector2(380, -1720), 110.0, 90.0, 3.0],
					["hazard", "spore", Vector2(0, -2400), 120.0, 90.0, 3.0], ["shake", 0.6]]},
			{"type": "carry", "text": "Carry the team to the truck", "hint": "Three trips through the gas. Don't stop in it",
				"carry": {"from": [Vector2(-360, -1180), Vector2(380, -1720), Vector2(0, -2400)], "to": Vector2(-60, -420), "slow": 0.6,
					"icon": "tab_crew", "pickup_toast": "Got you. Hold on.", "carry_hint": "To the truck. Heavy: you're slower. Pebble doesn't mind"},
				"trickle": {"every": 3.0, "kinds": ["plague", "swarm"], "cap": 12},
				"waves": [{"t": 20, "kinds": "t2", "n": 2}, {"t": 50, "kinds": "plague", "n": 6}, {"t": 80, "kinds": "t2", "n": 2}]},
			{"type": "reach", "text": "Go back for the last one", "hint": "On the catwalk, past the pipe rack", "at": Vector2(0, -2700), "r": 120,
				"waves": [{"t": 4, "kinds": "plague", "n": 6}],
				"on_done": [["clear_enemies"],
					["if", ["choke_fall", "vesper_thorn"], [["scene", "vesper_stays"], ["flag", "fallen_vesper_thorn", true]]],
					["if", ["choke_fall", "nyx_caldera"], [["scene", "nyx_goes"], ["flag", "fallen_nyx_caldera", true]]],
					["if", ["choke_fall", "none"], [["scene", "nobody"]]]]},
			{"type": "survive", "text": "Hold the catwalk", "hint": "They covered you. Now get out", "time": 40,
				"unless_flag": ["choke_fall", "none"],
				"waves": [{"t": 0, "kinds": "plague", "n": 6}, {"t": 8, "kinds": "raider", "n": 5}, {"t": 16, "kinds": "t2", "n": 2},
					{"t": 24, "kinds": "plague", "n": 7}, {"t": 32, "kinds": "swarm", "n": 8}],
				"on_start": [["if", ["choke_fall", "vesper_thorn"], [["radio", "vesper", "I've got the yard. Go. GO."]], [["radio", "nyx", "Over here, you idiots! Catch me if you can!"]]]]},
			{"type": "carry", "text": "Carry the last one out", "hint": "Everyone goes home",
				"if_flag": ["choke_fall", "none"],
				"carry": {"from": [Vector2(0, -2760)], "to": Vector2(-60, -420), "slow": 0.65, "icon": "tab_crew",
					"pickup_toast": "Up you get.", "carry_hint": "Two on your back. Pebble doesn't mind"},
				"trickle": {"every": 2.6, "kinds": ["plague", "swarm"], "cap": 14},
				"waves": [{"t": 5, "kinds": "t2", "n": 2}, {"t": 20, "kinds": "plague", "n": 7}]},
			{"type": "defend", "text": "Hold the truck", "hint": "Juno's restarting it. Coughing, but restarting it",
				"at": Vector2(-60, -400), "r": 240, "time": 40, "hp": 260, "fail": "The truck's gone. So is the way out.",
				"on_start": [["radio", "juno", "*cough* Give me forty seconds. *cough* Thirty if you stop them shooting at the engine."]],
				"waves": [{"t": 0, "kinds": "plague", "n": 7}, {"t": 9, "kinds": "swarm", "n": 8}, {"t": 18, "kinds": "t2", "n": 3},
					{"t": 27, "kinds": "plague", "n": 8}, {"t": 34, "kinds": "swarm", "n": 6}],
				"trickle": {"every": 3.0, "kinds": "plague", "cap": 13}},
			{"type": "extract", "text": "Drive out of the Works", "at": Vector2(-60, -300)},
		],
		"rewards": {"scrap": 360},
	}
