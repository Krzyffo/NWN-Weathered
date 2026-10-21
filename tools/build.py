"""Build NWN-Weathered.

  py tools/build.py               generate, compile and pack
  py tools/build.py --list FILE   print the contents of an .erf/.hak

Writes two files next to this script:
- nwn_weathered.hak: the weather shader, one .mtr material per creature
  texture of the base game, and the lookup tables the scripts use to find
  a creature's materials.
- nwn_weathered.erf: src/nss/*.nss and their compiled .ncs, for
  File > Import in the toolset.

Why the tables: the engine gives a texture a material when a .mtr of the
same name exists, and a script sets a material's values on one creature
by that name. Scripts can't read a creature's texture names, and they don't
follow from the model names (an elf's pelvis003 is textured with
pfh0_pelvis001), so this reads every player body part and monster model
and records which textures each one uses:
- wthr_<part>.2da   one per body part; row = part number, column = model
                    prefix such as pmd0 (male dwarf, normal phenotype)
- wthr_appear.2da   row = appearance.2da row, TEXTURES column, for monsters
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

RES_TYPES = {"nss": 2009, "ncs": 2010, "2da": 2017, "shd": 2069, "mtr": 2072}
TYPE_EXT = {v: k for k, v in RES_TYPES.items()}
T_TGA, T_PLT, T_MDL, T_2DA, T_DDS, T_MTR = 3, 6, 2002, 2017, 2033, 2072
HEADER_SIZE = 160
KEY_SIZE = 24
RES_SIZE = 8

# Body part names in the model files, indexed like CREATURE_PART_* and
# ITEM_APPR_ARMOR_MODEL_* (0-18), plus the head (CREATURE_PART_HEAD = 20).
PARTS = ["footr", "footl", "shinr", "shinl", "legl", "legr", "pelvis", "chest", "belt", "neck",
         "forer", "forel", "bicepr", "bicepl", "shor", "shol", "handr", "handl", "robe", "head"]
PART_MODEL = re.compile(r"^(p[mf][a-z]\d+)_(" + "|".join(PARTS) + r")(\d{3})$")

MATERIAL = """customshadervs vslit_sm
customshaderfs fs_weather
parameter float DustAmount 0.0
parameter float SnowAmount 0.0
"""


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
    textures, models, stock_materials = set(), {}, set()
    appearance = None
    for resref, rtype, bif, idx in nwn_key.all_entries():
        if rtype in (T_TGA, T_DDS, T_PLT):
            textures.add(resref)
        elif rtype == T_MDL:
            models[resref] = (bif, idx)
        elif rtype == T_MTR:
            stock_materials.add(resref)
        elif rtype == T_2DA and resref == "appearance":
            appearance = (bif, idx)
    # Later archives override earlier ones; the last copy of appearance.2da wins.
    rows = parse_2da(nwn_key.read_bif_resource(*appearance).decode("latin-1"))
    return textures, models, stock_materials, rows


def build_tables(textures, models, appearance_rows):
    """(2DA files as {resref: text}, set of textures used)."""
    used = set()

    # Player body parts: {part: {prefix: {number: textures}}}
    parts = {p: {} for p in PARTS}
    for name, loc in models.items():
        m = PART_MODEL.match(name)
        if not m:
            continue
        prefix, part, number = m.group(1), m.group(2), int(m.group(3))
        tex = model_textures(nwn_key.read_bif_resource(*loc), textures)
        if tex:
            parts[part].setdefault(prefix, {})[number] = tex
            used.update(tex)

    tables = {}
    for part, by_prefix in parts.items():
        prefixes = sorted(by_prefix)
        last = max((n for d in by_prefix.values() for n in d), default=0)
        lines = ["2DA V2.0", "", "    " + " ".join(prefixes)]
        for row in range(last + 1):
            cells = [";".join(by_prefix[p].get(row, [])) or "****" for p in prefixes]
            lines.append(f"{row} " + " ".join(cells))
        tables["wthr_" + part] = "\n".join(lines) + "\n"

    # Monsters: the model is the RACE column of appearance.2da.
    lines = ["2DA V2.0", "", "    TEXTURES"]
    for row, cells in enumerate(appearance_rows):
        model = cells.get("RACE", "****").lower()
        tex = []
        if cells.get("MODELTYPE", "").upper() != "P" and model in models:
            tex = model_textures(nwn_key.read_bif_resource(*models[model]), textures)
            used.update(tex)
        lines.append(f"{row} " + (";".join(tex) or "****"))
    tables["wthr_appear"] = "\n".join(lines) + "\n"
    return tables, used


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
        write_erf(ERF_OUT, read_file_entries(files(NSS, ".nss") + files(ncs, ".ncs")))

    print("reading the game's creature models...")
    textures, models, stock_materials, appearance = scan_game()
    tables, used = build_tables(textures, models, appearance)
    # A texture that already has a stock material keeps it (the old heads).
    materials = sorted(used - stock_materials)
    print(f"{len(materials)} creature textures get the weather material "
          f"({len(used & stock_materials)} keep their stock material)")

    entries = read_file_entries(files(SHADERS, ".shd"))
    entries += [(name, "2da", text.encode("ascii")) for name, text in sorted(tables.items())]
    entries += [(name, "mtr", MATERIAL.encode("ascii")) for name in materials]
    write_erf(HAK_OUT, entries, b"HAK ")
    print("Copy nwn_weathered.hak to your NWN hak folder and import nwn_weathered.erf into your module.")


if __name__ == "__main__":
    main()
