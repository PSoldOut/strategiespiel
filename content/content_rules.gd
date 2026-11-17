extends RefCounted
class_name ContentRules

## Pure evaluation helpers for content requirements. No game nodes allowed here.


static func is_met(requirement: ContentRequirement, context: ContentContext) -> bool:
	if requirement == null or context == null:
		return false

	var fulfilled: bool = false
	match requirement.kind:
		ContentRequirement.Kind.BUILDING:
			fulfilled = context.owned_buildings.has(requirement.id)
		ContentRequirement.Kind.TAG:
			fulfilled = context.unlocked_tags.has(requirement.id)
		ContentRequirement.Kind.UPGRADE:
			fulfilled = context.upgrades.has(requirement.id)

	if requirement.negated:
		return not fulfilled
	return fulfilled


static func are_met(
	requirements: Array[ContentRequirement],
	context: ContentContext
) -> bool:
	for requirement in requirements:
		if not is_met(requirement, context):
			return false
	return true


static func can_use(ability: AbilityDefinition, context: ContentContext) -> bool:
	if ability == null:
		return false
	if not are_met(ability.requirements, context):
		return false
	return context != null and context.can_afford(ability.costs)


static func describe_requirement(
	requirement: ContentRequirement,
	content: GameContentCatalog
) -> String:
	if requirement == null:
		return ""

	match requirement.kind:
		ContentRequirement.Kind.BUILDING:
			var building: BuildingDefinition = null
			if content != null:
				building = content.get_building(requirement.id)
			var building_label: String = building.label if building != null else String(requirement.id)
			if requirement.negated:
				return "Darf nicht vorhanden sein: %s" % building_label
			return "Benötigt %s" % building_label
		ContentRequirement.Kind.TAG:
			if requirement.negated:
				return "Darf nicht freigeschaltet sein: %s" % String(requirement.id)
			return "Benötigt Technologie: %s" % String(requirement.id)
		ContentRequirement.Kind.UPGRADE:
			var upgrade: UpgradeDefinition = null
			if content != null:
				upgrade = content.get_upgrade(requirement.id)
			var upgrade_label: String = upgrade.label if upgrade != null else String(requirement.id)
			if requirement.negated:
				return "Noch nicht ausgebaut: %s" % upgrade_label
			return "Benötigt %s" % upgrade_label
	return ""
