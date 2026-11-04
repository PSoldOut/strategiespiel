# Follow Camera Addon Guidelines

## Purpose

This addon provides a configurable 3D camera that follows a `Node3D` without
owning input, game state, or target selection. The root `AGENTS.md` also
applies.

## Standalone Boundary

- Depend only on Godot and files inside `addons/follow_camera/`.
- Do not reference game code, autoloads, input actions, or other addons.
- Receive the followed node through the exported `target` property.
- Keep camera behavior in `FollowCameraConfig` rather than game-specific code.

## Runtime Contract

- `FollowCameraConfig` owns offsets, smoothing speeds, enablement, and offset
  space.
- `FollowCamera3D` follows only valid `Node3D` targets.
- World offset mode never rotates the position offset with the target.
- Target offset mode rotates the position offset with the target, ignoring its
  scale.
- `look_at_offset` is always expressed in world space.
- `snap_to_target()` updates immediately and remains available while smooth
  following is disabled.
- Invalid targets and degenerate look directions must not corrupt the camera
  transform.

## Plugin Lifecycle

- Register the config resource before the camera custom type.
- Remove custom types in reverse order.
- Runtime classes must remain usable without enabling the editor plugin.

## Verification

- Run the headless SceneTree test in an isolated Godot 4.6 project.
- Verify snap, world offset behavior, exponential smoothing, disabled
  following, and safe handling of invalid and degenerate targets.
