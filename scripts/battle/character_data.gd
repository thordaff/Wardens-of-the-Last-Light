class_name CharacterData
extends Resource
## Data dasar satu anggota party. Disimpan sebagai .tres di data/characters/.

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 100
@export var max_sp: int = 30
@export var phys_atk: int = 30
@export var phys_def: int = 30
@export var elem_atk: int = 30
@export var elem_def: int = 30
@export var speed: int = 40
## Senjata untuk Serang biasa. Elemen didapat lewat skill.
@export var weapons: Array[BattleTypes.Type] = []
@export var skills: Array[SkillData] = []
## Warna sprite placeholder sampai sprite asli siap.
@export var placeholder_color: Color = Color.WHITE
