#!/usr/bin/env python3
"""Gera os ícones do PWA (PNG puro — sem dependências externas).

Desenho: bússola (o guia é o "catálogo de especialistas 🧭") — fundo índigo
(--accent #4f46e5), anel branco, agulha norte branca / sul teal (--accent2),
pontos leste/oeste suaves. Determinístico: mesma entrada → mesmos bytes.

Saídas em pwa-icons/:
  icon-192.png          (qualquer propósito, cantos arredondados, fundo transparente)
  icon-512.png          (idem, 512)
  icon-maskable-512.png (full-bleed p/ zone segura de máscara Android)
  apple-touch-icon.png  (180, full-bleed opaco — iOS arredonda sozinho)
"""
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "pwa-icons"
SS = 3  # supersampling (anti-aliasing por caixa 3×3)

# paleta (bate com o CSS do guia)
INDIGO = (79, 70, 229, 255)      # #4f46e5  --accent
INDIGO_DARK = (55, 48, 163, 255)
TEAL = (45, 212, 191, 255)       # #2dd4bf  --accent2
WHITE = (255, 255, 255, 255)
SOFT = (165, 180, 252, 255)      # #a5b4fc  pontos E/W
TRANSPARENT = (0, 0, 0, 0)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))


def rounded_rect(x, y, x0, y0, x1, y1, r):
    """SDF de retângulo com cantos arredondados: dentro do retângulo E a
    distância ao 'retângulo interno encolhido' cabe no raio."""
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    dx = max(x0 + r - x, x - (x1 - r), 0)
    dy = max(y0 + r - y, y - (y1 - r), 0)
    return dx * dx + dy * dy <= r * r


def in_tri(px, py, ax, ay, bx, by, cx, cy):
    d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
    d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
    d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
    has_neg = d1 < 0 or d2 < 0 or d3 < 0
    has_pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (has_neg and has_pos)


def render(size, full_bleed, content_scale=1.0):
    """Rasteriza o ícone; devolve lista size×size de RGBA."""
    hi = size * SS
    c = hi / 2.0
    s = content_scale
    # geometria em coordenadas do hi-res (proporções pensadas p/ 512 e escaladas)
    ring_r = hi * 0.293 * s
    ring_w = hi * 0.066 * s
    rrect = hi * 0.195
    apex_n = c - hi * 0.267 * s
    tri_base = hi * 0.058 * s
    tri_hw = hi * 0.062 * s
    ew_apex = hi * 0.155 * s
    ew_off = hi * 0.047 * s
    hub_r = hi * 0.047 * s
    dot_r = hi * 0.0175 * s

    def tri_n(x, y):  return in_tri(x, y, c, apex_n, c - tri_hw, c + tri_base, c + tri_hw, c + tri_base)
    def tri_s(x, y):  return in_tri(x, y, c, 2 * c - apex_n, c - tri_hw, c - tri_base, c + tri_hw, c - tri_base)
    def tri_e(x, y):  return in_tri(x, y, c + ew_apex, c, c + ew_off, c - ew_off * 0.62, c + ew_off, c + ew_off * 0.62)
    def tri_w(x, y):  return in_tri(x, y, c - ew_apex, c, c - ew_off, c - ew_off * 0.62, c - ew_off, c + ew_off * 0.62)

    px = [[TRANSPARENT] * hi for _ in range(hi)]
    for y in range(hi):
        for x in range(hi):
            dist2 = (x - c) ** 2 + (y - c) ** 2
            # fundo (full-bleed para maskable/apple; cantos arredondados no padrão)
            if full_bleed or rounded_rect(x, y, 0, 0, hi - 1, hi - 1, rrect):
                col = lerp(INDIGO, INDIGO_DARK, y / hi)  # leve gradiente vertical
            else:
                continue
            if dist2 <= (ring_r + ring_w / 2) ** 2 and dist2 >= (ring_r - ring_w / 2) ** 2:
                col = WHITE  # anel da bússola
            elif tri_n(x, y):
                col = WHITE
            elif tri_s(x, y):
                col = TEAL
            elif tri_e(x, y) or tri_w(x, y):
                col = SOFT
            elif dist2 <= hub_r ** 2:
                col = INDIGO
            if dist2 <= dot_r ** 2:
                col = WHITE
            px[x][y] = col

    # downsample por caixa SS×SS (RGBA com alpha premultiplicado p/ média correta)
    out = [[(0, 0, 0, 0)] * size for _ in range(size)]
    for oy in range(size):
        for ox in range(size):
            r = g = b = a = 0
            for sy in range(SS):
                for sx in range(SS):
                    pr, pg, pb, pa = px[ox * SS + sx][oy * SS + sy]
                    r += pr * pa
                    g += pg * pa
                    b += pb * pa
                    a += pa
            if a == 0:
                out[ox][oy] = (0, 0, 0, 0)
            else:
                out[ox][oy] = (round(r / a), round(g / a), round(b / a), round(a / (SS * SS)))
    return out


def write_png(path: Path, size: int, pix):
    raw = b""
    for y in range(size):
        raw += b"\x00" + b"".join(bytes(pix[x][y]) for x in range(size))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", ihdr)
                     + chunk(b"IDAT", zlib.compress(raw, 9))
                     + chunk(b"IEND", b""))


def main():
    OUT.mkdir(exist_ok=True)
    jobs = [
        ("icon-192.png", 192, False, 1.0),
        ("icon-512.png", 512, False, 1.0),
        ("icon-maskable-512.png", 512, True, 0.78),   # zona segura de máscara (~78% do conteúdo)
        ("apple-touch-icon.png", 180, True, 0.82),
    ]
    for name, size, bleed, scale in jobs:
        write_png(OUT / name, size, render(size, bleed, scale))
        print(f"pwa-icons/{name} ({size}×{size})")


if __name__ == "__main__":
    main()
