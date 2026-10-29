"""Generate the ink-wash artwork used by the Flutter client.

The app intentionally ships without third-party photography.  These backgrounds
are painted procedurally so the prototype is self-contained and can be
re-generated after visual tweaks:

    python tool/generate_assets.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "images"
ASSETS.mkdir(parents=True, exist_ok=True)

HERO_SIZE = (1200, 960)
PAPER_SIZE = (1200, 1800)
INK = (47, 74, 86)
MUTED_INK = (112, 137, 145)


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", (1, height))
    pixels = image.load()
    for y in range(height):
        t = y / max(1, height - 1)
        pixels[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return image.resize((width, height), Image.Resampling.BILINEAR)


def add_clouds(layer: Image.Image, seed: int = 3) -> None:
    rng = random.Random(seed)
    width, height = layer.size
    draw = ImageDraw.Draw(layer, "RGBA")
    for _ in range(16):
        cx = rng.randint(-80, width + 80)
        cy = rng.randint(int(height * 0.10), int(height * 0.56))
        rx = rng.randint(95, 240)
        ry = rng.randint(16, 40)
        alpha = rng.randint(24, 58)
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(255, 255, 255, alpha))


def soft_ridge(
    width: int,
    height: int,
    *,
    base: float,
    peaks: list[tuple[float, float, float]],
    seed: int,
) -> list[tuple[int, int]]:
    """A watercolour ridge made from overlapping Gaussian hills."""
    rng = random.Random(seed)
    wobble_a = rng.uniform(0.008, 0.016)
    wobble_b = rng.uniform(0.004, 0.009)
    phase_a = rng.uniform(0, math.tau)
    phase_b = rng.uniform(0, math.tau)
    points: list[tuple[int, int]] = [(-80, height)]
    step = 7
    for x in range(-80, width + 81, step):
        t = x / width
        y = base
        for center, amplitude, spread in peaks:
            y -= height * amplitude * math.exp(-(((t - center) / spread) ** 2))
        y += height * (wobble_a * math.sin(t * math.tau * 2.3 + phase_a))
        y += height * (wobble_b * math.sin(t * math.tau * 5.1 + phase_b))
        points.append((x, int(y)))
    points.append((width + 80, height))
    return points


def draw_ink_mountains(layer: Image.Image, *, opacity: int = 150, seed: int = 9) -> None:
    width, height = layer.size
    far = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    far_draw = ImageDraw.Draw(far, "RGBA")
    # Broad, misty massif behind the family name.
    far_points = soft_ridge(
        width,
        height,
        base=height * 0.78,
        peaks=[
            (0.08, 0.18, 0.14),
            (0.30, 0.30, 0.19),
            (0.48, 0.46, 0.14),
            (0.63, 0.23, 0.16),
            (0.81, 0.27, 0.13),
            (0.98, 0.16, 0.11),
        ],
        seed=seed,
    )
    far_draw.polygon(far_points, fill=(120, 149, 166, min(255, opacity)))
    far = far.filter(ImageFilter.GaussianBlur(7.0))
    layer.alpha_composite(far)

    middle = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    middle_draw = ImageDraw.Draw(middle, "RGBA")
    mid_points = soft_ridge(
        width,
        height,
        base=height * 0.88,
        peaks=[
            (0.02, 0.13, 0.16),
            (0.25, 0.20, 0.18),
            (0.44, 0.34, 0.13),
            (0.59, 0.16, 0.15),
            (0.74, 0.24, 0.11),
            (0.92, 0.16, 0.12),
        ],
        seed=seed + 11,
    )
    middle_draw.polygon(mid_points, fill=(69, 104, 119, int(opacity * 0.55)))
    middle = middle.filter(ImageFilter.GaussianBlur(3.0))
    layer.alpha_composite(middle)

    # A single quiet foreground hill anchors the composition.
    foreground = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    foreground_draw = ImageDraw.Draw(foreground, "RGBA")
    fg_points = soft_ridge(
        width,
        height,
        base=height * 0.98,
        peaks=[(0.12, 0.16, 0.24), (0.46, 0.10, 0.20), (0.78, 0.13, 0.23)],
        seed=seed + 23,
    )
    foreground_draw.polygon(fg_points, fill=(60, 94, 109, int(opacity * 0.28)))
    foreground = foreground.filter(ImageFilter.GaussianBlur(4))
    layer.alpha_composite(foreground)


def bezier(points: list[tuple[float, float]], steps: int = 80) -> list[tuple[float, float]]:
    """Sample a cubic Bezier with four control points."""
    p0, p1, p2, p3 = points
    result = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        result.append((x, y))
    return result


def draw_leaf(draw: ImageDraw.ImageDraw, x: float, y: float, length: float, angle: float, color: tuple[int, int, int, int]) -> None:
    points = []
    for t in [i / 14 for i in range(15)]:
        px = length * t
        py = math.sin(t * math.pi) * length * 0.28
        points.append((px, py))
    for t in [i / 14 for i in range(15)]:
        px = length * (1 - t)
        py = -math.sin(t * math.pi) * length * 0.28
        points.append((px, py))
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    rotated = [(x + px * cos_a - py * sin_a, y + px * sin_a + py * cos_a) for px, py in points]
    draw.polygon(rotated, fill=color)


def draw_branch_and_leaves(layer: Image.Image, seed: int = 7) -> None:
    rng = random.Random(seed)
    overlay = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    width, height = layer.size

    branch = bezier(
        [
            (width * 1.02, height * 0.10),
            (width * 0.83, height * 0.16),
            (width * 0.68, height * 0.22),
            (width * 0.55, height * 0.35),
        ]
    )
    for offset, alpha in [(12, 42), (7, 95), (3, 170)]:
        draw.line(branch, fill=(66, 72, 63, alpha), width=offset, joint="curve")

    twigs = [
        ((width * 0.84, height * 0.15), (width * 0.73, height * 0.08), (width * 0.69, height * 0.035)),
        ((width * 0.76, height * 0.20), (width * 0.64, height * 0.13), (width * 0.58, height * 0.065)),
        ((width * 0.69, height * 0.26), (width * 0.61, height * 0.22), (width * 0.53, height * 0.22)),
        ((width * 0.62, height * 0.30), (width * 0.52, height * 0.27), (width * 0.47, height * 0.30)),
    ]
    for start, control, end in twigs:
        pts = bezier([start, control, control, end])
        draw.line(pts, fill=(68, 74, 64, 145), width=4, joint="curve")

    leaf_colors = [
        (109, 143, 115, 162),
        (134, 160, 127, 142),
        (88, 127, 105, 156),
        (154, 178, 141, 116),
        (74, 113, 93, 150),
    ]
    centers = [
        (0.77, 0.13, 50),
        (0.70, 0.10, 55),
        (0.64, 0.17, 58),
        (0.58, 0.23, 46),
        (0.52, 0.29, 38),
        (0.82, 0.22, 44),
        (0.90, 0.14, 38),
    ]
    for cx_ratio, cy_ratio, count in centers:
        cx, cy = width * cx_ratio, height * cy_ratio
        for _ in range(count):
            angle = rng.uniform(0, math.tau)
            radius = rng.uniform(0, 72)
            x = cx + math.cos(angle) * radius
            y = cy + math.sin(angle) * radius * 0.55
            draw_leaf(draw, x, y, rng.uniform(15, 27), angle, rng.choice(leaf_colors))

    overlay = overlay.filter(ImageFilter.GaussianBlur(0.7))
    layer.alpha_composite(overlay)


def draw_traditional_roof(layer: Image.Image) -> None:
    width, height = layer.size
    overlay = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    # Main roof: a sweeping tiled silhouette with upturned eaves.
    # Roof ridge: a long, quiet sweep rather than a hard "factory" silhouette.
    roof = [
        (width * 0.72, height * 0.505),
        (width * 0.75, height * 0.455),
        (width * 0.82, height * 0.415),
        (width * 0.91, height * 0.405),
        (width * 1.02, height * 0.390),
        (width * 1.02, height * 0.465),
        (width * 0.94, height * 0.555),
        (width * 0.755, height * 0.555),
        (width * 0.72, height * 0.525),
    ]
    draw.polygon(roof, fill=(92, 114, 118, 96))
    ridge = bezier(
        [
            (width * 0.705, height * 0.505),
            (width * 0.77, height * 0.43),
            (width * 0.90, height * 0.402),
            (width * 1.02, height * 0.390),
        ]
    )
    draw.line(ridge, fill=(56, 80, 85, 150), width=6, joint="curve")
    # Upturned eave at the left.
    eave = bezier(
        [
            (width * 0.72, height * 0.51),
            (width * 0.69, height * 0.535),
            (width * 0.66, height * 0.555),
            (width * 0.635, height * 0.535),
        ]
    )
    draw.line(eave, fill=(67, 91, 96, 138), width=5, joint="curve")
    for x in range(int(width * 0.76), int(width * 0.99), 17):
        draw.line([(x, height * 0.425), (x + 7, height * 0.545)], fill=(230, 236, 232, 25), width=2)

    # Plaster wall, a timber window and a low stone plinth.
    draw.polygon(
        [
            (width * 0.75, height * 0.555),
            (width * 0.98, height * 0.545),
            (width * 1.02, height * 0.705),
            (width * 0.73, height * 0.705),
        ],
        fill=(247, 248, 242, 158),
    )
    draw.rectangle(
        (width * 0.835, height * 0.585, width * 0.915, height * 0.645),
        fill=(77, 94, 95, 72),
    )
    for x in [width * 0.856, width * 0.876, width * 0.896]:
        draw.line([(x, height * 0.588), (x, height * 0.642)], fill=(230, 235, 228, 44), width=2)
    draw.line([(width * 0.80, height * 0.655), (width * 0.95, height * 0.65)], fill=(74, 87, 82, 45), width=3)
    overlay = overlay.filter(ImageFilter.GaussianBlur(0.9))
    layer.alpha_composite(overlay)


def add_paper_grain(layer: Image.Image, strength: int = 10, seed: int = 23) -> None:
    rng = random.Random(seed)
    width, height = layer.size
    noise = Image.new("L", (width // 3, height // 3))
    noise.putdata([rng.randint(0, 255) for _ in range((width // 3) * (height // 3))])
    noise = noise.resize(layer.size, Image.Resampling.BILINEAR)
    tint = Image.new("RGBA", layer.size, (255, 255, 255, strength))
    alpha = noise.point(lambda value: int(abs(value - 127) / 127 * strength))
    tint.putalpha(alpha)
    layer.alpha_composite(tint)


def build_hero() -> None:
    base = vertical_gradient(HERO_SIZE, (225, 242, 252), (248, 251, 251)).convert("RGBA")
    clouds = Image.new("RGBA", HERO_SIZE, (0, 0, 0, 0))
    add_clouds(clouds)
    clouds = clouds.filter(ImageFilter.GaussianBlur(18))
    base.alpha_composite(clouds)
    draw_ink_mountains(base, opacity=145, seed=13)
    draw_traditional_roof(base)
    draw_branch_and_leaves(base)

    # Warm highlight around the title area.
    glow = Image.new("RGBA", HERO_SIZE, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow, "RGBA")
    glow_draw.ellipse((-200, 80, 1000, 700), fill=(255, 252, 240, 36))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    base.alpha_composite(glow)

    # Fade into the app canvas so the summary card feels native to the page.
    fade = Image.new("RGBA", HERO_SIZE, (0, 0, 0, 0))
    fade_draw = ImageDraw.Draw(fade, "RGBA")
    fade_top = int(HERO_SIZE[1] * 0.66)
    for y in range(fade_top, HERO_SIZE[1]):
        t = (y - fade_top) / (HERO_SIZE[1] - fade_top)
        fade_draw.line(
            [(0, y), (HERO_SIZE[0], y)],
            fill=(244, 247, 249, int(255 * (t**1.35))),
        )
    base.alpha_composite(fade)
    add_paper_grain(base, strength=6, seed=5)
    base.convert("RGB").save(ASSETS / "hero_ink.jpg", quality=91, optimize=True)


def build_tree_paper() -> None:
    base = vertical_gradient(PAPER_SIZE, (245, 247, 245), (250, 248, 242)).convert("RGBA")
    far = Image.new("RGBA", PAPER_SIZE, (0, 0, 0, 0))
    far_draw = ImageDraw.Draw(far, "RGBA")
    # Very pale mountain shapes, kept quiet enough for text and cards.
    points = soft_ridge(
        PAPER_SIZE[0],
        PAPER_SIZE[1],
        base=PAPER_SIZE[1] * 0.30,
        peaks=[
            (0.00, 0.10, 0.15),
            (0.16, 0.16, 0.16),
            (0.35, 0.23, 0.15),
            (0.50, 0.32, 0.12),
            (0.68, 0.19, 0.14),
            (0.84, 0.23, 0.13),
        ],
        seed=31,
    )
    far_draw.polygon(points, fill=(128, 151, 157, 26))
    far = far.filter(ImageFilter.GaussianBlur(12))
    base.alpha_composite(far)
    draw_branch_and_leaves(base)

    # Faint horizontal mist bands.
    mist = Image.new("RGBA", PAPER_SIZE, (0, 0, 0, 0))
    mist_draw = ImageDraw.Draw(mist, "RGBA")
    for y_ratio, alpha in [(0.10, 65), (0.22, 42), (0.38, 36), (0.57, 30)]:
        y = int(PAPER_SIZE[1] * y_ratio)
        mist_draw.rectangle((0, y, PAPER_SIZE[0], y + 75), fill=(255, 255, 252, alpha))
    mist = mist.filter(ImageFilter.GaussianBlur(24))
    base.alpha_composite(mist)
    add_paper_grain(base, strength=8, seed=27)
    base.convert("RGB").save(ASSETS / "tree_paper.jpg", quality=90, optimize=True)


def build_app_icon() -> None:
    size = 1024
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon, "RGBA")
    # A modern seal: warm paper, cinnabar stamp, simplified family tree.
    draw.rounded_rectangle((0, 0, size, size), radius=220, fill=(246, 244, 236, 255))
    draw.rounded_rectangle((110, 110, 914, 914), radius=168, fill=(177, 55, 48, 255))
    branch = (255, 244, 225, 238)
    draw.line((512, 700, 512, 420), fill=branch, width=48)
    draw.line((512, 540, 340, 400), fill=branch, width=38)
    draw.line((512, 540, 684, 400), fill=branch, width=38)
    for cx, cy, r in [(512, 334, 74), (320, 330, 63), (704, 330, 63)]:
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=branch)
    draw.line((512, 714, 512, 800), fill=branch, width=38)
    icon.save(ASSETS.parent / "app_icon.png")
    icon.resize((512, 512), Image.Resampling.LANCZOS).save(ASSETS.parent / "app_icon_512.png")


if __name__ == "__main__":
    build_hero()
    build_tree_paper()
    build_app_icon()
    print("Generated:", *(path.name for path in sorted(ASSETS.glob("*"))))
