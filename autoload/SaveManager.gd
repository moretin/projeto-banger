extends Node
## SaveManager — persistência do Fóssil Rush.
##
## • Salva em JSON (legível, fácil de depurar) em user://savegame.json.
## • Escrita atômica: grava em .tmp, guarda backup do save anterior e só então substitui.
## • Autosave periódico + ao fechar o jogo / perder foco (importante na Web e no celular).
## • Progresso offline: calcula o tempo fora e pede ao GameState para aplicar os ganhos.
## • Versionamento: SAVE_VERSION + _migrate() para não quebrar saves antigos.
## • Export/Import em Base64 (para o jogador copiar o save, padrão em jogos incrementais).

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.bak.json"
const TEMP_PATH: String = "user://savegame.tmp"

const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 30.0
## Limite de tempo offline recompensado (8 horas).
const MAX_OFFLINE_SECONDS: float = 8.0 * 3600.0
## Ausências menores que isso não geram popup de ganhos offline.
const MIN_OFFLINE_SECONDS: float = 60.0

var _autosave_timer: Timer
## Evita salvar enquanto um load está em andamento.
var _is_loading: bool = false
## Permite desligar o autosave (ex.: em testes ou cenas de debug).
var autosave_enabled: bool = true


func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)
	# Salva logo após um prestígio (momento importante).
	Events.prestige_completed.connect(func(_amber: float, _run: int) -> void: save_game())
	# Deferred: dá tempo da cena principal entrar na árvore e conectar em Events.game_loaded.
	load_game.call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()


#region Salvar
func save_game() -> bool:
	if _is_loading:
		return false
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": GameState.to_save_dict(),
	}
	var json_text: String = JSON.stringify(payload, "\t")

	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Falha ao abrir %s: %s" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(json_text)
	file.close()

	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("[SaveManager] Não foi possível acessar user://")
		return false
	if dir.file_exists(SAVE_PATH.get_file()):
		if dir.file_exists(BACKUP_PATH.get_file()):
			dir.remove(BACKUP_PATH.get_file())
		dir.rename(SAVE_PATH.get_file(), BACKUP_PATH.get_file())
	var err: Error = dir.rename(TEMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_error("[SaveManager] Falha ao finalizar save: %s" % error_string(err))
		return false

	Events.game_saved.emit()
	return true


func _on_autosave_timeout() -> void:
	if autosave_enabled:
		save_game()
#endregion


#region Carregar
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


## Carrega o save (ou o backup, se o principal estiver corrompido). Retorna true se carregou.
func load_game() -> bool:
	var payload: Dictionary = _read_payload(SAVE_PATH)
	if payload.is_empty():
		payload = _read_payload(BACKUP_PATH)
		if not payload.is_empty():
			push_warning("[SaveManager] Save principal inválido; usando backup.")
	if payload.is_empty():
		return false
	return _apply_payload(payload)


func _apply_payload(payload: Dictionary) -> bool:
	_is_loading = true
	payload = _migrate(payload)
	var game_data: Variant = payload.get("game", {})
	if not game_data is Dictionary:
		_is_loading = false
		return false
	GameState.load_save_dict(game_data as Dictionary)
	_is_loading = false
	Events.game_loaded.emit()

	var saved_at: float = float(payload.get("saved_at", 0.0))
	if saved_at > 0.0:
		_apply_offline_progress(Time.get_unix_time_from_system() - saved_at)
	return true


func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("[SaveManager] JSON inválido em %s" % path)
		return {}
	return parsed as Dictionary


## Converte saves de versões antigas para a atual. Adicione um `if` por versão.
func _migrate(payload: Dictionary) -> Dictionary:
	var version: int = int(payload.get("version", 0))
	# Exemplo para o futuro:
	# if version < 2:
	#     payload["game"]["novo_campo"] = valor_padrao
	#     version = 2
	if version > SAVE_VERSION:
		push_warning("[SaveManager] Save de versão mais nova (%d > %d)." % [version, SAVE_VERSION])
	payload["version"] = SAVE_VERSION
	return payload
#endregion


#region Offline
func _apply_offline_progress(elapsed: float) -> void:
	if elapsed < MIN_OFFLINE_SECONDS:
		return
	var seconds: float = minf(elapsed, MAX_OFFLINE_SECONDS)
	var gains: Dictionary = GameState.apply_offline_progress(seconds)
	if not gains.is_empty():
		Events.offline_progress_applied.emit(seconds, gains)
#endregion


#region Utilidades
## Apaga o save (botão "Resetar progresso" nas configurações).
func delete_save() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for path: String in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if dir.file_exists(path.get_file()):
			dir.remove(path.get_file())
	GameState.start_new_game()


## Save em texto Base64 (para o jogador copiar/colar).
func export_save_string() -> String:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": GameState.to_save_dict(),
	}
	return Marshalls.utf8_to_base64(JSON.stringify(payload))


func import_save_string(encoded: String) -> bool:
	var text: String = Marshalls.base64_to_utf8(encoded.strip_edges())
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("[SaveManager] Save importado inválido.")
		return false
	var payload: Dictionary = parsed as Dictionary
	payload.erase("saved_at")  # não conceder progresso offline em saves importados
	if not _apply_payload(payload):
		return false
	save_game()
	return true
#endregion
