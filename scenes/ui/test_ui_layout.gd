extends SceneTree
## Exercita o HUD inferior dinâmico, o botão de configurações e as janelas flutuantes compactas nos três formatos de janela suportados.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1920, 1440)]
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

		# 1) Validação do HUD no estado inicial (somente Rochas + barra do meteoro sem timer numérico).
		var hud: Control = main.get_node_or_null("RootVBox/HUD") as Control
		_check(hud != null, "HUD ausente em %s" % dimensions)
		if hud != null:
			_validate_hud(hud, screen, dimensions, "inicial")

			# 1b) Stress-test do HUD com TODOS os 9 recursos ativos da superfície simultaneamente.
			if game_state != null:
				_activate_all_surface_resources(game_state)
				await process_frame
				await process_frame
				var displayed: Array = hud.call("get_displayed_resources") as Array
				_check(displayed.size() == 9, "HUD deveria exibir 9 recursos ativos no stress-test em %s (viu %d)" % [dimensions, displayed.size()])
				_validate_hud(hud, screen, dimensions, "9-recursos")
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

		# 3) Marcos da superfície, janelas flutuantes compactas (Dock <= 280px) e aba Fósseis.
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
				var previous: Rect2 = Rect2()
				for child: Node in map.get_children():
					var location: Button = child as Button
					if location == null:
						continue
					var bounds: Rect2 = location.get_global_rect()
					_check(map.get_global_rect().encloses(bounds), "%s fora do mapa em %s" % [location.name, dimensions])
					_check(not bounds.intersects(previous), "Alvos sobrepostos em %s" % dimensions)
					previous = bounds
					if location.name == "egg":
						continue

					surface.call("move_hero_to_station", StringName(location.name))
					await process_frame
					await process_frame
					_validate_dock(surface, dock, items_scroll, items_list, action_btn, screen, dimensions, String(location.name), "site")

					for group_node: Node in groups.get_children():
						var group_btn: Button = group_node as Button
						if group_btn == null:
							continue
						group_btn.pressed.emit()
						await process_frame
						await process_frame
						_validate_dock(surface, dock, items_scroll, items_list, action_btn, screen, dimensions, String(location.name), group_btn.name)

						if location.name == "rubble_bunker" and group_btn.name == "fossils":
							var frow: Control = items_list.get_node_or_null("FossilRow_0") as Control
							_check(frow != null and frow.is_visible_in_tree(), "FossilRow_0 ausente na aba Fósseis em %s" % dimensions)
							if frow != null:
								var ficon: TextureRect = frow.get_node_or_null("Margin/Row/IconSlot/Icon") as TextureRect
								var fbar: ProgressBar = frow.get_node_or_null("Margin/Row/Info/CleanProgress") as ProgressBar
								_check(ficon != null and ficon.texture != null, "Ícone de fóssil ausente na aba Fósseis em %s" % dimensions)
								_check(fbar != null and fbar.is_visible_in_tree(), "ProgressBar de fóssil ausente na aba Fósseis em %s" % dimensions)

				# 3b) Validação das bancadas populadas (todas construídas + trabalhadores contratados + fósseis limpos).
				if game_state != null:
					_activate_all_surface_resources(game_state)
					game_state.call("add_fragments", &"ankylosaurus", 4)
					await process_frame
					for st_name: String in ["rubble_forge", "rubble_nest", "rubble_silo", "rubble_bunker"]:
						surface.call("move_hero_to_station", StringName(st_name))
						await process_frame
						await process_frame
						for group_node: Node in groups.get_children():
							var group_btn: Button = group_node as Button
							if group_btn == null:
								continue
							group_btn.pressed.emit()
							await process_frame
							await process_frame
							_validate_dock(surface, dock, items_scroll, items_list, action_btn, screen, dimensions, st_name + "-cheia", group_btn.name)

		_check(viewport.gui_get_focus_owner() != null, "Sem foco inicial em %s" % dimensions)
		viewport.free()
		await process_frame

	if game_state != null:
		game_state.call("start_new_game")
	await process_frame
	print("Layout do HUD e das bancadas: %d falhas" % _failures)
	quit(1 if _failures > 0 else 0)


func _activate_all_surface_resources(game_state: Node) -> void:
	game_state.call("add_resource", &"rocks", 1000.0)
	for st: StringName in [&"rubble_nest", &"rubble_silo", &"rubble_bunker"]:
		game_state.call("rebuild_rubble", st)
	for st: StringName in [&"rubble_forge", &"rubble_nest", &"rubble_silo", &"rubble_bunker"]:
		var defs: Dictionary = game_state.get("RUBBLE_DEFS") as Dictionary
		var def: Dictionary = defs[st] as Dictionary
		var prod: StringName = def["product"] as StringName
		game_state.call("add_resource", prod, 100.0)
		game_state.call("hire_station_worker", st)
	game_state.call("roll_station_raw_fossil", &"rubble_forge", 1, true)
	game_state.call("add_resource", &"metal", 12.0)
	game_state.call("add_resource", &"scales", 12.0)
	game_state.call("add_resource", &"beaks", 12.0)
	game_state.call("add_resource", &"amber", 42.0)


func _validate_hud(hud: Control, screen: Rect2, dimensions: Vector2i, tag: String) -> void:
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
