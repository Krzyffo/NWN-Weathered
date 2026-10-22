"""Build NWN-Weathered.

  py tools/build.py               generate, compile and pack
  py tools/build.py --list FILE   print the contents of an .erf/.hak

Writes two files next to this script:
- nwn_weathered.hak: the weather shaders, a noise texture, one .mtr
  material per creature texture of the base game, and the lookup tables
  the scripts use to find a creature's materials.
- nwn_weathered.erf: src/nss/*.nss and their compiled .ncs, and the
  clothes brush blueprint (wthr_brush.uti), for File > Import in the
  toolset.

Why the tables: the engine gives a texture a material when a .mtr of the
same name exists, and a script sets a material's values on one creature
by that name. Scripts can't read a creature's texture names, and they don't
follow from the model names (an elf's pelvis003 is textured with
pfh0_pelvis001), so this reads every player body part and monster model
and records which textures each one uses:
- wthr_<part>.2da   one per body part; row = part number, column = model
                    prefix such as pmd0 (male dwarf, normal phenotype)
- wthr_appear.2da   row = appearance.2da row, TEXTURES column, for monsters
- wthr_cloak.2da    row = cloakmodel.2da row: TEXTURES, and per model
                    prefix where that cloak hangs on the figure
- wthr_parts.2da    row = part (CREATURE_PART_*, then the cloak, 21): its
                    height range and how much blood it catches
Cells hold texture names joined by ";".

The game is found as described in tools/nwn_paths.py (NWN_ROOT, else Steam).
The script compiler comes from the neverwinter.nim release, unzipped into
tools/neverwinter/ (https://github.com/niv/neverwinter.nim/releases).
"""
import datetime
import os
import re
import struct
import subprocess
import sys
import tempfile

import nwn_key
import nwn_paths

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
NSS = os.path.join(ROOT, "src", "nss")
SHADERS = os.path.join(ROOT, "src", "shaders")
ERF_OUT = os.path.join(TOOLS, "nwn_weathered.erf")
HAK_OUT = os.path.join(TOOLS, "nwn_weathered.hak")
COMPILER = os.path.join(TOOLS, "neverwinter", "nwn_script_comp.exe")

RES_TYPES = {"tga": 3, "nss": 2009, "ncs": 2010, "2da": 2017, "uti": 2025, "shd": 2069, "mtr": 2072}
TYPE_EXT = {v: k for k, v in RES_TYPES.items()}
T_TGA, T_PLT, T_MDL, T_2DA, T_TXI, T_DDS, T_MTR = 3, 6, 2002, 2017, 2022, 2033, 2072
HEADER_SIZE = 160
KEY_SIZE = 24
RES_SIZE = 8

# Body part names in the model files, indexed like CREATURE_PART_* and
# ITEM_APPR_ARMOR_MODEL_* (0-18), plus the head (CREATURE_PART_HEAD = 20).
PARTS = ["footr", "footl", "shinr", "shinl", "legl", "legr", "pelvis", "chest", "belt", "neck",
         "forer", "forel", "bicepr", "bicepl", "shor", "shol", "handr", "handl", "robe", "head"]
PART_MODEL = re.compile(r"^(p[mf][a-z]\d+)_(" + "|".join(PARTS) + r")(\d{3})$")
# Cloaks are items with models of their own, <prefix>_cloak_NNN; their row
# in wthr_parts.2da follows the body parts and the head (20). Helmets,
# robes and weapons get no material: the engine doesn't pass a creature's
# material values on to their models (nor takes them from the item), so
# they couldn't change. A robe texture another body part uses too (some
# robes wear pmh0_pelvis001) still gets one, for that part.
CLOAK = "cloak"
CLOAK_MODEL = re.compile(r"^(p[mf][a-z]\d+)_cloak_(\d{3})$")
SKELETON_MODEL = re.compile(r"^p[mf][a-z]\d+$")
PART_ROWS = PARTS[:19] + [None, "head", CLOAK]

# Where each body part sits on a standing figure, as a share of its height
# (feet 0, top of the head 1). The shader grades within each part from its
# low to its high end, so dust can climb from the boots up.
PART_HEIGHT = {
    "footr": (0.0, 0.08), "footl": (0.0, 0.08),
    "shinr": (0.05, 0.3), "shinl": (0.05, 0.3),
    "legl": (0.28, 0.5), "legr": (0.28, 0.5),
    "pelvis": (0.45, 0.58), "belt": (0.52, 0.6),
    "handr": (0.38, 0.48), "handl": (0.38, 0.48),
    "forer": (0.45, 0.62), "forel": (0.45, 0.62),
    "bicepr": (0.6, 0.76), "bicepl": (0.6, 0.76),
    "chest": (0.56, 0.82), "shor": (0.76, 0.86), "shol": (0.76, 0.86),
    "neck": (0.8, 0.87), "head": (0.85, 1.0),
    "robe": (0.05, 0.85),
    # A cloak is a skin mesh, which the engine gives no bounding box: its
    # height comes from where it hangs on the figure (MeshBase, MeshHeight
    # in the material). This range is only the fallback.
    CLOAK: (0.1, 0.82),
}
WHOLE_BODY = (0.0, 1.0)  # monsters: one texture covers everything

# How much blood each part catches: (wounds, spatter). Wounds land on the
# body where blows fall; spatter from hitting others lands on the hands and
# arms first, then the chest and face.
PART_BLOOD = {
    "footr": (0.2, 0.1), "footl": (0.2, 0.1),
    "shinr": (0.5, 0.15), "shinl": (0.5, 0.15),
    "legl": (0.7, 0.2), "legr": (0.7, 0.2),
    "pelvis": (0.8, 0.3), "belt": (0.6, 0.3),
    "handr": (0.5, 1.0), "handl": (0.5, 0.9),
    "forer": (0.7, 0.9), "forel": (0.7, 0.8),
    "bicepr": (0.7, 0.5), "bicepl": (0.7, 0.45),
    "chest": (1.0, 0.6), "shor": (0.6, 0.4), "shol": (0.6, 0.4),
    "neck": (0.5, 0.45), "head": (0.4, 0.45),
    "robe": (0.8, 0.4),
    CLOAK: (0.5, 0.3),
}
MONSTER_BLOOD = (0.8, 0.6)

# Placeables and doors: a designer sets their look in variables. Blood on
# them shows evenly (no "front"), dust climbs each mesh from its bottom.
OBJECT = "object"
OBJECT_BLOOD = (1.0, 1.0)

# Object tables: (2DA in the game, its model column, our table).
OBJECT_TABLES = [
    ("placeables", "ModelName", "wthr_plc"),
    ("genericdoors", "ModelName", "wthr_gdoor"),
    ("doortypes", "Model", "wthr_door"),
]

NOISE_TEXTURE = "wthr_noise"
NOISE_SIZE = 256

# Values the scripts set per creature start at 0. PartLow/PartHigh, the
# blood weights and MeshBase/MeshHeight are each texture's defaults; for
# player-shaped creatures the scripts send the values of the parts the
# texture is on for that creature (wthr_parts.2da), since one texture can
# serve a thigh in one armour and a shoulder pad in another. texture4 is the noise (the shader's
# height-map slot). Shaders: vs_/fs_weather have the environment map, as
# creature textures need (their alpha is shininess: metal armour);
# vs_/fs_wthr_plain don't, for placeables and doors, whose alpha is
# transparency unless their .txi asks for an environment map.
MATERIAL = """customshadervs {vs}
customshaderfs {fs}
texture4 {noise}
parameter float DustAmount 0.0
parameter float DustSpread 0.0
parameter float SnowAmount 0.0
parameter float BloodWounds 0.0
parameter float BloodDry 0.0
parameter float BloodOwn 0.0
parameter float SpatterRed 0.0
parameter float SpatterGreen 0.0
parameter float SpatterYellow 0.0
parameter float SpatterWhite 0.0
parameter float PartLow {low}
parameter float PartHigh {high}
parameter float WoundWeight {wounds}
parameter float SpatterWeight {spatter}
parameter float SpatterFront {front}
parameter float MeshBase {base}
parameter float MeshHeight {height}
"""

# The clothes brush: a small misc item ("Rags" look) with Unique Power Self
# Only, unlimited uses; using it runs OnActivateItem (wthr_activate).
BRUSH_RESREF = "wthr_brush"
BRUSH_TEMPLATE = "nw_it_msmlmisc21"   # Rags
BRUSH_NAME = "Clothes Brush"
BRUSH_DESCRIPTION = ("A stiff-bristled brush for beating the dust and snow out of travelling clothes. "
                     "Use it to clean yourself up, or type /brush.")


def write_erf(out_path, entries, file_type=b"ERF "):
    """Write an ERF-family archive from (resref, ext, bytes) entries."""
    count = len(entries)
    off_keys = HEADER_SIZE
    off_res = off_keys + count * KEY_SIZE
    off_data = off_res + count * RES_SIZE
    today = datetime.date.today()
    header = struct.pack(
        "<4s4sIIIIIIIII",
        file_type, b"V1.0",
        0, 0,                 # language count, localized string size
        count,
        off_keys,             # no localized strings: they would start here
        off_keys, off_res,
        today.year - 1900, today.timetuple().tm_yday - 1,
        0,                    # description strref (0, as Beamdog's nwn_erf writes it)
    ) + b"\0" * 116
    keys, res_list, data = [], [], []
    offset = off_data
    for i, (resref, ext, blob) in enumerate(entries):
        if len(resref) > 16:
            raise SystemExit(f"{resref}.{ext}: resref longer than 16 characters")
        keys.append(struct.pack("<16sIHH", resref.encode("ascii"), i, RES_TYPES[ext], 0))
        res_list.append(struct.pack("<II", offset, len(blob)))
        data.append(blob)
        offset += len(blob)
    with open(out_path, "wb") as f:
        f.write(header + b"".join(keys) + b"".join(res_list) + b"".join(data))
    print(f"wrote {out_path} ({count} resources)")


def list_erf(path):
    with open(path, "rb") as f:
        blob = f.read()
    sig, ver, _lc, _ls, count, _ol, off_keys, off_res = struct.unpack_from("<4s4sIIIIII", blob, 0)
    print(f"{sig.decode()} {ver.decode()}: {count} entries")
    for i in range(count):
        resref, _rid, rtype, _ = struct.unpack_from("<16sIHH", blob, off_keys + i * KEY_SIZE)
        _offset, size = struct.unpack_from("<II", blob, off_res + i * RES_SIZE)
        print(f"  {resref.rstrip(b'\0').decode()}.{TYPE_EXT.get(rtype, rtype)}  {size:6d} bytes")


def files(folder, ext):
    return [os.path.join(folder, f) for f in sorted(os.listdir(folder)) if f.lower().endswith(ext)]


def read_file_entries(paths):
    out = []
    for path in paths:
        resref, ext = os.path.basename(path).lower().rsplit(".", 1)
        with open(path, "rb") as f:
            out.append((resref, ext, f.read()))
    return out


# ---- Reading the game ------------------------------------------------------

def parse_2da(text):
    """Rows of a 2DA as dicts (column -> value, '****' kept)."""
    lines = [l for l in text.splitlines()]
    body = [l for l in lines[2:] if l.strip()]
    columns = body[0].split()
    rows = []
    for line in body[1:]:
        cells = re.findall(r'"[^"]*"|\S+', line)
        cells = [c.strip('"') for c in cells]
        rows.append(dict(zip(columns, cells[1:])))
    return rows


# Binary model layout (NWN 1): a 12-byte file header, then the model data,
# which all offsets are relative to. The geometry header has the root node
# offset at 72. Each node starts with a 112-byte header (children array at
# 72, flags at 108); mesh nodes continue with a mesh header whose first
# texture name, 64 bytes, is at 120.
MDL_DATA = 12
NODE_MESH = 0x020
NODE_AABB = 0x200   # walkmesh: not drawn


def _u32(blob, offset):
    return struct.unpack_from("<I", blob, offset)[0]


ASCII_MESH_NODES = {"trimesh", "skin", "danglymesh", "animmesh"}


def ascii_model_textures(text, textures):
    """Same as model_textures, for a model in the ASCII format: the bitmap
    of each mesh node ("node trimesh ...", not emitters or walkmeshes)."""
    names, in_mesh = [], False
    for line in text.splitlines():
        words = line.split()
        if not words:
            continue
        key = words[0].lower()
        if key == "node" and len(words) > 1:
            in_mesh = words[1].lower() in ASCII_MESH_NODES
        elif key == "endnode":
            in_mesh = False
        elif in_mesh and key == "bitmap" and len(words) > 1:
            name = words[1].lower()
            if name in textures and name not in names:
                names.append(name)
    return names


def ascii_node_heights(text):
    """{node name: (height above the model's origin, node type, bitmap)}
    for a model in the ASCII format, adding up the positions of each node's
    parents (the figures stand upright, so rotations are left out)."""
    nodes, name = {}, None
    for line in text.splitlines():
        words = line.split()
        if not words:
            continue
        key = words[0].lower()
        if key in ("endmodelgeom", "newanim"):
            break  # animations name the same nodes again
        if key == "node" and len(words) > 2:
            name = words[2].lower()
            nodes[name] = {"type": words[1].lower(), "parent": None, "z": 0.0, "bitmap": None}
        elif key == "endnode":
            name = None
        elif name and key == "parent" and len(words) > 1:
            nodes[name]["parent"] = words[1].lower()
        elif name and key == "position" and len(words) > 3:
            nodes[name]["z"] = float(words[3])
        elif name and key == "bitmap" and len(words) > 1:
            nodes[name]["bitmap"] = words[1].lower()

    def height(n, depth=0):
        node = nodes.get(n)
        if node is None or depth > 64:
            return 0.0
        return node["z"] + height(node["parent"], depth + 1)

    return {n: (height(n), node["type"], node["bitmap"]) for n, node in nodes.items()}


def model_textures(blob, textures):
    """Texture names on the drawn meshes of a model, in node order.
    Emitters and walkmeshes are left out: their textures must keep the
    engine's own rendering."""
    if not blob.startswith(b"\0"):
        return ascii_model_textures(blob.decode("latin-1"), textures)
    names = []
    try:
        stack, seen = [_u32(blob, MDL_DATA + 72)], set()
        while stack:
            offset = stack.pop()
            node = MDL_DATA + offset
            if offset in seen or node + 112 > len(blob):
                continue
            seen.add(offset)
            flags = _u32(blob, node + 108)
            children, count = _u32(blob, node + 72), _u32(blob, node + 76)
            stack.extend(_u32(blob, MDL_DATA + children + 4 * k) for k in reversed(range(min(count, 1024))))
            if flags & NODE_MESH and not flags & NODE_AABB:
                raw = blob[node + 112 + 120:node + 112 + 184].split(b"\0")[0]
                name = raw.decode("latin-1").lower()
                if name in textures and name not in names:
                    names.append(name)
    except struct.error:
        pass  # truncated or not a binary model (ASCII models are skipped)
    return names


def scan_game():
    """(textures, models, stock materials, {2da name: rows}, textures whose
    .txi asks for an environment map) of the game."""
    textures, models, stock_materials, shiny = set(), {}, set(), set()
    wanted = {"appearance", "cloakmodel"} | {t[0] for t in OBJECT_TABLES}
    found = {}
    for resref, rtype, bif, idx in nwn_key.all_entries():
        if rtype in (T_TGA, T_DDS, T_PLT):
            textures.add(resref)
        elif rtype == T_MDL:
            models[resref] = (bif, idx)
        elif rtype == T_MTR:
            stock_materials.add(resref)
        elif rtype == T_TXI:
            txi = nwn_key.read_bif_resource(bif, idx).lower()
            if b"envmaptexture" in txi or b"bumpyshinytexture" in txi:
                shiny.add(resref)
        elif rtype == T_2DA and resref in wanted:
            found[resref] = (bif, idx)  # later archives override earlier ones
    tables = {name: parse_2da(nwn_key.read_bif_resource(*loc).decode("latin-1")) for name, loc in found.items()}
    return textures, models, stock_materials, tables, shiny


def build_object_tables(textures, models, game_tables, used):
    """wthr_plc / wthr_gdoor / wthr_door: the textures of each placeable and
    door appearance, rows as in the game's tables."""
    tables = {}
    for source, column, name in OBJECT_TABLES:
        lines = ["2DA V2.0", "", "    TEXTURES"]
        for row, cells in enumerate(game_tables.get(source, [])):
            model = cells.get(column, "****").lower()
            tex = []
            if model in models:
                tex = model_textures(nwn_key.read_bif_resource(*models[model]), textures)
                for t in tex:
                    used.setdefault(t, OBJECT)
            lines.append(f"{row} " + (";".join(tex) or "****"))
        tables[name] = "\n".join(lines) + "\n"
    return tables


FOOT_DEPTH = 0.14  # metres from a foot bone down to the sole


def figure_heights(models):
    """{model prefix: (ground, top of the head)} in model space, from the
    skeleton models (pmh0, pfd2, ...). Their "head" node sits at the top of
    the head; the smaller races stand with their feet above the model's
    origin."""
    out = {}
    for name, loc in models.items():
        if not SKELETON_MODEL.match(name):
            continue
        blob = nwn_key.read_bif_resource(*loc)
        if blob.startswith(b"\0"):
            continue  # binary: only pmh1, which has no cloaks
        nodes = ascii_node_heights(blob.decode("latin-1"))
        if "head" in nodes and "lfoot_g" in nodes and nodes["head"][0] > 0.1:
            out[name] = (nodes["lfoot_g"][0] - FOOT_DEPTH, nodes["head"][0])
    return out


def own_part(texture, parts):
    """The part whose defaults a texture shared by several parts gets in its
    material: the part it is named after (pmh0_pelvis001 also dresses some
    robes), else the first one found."""
    for p in parts:
        if re.search(r"_" + p + r"\d", texture):
            return p
    return parts[0]


def build_tables(textures, models, game_tables):
    """(2DA files as {resref: text}, {texture: body part, None for a
    monster}, {cloak texture: (MeshBase, MeshHeight)} for every texture
    used)."""
    users = {}  # texture: the parts it is on, in the order found

    # Player body parts: {part: {prefix: {number: textures}}}
    parts = {p: {} for p in PARTS}
    for name, loc in models.items():
        m = PART_MODEL.match(name)
        if not m:
            continue
        prefix, part, number = m.group(1), m.group(2), int(m.group(3))
        if part == "robe":
            continue  # no materials for robes (see CLOAK above)
        tex = model_textures(nwn_key.read_bif_resource(*loc), textures)
        if tex:
            parts[part].setdefault(prefix, {})[number] = tex
            for t in tex:
                users.setdefault(t, []).append(part)

    tables = {}
    for part, by_prefix in parts.items():
        if not by_prefix:
            continue  # the robes
        prefixes = sorted(by_prefix)
        last = max((n for d in by_prefix.values() for n in d), default=0)
        lines = ["2DA V2.0", "", "    " + " ".join(prefixes)]
        for row in range(last + 1):
            cells = [";".join(by_prefix[p].get(row, [])) or "****" for p in prefixes]
            lines.append(f"{row} " + " ".join(cells))
        tables["wthr_" + part] = "\n".join(lines) + "\n"

    # Cloaks: cloakmodel.2da gives each cloak appearance a model
    # (<prefix>_cloak_NNN, a skin mesh per race, gender and phenotype) and a
    # texture (cloak_NNN), which replaces the model's own. A skin mesh has no
    # bounding box, so the shader places a cloak's vertex on the figure at
    # (MeshBase + its height in the mesh) / MeshHeight: wthr_cloak holds the
    # texture and "MeshBase_MeshHeight" per model prefix.
    figure = figure_heights(models)
    hangs = {}  # (prefix, model number): (MeshBase, MeshHeight)
    for name, loc in sorted(models.items()):
        m = CLOAK_MODEL.match(name)
        if not m or m.group(1) not in figure:
            continue
        blob = nwn_key.read_bif_resource(*loc)
        if blob.startswith(b"\0"):
            continue
        skins = [z for z, kind, _ in ascii_node_heights(blob.decode("latin-1")).values() if kind == "skin"]
        if skins:
            ground, top = figure[m.group(1)]
            hangs[(m.group(1), int(m.group(2)))] = (skins[0] - ground, top - ground)
    prefixes = sorted({p for p, _ in hangs})
    mesh = {}
    lines = ["2DA V2.0", "", "    TEXTURES " + " ".join(prefixes)]
    for row, cells in enumerate(game_tables.get("cloakmodel", [])):
        try:
            model, texture = int(cells.get("MODEL", "")), int(cells.get("TEXTURE", ""))
        except ValueError:
            model, texture = 0, 0
        tex = f"cloak_{texture:03d}"
        if model <= 0 or tex not in textures:
            lines.append(f"{row} " + " ".join(["****"] * (len(prefixes) + 1)))
            continue
        users.setdefault(tex, []).append(CLOAK)
        if ("pmh0", model) in hangs and tex not in mesh:
            mesh[tex] = hangs[("pmh0", model)]
        z = [f"{hangs[(p, model)][0]:.3f}_{hangs[(p, model)][1]:.3f}" if (p, model) in hangs else "****"
             for p in prefixes]
        lines.append(f"{row} {tex} " + " ".join(z))
    tables["wthr_cloak"] = "\n".join(lines) + "\n"

    # The defaults of each part, for the scripts (rows as CREATURE_PART_*,
    # then the cloak).
    lines = ["2DA V2.0", "", "    LOW HIGH WOUNDS SPATTER"]
    for row, part in enumerate(PART_ROWS):
        if part is None:
            lines.append(f"{row} **** **** **** ****")
            continue
        (low, high), (wounds, spatter) = PART_HEIGHT[part], PART_BLOOD[part]
        lines.append(f"{row} {low:.2f} {high:.2f} {wounds:.2f} {spatter:.2f}")
    tables["wthr_parts"] = "\n".join(lines) + "\n"

    used = {t: own_part(t, ps) for t, ps in users.items()}

    # Monsters: the model is the RACE column of appearance.2da.
    lines = ["2DA V2.0", "", "    TEXTURES"]
    for row, cells in enumerate(game_tables["appearance"]):
        model = cells.get("RACE", "****").lower()
        tex = []
        if cells.get("MODELTYPE", "").upper() != "P" and model in models:
            tex = model_textures(nwn_key.read_bif_resource(*models[model]), textures)
            for t in tex:
                used.setdefault(t, None)
        lines.append(f"{row} " + (";".join(tex) or "****"))
    tables["wthr_appear"] = "\n".join(lines) + "\n"
    return tables, used, mesh


# ---- Generated content -----------------------------------------------------

def _value_noise(size, cells, seed, stretch_x=1):
    """Tileable value noise, size x size, values 0..1. cells: lattice points
    across (must divide size); stretch_x > 1 makes streaks along x."""
    import random
    rnd = random.Random(seed)
    cx, cy = max(1, cells // stretch_x), cells
    grid = [[rnd.random() for _ in range(cx)] for _ in range(cy)]

    def smooth(t):
        return t * t * (3 - 2 * t)

    out = []
    for y in range(size):
        fy = y * cy / size
        y0 = int(fy)
        ty = smooth(fy - y0)
        row0, row1 = grid[y0 % cy], grid[(y0 + 1) % cy]
        line = []
        for x in range(size):
            fx = x * cx / size
            x0 = int(fx)
            tx = smooth(fx - x0)
            a = row0[x0 % cx] + (row0[(x0 + 1) % cx] - row0[x0 % cx]) * tx
            b = row1[x0 % cx] + (row1[(x0 + 1) % cx] - row1[x0 % cx]) * tx
            line.append(a + (b - a) * ty)
        out.append(line)
    return out


def _octaves(size, base_cells, count, seed, stretch_x=1):
    total = [[0.0] * size for _ in range(size)]
    weight_sum, weight = 0.0, 1.0
    for o in range(count):
        layer = _value_noise(size, base_cells << o, seed + o, stretch_x)
        for y in range(size):
            row, src = total[y], layer[y]
            for x in range(size):
                row[x] += src[x] * weight
        weight_sum += weight
        weight *= 0.5
    lo = min(min(r) for r in total)
    hi = max(max(r) for r in total)
    return [[(v - lo) / (hi - lo) for v in r] for r in total]


def _droplets(size, seed):
    """Tileable blood droplets, 0..1. Each drop's value is its 'order', so
    a shader threshold reveals more drops as the amount grows instead of
    growing every drop at once. Round drops with satellites, and splashes:
    drops stretched along the direction they flew, with a tail of smaller
    drops behind them, at random angles."""
    import math
    import random
    rnd = random.Random(seed)
    out = [[0.0] * size for _ in range(size)]

    def blob(cx, cy, radius, value, stretch=1.0, angle=0.0):
        """A soft-edged ellipse: radius across, radius * stretch along angle."""
        c, s = math.cos(angle), math.sin(angle)
        r = int(radius * stretch) + 2
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                along = (dx * c + dy * s) / stretch
                across = -dx * s + dy * c
                d = (along * along + across * across) ** 0.5
                if d > radius + 1:
                    continue
                edge = max(0.0, min(1.0, radius + 1 - d))  # soft rim
                x, y = int(cx + dx) % size, int(cy + dy) % size
                v = value * edge
                if v > out[y][x]:
                    out[y][x] = v

    for _ in range(130):
        cx, cy = rnd.randrange(size), rnd.randrange(size)
        radius = rnd.choice((1.5, 2.0, 3.0, 4.0, 5.5, 7.5))
        value = 0.25 + 0.75 * rnd.random()
        if rnd.random() < 0.5:
            # A splash: stretched, then a tail of shrinking drops behind it.
            angle = rnd.random() * 6.2832
            stretch = 1.6 + rnd.random() * 1.6
            blob(cx, cy, radius * 0.8, value, stretch, angle)
            dist = radius * 0.8 * stretch
            drop = radius * 0.45
            for _ in range(2 + rnd.randrange(3)):
                dist += drop * 2.2 + 1.0
                blob(cx - dist * math.cos(angle) + rnd.uniform(-1, 1), cy - dist * math.sin(angle) + rnd.uniform(-1, 1),
                     max(0.8, drop), value * (0.85 + 0.15 * rnd.random()), 1.3, angle)
                drop *= 0.7
        else:
            blob(cx, cy, radius, value)
            for _ in range(int(radius * 0.7)):  # satellites around the bigger drops
                a = rnd.random() * 6.2832
                d = radius + 2 + rnd.random() * radius * 1.5
                blob(cx + d * math.cos(a), cy + d * math.sin(a),
                     1.0 + rnd.random() * 2.0, value * (0.8 + 0.2 * rnd.random()))
    return out


def noise_tga():
    """The noise texture, a tileable 32-bit TGA:
    R = coarse blotches (where dust and snow gather), G = fine grain (colour
    variation), B = horizontal streaks (wind-blown dust), A = blood
    droplets: round spots of many sizes, the bigger ones with a ring of
    small satellite drops."""
    size = NOISE_SIZE
    red = _octaves(size, 4, 4, 11)
    green = _octaves(size, 32, 3, 23)
    blue = _octaves(size, 8, 3, 37, stretch_x=4)
    alpha = _droplets(size, 53)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8)
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            pixels += bytes((int(blue[y][x] * 255), int(green[y][x] * 255), int(red[y][x] * 255),
                             int(alpha[y][x] * 255)))
    return header + bytes(pixels)


def material(part, shiny=True, mesh=(0.0, 0.0)):
    """The material for a texture of a body part, a monster (None) or an
    object (OBJECT); shiny: with the environment map; mesh: MeshBase and
    MeshHeight of a cloak (0: the mesh's bounding box is used)."""
    if part == OBJECT:
        (low, high), (wounds, spatter), front = WHOLE_BODY, OBJECT_BLOOD, 0.0
    elif part:
        (low, high), (wounds, spatter), front = PART_HEIGHT[part], PART_BLOOD[part], 0.75
    else:
        (low, high), (wounds, spatter), front = WHOLE_BODY, MONSTER_BLOOD, 0.75
    vs, fs = ("vs_weather", "fs_weather") if shiny else ("vs_wthr_plain", "fs_wthr_plain")
    return MATERIAL.format(vs=vs, fs=fs, noise=NOISE_TEXTURE, low=f"{low:.2f}", high=f"{high:.2f}",
                           wounds=f"{wounds:.2f}", spatter=f"{spatter:.2f}", front=f"{front:.2f}",
                           base=f"{mesh[0]:.3f}", height=f"{mesh[1]:.3f}")


def brush_uti():
    """The clothes brush blueprint, built from the stock Rags item."""
    import json
    gff = os.path.join(TOOLS, "neverwinter", "nwn_gff.exe")
    for resref, rtype, bif, idx in nwn_key.all_entries():
        if rtype == 2025 and resref == BRUSH_TEMPLATE:
            template = nwn_key.read_bif_resource(bif, idx)
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "in.uti")
        with open(src, "wb") as f:
            f.write(template)
        item = json.loads(subprocess.run([gff, "-i", src, "-k", "json"], capture_output=True, check=True).stdout)
        item["TemplateResRef"]["value"] = BRUSH_RESREF
        item["Tag"]["value"] = BRUSH_RESREF
        item["LocalizedName"]["value"] = {"0": BRUSH_NAME}
        item["DescIdentified"]["value"] = {"0": BRUSH_DESCRIPTION}
        item["Description"]["value"] = {"0": BRUSH_DESCRIPTION}
        item["Cost"]["value"] = 2
        item["Plot"]["value"] = 0
        item["PropertiesList"]["value"] = [{
            "__struct_id": 0,
            "PropertyName": {"type": "word", "value": 15},   # ITEM_PROPERTY_CAST_SPELL
            "Subtype": {"type": "word", "value": 335},       # Unique Power Self Only
            "CostTable": {"type": "byte", "value": 3},
            "CostValue": {"type": "word", "value": 13},      # unlimited uses
            "Param1": {"type": "byte", "value": 255},
            "Param1Value": {"type": "byte", "value": 255},
            "ChanceAppear": {"type": "byte", "value": 100},
        }]
        json_path = os.path.join(tmp, "brush.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(item, f)
        out = os.path.join(tmp, "brush.uti")
        subprocess.run([gff, "-i", json_path, "-l", "json", "-o", out, "-k", "gff"], check=True)
        with open(out, "rb") as f:
            return f.read()


# ---- Build -----------------------------------------------------------------

def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "--list":
        list_erf(args[1])
        return
    if args:
        sys.exit(__doc__)
    if not os.path.exists(COMPILER):
        sys.exit(f"compiler not found: {COMPILER}")
    nwn_root = nwn_paths.nwn_root()

    # The compiler also wants an NWN user folder; the scripts need nothing
    # from it, so an empty one will do.
    with tempfile.TemporaryDirectory() as ncs, tempfile.TemporaryDirectory() as user:
        result = subprocess.run([
            COMPILER, "--root", nwn_root, "--userdirectory", user,
            "--no-require-entry-point", "-y", "-d", ncs, "-c", NSS,
        ])
        if result.returncode != 0:
            sys.exit("compile failed")
        scripts = read_file_entries(files(NSS, ".nss") + files(ncs, ".ncs"))
    # The brush blueprint goes with the scripts, so it shows up in the
    # module's item palette after the import.
    write_erf(ERF_OUT, scripts + [(BRUSH_RESREF, "uti", brush_uti())])

    print("reading the game's creature models...")
    textures, models, stock_materials, game_tables, shiny = scan_game()
    tables, used, mesh = build_tables(textures, models, game_tables)
    print("reading the game's placeable and door models...")
    tables.update(build_object_tables(textures, models, game_tables, used))
    # A texture that already has a stock material keeps it (the old heads).
    materials = sorted(set(used) - stock_materials)
    print(f"{len(materials)} creature, placeable and door textures get the weather material "
          f"({len(set(used) & stock_materials)} keep their stock material)")

    entries = read_file_entries(files(SHADERS, ".shd"))
    entries.append((NOISE_TEXTURE, "tga", noise_tga()))
    entries += [(name, "2da", text.encode("ascii")) for name, text in sorted(tables.items())]
    entries += [(name, "mtr", material(used[name], used[name] != OBJECT or name in shiny,
                                             mesh.get(name, (0.0, 0.0))).encode("ascii"))
                for name in materials]
    write_erf(HAK_OUT, entries, b"HAK ")
    print("Copy nwn_weathered.hak to your NWN hak folder and import nwn_weathered.erf into your module.")


if __name__ == "__main__":
    main()
