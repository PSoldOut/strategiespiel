extends Resource
class_name ContentRequirement

## One condition that has to be fulfilled before a building, ability or upgrade
## becomes available. The game builds the context; this resource only stores
## the condition.

enum Kind {
	BUILDING, ## A constructed building of the player's team.
	TAG, ## An abstract technology tag unlocked by the game.
	UPGRADE, ## An upgrade already researched by the player's team.
}

@export var kind: Kind = Kind.BUILDING
@export var id: StringName = &""
## When true the condition is fulfilled if the id is absent. Useful for
## one-time upgrades that should disappear after they were applied.
@export var negated: bool = false


static func make(
	p_kind: Kind,
	p_id: StringName,
	p_negated: bool = false
) -> ContentRequirement:
	var requirement := ContentRequirement.new()
	requirement.kind = p_kind
	requirement.id = p_id
	requirement.negated = p_negated
	return requirement
