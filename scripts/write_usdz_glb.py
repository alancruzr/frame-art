#!/usr/bin/env python3
"""Build Quick Look USDZ (8 mm textured box, 64-byte aligned) and a matching GLB."""
from __future__ import annotations

import json
import struct
import sys
import zlib
from pathlib import Path

THICKNESS_M = 0.008


def extra_length(current_offset: int, header_base: int) -> int:
    misalignment = (current_offset + header_base) % 64
    if misalignment == 0:
        return 0
    extra = 64 - misalignment
    if 0 < extra < 4:
        extra += 64
    return extra


def write_usdz(destination: Path, files: list[tuple[str, bytes]]) -> None:
    entries: list[tuple[str, int, int, int]] = []
    archive = bytearray()
    for name, payload in files:
        name_data = name.encode("utf-8")
        crc = zlib.crc32(payload) & 0xFFFFFFFF
        size = len(payload)
        header_base = 30 + len(name_data)
        extra_len = extra_length(len(archive), header_base)
        local = bytearray()
        local += struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, 0, 0, 0, 0, crc, size, size, len(name_data), extra_len)
        local += name_data
        if extra_len:
            local += b"\x00" * extra_len
        offset = len(archive)
        archive += local
        archive += payload
        entries.append((name, crc, size, offset))

    cd_start = len(archive)
    for name, crc, size, offset in entries:
        name_data = name.encode("utf-8")
        cd = bytearray()
        cd += struct.pack(
            "<IHHHHHHIIIHHHHHII",
            0x02014B50,
            20,
            20,
            0,
            0,
            0,
            0,
            crc,
            size,
            size,
            len(name_data),
            0,
            0,
            0,
            0,
            0,
            offset,
        )
        cd += name_data
        archive += cd

    cd_size = len(archive) - cd_start
    archive += struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, len(entries), len(entries), cd_size, cd_start, 0)
    destination.write_bytes(bytes(archive))


def fmt(v: float) -> str:
    return f"{v:.6f}"


def make_usda(display_name: str, width_m: float, height_m: float, texture_name: str = "texture.jpg") -> str:
    hw = width_m / 2
    hh = height_m / 2
    ht = THICKNESS_M / 2
    escaped = display_name.replace("\\", "\\\\").replace('"', '\\"')
    nw, nh, nt = fmt(-hw), fmt(-hh), fmt(-ht)
    pw, ph, pt = fmt(hw), fmt(hh), fmt(ht)
    return f"""#usda 1.0
(
    defaultPrim = "Artwork"
    metersPerUnit = 1
    upAxis = "Y"
    doc = "Frame Art — losa texturizada 8 mm para AR Quick Look"
)

def Xform "Artwork" (
    assetInfo = {{
        string name = "{escaped}"
    }}
    kind = "component"
    prepend apiSchemas = ["Preliminary_AnchoringAPI"]
)
{{
    uniform token preliminary:anchoring:type = "plane"
    uniform token preliminary:planeAnchoring:alignment = "vertical"

    def Scope "Looks"
    {{
        def Material "PaintingMaterial"
        {{
            token outputs:surface.connect = </Artwork/Looks/PaintingMaterial/PreviewSurface.outputs:surface>

            def Shader "PreviewSurface"
            {{
                uniform token info:id = "UsdPreviewSurface"
                color3f inputs:diffuseColor.connect = </Artwork/Looks/PaintingMaterial/DiffuseTexture.outputs:rgb>
                color3f inputs:emissiveColor.connect = </Artwork/Looks/PaintingMaterial/DiffuseTexture.outputs:rgb>
                float inputs:metallic = 0
                float inputs:roughness = 1
                int inputs:useSpecularWorkflow = 0
                token outputs:surface
            }}

            def Shader "DiffuseTexture"
            {{
                uniform token info:id = "UsdUVTexture"
                asset inputs:file = @{texture_name}@
                token inputs:sourceColorSpace = "sRGB"
                float2 inputs:st.connect = </Artwork/Looks/PaintingMaterial/PrimvarST.outputs:result>
                token inputs:wrapS = "clamp"
                token inputs:wrapT = "clamp"
                float3 outputs:rgb
            }}

            def Shader "PrimvarST"
            {{
                uniform token info:id = "UsdPrimvarReader_float2"
                token inputs:varname = "st"
                float2 outputs:result
            }}
        }}

        def Material "EdgeMaterial"
        {{
            token outputs:surface.connect = </Artwork/Looks/EdgeMaterial/PreviewSurface.outputs:surface>

            def Shader "PreviewSurface"
            {{
                uniform token info:id = "UsdPreviewSurface"
                color3f inputs:diffuseColor = (0.12, 0.10, 0.08)
                color3f inputs:emissiveColor = (0.08, 0.07, 0.05)
                float inputs:metallic = 0
                float inputs:roughness = 1
                token outputs:surface
            }}
        }}
    }}

    def Mesh "Painting"
    {{
        uniform bool doubleSided = 1
        float3[] extent = [({nw}, {nh}, {nt}), ({pw}, {ph}, {pt})]
        int[] faceVertexCounts = [3, 3]
        int[] faceVertexIndices = [0, 1, 2, 0, 2, 3]
        rel material:binding = </Artwork/Looks/PaintingMaterial>
        normal3f[] normals = [(0, 0, 1), (0, 0, 1), (0, 0, 1), (0, 0, 1)] (
            interpolation = "vertex"
        )
        point3f[] points = [({nw}, {nh}, {pt}), ({pw}, {nh}, {pt}), ({pw}, {ph}, {pt}), ({nw}, {ph}, {pt})]
        texCoord2f[] primvars:st = [(0, 0), (1, 0), (1, 1), (0, 1)] (
            interpolation = "vertex"
        )
        uniform token subdivisionScheme = "none"
    }}

    def Mesh "Slab"
    {{
        float3[] extent = [({nw}, {nh}, {nt}), ({pw}, {ph}, {pt})]
        int[] faceVertexCounts = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
        int[] faceVertexIndices = [0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7, 8, 9, 10, 8, 10, 11, 12, 13, 14, 12, 14, 15, 16, 17, 18, 16, 18, 19]
        rel material:binding = </Artwork/Looks/EdgeMaterial>
        normal3f[] normals = [(0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (1, 0, 0), (1, 0, 0), (1, 0, 0), (1, 0, 0), (-1, 0, 0), (-1, 0, 0), (-1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, 1, 0), (0, 1, 0), (0, 1, 0), (0, -1, 0), (0, -1, 0), (0, -1, 0), (0, -1, 0)] (
            interpolation = "vertex"
        )
        point3f[] points = [({pw}, {nh}, {nt}), ({nw}, {nh}, {nt}), ({nw}, {ph}, {nt}), ({pw}, {ph}, {nt}), ({pw}, {nh}, {pt}), ({pw}, {nh}, {nt}), ({pw}, {ph}, {nt}), ({pw}, {ph}, {pt}), ({nw}, {nh}, {nt}), ({nw}, {nh}, {pt}), ({nw}, {ph}, {pt}), ({nw}, {ph}, {nt}), ({nw}, {ph}, {pt}), ({pw}, {ph}, {pt}), ({pw}, {ph}, {nt}), ({nw}, {ph}, {nt}), ({nw}, {nh}, {nt}), ({pw}, {nh}, {nt}), ({pw}, {nh}, {pt}), ({nw}, {nh}, {pt})]
        uniform token subdivisionScheme = "none"
    }}
}}
"""


def pack_f32(values: list[float]) -> bytes:
    return b"".join(struct.pack("<f", v) for v in values)


def box_geometry(hw: float, hh: float, ht: float) -> tuple[list[float], list[float], list[float], list[int]]:
    positions = [
        -hw, -hh,  ht,   hw, -hh,  ht,   hw,  hh,  ht,  -hw,  hh,  ht,
         hw, -hh,  ht,   hw, -hh, -ht,   hw,  hh, -ht,   hw,  hh,  ht,
         hw, -hh, -ht,  -hw, -hh, -ht,  -hw,  hh, -ht,   hw,  hh, -ht,
        -hw, -hh, -ht,  -hw, -hh,  ht,  -hw,  hh,  ht,  -hw,  hh, -ht,
        -hw,  hh,  ht,   hw,  hh,  ht,   hw,  hh, -ht,  -hw,  hh, -ht,
        -hw, -hh, -ht,   hw, -hh, -ht,   hw, -hh,  ht,  -hw, -hh,  ht,
    ]
    normals = [
        0, 0, 1,  0, 0, 1,  0, 0, 1,  0, 0, 1,
        1, 0, 0,  1, 0, 0,  1, 0, 0,  1, 0, 0,
        0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1,
        -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0,
        0, 1, 0,  0, 1, 0,  0, 1, 0,  0, 1, 0,
        0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0,
    ]
    uvs = (
        [0, 1, 1, 1, 1, 0, 0, 0]
        + [0, 0, 0, 0, 0, 0, 0, 0]
        + [1, 1, 0, 1, 0, 0, 1, 0]
        + [0, 0, 0, 0, 0, 0, 0, 0]
        + [0, 0, 0, 0, 0, 0, 0, 0]
        + [0, 0, 0, 0, 0, 0, 0, 0]
    )
    indices: list[int] = []
    for face in range(6):
        b = face * 4
        indices.extend([b, b + 1, b + 2, b, b + 2, b + 3])
    return positions, normals, uvs, indices


def write_glb(destination: Path, jpeg: bytes, width_m: float, height_m: float, title: str) -> None:
    hw = width_m / 2.0
    hh = height_m / 2.0
    ht = THICKNESS_M / 2.0
    positions, normals, uvs, indices = box_geometry(hw, hh, ht)
    bin_data = bytearray()
    bin_data += pack_f32(positions)
    bin_data += pack_f32(normals)
    bin_data += pack_f32(uvs)
    for i in indices:
        bin_data += struct.pack("<H", i)
    while len(bin_data) % 4:
        bin_data += b"\x00"
    image_offset = len(bin_data)
    bin_data += jpeg
    while len(bin_data) % 4:
        bin_data += b"\x00"

    pos_len = 24 * 3 * 4
    nrm_len = 24 * 3 * 4
    uv_len = 24 * 2 * 4
    idx_len = 36 * 2

    doc = {
        "asset": {"generator": "Frame Art", "version": "2.0"},
        "extensionsUsed": ["KHR_materials_unlit"],
        "scene": 0,
        "scenes": [{"name": title, "nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "Artwork"}],
        "meshes": [
            {
                "name": "Painting",
                "primitives": [
                    {
                        "attributes": {"NORMAL": 1, "POSITION": 0, "TEXCOORD_0": 2},
                        "indices": 3,
                        "material": 0,
                    }
                ],
            }
        ],
        "materials": [
            {
                "doubleSided": True,
                "extensions": {"KHR_materials_unlit": {}},
                "name": "Painting",
                "pbrMetallicRoughness": {
                    "baseColorTexture": {"index": 0},
                    "metallicFactor": 0,
                    "roughnessFactor": 1,
                },
            }
        ],
        "textures": [{"sampler": 0, "source": 0}],
        "images": [{"bufferView": 4, "mimeType": "image/jpeg"}],
        "samplers": [{"magFilter": 9729, "minFilter": 9729, "wrapS": 33071, "wrapT": 33071}],
        "buffers": [{"byteLength": len(bin_data)}],
        "bufferViews": [
            {"buffer": 0, "byteLength": pos_len, "byteOffset": 0, "target": 34962},
            {"buffer": 0, "byteLength": nrm_len, "byteOffset": pos_len, "target": 34962},
            {"buffer": 0, "byteLength": uv_len, "byteOffset": pos_len + nrm_len, "target": 34962},
            {"buffer": 0, "byteLength": idx_len, "byteOffset": pos_len + nrm_len + uv_len, "target": 34963},
            {"buffer": 0, "byteLength": len(jpeg), "byteOffset": image_offset},
        ],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": 24,
                "max": [hw, hh, ht],
                "min": [-hw, -hh, -ht],
                "type": "VEC3",
            },
            {"bufferView": 1, "componentType": 5126, "count": 24, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": 24, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123, "count": 36, "type": "SCALAR"},
        ],
    }
    json_data = bytearray(json.dumps(doc, separators=(",", ":"), sort_keys=True).encode("utf-8"))
    while len(json_data) % 4:
        json_data += b" "
    total = 12 + 8 + len(json_data) + 8 + len(bin_data)
    glb = bytearray()
    glb += struct.pack("<III", 0x46546C67, 2, total)
    glb += struct.pack("<II", len(json_data), 0x4E4F534A)
    glb += json_data
    glb += struct.pack("<II", len(bin_data), 0x004E4942)
    glb += bin_data
    destination.write_bytes(bytes(glb))


def build(jpeg_path: Path, out_dir: Path, title: str, width_m: float, height_m: float) -> None:
    jpeg = jpeg_path.read_bytes()
    out_dir.mkdir(parents=True, exist_ok=True)
    height_m = height_m if height_m >= 0.02 else width_m
    usda = make_usda(title, width_m, height_m).encode("utf-8")
    write_usdz(out_dir / "model.usdz", [("Artwork.usda", usda), ("texture.jpg", jpeg)])
    write_glb(out_dir / "model.glb", jpeg, width_m, height_m, title)
    print(f"wrote {out_dir / 'model.usdz'} and {out_dir / 'model.glb'}")


def main() -> None:
    if len(sys.argv) < 6:
        print("usage: write_usdz_glb.py jpeg out_dir title width_m height_m", file=sys.stderr)
        sys.exit(2)
    build(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], float(sys.argv[4]), float(sys.argv[5]))


if __name__ == "__main__":
    main()
