extends AbilityDefinition
class_name SetRallyPointAbility

## Puts the selected building into rally-point targeting mode.
##
## The resource only marks the ability as a rally-point command. Game.gd
## handles the right-click that chooses the world position, and AbilitySystem
## stores the resulting point for the source building.
