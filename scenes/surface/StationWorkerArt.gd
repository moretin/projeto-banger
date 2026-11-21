class_name StationWorkerArt
extends RefCounted
## Draws the workers and revived dinosaurs over a landmark's logical 84 × 64 canvas.

const PACHY: Texture2D = preload("res://assets/sprites/surface/workers/pachycephalosaurus.png")
const BARYONYX: Texture2D = preload("res://assets/sprites/surface/workers/baryonyx.png")
const PTERO: Texture2D = preload("res://assets/sprites/surface/workers/pterodactyl.png")
const TROODON: Texture2D = preload("res://assets/sprites/surface/workers/troodon.png")
const ANKYLO: Texture2D = preload("res://assets/sprites/surface/workers/ankylosaurus.png")
const DILO: Texture2D = preload("res://assets/sprites/surface/workers/dilophosaurus.png")
const RAPTOR: Texture2D = preload("res://assets/sprites/surface/workers/velociraptor.png")
const BRACHIO: Texture2D = preload("res://assets/sprites/surface/workers/brachiosaurus.png")

const TRICERA: Texture2D = preload("res://assets/sprites/triceratops.png")
const TREX: Texture2D = preload("res://assets/sprites/trex.png")
const PTERO_SINGLE: Texture2D = preload("res://assets/sprites/pterodactyl.png")
const COMPY: Texture2D = preload("res://assets/sprites/compsognathus.png")

const CELL: Vector2 = Vector2(112.0, 104.0)
const FOOT_OFFSET: float = 4.0
const MINING: Array[int] = [0, 0, 1, 1, 1, 2, 3, 3, 4, 5, 5, 0]
const FISHING: Array[int] = [0, 0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 0, 0]
const FLIGHT: Array[int] = [0, 0, 1, 2, 2, 3, 1, 4, 4, 5, 5]
const STUDY: Array[int] = [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 0]

const INK: Color = Color("#261820")
const BRASS: Color = Color("#e7ac5b")
const PAPER: Color = Color("#f3d79d")
const TEAL: Color = Color("#97d8c0")
const WOOD_CHIP: Color = Color("#c88a55")
const RESIN_GOLD: Color = Color("#f7b74a")
const BERRY_RED: Color = Color("#f26b7a")
const LEAF_GREEN: Color = Color("#86d46b")
const ICE_CYAN: Color = Color("#9ceeff")
const CRYSTAL_BLUE: Color = Color("#a8c7ff")
const AURORA_MINT: Color = Color("#7ff7da")
const SHADE: Color = Color(0.16, 0.10, 0.13, 0.37)

static var _icons: Dictionary = {}


static func get_icon(station: StringName) -> Texture2D:
	if _icons.has(station):
		return _icons[station] as Texture2D
	var atlas: Texture2D
	var crop: Rect2
	match station:
		&"rubble_forge":
			atlas = PACHY
			crop = Rect2(9, 26, 93, 77)
		&"rubble_nest":
			atlas = BARYONYX
			crop = Rect2(3, 40, 106, 63)
		&"rubble_silo":
			atlas = PTERO
			crop = Rect2(16, 9, 83, 70)
		&"rubble_bunker":
			atlas = TROODON
			crop = Rect2(3, 24, 106, 79)
		&"forest_grove":
			_icons[station] = TRICERA
			return TRICERA
		&"forest_sanctuary":
			var stego_tex: Texture2D = _build_worker_icon(
				PackedStringArray([
					"....OO.OO...",
					"...OAAOAAO..",
					"..OAGGGGGAO.",
					".OOGGLLGGGO.",
					"OGGGGGGGGGGO",
					"OEGGLLLLGGGO",
					"OOGGGGGGGGOO",
					"..OOGGGGO.OO",
					"..OGGOOGGO..",
					"..OGGOOGGO..",
					"..OOOO.OOO..",
					"............",
				]),
				{
					"O": INK,
					"G": Color("#46874d"),
					"L": Color("#75ba65"),
					"A": Color("#edaa48"),
					"E": Color("#fff2b2"),
				},
			)
			_icons[station] = stego_tex
			return stego_tex
		&"snow_glacier":
			var cryo_tex: Texture2D = _build_worker_icon(
				PackedStringArray([
					"..OOOO......",
					".OCCCCO.....",
					".OCBHHCO....",
					".OBBBBBBO...",
					"OBEBLLLLBO..",
					"OBBBBBBBBOO.",
					".OOBBBBLLLBO",
					"...OBBBBBBBO",
					"...OBBBOOBO.",
					"...OBBO.OBO.",
					"...OOO..OOO.",
					"............",
				]),
				{
					"O": INK,
					"B": Color("#4d7ea6"),
					"L": Color("#83c1e3"),
					"C": Color("#9ceeff"),
					"H": Color("#ffd873"),
					"E": Color("#fff6d4"),
				},
			)
			_icons[station] = cryo_tex
			return cryo_tex
		&"snow_observatory":
			var pachy_snow_tex: Texture2D = _build_worker_icon(
				PackedStringArray([
					"....OOOOO...",
					"...OFFFFFO..",
					"..OFSFFFSSO.",
					".OHOSSWSSSO.",
					"OHHSSSSSSSO.",
					"OENSSSSSSSOO",
					".OSSSSSSSSSO",
					"..OSSSSSSSO.",
					"..OSSOOSSO..",
					"..OSSOOSSO..",
					"..OOO..OOO..",
					"............",
				]),
				{
					"O": INK,
					"S": Color("#6f849c"),
					"F": Color("#9bb3cc"),
					"W": Color("#e4f3fc"),
					"H": Color("#e0cca6"),
					"N": Color("#b39978"),
					"E": Color("#ffe99e"),
				},
			)
			_icons[station] = pachy_snow_tex
			return pachy_snow_tex
		_:
			return null
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = atlas
	texture.region = crop
	texture.filter_clip = true
	_icons[station] = texture
	return texture


static func draw(
		canvas: Control,
		station: StringName,
		phase: float,
		equipped: bool,
		revived: bool,
		origin: Vector2,
		factor: float
) -> void:
	if revived:
		_draw_revived(canvas, station, phase, origin, factor)
		return
	match station:
		&"rubble_forge":
			_draw_mining(canvas, phase, equipped, origin, factor)
		&"rubble_nest":
			_draw_fishing(canvas, phase, equipped, origin, factor)
		&"rubble_silo":
			_draw_patrol(canvas, phase, equipped, origin, factor)
		&"rubble_bunker":
			_draw_research(canvas, phase, equipped, origin, factor)
		&"forest_grove":
			_draw_timber_worker(canvas, phase, equipped, origin, factor)
		&"forest_sanctuary":
			_draw_stegosaurus_worker(canvas, phase, equipped, origin, factor)
		&"snow_glacier":
			_draw_cryolophosaurus_worker(canvas, phase, equipped, origin, factor)
		&"snow_observatory":
			_draw_pachyrhinosaurus_worker(canvas, phase, equipped, origin, factor)


static func _draw_mining(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase, 1.44) / 1.44
	var frame: int = _pose(MINING, cycle)
	var recoil: float = 0.0
	if cycle >= 0.22 and cycle < 0.44:
		recoil = ease((cycle - 0.22) / 0.22, 0.7) * 3.0
	elif cycle >= 0.44 and cycle < 0.58:
		recoil = lerpf(3.0, -4.0, (cycle - 0.44) / 0.14)
	elif cycle >= 0.58:
		recoil = -4.0 * (1.0 - cycle) / 0.42
	var foot: Vector2 = Vector2(68.0 + recoil, 57.0).round()
	_shadow(canvas, foot, 19.0)
	_sprite(canvas, PACHY, frame, foot, 36.0, -1.0, origin, factor)
	if cycle >= 0.5 and cycle < 0.76:
		_chips(canvas, Vector2(foot.x - 15.0, 45.0), (cycle - 0.5) / 0.26, PAPER if equipped else BRASS, -1.0)
	if equipped and frame != 3:
		var crest_y: float = foot.y - (24.0 if frame == 1 else 21.0)
		canvas.draw_rect(Rect2(foot.x - 10.0, crest_y, 3.0, 1.0), PAPER)


static func _draw_fishing(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.38, 2.10) / 2.10
	var frame: int = _pose(FISHING, cycle)
	var dip: float = maxf(1.0 - absf(cycle - 0.48) / 0.17, 0.0)
	var foot: Vector2 = Vector2(43.0 + roundf(dip * 2.0), 53.0)
	_shadow(canvas, foot, 16.0)
	_sprite(canvas, BARYONYX, frame, foot, 36.0, 1.0, origin, factor)
	if cycle >= 0.42 and cycle < 0.7:
		_ripples(canvas, Vector2(58.0, 51.0), (cycle - 0.42) / 0.28, TEAL if equipped else Color("#a9cdc1"))


static func _draw_patrol(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var angle: float = phase * 1.60
	var flight_center: Vector2 = Vector2(42.0 + sin(angle) * 21.0, 15.0 + sin(angle * 2.0) * 4.0).round()
	var facing: float = 1.0 if cos(angle) >= 0.0 else -1.0
	var wing_frame: int = _pose(FLIGHT, fposmod(phase, 0.70) / 0.70)
	_shadow(canvas, Vector2(flight_center.x, 56.0), 9.0)
	_sprite(canvas, PTERO, wing_frame, flight_center, 40.0, facing, origin, factor, true)
	var feather_fall: float = fposmod(phase + 0.25, 2.25)
	if feather_fall < 0.83:
		var drift: float = sin(feather_fall * 15.0) * 3.0
		var feather: Vector2 = Vector2(43.0 + drift, 21.0 + feather_fall * 21.0).round()
		var tint: Color = PAPER if equipped else Color("#e4bb84")
		tint.a = 1.0 - feather_fall / 0.83
		canvas.draw_rect(Rect2(feather, Vector2(3.0, 1.0)), tint)
		canvas.draw_rect(Rect2(feather + Vector2(1.0, 1.0), Vector2(2.0, 1.0)), tint)


static func _draw_research(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.9, 2.5) / 2.5
	var frame: int = _pose(STUDY, cycle)
	var foot: Vector2 = Vector2(63.0, 57.0)
	_shadow(canvas, foot, 17.0)
	_sprite(canvas, TROODON, frame, foot, 31.0, 1.0, origin, factor)
	# A pequena bancada mantém o pergaminho ao alcance do bico.
	canvas.draw_rect(Rect2(74.0, 53.0, 2.0, 5.0), Color("#4d3135"))
	canvas.draw_rect(Rect2(71.0, 51.0, 8.0, 2.0), Color("#8c5740"))
	if frame < 3 or frame == 5:
		canvas.draw_rect(Rect2(72.0, 50.0, 5.0, 1.0), PAPER)
	if equipped and cycle >= 0.49 and cycle < 0.72:
		_chips(canvas, Vector2(76.0, 44.0), (cycle - 0.49) / 0.23, TEAL, 1.0)


## Bosque das Sequoias — Tricerátopo madeireiro (empurra e colhe madeira/resina).
static func _draw_timber_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.15, 1.65) / 1.65
	var lunge: float = 0.0
	var pitch: float = 0.0
	if cycle >= 0.20 and cycle < 0.42:
		var t: float = (cycle - 0.20) / 0.22
		lunge = ease(t, 0.7) * 3.0
		pitch = 0.05 * t
	elif cycle >= 0.42 and cycle < 0.56:
		var t: float = (cycle - 0.42) / 0.14
		lunge = lerpf(3.0, -4.5, t)
		pitch = lerpf(0.05, -0.11, t)
	elif cycle >= 0.56:
		var t: float = (cycle - 0.56) / 0.44
		lunge = lerpf(-4.5, 0.0, t)
		pitch = lerpf(-0.11, 0.0, t)
	var foot: Vector2 = Vector2(66.0 + lunge, 56.0).round()
	_shadow(canvas, foot, 19.0)
	_single_sprite(canvas, TRICERA, foot, 24.0, 1.0, pitch, origin, factor, false, Color.WHITE)
	if cycle >= 0.48 and cycle < 0.78:
		var ct: float = (cycle - 0.48) / 0.30
		_chips(canvas, Vector2(foot.x - 12.0, 48.0), ct, RESIN_GOLD if equipped else WOOD_CHIP, -1.0)
	if equipped:
		# Arreio dourado de madeira brilhando no dorso.
		canvas.draw_rect(Rect2(foot.x - 5.0, foot.y - 12.0, 6.0, 2.0), BRASS)
		canvas.draw_rect(Rect2(foot.x - 4.0, foot.y - 13.0, 2.0, 1.0), PAPER)


## Clareira das Samambaias — Estegossauro botânico (custom pixel art com placas douradas).
static func _draw_stegosaurus_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.4, 2.10) / 2.10
	var bob: float = roundf(sin(cycle * TAU) * 1.2)
	var tail_sway: float = sin(cycle * TAU) * 2.5
	var nibble: float = maxf(sin((cycle - 0.35) * PI * 2.5), 0.0) * 2.2
	var foot: Vector2 = Vector2(64.0, 56.0)
	_shadow(canvas, foot, 20.0)

	var body_dark: Color = Color("#2f6339")
	var body_mid: Color = Color("#4a8e50")
	var body_lit: Color = Color("#76ba64")
	var plate_gold: Color = Color("#edaa48")
	var plate_hi: Color = Color("#fff0b5")

	# Cauda articulada com espigões (thagomizer) à direita.
	var tail_tip := Vector2(foot.x + 12.0, foot.y - 7.0 + tail_sway)
	canvas.draw_line(Vector2(foot.x + 5.0, foot.y - 7.0 + bob), tail_tip, INK, 4.0)
	canvas.draw_line(Vector2(foot.x + 5.0, foot.y - 7.0 + bob), tail_tip, body_mid, 2.0)
	canvas.draw_rect(Rect2(tail_tip.x - 1.0, tail_tip.y - 3.0, 1.5, 2.5), PAPER)
	canvas.draw_rect(Rect2(tail_tip.x + 1.0, tail_tip.y - 2.0, 1.5, 2.5), PAPER)

	# Pernas robustas.
	canvas.draw_rect(Rect2(foot.x - 6.0, foot.y - 6.0, 4.0, 6.0), INK)
	canvas.draw_rect(Rect2(foot.x - 5.0, foot.y - 5.0, 2.0, 5.0), body_dark)
	canvas.draw_rect(Rect2(foot.x + 2.0, foot.y - 6.0, 4.0, 6.0), INK)
	canvas.draw_rect(Rect2(foot.x + 3.0, foot.y - 5.0, 2.0, 5.0), body_dark)

	# Placas dorsais características em âmbar-dourado.
	var plates: Array[Vector2] = [
		Vector2(foot.x - 5.0, foot.y - 14.0 + bob),
		Vector2(foot.x - 1.0, foot.y - 16.0 + bob),
		Vector2(foot.x + 3.0, foot.y - 15.0 + bob),
		Vector2(foot.x + 6.5, foot.y - 12.0 + bob),
	]
	for pl: Vector2 in plates:
		canvas.draw_rect(Rect2(pl.x - 1.5, pl.y - 1.0, 4.0, 5.0), INK)
		canvas.draw_rect(Rect2(pl.x - 0.5, pl.y, 2.5, 3.5), plate_gold)
		canvas.draw_rect(Rect2(pl.x - 0.5, pl.y, 1.5, 1.5), plate_hi)

	# Corpo arqueado.
	canvas.draw_rect(Rect2(foot.x - 8.0, foot.y - 12.0 + bob, 16.0, 8.0), INK)
	canvas.draw_rect(Rect2(foot.x - 7.0, foot.y - 11.0 + bob, 14.0, 6.0), body_mid)
	canvas.draw_rect(Rect2(foot.x - 6.0, foot.y - 11.0 + bob, 10.0, 2.5), body_lit)

	# Pescoço e cabeça baixa colhendo frutas à esquerda.
	var head_y: float = foot.y - 9.0 + bob + nibble
	canvas.draw_rect(Rect2(foot.x - 13.0, head_y, 6.0, 5.0), INK)
	canvas.draw_rect(Rect2(foot.x - 12.0, head_y + 1.0, 4.5, 3.0), body_lit)
	canvas.draw_rect(Rect2(foot.x - 11.0, head_y + 1.5, 1.0, 1.0), INK)

	# Cesto botânico no flanco quando equipado.
	if equipped:
		canvas.draw_rect(Rect2(foot.x - 3.0, foot.y - 10.0 + bob, 6.0, 5.0), INK)
		canvas.draw_rect(Rect2(foot.x - 2.0, foot.y - 9.0 + bob, 4.0, 3.0), BRASS)
		canvas.draw_rect(Rect2(foot.x - 1.5, foot.y - 10.5 + bob, 3.0, 1.5), BERRY_RED)

	# Partículas de frutas e esporos verdes na colheita.
	if cycle >= 0.35 and cycle < 0.72:
		var pt: float = (cycle - 0.35) / 0.37
		_chips(canvas, Vector2(foot.x - 13.0, foot.y - 6.0), pt, BERRY_RED, -1.0)
		_chips(canvas, Vector2(foot.x - 10.0, foot.y - 9.0), pt, LEAF_GREEN, -0.5)


## Geleira Cristalina — Criolofossauro polar (terópode emplumado com crista gelada).
static func _draw_cryolophosaurus_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.2, 1.55) / 1.55
	var strike: float = 0.0
	if cycle >= 0.28 and cycle < 0.48:
		strike = ease((cycle - 0.28) / 0.20, 0.5)
	elif cycle >= 0.48 and cycle < 0.66:
		strike = 1.0 - (cycle - 0.48) / 0.18
	var foot: Vector2 = Vector2(65.0 - roundf(strike * 4.0), 56.0)
	_shadow(canvas, foot, 17.0)

	var skin_dark: Color = Color("#315478")
	var skin_mid: Color = Color("#4f84ad")
	var skin_lit: Color = Color("#87c7e8")
	var belly: Color = Color("#d9f4ff")
	var crest_col: Color = Color("#9ceeff")
	var crest_tip: Color = Color("#ffdb75")

	# Cauda longa equilibrando o salto.
	var tail_end := Vector2(foot.x + 13.0, foot.y - 12.0 - strike * 2.5)
	canvas.draw_line(Vector2(foot.x + 3.0, foot.y - 10.0), tail_end, INK, 4.0)
	canvas.draw_line(Vector2(foot.x + 3.0, foot.y - 10.0), tail_end, skin_mid, 2.0)

	# Pernas ágeis + grampos de gelo de latão se equipado.
	canvas.draw_rect(Rect2(foot.x - 3.0, foot.y - 7.0, 3.0, 7.0), INK)
	canvas.draw_rect(Rect2(foot.x - 2.0, foot.y - 6.0, 1.5, 5.5), skin_dark)
	canvas.draw_rect(Rect2(foot.x + 1.0, foot.y - 7.0, 3.0, 7.0), INK)
	canvas.draw_rect(Rect2(foot.x + 2.0, foot.y - 6.0, 1.5, 5.5), skin_mid)
	if equipped:
		canvas.draw_rect(Rect2(foot.x - 3.5, foot.y - 1.5, 4.0, 1.5), BRASS)
		canvas.draw_rect(Rect2(foot.x + 0.5, foot.y - 1.5, 4.0, 1.5), PAPER)

	# Tronco inclinado para frente.
	var body_y: float = foot.y - 14.0 + strike * 1.5
	canvas.draw_rect(Rect2(foot.x - 6.0, body_y, 11.0, 8.0), INK)
	canvas.draw_rect(Rect2(foot.x - 5.0, body_y + 1.0, 9.0, 6.0), skin_mid)
	canvas.draw_rect(Rect2(foot.x - 4.0, body_y + 1.0, 7.0, 2.5), skin_lit)
	canvas.draw_rect(Rect2(foot.x - 4.0, body_y + 4.5, 6.0, 2.0), belly)

	# Cabeça e a icônica crista alta do Criolofossauro.
	var head_x: float = foot.x - 11.0 - strike * 2.5
	var head_y: float = body_y - 4.0 + strike * 3.0
	canvas.draw_rect(Rect2(head_x, head_y, 8.0, 6.0), INK)
	canvas.draw_rect(Rect2(head_x + 1.0, head_y + 1.0, 6.0, 4.0), skin_lit)
	canvas.draw_rect(Rect2(head_x + 2.0, head_y + 2.0, 1.5, 1.5), Color("#fff5b8"))
	# Crista em arco acima dos olhos.
	canvas.draw_rect(Rect2(head_x + 2.0, head_y - 3.5, 5.0, 4.0), INK)
	canvas.draw_rect(Rect2(head_x + 3.0, head_y - 2.5, 3.0, 2.5), crest_col)
	canvas.draw_rect(Rect2(head_x + 3.0, head_y - 3.0, 2.0, 1.2), crest_tip)

	# Lascas cristalinas voando durante a batida no gelo.
	if cycle >= 0.42 and cycle < 0.75:
		var ct: float = (cycle - 0.42) / 0.33
		_chips(canvas, Vector2(head_x - 1.0, head_y + 4.0), ct, ICE_CYAN, -1.0)


## Santuário Ártico — Paquirrinossauro polar (gola nevada + bossa nasal + prisma).
static func _draw_pachyrhinosaurus_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.65, 2.20) / 2.20
	var nudge: float = maxf(sin((cycle - 0.25) * PI * 2.2), 0.0) * 2.5
	var foot: Vector2 = Vector2(64.0 - roundf(nudge), 56.0)
	_shadow(canvas, foot, 20.0)

	var hide_dark: Color = Color("#4b5c73")
	var hide_mid: Color = Color("#6f849e")
	var hide_lit: Color = Color("#9bb3cc")
	var fur_snow: Color = Color("#e3f2fc")
	var boss_ivory: Color = Color("#e6d4b0")

	# Pernas fortes de ceratopsídeo polar.
	canvas.draw_rect(Rect2(foot.x - 6.0, foot.y - 6.0, 4.0, 6.0), INK)
	canvas.draw_rect(Rect2(foot.x - 5.0, foot.y - 5.0, 2.0, 5.0), hide_dark)
	canvas.draw_rect(Rect2(foot.x + 3.0, foot.y - 6.0, 4.0, 6.0), INK)
	canvas.draw_rect(Rect2(foot.x + 4.0, foot.y - 5.0, 2.0, 5.0), hide_dark)

	# Corpo robusto com pelagem nevada nos ombros.
	canvas.draw_rect(Rect2(foot.x - 7.0, foot.y - 13.0, 16.0, 9.0), INK)
	canvas.draw_rect(Rect2(foot.x - 6.0, foot.y - 12.0, 14.0, 7.0), hide_mid)
	canvas.draw_rect(Rect2(foot.x - 5.0, foot.y - 12.0, 10.0, 3.0), hide_lit)
	canvas.draw_rect(Rect2(foot.x - 6.0, foot.y - 13.0, 7.0, 3.0), fur_snow)

	# Gola ornamentada e cabeça com bossa nasal espessa voltada para o observatório.
	canvas.draw_rect(Rect2(foot.x - 11.0, foot.y - 17.0, 7.0, 9.0), INK)
	canvas.draw_rect(Rect2(foot.x - 10.0, foot.y - 16.0, 5.0, 7.0), hide_lit)
	canvas.draw_rect(Rect2(foot.x - 10.0, foot.y - 16.0, 2.0, 2.0), boss_ivory)
	canvas.draw_rect(Rect2(foot.x - 15.0, foot.y - 12.0, 6.0, 6.0), INK)
	canvas.draw_rect(Rect2(foot.x - 14.0, foot.y - 11.0, 4.5, 4.0), hide_mid)
	# Bossa nasal larga característica.
	canvas.draw_rect(Rect2(foot.x - 15.5, foot.y - 13.0, 4.0, 3.0), boss_ivory)
	canvas.draw_rect(Rect2(foot.x - 11.5, foot.y - 10.5, 1.2, 1.2), Color("#ffe99e"))

	# Prisma da aurora montado na gola quando equipado.
	if equipped:
		var pulse_c: float = 0.65 + 0.35 * sin(phase * 4.0)
		canvas.draw_rect(Rect2(foot.x - 9.0, foot.y - 20.0, 3.5, 3.5), Color(AURORA_MINT.r, AURORA_MINT.g, AURORA_MINT.b, pulse_c))
		canvas.draw_rect(Rect2(foot.x - 8.5, foot.y - 19.5, 1.5, 1.5), Color("#ffffff"))

	if cycle >= 0.42 and cycle < 0.74:
		var ct: float = (cycle - 0.42) / 0.32
		_chips(canvas, Vector2(foot.x - 15.0, foot.y - 11.0), ct, AURORA_MINT if equipped else CRYSTAL_BLUE, -1.0)


static func _draw_revived(canvas: Control, station: StringName, phase: float, origin: Vector2, factor: float) -> void:
	match station:
		&"rubble_forge":
			var cycle: float = fposmod(phase + 0.24, 2.13) / 2.13
			var frame: int = 1 if cycle > 0.31 and cycle < 0.60 else 0
			var foot: Vector2 = Vector2(21.0 + roundf(sin(cycle * TAU) * 2.0), 56.0)
			_shadow(canvas, foot, 18.0)
			_sprite(canvas, ANKYLO, frame, foot, 30.0, 1.0, origin, factor)
			if cycle > 0.60 and cycle < 0.85:
				_chips(canvas, Vector2(9.0, 49.0), (cycle - 0.60) / 0.25, BRASS, -1.0)
		&"rubble_nest":
			var cycle: float = fposmod(phase + 0.86, 2.23) / 2.23
			var frame: int = 1 if cycle > 0.42 and cycle < 0.68 else 0
			var foot: Vector2 = Vector2(69.0, 55.0)
			_shadow(canvas, foot, 13.0)
			_sprite(canvas, DILO, frame, foot, 26.0, -1.0, origin, factor)
			if frame == 1:
				_ripples(canvas, Vector2(58.0, 53.0), (cycle - 0.42) / 0.26, TEAL)
		&"rubble_silo":
			var cycle: float = fposmod(phase + 0.51, 1.93) / 1.93
			var hop: float = 0.0
			if cycle > 0.24 and cycle < 0.77:
				hop = sin((cycle - 0.24) / 0.53 * PI) * 10.0
			var foot: Vector2 = Vector2(59.0 + roundf(sin(cycle * TAU) * 5.0), 52.0 - roundf(hop))
			_shadow(canvas, Vector2(foot.x, 54.0), 13.0)
			_sprite(canvas, RAPTOR, 1 if hop > 2.0 else 0, foot, 26.0, -1.0, origin, factor)
		&"rubble_bunker":
			var cycle: float = fposmod(phase + 1.12, 2.90) / 2.90
			var frame: int = 1 if cycle > 0.36 and cycle < 0.72 else 0
			var foot: Vector2 = Vector2(22.0 + roundf(sin(cycle * TAU)), 57.0)
			_shadow(canvas, foot, 19.0)
			_sprite(canvas, BRACHIO, frame, foot, 34.0, 1.0, origin, factor)
		&"forest_grove":
			# Tricerátopo Alfa guardando a serraria e gerando Resina dourada.
			var cycle: float = fposmod(phase + 0.55, 2.35) / 2.35
			var sway: float = roundf(sin(cycle * TAU) * 2.0)
			var foot: Vector2 = Vector2(21.0 + sway, 56.0)
			_shadow(canvas, foot, 21.0)
			_single_sprite(canvas, TRICERA, foot, 27.0, -1.0, sin(cycle * TAU) * 0.04, origin, factor, false, Color(1.06, 0.96, 0.82))
			if cycle > 0.45 and cycle < 0.80:
				_chips(canvas, Vector2(foot.x + 11.0, 46.0), (cycle - 0.45) / 0.35, RESIN_GOLD, 1.0)
		&"forest_sanctuary":
			# T-Rex Guardião patrulhando a Clareira das Samambaias.
			var cycle: float = fposmod(phase + 0.30, 2.40) / 2.40
			var roar: float = sin((cycle - 0.35) / 0.35 * PI) if (cycle > 0.35 and cycle < 0.70) else 0.0
			var foot: Vector2 = Vector2(21.0 + roundf(sin(cycle * TAU) * 1.5), 56.0 - roundf(roar * 2.0))
			_shadow(canvas, Vector2(foot.x, 56.0), 20.0)
			_single_sprite(canvas, TREX, foot, 26.0, -1.0, -roar * 0.12, origin, factor, false, Color(1.02, 1.05, 0.95))
			if roar > 0.15:
				_chips(canvas, Vector2(foot.x + 10.0, 38.0), clampf(roar, 0.0, 1.0), LEAF_GREEN, 1.0)
		&"snow_glacier":
			# Pterodáctilo Polar planando acima da Geleira Cristalina.
			var angle: float = phase * 1.50
			var center: Vector2 = Vector2(42.0 + sin(angle) * 22.0, 14.0 + sin(angle * 2.0) * 4.0).round()
			var facing: float = 1.0 if cos(angle) >= 0.0 else -1.0
			var bank: float = sin(phase * 7.5) * 0.10
			_shadow(canvas, Vector2(center.x, 56.0), 10.0)
			_single_sprite(canvas, PTERO_SINGLE, center, 26.0, facing, bank, origin, factor, true, Color(0.76, 0.94, 1.0))
			var drop_t: float = fposmod(phase + 0.4, 1.8) / 1.8
			if drop_t < 0.55:
				_chips(canvas, Vector2(center.x, center.y + 6.0), drop_t / 0.55, ICE_CYAN, facing)
		&"snow_observatory":
			# Compsognato Ártico examinando cristais da aurora junto ao observatório.
			var cycle: float = fposmod(phase + 0.72, 1.85) / 1.85
			var hop: float = sin((cycle - 0.25) / 0.45 * PI) * 5.0 if (cycle > 0.25 and cycle < 0.70) else 0.0
			var foot: Vector2 = Vector2(21.0 + roundf(sin(cycle * TAU) * 3.0), 56.0 - roundf(hop))
			_shadow(canvas, Vector2(foot.x, 56.0), 14.0)
			_single_sprite(canvas, COMPY, foot, 24.0, 1.0, -hop * 0.02, origin, factor, false, Color(0.84, 0.97, 1.0))
			if cycle > 0.40 and cycle < 0.78:
				_chips(canvas, Vector2(foot.x + 8.0, 47.0), (cycle - 0.40) / 0.38, AURORA_MINT, 1.0)


static func _pose(sequence: Array[int], cycle: float) -> int:
	return sequence[mini(floori(cycle * sequence.size()), sequence.size() - 1)]


static func _sprite(
		canvas: Control,
		sheet: Texture2D,
		frame: int,
		anchor: Vector2,
		width: float,
		direction: float,
		origin: Vector2,
		factor: float,
		airborne: bool = false
) -> void:
	var height: float = width * CELL.y / CELL.x
	var top: float = -height * 0.5 if airborne else -height + FOOT_OFFSET * width / CELL.x
	var source: Rect2 = Rect2(Vector2(frame % 3, floori(float(frame) / 3.0)) * CELL, CELL)
	canvas.draw_set_transform(origin + anchor * factor, 0.0, Vector2(direction, 1.0) * factor)
	canvas.draw_texture_rect_region(sheet, Rect2(-width * 0.5, top, width, height), source)
	canvas.draw_set_transform(origin, 0.0, Vector2.ONE * factor)


static func _single_sprite(
		canvas: Control,
		tex: Texture2D,
		anchor: Vector2,
		width: float,
		direction: float,
		rot: float,
		origin: Vector2,
		factor: float,
		airborne: bool,
		tint: Color
) -> void:
	if tex == null:
		return
	var tex_sz: Vector2 = tex.get_size()
	var height: float = width * (tex_sz.y / maxf(tex_sz.x, 1.0))
	var top: float = -height * 0.5 if airborne else -height
	canvas.draw_set_transform(origin + anchor * factor, rot, Vector2(direction, 1.0) * factor)
	canvas.draw_texture_rect(tex, Rect2(-width * 0.5, top, width, height), false, tint)
	canvas.draw_set_transform(origin, 0.0, Vector2.ONE * factor)


static func _build_worker_icon(rows: PackedStringArray, palette: Dictionary) -> ImageTexture:
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in range(mini(rows.size(), 12)):
		var row: String = rows[y]
		for x: int in range(mini(row.length(), 12)):
			var ch: String = row.substr(x, 1)
			if not palette.has(ch):
				continue
			var col: Color = palette[ch] as Color
			var px: int = x * 2
			var py: int = y * 2
			img.set_pixel(px, py, col)
			img.set_pixel(px + 1, py, col)
			img.set_pixel(px, py + 1, col)
			img.set_pixel(px + 1, py + 1, col)
	return ImageTexture.create_from_image(img)


static func _shadow(canvas: Control, contact: Vector2, width: float) -> void:
	canvas.draw_rect(Rect2(contact.x - width * 0.5, contact.y - 0.5, width, 1.5), SHADE)


static func _chips(canvas: Control, contact: Vector2, t: float, tint: Color, direction: float) -> void:
	var fading: Color = Color(tint.r, tint.g, tint.b, 1.0 - t)
	for i: int in range(3):
		var offset: Vector2 = Vector2((2.0 + float(i) * 2.0) * t * direction, -float(i + 1) * t * 2.6)
		canvas.draw_rect(Rect2((contact + offset).round(), Vector2(1.0, 1.0)), fading)


static func _ripples(canvas: Control, center: Vector2, t: float, tint: Color) -> void:
	var span: float = roundf(2.0 + t * 5.0)
	var fading: Color = Color(tint.r, tint.g, tint.b, (1.0 - t) * 0.84)
	canvas.draw_rect(Rect2(center.x - span, center.y + 1.0, span * 2.0, 1.0), fading)
	canvas.draw_rect(Rect2(center.x + 2.0, center.y - 1.0 - roundf(sin(t * PI) * 3.0), 1.0, 1.0), fading)
