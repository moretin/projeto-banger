extends SceneTree
## Valida o layout responsivo da interface do reboot (RebootMain, TopBar, CommandTray, TalentModal e SettingsModal) em 3 resoluções.

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gnorp: Node = root.get_node_or_null("/root/GnorpGame")
	var save_manager: Node = root.get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.set("autosave_enabled", false)
	if gnorp != null:
		gnorp.call("reset_campaign")
		gnorp.call("delete_save")

	var scene: PackedScene = load("res://scenes/reboot/RebootMain.tscn") as PackedScene
	_check(scene != null, "RebootMain.tscn não carregou")
	if scene == null:
		print("Layout do Reboot: %d falhas" % _failures)
		quit(1)
		return

	for dims: Vector2i in RESOLUTIONS:
		if gnorp != null:
			gnorp.call("reset_campaign")
			gnorp.call("delete_save")

		var viewport: SubViewport = SubViewport.new()
		viewport.size = dims
		root.add_child(viewport)
		var main: Control = scene.instantiate() as Control
		_check(main != null, "RebootMain não instanciou como Control em %s" % dims)
		if main == null:
			viewport.free()
			continue
		viewport.add_child(main)
		for _i: int in range(3):
			await process_frame

		var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(dims))

		# 1) Estado inicial (sem estruturas construídas).
		_validate_hud_bars(main, screen, dims, "inicial")
		_validate_no_nearest_text(main, dims, "inicial")

		# 2) Estado populado (todas as 6 estruturas desbloqueadas/construídas + Rugido Alfa ativo).
		if gnorp != null:
			gnorp.set("fragments", 500000.0)
			gnorp.set("total_run_fragments", 500000.0)
			var structs: Array = gnorp.call("get_structure_list") as Array
			for raw_item: Variant in structs:
				var s_def: Dictionary = raw_item as Dictionary
				gnorp.call("build_structure", str(s_def.get("id", "")))
			gnorp.call("trigger_trex_roar")
		for _j: int in range(3):
			await process_frame

		_validate_hud_bars(main, screen, dims, "cheio")
		_validate_no_nearest_text(main, dims, "cheio")

		# 3) Abertura e validação de TalentModal.
		var talents_btn: Button = main.get_node_or_null("%TalentsButton") as Button
		var talent_modal: Control = main.get_node_or_null("%TalentModal") as Control
		_check(talents_btn != null and talent_modal != null, "TalentsButton/TalentModal ausentes em %s" % dims)
		if talents_btn != null and talent_modal != null:
			talents_btn.pressed.emit()
			for _k: int in range(3):
				await process_frame
			_check(talent_modal.visible, "TalentModal não abriu em %s" % dims)
			var talent_panel: Control = talent_modal.get_node_or_null("%TalentPanel") as Control
			_check(talent_panel != null and talent_panel.is_visible_in_tree(), "TalentPanel ausente em %s" % dims)
			if talent_panel != null:
				var t_rect: Rect2 = talent_panel.get_global_rect()
				_check(screen.encloses(t_rect), "TalentPanel saiu da viewport em %s (%s)" % [dims, t_rect])
				var t_close: Button = talent_modal.get_node_or_null("%CloseTalentButton") as Button
				if t_close != null:
					_check(t_rect.encloses(t_close.get_global_rect()), "CloseTalentButton saiu do painel em %s" % dims)
				_validate_no_nearest_text(talent_modal, dims, "talent_modal")
				if t_close != null:
					t_close.pressed.emit()
				else:
					talent_modal.call("close_modal")
			for _k2: int in range(2):
				await process_frame
			_check(not talent_modal.visible, "TalentModal não fechou em %s" % dims)

		# 4) Abertura e validação de SettingsModal.
		var settings_btn: Button = main.get_node_or_null("%SettingsButton") as Button
		var settings_modal: Control = main.get_node_or_null("%SettingsModal") as Control
		_check(settings_btn != null and settings_modal != null, "SettingsButton/SettingsModal ausentes em %s" % dims)
		if settings_btn != null and settings_modal != null:
			settings_btn.pressed.emit()
			for _m: int in range(3):
				await process_frame
			_check(settings_modal.visible, "SettingsModal não abriu em %s" % dims)
			var settings_panel: Control = settings_modal.get_node_or_null("%SettingsPanel") as Control
			_check(settings_panel != null and settings_panel.is_visible_in_tree(), "SettingsPanel ausente em %s" % dims)
			if settings_panel != null:
				var s_rect: Rect2 = settings_panel.get_global_rect()
				_check(screen.encloses(s_rect), "SettingsPanel saiu da viewport em %s (%s)" % [dims, s_rect])
				var vbox: Control = settings_panel.get_node_or_null("Margin/VBox") as Control
				if vbox != null:
					_validate_siblings_no_overlap(vbox, dims, "SettingsModal/VBox")
				for ctrl_name: String in ["%MuteCheckBox", "%VolumeSlider", "%AutoPanCheckBox", "%ResetCampaignButton", "%CloseSettingsButton"]:
					var ctrl: Control = settings_modal.get_node_or_null(ctrl_name) as Control
					_check(ctrl != null and ctrl.is_visible_in_tree(), "%s ausente em SettingsModal (%s)" % [ctrl_name, dims])
					if ctrl != null and ctrl.is_visible_in_tree():
						_check(s_rect.encloses(ctrl.get_global_rect()), "%s saiu do SettingsPanel em %s" % [ctrl_name, dims])
				_validate_no_nearest_text(settings_modal, dims, "settings_modal")
				var s_close: Button = settings_modal.get_node_or_null("%CloseSettingsButton") as Button
				if s_close != null:
					s_close.pressed.emit()
				else:
					settings_modal.call("close_modal")
			for _m2: int in range(2):
				await process_frame
			_check(not settings_modal.visible, "SettingsModal não fechou em %s" % dims)

		# 5) Validação do RunEndModal após impacto do meteoro.
		if gnorp != null:
			gnorp.call("end_run_by_impact")
			for _r: int in range(2):
				await process_frame
			var run_end_modal: Control = main.get_node_or_null("%RunEndModal") as Control
			_check(run_end_modal != null and run_end_modal.visible, "RunEndModal não abriu após impacto em %s" % dims)
			if run_end_modal != null:
				var run_panel: Control = run_end_modal.get_node_or_null("RunEndPanel") as Control
				if run_panel != null:
					_check(screen.encloses(run_panel.get_global_rect()), "RunEndPanel saiu da viewport em %s" % dims)
					var btn_row: Control = run_panel.get_node_or_null("Margin/VBox/ButtonsRow") as Control
					if btn_row != null:
						_validate_siblings_no_overlap(btn_row, dims, "RunEndModal/ButtonsRow")
				_validate_no_nearest_text(run_end_modal, dims, "run_end_modal")

		viewport.free()
		await process_frame

	if gnorp != null:
		gnorp.call("reset_campaign")
		gnorp.call("delete_save")
	await process_frame
	print("Layout do Reboot: %d falhas" % _failures)
	quit(1 if _failures > 0 else 0)


func _validate_hud_bars(main: Control, screen: Rect2, dims: Vector2i, tag: String) -> void:
	var top_bar: Control = main.get_node_or_null("%TopBar") as Control
	var command_tray: Control = main.get_node_or_null("%CommandTray") as Control
	var cards_scroll: ScrollContainer = main.get_node_or_null("%CardsScroll") as ScrollContainer
	var cards_row: HBoxContainer = main.get_node_or_null("%CardsRow") as HBoxContainer
	_check(top_bar != null and top_bar.is_visible_in_tree(), "TopBar ausente (%s) em %s" % [tag, dims])
	_check(command_tray != null and command_tray.is_visible_in_tree(), "CommandTray ausente (%s) em %s" % [tag, dims])
	if top_bar == null or command_tray == null:
		return

	var top_rect: Rect2 = top_bar.get_global_rect()
	var tray_rect: Rect2 = command_tray.get_global_rect()
	_check(screen.encloses(top_rect), "TopBar fora da viewport (%s) em %s: %s" % [tag, dims, top_rect])
	_check(screen.encloses(tray_rect), "CommandTray fora da viewport (%s) em %s: %s" % [tag, dims, tray_rect])
	_check(not top_rect.intersects(tray_rect), "TopBar e CommandTray colidem (%s) em %s" % [tag, dims])

	# Verifica que todos os controles visíveis da TopBar cabem na viewport e no TopBar sem colisão entre irmãos.
	for node: Node in top_bar.find_children("*", "Control", true, false):
		var ctrl: Control = node as Control
		if ctrl == null or not ctrl.is_visible_in_tree():
			continue
		var c_rect: Rect2 = ctrl.get_global_rect()
		_check(screen.encloses(c_rect), "TopBar/%s fora da tela (%s) em %s: %s" % [ctrl.name, tag, dims, c_rect])
		_check(top_rect.encloses(c_rect), "TopBar/%s extrapolou TopBar (%s) em %s" % [ctrl.name, tag, dims])

	var top_row: Control = top_bar.get_node_or_null("Margin/Row") as Control
	if top_row != null:
		_validate_siblings_no_overlap(top_row, dims, "TopBar/Row(%s)" % tag)
	for container_path: String in ["Margin/Row/StatsRow", "Margin/Row/MeteorPanel/Margin/HBox", "Margin/Row/NavRow"]:
		var box: Control = top_bar.get_node_or_null(container_path) as Control
		if box != null:
			_validate_siblings_no_overlap(box, dims, "TopBar/%s(%s)" % [container_path, tag])

	# Verifica controles da CommandTray (header + ScrollContainer + irmãos em CardsRow sem sobreposição).
	if cards_scroll != null and cards_scroll.is_visible_in_tree():
		var scroll_rect: Rect2 = cards_scroll.get_global_rect()
		_check(tray_rect.encloses(scroll_rect), "CardsScroll saiu da CommandTray (%s) em %s" % [tag, dims])
		_check(screen.encloses(scroll_rect), "CardsScroll fora da tela (%s) em %s" % [tag, dims])

	var tray_header: Control = command_tray.get_node_or_null("Margin/VBox/TrayHeader") as Control
	if tray_header != null:
		_validate_siblings_no_overlap(tray_header, dims, "CommandTray/TrayHeader(%s)" % tag)
		for child: Node in tray_header.get_children():
			var h_ctrl: Control = child as Control
			if h_ctrl != null and h_ctrl.is_visible_in_tree():
				_check(screen.encloses(h_ctrl.get_global_rect()), "TrayHeader/%s fora da tela (%s) em %s" % [h_ctrl.name, tag, dims])

	if cards_row != null:
		_validate_siblings_no_overlap(cards_row, dims, "CommandTray/CardsRow(%s)" % tag)
		for card_node: Node in cards_row.get_children():
			var card: Control = card_node as Control
			if card == null or not card.is_visible_in_tree():
				continue
			var card_rect: Rect2 = card.get_global_rect()
			_check(card_rect.position.y >= tray_rect.position.y - 1.0 and card_rect.end.y <= tray_rect.end.y + 1.0,
				"Card %s ultrapassou CommandTray verticalmente (%s) em %s" % [card.name, tag, dims])


func _validate_siblings_no_overlap(container: Control, dims: Vector2i, label: String) -> void:
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for child: Node in container.get_children():
		var ctrl: Control = child as Control
		if ctrl == null or not ctrl.is_visible_in_tree():
			continue
		var rect: Rect2 = ctrl.get_global_rect()
		if rect.size.x <= 0.5 or rect.size.y <= 0.5:
			continue
		for i: int in range(rects.size()):
			var shrunk_a: Rect2 = rect.grow(-0.5)
			var shrunk_b: Rect2 = rects[i].grow(-0.5)
			if shrunk_a.size.x > 0.0 and shrunk_a.size.y > 0.0 and shrunk_b.size.x > 0.0 and shrunk_b.size.y > 0.0:
				_check(
					not shrunk_a.intersects(shrunk_b),
					"Interseção entre irmãos em %s (%s vs %s) em %s" % [label, names[i], ctrl.name, dims]
				)
		rects.append(rect)
		names.append(ctrl.name)


func _validate_no_nearest_text(root_node: Node, dims: Vector2i, tag: String) -> void:
	for node: Node in root_node.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			var item: CanvasItem = node as CanvasItem
			_check(
				item.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST,
				"Texto %s (%s) não pode usar TEXTURE_FILTER_NEAREST em %s" % [item.name, tag, dims]
			)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
