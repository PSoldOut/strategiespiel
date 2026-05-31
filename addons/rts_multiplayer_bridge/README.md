# RTS Multiplayer Bridge

Reusable networking addon for RTS multiplayer games.

## Features
- Host / Join / Disconnect
- Match start and restart
- Pause / Resume synchronization
- Unit spawn replication
- Reinforcement requests for extra units
- Ping and packet counters
- Local IPv4 discovery and connection diagnostics

## Signals
- `status_changed(message)`
- `match_started_changed(started)`
- `pause_state_changed(paused)`
- `spawn_unit_requested(peer_id, slot, color)`
- `reinforcements_requested(peer_id, count)`
- `peer_left(peer_id)`
- `connection_state_changed(connected)`

## Minimal Usage
1. Enable the addon in the Godot editor.
2. Add the `RTSMultiplayerBridge` node to your RTS root scene or an autoload.
3. Connect the signals to your spawn and UI code.
4. Call:
   - `host_game(port)`
   - `join_game(address, port)`
   - `start_match_as_host()`
   - `request_pause_toggle()`
   - `request_reinforcements(count)`

## Recommended Pattern
- Keep unit spawning in your game scene.
- Use the bridge only for network state and RPC sync.
- Store ownership on units so selection and cleanup stay deterministic.
