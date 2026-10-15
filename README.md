# Wardens of the Last Light

JRPG turn-based bergaya HD-2D (sprite pixel art di dunia 3D), dengan combat Break & Boost seperti Octopath Traveler.
Dibuat dengan **Godot 4.5**, renderer **Forward+**.

## Menjalankan

1. Buka Godot 4.5 (atau lebih baru), pilih **Import**, arahkan ke `project.godot` di folder ini.
2. Tekan **F5**. Scene awal (`scenes/main.tscn`) masih scene uji yang menampilkan jam dan fase waktu.

## Struktur folder

| Folder | Isi |
|---|---|
| `scenes/` | Scene Godot (`.tscn`): field, battle, UI |
| `scripts/autoload/` | Singleton global: `GameClock`, `PartyManager` |
| `scripts/battle/` | Logika battle dan resource data karakter/musuh |
| `scripts/world/` | Field, lighting, siklus waktu |
| `assets/characters/` | Sprite karakter, satu folder per karakter |
| `assets/enemies/` | Sprite musuh |
| `assets/tilesets/` | Tile dan tekstur lingkungan |
| `data/` | Resource data (`.tres`): karakter, musuh, skill, preset waktu |

## Sistem global (autoload)

**GameClock** — jam dalam game ("Napas Suar"). Empat fase: pagi (06–10), siang (10–16), sore (16–19), malam (19–06).
Jam berhenti saat battle (`begin_battle()` / `end_battle()`). Preset lighting tiap fase ada di `data/time_of_day/`.

**PartyManager** — roster maksimal 8 karakter, 4 aktif. Tiap slot battle berisi 1 aktif dan 1 cadangan; `swap_slot(i)` menukar keduanya.

## Dokumen desain

Dokumen desain (cerita, art direction, layout battle, backlog) ada di folder proyek bersama, bukan di repo ini.

## Konvensi

- Nama file dan folder: `snake_case`. Nama kelas: `PascalCase`.
- Semua PNG pixel art: filter Nearest, mipmaps off.
- Folder `.godot/` tidak di-commit (dibuat ulang otomatis oleh editor).
