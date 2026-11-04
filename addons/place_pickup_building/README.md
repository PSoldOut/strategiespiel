# Place Pickup Building

A standalone Godot 4.6 addon for a fixed inventory of unique buildings. Each
building alternates between held and placed state.

## Flow

1. Create one `PlaceableBuildingDefinition` per building.
2. Assign definitions and an optional parent to `PlacePickupBuildingSystem`.
3. Select a held building or cycle with configured InputMap actions.
4. Call `begin_preview()`.
5. Game code calculates a transform and calls `update_preview(transform, valid)`.
6. Call `confirm_placement()` or `cancel_preview()`.
7. Call `pickup_building()` to return a placed building to inventory.

The addon deliberately does not raycast or validate map occupancy. The game is
the authority for terrain, footprints, blocked decorations, navigation, costs,
and persistence policy.

The consuming game must define the configured selection actions in its
InputMap. Missing actions are ignored safely.

## Saving

Call `create_save_state()` and persist the returned
`PlacePickupBuildingSave` with the game's save system. After initialization,
call `restore_save_state()` to recreate placed instances and held state.
