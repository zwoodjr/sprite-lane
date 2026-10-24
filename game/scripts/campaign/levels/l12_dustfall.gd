extends RefCounted

## CHAPTER 3 · 12 — Dustfall. Where the Dust began. The heart is a body now:
## the Wasteland God. Kill it, then choose what to do with what's left of it:
## destroy the heart, or carry it home to power Helm's plane.

static func def() -> Dictionary:
	return {
		"title": "Dustfall",
		"subtitle": "Where the Dust began. Where it ends.",
		"tier": 10,
		"enemy_hp": 1.6,
		"enemy_damage": 1.65,
		"heroes": [],
		"seed": 4412,
		"bounds": Rect2(-1400, -3300, 2800, 3600),
		"roads": [],
		"sets": [
			["spire_field", -640, -350], ["slab_field", 640, -400], ["spire_small", -660, -1050],
			["spire_field", 660, -1150], ["tank_hulk", -640, -1800], ["spire_field", 660, -1850],
			["spire_field", -680, -2750], ["slab_field", 680, -2800],
		],
		"props": [["dust_spire", -300, -1500], ["dust_spire", 320, -1450], ["sinkhole_dustfall_l", 0, -2400],
			["dust_spire", -360, -2050], ["dust_spire", 380, -2100]],
		"fires": [[-200, -900, 0.8], [220, -1700, 0.8]],
		"crates": [[300, -600], [-320, -1000], [300, -1600], [-300, -2200]],
		"clear": [[0, -1200, 220], [0, -2300, 360]],
		"intro": "intro",
		"outro": "outro",
		"scenes": {
			"intro": [
				["", "Dustfall. The sky is the colour of a lamp left on too long. The ground hums."],
				["quill", "Every shard we've ever picked up came from here. Every sick thing we ever fought was a finger of it."],
				["cinder", "Then let's go and shake its hand."],
				["helm", "I'm flying top cover with Biscuit as long as the radio holds. After that, you're on your own. You're never on your own.", "radio"],
				["{hero}", "Let's finish it."],
			],
			"choir": [
				["", "The wraiths stand in rows between the spires, swaying, humming one long note."],
				["quill", "A choir. It's singing to itself. Cut through them before the song finishes."],
			],
			"heart": [
				["dust", "SMALL THINGS. YOU CARRY MY SHARDS IN YOUR POCKETS. YOU BREATHE ME EVERY MORNING."],
				["dust", "I ATE THE PLAGUE. I AM WHAT THE PLAGUE BECAME WHEN IT STOPPED BEING HUNGRY FOR ONE BODY AND WANTED ALL OF THEM."],
				["dust", "STOP ME, AND THE WORLD STOPS BEING DUST. IT STARTS BEING SICK AGAIN. IS THAT BETTER?"],
				["{hero}", "Sick people can be healed. Dust can't. Yes. It's better."],
			],
			"choice": [
				["", "The Wasteland God falls apart into sand. In the middle of it, the heart: a knot of amber the size of a fist, still beating."],
				["juno", "That's... that's a power source. A real one. That could fly the plane to the edge of the world. I'm just saying. Factually."],
				["cinder", "Or it could start all of this again, one day, in someone's pocket."],
				["quill", "If it lives, the Dust lives, smaller. If it dies, the Dust dies and the plague comes back in its old shape. Weak. Curable."],
				{"speaker": "{hero}", "prompt": "The heart is still beating. What do you do?", "choice": [
					{"text": "Destroy the heart", "flag": "ending", "value": "destroy", "then": [
						["{hero}", "No more Dust. Not in anyone's pocket. Not in Helm's plane."],
						["", "One blow. The amber cracks, and the beat stops. Across the whole wasteland, the wind changes."],
						["quill", "...Listen. Nothing's humming."],
					]},
					{"text": "Take it to power the plane", "flag": "ending", "value": "power", "then": [
						["{hero}", "It burned the world. It can fly us out of it. We'll keep it close. We'll keep it caged."],
						["", "The heart goes into Juno's lead-lined box. It beats against the lid, slower now. Almost calm."],
						["cinder", "Then we watch it. Every day. I'll pray over it if I have to."],
					]},
				]},
				["", "The ground shakes. Without its heart, Dustfall is collapsing into the sinkhole."],
				["helm", "Get OUT of there! The whole crater's going down!", "radio"],
			],
			"outro": [
				["helm", "I see you! I see all of you! Get in the truck, you beautiful idiots!", "radio"],
				{"if": ["ending", "destroy"], "then": [["quill", "The Dust is settling. Really settling. You can see the hills."]],
					"else": [["juno", "The box is warm. Like holding a cat. A cat that ended the world. Good cat."]]},
				["{hero}", "Let's go home."],
			],
		},
		"triggers": [
			{"at": Vector2(0, -650), "r": 220, "do": [["radio", "dust", "...small things... coming home..."], ["spawn", "swarm", 6, Vector2(0, -900), 220]]},
			{"at": Vector2(0, -1650), "r": 220, "do": [["radio", "helm", "Radio's breaking up. If you can hear me: I'm proud of you. All of you."]]},
		],
		"objectives": [
			{"type": "reach", "text": "Walk into Dustfall", "at": Vector2(0, -1150), "r": 150,
				"waves": [{"t": 2, "kinds": ["ash_wraiths", "t2"], "n": 5}, {"t": 12, "kinds": "swarm", "n": 8}, {"t": 22, "kinds": "t2", "n": 4}],
				"trickle": {"every": 4.0, "kinds": ["plague", "swarm"], "cap": 10},
				"on_done": [["hazard", "spore", Vector2(-260, -1400), 100.0, 60.0, 4.0], ["hazard", "spore", Vector2(260, -1650), 100.0, 60.0, 4.0]]},
			{"type": "kill", "text": "Cut through the choir", "hint": "Wraiths in rows. Break the song", "count": 20,
				"on_start": [["scene", "choir"]],
				"waves": [{"t": 0, "kinds": "ash_wraiths", "n": 6, "at": Vector2(0, -1700), "r": 260},
					{"t": 8, "kinds": ["ash_wraiths", "apocalypse_wraith"], "n": 5}, {"t": 16, "kinds": "swarm", "n": 8},
					{"t": 24, "kinds": "ash_wraiths", "n": 7}, {"t": 32, "kinds": ["t2", "ash_wraiths"], "n": 5}]},
			{"type": "hold", "text": "Climb to the heart", "hint": "The spire shakes. Hold on",
				"at": Vector2(0, -2050), "r": 180, "time": 35,
				"waves": [{"t": 0, "kinds": "plague", "n": 7}, {"t": 9, "kinds": "ash_wraiths", "n": 6}, {"t": 18, "kinds": "t2", "n": 3},
					{"t": 27, "kinds": "swarm", "n": 9}],
				"on_done": [["clear_enemies"], ["scene", "heart"]]},
			{"type": "boss", "text": "Kill the Wasteland God", "hint": "Pulses near it, Dust falling where you stand. Keep moving",
				"boss": {"kind": "wasteland_god_entity", "name": "The Wasteland God", "epithet": "the heart of the Dust", "at": Vector2(0, -2450), "hp": 2.0, "brain": "god"},
				"on_done": [["clear_enemies"], ["scene", "choice"]]},
			{"type": "extract", "text": "Get out before it falls", "hint": "Run. The crater is caving in", "at": Vector2(0, -400),
				"waves": [{"t": 0, "kinds": "swarm", "n": 8}, {"t": 8, "kinds": "ash_wraiths", "n": 6}, {"t": 16, "kinds": "swarm", "n": 8}],
				"on_start": [["shake", 0.8], ["hazard", "spore", Vector2(-180, -1900), 120.0, 60.0, 5.0], ["hazard", "spore", Vector2(200, -1300), 120.0, 60.0, 5.0]]},
		],
		"rewards": {"scrap": 500, "part": "heart", "part_if": ["ending", "power"]},
	}
