"""Build Flush Rush sprites, tileset, and audio from generated art + pixel drawing."""
from __future__ import annotations

import math
import os
import random
import shutil
import struct
import wave
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

SRC = Path(r"C:\Users\Michael\.cursor\projects\c-Users-Michael-Desktop-Flush-Rush\assets")
ROOT = Path(r"C:\Users\Michael\Desktop\Flush_Rush")
SPR = ROOT / "assets" / "sprites"
UI = ROOT / "assets" / "ui"
AUD = ROOT / "assets" / "audio"


def _edge_key_color(im: Image.Image) -> tuple[int, int, int]:
    pix = im.load()
    w, h = im.size
    samples: list[tuple[int, int, int]] = []
    for x in range(0, w, max(1, w // 24)):
        samples.append(pix[x, 0][:3])
        samples.append(pix[x, h - 1][:3])
    for y in range(0, h, max(1, h // 24)):
        samples.append(pix[0, y][:3])
        samples.append(pix[w - 1, y][:3])
    rs = sorted(c[0] for c in samples)
    gs = sorted(c[1] for c in samples)
    bs = sorted(c[2] for c in samples)
    mid = len(samples) // 2
    return rs[mid], gs[mid], bs[mid]


def flood_chroma(im: Image.Image, thresh: float = 78.0) -> Image.Image:
    im = im.convert("RGBA")
    pix = im.load()
    w, h = im.size
    kr, kg, kb = _edge_key_color(im)

    def is_key(x: int, y: int) -> bool:
        r, g, b, a = pix[x, y]
        if a == 0:
            return True
        dist = math.sqrt((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2)
        if dist < thresh:
            return True
        # Hot pink / magenta family leftover from generators.
        if r > 200 and g < 90 and b > 140:
            return True
        if r > 188 and b > 188 and g < 105:
            return True
        return False

    seen = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if not is_key(x, y):
            continue
        pix[x, y] = (0, 0, 0, 0)
        q.append((x + 1, y))
        q.append((x - 1, y))
        q.append((x, y + 1))
        q.append((x, y - 1))

    # Defringe magenta halos
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            if a == 0:
                continue
            dist = math.sqrt((r - 255) ** 2 + g * g + (b - 255) ** 2)
            edge = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and pix[nx, ny][3] == 0:
                    edge = True
                    break
            if edge and dist < 140:
                fade = max(0.0, min(1.0, (dist - 40) / 100.0))
                pix[x, y] = (r, g, b, int(a * fade))
    return im


def autocrop(im: Image.Image, pad: int = 6) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(im.width, r + pad)
    b = min(im.height, b + pad)
    return im.crop((l, t, r, b))


def fit_height(im: Image.Image, height: int) -> Image.Image:
    if im.height == 0:
        return im
    scale = height / im.height
    w = max(1, int(im.width * scale))
    return im.resize((w, height), Image.Resampling.LANCZOS)


def process_sprite(name: str, dest: str, height: int, thresh: float = 110.0) -> Path:
    src = SRC / name
    im = flood_chroma(Image.open(src), thresh=thresh)
    im = autocrop(im, pad=8)
    im = fit_height(im, height)
    if im.width < height * 0.55:
        im = fit_height(im, int(height * 1.15))
    out = SPR / dest
    im.save(out)
    print(f"sprite {dest}: {im.size}")
    return out


def copy_ui(name: str, dest: str, size: tuple[int, int] | None = None) -> None:
    im = Image.open(SRC / name).convert("RGB")
    if size:
        im = im.resize(size, Image.Resampling.LANCZOS)
    im.save(UI / dest, quality=92)
    print(f"ui {dest}: {im.size}")


def make_bob_frames(src_path: Path, dest_name: str, height: int, n: int = 4) -> None:
    base = Image.open(src_path).convert("RGBA")
    base = fit_height(base, height)
    cell_w, cell_h = base.width + 8, height + 10
    sheet = Image.new("RGBA", (cell_w * n, cell_h), (0, 0, 0, 0))
    for i in range(n):
        frame = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        bob = int(round(math.sin(i / n * math.pi * 2) * 3))
        squash = 1.0 - abs(math.sin(i / n * math.pi * 2)) * 0.04
        fw, fh = base.width, int(base.height * squash)
        scaled = base.resize((fw, max(1, fh)), Image.Resampling.LANCZOS)
        x = (cell_w - fw) // 2
        y = cell_h - fh - 4 + bob
        frame.alpha_composite(scaled, (x, max(0, y)))
        sheet.paste(frame, (i * cell_w, 0))
    out = SPR / dest_name
    sheet.save(out)
    print(f"sheet {dest_name}: {sheet.size} cells={n}x1 {cell_w}x{cell_h}")


def pset(draw: ImageDraw.ImageDraw, x: int, y: int, c: tuple, s: int = 1) -> None:
    draw.rectangle([x, y, x + s - 1, y + s - 1], fill=c)


def brick_tile(size: int, grout: tuple, brick: tuple, highlight: tuple, shadow: tuple, seed: int) -> Image.Image:
    rng = random.Random(seed)
    im = Image.new("RGBA", (size, size), grout)
    d = ImageDraw.Draw(im)
    bh = size // 4
    for row in range(4):
        offset = 0 if row % 2 == 0 else size // 2
        y = row * bh
        x = -offset
        while x < size:
            w = size // 2
            jitter = rng.randint(-6, 8)
            col = tuple(max(0, min(255, brick[i] + jitter)) for i in range(3))
            d.rectangle([x + 1, y + 1, x + w - 2, y + bh - 2], fill=col)
            d.line([(x + 1, y + 1), (x + w - 2, y + 1)], fill=highlight)
            d.line([(x + 1, y + 1), (x + 1, y + bh - 2)], fill=highlight)
            d.line([(x + 1, y + bh - 2), (x + w - 2, y + bh - 2)], fill=shadow)
            x += w
    return im


def pipe_h(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rust = (176, 96, 58)
    dark = (92, 46, 28)
    shine = (232, 176, 112)
    d.rectangle([0, 6, size - 1, size - 7], fill=rust)
    d.rectangle([0, 8, size - 1, 12], fill=shine)
    d.rectangle([0, size - 12, size - 1, size - 8], fill=dark)
    for x in range(4, size, 10):
        d.ellipse([x, 10, x + 3, 13], fill=(120, 160, 70, 180))
    d.rectangle([0, 6, size - 1, 7], fill=dark)
    d.rectangle([0, size - 8, size - 1, size - 7], fill=dark)
    return im


def pipe_v(size: int) -> Image.Image:
    return pipe_h(size).transpose(Image.Transpose.ROTATE_90)


def metal_platform(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, size - 1, 14], fill=(86, 98, 118))
    d.rectangle([0, 0, size - 1, 3], fill=(188, 204, 222))
    d.rectangle([0, 12, size - 1, 14], fill=(42, 48, 62))
    for x in range(3, size, 8):
        d.line([(x, 4), (x, 11)], fill=(58, 66, 82))
    d.rectangle([0, 15, size - 1, 18], fill=(30, 24, 40, 90))
    return im


def moss_brick(size: int) -> Image.Image:
    im = brick_tile(size, (28, 22, 36), (72, 86, 64), (120, 150, 90), (30, 36, 28), 11)
    d = ImageDraw.Draw(im)
    d.ellipse([6, 18, 18, 28], fill=(86, 200, 90, 180))
    d.ellipse([16, 20, 28, 30], fill=(50, 160, 70, 160))
    return im


def bg_brick(size: int) -> Image.Image:
    return brick_tile(size, (18, 12, 28), (42, 32, 58), (62, 48, 78), (22, 16, 32), 3)


def grate(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (40, 44, 52, 255))
    d = ImageDraw.Draw(im)
    for i in range(4, size, 6):
        d.line([(i, 2), (i, size - 3)], fill=(18, 20, 26), width=2)
        d.line([(2, i), (size - 3, i)], fill=(90, 98, 112))
    return im


def mushroom(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([14, 18, 18, 30], fill=(210, 200, 180))
    d.ellipse([6, 6, 26, 22], fill=(186, 78, 220))
    d.ellipse([10, 9, 14, 13], fill=(255, 180, 255))
    d.ellipse([18, 11, 22, 15], fill=(255, 180, 255))
    d.ellipse([12, 4, 20, 8], fill=(230, 140, 255))
    return im


def ladder(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([6, 0, 9, size - 1], fill=(196, 132, 64))
    d.rectangle([22, 0, 25, size - 1], fill=(196, 132, 64))
    for y in range(4, size, 8):
        d.rectangle([6, y, 25, y + 2], fill=(230, 176, 96))
    return im


def slime_drip(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([4, 14, 28, 30], fill=(110, 220, 70))
    d.ellipse([12, 4, 20, 18], fill=(150, 255, 90))
    d.ellipse([8, 18, 14, 24], fill=(200, 255, 140))
    return im


def water_tile(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (32, 110, 118, 110))
    d = ImageDraw.Draw(im)
    d.arc([0, 4, 20, 16], 0, 180, fill=(140, 230, 210, 140), width=2)
    d.arc([12, 12, 32, 24], 0, 180, fill=(90, 200, 190, 100), width=2)
    return im


def manhole(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 30, 30], fill=(58, 62, 70))
    d.ellipse([6, 6, 26, 26], fill=(28, 30, 36))
    d.rectangle([8, 14, 24, 18], fill=(90, 96, 108))
    return im


def glow_moss(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([4, 16, 28, 30], fill=(60, 200, 120, 200))
    d.ellipse([10, 18, 18, 26], fill=(180, 255, 160, 180))
    return im


def pipe_cap(size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 30, 30], fill=(140, 78, 48))
    d.ellipse([8, 8, 24, 24], fill=(28, 22, 32))
    d.ellipse([11, 11, 16, 16], fill=(40, 80, 90))
    return im


def make_tileset() -> None:
    s = 32
    cols, rows = 8, 4
    sheet = Image.new("RGBA", (cols * s, rows * s), (0, 0, 0, 0))
    tiles = [
        brick_tile(s, (36, 24, 44), (92, 70, 108), (130, 100, 148), (48, 32, 58), 1),
        brick_tile(s, (36, 24, 44), (110, 78, 70), (160, 110, 90), (60, 40, 40), 7),
        pipe_h(s),
        pipe_v(s),
        metal_platform(s),
        moss_brick(s),
        bg_brick(s),
        grate(s),
        mushroom(s),
        ladder(s),
        slime_drip(s),
        water_tile(s),
        manhole(s),
        glow_moss(s),
        pipe_cap(s),
        brick_tile(s, (20, 16, 28), (58, 48, 72), (80, 64, 96), (30, 24, 40), 21),
    ]
    for i, tile in enumerate(tiles):
        x = (i % cols) * s
        y = (i // cols) * s
        sheet.paste(tile, (x, y))
    path = SPR / "tileset.png"
    sheet.save(path)
    print(f"tileset {sheet.size}")


def make_background() -> None:
    s = 96
    im = Image.new("RGB", (s * 3, s * 2), (16, 10, 26))
    d = ImageDraw.Draw(im)
    for y in range(0, im.height, 12):
        for x in range(0, im.width, 24):
            ox = 12 if (y // 12) % 2 else 0
            col = (28 + (x + y) % 18, 18 + (x // 8) % 10, 42 + (y // 6) % 16)
            d.rectangle([x + ox, y, x + ox + 22, y + 10], fill=col)
    # faint slime glow
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([40, 20, 120, 80], fill=(40, 180, 90, 28))
    od.ellipse([160, 50, 250, 110], fill=(140, 60, 200, 22))
    im = Image.alpha_composite(im.convert("RGBA"), overlay).convert("RGB")
    im.save(SPR / "bg_sewer.png")
    print("bg_sewer", im.size)


def make_hud_carrot() -> None:
    # backup tiny pixel carrot if needed
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(12, 22), (6, 8), (18, 8)], fill=(232, 118, 42))
    d.polygon([(12, 20), (9, 10), (15, 10)], fill=(255, 168, 70))
    d.rectangle([11, 2, 13, 8], fill=(56, 160, 64))
    d.polygon([(12, 2), (7, 8), (12, 6)], fill=(86, 196, 80))
    d.polygon([(12, 2), (17, 8), (12, 6)], fill=(46, 140, 56))
    im.save(SPR / "hud_carrot_pixel.png")


def clamp16(v: float) -> int:
    return max(-32767, min(32767, int(v)))


def write_wav(path: Path, samples: list[float], sr: int = 22050) -> None:
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = b"".join(struct.pack("<h", clamp16(s * 32767)) for s in samples)
        w.writeframes(frames)


def env(i: int, n: int, a: float = 0.01, r: float = 0.2) -> float:
    t = i / max(1, n - 1)
    if t < a:
        return t / a
    if t > 1 - r:
        return max(0.0, (1 - t) / r)
    return 1.0


def tone(freq: float, dur: float, vol: float = 0.3, kind: str = "square", sr: int = 22050) -> list[float]:
    n = int(sr * dur)
    out = []
    for i in range(n):
        t = i / sr
        ph = t * freq
        if kind == "square":
            v = 0.45 if math.sin(2 * math.pi * ph) >= 0 else -0.45
        elif kind == "tri":
            v = 2 * abs(2 * (ph % 1.0) - 1) - 1
        elif kind == "noise":
            v = random.uniform(-1, 1)
        else:
            v = math.sin(2 * math.pi * ph)
        out.append(v * vol * env(i, n))
    return out


def mix_at(base: list[float], add: list[float], at: int) -> None:
    if len(base) < at + len(add):
        base.extend([0.0] * (at + len(add) - len(base)))
    for i, v in enumerate(add):
        base[at + i] += v


def make_audio() -> None:
    random.seed(7)
    sr = 22050
    write_wav(AUD / "jump.wav", tone(420, 0.08, 0.22, "square") + tone(620, 0.10, 0.18, "square"))
    splash = []
    mix_at(splash, tone(180, 0.18, 0.2, "sine"), 0)
    mix_at(splash, [random.uniform(-0.25, 0.25) * env(i, int(0.2 * sr), 0.01, 0.6) for i in range(int(0.2 * sr))], 0)
    mix_at(splash, tone(520, 0.12, 0.08, "sine"), int(0.04 * sr))
    write_wav(AUD / "splash.wav", splash)
    collect = []
    for i, f in enumerate((523, 659, 784, 1046)):
        mix_at(collect, tone(f, 0.09, 0.2, "tri"), int(i * 0.06 * sr))
    write_wav(AUD / "collect.wav", collect)
    hurt = tone(180, 0.16, 0.25, "square") + tone(90, 0.18, 0.2, "square")
    write_wav(AUD / "hurt.wav", hurt)
    box = tone(300, 0.06, 0.18, "noise") + tone(700, 0.08, 0.16, "square")
    write_wav(AUD / "box.wav", box)
    write_wav(AUD / "drip.wav", tone(980, 0.05, 0.08, "sine") + tone(640, 0.08, 0.05, "sine"))
    hit = tone(140, 0.1, 0.28, "square") + tone(90, 0.16, 0.22, "square")
    write_wav(AUD / "hit_boss.wav", hit)
    win = []
    for i, f in enumerate((523, 659, 784, 1046, 784, 1318)):
        mix_at(win, tone(f, 0.16, 0.18, "tri"), int(i * 0.12 * sr))
    write_wav(AUD / "victory.wav", win)

    # Sewer BGM loop ~ 8s, gentle minor melody
    bgm: list[float] = [0.0] * int(sr * 8.0)
    melody = [
        (0.0, 220, 0.45),
        (0.45, 261, 0.45),
        (0.90, 329, 0.45),
        (1.35, 261, 0.45),
        (1.80, 196, 0.6),
        (2.40, 220, 0.45),
        (2.85, 246, 0.45),
        (3.30, 261, 0.7),
        (4.00, 329, 0.45),
        (4.45, 293, 0.45),
        (4.90, 261, 0.45),
        (5.35, 220, 0.45),
        (5.80, 196, 0.9),
        (6.70, 174, 1.2),
    ]
    bass = [110, 110, 87, 98, 110, 82, 87, 110]
    for t, f, d in melody:
        mix_at(bgm, tone(f, d, 0.09, "tri"), int(t * sr))
        mix_at(bgm, tone(f * 2, d * 0.5, 0.03, "sine"), int(t * sr))
    for i, f in enumerate(bass):
        mix_at(bgm, tone(f, 0.9, 0.07, "sine"), int(i * 1.0 * sr))
    # drip accents
    for t in (1.1, 3.4, 5.6, 7.2):
        mix_at(bgm, tone(1200, 0.04, 0.03, "sine"), int(t * sr))
    # fade loop edges
    fade = int(0.04 * sr)
    for i in range(fade):
        bgm[i] *= i / fade
        bgm[-1 - i] *= i / fade
    write_wav(AUD / "bgm_sewer.wav", bgm)

    party: list[float] = [0.0] * int(sr * 6)
    notes = [523, 659, 784, 659, 880, 784, 1046, 880]
    for i, f in enumerate(notes * 2):
        mix_at(party, tone(f, 0.18, 0.12, "tri"), int(i * 0.28 * sr))
        mix_at(party, tone(f / 2, 0.18, 0.05, "sine"), int(i * 0.28 * sr))
    write_wav(AUD / "bgm_victory.wav", party)
    print("audio written")


def make_icon() -> None:
    im = Image.open(SRC / "game_icon.png").convert("RGBA")
    im = im.resize((256, 256), Image.Resampling.LANCZOS)
    im.save(SPR / "icon.png")
    # Tiny SVG-like fallback isn't needed; Godot accepts png.


def main() -> None:
    for p in (SPR, UI, AUD):
        p.mkdir(parents=True, exist_ok=True)

    process_sprite("strawberry_sprite.png", "strawberry.png", 56)
    process_sprite("strawberry_swim.png", "strawberry_swim.png", 56)
    process_sprite("strawberry_jump.png", "strawberry_jump.png", 58)
    process_sprite("gator_sprite.png", "gator.png", 84)
    process_sprite("eel_sprite.png", "eel.png", 36)
    process_sprite("bat_sprite.png", "bat.png", 40)
    process_sprite("slime_sprite.png", "slime.png", 32)
    process_sprite("box_sprite.png", "mystery_box.png", 36)
    process_sprite("carrot_item.png", "carrot.png", 28)
    process_sprite("speed_item.png", "power_speed.png", 28)
    process_sprite("star_item.png", "power_star.png", 28)
    process_sprite("ghost_item.png", "power_ghost.png", 28)

    make_bob_frames(SPR / "strawberry.png", "strawberry_idle.png", 56, 4)
    make_bob_frames(SPR / "strawberry_swim.png", "strawberry_swim_sheet.png", 56, 4)

    copy_ui("intro_butterfly.png", "intro_1.png", (1280, 720))
    copy_ui("intro_flush.png", "intro_2.png", (1280, 720))
    copy_ui("intro_sewer.png", "intro_3.png", (1280, 720))
    copy_ui("ending_family.png", "ending.png", (1280, 720))
    copy_ui("strawberry_portrait.png", "portrait.png", (720, 720))
    copy_ui("gator_boss.png", "gator_portrait.png", (1280, 720))
    copy_ui("game_icon.png", "title_icon.png", (512, 512))

    make_tileset()
    make_background()
    make_hud_carrot()
    make_icon()
    make_audio()
    print("done")


if __name__ == "__main__":
    main()
