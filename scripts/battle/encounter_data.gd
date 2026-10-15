class_name EncounterData
extends Resource
## Satu formasi musuh. Maksimal 5 musuh (battle-layout.md §5).

@export var id: StringName
@export var display_name: String
@export var enemies: Array[EnemyData] = []
## Boss: tidak bisa kabur.
@export var is_boss: bool = false
## Pengali HP dan serangan/pertahanan musuh, untuk varian kuat (mis. Hampa di malam hari).
@export_range(0.5, 3.0) var stat_scale: float = 1.0
