extends Node

## Runtime driver for the light registry; the editor preview is driven by plugin.gd.

const IsoLightRegistryScript := preload("res://addons/isolit/runtime/iso_light_registry.gd")

var _registry: IsoLightRegistry

func _ready() -> void:
	_registry = IsoLightRegistryScript.new()
	# Run after gameplay scripts have moved their lights this frame.
	process_priority = 1000

	_reload_settings()
	if not ProjectSettings.settings_changed.is_connected(_reload_settings):
		ProjectSettings.settings_changed.connect(_reload_settings)

	_boot_self_check()

func _boot_self_check() -> void:
	if not ResourceLoader.exists(IsoShaderLibrary.COMMON_INCLUDE_PATH):
		push_error("IsoLit: %s failed to resolve; the receiver shader cannot compile. If this is an exported build, add '*.gdshaderinc' to the export's resource filters." % IsoShaderLibrary.COMMON_INCLUDE_PATH)

func _process(_delta: float) -> void:
	_registry.refresh(get_tree(), get_viewport(), get_tree().root)

func _reload_settings() -> void:
	IsoProjection.reload_settings()
