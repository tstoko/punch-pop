class_name MatchSystem
extends RefCounted

const NEIGHBOURS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

static func groups(board: BoardManager) -> Array:
	var visited := {}
	var matches: Array = []
	for y in BoardManager.HEIGHT:
		for x in BoardManager.WIDTH:
			var start := Vector2i(x, y)
			var color := board.at(start)
			if color == BoardManager.EMPTY or visited.has(start):
				continue
			var group: Array = []
			var stack: Array = [start]
			visited[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				group.append(p)
				for offset in NEIGHBOURS:
					var neighbour: Vector2i = p + offset
					if board.inside(neighbour) and board.at(neighbour) == color and not visited.has(neighbour):
						visited[neighbour] = true
						stack.append(neighbour)
			if group.size() >= 4:
				matches.append(group)
	return matches
