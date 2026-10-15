# Wardens of the Last Light

JRPG turn-based bergaya HD-2D (sprite pixel art di dunia 3D), dengan combat Break & Boost seperti Octopath Traveler.
Dibuat dengan **Godot 4.5**, renderer **Forward+**.

## Menjalankan

1. Buka Godot 4.5 (atau lebih baru), pilih **Import**, arahkan ke `project.godot` di folder ini.
2. Tekan **F5**. Scene awal (`scenes/main.tscn`) masih scene uji yang menampilkan jam dan fase waktu.
3. Tekan **1**, **2**, atau **3** untuk membuka prototipe battle (serigala, 5 musuh, boss), atau **4** untuk kota graybox. **T** memajukan jam 3 jam, jadi lighting ikut fase.

## Kota graybox (field)

`scenes/world/town_graybox.tscn`: kota kecil dari blok CSG untuk menguji tampilan HD-2D.

- Kamera tetap (FOV 32°, pitch −28°, jarak 11 m) mengikuti pemain dengan halus, DoF tilt-shift (`scripts/world/field_camera.gd`).
- `TimeOfDay` menerapkan preset `data/time_of_day/` ke cahaya utama dan Environment sesuai `GameClock`, dengan blend 1 jam antar fase. Cahaya datang dari arah Ashspire (`ashspire_yaw_deg`), lentera (group `lanterns`) berdenyut ±10%, jendela (group `lit_windows`) menyala sesuai fase.
- Pemain: `AnimatedSprite3D` billboard Y dengan sheet jalan Aldric (4 frame per arah, kanan = cermin kiri). Keyboard dan gamepad.
- Rumput hijau di timur kota = `EncounterZone`: berjalan di dalamnya bisa memicu battle acak. Setelah battle, pemain kembali ke posisi semula.

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
```

CI (`.github/workflows/godot-ci.yml`) menjalankan gdlint, gdformat, import, kedua tes, dan scene utama + battle secara headless di setiap PR.

## Kontrol

| Aksi | Keyboard | Gamepad |
|---|---|---|
| Gerak / pilih menu | WASD / panah | Stik kiri / D-pad |
| Konfirmasi | Enter / Spasi | A |
| Batal | Esc | B |
| Boost + / − | E / Q | R1 / L1 |

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
| `data/` | Resource data (`.tres`): karakter, skill, musuh, encounter, preset waktu |
| `tests/` | Tes headless |

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
