class_name GravitySystem
extends RefCounted

# Stable compaction. Returned movements drive visuals after the rule calculation.
static func apply(board: BoardManager) -> Array:
	var movements: Array = []
	for x in BoardManager.WIDTH:
		var target := BoardManager.HEIGHT - 1
		for y in range(BoardManager.HEIGHT - 1, -1, -1):
			var p := Vector2i(x, y)
			var color := board.at(p)
			if color == BoardManager.EMPTY:
				continue
			if target != y:
				board.put(Vector2i(x, target), color)
				board.put(p, BoardManager.EMPTY)
				movements.append({"from": p, "to": Vector2i(x, target), "color": color})
			target -= 1
	return movements
