# Agent Guidelines

## Scope

These rules apply to the entire repository. More specific instructions extend
them:

- Read `GAME.md` before changing game code, game scenes, project data, or
  `project.godot`.
- Read the nearest `addons/<addon>/AGENTS.md` before changing an addon.
- When instructions conflict, the file closest to the changed code wins.

Keep code, comments, identifiers, documentation, and commit messages in
English.

## Official References

Use the documentation for the project's Godot version as the baseline:

- [Godot 4.6 GDScript style guide](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Godot 4.6: Making plugins](https://docs.godotengine.org/en/4.6/tutorials/plugins/editor/making_plugins.html)

Repository instructions override the official guide only where an exception is
stated explicitly. Do not reformat unrelated legacy code while making a focused
change.

## Naming And Formatting

- Use UTF-8, LF line endings, tabs for GDScript indentation, and one final
  newline.
- Keep lines below 100 characters where practical.
- Use `snake_case` for files, directories, functions, variables, properties,
  and signals.
- Name signals in the past tense, such as `map_saved` or `state_changed`.
- Use a leading underscore for private fields and methods.
- Use `PascalCase` for classes, `class_name`, node names, enum types, and
  autoload names.
- Use `UPPER_SNAKE_CASE` for constants and enum members.
- Do not introduce `camelCase` identifiers except when an external API or a
  persisted data contract requires that exact spelling.
- Use `snake_case.gd` for a `PascalCase` named class.
- Use `snake_case` for new scene and addon directory names. Do not rename
  existing resources only to normalize their casing; Godot paths may break.
- Prefer static typing. Use `:=` when the type is unambiguous and explicit type
  annotations for public APIs, ambiguous expressions, and return values.
- Follow the declaration order from the official GDScript style guide.

## Values And Identifiers

- Use enums for finite states, modes, categories, and other closed domains.
- Give persisted enum members explicit integer values. Never reorder, recycle,
  or silently renumber persisted values.
- Do not compare raw strings to represent a state or category.
- Use named `StringName` constants for unavoidable identifiers such as input
  actions, groups, metadata keys, and stable dictionary keys.
- Replace magic numbers with a named constant or configuration property.
- Use enums for categorical numbers; use constants or configuration for
  measurements, limits, masks, speeds, sizes, and tuning values.
- Use Godot's built-in named constants instead of repeating their numeric
  values.

Example:

```gdscript
enum PlacementState {
	IDLE = 0,
	PREVIEW = 1,
	BLOCKED = 2,
}

const ACTION_PLACE := &"place_building"

@export var grid_size: float = 2.0
@export_flags_3d_physics var collision_mask: int = 1
```

## Standalone Addons

Every directory directly below `addons/` is an independently owned package.
Develop it so it can be copied into a minimal compatible Godot project.

- An addon may depend on Godot and files inside its own directory.
- An addon must not preload, load, extend, or reference game code outside its
  directory.
- Avoid dependencies between addons. If one is unavoidable, expose it as an
  explicit optional integration and document it in both addons.
- Never reference project-global enums directly from a standalone addon.
- Inject game-specific IDs, mappings, paths, input actions, masks, dimensions,
  and policies through a typed `Resource`, exported properties, call arguments,
  or a documented adapter API.
- Keep addon-internal states in addon-local enums.
- Give injected configuration safe defaults where a meaningful standalone
  default exists. Validate required configuration and fail with a clear error.
- Keep addon assets, icons, scenes, default resources, and documentation inside
  the addon directory.
- Keep the public API small, typed, and independent from concrete game scenes.
- Do not require a particular game autoload unless that integration is optional
  and injected behind an addon-owned interface.

A configuration resource should expose primitive Godot types and addon-owned
types rather than game classes:

```gdscript
class_name ExampleAddonConfig
extends Resource

@export var grid_size: float = 2.0
@export var category_ids: Dictionary[StringName, int] = {}
```

The game is responsible for translating its global enums into that contract.

## Editor Plugins

- Keep exactly one valid `plugin.cfg` entry point per plugin.
- The entry script must use `@tool` and extend `EditorPlugin`.
- Scripts executed by the editor must also use `@tool`.
- Treat paths as case-sensitive and keep every `res://` path consistent with
  the filesystem.
- Register resources in `_enter_tree()` or `_enable_plugin()` and perform the
  matching cleanup in `_exit_tree()` or `_disable_plugin()`.
- Keep `add_custom_type()` and `remove_custom_type()` symmetric.
- Keep autoload registration and removal symmetric. Disabling a plugin must not
  delete user-created data.
- Free docks, controls, previews, and temporary editor objects during cleanup.
- Ensure every global `class_name` is unique across the project.
- A plugin must tolerate enable, disable, and re-enable cycles.

## Godot Resources

- Treat `res://` paths, UIDs, node paths, signal connections, and resource IDs
  as part of the public project graph.
- Update scripts, scenes, resources, and plugin configuration together when a
  referenced file or node changes.
- Do not hand-edit `.godot/`, import caches, generated UID caches, or binary
  resource payloads.
- Avoid manual edits to scene UIDs, `unique_id`, subresource IDs, and packed
  array data.
- Inspect generated changes before keeping them. Do not commit unrelated editor
  churn.

## Verification

- Check changed paths for exact casing and valid `res://` references.
- Check that new `class_name` declarations are unique.
- Check plugin registration and cleanup as a pair.
- Validate changed JSON and other text data with an appropriate parser.
- Run `git diff --check` before finishing.
- Run Godot with the version used by the project. Prefer a temporary copy for
  import or editor checks when a run would modify caches or generated files.
- For addon changes, verify the addon independently as well as in the game.
