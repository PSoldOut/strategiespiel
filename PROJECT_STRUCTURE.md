# Projektstruktur

## Ziel
Trennung von Verantwortlichkeiten in Gameplay, Netzwerk, Szenen, Addons und Assets.

## Ordner
- `scenes/core/`
  - Kernszenen des Spiels (`World.tscn`, `Agent.tscn`, `Obstacle.tscn`)
- `scripts/world/`
  - Welt- und UI-Orchestrierung (`World.gd`)
- `scripts/agents/`
  - Agenten-/Einheitenlogik (`Agent.gd`)
- `scripts/network/`
  - Netzwerk- und Sessionlogik (`NetworkManager.gd`)
- `assets/`
  - `textures/teams/` fuer Team-/Farbtexturen
  - `textures/shared/` fuer gemeinsame Texturen (z. B. Normalmaps)
  - `icons/` fuer Projekt-/UI-Icons
- `addons/`
  - Drittanbieter- oder Projekt-Addons
- `demo/`
  - Demo-Szenen und beispielhafte Inhalte
- `black/`, `green/`, `light/`, `orange/`, `purple/`, `red/`
  - Farb-/Textur-Assets

## Verantwortlichkeiten
- `World.gd`: UI, Eingabeweiterleitung, Spawn-Orchestrierung, Drag-Selection-Verknüpfung
- `NetworkManager.gd`: Host/Join, Peer-Events, Match-Start/Restart, Pause/Resume, Ping und Paketzaehler
- `Agent.gd`: Bewegung, Autoritaet pro Peer, Sync von Position/Rotation

## Hinweis zu Git
Editor- und Cache-Zustaende liegen unter `.godot/` und werden via `.gitignore` ausgeschlossen.
