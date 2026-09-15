class_name MatchHud
extends CanvasLayer

signal build_requested(building_id: String)
signal placement_confirmed
signal placement_cancelled
signal production_requested(unit_id: String)
signal production_cancel_requested
signal army_filter_requested(filter_id: String, visible_only: bool)
signal army_command_requested(command_id: String)
signal group_selected(group_id: int)
signal group_saved(group_id: int)

var money := 10000
var power_current := 0
var power_max := 0
var unit_count := 1
var unit_cap := 60
var selected_count := 0
var selected_label := "None"

var _top_bar: Label
var _selection_label: Label
var _hint_label: Label
var _context_panel: HBoxContainer
var _builder_panel: HBoxContainer
var _placement_panel: HBoxContainer
var _production_panel: HBoxContainer
var _production_status: Label
var _army_panel: HBoxContainer
var _army_visible_toggle: CheckButton
var _interactive_controls: Array[Control] = []
var _building_buttons: Dictionary = {}
var _unit_buttons: Dictionary = {}
var _group_buttons: Dictionary = {}
var _group_press_started_at: Dictionary = {}

func _ready() -> void:
	_build_ui()
	update_match_stats(money, power_current, power_max, unit_count, unit_cap)
	update_selection(0, "None")

func update_match_stats(new_money: int, current_power: int, max_power: int, units: int, cap: int) -> void:
	money = new_money
	power_current = current_power
	power_max = max_power
	unit_count = units
	unit_cap = cap
	if is_instance_valid(_top_bar):
		_top_bar.text = "$ %s | Power %d/%d | Units %d/%d | 00:00" % [_format_money(money), power_current, power_max, unit_count, unit_cap]

func update_selection(count: int, label: String) -> void:
	selected_count = count
	selected_label = label
	if is_instance_valid(_selection_label):
		if count == 0:
			_selection_label.text = "Selected: none"
		elif count == 1:
			_selection_label.text = "Selected: %s" % label
		else:
			_selection_label.text = "Selected: %d units" % count

func show_builder_controls(enabled: bool) -> void:
	if is_instance_valid(_builder_panel):
		_builder_panel.visible = enabled
	if is_instance_valid(_placement_panel):
		_placement_panel.visible = false
	if is_instance_valid(_production_panel):
		_production_panel.visible = false
	if is_instance_valid(_army_panel):
		_army_panel.visible = false
	_set_default_hint()

func show_placement_controls(building_name: String, valid: bool) -> void:
	if is_instance_valid(_builder_panel):
		_builder_panel.visible = false
	if is_instance_valid(_placement_panel):
		_placement_panel.visible = true
	if is_instance_valid(_production_panel):
		_production_panel.visible = false
	if is_instance_valid(_army_panel):
		_army_panel.visible = false
	_set_hint("Placing %s: %s" % [building_name, "valid location" if valid else "blocked location"])

func show_production_controls(building_name: String, available_units: Array, queue_names: Array[String], progress: float) -> void:
	if is_instance_valid(_builder_panel):
		_builder_panel.visible = false
	if is_instance_valid(_placement_panel):
		_placement_panel.visible = false
	if is_instance_valid(_production_panel):
		_production_panel.visible = true
	if is_instance_valid(_army_panel):
		_army_panel.visible = false

	for unit_id in _unit_buttons.keys():
		var button := _unit_buttons[unit_id] as Button
		button.visible = _unit_is_available(available_units, unit_id)
		if button.visible:
			var data := _unit_data_from_list(available_units, unit_id)
			button.text = "%s\n$%d" % [str(data.get("name", unit_id)), int(data.get("price", 0))]

	if is_instance_valid(_production_status):
		var queue_text := "Queue empty" if queue_names.is_empty() else "Queue: " + _join_strings(queue_names, ", ")
		if progress > 0.0 and not queue_names.is_empty():
			queue_text += " | %d%%" % int(round(progress * 100.0))
		_production_status.text = "%s | %s" % [building_name, queue_text]
	_set_hint("Select production. Units spawn beside the building when ready.")

func show_army_controls(count: int) -> void:
	if is_instance_valid(_builder_panel):
		_builder_panel.visible = false
	if is_instance_valid(_placement_panel):
		_placement_panel.visible = false
	if is_instance_valid(_production_panel):
		_production_panel.visible = false
	if is_instance_valid(_army_panel):
		_army_panel.visible = true
	_set_hint("Army selected: %d. Use commands or quick filters." % count)

func set_hint(message: String) -> void:
	_set_hint(message)

func set_build_button_enabled(building_id: String, enabled: bool) -> void:
	if _building_buttons.has(building_id):
		var button := _building_buttons[building_id] as Button
		button.disabled = not enabled

func set_unit_button_enabled(unit_id: String, enabled: bool) -> void:
	if _unit_buttons.has(unit_id):
		var button := _unit_buttons[unit_id] as Button
		button.disabled = not enabled

func set_group_count(group_id: int, count: int) -> void:
	if _group_buttons.has(group_id):
		var button := _group_buttons[group_id] as Button
		button.text = "%d\n%d" % [group_id, count]

func is_screen_position_over_ui(screen_position: Vector2) -> bool:
	for control in _interactive_controls:
		if control.visible and control.get_global_rect().has_point(screen_position):
			return true
	return false

func _build_ui() -> void:
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var safe_margin := 18.0

	var top_panel := PanelContainer.new()
	top_panel.name = "TopPanel"
	top_panel.position = Vector2(safe_margin, safe_margin)
	top_panel.custom_minimum_size = Vector2(700.0, 54.0)
	root.add_child(top_panel)
	_interactive_controls.append(top_panel)

	_top_bar = Label.new()
	_top_bar.name = "TopStats"
	_top_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_bar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_top_bar.add_theme_font_size_override("font_size", 24)
	top_panel.add_child(_top_bar)

	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = safe_margin
	bottom_panel.offset_top = -118.0
	bottom_panel.offset_right = -safe_margin
	bottom_panel.offset_bottom = -safe_margin
	root.add_child(bottom_panel)
	_interactive_controls.append(bottom_panel)

	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 20)
	bottom_panel.add_child(bottom_row)

	_selection_label = Label.new()
	_selection_label.custom_minimum_size = Vector2(320.0, 76.0)
	_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_selection_label.add_theme_font_size_override("font_size", 24)
	bottom_row.add_child(_selection_label)

	_hint_label = Label.new()
	_hint_label.text = "Tap Builder to select. Tap terrain to move. Pinch to zoom."
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 22)
	bottom_row.add_child(_hint_label)

	_context_panel = HBoxContainer.new()
	_context_panel.name = "ContextPanel"
	_context_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_context_panel.add_theme_constant_override("separation", 10)
	bottom_row.add_child(_context_panel)

	_builder_panel = HBoxContainer.new()
	_builder_panel.name = "BuilderPanel"
	_builder_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_builder_panel.add_theme_constant_override("separation", 10)
	_builder_panel.visible = false
	_context_panel.add_child(_builder_panel)

	_add_category_label("Economy")
	_add_build_button("Power Plant", "power_plant", 800)
	_add_build_button("Resource Center", "resource_center", 1200)
	_add_category_label("Military")
	_add_build_button("Barracks", "barracks", 1000)
	_add_build_button("War Factory", "war_factory", 2000)
	_add_category_label("Defense")
	_add_build_button("Turret", "defense_turret", 900)

	_placement_panel = HBoxContainer.new()
	_placement_panel.name = "PlacementPanel"
	_placement_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_placement_panel.add_theme_constant_override("separation", 10)
	_placement_panel.visible = false
	_context_panel.add_child(_placement_panel)

	var confirm_button := _make_button("Confirm")
	confirm_button.pressed.connect(Callable(self, "_on_confirm_pressed"))
	_placement_panel.add_child(confirm_button)

	var cancel_button := _make_button("Cancel")
	cancel_button.pressed.connect(Callable(self, "_on_cancel_pressed"))
	_placement_panel.add_child(cancel_button)

	_production_panel = HBoxContainer.new()
	_production_panel.name = "ProductionPanel"
	_production_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_production_panel.add_theme_constant_override("separation", 10)
	_production_panel.visible = false
	_context_panel.add_child(_production_panel)

	_production_status = Label.new()
	_production_status.custom_minimum_size = Vector2(300.0, 64.0)
	_production_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_production_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_production_status.add_theme_font_size_override("font_size", 18)
	_production_panel.add_child(_production_status)

	_add_unit_button("Rifleman", "rifleman", 150)
	_add_unit_button("RPG", "rpg_soldier", 300)
	_add_unit_button("Tank", "main_battle_tank", 900)

	var cancel_queue_button := _make_button("Cancel\nQueue")
	cancel_queue_button.pressed.connect(Callable(self, "_on_cancel_production_pressed"))
	_production_panel.add_child(cancel_queue_button)

	_army_panel = HBoxContainer.new()
	_army_panel.name = "ArmyPanel"
	_army_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_army_panel.add_theme_constant_override("separation", 8)
	_army_panel.visible = false
	_context_panel.add_child(_army_panel)

	_army_visible_toggle = CheckButton.new()
	_army_visible_toggle.text = "Visible"
	_army_visible_toggle.button_pressed = false
	_army_visible_toggle.custom_minimum_size = Vector2(96.0, 64.0)
	_army_visible_toggle.add_theme_font_size_override("font_size", 18)
	_army_panel.add_child(_army_visible_toggle)

	_add_army_filter_button("All", "all")
	_add_army_filter_button("Infantry", "infantry")
	_add_army_filter_button("RPG", "rpg")
	_add_army_filter_button("Tanks", "tanks")

	for group_id in range(1, 5):
		_add_group_button(group_id)

	_add_army_command_button("Move", "move")
	_add_army_command_button("Attack\nMove", "attack_move")
	_add_army_command_button("Attack", "attack")
	_add_army_command_button("Stop", "stop")

func _format_money(value: int) -> String:
	var raw := str(value)
	var result := ""
	while raw.length() > 3:
		result = " " + raw.substr(raw.length() - 3, 3) + result
		raw = raw.substr(0, raw.length() - 3)
	return raw + result

func _add_category_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	_builder_panel.add_child(label)

func _add_build_button(label: String, building_id: String, cost: int) -> void:
	var button := _make_button("%s\n$%d" % [label, cost])
	button.pressed.connect(Callable(self, "_on_build_pressed").bind(building_id))
	_builder_panel.add_child(button)
	_building_buttons[building_id] = button

func _add_unit_button(label: String, unit_id: String, cost: int) -> void:
	var button := _make_button("%s\n$%d" % [label, cost])
	button.visible = false
	button.pressed.connect(Callable(self, "_on_unit_pressed").bind(unit_id))
	_production_panel.add_child(button)
	_unit_buttons[unit_id] = button

func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(112.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 18)
	return button

func _on_build_pressed(building_id: String) -> void:
	build_requested.emit(building_id)

func _on_confirm_pressed() -> void:
	placement_confirmed.emit()

func _on_cancel_pressed() -> void:
	placement_cancelled.emit()

func _on_unit_pressed(unit_id: String) -> void:
	production_requested.emit(unit_id)

func _on_cancel_production_pressed() -> void:
	production_cancel_requested.emit()

func _on_army_filter_pressed(filter_id: String) -> void:
	army_filter_requested.emit(filter_id, _army_visible_toggle.button_pressed if is_instance_valid(_army_visible_toggle) else false)

func _on_army_command_pressed(command_id: String) -> void:
	army_command_requested.emit(command_id)

func _on_group_button_down(group_id: int) -> void:
	_group_press_started_at[group_id] = Time.get_ticks_msec()

func _on_group_button_up(group_id: int) -> void:
	var started_at := int(_group_press_started_at.get(group_id, Time.get_ticks_msec()))
	_group_press_started_at.erase(group_id)
	if Time.get_ticks_msec() - started_at >= 550:
		group_saved.emit(group_id)
	else:
		group_selected.emit(group_id)

func _set_default_hint() -> void:
	_set_hint("Tap Builder to select. Tap terrain to move. Pinch to zoom.")

func _set_hint(message: String) -> void:
	if is_instance_valid(_hint_label):
		_hint_label.text = message

func _unit_data_from_list(available_units: Array, unit_id: String) -> Dictionary:
	for item in available_units:
		if str(item.get("id", "")) == unit_id:
			return item
	return {}

func _unit_is_available(available_units: Array, unit_id: String) -> bool:
	for item in available_units:
		if str(item.get("id", "")) == unit_id:
			return true
	return false

func _join_strings(values: Array[String], separator: String) -> String:
	var result := ""
	for index in values.size():
		if index > 0:
			result += separator
		result += values[index]
	return result

func _add_army_filter_button(label: String, filter_id: String) -> void:
	var button := _make_button(label)
	button.pressed.connect(Callable(self, "_on_army_filter_pressed").bind(filter_id))
	_army_panel.add_child(button)

func _add_army_command_button(label: String, command_id: String) -> void:
	var button := _make_button(label)
	button.pressed.connect(Callable(self, "_on_army_command_pressed").bind(command_id))
	_army_panel.add_child(button)

func _add_group_button(group_id: int) -> void:
	var button := _make_button("%d\n0" % group_id)
	button.custom_minimum_size = Vector2(64.0, 64.0)
	button.button_down.connect(Callable(self, "_on_group_button_down").bind(group_id))
	button.button_up.connect(Callable(self, "_on_group_button_up").bind(group_id))
	_army_panel.add_child(button)
	_group_buttons[group_id] = button
