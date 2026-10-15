class_name EncounterEntry
extends Resource
## Satu baris tabel encounter: formasi + bobot peluang.

@export var encounter: EncounterData
@export_range(1, 100) var weight: int = 1
