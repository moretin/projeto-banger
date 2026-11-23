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
const TRICERA_WORKER: Texture2D = preload("res://assets/sprites/surface/workers/triceratops.png")
const STEGO: Texture2D = preload("res://assets/sprites/surface/workers/stegosaurus.png")
const CRYO: Texture2D = preload("res://assets/sprites/surface/workers/cryolophosaurus.png")
const PACHYRHINO: Texture2D = preload("res://assets/sprites/surface/workers/pachyrhinosaurus.png")

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
const GATHER: Array[int] = [0, 0, 1, 1, 2, 2, 2, 3, 3, 0]
const WORKER_ICON: Rect2 = Rect2(2.0, 26.0, 108.0, 75.0)

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
const METAL_MID: Color = Color("#7d92a6")
const METAL_GLINT: Color = Color("#d7e8f5")
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
			atlas = TRICERA_WORKER
			crop = WORKER_ICON
		&"forest_sanctuary":
			atlas = STEGO
			crop = WORKER_ICON
		&"snow_glacier":
			atlas = CRYO
			crop = WORKER_ICON
		&"snow_observatory":
			atlas = PACHYRHINO
			crop = WORKER_ICON
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


## Bosque das Sequoias — arrasta toras e solta lascas e resina.
static func _draw_timber_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.15, 1.65) / 1.65
	var frame: int = _pose(GATHER, cycle)
	var lunge: float = sin((cycle - 0.20) * PI / 0.51) * 3.0 if cycle > 0.20 and cycle < 0.71 else 0.0
	var foot: Vector2 = Vector2(66.0 - roundf(lunge), 57.0)
	_shadow(canvas, foot, 19.0)
	_sprite(canvas, TRICERA_WORKER, frame, foot, 34.0, -1.0, origin, factor)
	if cycle >= 0.43 and cycle < 0.76:
		_chips(canvas, foot + Vector2(-16.0, -4.0), (cycle - 0.43) / 0.33, RESIN_GOLD if equipped else WOOD_CHIP, -1.0)
	if equipped:
		canvas.draw_rect(Rect2(foot + Vector2(4.0, -13.0), Vector2(3.0, 1.5)), BRASS)


## Clareira das Samambaias — baixa o focinho para colher frutas.
static func _draw_stegosaurus_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.4, 2.1) / 2.1
	var frame: int = _pose(GATHER, cycle)
	var foot: Vector2 = Vector2(63.0, 57.0)
	_shadow(canvas, foot, 20.0)
	_sprite(canvas, STEGO, frame, foot, 36.0, -1.0, origin, factor)
	if equipped:
		canvas.draw_rect(Rect2(foot + Vector2(1.0, -9.0), Vector2(3.0, 2.0)), BRASS)
	if cycle >= 0.40 and cycle < 0.72:
		_chips(canvas, foot + Vector2(-17.0, -5.0), (cycle - 0.40) / 0.32, BERRY_RED, -1.0)


## Geleira Cristalina — ergue a crista e golpeia o gelo.
static func _draw_cryolophosaurus_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.2, 1.55) / 1.55
	var frame: int = _pose(GATHER, cycle)
	var foot: Vector2 = Vector2(65.0 - (2.0 if frame == 2 else 0.0), 57.0)
	_shadow(canvas, foot, 17.0)
	_sprite(canvas, CRYO, frame, foot, 36.0, -1.0, origin, factor)
	if equipped:
		canvas.draw_rect(Rect2(foot + Vector2(-4.0, -0.5), Vector2(3.0, 1.0)), BRASS)
	if cycle >= 0.40 and cycle < 0.74:
		_chips(canvas, foot + Vector2(-15.0, -3.0), (cycle - 0.40) / 0.34, ICE_CYAN, -1.0)


## Santuário Ártico — lapida cristais com a bossa nasal.
static func _draw_pachyrhinosaurus_worker(canvas: Control, phase: float, equipped: bool, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.65, 2.20) / 2.20
	var frame: int = _pose(GATHER, cycle)
	var foot: Vector2 = Vector2(64.0 - (2.0 if frame == 2 else 0.0), 57.0)
	_shadow(canvas, foot, 20.0)
	_sprite(canvas, PACHYRHINO, frame, foot, 34.0, -1.0, origin, factor)
	if equipped:
		var prism_y: float = -11.0 if frame == 2 else -16.0
		canvas.draw_rect(Rect2(foot + Vector2(-7.0, prism_y), Vector2(2.0, 2.0)), AURORA_MINT)
	if cycle >= 0.40 and cycle < 0.74:
		_chips(canvas, foot + Vector2(-15.0, -4.0), (cycle - 0.40) / 0.34, AURORA_MINT if equipped else CRYSTAL_BLUE, -1.0)


## Desenha o Anquilossauro resgatado em vigília junto ao Ovo de Âmbar pós-impacto.
static func draw_ankylo_companion_by_egg(canvas: CanvasItem, phase: float, origin: Vector2, factor: float) -> void:
	var cycle: float = fposmod(phase + 0.18, 2.50) / 2.50
	var tail_up: bool = cycle > 0.56 and cycle < 0.80
	var frame: int = 1 if tail_up else 0
	var shift_x: float = roundf(sin(cycle * TAU) * 1.0)
	var foot: Vector2 = Vector2(19.0 + shift_x, 56.0)
	_shadow(canvas, foot, 17.0)
	_sprite(canvas, ANKYLO, frame, foot, 28.0, 1.0, origin, factor)
	if tail_up:
		var pulse_a: float = sin(((cycle - 0.56) / 0.24) * PI) * 0.85
		var glint_pos: Vector2 = Vector2(foot.x + 8.0, 38.0)
		var glint_col: Color = Color(1.0, 0.91, 0.56, pulse_a)
		canvas.draw_rect(Rect2(glint_pos.x - 1.5, glint_pos.y, 4.0, 1.0), glint_col)
		canvas.draw_rect(Rect2(glint_pos.x, glint_pos.y - 1.5, 1.0, 4.0), glint_col)
	elif cycle >= 0.80 and cycle < 0.95:
		_chips(canvas, Vector2(foot.x - 9.0, 54.0), (cycle - 0.80) / 0.15, BRASS, -1.0)


static func _draw_revived(canvas: CanvasItem, station: StringName, phase: float, origin: Vector2, factor: float) -> void:
	match station:
		&"rubble_forge":
			var cycle: float = fposmod(phase + 0.24, 2.13) / 2.13
			var frame: int = 1 if cycle > 0.31 and cycle < 0.60 else 0
			var foot: Vector2 = Vector2(21.0 + roundf(sin(cycle * TAU) * 2.0), 56.0)
			_shadow(canvas, foot, 18.0)
			_sprite(canvas, ANKYLO, frame, foot, 30.0, 1.0, origin, factor)
			if cycle > 0.53 and cycle <= 0.61:
				var swoop_a: float = 0.55 * sin(((cycle - 0.53) / 0.08) * PI)
				canvas.draw_line(Vector2(10.0, 38.0), Vector2(8.0, 47.0), Color(METAL_GLINT.r, METAL_GLINT.g, METAL_GLINT.b, swoop_a), 1.5)
			if cycle >= 0.59 and cycle < 0.86:
				var spark_t: float = (cycle - 0.59) / 0.27
				var vein_hit: Vector2 = Vector2(9.0, 48.0)
				if spark_t < 0.50:
					var flash_a: float = 1.0 - (spark_t / 0.50)
					var glint_col: Color = Color(METAL_GLINT.r, METAL_GLINT.g, METAL_GLINT.b, flash_a)
					var core_col: Color = Color(1.0, 0.93, 0.62, flash_a)
					var r: float = 1.5 + spark_t * 6.0
					canvas.draw_rect(Rect2(vein_hit.x - r, vein_hit.y, r * 2.0, 1.0), glint_col)
					canvas.draw_rect(Rect2(vein_hit.x, vein_hit.y - r, 1.0, r * 2.0), glint_col)
					canvas.draw_rect(Rect2(vein_hit.x - 1.5, vein_hit.y - 1.5, 3.0, 3.0), core_col)
				_chips(canvas, vein_hit, spark_t, METAL_GLINT, -1.0)
				_chips(canvas, Vector2(10.0, 47.0), spark_t * 0.9, BRASS, -0.6)
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
		canvas: CanvasItem,
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
		canvas: CanvasItem,
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


static func _shadow(canvas: CanvasItem, contact: Vector2, width: float) -> void:
	canvas.draw_rect(Rect2(contact.x - width * 0.5, contact.y - 0.5, width, 1.5), SHADE)


static func _chips(canvas: CanvasItem, contact: Vector2, t: float, tint: Color, direction: float) -> void:
	var fading: Color = Color(tint.r, tint.g, tint.b, 1.0 - t)
	for i: int in range(3):
		var offset: Vector2 = Vector2((2.0 + float(i) * 2.0) * t * direction, -float(i + 1) * t * 2.6)
		canvas.draw_rect(Rect2((contact + offset).round(), Vector2(1.0, 1.0)), fading)


static func _ripples(canvas: CanvasItem, center: Vector2, t: float, tint: Color) -> void:
	var span: float = roundf(2.0 + t * 5.0)
	var fading: Color = Color(tint.r, tint.g, tint.b, (1.0 - t) * 0.84)
	canvas.draw_rect(Rect2(center.x - span, center.y + 1.0, span * 2.0, 1.0), fading)
	canvas.draw_rect(Rect2(center.x + 2.0, center.y - 1.0 - roundf(sin(t * PI) * 3.0), 1.0, 1.0), fading)
