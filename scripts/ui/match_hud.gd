class_name MatchHud
extends CanvasLayer

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
var _interactive_controls: Array[Control] = []

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

func _format_money(value: int) -> String:
	var raw := str(value)
	var result := ""
	while raw.length() > 3:
		result = " " + raw.substr(raw.length() - 3, 3) + result
		raw = raw.substr(0, raw.length() - 3)
	return raw + result

