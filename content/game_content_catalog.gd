extends BuildingCatalog
class_name GameContentCatalog

## Single content database for the game.
##
## It extends the old BuildingCatalog so existing scenes can keep using the
## [code]building_catalog[/code] export slot while new code gets access to
## units, upgrades and abilities.

@export var units: Array[UnitDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []


func get_building(id: StringName) -> BuildingDefinition:
	for building in buildings:
		if building != null and building.id == id:
			return building
	return null


func get_unit(id: StringName) -> UnitDefinition:
	for unit in units:
		if unit != null and unit.id == id:
			return unit
	return null


func get_upgrade(id: StringName) -> UpgradeDefinition:
	for upgrade in upgrades:
		if upgrade != null and upgrade.id == id:
			return upgrade
	return null


## Looks up abilities attached to buildings or units.
func get_ability(id: StringName) -> AbilityDefinition:
	for building in buildings:
		if building == null:
			continue
		for ability in building.abilities:
			if ability != null and ability.id == id:
				return ability

	for unit in units:
		if unit == null:
			continue
		for ability in unit.abilities:
			if ability != null and ability.id == id:
				return ability
	return null
