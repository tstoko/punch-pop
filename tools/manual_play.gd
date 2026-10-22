extends SceneTree

func _initialize() -> void:
	call_deferred("play")

func play() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new("/private/tmp/punch-pop-manual.cfg")
	root.add_child(game)
	await process_frame
	game.start_game(true)
