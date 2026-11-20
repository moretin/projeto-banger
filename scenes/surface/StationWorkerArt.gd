class_name StationWorkerArt
extends RefCounted
## Draws the workers over a landmark's logical 84 × 64 canvas. The cycle is visual.

const PACHY: Texture2D = preload("res://assets/sprites/surface/workers/pachycephalosaurus.png")
const BARYONYX: Texture2D = preload("res://assets/sprites/surface/workers/baryonyx.png")
const PTERO: Texture2D = preload("res://assets/sprites/surface/workers/pterodactyl.png")
const TROODON: Texture2D = preload("res://assets/sprites/surface/workers/troodon.png")
const ANKYLO: Texture2D = preload("res://assets/sprites/surface/workers/ankylosaurus.png")
const DILO: Texture2D = preload("res://assets/sprites/surface/workers/dilophosaurus.png")
const RAPTOR: Texture2D = preload("res://assets/sprites/surface/workers/velociraptor.png")
const BRACHIO: Texture2D = preload("res://assets/sprites/surface/workers/brachiosaurus.png")

const CELL: Vector2 = Vector2(112.0, 104.0)
const FOOT_OFFSET: float = 4.0
const MINING: Array[int] = [0, 0, 1, 1, 1, 2, 3, 3, 4, 5, 5, 0]
const FISHING: Array[int] = [0, 0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 0, 0]
const FLIGHT: Array[int] = [0, 0, 1, 2, 2, 3, 1, 4, 4, 5, 5]
const STUDY: Array[int] = [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 0]
const BRASS: Color = Color("#e7ac5b")
const PAPER: Color = Color("#f3d79d")
const TEAL: Color = Color("#97d8c0")
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
