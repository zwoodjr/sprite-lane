extends RefCounted

## CHAPTER 3 · 9 — Quarantine. The old army walled the Dust in here, and the
## machines held the line until something broke it: a war machine with the
## plague grown through it. The road to Dustfall runs through the gap.

static func def() -> Dictionary:
	return {
		"title": "Quarantine",
		"subtitle": "The machines held this line for years. Something broke it.",
		"tier": 5,
		"enemy_hp": 1.45,
		"enemy_damage": 1.6,
		"heroes": [],
		"seed": 4109,
		"bounds": Rect2(-1400, -3500, 2800, 3800),
		"roads": [[Vector2(0, 320), Vector2(-80, -900), Vector2(60, -1700), Vector2(-40, -2600), Vector2(0, -3600)]],
		"sets": [
			["q_camp", -640, -350], ["fence_run", 640, -400], ["tent_post", -660, -1050],
			["q_camp", 660, -1150], ["fence_run", -640, -1800], ["tent_post", 660, -1900],
			["q_camp", -660, -2650], ["fence_run", 660, -2700], ["junk_heap", -640, -3200], ["tent_post", 640, -3250],
		],
		"props": [["world/relay", -420, -1500], ["world/relay", 440, -1560], ["hazard_barrier", -160, -2060],
			["hazard_barrier", 180, -2060], ["quarantine_tent", -300, -700], ["veh_ambulance_1", 300, -760],
			["world/field_tent", 120, -380]],
		"fires": [[-60, -600, 0.6]],
		"crates": [[320, -500], [-360, -1000], [300, -1300], [-320, -2300], [300, -2500]],
		"clear": [[-420, -1420, 140], [440, -1480, 140], [0, -2200, 280]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["quill", "The quarantine line. They walled the Dust in here, early on. Before anyone knew what it was."],
				["juno", "Those pylons along the fence: they're not fences. They're emitters. The machines were BURNING the Dust back."],
				["helm", "Dustfall's past the gate on the far side. This is the only road through.", "radio"],
				{"if": ["shared_medicine", true], "then": [
					["cinder", "There was a camp here. We left them half our medicine. Let's see if it bought them anything.", "radio"]],
					"else": [["cinder", "There was a camp here. We kept the medicine for ourselves. I've prayed on it every night since.", "radio"]]},
			],
			"camp_ok": [
				["", "The camp is still standing. Someone has painted a red cross on the gate, and under it: THANK YOU, SISTER."],
				["cinder", "...They lived. Some of them. They lived.", "radio"],
				["", "A crate waits by the gate: tonics, bandages, a box of shells. And a note: for the road."],
			],
			"camp_gone": [
				["", "The camp is empty. Tents flapping. Cots in rows. The Dust has been through."],
				["cinder", "Lord, forgive us. Forgive me.", "radio"],
				["rook", "Nothing to do here but keep moving. And remember it.", "radio"],
			],
			"pylons": [
				["juno", "Both emitters humming! The line's live again. The Dust is pulling back, look at it go!"],
				["quill", "Something in the middle of the yard isn't pulling back. It's coming toward the gate."],
				["", "A war machine walks out of the Dust. Half of it is steel. The other half is grown."],
			],
			"outro": [
				["quill", "Plague grown through a machine built to fight the plague. The Dust doesn't just spread. It recruits."],
				["juno", "The emitters will hold for a while. A while. Not forever. Nothing holds forever against that."],
				["helm", "Then we don't wait for forever. Choke Works is next, then the gate, then the heart.", "radio"],
				["pebble", "Then we go together. All of us. I'll carry whoever needs carrying."],
			],
		},
		"objectives": [
			{"type": "reach", "text": "Enter the quarantine line", "at": Vector2(0, -620), "r": 140,
				"waves": [{"t": 2, "kinds": "plague", "n": 5}, {"t": 12, "kinds": "swarm", "n": 6}, {"t": 22, "kinds": "plague", "n": 5}]},
			{"type": "reach", "text": "Check on the camp", "at": Vector2(60, -480), "r": 120,
				"on_done": [["if", ["shared_medicine", true], [["scene", "camp_ok"], ["heal"], ["scrap", 120]], [["scene", "camp_gone"], ["spawn", "swarm", 8, Vector2(0, -700), 260]]]]},
			{"type": "hold", "text": "Restart the west emitter", "hint": "Hold at the pylon while it charges",
				"at": Vector2(-420, -1385), "r": 130, "time": 22,
				"waves": [{"t": 0, "kinds": "plague", "n": 6}, {"t": 8, "kinds": "swarm", "n": 7}, {"t": 15, "kinds": ["scav_bear", "glow_moth_queen"], "n": 2}],
				"on_done": [["radio", "juno", "West emitter live! I love that sound. That's the sound of a machine doing its job."]]},
			{"type": "hold", "text": "Restart the east emitter", "hint": "Across the yard. Faster now",
				"at": Vector2(440, -1445), "r": 130, "time": 22,
				"waves": [{"t": 0, "kinds": "plague", "n": 7}, {"t": 8, "kinds": "t2", "n": 2}, {"t": 15, "kinds": "swarm", "n": 8}],
				"on_done": [["scene", "pylons"]]},
			{"type": "boss", "text": "Bring down the line-breaker", "hint": "Spores under you: move. Brood: burn it",
				"boss": {"kind": "mutant_overlord", "name": "Mutant Overlord", "epithet": "the machine that broke the line", "at": Vector2(0, -2250), "hp": 2.2, "brain": "overlord"},
				"trickle": {"every": 7.0, "kinds": "plague", "cap": 6}},
			{"type": "defend", "text": "Hold the gate open", "hint": "Juno's resetting the gate. The Dust pushes back",
				"at": Vector2(0, -2400), "r": 260, "time": 45, "hp": 260, "fail": "The gate slammed shut. The road to Dustfall is closed.",
				"waves": [{"t": 0, "kinds": "plague", "n": 7}, {"t": 9, "kinds": "swarm", "n": 8}, {"t": 18, "kinds": "t2", "n": 3},
					{"t": 27, "kinds": "plague", "n": 8}, {"t": 36, "kinds": ["ash_wraiths", "scav_bear"], "n": 3}],
				"trickle": {"every": 3.0, "kinds": "plague", "cap": 13}},
			{"type": "extract", "text": "Through the gate", "at": Vector2(0, -2700)},
		],
		"rewards": {"scrap": 340, "camp": {"ammo_bench": 1}},
	}
