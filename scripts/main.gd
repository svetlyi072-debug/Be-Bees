extends Control

var logic: ChessLogic
var board_view: BoardView
var status_label: Label
var new_game_button: TextureButton
var promotion_dialog: PopupPanel
var pending_promotion_move: Array = []
var game_over: bool = false
var _game_started: bool = false

var game_over_dialog: PopupPanel
var game_over_title: Label
var game_over_subtitle: Label

var menu_screen: Control
var game_screen: Control
var leaderboard_dialog: PopupPanel
var profile_dialog: PopupPanel
var profile_name_label: Label
var profile_id_label: Label
var profile_stats_label: Label
var settings_dialog: PopupPanel
var sound_button: TextureButton
var music_button: TextureButton
var sound_volume_slider: HSlider
var music_volume_slider: HSlider
var nickname_edit: LineEdit

var mode_dialog: PopupPanel
var online_dialog: PopupPanel
var online_status_label: Label
var online_code_label: Label
var online_create_btn: Button
var online_join_row: Control
var join_code_edit: LineEdit
var create_code_edit: LineEdit
var public_checkbox: CheckBox
var find_public_btn: Button
var online_create_group: Control

var online_match: OnlineMatch = null
var my_color: String = "w"

var register_screen: Control
var register_name_edit: LineEdit

var resume_dialog: PopupPanel
var resume_label: Label
var _pending_resume_session: Dictionary = {}

var confirm_dialog: PopupPanel
var confirm_label: Label
var _confirm_action: Callable = Callable()

const DIALOG_CONTENT_WIDTH := 560.0
const DIALOG_TITLE_FONT := 34
const DIALOG_TEXT_FONT := 22
const DIALOG_BUTTON_FONT := 22
const DIALOG_BUTTON_HEIGHT := 64.0

const NAME_MAP := {"w": "Белые", "b": "Чёрные"}
const PROMO_LABELS := {"queen": "Королева", "rook": "Ладья", "bishop": "Слон", "knight": "Конь"}
const PROMO_ORDER := ["queen", "rook", "bishop", "knight"]

var square_size: int = 80
var board_size: int = 640
var label_height: int = 36
var button_height: int = 44
var gap: int = 14
var content_height: int = 748
var ui_scale: float = 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.15, 0.16, 0.18)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	logic = ChessLogic.new()

	_compute_layout_sizes()
	_build_menu_screen()
	_build_game_screen()
	_build_register_screen()
	_build_resume_dialog()
	_build_confirm_dialog()

	_show_menu()
	register_screen.visible = UserProfile.is_new_profile

	var saved_session := OnlineMatch.load_saved_session()
	if not saved_session.is_empty():
		_offer_resume_session(saved_session)

func _compute_layout_sizes() -> void:
	var viewport_size := get_viewport_rect().size
	var usable_height: float = viewport_size.y - 160.0
	var usable_width: float = viewport_size.x - 80.0
	var raw_square: float = floor(min(usable_height, usable_width) / 8.0)
	square_size = int(clamp(raw_square, 70.0, 150.0))
	board_size = square_size * 8
	ui_scale = square_size / 80.0
	label_height = int(round(clamp(36.0 * ui_scale, 36.0, 64.0)))
	button_height = int(round(clamp(44.0 * ui_scale, 44.0, 72.0)))
	gap = int(round(clamp(14.0 * ui_scale, 14.0, 24.0)))
	content_height = label_height + gap + board_size + gap + button_height

func _load_texture_safe(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	return res if res is Texture2D else null

func _make_icon_button(icon_key: String, btn_size: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.custom_minimum_size = btn_size
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tex := _load_texture_safe("res://assets/ui/%s.png" % icon_key)
	if tex != null:
		btn.texture_normal = tex
	btn.pressed.connect(GameSettings.play_click)
	return btn

func _make_text_button(label: String, min_size: Vector2, font_size: int = 0) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = min_size
	if font_size > 0:
		btn.add_theme_font_size_override("font_size", font_size)
	btn.pressed.connect(GameSettings.play_click)
	return btn

func _make_volume_slider(initial_percent: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 200
	slider.step = 1
	slider.value = initial_percent
	slider.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 36)
	return slider

func _build_menu_screen() -> void:
	menu_screen = Control.new()
	menu_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_screen)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_screen.add_child(center)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(panel)

	var title := Label.new()
	title.text = "Be_Bees"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Шахматы: Пчёлы против Ос"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	panel.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	panel.add_child(spacer)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 32)
	panel.add_child(button_row)

	var icon_size := Vector2(180, 180)

	var new_game_btn := _make_icon_button("new_game", icon_size)
	new_game_btn.pressed.connect(func(): mode_dialog.popup_centered_ratio(0.55))
	button_row.add_child(new_game_btn)

	var leaderboard_btn := _make_icon_button("leaderboard", icon_size)
	leaderboard_btn.pressed.connect(func(): leaderboard_dialog.popup_centered_ratio(0.8))
	button_row.add_child(leaderboard_btn)

	var profile_btn := _make_icon_button("profile", icon_size)
	profile_btn.pressed.connect(func(): profile_dialog.popup_centered_ratio(0.8))
	button_row.add_child(profile_btn)

	var settings_btn := _make_icon_button("settings", icon_size)
	settings_btn.pressed.connect(func(): settings_dialog.popup_centered_ratio(0.8))
	button_row.add_child(settings_btn)

	leaderboard_dialog = _make_info_dialog("Таблица лидеров", "Пока нет сыгранных партий.\nТаблица появится после первых матчей.")
	add_child(leaderboard_dialog)
	_build_profile_dialog()
	_build_settings_dialog()
	_build_mode_dialog()
	_build_online_dialog()

func _make_info_dialog(title_text: String, message: String) -> PopupPanel:
	var dialog := PopupPanel.new()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", DIALOG_TITLE_FONT)
	vbox.add_child(title_label)

	var msg_label := Label.new()
	msg_label.text = message
	msg_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_label.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	vbox.add_child(msg_label)

	var close_btn := _make_text_button("Закрыть", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	close_btn.pressed.connect(func(): dialog.hide())
	vbox.add_child(close_btn)

	return dialog

func _build_profile_dialog() -> void:
	profile_dialog = PopupPanel.new()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_dialog.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Профиль"
	title_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", DIALOG_TITLE_FONT)
	vbox.add_child(title_label)

	profile_name_label = Label.new()
	profile_name_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	profile_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_name_label.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	vbox.add_child(profile_name_label)

	profile_id_label = Label.new()
	profile_id_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	profile_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_id_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	profile_id_label.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	vbox.add_child(profile_id_label)

	profile_stats_label = Label.new()
	profile_stats_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	profile_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	profile_stats_label.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	vbox.add_child(profile_stats_label)

	var close_btn := _make_text_button("Закрыть", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	close_btn.pressed.connect(func(): profile_dialog.hide())
	vbox.add_child(close_btn)

	profile_dialog.about_to_popup.connect(_refresh_profile_dialog)
	add_child(profile_dialog)

func _refresh_profile_dialog() -> void:
	profile_name_label.text = "Имя: " + UserProfile.player_name
	profile_id_label.text = "ID: " + UserProfile.id
	if UserProfile.stats_synced:
		profile_stats_label.text = "Партий сыграно: %d\nПобед белых: %d   Побед чёрных: %d   Ничьих: %d" % [
			UserProfile.games_played, UserProfile.white_wins, UserProfile.black_wins, UserProfile.draws
		]
	else:
		profile_stats_label.text = "Нет связи с сервером — статистика недоступна."

func _build_settings_dialog() -> void:
	settings_dialog = PopupPanel.new()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_dialog.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	center.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Настройки"
	title_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", DIALOG_TITLE_FONT)
	vbox.add_child(title_label)

	var sound_row := HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 20)
	vbox.add_child(sound_row)
	var sound_label := Label.new()
	sound_label.text = "Звук"
	sound_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH - 110, 0)
	sound_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sound_label.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	sound_row.add_child(sound_label)
	sound_button = _make_icon_button("sound_on", Vector2(90, 90))
	sound_button.pressed.connect(_on_sound_button_pressed)
	sound_row.add_child(sound_button)

	sound_volume_slider = _make_volume_slider(GameSettings.sound_volume_percent)
	sound_volume_slider.value_changed.connect(func(v): GameSettings.set_sound_volume_percent(v))
	vbox.add_child(sound_volume_slider)

	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 20)
	vbox.add_child(music_row)
	var music_label := Label.new()
	music_label.text = "Музыка"
	music_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH - 110, 0)
	music_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	music_label.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	music_row.add_child(music_label)
	music_button = _make_icon_button("music_on", Vector2(90, 90))
	music_button.pressed.connect(_on_music_button_pressed)
	music_row.add_child(music_button)

	music_volume_slider = _make_volume_slider(GameSettings.music_volume_percent)
	music_volume_slider.value_changed.connect(func(v): GameSettings.set_music_volume_percent(v))
	vbox.add_child(music_volume_slider)

	var nick_row := HBoxContainer.new()
	nick_row.add_theme_constant_override("separation", 16)
	vbox.add_child(nick_row)
	var nick_icon := TextureRect.new()
	nick_icon.custom_minimum_size = Vector2(72, 72)
	nick_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nick_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var profile_tex := _load_texture_safe("res://assets/ui/profile.png")
	if profile_tex != null:
		nick_icon.texture = profile_tex
	nick_row.add_child(nick_icon)
	nickname_edit = LineEdit.new()
	nickname_edit.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH - 88, 56)
	nickname_edit.max_length = 20
	nickname_edit.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	nick_row.add_child(nickname_edit)

	var save_btn := _make_text_button("Сохранить ник", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	save_btn.pressed.connect(_on_save_nickname_pressed)
	vbox.add_child(save_btn)

	var close_btn := _make_text_button("Закрыть", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	close_btn.pressed.connect(func(): settings_dialog.hide())
	vbox.add_child(close_btn)

	settings_dialog.about_to_popup.connect(_refresh_settings_dialog)
	add_child(settings_dialog)

func _refresh_settings_dialog() -> void:
	_update_sound_button_icon()
	_update_music_button_icon()
	sound_volume_slider.set_value_no_signal(GameSettings.sound_volume_percent)
	music_volume_slider.set_value_no_signal(GameSettings.music_volume_percent)
	nickname_edit.text = UserProfile.player_name

func _on_sound_button_pressed() -> void:
	GameSettings.set_sound_enabled(not GameSettings.sound_enabled)
	_update_sound_button_icon()

func _update_sound_button_icon() -> void:
	var icon_key := "sound_on" if GameSettings.sound_enabled else "sound_off"
	var tex := _load_texture_safe("res://assets/ui/%s.png" % icon_key)
	if tex != null:
		sound_button.texture_normal = tex

func _on_music_button_pressed() -> void:
	GameSettings.set_music_enabled(not GameSettings.music_enabled)
	_update_music_button_icon()

func _update_music_button_icon() -> void:
	var icon_key := "music_on" if GameSettings.music_enabled else "music_off"
	var tex := _load_texture_safe("res://assets/ui/%s.png" % icon_key)
	if tex != null:
		music_button.texture_normal = tex

func _on_save_nickname_pressed() -> void:
	var new_name := nickname_edit.text.strip_edges()
	if new_name != "":
		UserProfile.set_player_name(new_name)

func _build_mode_dialog() -> void:
	mode_dialog = PopupPanel.new()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_dialog.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	center.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Новая игра"
	title_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", DIALOG_TITLE_FONT)
	vbox.add_child(title_label)

	var local_btn := _make_text_button("Играть локально", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	local_btn.pressed.connect(func():
		mode_dialog.hide()
		if _has_unfinished_online_match():
			_confirm("Текущая онлайн-партия еще не завершена. Начать новую локальную игру?", _start_local_game)
		else:
			_start_local_game()
	)
	vbox.add_child(local_btn)

	var online_btn := _make_text_button("Играть онлайн", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	online_btn.pressed.connect(func():
		mode_dialog.hide()
		_show_online_dialog()
	)
	vbox.add_child(online_btn)

	var close_btn := _make_text_button("Закрыть", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	close_btn.pressed.connect(func(): mode_dialog.hide())
	vbox.add_child(close_btn)

	add_child(mode_dialog)

func _build_online_dialog() -> void:
	online_dialog = PopupPanel.new()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	online_dialog.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	center.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Онлайн-игра"
	title_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", DIALOG_TITLE_FONT)
	vbox.add_child(title_label)

	online_status_label = Label.new()
	online_status_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	online_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	online_status_label.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	vbox.add_child(online_status_label)

	online_code_label = Label.new()
	online_code_label.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	online_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_code_label.add_theme_font_size_override("font_size", DIALOG_TITLE_FONT)
	online_code_label.visible = false
	vbox.add_child(online_code_label)

	online_create_group = VBoxContainer.new()
	online_create_group.add_theme_constant_override("separation", 14)
	vbox.add_child(online_create_group)

	var create_row := HBoxContainer.new()
	create_row.add_theme_constant_override("separation", 16)
	online_create_group.add_child(create_row)

	create_code_edit = LineEdit.new()
	create_code_edit.placeholder_text = "Свой код"
	create_code_edit.max_length = 12
	create_code_edit.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH - 216, 56)
	create_code_edit.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	create_row.add_child(create_code_edit)

	var random_btn := _make_text_button("Случайный", Vector2(200, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	random_btn.pressed.connect(func(): create_code_edit.text = OnlineMatch.generate_room_code())
	create_row.add_child(random_btn)

	public_checkbox = CheckBox.new()
	public_checkbox.text = "Публичная комната (видна всем)"
	public_checkbox.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	online_create_group.add_child(public_checkbox)

	online_create_btn = _make_text_button("Создать комнату", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	online_create_btn.pressed.connect(_on_create_room_pressed)
	online_create_group.add_child(online_create_btn)

	online_join_row = VBoxContainer.new()
	online_join_row.add_theme_constant_override("separation", 14)
	vbox.add_child(online_join_row)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 16)
	online_join_row.add_child(join_row)

	join_code_edit = LineEdit.new()
	join_code_edit.placeholder_text = "Код комнаты"
	join_code_edit.max_length = 12
	join_code_edit.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH - 216, 56)
	join_code_edit.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	join_row.add_child(join_code_edit)

	var join_btn := _make_text_button("Войти", Vector2(200, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	join_btn.pressed.connect(_on_join_room_pressed)
	join_row.add_child(join_btn)

	find_public_btn = _make_text_button("Случайная игра", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	find_public_btn.pressed.connect(_on_find_public_pressed)
	online_join_row.add_child(find_public_btn)

	var cancel_btn := _make_text_button("Отмена", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	cancel_btn.pressed.connect(_on_online_cancel_pressed)
	vbox.add_child(cancel_btn)

	add_child(online_dialog)

func _show_online_dialog() -> void:
	online_status_label.text = "Создайте комнату или введите код, чтобы присоединиться."
	online_code_label.visible = false
	online_create_group.visible = true
	online_join_row.visible = true
	create_code_edit.text = OnlineMatch.generate_room_code()
	public_checkbox.button_pressed = false
	join_code_edit.text = ""
	online_dialog.popup_centered_ratio(0.65)

func _setup_online_match() -> void:
	if online_match != null:
		online_match.leave()
		online_match.queue_free()
	online_match = OnlineMatch.new()
	add_child(online_match)
	online_match.opponent_joined.connect(_on_online_opponent_joined)
	online_match.state_updated.connect(_on_online_state_updated)
	online_match.join_failed.connect(_on_online_join_failed)

func _on_create_room_pressed() -> void:
	var code := create_code_edit.text.strip_edges()
	if code == "":
		online_status_label.text = "Введите код комнаты или нажмите «Случайный»."
		return
	online_status_label.text = "Создаём комнату..."
	online_create_group.visible = false
	online_join_row.visible = false
	logic.reset_board()
	_setup_online_match()
	online_match.create_room(logic.to_dict(), code, public_checkbox.button_pressed)
	online_code_label.text = "Код комнаты: " + online_match.room_code
	online_code_label.visible = true
	online_status_label.text = "Ожидание соперника..."

func _on_join_room_pressed() -> void:
	var code := join_code_edit.text.strip_edges()
	if code == "":
		return
	online_status_label.text = "Подключение..."
	online_create_group.visible = false
	online_join_row.visible = false
	_setup_online_match()
	online_match.join_room(code)

func _on_find_public_pressed() -> void:
	online_status_label.text = "Ищем публичную игру..."
	_setup_online_match()
	online_match.find_public_room(_on_public_room_found)

func _on_public_room_found(code: String) -> void:
	if code == "":
		online_status_label.text = "Нет доступных публичных комнат. Попробуйте позже."
		online_match.leave()
		online_match = null
		return
	online_status_label.text = "Подключение..."
	online_create_group.visible = false
	online_join_row.visible = false
	online_match.join_room(code)

func _on_online_cancel_pressed() -> void:
	if online_match != null:
		online_match.leave()
		online_match = null
	online_dialog.hide()

func _on_online_join_failed(reason: String) -> void:
	online_status_label.text = reason
	online_create_group.visible = true
	online_join_row.visible = true
	OnlineMatch.clear_saved_session()
	online_match = null

func _on_online_opponent_joined(state: Dictionary) -> void:
	online_dialog.hide()
	my_color = online_match.my_color
	logic.load_from_dict(state)
	board_view.last_move = []
	game_over = false
	_game_started = true
	_deselect()
	_refresh_status()
	_show_game()

func _build_resume_dialog() -> void:
	resume_dialog = PopupPanel.new()
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.add_theme_constant_override("separation", 14)
	resume_dialog.add_child(vbox)

	resume_label = Label.new()
	resume_label.custom_minimum_size = Vector2(300, 0)
	resume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resume_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(resume_label)

	var yes_btn := _make_text_button("Продолжить", Vector2(300, 0))
	yes_btn.pressed.connect(_on_resume_confirmed)
	vbox.add_child(yes_btn)

	var no_btn := _make_text_button("Нет, в меню", Vector2(300, 0))
	no_btn.pressed.connect(_on_resume_declined)
	vbox.add_child(no_btn)

	add_child(resume_dialog)

func _offer_resume_session(session: Dictionary) -> void:
	_pending_resume_session = session
	resume_label.text = "Обнаружена незавершённая онлайн-партия (комната %s). Продолжить?" % session.get("room_code", "")
	resume_dialog.popup_centered(Vector2i(340, 240))

func _on_resume_confirmed() -> void:
	resume_dialog.hide()
	var session := _pending_resume_session
	var code: String = session.get("room_code", "")
	_setup_online_match()
	online_status_label.text = "Переподключение к комнате %s..." % code
	online_code_label.text = "Код комнаты: " + code
	online_code_label.visible = true
	online_create_group.visible = false
	online_join_row.visible = false
	online_dialog.popup_centered_ratio(0.65)
	online_match.resume_session(code, session.get("my_color", "w"), session.get("is_host", false))

func _on_resume_declined() -> void:
	resume_dialog.hide()
	OnlineMatch.clear_saved_session()

func _on_online_state_updated(state: Dictionary) -> void:
	logic.load_from_dict(state)
	var lm = state.get("last_move", null)
	if lm is Dictionary:
		board_view.last_move = [
			Vector2i(int(lm.from.x), int(lm.from.y)),
			Vector2i(int(lm.to.x), int(lm.to.y)),
		]
	else:
		board_view.last_move = []
	_deselect()
	_refresh_status()

func _build_register_screen() -> void:
	register_screen = Control.new()
	register_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(register_screen)

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.16, 0.18)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	register_screen.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	register_screen.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Добро пожаловать в Be_Bees!"
	title.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", DIALOG_TITLE_FONT)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Как вас называть?"
	subtitle.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	vbox.add_child(subtitle)

	register_name_edit = LineEdit.new()
	register_name_edit.placeholder_text = "Ваш ник"
	register_name_edit.max_length = 20
	register_name_edit.custom_minimum_size = Vector2(DIALOG_CONTENT_WIDTH, 56)
	register_name_edit.add_theme_font_size_override("font_size", DIALOG_TEXT_FONT)
	register_name_edit.text_submitted.connect(func(_t): _on_register_confirmed())
	vbox.add_child(register_name_edit)

	var confirm_btn := _make_text_button("Начать игру", Vector2(DIALOG_CONTENT_WIDTH, DIALOG_BUTTON_HEIGHT), DIALOG_BUTTON_FONT)
	confirm_btn.pressed.connect(_on_register_confirmed)
	vbox.add_child(confirm_btn)

func _on_register_confirmed() -> void:
	var new_name := register_name_edit.text.strip_edges()
	if new_name == "":
		new_name = "Игрок"
	UserProfile.set_player_name(new_name)
	register_screen.visible = false

func _build_game_screen() -> void:
	game_screen = Control.new()
	game_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_screen)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_screen.add_child(center)

	var content_panel := Control.new()
	content_panel.custom_minimum_size = Vector2(board_size, content_height)
	center.add_child(content_panel)

	status_label = Label.new()
	status_label.position = Vector2(0, 0)
	status_label.size = Vector2(board_size, label_height)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", int(round(22 * ui_scale)))
	content_panel.add_child(status_label)

	board_view = BoardView.new(square_size)
	board_view.position = Vector2(0, label_height + gap)
	board_view.logic = logic
	board_view.square_clicked.connect(_on_square_clicked)
	content_panel.add_child(board_view)

	var in_game_icon_size := Vector2(button_height * 1.6, button_height * 1.6)

	var button_row := HBoxContainer.new()
	button_row.position = Vector2(0, label_height + gap + board_size + gap)
	button_row.size = Vector2(board_size, in_game_icon_size.y)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", int(round(20 * ui_scale)))
	content_panel.add_child(button_row)

	new_game_button = _make_icon_button("new_game", in_game_icon_size)
	new_game_button.pressed.connect(_on_new_game_pressed)
	button_row.add_child(new_game_button)

	promotion_dialog = PopupPanel.new()
	game_screen.add_child(promotion_dialog)
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(12, 12)
	vbox.add_theme_constant_override("separation", 6)
	promotion_dialog.add_child(vbox)
	var promo_title := Label.new()
	promo_title.text = "Выберите фигуру для превращения:"
	vbox.add_child(promo_title)
	for t in PROMO_ORDER:
		var btn := _make_text_button(PROMO_LABELS[t], Vector2(200, 0))
		btn.pressed.connect(_on_promotion_chosen.bind(t))
		vbox.add_child(btn)

	game_over_dialog = PopupPanel.new()
	game_screen.add_child(game_over_dialog)
	var go_vbox := VBoxContainer.new()
	go_vbox.position = Vector2(20, 20)
	go_vbox.add_theme_constant_override("separation", 14)
	game_over_dialog.add_child(go_vbox)

	game_over_title = Label.new()
	game_over_title.custom_minimum_size = Vector2(240, 0)
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_font_size_override("font_size", 28)
	go_vbox.add_child(game_over_title)

	game_over_subtitle = Label.new()
	game_over_subtitle.custom_minimum_size = Vector2(240, 0)
	game_over_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_subtitle.add_theme_font_size_override("font_size", 18)
	go_vbox.add_child(game_over_subtitle)

	var go_button := _make_text_button("Новая игра", Vector2(240, 0))
	go_button.pressed.connect(_on_new_game_pressed)
	go_vbox.add_child(go_button)

	_refresh_status()

func _show_menu() -> void:
	menu_screen.visible = true
	game_screen.visible = false

func _show_game() -> void:
	menu_screen.visible = false
	game_screen.visible = true

func _reset_board_state() -> void:
	logic.reset_board()
	board_view.last_move = []
	game_over = false
	_game_started = true
	_deselect()
	_refresh_status()

func _start_local_game() -> void:
	if online_match != null:
		online_match.leave()
		online_match = null
	my_color = "w"
	_reset_board_state()
	_show_game()

func _has_unfinished_online_match() -> bool:
	return online_match != null and not game_over

func _build_confirm_dialog() -> void:
	confirm_dialog = PopupPanel.new()
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.add_theme_constant_override("separation", 14)
	confirm_dialog.add_child(vbox)

	confirm_label = Label.new()
	confirm_label.custom_minimum_size = Vector2(320, 0)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(confirm_label)

	var yes_btn := _make_text_button("Да, начать новую", Vector2(320, 0))
	yes_btn.pressed.connect(func():
		confirm_dialog.hide()
		if _confirm_action.is_valid():
			_confirm_action.call()
	)
	vbox.add_child(yes_btn)

	var no_btn := _make_text_button("Отмена", Vector2(320, 0))
	no_btn.pressed.connect(func(): confirm_dialog.hide())
	vbox.add_child(no_btn)

	add_child(confirm_dialog)

func _confirm(message: String, action: Callable) -> void:
	confirm_label.text = message
	_confirm_action = action
	confirm_dialog.popup_centered(Vector2i(360, 220))

func _on_continue_pressed() -> void:
	if _game_started:
		_show_game()

func _on_to_menu_pressed() -> void:
	_show_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_square_clicked(pos: Vector2i) -> void:
	if online_match != null and logic.turn != my_color:
		return
	if not promotion_dialog.visible and not game_over:
		_handle_click(pos)

func _handle_click(pos: Vector2i) -> void:
	var selected = board_view.selected_pos
	if selected.x < 0:
		var piece = logic.get_piece(pos)
		if piece != null and piece.color == logic.turn:
			_select(pos)
		return
	if pos == selected:
		_deselect()
		return
	if pos in board_view.legal_moves:
		_try_move(selected, pos)
		return
	var piece = logic.get_piece(pos)
	if piece != null and piece.color == logic.turn:
		_select(pos)
	else:
		_deselect()

func _select(pos: Vector2i) -> void:
	board_view.selected_pos = pos
	board_view.legal_moves = logic.generate_legal_moves(pos)
	board_view.refresh()
	GameSettings.play_click()

func _deselect() -> void:
	board_view.selected_pos = Vector2i(-1, -1)
	board_view.legal_moves = []
	board_view.refresh()

func _try_move(from: Vector2i, to: Vector2i) -> void:
	var piece = logic.get_piece(from)
	if piece.type == "pawn" and (to.y == 7 or to.y == 0):
		pending_promotion_move = [from, to]
		promotion_dialog.popup_centered(Vector2i(240, 220))
		return
	logic.move_piece(from, to)
	_after_move(from, to)

func _on_promotion_chosen(promotion_type: String) -> void:
	promotion_dialog.hide()
	var from: Vector2i = pending_promotion_move[0]
	var to: Vector2i = pending_promotion_move[1]
	logic.move_piece(from, to, promotion_type)
	_after_move(from, to)

func _after_move(from: Vector2i, to: Vector2i) -> void:
	board_view.last_move = [from, to]
	_deselect()
	_refresh_status()
	GameSettings.play_click()
	if online_match != null:
		online_match.submit_move(logic.to_dict(), [from, to])

func _refresh_status() -> void:
	board_view.flipped = (my_color == "b") if online_match != null else (logic.turn == "b")
	board_view.refresh()
	var color_name: String = NAME_MAP[logic.turn]
	var in_check: bool = logic.is_in_check(logic.turn)
	var has_moves: bool = logic.has_any_legal_moves(logic.turn)
	var prefix: String = ("Вы — " + NAME_MAP[my_color] + ". ") if online_match != null else ""
	if not has_moves:
		game_over = true
		if in_check:
			var winner_color: String = logic.opponent(logic.turn)
			var winner: String = NAME_MAP[winner_color]
			status_label.text = prefix + "Мат! Победа: " + winner
			_show_game_over("Шах и мат!", "Победили: " + winner)
			UserProfile.record_game_result(winner_color)
		else:
			status_label.text = prefix + "Пат — ничья"
			_show_game_over("Пат", "Ничья")
			UserProfile.record_game_result("")
	else:
		game_over = false
		if in_check:
			status_label.text = prefix + color_name + " под шахом"
		else:
			status_label.text = prefix + "Ходят: " + color_name

func _show_game_over(title_text: String, subtitle: String) -> void:
	game_over_title.text = title_text
	game_over_subtitle.text = subtitle
	game_over_dialog.popup_centered(Vector2i(280, 190))

func _on_new_game_pressed() -> void:
	if _has_unfinished_online_match():
		_confirm("Текущая онлайн-партия еще не завершена. Начать новую локальную игру?", _do_new_game_pressed)
	else:
		_do_new_game_pressed()

func _do_new_game_pressed() -> void:
	game_over_dialog.hide()
	if online_match != null:
		online_match.leave()
		online_match = null
	my_color = "w"
	_reset_board_state()
