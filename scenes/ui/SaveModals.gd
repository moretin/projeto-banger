class_name SaveModals
extends Control
## Modais de Progresso Offline ("Enquanto você estava fora...") e Save/Export/Import/Reset.

@onready var _offline_backdrop: ColorRect = %OfflineBackdrop
@onready var _offline_summary_label: Label = %OfflineSummaryLabel
@onready var _offline_ok_button: Button = %OfflineOkButton

@onready var _settings_backdrop: ColorRect = %SettingsBackdrop
@onready var _save_now_button: Button = %SaveNowButton
@onready var _export_button: Button = %ExportButton
@onready var _import_button: Button = %ImportButton
@onready var _reset_button: Button = %ResetButton
@onready var _close_settings_button: Button = %CloseSettingsButton
@onready var _save_text_edit: TextEdit = %SaveTextEdit
@onready var _status_label: Label = %SaveStatusLabel

var _confirm_reset: bool = false


func _ready() -> void:
	_offline_backdrop.visible = false
	_settings_backdrop.visible = false
	_save_now_button.icon = AmberTheme.get_icon(&"save")
	_export_button.icon = AmberTheme.get_icon(&"settings")
	_import_button.icon = AmberTheme.get_icon(&"camp")

	_offline_ok_button.pressed.connect(func() -> void: _offline_backdrop.visible = false)
	_close_settings_button.pressed.connect(_close_settings)
	_save_now_button.pressed.connect(_on_save_now_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_import_button.pressed.connect(_on_import_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)

	Events.offline_progress_applied.connect(_on_offline_progress_applied)
	Events.settings_modal_requested.connect(open_settings)
	Events.game_saved.connect(_on_game_saved)


func open_settings() -> void:
	_confirm_reset = false
	_reset_button.text = "Resetar Todo o Progresso"
	_status_label.text = ""
	_save_text_edit.text = SaveManager.export_save_string()
	_settings_backdrop.visible = true


func _close_settings() -> void:
	_settings_backdrop.visible = false


func _on_offline_progress_applied(seconds: float, gains: Dictionary) -> void:
	var lines: PackedStringArray = [
		"Tempo ausente: %s\n" % GameState.format_time(seconds),
		"Sua equipe de dinossauros e máquinas coletou:",
	]
	for resource_id: Variant in gains:
		lines.append("• +%s %s" % [GameState.format_number(float(gains[resource_id])), GameState.RESOURCE_NAMES[resource_id]])
	_offline_summary_label.text = "\n".join(lines)
	_offline_backdrop.visible = true


func _on_game_saved() -> void:
	if _settings_backdrop.visible and _status_label.text.is_empty():
		_status_label.text = "Progresso salvo automaticamente."


func _on_save_now_pressed() -> void:
	var ok: bool = SaveManager.save_game()
	_status_label.text = "Jogo salvo com sucesso!" if ok else "Erro ao salvar."


func _on_export_pressed() -> void:
	var encoded: String = SaveManager.export_save_string()
	_save_text_edit.text = encoded
	DisplayServer.clipboard_set(encoded)
	_status_label.text = "Código Base64 copiado para a área de transferência."


func _on_import_pressed() -> void:
	var ok: bool = SaveManager.import_save_string(_save_text_edit.text)
	if ok:
		if SaveManager.last_migrated_reset_version >= 0:
			_status_label.text = "Save antigo (v%d) incompatível — novo jogo iniciado." % SaveManager.last_migrated_reset_version
		else:
			_status_label.text = "Save importado com sucesso!"
			Events.notification_requested.emit("Save importado com sucesso!", AmberTheme.get_icon(&"save"))
	else:
		_status_label.text = "Código de save inválido."


func _on_reset_pressed() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_button.text = "Confirmar Reset Permanente (Clique novamente)"
		return
	SaveManager.delete_save()
	_confirm_reset = false
	_settings_backdrop.visible = false
	Events.notification_requested.emit("Progresso resetado.", AmberTheme.get_icon(&"camp"))
