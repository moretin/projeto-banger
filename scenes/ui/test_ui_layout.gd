extends SceneTree
## Exercita o HUD e as bancadas da cena real nos três formatos de janela suportados.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1920, 1440)]
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	for dimensions: Vector2i in SIZES:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = dimensions
		root.add_child(viewport)
		var main: Control = scene.instantiate() as Control
		viewport.add_child(main)
		await process_frame
		await process_frame
		var screen: Rect2 = Rect2(Vector2.ZERO, dimensions)
		var hud: Control = main.get_node_or_null("RootVBox/HUD") as Control
		_check(hud != null, "HUD ausente em %s" % dimensions)
		if hud != null:
			for node: Node in hud.find_children("*", "Control", true, false):
				var control: Control = node as Control
				if control.is_visible_in_tree():
					_check(screen.encloses(control.get_global_rect()), "HUD/%s fora da tela em %s" % [control.name, dimensions])
		var surface: Control = main.get_node("%SurfaceScene") as Control
		var map: Control = surface.get_node("%Map") as Control
		var previous: Rect2 = Rect2()
		for child: Node in map.get_children():
			var location: Button = child as Button
			if location == null:
				continue
			var bounds: Rect2 = location.get_global_rect()
			_check(map.get_global_rect().encloses(bounds), "%s fora do mapa em %s" % [location.name, dimensions])
			_check(not bounds.intersects(previous), "Alvos sobrepostos em %s" % dimensions)
			previous = bounds
			if location.name == &"egg":
				continue
			location.pressed.emit()
			await process_frame
			var groups: HBoxContainer = surface.get_node("%Groups") as HBoxContainer
			for group: Node in groups.get_children():
				(group as Button).pressed.emit()
				await process_frame
				for control: Node in surface.find_children("*", "Button", true, false):
					var button: Button = control as Button
					if button.is_visible_in_tree():
						_check(screen.encloses(button.get_global_rect()), "%s fora da tela em %s" % [button.name, dimensions])
		_check(viewport.gui_get_focus_owner() != null, "Sem foco inicial em %s" % dimensions)
		viewport.free()
	print("Layout do HUD e das bancadas: %d falhas" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
