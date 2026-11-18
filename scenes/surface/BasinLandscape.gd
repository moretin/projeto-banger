extends Control
## Atlas desenhado em coordenadas de pixel. Os marcos usam as mesmas cotas do terreno.

const INK: Color = Color("#262638")
const CLAY: Color = Color("#ad6654")
const DUNE: Color = Color("#d39169")
const SAND: Color = Color("#e8b580")


func _ready() -> void:
	Events.danger_level_changed.connect(_on_danger_changed)


func _on_danger_changed(_danger: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(480, 240))
	var danger: float = GameState.danger_level
	draw_rect(Rect2(0, 0, 480, 240), Color("#a6cebf").lerp(Color("#db947c"), danger))
	draw_rect(Rect2(0, 40, 480, 33), Color("#c5dac0").lerp(Color("#e6b08c"), danger))
	draw_rect(Rect2(0, 72, 480, 43), Color("#e4ddae").lerp(Color("#efc49b"), danger))
	# Disco solar com as bordas escalonadas e nuvens baixas.
	draw_rect(Rect2(302, 18, 20, 28), Color("#fff0bd"))
	draw_rect(Rect2(298, 22, 28, 20), Color("#fff0bd"))
	for i: int in range(9):
		var x: int = (i * 83 + 31) % 490
		var y: int = 16 + (i * 37) % 48
		draw_rect(Rect2(x, y, 22 + i % 4 * 6, 2), Color("#e6e9cc"))
		draw_rect(Rect2(x + 8, y - 2, 13, 2), Color("#e6e9cc"))
	_ridge(PackedVector2Array([Vector2(0,80),Vector2(38,68),Vector2(54,68),Vector2(75,83),Vector2(111,62),Vector2(136,62),Vector2(159,88),Vector2(216,70),Vector2(232,54),Vector2(253,54),Vector2(272,76),Vector2(335,91),Vector2(375,59),Vector2(406,59),Vector2(436,80),Vector2(480,62)]), Color("#92aaa0"))
	_ridge(PackedVector2Array([Vector2(0,100),Vector2(24,90),Vector2(52,91),Vector2(76,110),Vector2(123,90),Vector2(145,92),Vector2(166,104),Vector2(208,86),Vector2(247,86),Vector2(274,96),Vector2(298,88),Vector2(320,88),Vector2(349,105),Vector2(391,92),Vector2(427,99),Vector2(451,84),Vector2(480,84)]), Color("#628b81"))
	for i: int in range(70):
		var x: int = (i * 61) % 480
		var y: int = 104 + (i * 23) % 16
		draw_rect(Rect2(x, y-6, 2, 8), Color("#56796d"))
		draw_rect(Rect2(x-3, y-7, 8, 3), Color("#56796d"))
	_ridge(PackedVector2Array([Vector2(0,104),Vector2(40,110),Vector2(91,117),Vector2(133,137),Vector2(184,131),Vector2(226,109),Vector2(267,113),Vector2(308,101),Vector2(336,105),Vector2(363,125),Vector2(407,117),Vector2(444,114),Vector2(480,126)]), Color("#759178"))
	_ridge(PackedVector2Array([Vector2(0,129),Vector2(43,120),Vector2(77,121),Vector2(111,145),Vector2(146,161),Vector2(186,157),Vector2(225,132),Vector2(250,130),Vector2(290,115),Vector2(333,114),Vector2(362,138),Vector2(405,139),Vector2(448,133),Vector2(480,142)]), SAND)
	# Trilha clara de sedimento liga as quatro bancadas e o ninho central.
	var trail: PackedVector2Array = PackedVector2Array([Vector2(0,141),Vector2(60,132),Vector2(102,151),Vector2(163,175),Vector2(209,160),Vector2(236,137),Vector2(270,136),Vector2(316,120),Vector2(355,139),Vector2(407,152),Vector2(480,146)])
	draw_polyline(trail, Color("#ca8c68"), 5)
	draw_polyline(trail, Color("#f5cd90"), 2)
	for i: int in range(150):
		var x: int = (i * 113) % 479
		var y: int = 172 + (i * 31) % 32
		draw_rect(Rect2(x, y, 1 + i % 4, 1), DUNE)
	var lip: PackedVector2Array = PackedVector2Array([Vector2(0,177),Vector2(45,180),Vector2(80,177),Vector2(105,180),Vector2(140,193),Vector2(176,193),Vector2(210,182),Vector2(254,183),Vector2(290,173),Vector2(323,172),Vector2(359,183),Vector2(400,181),Vector2(445,187),Vector2(480,182)])
	for band: int in range(4):
		var color: Color = [CLAY, Color("#864d4a"), Color("#5b3e45"), INK][band]
		_ridge(lip, color)
		for j: int in range(lip.size()):
			lip[j].y += 6 + (j + band) % 5
	for i: int in range(39):
		var x: int = (i * 131) % 478
		var y: int = 211 + (i * 19) % 27
		draw_rect(Rect2(x, y, 2 + i % 6, 1), Color("#57424b"))
	# Uma coluna vertebral embutida na parede da cratera.
	for i: int in range(11):
		var y: float = 202 + roundf(sin(float(i) * 0.30) * 3)
		draw_rect(Rect2(64 + i * 3, y, 2, 2), Color("#d3a782"))
		if i % 2 == 0:
			draw_rect(Rect2(64 + i * 3, y + 2, 1, 4), Color("#b88870"))


func _ridge(top: PackedVector2Array, color: Color) -> void:
	top.append(Vector2(480, 240))
	top.append(Vector2(0, 240))
	draw_colored_polygon(top, color)
