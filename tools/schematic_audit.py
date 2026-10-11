#!/usr/bin/env python3
"""Read-only Litematica structural audit. Passing never implies Minecraft function."""
import argparse
import collections
import gzip
import hashlib
import json
import math
import pathlib
import struct

class NBT:
    def __init__(self, data):
        self.data = memoryview(data)
        self.pos = 0

    def take(self, n):
        if n < 0 or self.pos + n > len(self.data):
            raise ValueError("Invalid/truncated NBT length")
        result = self.data[self.pos:self.pos+n]
        self.pos += n
        return result

    def number(self, fmt):
        return struct.unpack(">" + fmt, self.take(struct.calcsize(">" + fmt)))[0]

    def string(self):
        return self.take(self.number("H")).tobytes().decode("utf-8")

    def payload(self, tag, depth=0):
        if depth > 70:
            raise ValueError("NBT depth limit")
        fmt = {1:"b", 2:"h", 3:"i", 4:"q", 5:"f", 6:"d"}
        if tag in fmt:
            return self.number(fmt[tag])
        if tag == 7:
            return self.take(self.number("i")).tobytes()
        if tag == 8:
            return self.string()
        if tag == 9:
            child = self.number("b")
            n = self.number("i")
            if not 0 <= n <= 50000000:
                raise ValueError("Invalid NBT list size")
            return [self.payload(child, depth+1) for _ in range(n)]
        if tag == 10:
            result = {}
            while True:
                child = self.number("b")
                if child == 0:
                    return result
                name = self.string()
                if name in result:
                    raise ValueError("Duplicate NBT key: " + name)
                result[name] = self.payload(child, depth+1)
        if tag in (11,12):
            n = self.number("i")
            if not 0 <= n <= 20000000:
                raise ValueError("Invalid NBT array size")
            char = "i" if tag == 11 else "q"
            return list(struct.unpack(">" + char*n, self.take(n*struct.calcsize(char))))
        raise ValueError("Unsupported NBT tag type: " + str(tag))

def check(path, expected_sha=None):
    path = pathlib.Path(path)
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    if expected_sha and sha.lower() != expected_sha.lower():
        raise ValueError("Wrong file: SHA-256 does not match expected")
    with gzip.open(path, "rb") as stream:
        data = stream.read(100*1024*1024 + 1)
    if len(data) > 100*1024*1024:
        raise ValueError("Decompressed schematic exceeds limit")
    decoder = NBT(data)
    if decoder.number("b") != 10:
        raise ValueError("NBT root must be compound")
    decoder.string()
    root = decoder.payload(10)
    if decoder.pos != len(data):
        raise ValueError("Trailing NBT data")
    regions = root.get("Regions")
    if not isinstance(regions, dict) or not regions:
        raise ValueError("Schematic missing regions")
    report = {"file":path.name,"sha256":sha,
              "minecraft_data_version":root.get("MinecraftDataVersion"),
              "region_count":len(regions),"regions":{},
              "totals":{"non_air":0,"hoppers":0,"redstone_wire":0,
                        "block_entities":0,"entities":0}}
    for name, region in regions.items():
        size = [abs(region["Size"][k]) for k in ("x","y","z")]
        volume = math.prod(size)
        if volume <= 0:
            raise ValueError("Invalid region size")
        palette = region["BlockStatePalette"]
        bits = max(2,(len(palette)-1).bit_length())
        packed = region["BlockStates"]
        if len(packed) != (volume*bits+63)//64:
            raise ValueError("Incorrect packed data size")
        mask = (1<<bits)-1
        histogram = collections.Counter()
        for pos in range(volume):
            bit = pos*bits
            wi, shift = divmod(bit,64)
            value = (packed[wi] & ((1<<64)-1)) >> shift
            if shift+bits > 64:
                value |= (packed[wi+1] & ((1<<64)-1)) << (64-shift)
            index = value & mask
            if index >= len(palette):
                raise ValueError("Invalid palette index at block "+str(pos))
            histogram[palette[index]["Name"]] += 1
        block_entities = region.get("TileEntities",[])
        unique = set()
        for entity in block_entities:
            xyz = tuple(entity.get(k) for k in ("x","y","z"))
            if xyz in unique:
                raise ValueError("Duplicate block entity: "+str(xyz))
            unique.add(xyz)
            if any(not isinstance(v,int) or not 0 <= v < s for v,s in zip(xyz,size)):
                raise ValueError("Out-of-bounds block entity: "+str(xyz))
        non_air = volume-histogram.get("minecraft:air",0)
        counts = {"non_air":non_air,"hoppers":histogram.get("minecraft:hopper",0),
                  "redstone_wire":histogram.get("minecraft:redstone_wire",0),
                  "block_entities":len(block_entities),"entities":len(region.get("Entities",[]))}
        report["regions"][name] = {"dimensions":size,"palette":len(palette),
                                   **counts,"top_blocks":histogram.most_common(12)}
        for k in report["totals"]:
            report["totals"][k] += counts[k]
    return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("schematic")
    parser.add_argument("--sha256", default=None)
    args = parser.parse_args()
    try:
        report = check(args.schematic,args.sha256)
        print(json.dumps({"status":"STRUCTURAL_PASS","report":report},indent=2))
    except Exception as error:
        print(json.dumps({"status":"STRUCTURAL_FAIL","error":str(error)}))
        raise SystemExit(1)
