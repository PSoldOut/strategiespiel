# EntityDatabase Addon Guidelines

## Purpose

This addon provides a stable lookup API for resource, building, and unit
archetype definitions loaded from JSON. It is intended to hide the storage
format from consumers. The root `AGENTS.md` also applies.

## Public Contract

- `entity_database_plugin.gd` owns optional autoload registration.
- `entity_database.gd` owns loading, validation, and lookup behavior.
- Keep callers behind methods such as `load_definitions()`, `is_loaded()`, and
  the resource, building, and unit lookup methods.
- Return documented fallback values for unknown IDs and malformed entries.
- Do not expose the mutable internal dictionary directly unless mutation is an
  intentional API guarantee.

## Standalone Boundary

- Do not depend directly on `EnumMappings` or any other game class.
- Accept game IDs and name mappings through an addon-owned configuration
  `Resource`, a dictionary contract, or explicit method arguments.
- Keep the addon functional with its own example/default definition data.
- All default paths must use the exact `EntityDatabase` directory casing.
- The game is responsible for adapting its persisted enum IDs to this API.

## Definition Schema

- Choose one canonical key format and use it consistently. Do not mix symbolic
  keys such as `GOLD` with numeric string keys such as `"1"`.
- Store stable machine identifiers separately from display names.
- Use lowercase `snake_case` string IDs for resources, buildings, and units.
- Use `StringName` constants for stable schema keys used repeatedly in code.
- Validate the JSON root and every required field before publishing loaded
  definitions.
- Schema changes require a documented version and migration strategy.

## Unit Stats And Balance

- Unit archetypes define `range`, `speed`, `life`, and `damage` as relative
  `LOW`, `NORMAL`, or `HIGH` tiers.
- Keep the tier names synchronized with the addon-local `StatTier` enum.
- Do not store final numeric combat stats in the archetype database.
- Enemy stat resolution belongs to game-owned wave and difficulty balance
  configuration.
- Friendly stat resolution belongs to game-owned base balance plus the active
  run's upgrade modifiers.
- Do not define Vampire Survivors-style modifiers in this database. Modifiers
  need their own IDs, operations, stacking rules, targets, and runtime state.
- Unit definitions may later expose stable tags for modifier targeting, but
  they must not contain a run's selected or accumulated modifiers.

## Plugin Lifecycle

- Keep autoload installation and removal symmetric.
- Use a `PascalCase` autoload name.
- Enabling or disabling the plugin must not modify definition files.
- Make the ownership of an existing user-configured autoload explicit; do not
  remove an autoload the plugin did not create.

## Compatibility

- Schema version 1 uses stable string IDs and has no dependency on
  `EnumMappings`.
- The game must translate persisted numeric IDs to these string IDs at the
  integration boundary.
- Do not reintroduce the legacy `NONE`, `STONE`, `HOUSE`, or numeric-key schema.

## Verification

- Test valid, missing, unreadable, malformed, and empty JSON files.
- Test known and unknown IDs, fallback values, sorting, faction filtering, and
  every stat tier.
- Validate that every unit contains all four required stats and a valid
  faction.
- Enable, disable, and re-enable the plugin in a minimal Godot 4.6 project.
- Confirm the addon works without game code or another addon installed.
