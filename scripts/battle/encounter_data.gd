class_name EncounterData
extends Resource
## Satu formasi musuh. Maksimal 5 musuh (battle-layout.md §5).

@export var id: StringName
@export var display_name: String
@export var enemies: Array[EnemyData] = []
## Boss: tidak bisa kabur.
@export var is_boss: bool = false
