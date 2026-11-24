#!/usr/bin/env python3
"""Read-only Luau v14 structure and constant reader; never executes a capture.

The prototype size field is authoritative. Debug/type suffixes are skipped, not
decompiled. Instruction listings require an explicit opcode multiplier.
"""
import argparse
import base64
import hashlib
import json
import pathlib
import re
import struct
import zlib


class Reader:
    def __init__(self, data):
        self.data, self.pos = data, 0

    def take(self, count):
        end = self.pos + count
        if count < 0 or end > len(self.data):
            raise ValueError("truncated bytecode")
        result = self.data[self.pos:end]
        self.pos = end
        return result

    def number(self, fmt):
        return struct.unpack("<" + fmt, self.take(struct.calcsize("<" + fmt)))[0]

    def varint(self):
        value = 0
        for shift in range(0, 70, 7):
            byte = self.number("B")
            value |= (byte & 127) << shift
            if byte < 128:
                return value
        raise ValueError("invalid varint")


def parse(data):
    r = Reader(data)
    version, types = r.number("B"), r.number("B")
    if version != 14 or types != 3:
        raise ValueError(f"unsupported format {version}/{types}")
    strings = [None]
    for _ in range(r.varint()):
        strings.append(r.take(r.varint()).decode("utf8", "replace"))
    while r.number("B") != 0:
        r.varint()
    protos = []
    for index in range(r.varint()):
        size = r.varint()
        start = r.pos
        stack, params, upvalues, vararg, flags = [r.number("B") for _ in range(5)]
        r.take(r.varint())
        words = [r.number("I") for _ in range(r.varint())]
        constants = []
        for _ in range(r.varint()):
            tag = r.number("B")
            if tag == 0:
                value = None
            elif tag == 1:
                value = bool(r.number("B"))
            elif tag == 2:
                value = r.number("d")
            elif tag == 3:
                value = strings[r.varint()]
            elif tag == 4:
                value = {"import": r.number("I")}
            elif tag == 5:
                value = {"keys": [r.varint() for _ in range(r.varint())]}
            elif tag == 6:
                value = {"closure": r.varint()}
            elif tag in (7, 11):
                value = {"vector": [r.number("f" if tag == 7 else "d") for _ in range(4)]}
            elif tag == 8:
                value = {"table": [[r.varint(), r.number("i")] for _ in range(r.varint())]}
            else:
                raise ValueError(f"unsupported constant tag {tag} in proto {index}")
            constants.append(value)
        children = [r.varint() for _ in range(r.varint())]
        line, name = r.varint(), strings[r.varint()]
        if r.pos > start + size:
            raise ValueError("prototype boundary mismatch")
        r.pos = start + size
        protos.append(dict(index=index, name=name, line=line, words=words,
                           constants=constants, children=children, stack=stack,
                           params=params, upvalues=upvalues, flags=flags))
    main = r.varint()
    if main >= len(protos):
        raise ValueError("invalid main prototype")
    return dict(version=version, main=main, protos=protos,
                suffix_bytes=len(data)-r.pos, sha256=hashlib.sha256(data).hexdigest())


def verify(root):
    entries = []
    for p in sorted(root.glob("UPLOAD_PART_000_METADATA/catalog/*")):
        entries += [json.loads(line) for line in p.read_text().splitlines() if line]
    errors = []
    for entry in entries:
        p = root / entry["path"]
        data = p.read_bytes() if p.is_file() else b""
        if not p.is_file() or len(data) != entry["bytes"] or f"{zlib.adler32(data):08x}" != entry["adler32"]:
            errors.append(entry["path"])
    return {"catalog_entries": len(entries), "errors": errors}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("capture", type=pathlib.Path)
    ap.add_argument("--output", type=pathlib.Path, required=True)
    args = ap.parse_args()
    result = verify(args.capture)
    programs = {}
    for p in sorted(args.capture.glob("*/bytecode/game/*b64.txt")):
        data = base64.b64decode(p.read_text(), validate=True)
        digest = hashlib.sha256(data).hexdigest()
        if digest not in programs:
            parsed = parse(data)
            programs[digest] = {
                "sha256": digest, "file": p.name, "version": parsed["version"],
                "prototypes": len(parsed["protos"]),
                "instructions": sum(len(x["words"]) for x in parsed["protos"]),
                "constants": sum(len(x["constants"]) for x in parsed["protos"]),
                "suffix_bytes": parsed["suffix_bytes"],
            }
    result["programs"] = list(programs.values())
    result["totals"] = {k: sum(p[k] for p in programs.values())
                        for k in ("prototypes", "instructions", "constants")}
    result["raw_bytecode_executed"] = False
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "programs"}))
    if result["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
