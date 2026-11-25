class_name ThemeCatalog
extends RefCounted

const STUDIO_START := 16
const PALETTES := [
	[16, 17, 18, 19, 20, 21],
	[16, 17, 18, 19, 21, 1],
	[18, 21, 22, 23, 2, 16],
	[17, 20, 23, 24, 3, 18],
	[16, 18, 19, 21, 4, 22],
]

const MATERIALS := [
	[&"SKIN_CLASSIC", 0],
	[&"SKIN_RAINBOW", 5000],
	[&"SKIN_GALAXY", 20000],
	[&"SKIN_GOLDEN", 50000],
	[&"SKIN_MARBLE", 100000],
	[&"SKIN_CANDY", 1000],
	[&"SKIN_NEON", 3000],
	[&"SKIN_WATERMELON", 8000],
	[&"SKIN_COOKIE", 12000],
	[&"SKIN_CRYSTAL", 25000],
	[&"SKIN_LAVA", 35000],
	[&"SKIN_ICE", 75000],
	[&"SKIN_MINT", 500],
	[&"SKIN_CONFETTI", 1500],
	[&"SKIN_WAFFLE", 4400],
	[&"SKIN_AURORA", 17000],
]
const CUTTERS := [
	[&"STEEL", 0, Color.WHITE],
	[&"ROSE_METAL", 40, Color("#ffb7cc")],
	[&"GOLD_METAL", 120, Color("#ffcf74")],
]
const STYLES := [
	[&"WORKSHOP", 0, Color("#cce9dd")],
	[&"MIDNIGHT", 200, Color("#d9d5f4")],
	[&"SUNSET", 600, Color("#f6d4c0")],
]
const EFFECTS := [
	[&"CLAY_DUST", 0, Color.WHITE],
	[&"STAR_DUST", 15, Color("#ffd572")],
	[&"AURORA_DUST", 65, Color("#a0fff5")],
]
const ACHIEVEMENTS := [
	[&"FIRST_LINES", "lines", 10],
	[&"COMBO_ARTIST", "combo", 5],
	[&"SCULPTOR", "cells", 500],
	[&"WORKSHOP_VETERAN", "games", 20],
]

static func active_palette(run: GameManager, save: SaveManager) -> Array:
	var choice := int(save.setting("material", -1))
	if choice >= 0 and choice < MATERIALS.size() and save.best() >= MATERIALS[choice][1]:
		return [choice]
	return PALETTES[run.tier()]

static func material_at(palette: Array, cell: Vector2i) -> int:
	var index := cell.y * BoardManager.SIZE + cell.x
	var group := floori(float(index) / palette.size())
	var offset := index % palette.size()
	var order := offset if group % 2 == 0 else -offset
	return palette[posmod(order + group * 2 + (group >> 1), palette.size())]

static func unlocked_choice(save: SaveManager, key: String, options: Array, tally: int) -> int:
	var choice := clampi(int(save.setting(key, 0)), 0, options.size() - 1)
	return choice if tally >= options[choice][1] else 0
