extends SceneTree
## Exercita o HUD inferior dinâmico (14 recursos), os 3 biomas, as abas de ícones e as janelas flutuantes compactas nos três formatos de janela suportados.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1920, 1440)]
const BIOMES: Array[StringName] = [&"amber_basin", &"forest", &"snow"]
const MAX_DOCK_HEIGHT: float = 280.0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_manager: Node = root.get_node_or_null("/root/SaveManager")
	var game_state: Node = root.get_node_or_null("/root/GameState")
	var events: Node = root.get_node_or_null("/root/Events")
	if save_manager != null:
		save_manager.set("autosave_enabled", false)

	var scene: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	_check(scene != null, "Main.tscn não carregou")
	if scene == null:
		print("Layout do HUD e das bancadas: %d falhas" % _failures)
		quit(1)
		return

	for dimensions: Vector2i in SIZES:
		if game_state != null:
			game_state.call("start_new_game")
		var viewport: SubViewport = SubViewport.new()
		viewport.size = dimensions
		root.add_child(viewport)
		var main: Control = scene.instantiate() as Control
		viewport.add_child(main)
		await process_frame
		await process_frame
		var screen: Rect2 = Rect2(Vector2.ZERO, dimensions)

		# 0) Museu removido de Main.tscn.
		_check(main.get_node_or_null("FossilMuseum") == null, "FossilMuseum não deve existir em Main.tscn (%s)" % dimensions)

		# 1) Validação do HUD no estado inicial (somente Rochas + barra do meteoro sem timer numérico).
		var hud: Control = main.get_node_or_null("RootVBox/HUD") as Control
		_check(hud != null, "HUD ausente em %s" % dimensions)
		if hud != null:
			_validate_hud(hud, screen, dimensions, "inicial")

			# 1b) Stress-test do HUD com TODOS os 14 recursos ativos dos 3 biomas simultaneamente.
			if game_state != null:
				_activate_all_surface_resources(game_state)
				await process_frame
				await process_frame
				var displayed: Array = hud.call("get_displayed_resources") as Array
				_check(displayed.size() == 14, "HUD deveria exibir 14 recursos ativos no stress-test em %s (viu %d)" % [dimensions, displayed.size()])
				var row_bottom: Control = hud.get_node_or_null("%RowBottom") as Control
				_check(row_bottom != null and row_bottom.visible, "HUD deveria ativar 2ª linha compacta com 14 recursos em %s" % dimensions)
				_validate_hud(hud, screen, dimensions, "14-recursos")
				game_state.call("start_new_game")
				await process_frame
				await process_frame

		# 2) Engrenagem de configurações e %ResetButton.
		var gear: Button = main.get_node_or_null("%TopGearButton") as Button
		_check(gear != null and gear.is_visible_in_tree(), "Engrenagem de configurações ausente em %s" % dimensions)
		if gear != null and gear.is_visible_in_tree():
			_check(screen.encloses(gear.get_global_rect()), "TopGearButton fora da tela em %s" % dimensions)

		var modals: Control = main.get_node_or_null("SaveModals") as Control
		if modals != null and gear != null:
			gear.pressed.emit()
			await process_frame
			var reset_btn: Button = modals.get_node_or_null("%ResetButton") as Button
			_check(reset_btn != null and reset_btn.is_visible_in_tree(), "ResetButton ausente nas configurações em %s" % dimensions)
			if reset_btn != null and reset_btn.is_visible_in_tree():
				_check(screen.encloses(reset_btn.get_global_rect()), "ResetButton fora da tela em %s" % dimensions)
			var close_btn: Button = modals.get_node_or_null("%CloseSettingsButton") as Button
			if close_btn != null:
				close_btn.pressed.emit()
			await process_frame

		# 3) Marcos da superfície em todos os 3 biomas, abas de ícones e janelas flutuantes compactas (Dock <= 280px).
		if events != null:
			var egg_sig: Signal = events.get("orange_rock_hit") as Signal
			egg_sig.emit(20.0, Vector2.ZERO)
		if game_state != null:
			game_state.call("roll_station_raw_fossil", &"rubble_forge", 1, true)
			game_state.call("roll_station_raw_fossil", &"rubble_nest", 1, true)
		await process_frame

		var surface: Control = main.get_node_or_null("%SurfaceScene") as Control
		_check(surface != null, "SurfaceScene ausente em %s" % dimensions)
		if surface != null:
			var map: Control = surface.get_node_or_null("%Map") as Control
			var dock: Control = surface.get_node_or_null("%Dock") as Control
			var items_scroll: ScrollContainer = surface.get_node_or_null("%ItemsScroll") as ScrollContainer
			var items_list: VBoxContainer = surface.get_node_or_null("%ItemsList") as VBoxContainer
			var action_btn: Button = surface.get_node_or_null("%ToDigSiteButton") as Button
			var groups: HBoxContainer = surface.get_node_or_null("%Groups") as HBoxContainer
			_check(map != null and dock != null and items_scroll != null and items_list != null and action_btn != null and groups != null, "Nós essenciais do Dock ausentes em %s" % dimensions)

			if map != null and dock != null and items_scroll != null and items_list != null and action_btn != null and groups != null:
				# 3a) Validação de marcos por bioma (sem sobreposição e dentro do mapa) + estado inicial das bancadas.
				for biome_id: StringName in BIOMES:
					if game_state != null:
						game_state.call("set_current_biome", biome_id)
					await process_frame
					await process_frame
					var visible_rects: Array[Rect2] = []
					var visible_names: Array[String] = []
					var biome_stations: Array[StringName] = []
					for child: Node in map.get_children():
						var location: Button = child as Button
						if location == null or not location.visible:
							continue
						var bounds: Rect2 = location.get_global_rect()
						_check(map.get_global_rect().encloses(bounds), "%s (%s) fora do mapa em %s" % [location.name, biome_id, dimensions])
						for i: int in range(visible_rects.size()):
							_check(
								not bounds.intersects(visible_rects[i]),
								"Alvos sobrepostos (%s vs %s) em %s (%s)" % [location.name, visible_names[i], biome_id, dimensions]
							)
						visible_rects.append(bounds)
						visible_names.append(location.name)
						if location.name != "egg":
							biome_stations.append(StringName(location.name))
					_check(not biome_stations.is_empty(), "Bioma %s sem estruturas visíveis em %s" % [biome_id, dimensions])
					if biome_id == &"amber_basin":
						_check(&"ark" in biome_stations, "Marco 'ark' deve estar visível na Bacia do Âmbar em %s" % dimensions)

					for st_id: StringName in biome_stations:
						surface.call("move_hero_to_station", st_id)
						await process_frame
						await process_frame
						_validate_dock(surface, dock, groups, items_scroll, items_list, action_btn, screen, dimensions, String(st_id), "site")

						for group_node: Node in groups.get_children():
							var group_btn: Button = group_node as Button
							if group_btn == null:
								continue
							group_btn.pressed.emit()
							await process_frame
							await process_frame
							_validate_dock(surface, dock, groups, items_scroll, items_list, action_btn, screen, dimensions, String(st_id), group_btn.name)

							if st_id == &"rubble_bunker" and group_btn.name == "fossils":
								var frow: Control = items_list.get_node_or_null("FossilRow_0") as Control
								_check(frow != null and frow.is_visible_in_tree(), "FossilRow_0 ausente na aba Fósseis em %s" % dimensions)
								if frow != null:
									var ficon: TextureRect = frow.get_node_or_null("Margin/Row/IconSlot/Icon") as TextureRect
									var fbar: ProgressBar = frow.get_node_or_null("Margin/Row/Info/CleanProgress") as ProgressBar
									_check(ficon != null and ficon.texture != null, "Ícone de fóssil ausente na aba Fósseis em %s" % dimensions)
									_check(fbar != null and fbar.is_visible_in_tree(), "ProgressBar de fóssil ausente na aba Fósseis em %s" % dimensions)

				# 3b) Validação das bancadas populadas (todas as 8 estações construídas + trabalhadores + fósseis limpos + Arca populada + 14 recursos).
				if game_state != null:
					_activate_all_surface_resources(game_state)
					game_state.call("add_fragments", &"ankylosaurus", 10)
					game_state.call("add_fragments", &"triceratops", 10)
					game_state.call("claim_quarry_special_plate")
					game_state.call("awaken_quarry_ankylosaurus")
					game_state.call("add_resource", &"rocks", 80.0)
					game_state.call("add_resource", &"metal", 6.0)
					game_state.call("build_ark_module", &"hull_reinforcement")
					await process_frame
					var all_stations: Array = (game_state.get("RUBBLE_ORDER") as Array).duplicate()
					all_stations.append(&"ark")
					for st_val: Variant in all_stations:
						var st_id: StringName = st_val as StringName
						surface.call("move_hero_to_station", st_id)
						await process_frame
						await process_frame
						for group_node: Node in groups.get_children():
							var group_btn: Button = group_node as Button
							if group_btn == null:
								continue
							group_btn.pressed.emit()
							await process_frame
							await process_frame
							_validate_dock(surface, dock, groups, items_scroll, items_list, action_btn, screen, dimensions, String(st_id) + "-cheia", group_btn.name)
					if hud != null:
						_validate_hud(hud, screen, dimensions, "14-recursos-com-dock")

			# 4) Validação do QuarryExtractionModal dentro dos limites da tela nas 3 resoluções.
			var qmodal: Control = surface.get_node_or_null("%QuarryExtractionModal") as Control
			_check(qmodal != null, "QuarryExtractionModal ausente em SurfaceScene (%s)" % dimensions)
			if qmodal != null:
				_check(not bool(qmodal.call("is_extraction_open")), "QuarryExtractionModal deve iniciar fechado em %s" % dimensions)
				if events != null:
					var qsig: Signal = events.get("quarry_extraction_requested") as Signal
					qsig.emit()
				else:
					qmodal.call("open_extraction")
				await process_frame
				await process_frame
				_validate_quarry_modal(qmodal, screen, dimensions, "aberta")
				qmodal.call("trigger_precise_strike_window")
				qmodal.call("resolve_precise_strike_attempt", &"good")
				qmodal.call("apply_brush_progress", 1.0)
				await process_frame
				await process_frame
				_validate_quarry_modal(qmodal, screen, dimensions, "concluida")
				var complete_btn: Button = qmodal.get_node_or_null("%CompleteReturnButton") as Button
				_check(complete_btn != null and complete_btn.is_visible_in_tree(), "CompleteReturnButton deve aparecer após extração (%s)" % dimensions)
				if complete_btn != null:
					_check(screen.encloses(complete_btn.get_global_rect()), "CompleteReturnButton fora da tela em %s" % dimensions)
					complete_btn.pressed.emit()
				else:
					qmodal.call("close_extraction")
				await process_frame
				await process_frame
				_check(not bool(qmodal.call("is_extraction_open")), "QuarryExtractionModal deve fechar ao clicar em Voltar à Pedreira (%s)" % dimensions)

		_check(viewport.gui_get_focus_owner() != null, "Sem foco inicial em %s" % dimensions)
		viewport.free()
		await process_frame

	if game_state != null:
		game_state.call("start_new_game")
	await process_frame
	print("Layout do HUD e das bancadas: %d falhas" % _failures)
	quit(1 if _failures > 0 else 0)


func _activate_all_surface_resources(game_state: Node) -> void:
	game_state.call("add_resource", &"rocks", 5000.0)
	game_state.call("add_resource", &"metal", 50.0)
	game_state.call("add_resource", &"scales", 50.0)
	game_state.call("add_resource", &"beaks", 50.0)
	game_state.call("add_resource", &"resin", 50.0)
	var all_stations: Array = game_state.get("RUBBLE_ORDER") as Array
	var defs: Dictionary = game_state.get("RUBBLE_DEFS") as Dictionary
	for st_val: Variant in all_stations:
		var st: StringName = st_val as StringName
		if not bool(game_state.call("is_station_built", st)):
			game_state.call("rebuild_rubble", st)
		var def: Dictionary = defs[st] as Dictionary
		var prod: StringName = def["product"] as StringName
		game_state.call("add_resource", prod, 500.0)
		game_state.call("hire_station_worker", st)
	game_state.call("roll_station_raw_fossil", &"rubble_forge", 1, true)
	game_state.call("add_resource", &"amber", 42.0)


func _validate_hud(hud: Control, screen: Rect2, dimensions: Vector2i, tag: String) -> void:
	_check(hud.get_node_or_null("%MuseumButton") == null, "MuseumButton não deve existir no HUD (%s) em %s" % [tag, dimensions])
	_check(hud.size.y >= hud.get_combined_minimum_size().y - 0.5, "HUD (%s) comprimido verticalmente em %s (%s < %s)" % [tag, dimensions, hud.size.y, hud.get_combined_minimum_size().y])
	_check(screen.encloses(hud.get_global_rect()), "HUD (%s) fora da tela em %s" % [tag, dimensions])
	var meteor_bar: ProgressBar = hud.get_node_or_null("%MeteorBar") as ProgressBar
	_check(meteor_bar != null and meteor_bar.is_visible_in_tree(), "MeteorBar (%s) ausente em %s" % [tag, dimensions])
	if meteor_bar != null:
		_check(not meteor_bar.show_percentage, "MeteorBar (%s) não pode exibir porcentagem numérica em %s" % [tag, dimensions])
	_check(hud.get_node_or_null("%MeteorLabel") == null, "MeteorLabel numérico não pode existir no HUD (%s) em %s" % [tag, dimensions])
	var res_center: Control = hud.get_node_or_null("%ResourcesCenter") as Control
	_check(res_center != null and res_center.is_visible_in_tree(), "ResourcesCenter (%s) ausente em %s" % [tag, dimensions])
	for node: Node in hud.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree():
			_check(screen.encloses(control.get_global_rect()), "HUD/%s (%s) fora da tela em %s" % [control.name, tag, dimensions])


func _validate_dock(
	surface: Control,
	dock: Control,
	groups: HBoxContainer,
	items_scroll: ScrollContainer,
	items_list: VBoxContainer,
	action_btn: Button,
	screen: Rect2,
	dimensions: Vector2i,
	station_name: String,
	tab_name: String
) -> void:
	_check(dock.is_visible_in_tree(), "Janela flutuante (%s/%s) não abriu em %s" % [station_name, tab_name, dimensions])
	if not dock.is_visible_in_tree():
		return
	var dock_rect: Rect2 = dock.get_global_rect()
	var scroll_rect: Rect2 = items_scroll.get_global_rect()
	_check(screen.encloses(dock_rect), "Dock (%s/%s) fora da tela em %s" % [station_name, tab_name, dimensions])
	_check(dock.size.y <= MAX_DOCK_HEIGHT, "Dock (%s/%s) grande demais (%spx > %spx) em %s" % [station_name, tab_name, dock.size.y, MAX_DOCK_HEIGHT, dimensions])
	_check(dock_rect.encloses(scroll_rect), "ItemsScroll (%s/%s) ultrapassou o Dock em %s" % [station_name, tab_name, dimensions])
	_check(screen.encloses(scroll_rect), "ItemsScroll (%s/%s) fora da tela em %s" % [station_name, tab_name, dimensions])
	_check(action_btn.is_visible_in_tree() and screen.encloses(action_btn.get_global_rect()), "ToDigSiteButton (%s/%s) fora da tela em %s" % [station_name, tab_name, dimensions])

	# Abas de ícones minimalistas dentro do Dock.
	for g_node: Node in groups.get_children():
		var tab_btn: Button = g_node as Button
		if tab_btn == null or not tab_btn.is_visible_in_tree():
			continue
		_check(tab_btn.text == "", "Aba %s (%s) deve usar somente ícone sem texto em %s" % [tab_btn.name, station_name, dimensions])
		_check(dock_rect.encloses(tab_btn.get_global_rect()), "Aba %s (%s/%s) saiu do Dock em %s" % [tab_btn.name, station_name, tab_name, dimensions])
		var tab_icon: TextureRect = tab_btn.get_node_or_null("Content/Icon") as TextureRect
		_check(tab_icon != null and tab_icon.visible and tab_icon.texture != null, "Ícone da aba %s (%s) ausente em %s" % [tab_btn.name, station_name, dimensions])

	# Botões visíveis fora da lista rolável devem ficar integralmente dentro da tela.
	for control: Node in surface.find_children("*", "Button", true, false):
		var button: Button = control as Button
		if button == null or not button.is_visible_in_tree():
			continue
		if items_list.is_ancestor_of(button):
			continue
		_check(screen.encloses(button.get_global_rect()), "%s (%s/%s) fora da tela em %s" % [button.name, station_name, tab_name, dimensions])

	# Cards dentro da lista rolável: sem transbordamento horizontal e BuyButton à direita do texto.
	for card_node: Node in items_list.get_children():
		var card: Control = card_node as Control
		if card == null or not card.is_visible_in_tree():
			continue
		var card_rect: Rect2 = card.get_global_rect()
		_check(
			card_rect.position.x >= scroll_rect.position.x - 1.5 and card_rect.end.x <= scroll_rect.end.x + 1.5,
			"Card %s (%s/%s) transbordou horizontalmente o ScrollContainer em %s" % [card.name, station_name, tab_name, dimensions]
		)
		var buy_btn: Button = card.get_node_or_null("Margin/Row/BuyButton") as Button
		var info_box: Control = card.get_node_or_null("Margin/Row/Info") as Control
		if buy_btn != null and buy_btn.is_visible_in_tree() and info_box != null:
			var buy_rect: Rect2 = buy_btn.get_global_rect()
			var info_rect: Rect2 = info_box.get_global_rect()
			_check(
				buy_rect.position.x >= info_rect.end.x - 2.0,
				"BuyButton de %s (%s/%s) deve ficar à direita do texto em %s" % [card.name, station_name, tab_name, dimensions]
			)
			if scroll_rect.intersects(buy_rect):
				var visible_buy: Rect2 = scroll_rect.intersection(buy_rect)
				_check(screen.encloses(visible_buy), "BuyButton visível de %s (%s/%s) fora da tela em %s" % [card.name, station_name, tab_name, dimensions])


func _validate_quarry_modal(qmodal: Control, screen: Rect2, dimensions: Vector2i, stage: String) -> void:
	_check(bool(qmodal.call("is_extraction_open")) and qmodal.is_visible_in_tree(), "QuarryExtractionModal (%s) não abriu em %s" % [stage, dimensions])
	var workshop: Control = qmodal.get_node_or_null("%WorkshopPanel") as Control
	var bed: Control = qmodal.get_node_or_null("%SedimentBed") as Control
	var seismo: Control = qmodal.get_node_or_null("%SeismographBar") as Control
	var close_btn: Button = qmodal.get_node_or_null("%CloseButton") as Button
	var bar: ProgressBar = qmodal.get_node_or_null("%ExtractionProgressBar") as ProgressBar
	var status_lbl: Label = qmodal.get_node_or_null("%StatusLabel") as Label
	_check(workshop != null and bed != null and seismo != null and close_btn != null and bar != null and status_lbl != null, "Nós essenciais de QuarryExtractionModal (%s) ausentes em %s" % [stage, dimensions])
	if workshop != null and workshop.is_visible_in_tree():
		var w_rect: Rect2 = workshop.get_global_rect()
		_check(screen.encloses(w_rect), "QuarryExtractionModal/WorkshopPanel (%s) fora da tela em %s (%s)" % [stage, dimensions, w_rect])
		for ctrl: Control in [bed, seismo, close_btn, bar, status_lbl]:
			if ctrl != null and ctrl.is_visible_in_tree():
				var c_rect: Rect2 = ctrl.get_global_rect()
				_check(screen.encloses(c_rect), "QuarryExtractionModal/%s (%s) fora da tela em %s" % [ctrl.name, stage, dimensions])
				_check(w_rect.encloses(c_rect), "QuarryExtractionModal/%s (%s) ultrapassou WorkshopPanel em %s" % [ctrl.name, stage, dimensions])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
