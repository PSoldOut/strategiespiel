@startuml
skinparam classAttributeIconSize 0
skinparam classFontStyle plain
skinparam showStereotype false
hide circle

enum WeaponEnums{
    Fist,
    Sword,
    Shield,
    2hSword,
    ....
}

enum WeaponEffect{
    None,
    Fire,
    Frost,
    Slow
    ...
}

class Weapon{
+ type: WeaponEnum
+ effect: WeaponEnum
+ dmg: float
+ speed: float
+ grid_range: int
--
+ pos_sync(pos:Transform): void
}

enum UnitEnums{
    Builder,
    SwordFighter,
    2hSwordFighter,
    ....
}




class Path{}

class UnitBehavoir{}

class Body{
+ type: UnitEnums
--
+ pos_sync(): void
}

class Unit{
+ type: UnitEnums
+ behavoir: UnitBehavoir
+ weapon: Weapon
+ body: Body
+ movement_speed: float
+ path: Path
+ next_waypoint: Vector3?Vector2
--
+ pos_sync(): void
+ move_to(pos: Vector3?Vector2): void
+ check_path(): bool
+ create_path(pos: Vector3?Vector2): Path
+ next_waypoint(path): Vector3?Vector2
+ attack()

}

' Relations
WeaponEnums "1..n" --o "1" Weapon : bestimmt Type
WeaponEffect "1..n" --o "1" Weapon : bestimmt Effekte

UnitEnums "1..n" --o "1" Unit : bestimmt Type

Weapon "1..n" --o "1" Unit : benutzt
UnitBehavoir "1..n" --o "1" Unit : hat
Path "1..n" --o "1" Unit : hat
Body "1..n" --o "1" Unit : hat
@enduml