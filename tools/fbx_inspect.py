"""Print what a binary FBX really contains: unit settings, every Model node's transform,
and each Geometry's raw vertex bounds. Used to check exports before uploading.

Run: python3 tools/fbx_inspect.py exports/Props/Prop_SupplyCrate.fbx
"""
from __future__ import annotations

import struct
import sys
import zlib


def _read_props(data: bytes, pos: int, n: int):
    props = []
    for _ in range(n):
        t = chr(data[pos]); pos += 1
        if t == "Y":
            props.append(struct.unpack_from("<h", data, pos)[0]); pos += 2
        elif t == "C":
            props.append(bool(data[pos])); pos += 1
        elif t == "I":
            props.append(struct.unpack_from("<i", data, pos)[0]); pos += 4
        elif t == "F":
            props.append(struct.unpack_from("<f", data, pos)[0]); pos += 4
        elif t == "D":
            props.append(struct.unpack_from("<d", data, pos)[0]); pos += 8
        elif t == "L":
            props.append(struct.unpack_from("<q", data, pos)[0]); pos += 8
        elif t in "fdlib":
            count, enc, clen = struct.unpack_from("<III", data, pos); pos += 12
            raw = data[pos:pos + clen]; pos += clen
            if enc == 1:
                raw = zlib.decompress(raw)
            fmt = {"f": "f", "d": "d", "l": "q", "i": "i", "b": "?"}[t]
            props.append(list(struct.unpack(f"<{count}{fmt}", raw)))
        elif t in "SR":
            ln = struct.unpack_from("<I", data, pos)[0]; pos += 4
            raw = data[pos:pos + ln]; pos += ln
            props.append(raw.decode("utf-8", "replace") if t == "S" else raw)
        else:
            raise ValueError(f"unknown property type {t!r} at {pos}")
    return props, pos


def parse(path: str):
    data = open(path, "rb").read()
    assert data[:20] == b"Kaydara FBX Binary  ", "not a binary FBX"
    version = struct.unpack_from("<I", data, 23)[0]
    wide = version >= 7500
    hdr = 25 if wide else 13

    def node(pos: int):
        if wide:
            end, nprops, plen = struct.unpack_from("<QQQ", data, pos)
        else:
            end, nprops, plen = struct.unpack_from("<III", data, pos)
        if end == 0:
            return None, pos + hdr
        nlen = data[pos + hdr - 1 + 0] if False else data[pos + (24 if wide else 12)]
        name = data[pos + hdr:pos + hdr + nlen].decode()
        p = pos + hdr + nlen
        props, p = _read_props(data, p, nprops)
        children = []
        while p < end:
            child, p = node(p)
            if child is None:
                break
            children.append(child)
        return {"name": name, "props": props, "children": children}, end

    nodes, pos = [], 27
    while pos < len(data) - 160:
        n, pos = node(pos)
        if n is None:
            break
        nodes.append(n)
    return version, nodes


def find(nodes, name):
    for n in nodes:
        if n["name"] == name:
            yield n
        yield from find(n["children"], name)


def main(path: str) -> None:
    version, nodes = parse(path)
    print(f"FBX version {version}")
    for gs in find(nodes, "GlobalSettings"):
        for p70 in find(gs["children"], "P"):
            if p70["props"][0] in ("UpAxis", "UpAxisSign", "FrontAxis", "FrontAxisSign", "CoordAxis",
                                   "CoordAxisSign", "UnitScaleFactor", "OriginalUnitScaleFactor"):
                print(f"  {p70['props'][0]} = {p70['props'][-1]}")
    for m in find(nodes, "Model"):
        if len(m["props"]) >= 3 and m["props"][2] == "Mesh":
            name = m["props"][1].split("\x00")[0]
            tr = {p["props"][0]: p["props"][-3:] for p in find(m["children"], "P")
                  if p["props"][0] in ("Lcl Translation", "Lcl Rotation", "Lcl Scaling")}
            print(f"  Model {name}: {tr}")
    for g in find(nodes, "Geometry"):
        v = next(find(g["children"], "Vertices"))["props"][0]
        xs, ys, zs = v[0::3], v[1::3], v[2::3]
        print(f"  Geometry {g['props'][1].split(chr(0))[0]}: {len(v)//3} verts, "
              f"x {min(xs):.3f}..{max(xs):.3f}  y {min(ys):.3f}..{max(ys):.3f}  z {min(zs):.3f}..{max(zs):.3f}")


if __name__ == "__main__":
    main(sys.argv[1])
