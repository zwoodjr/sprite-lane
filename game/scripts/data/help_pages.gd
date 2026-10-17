class_name HelpPages
extends RefCounted

## Plain-language "How to play" content. Shared by the How to Play screen
## and the pause menu. Keep each page short — it's read on a phone.

static func pages() -> Array[Dictionary]:
	return [
		{
			"title": "The idea",
			"icon": "◎",
			"body": "You drop into an endless dust wasteland. Fight, loot crates, and get OUT through an extract pad.\n\nMake it out → you keep everything and get paid.\nGo down → you lose the gear you brought (unless insured). XP is always kept.",
		},
		{
			"title": "Moving & shooting",
			"icon": "✥",
			"body": "LEFT thumb anywhere on the left half = move. The stick appears under your thumb.\n\nRIGHT thumb anywhere on the right half = aim. Push past the inner ring and you fire.\n\nOr just hold FIRE — it auto-targets the nearest enemy.",
		},
		{
			"title": "Dash",
			"icon": "»",
			"body": "Tap DASH to burst in the direction you're moving.\n\nYou're invincible for a split second — dash THROUGH red bullets and charging enemies.\n\nThe ring on the button shows the cooldown.",
		},
		{
			"title": "Read the enemy",
			"icon": "!",
			"body": "A red wedge appears before every attack. That's your cue to move or dash.\n\nRaiders shoot from range. Chargers (orange) rush you and lunge. Brutes (blue, big) are slow tanks that fire spreads.",
		},
		{
			"title": "The clock",
			"icon": "◷",
			"body": "Every run has phases shown at the top:\n\nLOCKOUT — extracts are sealed. Survive and loot.\nEXTRACT OPEN — pads light up gold. Stand on one to leave.\nSEALED — window closed; another opens later.\nLAST EXTRACT — final chance. Miss it and you're wiped.",
		},
		{
			"title": "Threat & greed",
			"icon": "▲",
			"body": "Every extract window you skip raises THREAT by 1.\n\nHigher Threat = tougher, more frequent enemies… and a much bigger payout (up to ×2.25).\n\nStaying near an open window also builds your Stay bonus. Leave early and safe, or stay and get rich.",
		},
		{
			"title": "Finding the way out",
			"icon": "➤",
			"body": "Pads move every run.\n\nGold arrows on the screen edge point to them (with distance). The minimap (top-right) shows pads as squares — gold when open.\n\nOpen pads also shoot a light beam into the sky.",
		},
		{
			"title": "Loot & abilities",
			"icon": "✚",
			"body": "Shoot crates open for scrap and the occasional timed buff (speed, damage, shield, heal).\n\nYour character's ABILITY button is unique — check the character screen for what it does.\n\nRIDE hops on your mount for speed (it burns fuel). Riding into crates smashes them.",
		},
	]
