class_name TubeModel
extends RefCounted

## Logical layers are ordered bottom -> top. No Node or display colour here.
var layers: Array[int] = []


func _init(initial: Array[int] = []) -> void:
	layers = initial.duplicate()


func copy() -> TubeModel:
	return TubeModel.new(layers)


func top() -> int:
	return layers.back() if not layers.is_empty() else -1


func top_group_size() -> int:
	if layers.is_empty():
		return 0
	var colour: int = top()
	var count: int = 0
	for index: int in range(layers.size() - 1, -1, -1):
		if layers[index] != colour:
			break
		count += 1
	return count
