# Map Generator

Eigenständiger Karten-Editor für die Entwicklung. Das Plugin läuft in einer
eigenen Szene (`map_generator.tscn`) und ist unabhängig vom Spiel bzw. von
`Game.tscn`. Es kennt keine Spielklassen; platzierbare Objekte werden in der
Szene über `MapPlaceable`-Ressourcen konfiguriert.

## Starten

In Godot oben in der Toolbar auf **Map Generator** klicken. Alternativ:
**Projekt > Tools > Map Generator**.

## Bedienung

| Eingabe | Funktion |
| --- | --- |
| LMB | Gelände anheben / Boden malen / Objekt setzen |
| RMB | Gelände absenken / Objekt löschen |
| R | Objekt um 90° drehen |
| MMB | Kamera drehen |
| Mausrad | Zoomen |
| WASD / Pfeiltasten | Kamera bewegen |
| Q / E | Kamera drehen |
| Shift | Schneller bewegen |

- **Feldgröße**: Breite und Tiefe in Zellen. Eine Zelle ist standardmäßig
  `2.0` Welteinheiten groß, passend zum `grid_size` des Bau-Systems.
  „Größe anwenden“ leert die Karte.
- **Gelände formen**: Pinselradius in Zellen und Stärke einstellen.
- **Boden malen**: Wiese, Sand oder Wasser pro Zelle.
- **Objekte platzieren**: Objekt aus der Liste wählen, mit LMB auf eine Zelle
  setzen, mit RMB wieder entfernen.

## Speichern

Der Button **Speichern** schreibt zwei Dateien nach `res://GeneratedMaps/`:

- `<Name>.tscn`: Fertige Szene mit Terrain-Mesh, Terrain-Kollision und allen
  platzierten Objekten. Die Szene enthält **keine Plugin-Skripte** und kann
  direkt vom Spiel geladen werden.
- `<Name>.json`: Höhenfeld, Bodenarten und Objektliste. Damit kann die Karte
  später im Map Generator mit **Laden** weiterbearbeitet werden.

Aufbau der gespeicherten Szene:

```
<Name>
├── Terrain
│   ├── TerrainMesh            (ArrayMesh, eine Surface pro Bodenart)
│   └── TerrainCollision       (StaticBody3D, Layer 1+2, ConcavePolygonShape3D)
└── Objects
    ├── Ressourcen
    │   └── Holz_1 ...
    ├── Gebäude
    │   └── Haus_2 ...
    └── Einheiten
        └── Pionier_1 ...
```

Jedes platzierte Objekt speichert seine Herkunft in Metadaten:
`map_label`, `map_category`, `map_scene_path`, `map_rotation_steps`.
Die Wurzel der Szene enthält zusätzlich `map_name`, `map_width`, `map_depth`
und `map_cell_size`.

## Platzierbare Objekte ändern

`map_generator.tscn` öffnen und im Root-Node `MapGenerator` das Array
`placeables` bearbeiten. Jeder Eintrag ist eine `MapPlaceable`-Ressource mit:

- `label`: Anzeigename
- `category`: Palette-Gruppe und Ordnername in der gespeicherten Szene
- `scene`: zu instanzierende Szene
- `auto_ground_offset`: setzt das Objekt mit seiner untersten sichtbaren Mesh-
  Kante auf den Boden (funktioniert für Bäume und zentrierte Gebäude)
- `vertical_offset`: manueller Versatz, wenn `auto_ground_offset` aus ist

## Im Spiel verwenden

1. Karte im Map Generator speichern.
2. `Game.tscn` öffnen und im Root-Node `Game` beim Export-Feld
   **Generated Map** die gespeicherte `<Name>.tscn` aus
   `res://GeneratedMaps/` zuweisen.
3. Spiel starten.

`Game.gd` ersetzt dann automatisch den eingebauten Boden. Die generierte
Szene wird als Kind von `Map/NavigationRegion3D` instanziiert, damit das
Terrain-`StaticBody3D` unter der Navigationsregion liegt. Gebäude, Ressourcen
und Einheiten werden in die Karte umgehängt (`Map/NavigationRegion3D/Buildings`,
`Map/Resources` bzw. `Map/Agents`). Gebäude gelten sofort als fertig, ihre
Dropoff-Signale werden verbunden und die Auswahl wird registriert. Platzierte
Einheiten übernehmen das Team des Spielers und werden ebenfalls auswählbar.

Die Standard-Ressourcen aus `RESOURCE_SPAWNS` werden bei einer generierten
Karte nicht erzeugt, weil die Ressourcen bereits in der Karte enthalten sind.
Enthält die Karte Einheiten, entfällt auch der zufällige Starttrupp; ohne
platzierte Einheiten werden wie bisher Agenten im Kartenbereich verteilt.

Kamera und Fallback-Spawns verwenden die Abmessungen der generierten Karte,
statt der fest eingebauten Koordinaten. Ohne zugewiesene **Generated Map**
bleibt das bisherige Verhalten unverändert.
