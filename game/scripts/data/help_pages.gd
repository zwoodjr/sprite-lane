class_name HelpPages
extends RefCounted

## Plain-language "How to play" content. Shared by the How to Play screen
## and the pause menu. Keep each page short — it's read on a phone.
## "art": a texture path, "strip:<path>" (animated strip), or hero / pet / ability.

static func pages() -> Array[Dictionary]:
	return [
		{
			"title": "The idea",
			"icon": "◎",
			"art": "res://assets/sprites/pickups/supply_crate.png",
			"body": "You drop into an endless dust wasteland. Fight, loot crates, and get OUT through an extract pad.\n\nMake it out → bank scrap and spend it in the Hangar.\nGo down → lose bag loot; banked scrap and Hangar upgrades stay.\n\nDuring a run you also level up for temporary loadout picks — those reset every deploy.",
		},
		{
			"title": "Moving & shooting",
			"icon": "✥",
			"art": "hero",
			"body": "Drag anywhere on the left side of the screen to MOVE — the stick appears under your thumb.\n\nAttacks are automatic: your hero fires (or swings) at the closest enemy inside weapon range. Gunners reach far; melee heroes need to get close.\n\nRight thumb: DASH (big) and your hero ABILITY.",
		},
		{
			"title": "Dash",
			"icon": "»",
			"art": "res://assets/sprites/ui/btn_dash.png",
			"body": "Tap DASH to burst in the direction you're moving.\n\nYou're invincible for a split second — dash THROUGH red bullets and charging enemies.\n\nThe ring on the button shows the cooldown.",
		},
		{
			"title": "Read the enemy",
			"icon": "!",
			"art": "strip:res://assets/sprites/enemies/scav_bear/scav_bear_idle.png",
			"body": "A red wedge appears before every attack. That's your cue to move or dash.\n\nRaiders shoot from range. Chargers (orange) rush you and lunge. Brutes (blue, big) are slow tanks that fire spreads.",
		},
		{
			"title": "The clock",
			"icon": "◷",
			"art": "res://assets/sprites/props/extract_sealed.png",
			"body": "Every run has phases shown at the top:\n\nLOCKOUT — extracts are sealed. Survive and loot.\nEXTRACT OPEN — pads light up gold. Stand on one to leave.\nSEALED — window closed; another opens later.\nLAST EXTRACT — final chance. Miss it and you're wiped.",
		},
		{
			"title": "Threat & greed",
			"icon": "▲",
			"art": "res://assets/sprites/pickups/dust_heart.png",
			"body": "Every extract window you skip raises THREAT by 1.\n\nHigher Threat = tougher, more frequent enemies… and a much bigger payout (up to ×2.25).\n\nStaying near an open window also builds your Stay bonus. Leave early and safe, or stay and get rich.",
		},
		{
			"title": "Finding the way out",
			"icon": "➤",
			"art": "res://assets/sprites/props/extract_open.png",
			"body": "Pads move every run.\n\nGold arrows on the screen edge point to them (with distance). The minimap (top-right) shows pads as squares — gold when open.\n\nOpen pads also shoot a light beam into the sky.",
		},
		{
			"title": "Loot & abilities",
			"icon": "✚",
			"art": "ability",
			"body": "Shoot crates open — many are empty, some drop lean scrap, a few (~2/10) drop timed buffs (speed, damage, shield, heal).\n\nYour character's ABILITY button is unique — check the character screen for what it does.",
		},
		{
			"title": "Your pet",
			"icon": "🐾",
			"art": "pet",
			"body": "Equip a pet on the character screen (default: Noel).\n\nNoel — territorial: when you're hit, she AOE-rampages until THAT attacker dies.\nBentley — bark distracts foes; periodically finds scrap/crates/pickups.\nLillie — tank ram: charge with wake damage, then AOE on impact.",
		},
		{
			"title": "Two progress tracks",
			"icon": "◆",
			"art": "res://assets/sprites/pickups/salvage_core.png",
			"body": "IN-RUN: kills and staying near open extracts fill your RUN level bar. Each level lets you pick a temporary boost (damage, HP, speed…). Gone when the run ends.\n\nMETA: extracted scrap banks permanently. Spend it in the Hangar for HP, endurance, scrap find, loot quality, damage, crits, AoE, dodge/block, speed, pickup reach, pet power, dash, extract grace, and payout. Account level soft-gates higher tiers. (Loadout insurance UI comes later — no fake insurance buy in the Hangar yet.)",
		},
	]
