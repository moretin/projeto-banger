extends SceneTree
## Teste headless de layout e foco da UI [B2] em múltiplas resoluções (godot-ui-control Pattern 4).
##
## Execução:
##   godot --headless --path . --script res://scenes/ui/test_ui_layout.gd
##
## Com viewport base 1920x1080, stretch mode `canvas_items` e aspect `expand`:
##   • 16:9  → 1920x1080
##   • 21:9  → 2560x1080
##   • 4:3   → 1920x1440

const SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(1920, 1440),
]

const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const UPGRADE_PANEL_SCENE: PackedScene = preload("res://scenes/ui/UpgradePanel.tscn")


func _initialize() -> void:
	var failed: int = 0
	for size: Vector2i in SIZES:
		var vp: SubViewport = SubViewport.new()
		vp.size = size
		root.add_child(vp)

		var ui_root: VBoxContainer = VBoxContainer.new()
		ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui_root.add_theme_constant_override("separation", 0)
		vp.add_child(ui_root)

		var hud: Control = HUD_SCENE.instantiate() as Control
		ui_root.add_child(hud)

		var body_split: HBoxContainer = HBoxContainer.new()
		body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_split.add_theme_constant_override("separation", 0)
		ui_root.add_child(body_split)

		var dig_placeholder: Control = Control.new()
		dig_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dig_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dig_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body_split.add_child(dig_placeholder)

		var panel: Control = UPGRADE_PANEL_SCENE.instantiate() as Control
		body_split.add_child(panel)

		await process_frame
		await process_frame

		var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
		for node: Node in ui_root.find_children("*", "Control", true, false):
			var c: Control = node as Control
			if c == null or not c.is_visible_in_tree():
				continue
			if _is_inside_scroll_container(c, ui_root):
				continue
			if not screen.encloses(c.get_global_rect()):
				failed += 1
				push_error("%s off-screen at %s: %s" % [ui_root.get_path_to(c), size, c.get_global_rect()])

		if vp.gui_get_focus_owner() == null:
			failed += 1
			push_error("nothing has focus at %s, so a gamepad cannot navigate" % size)

		vp.free()

	print("Results: %d failed" % failed)
	quit(1 if failed > 0 else 0)


static func _is_inside_scroll_container(node: Control, stop_at: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null and p != stop_at:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false
