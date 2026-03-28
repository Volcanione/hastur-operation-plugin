@tool
extends EditorPlugin


var _dock: EditorDock


func _enable_plugin() -> void:
	pass


func _disable_plugin() -> void:
	pass


func _enter_tree() -> void:
	HasturOperationGDPluginSettings.register_settings()
	_dock = EditorDock.new()
	_dock.title = "Hastur Executor"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UL
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	var dock_content = preload("executor_dock.gd").new()
	_dock.add_child(dock_content)
	add_dock(_dock)


func _exit_tree() -> void:
	if _dock:
		var dock_content = _dock.get_child(0)
		if dock_content and dock_content.has_method("_get_broker_client"):
			var broker_client = dock_content._get_broker_client()
			if broker_client:
				broker_client.disconnect_client()
	remove_dock(_dock)
	_dock.queue_free()
	_dock = null
