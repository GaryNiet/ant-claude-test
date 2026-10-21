"""Generates the game's pixel art: ground tiles (tiles/) and sprites (sprites/).

Style: low-detail pixel art in the colors of the inspiration images (art/inspiration/):
warm browns, moss greens, cream, ochre and slate blue, lit from the top left.

Run from the project folder:   python3 tools/make_art.py
Needs Python 3 with Pillow and numpy (pip install pillow numpy).
Every image is made from code (shapes and noise), so changing a color or a size here and
running it again rebuilds all the art. The random seed is fixed: same output every run.
"""
import os
import random

import numpy as np
from PIL import Image, ImageDraw

TILE = 32          # tile images are 32 x 32 px: one image pixel per map pixel
VARIANTS = 3       # plain tiles get this many variants (dirt.png, dirt_2.png, dirt_3.png)
SIDES = "nesw"     # transition sides, always written in this order

# --- Palette (from the inspiration images) -----------------------------------
DIRT = ["#4a3220", "#5c3f27", "#6b4a2f", "#7d5837", "#8f6a43"]
PEBBLE = ["#6f6a62", "#8f877a", "#b3a790", "#d8c9a6"]
GRASS = ["#2f431c", "#3c5423", "#4b6a2b", "#5e7f35", "#76984a"]
CLOVER = ["#5f8f3a", "#7fb04a", "#a0c865"]
FLOWER = ["#efe4c0", "#e3c75a"]
WATER = ["#1f2f40", "#263a4d", "#2e4659", "#38556b", "#7d9bb0"]
DAMP = "#3b2a1c"     # wet dirt at the water's edge
MOSS = ["#3d4a22", "#55662e", "#6c7f38"]
NEST = ["#6b4c2e", "#7f5c38", "#936d44", "#a98352", "#c29a63"]
ROCK = ["#2a2620", "#4b4a46", "#66655f", "#82817a", "#a3a199"]
ANT = ["#2c140a", "#6e3216", "#9a4a22", "#c06a32", "#e8995a"]
SPIDER = ["#141116", "#2b2630", "#3d3645", "#5a4f66", "#8a7a96", "#a33a2a"]
CRUMB = ["#7a5220", "#b07a2a", "#d9a441", "#f0cf7a"]

ROOT = os.path.join(os.path.dirname(__file__), "..")
rng = random.Random(7)
np_rng = np.random.default_rng(7)


def rgb(color):
    return tuple(int(color[i:i + 2], 16) for i in (1, 3, 5))


# --- Noise and tiles ----------------------------------------------------------

def tileable_noise(size, period, seed):
    """Smooth random values in 0..1 that wrap around (left edge matches right edge)."""
    grid = np.random.default_rng(seed).random((period, period))
    coords = np.arange(size) * period / size
    low = np.floor(coords).astype(int)
    high = (low + 1) % period
    t = coords - low
    t = t * t * (3 - 2 * t)  # smoothstep
    rows = grid[low][:, low] * (1 - t)[None, :] + grid[low][:, high] * t[None, :]
    rows_next = grid[high][:, low] * (1 - t)[None, :] + grid[high][:, high] * t[None, :]
    return rows * (1 - t)[:, None] + rows_next * t[:, None]


def layered_noise(seed):
    """Big blotches plus fine grain, 0..1, tileable."""
    return (tileable_noise(TILE, 4, seed) * 0.55 + tileable_noise(TILE, 8, seed + 1) * 0.3
            + tileable_noise(TILE, 16, seed + 2) * 0.15)


def shade(noise, colors):
    """Turns noise into pixels, picking a color from the dark-to-light list."""
    image = Image.new("RGB", (TILE, TILE))
    pixels = image.load()
    for y in range(TILE):
        for x in range(TILE):
            index = int(np.clip(noise[y, x], 0, 0.999) * len(colors))
            pixels[x, y] = rgb(colors[index])
    return image


def scatter(image, count, colors, size=1, seed=0):
    """Small dots (pebbles, grains) at random spots, wrapping around the edges."""
    local = random.Random(seed)
    pixels = image.load()
    for _ in range(count):
        x, y = local.randrange(TILE), local.randrange(TILE)
        color = rgb(local.choice(colors))
        for dy in range(size):
            for dx in range(size):
                pixels[(x + dx) % TILE, (y + dy) % TILE] = color
        if size > 1:  # a lighter top-left pixel and a darker shadow pixel
            pixels[x % TILE, y % TILE] = tuple(min(c + 40, 255) for c in color)
            pixels[(x + size) % TILE, (y + size) % TILE] = rgb(DIRT[0])
    return image


def dirt_tile(seed):
    image = shade(layered_noise(seed), DIRT[1:])
    scatter(image, 7, [DIRT[0], PEBBLE[0]], 1, seed)
    return scatter(image, 2, PEBBLE[1:3], 2, seed + 50)


def grass_tile(seed):
    image = shade(layered_noise(seed), GRASS[1:])
    local = random.Random(seed)
    pixels = image.load()
    for _ in range(40):  # blades: a light pixel above a dark one
        x, y = local.randrange(TILE), local.randrange(TILE)
        pixels[x, y] = rgb(GRASS[4])
        pixels[x, (y + 1) % TILE] = rgb(GRASS[0])
    if local.random() < 0.7:  # a clover
        x, y = local.randrange(TILE), local.randrange(TILE)
        for dx, dy in [(0, -2), (-2, 1), (2, 1)]:
            for ox in range(2):
                for oy in range(2):
                    pixels[(x + dx + ox) % TILE, (y + dy + oy) % TILE] = rgb(CLOVER[1 + (ox + oy) % 2])
    if local.random() < 0.35:  # a tiny flower
        x, y = local.randrange(TILE), local.randrange(TILE)
        for dx, dy in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
            pixels[(x + dx) % TILE, (y + dy) % TILE] = rgb(FLOWER[0])
        pixels[x, y] = rgb(FLOWER[1])
    return image


def water_tile(seed):
    image = shade(layered_noise(seed) * 0.8, WATER[:4])
    local = random.Random(seed)
    pixels = image.load()
    for _ in range(5):  # ripples: short light lines
        x, y = local.randrange(TILE), local.randrange(TILE)
        for dx in range(local.randint(2, 4)):
            pixels[(x + dx) % TILE, y] = rgb(WATER[4] if dx else WATER[3])
    return image


def obstacle_tile(seed):
    """The ground under a rock: dark soil and moss (the rock itself is a sprite)."""
    image = shade(layered_noise(seed) * 0.9, [DIRT[0], DIRT[1], MOSS[0], MOSS[1]])
    return scatter(image, 8, ROCK[1:3], 2, seed)


def nest_tile(seed):
    """Packed, sandy soil around the nest."""
    image = shade(layered_noise(seed), NEST[:4])
    scatter(image, 14, NEST[3:], 1, seed)
    return scatter(image, 4, PEBBLE[1:], 2, seed + 9)


def edge_mask(sides, seed, width):
    """1 where a transition band from the given sides reaches, with a ragged edge."""
    wobble = tileable_noise(TILE, 8, seed) * 4.0
    y, x = np.mgrid[0:TILE, 0:TILE]
    distance = {"n": y, "s": TILE - 1 - y, "w": x, "e": TILE - 1 - x}
    mask = np.zeros((TILE, TILE), bool)
    for side in sides:
        mask |= distance[side] < width + wobble
    return mask


def blend(base, top, mask):
    base_pixels, top_pixels = np.array(base), np.array(top)
    base_pixels[mask] = top_pixels[mask]
    return Image.fromarray(base_pixels)


def all_side_combinations():
    for bits in range(1, 16):
        yield "".join(side for index, side in enumerate(SIDES) if bits & (1 << index))


def save(image, *path):
    full = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    image.save(full)


def make_tiles():
    makers = {"dirt": dirt_tile, "grass": grass_tile, "water": water_tile,
              "obstacle": obstacle_tile, "nest": nest_tile}
    for type_name, maker in makers.items():
        for variant in range(VARIANTS):
            name = type_name if variant == 0 else "%s_%d" % (type_name, variant + 1)
            save(maker(100 * variant + len(type_name)), "tiles", name + ".png")

    damp = Image.new("RGB", (TILE, TILE), rgb(DAMP))
    shallow = shade(layered_noise(77) * 0.6 + 0.4, WATER[2:4])
    # (tile type, neighbour type): (what creeps in from those sides, band width)
    transitions = {
        ("dirt", "grass"): (grass_tile(31), 5),
        ("dirt", "water"): (damp, 3),
        ("grass", "water"): (damp, 3),
        ("water", "dirt"): (shallow, 3),
        ("water", "grass"): (shallow, 3),
        ("dirt", "nest"): (nest_tile(5), 4),
        ("grass", "nest"): (nest_tile(6), 4),
        ("grass", "dirt"): (dirt_tile(8), 2),
    }
    for (type_name, neighbour), (creeping, width) in transitions.items():
        base = makers[type_name](3)
        for sides in all_side_combinations():
            mask = edge_mask(sides, len(sides) + 17, width)
            save(blend(base, creeping, mask), "tiles", "%s_%s_%s.png" % (type_name, neighbour, sides))


# --- Sprites --------------------------------------------------------------------

def outline(image, color):
    """Adds a 1 px outline around everything that is fully opaque."""
    pixels = np.array(image)
    solid = pixels[:, :, 3] == 255
    padded = np.pad(solid, 1)
    around = padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
    edge = around & ~solid
    pixels[edge] = rgb(color) + (255,)
    return Image.fromarray(pixels)


def with_shadow(image, center, radius_x, radius_y):
    """Puts a soft dark ellipse on the ground under a sprite."""
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ellipse(ImageDraw.Draw(shadow), center, radius_x, radius_y, (0, 0, 0, 90))
    shadow.alpha_composite(image)
    return shadow


def ellipse(draw, center, radius_x, radius_y, color):
    x, y = center
    draw.ellipse([x - radius_x, y - radius_y, x + radius_x, y + radius_y], fill=color)


def shaded_blob(draw, center, radius_x, radius_y, colors):
    """A body part lit from the top left: dark base, mid color, a light highlight."""
    x, y = center
    ellipse(draw, (x, y), radius_x, radius_y, colors[0])
    ellipse(draw, (x - 0.5, y - 0.5), radius_x - 1, radius_y - 1, colors[1])
    ellipse(draw, (x - radius_x * 0.35, y - radius_y * 0.4), max(radius_x * 0.35, 0.6), max(radius_y * 0.3, 0.6), colors[2])


def ant_sprite():
    """Seen from above, facing right (the game turns it to face where the ant walks)."""
    size = 24
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    legs = rgb(ANT[0])
    for x_offset, spread in [(-2, -3), (0, 0), (2, 3)]:  # 3 pairs of legs from the thorax
        for side in (-1, 1):
            knee = (12 + x_offset + spread * 0.3, 12 + side * 4)
            draw.line([(12 + x_offset, 12), knee, (12 + x_offset + spread, 12 + side * 7)], fill=legs)
    draw.line([(18, 11), (21, 8), (22, 7)], fill=legs)   # antennae
    draw.line([(18, 13), (21, 16), (22, 17)], fill=legs)
    shaded_blob(draw, (6.5, 12), 4.5, 3.5, [rgb(ANT[1]), rgb(ANT[2]), rgb(ANT[4])])   # abdomen
    shaded_blob(draw, (12, 12), 2.5, 2, [rgb(ANT[1]), rgb(ANT[3]), rgb(ANT[4])])      # thorax
    shaded_blob(draw, (16.5, 12), 2.5, 2.5, [rgb(ANT[1]), rgb(ANT[2]), rgb(ANT[4])])  # head
    return outline(image, ANT[0])


def spider_sprite():
    """Seen from above, facing right: big round abdomen, 8 bent legs."""
    size = 40
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    legs = rgb(SPIDER[1])
    joints = rgb(SPIDER[3])
    for index, angle in enumerate([-60, -25, 15, 50]):  # 4 legs per side, from the front pair back
        for side in (-1, 1):
            start = (22 - index * 1.5, 20)
            knee = (start[0] + 6 - index * 4, 20 + side * (8 + index % 2))
            foot = (start[0] + 9 - index * 7, 20 + side * 17)
            draw.line([start, knee], fill=legs, width=2)
            draw.line([knee, foot], fill=legs, width=1)
            draw.point(knee, fill=joints)
    shaded_blob(draw, (12, 20), 8, 7, [rgb(SPIDER[1]), rgb(SPIDER[2]), rgb(SPIDER[4])])   # abdomen
    draw.line([(8, 20), (15, 20)], fill=rgb(SPIDER[5]))                                    # marking
    draw.line([(11, 18), (11, 22)], fill=rgb(SPIDER[5]))
    shaded_blob(draw, (23, 20), 4.5, 4, [rgb(SPIDER[1]), rgb(SPIDER[3]), rgb(SPIDER[4])])  # head
    for dy in (-1, 1):  # eyes and fangs
        draw.point((26, 20 + dy), fill=rgb(SPIDER[5]))
        draw.point((28, 20 + dy * 2), fill=rgb(SPIDER[0]))
    return outline(image, SPIDER[0])


def crumb_sprite():
    image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon([(1, 4), (3, 1), (6, 2), (7, 5), (4, 7)], fill=rgb(CRUMB[1]))
    draw.polygon([(2, 4), (3, 2), (5, 3), (4, 5)], fill=rgb(CRUMB[2]))
    draw.point((3, 2), fill=rgb(CRUMB[3]))
    return outline(image, CRUMB[0])


def rock_sprite(seed):
    """A boulder standing on an obstacle tile, seen from the side and a bit above."""
    local = random.Random(seed)
    width, height = 34, 30
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    bumps = [(17 + local.randint(-3, 3), 16, 13, 10), (10, 19, 8, 7), (24, 19, 8, 7)]
    for x, y, radius_x, radius_y in bumps:
        ellipse(draw, (x, y), radius_x, radius_y, rgb(ROCK[1]))
    for x, y, radius_x, radius_y in bumps:
        ellipse(draw, (x - 1, y - 1), radius_x - 2, radius_y - 2, rgb(ROCK[2]))
        ellipse(draw, (x - radius_x * 0.3, y - radius_y * 0.45), radius_x * 0.4, radius_y * 0.3, rgb(ROCK[3]))
    for _ in range(6):  # moss on top
        x, y = local.randint(8, 25), local.randint(7, 12)
        ellipse(draw, (x, y), local.randint(1, 3), 1, rgb(local.choice(MOSS[1:])))
    draw.point((12, 10), fill=rgb(ROCK[4]))
    return with_shadow(outline(image, ROCK[0]), (17, 26), 16, 3)


def nest_sprite(width, height, entrances, seed):
    """A mound of dirt with dark entrance holes. Bigger version = growing nest."""
    local = random.Random(seed)
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    middle = width / 2
    base = height - 6
    ellipse(draw, (middle, base - height * 0.25), width / 2 - 2, height * 0.45, rgb(NEST[1]))
    ellipse(draw, (middle - 2, base - height * 0.3), width / 2 - 6, height * 0.36, rgb(NEST[2]))
    ellipse(draw, (middle - width * 0.15, base - height * 0.45), width * 0.18, height * 0.14, rgb(NEST[3]))
    for _ in range(width):  # grains and pebbles
        x = local.uniform(4, width - 4)
        y = local.uniform(base - height * 0.6, base)
        if image.getpixel((int(x), int(y)))[3]:
            draw.point((x, y), fill=rgb(local.choice([NEST[0], NEST[4], PEBBLE[2]])))
    for index in range(entrances):
        x = middle + (index - (entrances - 1) / 2) * width * 0.28
        y = base - 4 - (index % 2) * 4
        ellipse(draw, (x, y), 4, 3.5, rgb(DIRT[0]))
        ellipse(draw, (x, y + 0.5), 3, 2.5, (20, 12, 6))
    return with_shadow(outline(image, DIRT[0]), (middle, base + 2), width / 2 - 1, 4)


def make_sprites():
    save(ant_sprite(), "sprites", "ant.png")
    save(spider_sprite(), "sprites", "spider.png")
    save(crumb_sprite(), "sprites", "food_crumb.png")
    for variant in range(3):
        save(rock_sprite(variant), "sprites", "rock_%d.png" % (variant + 1))
    save(nest_sprite(48, 30, 1, 1), "sprites", "nest_small.png")
    save(nest_sprite(80, 48, 3, 2), "sprites", "nest_big.png")


if __name__ == "__main__":
    make_tiles()
    make_sprites()
    print("Art written to tiles/ and sprites/")
