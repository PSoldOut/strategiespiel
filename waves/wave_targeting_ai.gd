extends Resource
class_name WaveTargetingAI

## Primitive, decoupled targeting AI for enemy waves.
##
## The AI knows nothing about Game, scenes or signals. It receives three plain
## arrays and answers exactly one question: "who attacks whom?"
##
## Input:
##   attackers        - nodes that will receive an attack order
##   player_units     - units of the player
##   player_buildings - buildings of the player
##
## Output:
##   A dictionary mapping an attacker node to its target node.
##
## The system that owns the wave (WaveSystem) decides when to call this and
## applies the result. This keeps targeting separable and testable.

## Extra distance cost for buildings. Lower values make the player's base more
## attractive; 0.0 treats buildings exactly like units.
@export var building_distance_bias: float = 6.0

## How many attackers should preferably share one target before the AI looks
## for another one. Avoids all enemies running after the same single unit.
@export var max_attackers_per_target: int = 3

## Distance cost for each attacker already assigned to a target.
@export var crowd_penalty: float = 4.0


## Returns { attacker_node: target_node } for every attacker that got a target.
func assign_targets(
	attackers: Array,
	player_units: Array,
	player_buildings: Array
) -> Dictionary:
	var assignments := {}
	var targets: Array[Node] = []
	for unit in player_units:
		_add_target(targets, unit)
	for building in player_buildings:
		_add_target(targets, building)
	if targets.is_empty():
		return assignments

	var assigned_count: Dictionary = {}
	for attacker in attackers:
		var attacker_node := attacker as Node3D
		if attacker_node == null or not is_instance_valid(attacker_node):
			continue
		var target := _pick_target(attacker_node, targets, assigned_count)
		if target == null:
			continue
		assignments[attacker_node] = target
		assigned_count[target] = int(assigned_count.get(target, 0)) + 1
	return assignments


## Human-readable form of an assignment dictionary, useful for debugging.
func describe_assignments(assignments: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for attacker in assignments.keys():
		var attacker_node := attacker as Node
		var target_node := assignments[attacker] as Node
		if attacker_node == null or target_node == null:
			continue
		lines.append("%s -> %s" % [attacker_node.name, target_node.name])
	return lines


func _add_target(targets: Array[Node], candidate: Variant) -> void:
	var node := candidate as Node3D
	if node == null or not is_instance_valid(node):
		return
	# Buildings and units both expose take_damage; resource deposits do not.
	if not node.has_method("take_damage"):
		return
	targets.append(node)


func _pick_target(attacker: Node3D, targets: Array[Node], assigned_count: Dictionary) -> Node:
	var best: Node = null
	var best_score := INF
	for target in targets:
		if not is_instance_valid(target):
			continue
		var count := int(assigned_count.get(target, 0))
		if count >= max_attackers_per_target:
			continue
		var score := attacker.global_position.distance_to(target.global_position)
		if target is Building:
			score += building_distance_bias
		score += float(count) * crowd_penalty
		if score < best_score:
			best_score = score
			best = target

	if best != null:
		return best

	# Every target is already crowded: overloading is better than idling.
	for target in targets:
		if is_instance_valid(target):
			return target
	return null
