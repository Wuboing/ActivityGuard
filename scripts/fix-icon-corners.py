#!/usr/bin/env python3
"""Replace dark/transparent icon corner pixels with the sampled background color."""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")

    width = height = 0
    bit_depth = color_type = 0
    idat = bytearray()

    pos = 8
    while pos + 8 <= len(data):
        length, chunk_type = struct.unpack(">I4s", data[pos : pos + 8])
        pos += 8
        chunk = data[pos : pos + length]
        pos += length + 4

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBBBBB", chunk)[:4]
        elif chunk_type == b"IDAT":
            idat.extend(chunk)
        elif chunk_type == b"IEND":
            break

    if bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"Unsupported PNG format: depth={bit_depth}, type={color_type}")

    channels = 4 if color_type == 6 else 3
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    pixels: list[tuple[int, int, int, int]] = []

    offset = 0
    prior = [0] * stride
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        row = list(raw[offset : offset + stride])
        offset += stride

        recon = [0] * stride
        for i in range(stride):
            x = row[i]
            a = recon[i - channels] if i >= channels else 0
            b = prior[i]
            c = prior[i - channels] if i >= channels else 0
            if filter_type == 0:
                value = x
            elif filter_type == 1:
                value = (x + a) & 0xFF
            elif filter_type == 2:
                value = (x + b) & 0xFF
            elif filter_type == 3:
                value = (x + ((a + b) // 2)) & 0xFF
            elif filter_type == 4:
                value = (x + paeth(a, b, c)) & 0xFF
            else:
                raise ValueError(f"Unsupported PNG filter: {filter_type}")
            recon[i] = value

        for x in range(width):
            base = x * channels
            r, g, b = recon[base], recon[base + 1], recon[base + 2]
            a = recon[base + 3] if channels == 4 else 255
            pixels.append((r, g, b, a))
        prior = recon

    return width, height, pixels


def write_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type None
        for x in range(width):
            r, g, b, a = pixels[y * width + x]
            raw.extend((r, g, b, a))

    compressed = zlib.compress(bytes(raw), level=9)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)

    def chunk(tag: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", crc)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def luminance(r: int, g: int, b: int) -> int:
    return r + g + b


def sample_background(width: int, height: int, pixels: list[tuple[int, int, int, int]], threshold: int) -> tuple[int, int, int]:
    probes = [
        (width // 2, max(0, height // 24)),
        (width // 2, min(height - 1, height - height // 24)),
        (max(0, width // 24), height // 2),
        (min(width - 1, width - width // 24), height // 2),
        (width // 4, height // 10),
        (3 * width // 4, height // 10),
        (width // 2, height // 6),
    ]

    best = None
    best_score = -1
    for x, y in probes:
        r, g, b, a = pixels[y * width + x]
        if a < 16 or luminance(r, g, b) <= threshold * 3:
            continue
        score = luminance(r, g, b)
        if score > best_score:
            best_score = score
            best = (r, g, b)

    return best or (211, 225, 238)


def fix_corners(input_path: Path, output_path: Path, threshold: int = 24) -> None:
    width, height, pixels = read_png(input_path)
    bg = sample_background(width, height, pixels, threshold)

    fixed: list[tuple[int, int, int, int]] = []
    for r, g, b, a in pixels:
        if a < 16 or luminance(r, g, b) <= threshold * 3:
            fixed.append((bg[0], bg[1], bg[2], 255))
        else:
            fixed.append((r, g, b, 255))

    write_png(output_path, width, height, fixed)


def main() -> int:
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.png> <output.png> [threshold]", file=sys.stderr)
        return 1

    threshold = int(sys.argv[3]) if len(sys.argv) > 3 else 24
    fix_corners(Path(sys.argv[1]), Path(sys.argv[2]), threshold)
    print(f"Fixed icon corners -> {sys.argv[2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
