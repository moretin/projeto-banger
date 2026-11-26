extends Control

signal closed

@onready var _panel: PanelContainer = %SettingsPanel
@onready var _chk_mute: CheckBox = %MuteCheckBox
@onready var _slider_volume: HSlider = %VolumeSlider
@onready var _lbl_volume_pct: Label = %VolumePercentLabel
@onready var _chk_auto_pan: CheckBox = %AutoPanCheckBox
@onready var _btn_reset: Button = %ResetCampaignButton
@onready var _btn_close: Button = %CloseSettingsButton

var _reset_armed: bool = false
var _syncing_controls: bool = false


func _ready() -> void:
	visible = false
	_chk_mute.toggled.connect(_on_mute_toggled)
	_slider_volume.value_changed.connect(_on_volume_changed)
	_chk_auto_pan.toggled.connect(_on_auto_pan_toggled)
	_btn_reset.pressed.connect(_on_reset_pressed)
	_btn_close.pressed.connect(_on_close_pressed)
	if GnorpGame != null:
		GnorpGame.audio_settings_changed.connect(_sync_from_game)
	_sync_from_game()


func open_modal() -> void:
	_disarm_reset()
	_sync_from_game()
	visible = true


func close_modal() -> void:
	if not visible:
		return
	_disarm_reset()
	visible = false
	closed.emit()


func _sync_from_game() -> void:
	if GnorpGame == null:
		return
	_syncing_controls = true
	_chk_mute.button_pressed = GnorpGame.audio_muted
	_slider_volume.value = GnorpGame.master_volume
	_lbl_volume_pct.text = "%d%%" % int(round(GnorpGame.master_volume * 100.0))
	_chk_auto_pan.button_pressed = GnorpGame.auto_pan_enabled
	_syncing_controls = false


func _disarm_reset() -> void:
	_reset_armed = false
	_btn_reset.text = "Resetar Campanha"
	_btn_reset.remove_theme_color_override("font_color")


func _on_mute_toggled(toggled: bool) -> void:
	if _syncing_controls or GnorpGame == null:
		return
	GnorpGame.set_audio_muted(toggled)


func _on_volume_changed(val: float) -> void:
	_lbl_volume_pct.text = "%d%%" % int(round(val * 100.0))
	if _syncing_controls or GnorpGame == null:
		return
	GnorpGame.set_master_volume(val)


func _on_auto_pan_toggled(toggled: bool) -> void:
	if _syncing_controls or GnorpGame == null:
		return
	GnorpGame.set_auto_pan(toggled)


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_btn_reset.text = "Confirmar Reset?"
		_btn_reset.add_theme_color_override("font_color", Color(0.85, 0.14, 0.10, 1.0))
		return
	_disarm_reset()
	if GnorpGame != null:
		GnorpGame.reset_campaign()
	close_modal()


func _on_close_pressed() -> void:
	close_modal()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var panel_rect: Rect2 = _panel.get_global_rect()
		if not panel_rect.has_point(mb.global_position):
			close_modal()
			accept_event()
