class_name BoardManager
extends RefCounted

const WIDTH := 7
const HEIGHT := 9
const EMPTY := -1
var cells: Array = []

func _init() -> void:
	clear()

func clear() -> void:
	cells.clear()
	for y in HEIGHT:
		var row: Array = []
		row.resize(WIDTH)
		row.fill(EMPTY)
		cells.append(row)

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < WIDTH and p.y >= 0 and p.y < HEIGHT

func at(p: Vector2i) -> int:
	return cells[p.y][p.x] if inside(p) else EMPTY

func put(p: Vector2i, color: int) -> void:
	assert(inside(p))
	cells[p.y][p.x] = color

func remove(points: Array) -> void:
	for p in points:
		put(p, EMPTY)

func snapshot() -> Array:
	return cells.duplicate(true)

func occupied() -> int:
	var count := 0
	for row in cells:
		for color in row:
			if color != EMPTY:
				count += 1
	return count
