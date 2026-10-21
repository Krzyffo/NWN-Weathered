"""Minimal reader for NWN KEY/BIF archives.

Lists or extracts game resources (scripts, blueprints) from an NWN:EE install.

  py tools/nwn_key.py list  <pattern> [--type nss]
  py tools/nwn_key.py extract <resref.ext> <out_dir>
"""
import os
import struct
import sys
import fnmatch

import nwn_paths


RES_TYPES = {
    2009: "nss", 2010: "ncs", 2017: "2da", 2025: "uti", 2027: "utc",
    2029: "dlg", 2032: "utt", 2040: "utd", 2042: "uts", 2044: "utp",
    2058: "utw", 2002: "mdl", 3: "tga", 2033: "dds", 4: "wav",
}
EXT_TO_TYPE = {v: k for k, v in RES_TYPES.items()}


def read_key(key_path):
    with open(key_path, "rb") as f:
        data = f.read()
    sig, ver, bif_count, key_count, off_files, off_keys = struct.unpack_from(
        "<4s4sIIII", data, 0)
    if sig != b"KEY ":
        raise ValueError(f"{key_path}: not a KEY file ({sig!r} {ver!r})")
    bifs = []
    for i in range(bif_count):
        size, name_off, name_len, _drives = struct.unpack_from(
            "<IIHH", data, off_files + i * 12)
        name = data[name_off:name_off + name_len].rstrip(b"\0").decode()
        bifs.append(name.replace("\\", os.sep))
    entries = []
    for i in range(key_count):
        resref, rtype, rid = struct.unpack_from("<16sHI", data, off_keys + i * 22)
        resref = resref.rstrip(b"\0").decode("latin-1").lower()
        entries.append((resref, rtype, rid >> 20, rid & 0xFFFFF))
    return bifs, entries


def all_entries():
    data_dir = os.path.join(nwn_paths.nwn_root(), "data")
    for key in ("nwn_base.key", "nwn_retail.key"):
        path = os.path.join(data_dir, key)
        if not os.path.exists(path):
            continue
        bifs, entries = read_key(path)
        for resref, rtype, bif_idx, res_idx in entries:
            yield resref, rtype, bifs[bif_idx], res_idx


def read_bif_resource(bif_rel, res_idx):
    path = os.path.join(nwn_paths.nwn_root(), bif_rel)
    with open(path, "rb") as f:
        sig, ver, var_count, _fixed, var_off = struct.unpack("<4s4sIII", f.read(20))
        if sig != b"BIFF":
            raise ValueError(f"{path}: not a BIF file")
        f.seek(var_off)
        table = f.read(var_count * 16)
        for i in range(var_count):
            rid, off, size, _t = struct.unpack_from("<IIII", table, i * 16)
            if rid & 0xFFFFF == res_idx:
                f.seek(off)
                return f.read(size)
    raise KeyError(f"resource {res_idx} not in {bif_rel}")


def main(argv):
    if len(argv) >= 2 and argv[0] == "list":
        want = EXT_TO_TYPE.get(argv[argv.index("--type") + 1]) if "--type" in argv else None
        for resref, rtype, bif, _ in all_entries():
            if fnmatch.fnmatch(resref, argv[1]) and (want is None or rtype == want):
                print(f"{resref}.{RES_TYPES.get(rtype, rtype)}\t{bif}")
        return 0
    if len(argv) == 3 and argv[0] == "extract":
        name, ext = argv[1].lower().rsplit(".", 1)
        rtype = EXT_TO_TYPE[ext]
        for resref, t, bif, idx in all_entries():
            if resref == name and t == rtype:
                os.makedirs(argv[2], exist_ok=True)
                out = os.path.join(argv[2], argv[1].lower())
                with open(out, "wb") as f:
                    f.write(read_bif_resource(bif, idx))
                print(out)
                return 0
        print(f"not found: {argv[1]}", file=sys.stderr)
        return 1
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
