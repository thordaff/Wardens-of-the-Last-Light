class_name TimeOfDayPreset
extends Resource
## Satu preset lighting per fase (art-direction.md §5b, tabel "Preset per fase").
## Diedit di Inspector; dibaca node TimeOfDay saat blend antar fase.

## Sama dengan GameClock.Phase (0 pagi, 1 siang, 2 sore, 3 malam).
@export_enum("Pagi", "Siang", "Sore", "Malam") var phase: int = 0
@export var sun_color: Color = Color.WHITE
@export var sun_energy: float = 1.0
## Elevasi cahaya utama dari arah Ashspire, dalam derajat.
@export var sun_elevation_deg: float = 45.0
@export var ambient_color: Color = Color.WHITE
@export var ambient_energy: float = 0.5
@export var fog_density: float = 0.01
@export var fog_albedo: Color = Color.WHITE
@export var glow_intensity: float = 0.6
@export var saturation: float = 1.0
## Kekuatan lentera (OmniLight amber), 0..1.
@export_range(0.0, 1.0) var lantern_strength: float = 0.5
@export var windows_lit: bool = true
