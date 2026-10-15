class_name SkillData
extends Resource
## Satu skill. Disimpan sebagai .tres di data/skills/.

enum Target { ONE_ENEMY, ALL_ENEMIES, ONE_ALLY, ALL_ALLIES }
enum Effect { DAMAGE, HEAL }

@export var id: StringName
@export var display_name: String
@export var sp_cost: int = 8
## Pengali damage/heal. Serang biasa = 1.0.
@export var power: float = 1.0
@export var type: BattleTypes.Type = BattleTypes.Type.PEDANG
@export var target: Target = Target.ONE_ENEMY
@export var effect: Effect = Effect.DAMAGE


func targets_enemies() -> bool:
	return target == Target.ONE_ENEMY or target == Target.ALL_ENEMIES


func is_single_target() -> bool:
	return target == Target.ONE_ENEMY or target == Target.ONE_ALLY
