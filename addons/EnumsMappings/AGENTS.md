# EnumsMappings Addon Guidelines

## Purpose

This addon currently defines the game's shared enum types and persisted IDs.
The root `AGENTS.md` also applies. Because the enum meanings are game-specific,
changes must also follow `GAME.md`.

## Enum Contract

- Use singular `PascalCase` enum names.
- Use `UPPER_SNAKE_CASE` members.
- Assign explicit integer values to every persisted member.
- Never reorder, recycle, or silently renumber an existing persisted member.
- Append new persisted values.
- Renames require migration of maps, definitions, scenes, and every serialized
  reference.
- Keep one enum member per line and include a trailing comma.
- Document unusual ordering or intentionally retained legacy spelling.

## Dependency Direction

- This addon must not import game code or other addons.
- Game code may use these enums directly.
- Standalone addons must not import this addon. The game must translate enum
  values into addon-owned configuration contracts.
- Do not add utility behavior here merely because many systems need it. Keep
  this package limited to stable taxonomy and mapping helpers.

## Editor Plugin

- Decide whether the custom `EnumMappings` node type is actually required
  before expanding the editor integration.
- Keep custom type registration and removal symmetric.
- Do not require a node instance merely to access enum values.

## Verification

- Search all code, JSON, and scenes for uses of a changed enum.
- Verify existing numeric values before and after the change.
- Validate all affected persisted data and migrations.
- Enable, disable, and re-enable the editor plugin.
