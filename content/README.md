# Content-Katalog

Alle spielrelevanten Daten liegen hier in `game_content.tres`. Das restliche
Spiel kennt nur IDs und liest die Resources über `GameContentCatalog`.

## Dateien

- `game_content.tres`: **die Datei zum Bearbeiten**. Gebäude, Einheiten,
  Upgrades und Fähigkeiten stehen hier beieinander.
- `building_definition.gd`: beschreibt ein Gebäude inklusive seiner Fähigkeiten.
- `unit_definition.gd`: beschreibt eine spawnbar Einheit und ihre Szene.
- `ability_definition.gd`: gemeinsame Felder aller Fähigkeiten.
- `spawn_unit_ability.gd`: erzeugt eine oder mehrere Einheiten.
- `upgrade_ability.gd`: fügt dem Team eine Upgrade-ID hinzu.
- `unlock_tag_ability.gd`: schaltet einen abstrakten Tag frei.
- `content_requirement.gd`: Voraussetzung vom Typ Gebäude, Tag oder Upgrade.
- `upgrade_definition.gd`: Anzeigename und Beschreibung eines Upgrades.
- `content_context.gd`: Zustand, gegen den Voraussetzungen geprüft werden.
- `content_rules.gd`: reine Prüf- und Anzeige-Helfer.
- `ability_system.gd`: führt Fähigkeiten zur Laufzeit aus.

## Neu Einheit hinzufügen

1. In `game_content.tres` unter **Units** eine `UnitDefinition` anlegen.
2. `id`, `label` und `scene` setzen.
3. In einer `SpawnUnitAbility` bei `unit` diese ID eintragen.
4. Diese Fähigkeit beim gewünschten Gebäude unter `abilities` einhängen.

## Neues Upgrade hinzufügen

1. Eine `UpgradeDefinition` mit eindeutiger `id` anlegen.
2. Eine `UpgradeAbility` anlegen und dort `upgrade = id` setzen.
3. Der Fähigkeit Kosten und ggf. `requirements` geben.
4. Die Fähigkeit beim Gebäude einhängen.

Weitere Fähigkeiten, die erst nach dem Upgrade erscheinen sollen, bekommen
einfach eine Anforderung vom Typ `UPGRADE` mit der Upgrade-ID. Es ist kein
neues Skript nötig.

Einmalige Fähigkeiten wie der Ausbau selbst erhalten zusätzlich eine
Anforderung mit `negated = true`. Damit verschwindet die Fähigkeit, sobald die
Upgrade-ID gesetzt ist.

## Wichtig

Die Resources enthalten keine Spiel- oder UI-Logik. Sie beschreiben nur, was
passieren soll. Ausführung und Aktualisierung der Oberfläche laufen über
`AbilitySystem.gd` und `Game.gd`.
