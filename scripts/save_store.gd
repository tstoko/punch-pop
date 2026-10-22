class_name SaveStore
extends RefCounted

var path: String
var best := 0
var tutorial_done := false
var sound := true
var haptics := false
var reduced_motion := false
var high_contrast := false
var explain_clears := true
var round_data: Dictionary = {}
var undo_data: Dictionary = {}

func _init(save_path: String = "user://punch_pop.cfg") -> void:
	path = save_path

func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var record = config.get_value("player", "best", 0)
	best = maxi(0, record) if record is int else 0
	tutorial_done = config.get_value("player", "tutorial_done", false) == true and config.get_value("player", "tutorial_version", 0) == 2
	sound = config.get_value("settings", "sound", true) == true
	haptics = config.get_value("settings", "haptics", false) == true
	reduced_motion = config.get_value("settings", "reduced_motion", false) == true
	high_contrast = config.get_value("settings", "high_contrast", false) == true
	explain_clears = config.get_value("settings", "explain_clears", true) == true
	var round_value = config.get_value("round", "checkpoint", {})
	var undo_value = config.get_value("round", "undo", {})
	round_data = round_value if round_value is Dictionary and RoundModel.valid(round_value) else {}
	undo_data = undo_value if undo_value is Dictionary and RoundModel.valid(undo_value) else {}

func save_data() -> bool:
	var config := ConfigFile.new()
	config.set_value("player", "best", best)
	config.set_value("player", "tutorial_done", tutorial_done)
	config.set_value("player", "tutorial_version", 2)
	config.set_value("settings", "sound", sound)
	config.set_value("settings", "haptics", haptics)
	config.set_value("settings", "reduced_motion", reduced_motion)
	config.set_value("settings", "high_contrast", high_contrast)
	config.set_value("settings", "explain_clears", explain_clears)
	config.set_value("round", "checkpoint", round_data)
	config.set_value("round", "undo", undo_data)
	var error := config.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if error != OK:
		push_warning("Local save failed: %s" % error_string(error))
		return false
	return true
