class_name StageOneHud
extends CanvasLayer

signal select_mode_requested
signal worker_build_requested(building_id: String)
signal hq_worker_requested
signal placement_cancel_requested

var _top_bar: Label
var _hint_label: Label
var _selected_label: Label
var _select_button: Button
var _context_panel: HBoxContainer
var _selection_rect: ColorRect

func _ready() -> void:
	_build_ui()
	update_status(10000, 0, 40, 0)
	update_selection_summary(0)
	set_hint("Tap Worker to build. Tap HQ to train another Worker.")

func update_status(money: int, unit_count: int, unit_cap: int, match_seconds: int) -> void:
	if not is_instance_valid(_top_bar):
		return
	var minutes: int = match_seconds / 60
	var seconds: int = match_seconds % 60
	_top_bar.text = "$ %s    Units %d/%d    %02d:%02d" % [_format_money(money), unit_count, unit_cap, minutes, seconds]

func update_selection_summary(count: int) -> void:
	if is_instance_valid(_selected_label):
		_selected_label.text = "Selected: %d" % count

func set_hint(message: String) -> void:
	if is_instance_valid(_hint_label):
		_hint_label.text = message

func set_select_mode(active: bool) -> void:
	if is_instance_valid(_select_button):
		_select_button.button_pressed = active
	if active:
		set_hint("SELECT: drag over friendly soldiers.")
	else:
		set_hint("Tap ground to move. Tap enemy to attack.")

func show_default_context() -> void:
	_clear_context_panel()

func show_worker_context() -> void:
	_clear_context_panel()
	_add_context_button("Resource\n$1200", "_on_worker_build_pressed", "resource_center")
	_add_context_button("Power\n$700", "_on_worker_build_pressed", "power_plant")
	_add_context_button("Barracks\n$1000", "_on_worker_build_pressed", "barracks")
	_add_context_button("Defense\n$900", "_on_worker_build_pressed", "defense_post")

func show_hq_context() -> void:
	_clear_context_panel()
	_add_context_button("Worker\n$500", "_on_hq_worker_pressed")

func show_building_context(label: String) -> void:
	_clear_context_panel()
	set_hint("%s selected." % label)

func show_placement_context(building_name: String, valid: bool) -> void:
	_clear_context_panel()
	_add_context_button("Cancel", "_on_cancel_placement_pressed")
	set_hint("Place %s: %s" % [building_name, "valid" if valid else "blocked"])

func show_selection_rect(start: Vector2, current: Vector2) -> void:
	if not is_instance_valid(_selection_rect):
		return
	var rect := Rect2(start, current - start).abs()
	_selection_rect.position = rect.position
	_selection_rect.size = rect.size
	_selection_rect.visible = rect.size.length_squared() > 16.0

func hide_selection_rect() -> void:
	if is_instance_valid(_selection_rect):
		_selection_rect.visible = false

func is_screen_position_over_ui(screen_position: Vector2) -> bool:
	if is_instance_valid(_select_button) and _select_button.visible and _select_button.get_global_rect().has_point(screen_position):
		return true
	if is_instance_valid(_context_panel) and _context_panel.visible and _context_panel.get_global_rect().has_point(screen_position):
		return true
	return false

func _build_ui() -> void:
	var root := Control.new()
	root.name = "StageOneHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.name = "TopPanel"
	top_panel.position = Vector2(18.0, 16.0)
	top_panel.custom_minimum_size = Vector2(460.0, 48.0)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_theme_stylebox_override("panel", _make_panel_style())
	root.add_child(top_panel)

	_top_bar = Label.new()
	_top_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_bar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_bar.add_theme_font_size_override("font_size", 22)
	top_panel.add_child(_top_bar)

	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 18.0
	bottom_panel.offset_top = -96.0
	bottom_panel.offset_right = -18.0
	bottom_panel.offset_bottom = -18.0
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_panel.add_theme_stylebox_override("panel", _make_panel_style())
	root.add_child(bottom_panel)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 10)
	bottom_panel.add_child(bottom_row)

	_selected_label = Label.new()
	_selected_label.custom_minimum_size = Vector2(132.0, 56.0)
	_selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selected_label.add_theme_font_size_override("font_size", 22)
	bottom_row.add_child(_selected_label)

	_hint_label = Label.new()
	_hint_label.custom_minimum_size = Vector2(360.0, 56.0)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 20)
	bottom_row.add_child(_hint_label)

	_select_button = Button.new()
	_select_button.text = "SELECT"
	_select_button.toggle_mode = true
	_select_button.custom_minimum_size = Vector2(112.0, 58.0)
	_select_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_select_button.add_theme_font_size_override("font_size", 20)
	_select_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.08, 0.16, 0.22, 0.92)))
	_select_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.10, 0.24, 0.34, 0.96)))
	_select_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.06, 0.38, 0.68, 0.96)))
	_select_button.pressed.connect(Callable(self, "_on_select_pressed"))
	bottom_row.add_child(_select_button)

	_context_panel = HBoxContainer.new()
	_context_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_context_panel.add_theme_constant_override("separation", 10)
	bottom_row.add_child(_context_panel)

	_selection_rect = ColorRect.new()
	_selection_rect.name = "SelectionRect"
	_selection_rect.color = Color(0.1, 0.55, 1.0, 0.22)
	_selection_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_rect.visible = false
	root.add_child(_selection_rect)

func _on_select_pressed() -> void:
	select_mode_requested.emit()

func _on_worker_build_pressed(building_id: String) -> void:
	worker_build_requested.emit(building_id)

func _on_hq_worker_pressed() -> void:
	hq_worker_requested.emit()

func _on_cancel_placement_pressed() -> void:
	placement_cancel_requested.emit()

func _clear_context_panel() -> void:
	if not is_instance_valid(_context_panel):
		return
	for child in _context_panel.get_children():
		child.queue_free()

func _add_context_button(label: String, method_name: String, bind_value: String = "") -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(104.0, 58.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.08, 0.16, 0.22, 0.92)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.10, 0.24, 0.34, 0.96)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.06, 0.38, 0.68, 0.96)))
	if bind_value.is_empty():
		button.pressed.connect(Callable(self, method_name))
	else:
		button.pressed.connect(Callable(self, method_name).bind(bind_value))
	_context_panel.add_child(button)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.04, 0.78)
	style.border_color = Color(0.16, 0.42, 0.62, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.18, 0.58, 0.90, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _format_money(value: int) -> String:
	var raw := str(value)
	var result := ""
	while raw.length() > 3:
		result = " " + raw.substr(raw.length() - 3, 3) + result
		raw = raw.substr(0, raw.length() - 3)
	return raw + result
