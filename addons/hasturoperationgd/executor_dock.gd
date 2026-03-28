@tool
extends Control


var _code_edit: CodeEdit
var _result_edit: CodeEdit
var _executor: GDScriptExecutor
var _status_label: Label
var _id_label: LineEdit
var _history_list: ItemList
var _history: Array = []
var _max_history: int = 50
var _broker_client: BrokerClient


func _ready() -> void:
	_executor = GDScriptExecutor.new()

	var broker_host = HasturOperationGDPluginSettings.get_broker_host()
	var broker_port = HasturOperationGDPluginSettings.get_broker_port()
	_broker_client = BrokerClient.new(broker_host, broker_port)
	_broker_client.connection_established.connect(_on_connection_established)
	_broker_client.connection_lost.connect(_on_connection_lost)
	_broker_client.remote_execution_completed.connect(_on_remote_execution)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var status_bar = HBoxContainer.new()
	_status_label = Label.new()
	_status_label.text = "Disconnected"
	_status_label.add_theme_color_override("font_color", Color.RED)
	status_bar.add_child(_status_label)

	_id_label = LineEdit.new()
	_id_label.text = ""
	_id_label.visible = false
	_id_label.editable = false
	_id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_label.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_id_label.custom_minimum_size = Vector2(200, 0)
	_id_label.tooltip_text = "Click and Ctrl+C to copy"
	status_bar.add_child(_id_label)
	vbox.add_child(status_bar)

	_code_edit = CodeEdit.new()
	_code_edit.custom_minimum_size = Vector2(0, 200)
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_code_edit)

	var button = Button.new()
	button.text = "Execute"
	button.pressed.connect(_on_execute_pressed)
	vbox.add_child(button)

	_result_edit = CodeEdit.new()
	_result_edit.custom_minimum_size = Vector2(0, 100)
	_result_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_edit.editable = false
	_result_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_result_edit)

	var history_vbox = VBoxContainer.new()
	history_vbox.custom_minimum_size = Vector2(0, 100)
	history_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var history_header = HBoxContainer.new()
	var history_title = Label.new()
	history_title.text = "Execution History"
	history_header.add_child(history_title)

	var clear_button = Button.new()
	clear_button.text = "Clear History"
	clear_button.pressed.connect(_on_clear_history)
	history_header.add_child(clear_button)
	history_vbox.add_child(history_header)

	_history_list = ItemList.new()
	_history_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_list.item_selected.connect(_on_history_selected)
	history_vbox.add_child(_history_list)

	vbox.add_child(history_vbox)


func _process(delta: float) -> void:
	if _broker_client:
		_broker_client.poll(delta)


func _on_execute_pressed() -> void:
	var code = _code_edit.text
	var start_time = Time.get_ticks_msec()
	var result = _executor.execute_code(code)
	var end_time = Time.get_ticks_msec()
	var duration_ms = end_time - start_time
	_display_result(result)
	_add_history(code, result, duration_ms, "local")


func _display_result(result: Dictionary) -> void:
	var text = ""

	if result.compile_success:
		text += "Compile: SUCCESS\n"
	else:
		text += "Compile: FAILED\n"
		text += result.compile_error + "\n"

	if not result.compile_success:
		text += "Run: (skipped)\n"
	elif result.run_success:
		text += "Run: SUCCESS\n"
	else:
		text += "Run: FAILED\n"
		text += result.run_error + "\n"

	if result.outputs.size() > 0:
		text += "---\n"
		text += "Output:\n"
		for entry in result.outputs:
			text += str(entry[0]) + ": " + str(entry[1]) + "\n"

	_result_edit.text = text


func _on_connection_established(id: String) -> void:
	_status_label.text = "Connected"
	_status_label.add_theme_color_override("font_color", Color.GREEN)
	_id_label.text = "ID: " + id
	_id_label.visible = true


func _on_connection_lost() -> void:
	_status_label.text = "Disconnected"
	_status_label.add_theme_color_override("font_color", Color.RED)
	_id_label.text = ""
	_id_label.visible = false


func _add_history(code: String, result: Dictionary, duration_ms: int, source: String) -> void:
	var entry = {
		"code": code,
		"result": result,
		"timestamp": Time.get_time_string_from_system(),
		"duration_ms": duration_ms,
		"source": source
	}
	_history.append(entry)
	if _history.size() > _max_history:
		_history.pop_front()
	_refresh_history_list()


func _refresh_history_list() -> void:
	_history_list.clear()
	for entry in _history:
		var preview = entry.code.split("\n")[0]
		if preview.length() > 60:
			preview = preview.substr(0, 60) + "..."
		var status_str = "OK"
		if not entry.result.get("compile_success", false):
			status_str = "FAIL"
		elif not entry.result.get("run_success", false):
			status_str = "FAIL"
		var source_str = entry.source
		var display = "%s [%s] %s - %dms (%s)" % [preview, status_str, entry.timestamp, entry.duration_ms, source_str]
		_history_list.add_item(display)


func _on_history_selected(index: int) -> void:
	if index < 0 or index >= _history.size():
		return
	var entry = _history[index]
	_code_edit.text = entry.code
	_display_result(entry.result)


func _on_clear_history() -> void:
	_history.clear()
	_history_list.clear()


func _on_remote_execution(code: String, result: Dictionary, duration_ms: int) -> void:
	_add_history(code, result, duration_ms, "remote")


func _get_broker_client() -> BrokerClient:
	return _broker_client
