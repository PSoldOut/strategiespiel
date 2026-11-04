# Follow Camera

A standalone Godot 4.6 addon for smoothly following a `Node3D` with a
`Camera3D`. It has no input handling, autoload, game-code, or other-addon
dependencies.

## Installation

Copy `addons/follow_camera/` into a Godot 4.6 project and enable **Follow
Camera** under **Project > Project Settings > Plugins**. Enabling the plugin
adds `FollowCameraConfig` and `FollowCamera3D` to the Create Node/Resource
dialogs. The runtime classes also work through `class_name` when the plugin is
disabled.

## Usage

1. Add a `FollowCamera3D` node.
2. Assign the `target` to a `Node3D`.
3. Create and assign a `FollowCameraConfig` resource.
4. Adjust `offset`, `look_at_offset`, and the smoothing speeds.

`offset_space` controls the position offset:

- `WORLD` keeps `offset` aligned with world axes.
- `TARGET` rotates `offset` with the target while ignoring target scale.

`look_at_offset` is always in world space. Smoothing speeds are exponential
rates in inverse seconds, making behavior consistent across frame rates. A
speed of zero leaves that transform component unchanged. Set
`require_current_camera` to update only while this camera is current.

Call `snap_to_target()` after teleports or other discontinuous movement. It
updates immediately even when smooth following is disabled or the camera is
not current. A valid target is snapped once when the camera becomes ready; if
there is no valid target, the scene-authored transform is preserved.

## Test

From a project containing only this addon, run:

```sh
godot --headless --path . --script \
  res://addons/follow_camera/tests/follow_camera_test.gd
```
