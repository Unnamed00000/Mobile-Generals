class_name MatchHud
extends CanvasLayer

signal build_requested(building_id: String)
signal placement_confirmed
signal placement_cancelled

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
var _interactive_controls: Array[Control] = []
var _building_buttons: Dictionary = {}

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
	_set_default_hint()

func show_placement_controls(building_name: String, valid: bool) -> void:
	if is_instance_valid(_builder_panel):
		_builder_panel.visible = false
	if is_instance_valid(_placement_panel):
		_placement_panel.visible = true
	_set_hint("Placing %s: %s" % [building_name, "valid location" if valid else "blocked location"])

func set_hint(message: String) -> void:
	_set_hint(message)

func set_build_button_enabled(building_id: String, enabled: bool) -> void:
	if _building_buttons.has(building_id):
		var button := _building_buttons[building_id] as Button
		button.disabled = not enabled

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

func _set_default_hint() -> void:
	_set_hint("Tap Builder to select. Tap terrain to move. Pinch to zoom.")

func _set_hint(message: String) -> void:
	if is_instance_valid(_hint_label):
		_hint_label.text = message
