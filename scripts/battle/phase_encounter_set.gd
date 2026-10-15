class_name PhaseEncounterSet
extends Resource
## Isi tabel encounter untuk satu fase Napas Suar (konsep-cerita.md, "Siklus hari").

## Sama dengan GameClock.Phase (0 pagi, 1 siang, 2 sore, 3 malam).
@export_enum("Pagi", "Siang", "Sore", "Malam") var phase: int = 0
## Pengali peluang encounter per meter. Siang paling jarang, malam paling sering.
@export_range(0.0, 5.0) var rate_multiplier: float = 1.0
@export var common: Array[EncounterEntry] = []
## Musuh langka: hanya diundi dengan peluang `rare_chance` per encounter.
@export var rare: Array[EncounterEntry] = []
@export_range(0.0, 1.0) var rare_chance: float = 0.0
## Pengali kepadatan kabut (Pudar) di atas preset TimeOfDay.
@export_range(0.0, 5.0) var fog_density_scale: float = 1.0
