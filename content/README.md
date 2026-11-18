# Content-Katalog

Alle spielrelevanten Daten liegen hier in `game_content.tres`. Das restliche
Spiel kennt nur IDs und liest die Resources über `GameContentCatalog`.

## Dateien

- `game_content.tres`: **die Datei zum Bearbeiten**. Gebäude, Einheiten,
  Upgrades und Fähigkeiten stehen hier beieinander.
- `building_definition.gd`: beschreibt ein Gebäude inklusive seiner Fähigkeiten.
- `unit_definition.gd`: beschreibt eine spawnbar Einheit und ihre Szene.
- `ability_definition.gd`: gemeinsame Felder aller Fähigkeiten.
- `spawn_unit_ability.gd`: erzeugt eine oder mehrere Einheiten. Bei
  `duration > 0` wird die Einheit erst nach dieser Zeit erzeugt.
- `set_rally_point_ability.gd`: versetzt ein Gebäude in den Sammelpunkt-Modus.
  `Game.gd` wartet danach auf einen Rechtsklick und speichert den Punkt über
  `AbilitySystem`.
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

## Ausbildung und Sammelpunkt

`duration` einer `SpawnUnitAbility` bestimmt die Ausbildungszeit in Sekunden.
Die Kosten werden sofort abgezogen, die Einheit erscheint erst nach der Zeit.
Solange sie wartet, zeigt die Auswahl des Gebäudes die Anzahl und die Restzeit.

Die Fähigkeit `Sammelpunkt setzen` ist eine `SetRallyPointAbility`. Nach dem
Klick darauf wartet das Spiel auf einen Rechtsklick auf der Karte. Dort erscheint
ein grüner Marker, und alle späteren Einheiten dieses Gebäudes spawn dort.
Ohne Sammelpunkt erscheinen sie neben dem Gebäude. Der Sammelpunkt kann jederzeit
neu gesetzt werden; das wirkt auch auf Einheiten, die noch in Ausbildung sind.

## Wichtig

Die Resources enthalten keine Spiel- oder UI-Logik. Sie beschreiben nur, was
passieren soll. Ausführung und Aktualisierung der Oberfläche laufen über
`AbilitySystem.gd` und `Game.gd`.
