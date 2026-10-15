# Wardens of the Last Light

JRPG turn-based bergaya HD-2D (sprite pixel art di dunia 3D), dengan combat Break & Boost seperti Octopath Traveler.
Dibuat dengan **Godot 4.5**, renderer **Forward+**.

## Menjalankan

1. Buka Godot 4.5 (atau lebih baru), pilih **Import**, arahkan ke `project.godot` di folder ini.
2. Tekan **F5**. Game dibuka di **title screen** (`scenes/ui/title_screen.tscn`). **Mulai Baru** memulai di kota graybox jam 08:00 dengan roster default.
3. Di title screen, **F1** membuka scene uji lama (`scenes/main.tscn`): **1**, **2**, **3** untuk prototipe battle (serigala, 5 musuh, boss), **4** untuk kota graybox. **T** memajukan jam 3 jam, jadi lighting ikut fase.

## Alur UI

Semua menu bisa dipakai penuh dengan keyboard atau gamepad (fokus otomatis ke tombol pertama). Gaya placeholder ada di satu Theme bersama, `themes/ui_theme.tres` (dipasang sebagai `gui/theme/custom`), jadi tim art cukup mengganti theme itu.

- **Title screen**: Mulai Baru, Lanjutkan (nonaktif sampai ada sistem save), Pengaturan, Keluar.
- **Jeda** (Esc / Start di field): Lanjutkan, Pengaturan, Kembali ke judul. Game dan `GameClock` berhenti selama jeda. Autoload `PauseMenu` hanya aktif di scene yang masuk group `pausable` (saat ini kota).
- **Game over** ("Cahaya Padam") setelah seluruh party kalah: **Coba lagi** mengulang battle yang sama (lalu kembali ke tempat semula di field), **Kembali ke judul**.
- **Pengaturan**: volume master/musik/SFX (bus `Master`, `Music`, `SFX` di `default_bus_layout.tres`), layar penuh/jendela, skala resolusi 1x–4x dari 640×360. Langsung diterapkan dan disimpan ke `user://settings.cfg` oleh autoload `Settings`.

## Kota graybox (field)

`scenes/world/town_graybox.tscn`: kota kecil bergaya Eropa "mewah & historis" (art-direction.md §7b), masih dari blok CSG dengan palet §7b sampai kit half-timber dari tim art siap. Scene ini dibuat oleh `tools/gen_town_graybox.py` (jalankan ulang hanya bila ingin kembali ke tata letak generator; editan manual di Godot akan tertimpa).

- 4 ketinggian: jalan bawah & pasar (0 m), alun-alun dengan air mancur (1.5 m), teras kapel (3 m), belvedere (4.5 m), dihubungkan tangga lebar berpagar. Dinding penahan dan balustrade dengan baluster.
- 12 rumah half-timber 2–3 lantai: fondasi batu pasir, lantai atas menjorok, balok kayu, atap slate teal curam 50°, dormer, cerobong, jendela berbunga dengan kusen hijau/biru/merah, spanduk atau papan toko, lentera dinding. Kapel bermenara di teras.
- Set dressing acak (seed tetap): tong, peti, pot bunga, pohon, karung, keranjang buah, minimal 1 per sel 4×4 m yang bisa dimasuki; kios pasar berkanopi.
- Kamera tetap (FOV 32°, pitch −28°, jarak 11 m), DoF near blur s/d 4 m dan far blur mulai 14 m, dengan occluder foreground (pohon, balustrade, ujung atap) yang menempel di kamera dan selalu blur (`scripts/world/field_camera.gd`).
- Grading hangat sepia (color correction: bayangan coklat, sorotan keemasan), vignette 0.35 (`shaders/vignette.gdshader`), debu cahaya (GPUParticles3D), kabut krem.
- `TimeOfDay` menerapkan preset `data/time_of_day/` ke cahaya utama dan Environment sesuai `GameClock`, dengan blend 1 jam antar fase. Cahaya datang dari arah Ashspire (`ashspire_yaw_deg`), lentera (group `lanterns`) berdenyut ±10%, jendela (group `lit_windows`) menyala sesuai fase.
- Pemain: `AnimatedSprite3D` billboard Y dengan sheet jalan Aldric (4 frame per arah). Keyboard dan gamepad.
- Rumput di luar gerbang timur = `EncounterZone`: berjalan di dalamnya bisa memicu battle acak. Setelah battle, pemain kembali ke posisi semula.

## Encounter per fase (Napas Suar)

Pudar mengikuti jam: `data/encounter_tables/kota_awal.tres` (`EncounterTable`) berisi satu `PhaseEncounterSet` per fase.

| Fase | Laju | Formasi | Langka | Kabut |
|---|---|---|---|---|
| Pagi | ×0.8 | serigala, kelelawar | – | ×1.0 |
| Siang | ×0.5 | kelelawar lemah (stat ×0.9) | – | ×0.6 |
| Sore | ×1.0 | serigala, 5 musuh | – | ×1.2 |
| Malam | ×1.6 | Hampa ×1.3, kawanan ×1.25, 5 musuh | Bayang Suar 10% | ×1.5 |

- `EncounterZone.table` memakai laju dan formasi fase saat ini; `EncounterData.stat_scale` membuat varian kuat (HP dan atk/def, speed dan shield tetap).
- `TimeOfDay.pudar_table` mengalikan kepadatan kabut volumetrik dengan `fog_density_scale` fase yang sama (ikut blend antar fase).

## Prototipe battle

Logika battle ada di `scripts/battle/battle_system.gd` dan tidak bergantung pada tampilan; `scenes/battle/battle.tscn` hanya menampilkannya dengan sprite placeholder berwarna.

- Urutan giliran per ronde berdasarkan speed. Bar atas menampilkan **GILIRAN INI** dan **BERIKUTNYA**.
- 4 party aktif melawan sampai 5 musuh (atau 1 boss + 2).
- Kelemahan: 6 senjata (Pedang, Tombak, Belati, Kapak, Busur, Tongkat) + 6 elemen (Api, Es, Petir, Angin, Cahaya, Gelap). Awalnya `?`, terbuka saat kena.
- Shield turun 1 per hit kelemahan. Shield 0 = **BREAK**: musuh kehilangan giliran sampai 2 ronde berikutnya dan menerima damage ×2.
- **Boost**: BP +1 per giliran (maks 5), pakai sampai 3 per aksi dengan **Q/E** (gamepad L1/R1). Serang biasa + boost = lebih banyak hit; skill + boost = lebih kuat.
- **Tukar**: tiap slot punya 1 cadangan. Switch tidak memakai giliran, maksimal sekali per slot per ronde. Anggota yang KO otomatis digantikan cadangannya.

Semua angka ada di Resource `data/` (`characters/`, `skills/`, `enemies/`, `encounters/`) dan bisa diedit di Inspector.

## Tes

```
godot --headless --import
godot --headless -s res://tests/smoke_test.gd
godot --headless -s res://tests/test_battle.gd
godot --headless -s res://tests/test_town.gd
godot --headless -s res://tests/test_encounters.gd
godot --headless -s res://tests/test_settings.gd
```

CI (`.github/workflows/godot-ci.yml`) menjalankan gdlint, gdformat, import, semua tes, lalu title screen, battle, kota, scene uji, dan game over secara headless di setiap PR.

## Kontrol

| Aksi | Keyboard | Gamepad |
|---|---|---|
| Gerak / pilih menu | WASD / panah | Stik kiri / D-pad |
| Konfirmasi | Enter / Spasi | A |
| Batal / kembali | Esc | B |
| Jeda (di field) | Esc | Start |
| Boost + / − | E / Q | R1 / L1 |

## Struktur folder

| Folder | Isi |
|---|---|
| `scenes/` | Scene Godot (`.tscn`): field, battle, UI |
| `scripts/autoload/` | Singleton global: `GameClock`, `PartyManager`, `Settings` |
| `scripts/battle/` | Logika battle dan resource data karakter/musuh |
| `scripts/ui/` | Title screen, jeda, game over, pengaturan |
| `themes/` | Theme UI bersama |
| `scripts/world/` | Field, lighting, siklus waktu |
| `assets/characters/` | Sprite karakter, satu folder per karakter |
| `assets/enemies/` | Sprite musuh |
| `assets/tilesets/` | Tile dan tekstur lingkungan |
| `data/` | Resource data (`.tres`): karakter, skill, musuh, encounter, preset waktu |
| `tests/` | Tes headless |

## Sistem global (autoload)

**GameClock** — jam dalam game ("Napas Suar"). Empat fase: pagi (06–10), siang (10–16), sore (16–19), malam (19–06).
Jam berhenti saat battle (`begin_battle()` / `end_battle()`). Preset lighting tiap fase ada di `data/time_of_day/`.

**PartyManager** — roster maksimal 8 karakter, 4 aktif. Tiap slot battle berisi 1 aktif dan 1 cadangan; `swap_slot(i)` menukar keduanya. `load_default_roster()` mengisi roster dari `data/characters/`.

**Settings** — volume, layar penuh, skala resolusi; disimpan di `user://settings.cfg`.

**PauseMenu** — menu jeda (scene autoload, CanvasLayer 10).

## Dokumen desain

Dokumen desain (cerita, art direction, layout battle, backlog) ada di folder proyek bersama, bukan di repo ini.

## Konvensi

- Nama file dan folder: `snake_case`. Nama kelas: `PascalCase`.
- Semua PNG pixel art: filter Nearest, mipmaps off.
- Folder `.godot/` tidak di-commit (dibuat ulang otomatis oleh editor).
