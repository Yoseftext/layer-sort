class_name WinRules
extends RefCounted


static func is_won(state: GameState) -> bool:
	for tube: TubeModel in state.tubes:
		if tube.layers.is_empty():
			continue
		if tube.layers.size() != state.capacity:
			return false
		var colour: int = tube.top()
		for layer: int in tube.layers:
			if layer != colour:
				return false
	return true
