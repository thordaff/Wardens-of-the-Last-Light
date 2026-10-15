#!/usr/bin/env python3
"""Generator scene kota graybox (art-direction.md §7b: kota mewah & historis).

Menulis scenes/world/town_graybox.tscn dari tata letak di bawah. Geometri masih
placeholder (mesh primitif + warna palet §7b, digabung per grup oleh MeshMerger) sampai kit half-timber dari tim art siap.

    python3 tools/gen_town_graybox.py

Scene hasilnya boleh diedit langsung di Godot; jalankan ulang generator hanya bila
ingin membuang editan manual dan kembali ke tata letak ini.
"""

import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "scenes" / "world" / "town_graybox.tscn"
SEED = 7

# Ketinggian (m): jalan bawah, alun-alun, teras kapel, belvedere.
L0, L1, L2, L3 = 0.0, 1.5, 3.0, 4.5

ext, sub, nodes = [], [], []
ids = set()


def add_ext(typ, path, id_):
    ext.append(f'[ext_resource type="{typ}" path="{path}" id="{id_}"]')


def add_sub(typ, id_, props):
    lines = [f'[sub_resource type="{typ}" id="{id_}"]']
    lines += [f"{k} = {v}" for k, v in props.items()]
    sub.append("\n".join(lines) + "\n")


def col(h, a=1.0):
    r, g, b = (int(h[i : i + 2], 16) / 255 for i in (1, 3, 5))
    return f"Color({r:.4g}, {g:.4g}, {b:.4g}, {a})"


def v3(x, y, z):
    return f"Vector3({x:.4g}, {y:.4g}, {z:.4g})"


def tf(pos=(0, 0, 0), rot_x=0.0, rot_y=0.0, rot_z=0.0):
    """Transform3D dengan urutan Euler Godot (YXZ)."""
    cx, sx = math.cos(math.radians(rot_x)), math.sin(math.radians(rot_x))
    cy, sy = math.cos(math.radians(rot_y)), math.sin(math.radians(rot_y))
    cz, sz = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))

    def rz(v):
        return (cz * v[0] - sz * v[1], sz * v[0] + cz * v[1], v[2])

    def rx(v):
        return (v[0], cx * v[1] - sx * v[2], sx * v[1] + cx * v[2])

    def ry(v):
        return (cy * v[0] + sy * v[2], v[1], -sy * v[0] + cy * v[2])

    basis = [ry(rx(rz(a))) for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1))]
    f = lambda v: ", ".join(f"{c:.5g}" for c in v)  # noqa: E731
    return f"Transform3D({f(basis[0])}, {f(basis[1])}, {f(basis[2])}, {f(pos)})"


def unique(name, parent):
    n, i = name, 2
    while (parent, n) in ids:
        n = f"{name}{i}"
        i += 1
    ids.add((parent, n))
    return n


def node(name, typ, parent=".", props=None, instance=None, groups=None):
    name = unique(name, parent)
    head = f'[node name="{name}"'
    if typ:
        head += f' type="{typ}"'
    if parent is not None:
        head += f' parent="{parent}"'
    # Export bertipe Node yang diisi NodePath wajib didaftarkan di header (Godot 4).
    paths = [k for k, v in (props or {}).items() if str(v).startswith("NodePath(")]
    if paths:
        head += " node_paths=PackedStringArray(" + ", ".join(f'"{k}"' for k in paths) + ")"
    if instance:
        head += f' instance=ExtResource("{instance}")'
    if groups:
        head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
    head += "]"
    body = "\n".join(f"{k} = {v}" for k, v in (props or {}).items())
    nodes.append(head + ("\n" + body if body else "") + "\n")
    return name if parent in (None, ".") else f"{parent}/{name}"


def mat(id_, color, extra=None):
    props = {"albedo_color": color}
    props.update(extra or {})
    add_sub("StandardMaterial3D", id_, props)
    return f'SubResource("{id_}")'


_meshes = {}
_colliders = {}


def shared(typ, props):
    """Satu sub_resource mesh/shape per kombinasi parameter, dipakai bersama."""
    key = (typ, tuple(sorted(props.items())))
    if key not in _meshes:
        id_ = f"{typ}_{len(_meshes) + 1}"
        add_sub(typ, id_, props)
        _meshes[key] = id_
    return f'SubResource("{_meshes[key]}")'


# Prop yang sedang dibuat: (grup prop, petak, posisi, rot_y). Collider prop masuk ke
# StaticBody3D petaknya, bukan satu body per prop.
current_prop = None


def collider(parent, pos, shape, rot_x=0.0, rot_y=0.0):
    """Satu StaticBody3D per grup; tiap collider jadi CollisionShape3D di dalamnya."""
    if current_prop and parent == current_prop[0]:
        _, parent, (px, py, pz), pry = current_prop
        r = math.radians(pry)
        x, y, z = pos
        pos = (px + math.cos(r) * x + math.sin(r) * z, py + y, pz - math.sin(r) * x + math.cos(r) * z)
        rot_y += pry
    if parent not in _colliders:
        _colliders[parent] = node("Colliders", "StaticBody3D", parent)
    props = {"transform": tf(pos, rot_x=rot_x, rot_y=rot_y), "shape": shape}
    node("Shape", "CollisionShape3D", _colliders[parent], props)


def mesh(parent, name, transform, mesh_res, material, groups=None):
    """MeshInstance3D primitif; MeshMerger di grup induknya menggabungkannya saat runtime."""
    props = {"transform": transform, "mesh": mesh_res, "material_override": material}
    return node(name, "MeshInstance3D", parent, props, groups=groups)


def box(parent, name, pos, size, material, collide=False, rot_y=0.0, rot_x=0.0, groups=None):
    t = tf(pos, rot_x=rot_x, rot_y=rot_y)
    if collide:
        collider(parent, pos, box_shape(size), rot_x, rot_y)
    return mesh(parent, name, t, shared("BoxMesh", {"size": v3(*size)}), material, groups)


def cyl(parent, name, pos, radius, height, material, sides=10, cone=False, collide=False):
    props = {
        "top_radius": 0.0 if cone else radius,
        "bottom_radius": radius,
        "height": height,
        "radial_segments": sides,
        "rings": 0,
    }
    if collide:
        shape = shared("CylinderShape3D", {"radius": radius, "height": height})
        collider(parent, pos, shape)
    return mesh(parent, name, tf(pos), shared("CylinderMesh", props), material)


def sphere(parent, name, pos, radius, material):
    props = {"radius": radius, "height": radius * 2, "radial_segments": 10, "rings": 6}
    return mesh(parent, name, tf(pos), shared("SphereMesh", props), material)


def roof(parent, name, pos, width, depth, height, material, rot_y=0.0):
    """Atap pelana: prisma segitiga, alas di `pos.y`, memanjang ke -Z sedalam `depth`."""
    ry = math.radians(rot_y)
    ox, oz = math.sin(ry) * -depth / 2, math.cos(ry) * -depth / 2
    center = (pos[0] + ox, pos[1] + height / 2, pos[2] + oz)
    prism = shared("PrismMesh", {"size": v3(width, height, depth)})
    return mesh(parent, name, tf(center, rot_y=rot_y), prism, material)


def merged(name, parent=".", props=None):
    """Grup Node3D yang anak-anak primitifnya digabung per material saat runtime."""
    props = dict(props or {})
    props["script"] = 'ExtResource("11_merge")'
    return node(name, "Node3D", parent, props)


# --- resource -----------------------------------------------------------------

add_ext("Script", "res://scripts/world/town.gd", "1_town")
add_ext("Script", "res://scripts/world/time_of_day.gd", "2_tod")
add_ext("Script", "res://scripts/world/lantern.gd", "3_lantern")
add_ext("Script", "res://scripts/world/field_camera.gd", "4_camera")
add_ext("Script", "res://scripts/world/encounter_zone.gd", "5_zone")
add_ext("PackedScene", "res://scenes/world/player.tscn", "6_player")
for i, n in enumerate(["pagi", "siang", "sore", "malam"]):
    add_ext("Resource", f"res://data/time_of_day/{n}.tres", f"p{i}")
add_ext("Script", "res://scripts/world/time_of_day_preset.gd", "7_preset")
add_ext("Resource", "res://data/encounter_tables/kota_awal.tres", "9_table")
add_ext("Shader", "res://shaders/vignette.gdshader", "10_vignette")
add_ext("Script", "res://scripts/world/mesh_merger.gd", "11_merge")

# Grading "historis" §7b: bayangan ke coklat #4A2E2A, sorotan ke #FFD27A.
add_sub(
    "Gradient",
    "Gradient_grade",
    {
        "offsets": "PackedFloat32Array(0, 0.5, 1)",
        "colors": "PackedColorArray(0.1, 0.06, 0.05, 1, 0.55, 0.47, 0.39, 1, 1, 0.93, 0.76, 1)",
    },
)
add_sub("GradientTexture1D", "GradientTexture_grade", {"gradient": 'SubResource("Gradient_grade")'})
add_sub(
    "Environment",
    "Environment_town",
    {
        "background_mode": 1,
        "background_color": col("#1A1C2E"),
        "ambient_light_source": 2,
        "ambient_light_color": col("#8C86A8"),
        "ambient_light_energy": 0.5,
        "tonemap_mode": 2,
        "ssao_enabled": "true",
        "ssao_intensity": 1.0,
        "sdfgi_enabled": "true",
        "glow_enabled": "true",
        "glow_intensity": 0.6,
        "glow_blend_mode": 2,
        "glow_hdr_threshold": 0.9,
        "volumetric_fog_enabled": "true",
        "volumetric_fog_density": 0.015,
        "volumetric_fog_albedo": col("#E8DCC4"),
        "adjustment_enabled": "true",
        "adjustment_color_correction": 'SubResource("GradientTexture_grade")',
    },
)
add_sub(
    "ShaderMaterial",
    "Vignette_mat",
    {"shader": 'ExtResource("10_vignette")', "shader_parameter/strength": 0.35},
)

# Palet §7b.
M = {
    "sand": mat("Mat_sand", col("#CDB58A")),
    "sand_dark": mat("Mat_sand_dark", col("#B07A5A")),
    "cobble": mat("Mat_cobble", col("#BFA67C")),
    "plaster": mat("Mat_plaster", col("#EDE8E3")),
    "plaster2": mat("Mat_plaster2", col("#FFF8EC")),
    "beam": mat("Mat_beam", col("#4A2E2A")),
    "beam2": mat("Mat_beam2", col("#5C2A12")),
    "slate": mat("Mat_slate", col("#2E5A6A")),
    "slate2": mat("Mat_slate2", col("#4A8A96")),
    "tile": mat("Mat_tile", col("#B5643A")),
    "banner": mat("Mat_banner", col("#A3263F")),
    "flower": mat("Mat_flower", col("#E04E5A")),
    "flower2": mat("Mat_flower2", col("#B58AD8")),
    "leaf": mat("Mat_leaf", col("#2F6B3E")),
    "leaf2": mat("Mat_leaf2", col("#5FA055")),
    "wood": mat("Mat_wood", col("#7A5236")),
    "grass": mat("Mat_grass", col("#4E7A3E")),
    "peak": mat("Mat_peak", col("#38344A")),
    "frame_green": mat("Mat_frame_green", col("#3E6B4A")),
    "frame_blue": mat("Mat_frame_blue", col("#3A5A86")),
    "frame_red": mat("Mat_frame_red", col("#8A3A32")),
    "window": mat(
        "Mat_window",
        col("#FFC070"),
        {"emission_enabled": "true", "emission": col("#FFB060"), "emission_energy_multiplier": 2.0},
    ),
    "dust": mat(
        "Mat_dust",
        col("#FFE2B0", 0.6),
        {
            "transparency": 1,
            "shading_mode": 0,
            "billboard_mode": 3,
            "billboard_keep_scale": "true",
            "vertex_color_use_as_albedo": "true",
        },
    ),
}
add_sub("BoxShape3D", "Box_zone", {"size": v3(8, 2, 10)})
_shapes = {}


def box_shape(size):
    """BoxShape3D per ukuran (CollisionShape3D tidak boleh di-scale non-uniform)."""
    key = tuple(round(c, 3) for c in size)
    if key not in _shapes:
        id_ = f"Box_{len(_shapes) + 1}"
        add_sub("BoxShape3D", id_, {"size": v3(*key)})
        _shapes[key] = id_
    return f'SubResource("{_shapes[key]}")'


add_sub(
    "ParticleProcessMaterial",
    "Dust_process",
    {
        "emission_shape": 3,
        "emission_box_extents": v3(18, 3, 14),
        "direction": v3(0.3, 1, 0),
        "spread": 60.0,
        "initial_velocity_min": 0.05,
        "initial_velocity_max": 0.2,
        "gravity": v3(0, 0.02, 0),
        "scale_min": 0.5,
        "scale_max": 1.2,
    },
)
add_sub("QuadMesh", "Dust_mesh", {"size": "Vector2(0.05, 0.05)", "material": M["dust"]})

# --- tata letak ---------------------------------------------------------------

rng = random.Random(SEED)
footprints = []  # (x0, z0, x1, z1) area yang tidak boleh diisi prop


def block(x0, z0, x1, z1, pad=0.3):
    footprints.append((x0 - pad, z0 - pad, x1 + pad, z1 + pad))


def ground_height(x, z):
    """Tinggi lantai di (x, z): sama dengan platform di bawah."""
    if -12 <= x <= -8 and -18 <= z <= -14:
        return L3
    if -12 <= x <= 12 and z <= -8:
        return L2
    if -16 <= x <= 16 and -8 < z <= 5:
        return L1
    return L0


node("Town", "Node3D", None, {"script": 'ExtResource("1_town")'})
node("WorldEnvironment", "WorldEnvironment", ".", {"environment": 'SubResource("Environment_town")'})
node(
    "Sun",
    "DirectionalLight3D",
    ".",
    {
        "transform": tf((0, 10, 0), -20, 210),
        "light_color": col("#FFC98A"),
        "light_energy": 0.9,
        "shadow_enabled": "true",
    },
)
node(
    "TimeOfDay",
    "Node",
    ".",
    {
        "script": 'ExtResource("2_tod")',
        "sun": 'NodePath("../Sun")',
        "world_environment": 'NodePath("../WorldEnvironment")',
        "presets": 'Array[ExtResource("7_preset")]([ExtResource("p0"), ExtResource("p1"), '
        'ExtResource("p2"), ExtResource("p3")])',
        "ashspire_yaw_deg": 30.0,
        "pudar_table": 'ExtResource("9_table")',
    },
)

# Lantai dan platform bertingkat.
terrain = merged("Terrain")
box(terrain, "Ground", (4, -0.5, 0), (52, 1, 38), M["cobble"], collide=True)
box(terrain, "Plaza", (0, L1 / 2, -1.5), (32, L1, 13), M["sand"], collide=True)
box(terrain, "PlazaTiles", (0, L1 + 0.005, -1.5), (14, 0.01, 9), M["sand_dark"])
box(terrain, "Terrace", (0, L2 / 2, -13), (24, L2, 10), M["sand"], collide=True)
box(terrain, "Belvedere", (-10, L3 / 2, -16), (4, L3, 4), M["sand"], collide=True)
# Dinding penahan diberi sabuk batu gelap supaya level terbaca.
for name, pos, size in [
    ("PlazaBand", (0, L1 - 0.1, 5.02), (32, 0.2, 0.05)),
    ("TerraceBand", (0, L2 - 0.1, -7.98), (24, 0.2, 0.05)),
    ("BelvedereBand", (-10, L3 - 0.1, -13.98), (4, 0.2, 0.05)),
]:
    box(terrain, name, pos, size, M["sand_dark"])


def stairs(parent, name, x, z_top, z_bottom, y_top, y_bottom, width):
    """Tangga turun ke arah +z. Anak tangga visual + ramp collider tak terlihat."""
    g = merged(name, parent)
    rise = y_top - y_bottom
    run = z_bottom - z_top
    steps = max(2, round(rise / 0.25))
    for i in range(steps):
        h = rise - i * rise / steps
        depth = run / steps
        z = z_top + depth * (i + 0.5)
        box(g, "Step", (x, y_bottom + h / 2, z), (width, h, depth), M["sand"])
    # Ramp: kotak tipis dimiringkan dari tepi atas ke tepi bawah.
    length = math.hypot(run, rise)
    angle = math.degrees(math.atan2(rise, run))
    body = node("Ramp", "StaticBody3D", g, {"transform": tf((x, (y_top + y_bottom) / 2 - 0.1, (z_top + z_bottom) / 2), rot_x=angle)})
    node(
        "Shape",
        "CollisionShape3D",
        body,
        {"shape": box_shape((width, 0.2, length))},
    )
    # Pagar tangga (balustrade pendek) di kedua sisi.
    for side in (-1, 1):
        rail = width / 2 + 0.15
        box(
            g,
            "Rail",
            (x + side * rail, (y_top + y_bottom) / 2 + 0.45, (z_top + z_bottom) / 2),
            (0.25, 0.15, length),
            M["sand_dark"],
            rot_x=angle,
        )
    block(x - width / 2, z_top, x + width / 2, z_bottom)


def balustrade(parent, name, x0, x1, z, y, gaps=()):
    """Pagar batu dengan baluster tiap 0.5 m, dilewati di rentang `gaps`."""
    g = merged(name, parent)
    segments = []
    start = x0
    for g0, g1 in sorted(gaps):
        segments.append((start, g0))
        start = g1
    segments.append((start, x1))
    for a, b in segments:
        if b - a < 0.4:
            continue
        mid, length = (a + b) / 2, b - a
        box(g, "Rail", (mid, y + 0.85, z), (length, 0.12, 0.3), M["sand_dark"], collide=True)
        box(g, "Base", (mid, y + 0.08, z), (length, 0.16, 0.3), M["sand_dark"])
        n = int(length / 0.5)
        for i in range(n + 1):
            box(g, "Baluster", (a + i * length / max(1, n), y + 0.47, z), (0.12, 0.62, 0.12), M["sand"])


levels = node("Levels", "Node3D")
stairs(levels, "MainStairs", 0, 5, 8.5, L1, L0, 5)
stairs(levels, "TerraceStairsL", -8, -8, -4.5, L2, L1, 2.4)
stairs(levels, "TerraceStairsR", 8, -8, -4.5, L2, L1, 2.4)
stairs(levels, "BelvedereStairs", -10, -14, -11.5, L3, L2, 1.6)
balustrade(levels, "PlazaRail", -16, 16, 4.85, L1, gaps=[(-2.8, 2.8)])
balustrade(levels, "TerraceRail", -12, 12, -8.15, L2, gaps=[(-9.5, -6.5), (6.5, 9.5)])
balustrade(levels, "BelvedereRail", -12, -8, -14.15, L3, gaps=[(-11.1, -8.9)])


def house(parent, name, x, y, z, w, d, floors, rot_y=0.0, roof_mat="slate", frame="frame_green", lantern=True):
    """Rumah half-timber: fondasi batu, lantai atas menjorok (jetty), atap curam,
    dormer, cerobong, jendela berbunga, spanduk/papan, lentera dinding."""
    g = merged(name, parent, {"transform": tf((x, y, z), rot_y=rot_y)})
    floor_h = 2.6
    found_h = 0.8
    plaster = M["plaster"] if rng.random() < 0.5 else M["plaster2"]
    box(g, "Foundation", (0, found_h / 2, 0), (w + 0.2, found_h, d + 0.2), M["sand"], collide=True)
    top = found_h
    for f in range(floors):
        jetty = 0.3 * f
        fw, fd = w + jetty * 2, d + jetty
        cz = jetty / 2
        box(g, f"Floor{f + 1}", (0, top + floor_h / 2, cz), (fw, floor_h, fd), plaster, collide=(f == 0))
        front = cz + fd / 2 + 0.03
        # Balok kayu: tiang sudut + balok lantai + diagonal di lantai atas.
        for sx in (-fw / 2 + 0.1, fw / 2 - 0.1):
            box(g, "Post", (sx, top + floor_h / 2, front), (0.18, floor_h, 0.06), M["beam"])
        box(g, "Beam", (0, top + 0.08, front), (fw, 0.16, 0.07), M["beam2"])
        box(g, "Beam", (0, top + floor_h - 0.08, front), (fw, 0.16, 0.07), M["beam2"])
        if f > 0:
            for sx in (-1, 1):
                box(g, "Post", (sx * fw / 4, top + floor_h / 2, front), (0.14, floor_h, 0.06), M["beam"])
        # Jendela + kotak bunga + kusen berwarna.
        n_win = max(2, int(fw / 1.8))
        for i in range(n_win):
            wx = -fw / 2 + fw * (i + 0.5) / n_win
            if f == 0 and abs(wx) < 0.7:
                continue  # tempat pintu
            wy = top + floor_h * 0.55
            box(g, "Frame", (wx, wy, front + 0.01), (0.8, 0.95, 0.04), M[frame])
            box(g, "Window", (wx, wy, front + 0.03), (0.6, 0.75, 0.04), M["window"], groups=["lit_windows"])
            box(g, "FlowerBox", (wx, wy - 0.5, front + 0.15), (0.75, 0.18, 0.25), M["wood"])
            fm = M["flower"] if rng.random() < 0.6 else M["flower2"]
            box(g, "Flowers", (wx, wy - 0.36, front + 0.15), (0.7, 0.12, 0.2), fm)
        top += floor_h
    # Pintu + papan toko / spanduk.
    front0 = d / 2 + 0.03
    box(g, "Door", (0, found_h + 1.0, front0 + 0.01), (1.0, 2.0, 0.06), M["beam2"])
    if rng.random() < 0.5:
        box(g, "Sign", (w / 2 - 0.2, found_h + 2.3, front0 + 0.45), (0.06, 0.5, 0.7), M["wood"])
    else:
        box(g, "Banner", (-w / 4, top - 1.3, front0 + 0.3 * (floors - 1) + 0.06), (0.6, 1.8, 0.04), M["banner"])
    # Atap curam 50°.
    rw = w + 0.6 * floors + 0.4
    rd = d + 0.3 * (floors - 1) + 0.6
    rh = math.tan(math.radians(50)) * rw / 2
    rz = 0.15 * (floors - 1) + rd / 2
    roof(g, "Roof", (0, top, rz), rw, rd, rh, M[roof_mat])
    # Dormer di lereng depan.
    dy = top + rh * 0.3
    dz = rz - rd * 0.2
    box(g, "Dormer", (0, dy + 0.45, dz), (1.1, 0.9, 1.4), plaster)
    box(g, "DormerWindow", (0, dy + 0.45, dz + 0.71), (0.5, 0.5, 0.04), M["window"], groups=["lit_windows"])
    roof(g, "DormerRoof", (0, dy + 0.9, dz + 0.75), 1.4, 1.6, 0.8, M[roof_mat])
    # Cerobong.
    box(g, "Chimney", (w / 3, top + rh * 0.7, rz - rd * 0.65), (0.6, rh * 0.9, 0.6), M["sand_dark"])
    if lantern:
        light = node(
            "WallLantern",
            "OmniLight3D",
            g,
            {
                "transform": tf((-0.9, found_h + 2.2, front0 + 0.35)),
                "script": 'ExtResource("3_lantern")',
                "light_color": col("#FFAD4D"),
                "light_energy": 1.5,
                "base_energy": 1.5,
                "omni_range": 4.5,
            },
        )
        box(light, "Housing", (0, 0, 0), (0.22, 0.32, 0.22), M["beam"])
    # Footprint di dunia (AABB kasar, memperhitungkan rotasi 90°).
    ex, ez = (w / 2 + 0.6, d / 2 + 0.9) if abs(rot_y) % 180 == 0 else (d / 2 + 0.9, w / 2 + 0.6)
    block(x - ex, z - ez, x + ex, z + ez)


buildings = node("Buildings", "Node3D")
frames = ["frame_green", "frame_blue", "frame_red"]
H = [
    # x, y, z, w, d, lantai, rot_y, atap
    (-18, L0, 10.5, 6, 5, 3, 0, "slate"),
    (-11.5, L0, 11, 5, 4.5, 2, 0, "slate2"),
    (11.5, L0, 11, 5, 4.5, 2, 0, "tile"),
    (-13.5, L1, -5, 5, 4.5, 2, 90, "slate"),
    (-13.5, L1, 1, 4.5, 4.5, 3, 90, "slate2"),
    (13.5, L1, -5, 5, 4.5, 3, -90, "slate2"),
    (13.5, L1, 1, 4.5, 4.5, 2, -90, "slate"),
    (-5.5, L2, -12, 4, 4, 2, 0, "slate2"),
    (6.5, L2, -12, 5, 4.5, 3, 0, "slate"),
    (10, L2, -16, 3.5, 3.5, 2, 0, "tile"),
    (-17, L0, -12, 6, 5, 3, 0, "slate"),
    (17, L0, -12, 6, 5, 3, 0, "slate2"),
]
for i, (x, y, z, w, d, fl, ry, rm) in enumerate(H):
    house(buildings, f"House{i + 1}", x, y, z, w, d, fl, ry, rm, frames[i % 3])

# Kapel dengan menara di teras tengah.
chapel = merged("Chapel", buildings, {"transform": tf((0, L2, -14.5))})
box(chapel, "Nave", (0, 2.5, 0), (5, 5, 6), M["sand"], collide=True)
roof(chapel, "Roof", (0, 5, 3.3), 5.8, 6.6, 3.5, M["slate"])
box(chapel, "Tower", (0, 5, -2.2), (2.2, 10, 2.2), M["sand"], collide=True)
cyl(chapel, "Spire", (0, 11.75, -2.2), 1.6, 3.5, M["slate2"], sides=4, cone=True)
box(chapel, "RoseWindow", (0, 3.6, 3.03), (1.4, 1.4, 0.05), M["window"], groups=["lit_windows"])
box(chapel, "Door", (0, 1.1, 3.03), (1.4, 2.2, 0.06), M["beam2"])
block(-3, -18, 3, -11)

# Gazebo belvedere (level 4).
gazebo = merged("Gazebo", buildings, {"transform": tf((-10.5, L3, -16.5))})
for px, pz in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
    cyl(gazebo, "Pillar", (px, 1.2, pz), 0.12, 2.4, M["plaster2"], sides=8)
cyl(gazebo, "Dome", (0, 3.0, 0), 1.6, 1.2, M["slate2"], sides=8, cone=True)

# Air mancur di tengah alun-alun.
fountain = merged("Fountain", ".", {"transform": tf((0, L1, -1.5))})
cyl(fountain, "Basin", (0, 0.35, 0), 1.8, 0.7, M["sand_dark"], sides=16, collide=True)
cyl(fountain, "Column", (0, 1.1, 0), 0.25, 1.6, M["sand"], sides=8)
cyl(fountain, "Bowl", (0, 1.9, 0), 0.8, 0.25, M["sand"], sides=12)
block(-2.2, -3.7, 2.2, 0.7)

# Pasar di jalan bawah (kanopi bergaris).
market = node("Market", "Node3D")
for i, (mx, mz, mcol) in enumerate([(-6.5, 11.5, "banner"), (6.5, 11.5, "slate2"), (-6.5, 15, "slate2"), (6.5, 15, "banner")]):
    stall = merged(f"Stall{i + 1}", market, {"transform": tf((mx, L0, mz))})
    box(stall, "Counter", (0, 0.5, 0), (2.4, 1.0, 1.0), M["wood"], collide=True)
    for sx in (-1.1, 1.1):
        box(stall, "Pole", (sx, 1.2, -0.4), (0.08, 2.4, 0.08), M["beam"])
        box(stall, "Pole", (sx, 1.0, 0.45), (0.08, 2.0, 0.08), M["beam"])
    box(stall, "Canopy", (0, 2.25, 0.05), (2.6, 0.06, 1.4), M[mcol], rot_x=-12)
    for k in range(4):
        fruit = [M["flower"], M["leaf2"], M["banner"], M["flower2"]][k]
        sphere(stall, "Fruit", (-0.85 + k * 0.57, 1.1, 0.1), 0.18, fruit)
    block(mx - 1.4, mz - 0.8, mx + 1.4, mz + 0.8)

# Lentera jalan.
lamps = merged("Lanterns")
# Hanya lentera di jalur utama (alun-alun + kaki tangga) yang ber-shadow; omni shadow mahal.
SHADOW_LAMPS = {0, 1, 4, 5}
for i, (lx, lz) in enumerate([(-3.2, 2.5), (3.2, 2.5), (-3.2, -6.5), (3.2, -6.5), (-3.5, 9), (3.5, 9), (16, 15), (24, 15)]):
    ly = ground_height(lx, lz)
    lamp = node(f"Lamp{i + 1}", "Node3D", lamps, {"transform": tf((lx, ly, lz))})
    cyl(lamp, "Post", (0, 1.2, 0), 0.08, 2.4, M["beam"], sides=6, collide=True)
    node(
        "Light",
        "OmniLight3D",
        lamp,
        {
            "transform": tf((0, 2.5, 0)),
            "script": 'ExtResource("3_lantern")',
            "light_color": col("#FFAD4D"),
            "light_energy": 2.0,
            "omni_range": 6.0,
            "shadow_enabled": "true" if i in SHADOW_LAMPS else "false",
        },
    )
    block(lx - 0.3, lz - 0.3, lx + 0.3, lz + 0.3)

# Jalan setapak tengah dan jalan keluar timur tetap kosong.
footprints.append((-2.6, -8, 2.6, 18))
footprints.append((-9.5, -8, -6.5, -4))
footprints.append((6.5, -8, 9.5, -4))
footprints.append((16, 12.5, 30, 17.5))

# Set dressing: minimal 1 prop per sel 4x4 m yang terlihat (§7b).
props = node("SetDressing", "Node3D")
# Prop digabung per petak 8x8 m: draw call sedikit tapi frustum culling tetap jalan.
CHUNK = 8
chunks = {}


def free(x, z, r=0.6):
    return all(not (x0 - r <= x <= x1 + r and z0 - r <= z <= z1 + r) for x0, z0, x1, z1 in footprints)


def place_prop(x, z):
    y = ground_height(x, z)
    kind = rng.choice(["barrel", "crate", "pot", "tree", "sack", "basket", "barrel", "pot"])
    key = (math.floor(x / CHUNK), math.floor(z / CHUNK))
    if key not in chunks:
        chunks[key] = merged(f"Chunk_{key[0]}_{key[1]}".replace("-", "m"), props)
    ry = rng.uniform(0, 360)
    g = node(kind.capitalize(), "Node3D", chunks[key], {"transform": tf((x, y, z), rot_y=ry)})
    global current_prop
    current_prop = (g, chunks[key], (x, y, z), ry)
    if kind == "barrel":
        cyl(g, "Body", (0, 0.45, 0), 0.35, 0.9, M["wood"], sides=10, collide=True)
        cyl(g, "Hoop", (0, 0.7, 0), 0.37, 0.06, M["beam"], sides=10)
    elif kind == "crate":
        s = rng.uniform(0.6, 0.9)
        box(g, "Body", (0, s / 2, 0), (s, s, s), M["wood"], collide=True)
        if rng.random() < 0.5:
            box(g, "Top", (0.1, s + 0.25, 0.05), (0.5, 0.5, 0.5), M["wood"])
    elif kind == "pot":
        cyl(g, "Pot", (0, 0.35, 0), 0.4, 0.7, M["sand_dark"], sides=10, collide=True)
        sphere(g, "Plant", (0, 1.0, 0), 0.55, M["leaf2"])
        sphere(g, "Bloom", (0.2, 1.35, 0.15), 0.2, M["flower"] if rng.random() < 0.5 else M["flower2"])
    elif kind == "tree":
        cyl(g, "Trunk", (0, 1.0, 0), 0.15, 2.0, M["beam2"], sides=6, collide=True)
        sphere(g, "Canopy", (0, 2.6, 0), 1.2, M["leaf"])
        sphere(g, "Canopy2", (0.5, 2.2, 0.4), 0.8, M["leaf2"])
    elif kind == "sack":
        sphere(g, "Sack", (0, 0.3, 0), 0.35, M["plaster2"])
        sphere(g, "Sack2", (0.4, 0.25, 0.2), 0.3, M["sand"])
    else:
        cyl(g, "Basket", (0, 0.2, 0), 0.35, 0.4, M["wood"], sides=10, collide=True)
        for k in range(3):
            sphere(g, "Fruit", (-0.12 + k * 0.12, 0.45, 0), 0.1, M["banner"] if k % 2 else M["flower"])
    block(x - 0.5, z - 0.5, x + 0.5, z + 0.5, pad=0.2)
    current_prop = None


for cx in range(-20, 28, 4):
    for cz in range(-18, 18, 4):
        for _ in range(12):
            x = cx + rng.uniform(0.5, 3.5)
            z = cz + rng.uniform(0.5, 3.5)
            if free(x, z):
                place_prop(x, z)
                break

# Rumput tinggi + zona encounter di luar gerbang timur.
box(".", "TallGrass", (26, 0.15, 12), (8, 0.3, 10), M["grass"])
zone = node(
    "EncounterZone",
    "Area3D",
    ".",
    {"transform": tf((26, 1, 12)), "script": 'ExtResource("5_zone")', "table": 'ExtResource("9_table")'},
)
node("CollisionShape3D", "CollisionShape3D", zone, {"shape": 'SubResource("Box_zone")'})
gate = merged("EastGate", ".", {"transform": tf((21, L0, 15))})
for gz in (-2.2, 2.2):
    box(gate, "Pillar", (0, 2, gz), (0.8, 4, 0.8), M["sand"], collide=True)
box(gate, "Arch", (0, 4.3, 0), (0.9, 0.6, 5.2), M["sand_dark"])

# Ashspire di kejauhan, searah ashspire_yaw_deg = 30 (kiri belakang).
cyl(".", "Ashspire", (-24, 14, -42), 7.0, 30.0, M["peak"], sides=8, cone=True)

# Batas dunia.
bounds = node("Bounds", "StaticBody3D")
for i, (x, z, sx, sz) in enumerate([(-22.5, 0, 1, 38), (30.5, 0, 1, 38), (4, -19.5, 54, 1), (4, 19.5, 54, 1)]):
    node(
        f"Wall{i + 1}",
        "CollisionShape3D",
        bounds,
        {"transform": tf((x, 3, z)), "shape": box_shape((sx, 6, sz))},
    )

# Debu cahaya (§7b atmosfer).
node(
    "LightDust",
    "GPUParticles3D",
    ".",
    {
        "transform": tf((0, 4, -2)),
        "amount": 160,
        "lifetime": 8.0,
        "visibility_aabb": "AABB(-20, -5, -16, 40, 12, 32)",
        "process_material": 'SubResource("Dust_process")',
        "draw_pass_1": 'SubResource("Dust_mesh")',
    },
)

node("Player", None, ".", {"transform": tf((0, L1, 2.5))}, instance="6_player")
cam = node(
    "FieldCamera",
    "Camera3D",
    ".",
    {
        "transform": tf((0, L1 + 6, 12.5), -28),
        "script": 'ExtResource("4_camera")',
        "target": 'NodePath("../Player")',
    },
)

# Foreground occluder (§7b): menempel di kamera, ±3 m di depannya, selalu di zona near blur.
fg = merged("Foreground", cam)
sphere(fg, "TreeCanopy", (-1.55, -0.95, -3.0), 0.75, M["leaf"])
sphere(fg, "TreeCanopy2", (-1.05, -1.1, -3.3), 0.55, M["leaf2"])
box(fg, "Balustrade", (0.6, -1.02, -3.1), (1.6, 0.14, 0.18), M["sand_dark"])
for i in range(5):
    box(fg, "Baluster", (-0.1 + i * 0.35, -1.18, -3.1), (0.08, 0.3, 0.08), M["sand"])
box(fg, "RoofEave", (1.75, -0.85, -2.9), (0.9, 0.12, 0.7), M["slate"], rot_y=20)

# HUD + vignette.
post = node("PostFX", "CanvasLayer", ".", {"layer": 0})
node(
    "Vignette",
    "ColorRect",
    post,
    {
        "anchors_preset": 15,
        "anchor_right": 1.0,
        "anchor_bottom": 1.0,
        "grow_horizontal": 2,
        "grow_vertical": 2,
        "mouse_filter": 2,
        "material": 'SubResource("Vignette_mat")',
    },
)
hud = node("HUD", "CanvasLayer", ".")
node(
    "Hint",
    "Label",
    hud,
    {
        "offset_left": 6.0,
        "offset_top": 4.0,
        "offset_right": 420.0,
        "offset_bottom": 40.0,
        "theme_override_font_sizes/font_size": 8,
        "text": '"Kota graybox  |  WASD / stik: jalan  |  gerbang timur: rumput encounter'
        '\\nT: jam +3  |  Esc / Start: jeda"',
    },
)

header = f"[gd_scene load_steps={len(ext) + len(sub) + 1} format=3]\n"
OUT.write_text(header + "\n" + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n" + "\n".join(nodes))
print(f"{OUT}: {len(nodes)} node")
