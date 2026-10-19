class_name BestiaryDefs
extends RefCounted

## Depth Update E3 — Quill's Field Notes. Every kill of a monster counts toward
## its entry (kept across runs): enough kills unlock the lore page, then the
## weak spot (+damage against it), then mastery (+more). Hidden lore pages turn
## up in the world; found pages are kept straight away.

## Kills needed for: entry (lore), weak spot, mastery.
const THRESHOLDS: Array = [10, 40, 120]
## Damage bonus against that kind at stage 0..3.
const DAMAGE: Array = [0.0, 0.0, 0.10, 0.20]
const STAGE_NAME: Array = ["Unknown", "Studied", "Weak spot found", "Mastered"]

## Quill's notes (lore) and the weak spot she found.
const NOTES := {
	"rad_gator": ["Swamp gators that crawled out of the flooded refinery. The plague made them hungry, not fast.", "Soft belly behind the forelegs."],
	"toxic_scorp": ["Scorpions the size of dogs. The tail venom is the plague itself, concentrated.", "Cut the tail joint mid-lunge."],
	"glow_moth": ["They glow because they're rotting. The light draws more of them.", "Wings tear easily — fire spreads fast."],
	"scrap_hound": ["War dogs, rebuilt by whatever still runs the factories. They still hunt in packs.", "The power cell sits behind the jaw."],
	"dune_stalker": ["Something that used to be a man. Keeps its distance, waits for you to tire.", "It never guards its left side."],
	"coil_spider": ["Mine-laying drones that learned to walk. Their legs spark when they lunge.", "Shock fries the leg servos."],
	"rad_bat": ["Plague bats. Their screech carries for a mile.", "One hit drops them. Don't miss."],
	"iron_horse": ["A cavalry walker from the war, still charging enemies that died years ago.", "It can't turn mid-charge."],
	"chimera_rat": ["Three rats grown into one. The plague does that when it's bored.", "Each head feels the others' pain."],
	"muck_golem": ["Sludge from the plague pits, walking. Slow, but it doesn't stop.", "Burn it — the muck dries and cracks."],
	"scav_bear_cub": ["A cub already sick. It will be a Scav-Bear by winter.", "Still small. Still soft."],
	"ash_singer": ["It hums. We don't know why. Rook says it's mourning.", "Its throat sac bursts if you hit it hard."],
	"scav_bear": ["Bears that ate plague corpses for a whole winter. Now they eat anything.", "The hide is thin over the spine."],
	"dune_serpent": ["They swim through sand. You feel them before you see them.", "Hit it the moment it surfaces."],
	"fusion_golem": ["A reactor walker. It doesn't know the war ended.", "The core vents overheat — shock it while it cools."],
	"scorpion_king": ["The old queen of the scorps. Her brood follows her.", "The crown plates crack under fire."],
	"dread_naught": ["The war's last siege engine. Infected now, but it still follows orders.", "Its turrets can't track close targets."],
	"glow_moth_queen": ["Lays her eggs in the dead. Every light in the Dust might be one of hers.", "Her wings burn like paper."],
	"mech_wyrm": ["Tunnel borers from the mines, now coiled and furious.", "Shock the joint segments."],
	"mech_wyrm_b": ["The armoured wyrm. Slower, meaner.", "Its plates leave the underbelly bare."],
	"geist_alpha": ["Leads the stalkers. The others go quiet when it moves.", "Kill it first; the rest scatter."],
	"ash_wraiths": ["People who stayed in the city when the Dust came. They didn't leave.", "They can't stand bright fire."],
	"mutant_overlord": ["A war machine with the plague grown all through it. Half flesh, half steel, all angry.", "Fire for the flesh, shock for the steel."],
	"cyber_juggernaut": ["Front-line breach walkers. They carry the best salvage in the Dust.", "The shield only covers the front."],
	"void_spider": ["Nobody who saw one up close came back with notes. These are mine.", "It flinches from light."],
	"wasteland_god_entity": ["The raiders pray to it. I'd rather dissect it.", "Every eye is a weak spot. There are many."],
	"apocalypse_wraith": ["The Dust given a shape. Cinder won't talk about it.", "It comes back once. Finish it."],
	"raider_grunt": ["War deserters. They kept the guns and lost the reasons.", "Gas masks crack — aim high."],
	"raider_brute": ["The muscle of a raider crew. Welding masks, scrap mauls, no mercy.", "Slow to turn after a swing."],
	"raider_captain": ["Crew leader. Keeps the medicine bag on her own back.", "Kill her and the bag drops."],
	"dust_warden": ["What guards the pads at the end. A war machine the plague made into something holy.", "The plague core opens when it vents."],
}

## Hidden lore pages (found in runs, kept at once).
const PAGES: Array = [
	{"id": "p_first", "title": "Before the Dust", "text": "There were trains. Real ones. I remember the sound more than the city."},
	{"id": "p_plague", "title": "The First Cough", "text": "It started in the river towns. By the time the cities closed their gates, it was already inside."},
	{"id": "p_war", "title": "Scarce", "text": "When the medicine ran short the governments stopped talking. Then they stopped pretending."},
	{"id": "p_machines", "title": "Standing Orders", "text": "The war machines were told to hold the line. Nobody ever told them it was over."},
	{"id": "p_dust", "title": "The Dust", "text": "Ash from the burned cities, plague spores, and something else. It glows amber at night."},
	{"id": "p_cathedral", "title": "Cinder's Choice", "text": "Raiders came for the cathedral's medicine. She gave them fire instead."},
	{"id": "p_hangar", "title": "Crash Site", "text": "Helm's plane went down beside an empty hangar. She calls it luck. We call it home."},
	{"id": "p_raiders", "title": "The Crews", "text": "Raiders aren't monsters. They're what's left of armies that never got paid."},
	{"id": "p_quill", "title": "Specimen 41", "text": "The plague rewrites flesh the way rust rewrites iron. Slowly, then completely. — Q.M."},
	{"id": "p_bell", "title": "The Bell Tower", "text": "Rook found her starving, still watching the road through a scope with no bullets."},
	{"id": "p_wardens", "title": "Wardens", "text": "Something gathers at the landing pads when the windows close. It waits for whoever's late."},
	{"id": "p_origin", "title": "Where It Began", "text": "Every map we find marks the same place in the deep Dust. Nobody who went there came back."},
]
## Chance a run hides a page (if any are left), and how far out.
const PAGE_CHANCE := 0.55
const PAGE_DIST := Vector2(700.0, 1400.0)
const PAGE_ICON := "res://assets/sprites/depth/icons/lore_page.png"


static func stage_for(kills: int) -> int:
	var s := 0
	for t in THRESHOLDS:
		if kills >= int(t):
			s += 1
	return s


static func damage_bonus(kills: int) -> float:
	return float(DAMAGE[stage_for(kills)])


static func next_threshold(kills: int) -> int:
	for t in THRESHOLDS:
		if kills < int(t):
			return int(t)
	return -1


static func page(id: String) -> Dictionary:
	for p in PAGES:
		if str(p["id"]) == id:
			return p
	return {}
