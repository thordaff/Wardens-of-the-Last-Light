class_name EnemyData
extends Resource
## Data satu jenis musuh. Disimpan sebagai .tres di data/enemies/.

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 300
## Poin shield; turun 1 per hit kelemahan, BREAK saat 0.
@export var shield: int = 3
@export var phys_atk: int = 30
@export var phys_def: int = 20
@export var elem_atk: int = 20
@export var elem_def: int = 20
@export var speed: int = 40
@export var weaknesses: Array[BattleTypes.Type] = []
## Skill opsional; tanpa skill musuh hanya memakai serangan biasa.
@export var skills: Array[SkillData] = []
## Musuh besar / boss: berdiri di tengah kiri dan dihitung 2 slot.
@export var large: bool = false
@export var placeholder_color: Color = Color(0.6, 0.55, 0.75)
