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
BLUEBERRY = ["#1b1d3a", "#2c3263", "#3f4a8a", "#6f7fbf", "#b9c3e8"]
STRAWBERRY = ["#4a0e12", "#8a1c22", "#c0322f", "#e0584a", "#f2c26a"]
LARVA = ["#7a6a4a", "#c9b98e", "#e8dcb5", "#f6efd8"]
BARK = ["#2a1c12", "#3e2a1a", "#553a24", "#6e4c30", "#8a6442"]
LEAF = ["#5a2410", "#8a3a16", "#b8581e", "#d9822e", "#efb45a"]
PINE = ["#2e1a0e", "#4e2e18", "#6e4426", "#8e5e36"]
MUSHROOM = ["#5a3a22", "#8a5a34", "#b07a48", "#e8d8b0", "#f6efd8"]

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


def moss_tile(seed):
    """Soft moss patches on dirt (decoration only)."""
    image = shade(layered_noise(seed), MOSS + [GRASS[3]])
    return scatter(image, 10, [CLOVER[0], MOSS[0]], 1, seed)


def nest_tile(seed):
    """Packed, sandy soil around the nest."""
    image = shade(layered_noise(seed), NEST[:4])
    scatter(image, 14, NEST[3:], 1, seed)
    return scatter(image, 4, PEBBLE[1:], 2, seed + 9)


def path_tile(seed):
    """Unobstructed ground worn by ants: smoother and lighter, almost no gravel or moss."""
    image = shade(layered_noise(seed) * 0.7 + 0.15, NEST[2:5])
    return scatter(image, 3, [NEST[1]], 1, seed)


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
    makers = {"dirt": dirt_tile, "grass": grass_tile, "water": water_tile, "nest": nest_tile}
    for type_name, maker in makers.items():
        for variant in range(VARIANTS):
            name = type_name if variant == 0 else "%s_%d" % (type_name, variant + 1)
            save(maker(100 * variant + len(type_name)), "tiles", name + ".png")
    # Laid over any ground where ants have worn a path (see [paths] in game_settings.cfg).
    save(path_tile(11), "tiles", "path.png")
    # Laid over parts of the dirt as decoration (see [moss] in game_settings.cfg).
    save(moss_tile(12), "tiles", "moss.png")

    damp = Image.new("RGB", (TILE, TILE), rgb(DAMP))
    shallow = shade(layered_noise(77) * 0.6 + 0.4, WATER[2:4])
    # (tile type, neighbour type): (what creeps in from those sides, band width)
    transitions = {
        ("dirt", "grass"): (grass_tile(3), 4),  # same grass as the neighbouring tile: no visible seam
        ("dirt", "water"): (damp, 3),
        ("grass", "water"): (damp, 3),
        ("water", "dirt"): (shallow, 3),
        ("water", "grass"): (shallow, 3),
        ("dirt", "nest"): (nest_tile(5), 4),
        ("grass", "nest"): (nest_tile(6), 4),
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


# Creatures stand upright, parallel to the screen, seen from the side and a bit above (like
# classic isometric games). 4 directions: "se" = walking towards the screen and to the right,
# "ne" = away from the screen and to the right, "sw" / "nw" = the same, mirrored.
# 2 walking frames each (legs alternate). Their feet touch the ground GROUND_MARGIN px above
# the bottom of the image (the game puts that line on the creature's position).
GROUND_MARGIN = 3
WALK_FRAMES = 2


def leg(draw, hip, knee, foot, color, width=1):
    draw.line([hip, knee], fill=color, width=width)
    draw.line([knee, foot], fill=color, width=1)


def gait(frame, leg_number, side):
    """Tripod walk: legs 0 and 2 of one side move with leg 1 of the other side."""
    forward = (leg_number + side) % 2 == frame
    return 1.5 if forward else -1.5


def creature(size, body_parts, legs_far, legs_near, extras, shadow):
    """Draws far legs, the body parts (back to front), near legs and extras, then outlines.
    body_parts: list of (center, radius_x, radius_y, colors). Legs: list of (hip, knee, foot, width).
    extras: function(draw) for eyes, antennae, markings."""
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for hip, knee, foot, width in legs_far:
        leg(draw, hip, knee, foot, rgb(ANT[0]) if size[0] < 40 else rgb(SPIDER[0]), width)
    for center, radius_x, radius_y, colors in body_parts:
        shaded_blob(draw, center, radius_x, radius_y, colors)
    for hip, knee, foot, width in legs_near:
        leg(draw, hip, knee, foot, rgb(ANT[1]) if size[0] < 40 else rgb(SPIDER[2]), width)
    extras(draw)
    outlined = outline(image, ANT[0] if size[0] < 40 else SPIDER[0])
    return with_shadow(outlined, *shadow)


def ant_sprite(towards_screen, frame):
    """An ant walking to the right, towards the screen (head low and in front) or away from it."""
    width, height = 28, 22
    ground = height - GROUND_MARGIN
    dark, mid, light, bright = rgb(ANT[1]), rgb(ANT[2]), rgb(ANT[3]), rgb(ANT[4])
    if towards_screen:
        abdomen, thorax, head = (7, 10), (13.5, 11), (19, 12)
        parts = [(abdomen, 4.3, 3.4, [dark, mid, bright]), (thorax, 2.4, 1.6, [dark, light, bright]),
                 (head, 2.6, 2.4, [dark, mid, bright])]
    else:
        abdomen, thorax, head = (8, 12), (14, 10), (19, 8.5)
        parts = [(head, 2.4, 2.2, [dark, mid, bright]), (thorax, 2.4, 1.6, [dark, light, bright]),
                 (abdomen, 4.5, 3.6, [dark, mid, bright])]
    legs_far, legs_near = [], []
    for number, along in enumerate([-1, 0, 1]):  # back, middle, front leg
        for side, legs, foot_y, knee_drop in [(0, legs_far, ground - 1.5, 0.5), (1, legs_near, ground, 2)]:
            hip = (thorax[0] + along * 1.2, thorax[1] + 1)
            knee = (thorax[0] + along * 4.5, thorax[1] + knee_drop - 2)
            foot = (thorax[0] + along * 7 + gait(frame, number, side), foot_y)
            legs.append((hip, knee, foot, 1))

    def extras(draw):
        antenna = rgb(ANT[0])
        if towards_screen:
            draw.line([(20, 10), (22.5, 6), (25, 7)], fill=antenna)
            draw.point((20, 11.5), fill=(20, 8, 4))           # eye
            draw.line([(21.5, 13.5), (22.5, 14)], fill=antenna)  # mandibles
        else:
            draw.line([(20, 7), (22, 4), (24, 4.5)], fill=antenna)

    return creature((width, height), parts, legs_far, legs_near, extras, ((14, ground), 9, 2))


def spider_sprite(towards_screen, frame):
    """A spider walking to the right: big round abdomen, 8 legs bending up above the body."""
    width, height = 46, 36
    ground = height - GROUND_MARGIN
    body = [rgb(SPIDER[1]), rgb(SPIDER[2]), rgb(SPIDER[4])]
    head_colors = [rgb(SPIDER[1]), rgb(SPIDER[3]), rgb(SPIDER[4])]
    if towards_screen:
        abdomen, head = (15, 17), (27, 21)
        parts = [(abdomen, 9, 7.5, body), (head, 5.5, 4.5, head_colors)]
    else:
        abdomen, head = (17, 20), (28, 15)
        parts = [(head, 5, 4, head_colors), (abdomen, 9.5, 8, body)]
    legs_far, legs_near = [], []
    for number, (knee_x, foot_x) in enumerate([(9, 16), (4, 9), (-6, -9), (-12, -17)]):  # front to back
        for side, legs, foot_y, knee_y in [(0, legs_far, ground - 4, head[1] - 15), (1, legs_near, ground, head[1] - 12)]:
            knee = (head[0] + knee_x, knee_y - number % 2)
            foot = (head[0] + foot_x + gait(frame, number, side), foot_y)
            legs.append((head, knee, foot, 2))

    def extras(draw):
        red = rgb(SPIDER[5])
        if towards_screen:
            draw.point((30, 19), fill=red)                    # eyes
            draw.point((31, 20.5), fill=red)
            draw.line([(31.5, 23), (32.5, 24)], fill=rgb(SPIDER[0]))  # fangs
            draw.line([(11, 15), (18, 15)], fill=red)        # marking on the abdomen
        else:
            draw.line([(13, 18), (21, 18)], fill=red)
            draw.line([(17, 15), (17, 21)], fill=red)

    return creature((width, height), parts, legs_far, legs_near, extras, ((22, ground), 16, 3))


def save_four_directions(maker, name):
    """name_se_1.png ... name_nw_2.png: se and ne are drawn, sw and nw are their mirror images."""
    for frame in range(WALK_FRAMES):
        for direction, towards_screen in [("e", True), ("e", False)]:
            image = maker(towards_screen, frame)
            vertical = "s" if towards_screen else "n"
            save(image, "sprites", "%s_%se_%d.png" % (name, vertical, frame + 1))
            save(image.transpose(Image.FLIP_LEFT_RIGHT), "sprites", "%s_%sw_%d.png" % (name, vertical, frame + 1))


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
    """An ant hill: a wide, low heap of soil, steeper in the middle, lit from the left,
    with dark entrances. The bigger version is the growing nest."""
    local = random.Random(seed)
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = image.load()
    middle = width / 2
    ground = height - GROUND_MARGIN
    base_depth = height * 0.18                  # the heap's base is an ellipse seen from above
    peak = ground - base_depth - height * 0.62  # top of the hill
    bumps = tileable_noise(width, 6, seed)[0] * 3.0
    tops = {}
    for x in range(width):
        across = abs(x - middle) / (middle - 1)
        if across >= 1:
            continue
        profile = (1 - across ** 1.8) ** 2.2        # rounded top, long gentle slopes
        top = ground - base_depth * (1 - across ** 2) ** 0.5 - (ground - base_depth - peak) * profile + bumps[x]
        tops[x] = top
        bottom = ground + base_depth * 0.35 * (1 - across ** 2) ** 0.5
        for y in range(max(int(top), 0), min(int(bottom) + 1, height)):
            slope = (x - middle) / middle                 # -1 left (lit) .. +1 right (shade)
            light = 0.62 - slope * 0.35 - (y - top) / (bottom - top + 1) * 0.25 + local.uniform(-0.08, 0.08)
            index = int(np.clip(light, 0, 0.999) * len(NEST))
            pixels[x, y] = rgb(NEST[index]) + (255,)
    draw = ImageDraw.Draw(image)
    for _ in range(width * 2):  # grains and small pebbles on the slopes
        x, y = local.uniform(2, width - 2), local.uniform(peak, ground)
        if pixels[int(x), int(y)][3]:
            draw.point((x, y), fill=rgb(local.choice([NEST[0], NEST[4], PEBBLE[2], DIRT[1]])))
    for index in range(entrances):  # on the slope facing the viewer, just below the surface line
        x = middle + (index - (entrances - 1) / 2) * width * 0.26
        y = tops[int(x)] + 5 + abs(index - (entrances - 1) / 2) * 2
        ellipse(draw, (x, y), 4, 3, rgb(NEST[0]))
        ellipse(draw, (x, y + 0.5), 3, 2, (20, 12, 6))
    return with_shadow(outline(image, DIRT[0]), (middle, ground), middle, base_depth * 0.5)


# --- Map objects: food and obstacles ---------------------------------------------
# Upright, seen from the side and a bit above, standing on the ground GROUND_MARGIN px above
# the bottom of the image, like the creatures. The game puts that point on the object's spot.

def canvas(width, height):
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image), height - GROUND_MARGIN


def blueberry_sprite():
    image, draw, ground = canvas(22, 22)
    shaded_blob(draw, (11, ground - 8), 8, 8, [rgb(BLUEBERRY[1]), rgb(BLUEBERRY[2]), rgb(BLUEBERRY[3])])
    draw.point((7, ground - 12), fill=rgb(BLUEBERRY[4]))                    # shine
    for dx, dy in [(0, 0), (-1, 1), (1, 1), (0, 1)]:                        # the little crown
        draw.point((11 + dx, ground - 15 + dy), fill=rgb(BLUEBERRY[0]))
    return with_shadow(outline(image, BLUEBERRY[0]), (11, ground), 8, 2)


def strawberry_sprite():
    image, draw, ground = canvas(28, 32)
    draw.polygon([(4, 12), (24, 12), (22, 20), (14, ground), (6, 20)], fill=rgb(STRAWBERRY[1]))
    draw.polygon([(6, 13), (20, 13), (18, 19), (13, ground - 4), (8, 19)], fill=rgb(STRAWBERRY[2]))
    ellipse(draw, (9, 15), 2, 1.5, rgb(STRAWBERRY[3]))
    local = random.Random(3)
    for _ in range(12):  # seeds
        x, y = local.randint(6, 21), local.randint(13, ground - 5)
        if image.getpixel((x, y))[3]:
            draw.point((x, y), fill=rgb(STRAWBERRY[4]))
    for angle in range(5):  # green leaves on top
        x = 14 + (angle - 2) * 4
        draw.polygon([(14, 12), (x - 2, 6 + abs(angle - 2)), (x + 2, 7 + abs(angle - 2))], fill=rgb(GRASS[3]))
    draw.line([(14, 11), (15, 4)], fill=rgb(GRASS[1]), width=2)
    return with_shadow(outline(image, STRAWBERRY[0]), (14, ground), 10, 2)


def seed_sprite():
    image, draw, ground = canvas(16, 12)
    draw.polygon([(2, ground - 3), (8, ground - 7), (14, ground - 5), (9, ground)], fill=rgb(BARK[2]))
    draw.line([(4, ground - 3), (12, ground - 5)], fill=rgb(LARVA[2]))   # sunflower seed stripes
    draw.line([(6, ground - 1), (11, ground - 3)], fill=rgb(LARVA[1]))
    return with_shadow(outline(image, BARK[0]), (8, ground), 6, 1.5)


def larva_sprite():
    image, draw, ground = canvas(28, 16)
    for segment in range(6):  # a curled grub made of round segments
        x = 5 + segment * 3.4
        y = ground - 5 - (1.5 if 1 <= segment <= 4 else 0)
        shaded_blob(draw, (x, y), 3.4, 4 - abs(segment - 2.5) * 0.4, [rgb(LARVA[1]), rgb(LARVA[2]), rgb(LARVA[3])])
        draw.line([(x + 1.6, y - 3), (x + 1.6, y + 2)], fill=rgb(LARVA[1]))
    ellipse(draw, (24, ground - 5), 2.5, 2.5, rgb(CRUMB[1]))   # head
    return with_shadow(outline(image, LARVA[0]), (14, ground), 12, 2)


def dead_spider_sprite():
    """A spider on its back, legs curled up: a food item."""
    image, draw, ground = canvas(40, 28)
    for number in range(4):
        for side in (-1, 1):
            hip = (20 + side * 3, ground - 8)
            knee = (20 + side * (6 + number * 3), ground - 15 - number % 2 * 2)
            foot = (20 + side * (4 + number * 3), ground - 19 - number)
            leg(draw, hip, knee, foot, rgb(SPIDER[2]), 2)
    shaded_blob(draw, (16, ground - 6), 8, 5, [rgb(SPIDER[1]), rgb(SPIDER[2]), rgb(SPIDER[3])])
    shaded_blob(draw, (26, ground - 5), 4.5, 3.5, [rgb(SPIDER[1]), rgb(SPIDER[3]), rgb(SPIDER[4])])
    return with_shadow(outline(image, SPIDER[0]), (20, ground), 15, 2)


def dead_ant_sprite():
    """An ant on its back, legs up (fades away in the game)."""
    image, draw, ground = canvas(28, 16)
    for along in (-1, 0, 1):
        for side in (-1, 1):
            hip = (14 + along * 1.5, ground - 4)
            knee = (14 + along * 4 + side, ground - 8)
            foot = (14 + along * 5 + side * 2, ground - 10 + abs(along))
            leg(draw, hip, knee, foot, rgb(ANT[0]))
    for center, radius_x, radius_y in [((7, ground - 3), 4.3, 2.8), ((14, ground - 3), 2.4, 1.6), ((20, ground - 3), 2.5, 2.2)]:
        shaded_blob(draw, center, radius_x, radius_y, [rgb(ANT[1]), rgb(ANT[2]), rgb(ANT[3])])
    return with_shadow(outline(image, ANT[0]), (14, ground), 11, 2)


def rock_sprite(seed):
    """A mossy boulder."""
    local = random.Random(seed)
    image, draw, ground = canvas(34, 30)
    bumps = [(17 + local.randint(-3, 3), ground - 11, 13, 10), (10, ground - 7, 8, 7), (24, ground - 7, 8, 7)]
    for x, y, radius_x, radius_y in bumps:
        ellipse(draw, (x, y), radius_x, radius_y, rgb(ROCK[1]))
    for x, y, radius_x, radius_y in bumps:
        ellipse(draw, (x - 1, y - 1), radius_x - 2, radius_y - 2, rgb(ROCK[2]))
        ellipse(draw, (x - radius_x * 0.3, y - radius_y * 0.45), radius_x * 0.4, radius_y * 0.3, rgb(ROCK[3]))
    for _ in range(6):  # moss on top
        x, y = local.randint(8, 25), local.randint(ground - 20, ground - 15)
        ellipse(draw, (x, y), local.randint(1, 3), 1, rgb(local.choice(MOSS[1:])))
    return with_shadow(outline(image, ROCK[0]), (17, ground), 16, 3)


def twig_sprite():
    image, draw, ground = canvas(46, 16)
    draw.line([(3, ground - 3), (43, ground - 7)], fill=rgb(BARK[2]), width=3)
    draw.line([(3, ground - 4), (43, ground - 8)], fill=rgb(BARK[4]), width=1)   # lit top edge
    draw.line([(26, ground - 5), (33, ground - 12), (36, ground - 12)], fill=rgb(BARK[2]), width=2)
    draw.polygon([(36, ground - 13), (40, ground - 15), (39, ground - 11)], fill=rgb(GRASS[3]))  # a leaf
    return with_shadow(outline(image, BARK[0]), (23, ground), 20, 2)


def high_grass_sprite(seed):
    local = random.Random(seed)
    image, draw, ground = canvas(30, 42)
    for blade in range(18):  # thin blades fanning out from the tuft, bending at the tip
        x = local.uniform(11, 19)
        lean = (x - 15) * 1.6 + local.uniform(-4, 4)
        tall = local.uniform(16, 37)
        color = rgb(local.choice(GRASS[1:]))
        draw.line([(x, ground), (x + lean * 0.4, ground - tall * 0.6), (x + lean, ground - tall)], fill=color, width=1)
    x = local.uniform(12, 18)  # one seed head
    draw.line([(x, ground), (x + 1, 6)], fill=rgb(GRASS[2]))
    ellipse(draw, (x + 1, 5), 1, 2.5, rgb(CRUMB[1]))
    return with_shadow(outline(image, GRASS[0]), (15, ground), 11, 2)


def pine_cone_sprite():
    image, draw, ground = canvas(22, 28)
    for row in range(7):  # overlapping scales, wider in the middle
        y = 4 + row * 3
        half = 3 + (3 - abs(row - 3.5)) * 1.6
        for x in np.arange(11 - half, 11 + half, 3):
            color = PINE[2] if (row + int(x)) % 2 else PINE[3]
            draw.polygon([(x, y), (x + 3, y), (x + 1.5, y + 4)], fill=rgb(color))
    draw.line([(11, 1), (11, 4)], fill=rgb(PINE[1]), width=2)
    return with_shadow(outline(image, PINE[0]), (11, ground), 8, 2)


def dead_leaf_sprite():
    image, draw, ground = canvas(46, 24)
    outline_points = [(3, ground - 4), (12, ground - 13), (26, ground - 17), (40, ground - 13), (44, ground - 9),
                      (36, ground - 3), (20, ground), (8, ground - 1)]
    draw.polygon(outline_points, fill=rgb(LEAF[2]))
    draw.polygon([(8, ground - 6), (18, ground - 12), (30, ground - 13), (38, ground - 10), (28, ground - 6), (14, ground - 4)], fill=rgb(LEAF[3]))
    draw.line([(3, ground - 4), (44, ground - 9)], fill=rgb(LEAF[1]))                  # midrib
    for x in range(10, 40, 6):                                                        # veins
        draw.line([(x, ground - 4 - x * 0.12), (x + 4, ground - 11 - x * 0.05)], fill=rgb(LEAF[1]))
    draw.line([(1, ground - 3), (4, ground - 4)], fill=rgb(LEAF[0]), width=2)          # stem
    return with_shadow(outline(image, LEAF[0]), (23, ground), 21, 3)


def tree_trunk_sprite():
    """A huge standing trunk: much taller than the screen at close zoom, with roots."""
    local = random.Random(9)
    image, draw, ground = canvas(64, 240)
    for x in range(10, 54):  # bark: vertical stripes, lit from the left
        light = 0.75 - (x - 10) / 44 * 0.6
        for y in range(0, ground - 6):
            stripe = 0.12 if (x + local.randint(0, 1)) % 5 == 0 else 0
            index = int(np.clip(light - stripe + local.uniform(-0.05, 0.05), 0, 0.999) * len(BARK))
            image.putpixel((x, y), rgb(BARK[index]) + (255,))
    for side, x in [(-1, 12), (1, 52)]:  # roots spreading on the ground
        draw.polygon([(x, ground - 30), (x + side * 10, ground - 2), (x - side * 8, ground - 4)], fill=rgb(BARK[2]))
    draw.polygon([(26, ground - 10), (32, ground), (38, ground - 10)], fill=rgb(BARK[3]))
    for _ in range(8):  # moss on the bark
        x, y = local.randint(14, 30), local.randint(ground - 60, ground - 8)
        ellipse(draw, (x, y), local.randint(2, 4), local.randint(1, 3), rgb(local.choice(MOSS)))
    return with_shadow(outline(image, BARK[0]), (32, ground), 30, 5)


def mushroom_sprite():
    image, draw, ground = canvas(20, 24)
    draw.rectangle([8, ground - 10, 12, ground], fill=rgb(MUSHROOM[3]))
    draw.line([(8, ground - 10), (8, ground)], fill=rgb(MUSHROOM[4]))
    draw.pieslice([1, ground - 21, 19, ground - 5], 180, 360, fill=rgb(MUSHROOM[1]))
    draw.pieslice([3, ground - 20, 15, ground - 9], 180, 360, fill=rgb(MUSHROOM[2]))
    for x, y in [(6, ground - 16), (12, ground - 18), (14, ground - 14)]:
        draw.point((x, y), fill=rgb(MUSHROOM[4]))
    return with_shadow(outline(image, MUSHROOM[0]), (10, ground), 6, 1.5)


def glow_sprite():
    """Soft round yellow light, drawn on the ground under food."""
    size = 64
    y, x = np.mgrid[0:size, 0:size]
    distance = np.hypot(x - size / 2 + 0.5, y - size / 2 + 0.5) / (size / 2)
    alpha = np.clip(1 - distance, 0, 1) ** 2 * 255
    pixels = np.zeros((size, size, 4), np.uint8)
    pixels[:, :, :3] = rgb("#ffe27a")
    pixels[:, :, 3] = alpha.astype(np.uint8)
    return Image.fromarray(pixels)


def make_sprites():
    save_four_directions(ant_sprite, "ant")
    save_four_directions(spider_sprite, "spider")
    dead_ant = dead_ant_sprite()
    save(dead_ant, "sprites", "ant_dead_e.png")
    save(dead_ant.transpose(Image.FLIP_LEFT_RIGHT), "sprites", "ant_dead_w.png")
    save(crumb_sprite(), "sprites", "food_crumb.png")
    save(glow_sprite(), "sprites", "food_glow.png")
    save(nest_sprite(52, 30, 1, 1), "sprites", "nest_small.png")
    save(nest_sprite(88, 46, 3, 2), "sprites", "nest_big.png")
    # Food (objects/<kind>.png); variants would be <kind>_2.png, <kind>_3.png...
    save(blueberry_sprite(), "sprites", "objects", "blueberry.png")
    save(strawberry_sprite(), "sprites", "objects", "strawberry.png")
    save(seed_sprite(), "sprites", "objects", "seed.png")
    save(larva_sprite(), "sprites", "objects", "larva.png")
    save(dead_spider_sprite(), "sprites", "objects", "dead_spider.png")
    # Obstacles
    for variant in range(3):
        save(rock_sprite(variant), "sprites", "objects", "rock.png" if variant == 0 else "rock_%d.png" % (variant + 1))
        save(high_grass_sprite(variant), "sprites", "objects", "high_grass.png" if variant == 0 else "high_grass_%d.png" % (variant + 1))
    save(twig_sprite(), "sprites", "objects", "twig.png")
    save(pine_cone_sprite(), "sprites", "objects", "pine_cone.png")
    save(dead_leaf_sprite(), "sprites", "objects", "dead_leaf.png")
    save(tree_trunk_sprite(), "sprites", "objects", "tree_trunk.png")
    save(mushroom_sprite(), "sprites", "objects", "mushroom.png")


if __name__ == "__main__":
    make_tiles()
    make_sprites()
    print("Art written to tiles/ and sprites/")
