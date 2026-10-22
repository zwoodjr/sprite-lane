extends RefCounted

## EPILOGUE — Wheels Up. The plane is whole. Everyone the story kept climbs
## in; the ones it didn't are remembered. The Dust ends somewhere out there.
## (A cinematic: the painted hangar, the takeoff, the tease for Act Two.)

static func def() -> Dictionary:
	return {
		"title": "Wheels Up",
		"subtitle": "Airframe, battery, fuel, engine, heart. Everybody in.",
		"goal": "Say your goodbyes to the Dust",
		"tier": 1,
		"hero": "helm_wisp",
		"pet": "",
		"seed": 5000,
		"cinematic": true,
		"bounds": Rect2(-600, -600, 1200, 1200),
		"outro_title": "ACT ONE COMPLETE",
		"intro": "hangar",
		"sky": "sky",
		"scenes": {
			"hangar": [
				["", "The hangar, the morning after. Somebody painted a sign over the door. It says HOME. It's spelled right. Mostly."],
				["helm", "Okay. Okay okay okay. Airframe. Battery. Fuel. Engine..."],
				{"if": ["ending", "power"], "then": [["juno", "...and one caged heart, purring in a lead box. She'll fly on that thing for a hundred years. Probably. Don't quote me."]],
					"else": [["juno", "...and the heart's last shard, cold now. Just a battery. A very dramatic battery."]]},
				["rook", "Wall's fixed. Rack's mine. Nobody touches the rack."],
				["pebble", "I fixed the roof. Twice. The second time was for practice."],
				{"if": ["fallen_vesper_thorn", true], "then": [["rook", "Vesper would've taken the window seat. I'm keeping it empty."]],
					"else": [["vesper", "I'll ride up top. I like to see things coming."], ["rook", "You took your time warming up to us."], ["vesper", "You took your time finding me. We're even."]]},
				["cinder", "I've packed tonics. And a kettle. A REAL kettle. Juno made it out of a shell casing."],
				["quill", "And I've packed the notebook. Nobody has ever catalogued the world past the Dust. I'm unreasonably excited."],
				{"if": ["fallen_nyx_caldera", true], "then": [["cinder", "Nyx would have found us a shortcut through the sky. She always knew a back way."]],
					"else": [["nyx", "Somebody has to know the back way out of a sky. Might as well be me."]]},
				{"if": ["vane_spared", true], "then": [["helm", "Mother Vane's crew is minding the hangar while we're gone. Weird times. Good weird."]]},
				{"if": ["shared_medicine", true], "then": [["cinder", "The quarantine camp sent a crate for the road. Bandages and a note. It says: come back."]]},
				["noel", "*sits on Helm's boot. Refuses to move. Has decided she's coming.*"],
				["bentley", "*yips at the propeller like it owes him money*"],
				["lillie", "*headbutts the landing gear. The landing gear survives. Barely.*"],
				["helm", "Everybody in. Dogs in. Biscuit, you're co-pilot. Don't touch anything."],
				["helm", "Wisp Two... no. New plane. New name. This is Wisp Home, requesting the whole sky."],
			],
			"sky": [
				["", "Wheels up."],
				["helm", "Look at it. Look at all of it. The Dust ends. Out there it just... ends."],
				{"if": ["ending", "destroy"], "then": [["quill", "Green. On the hills. That's green. I'd forgotten green."],
					["cinder", "The plague will come back, weak and small. We'll be ready for it this time."]],
					"else": [["cinder", "Amber behind us, blue ahead. Keep that heart caged, Helm. Promise me."], ["helm", "I promise. Every day."]]},
				["rook", "What's out there?"],
				["helm", "No idea. Isn't it great?"],
				["", "ACT ONE: THE LONG DUST. The end."],
				["", "ACT TWO: NEW LANDS. Coming soon."],
			],
		},
		"objectives": [],
		"rewards": {"scrap": 600},
	}
