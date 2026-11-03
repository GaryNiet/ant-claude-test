"""Generates the game's music and sound effects (sounds/*.wav).

Run from the project folder:   python3 tools/make_sounds.py
Needs Python 3 with numpy (pip install numpy).
Every sound is made from code (tones, noise and envelopes), so changing a note or a length
here and running it again rebuilds them all. The random seed is fixed: same output every run.

  music.wav           a calm looping tune for the meadow: A minor, 84 beats per minute,
                      16 bars (pad, plucked arpeggios, bass, a kalimba melody, soft shaker).
                      It loops seamlessly: the notes still ringing at the end start the file.
  spider_death.wav    a spider is killed: a crunch, a falling screech and a thud
  spider_arrival.wav  a spider comes onto the map: two low, growling notes
  hatch.wav           a larva hatches into one of our ants: a little pop
  click.wav           a button is pressed: a soft wooden tick
"""
import os
import wave

import numpy as np

RATE = 22050                 # samples per second (enough for these soft sounds, and small files)
OUT = "sounds"
rng = np.random.default_rng(29)


# --- Building blocks ---------------------------------------------------------------------

def note_hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def time_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def envelope(seconds, attack, release):
    """Rises over `attack`, stays at 1, falls over `release` (all in seconds)."""
    t = time_axis(seconds)
    env = np.ones_like(t)
    if attack > 0:
        env = np.minimum(env, t / attack)
    if release > 0:
        env = np.minimum(env, (seconds - t) / release)
    return np.clip(env, 0.0, 1.0)


def pluck(midi, seconds, brightness=1.0):
    """A plucked string: harmonics that die away, the high ones faster."""
    t = time_axis(seconds)
    f = note_hz(midi)
    sound = np.zeros_like(t)
    for harmonic, level in [(1, 1.0), (2, 0.5 * brightness), (3, 0.25 * brightness), (4, 0.12 * brightness)]:
        sound += level * np.sin(2 * np.pi * f * harmonic * t) * np.exp(-t * (2.5 + 2.0 * harmonic))
    return sound * np.minimum(1.0, t / 0.004)


def kalimba(midi, seconds):
    """A kalimba / marimba tone: a pure note with a short metallic ping on top."""
    t = time_axis(seconds)
    f = note_hz(midi)
    body = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.0)
    ping = 0.3 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 25.0)
    return (body + ping) * np.minimum(1.0, t / 0.003)


def pad(midis, seconds):
    """A soft held chord: slightly detuned sines that swell in and out."""
    t = time_axis(seconds)
    sound = np.zeros_like(t)
    for midi in midis:
        f = note_hz(midi)
        for detune in (-0.15, 0.15):
            sound += np.sin(2 * np.pi * f * (1 + detune / 100.0) * t)
            sound += 0.2 * np.sin(2 * np.pi * 2 * f * (1 + detune / 100.0) * t)
    return sound / (2 * len(midis)) * envelope(seconds, seconds * 0.35, seconds * 0.4)


def bass(midi, seconds):
    """A round, soft bass note (a triangle wave with its edges smoothed)."""
    t = time_axis(seconds)
    f = note_hz(midi)
    tri = 2.0 / np.pi * np.arcsin(np.sin(2 * np.pi * f * t))
    return (0.7 * tri + 0.3 * np.sin(2 * np.pi * f * t)) * envelope(seconds, 0.01, seconds * 0.5) * np.exp(-t * 0.8)


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(seconds * RATE))


def low_pass(sound, strength):
    """Smooths a sound (removes its highs). strength 0..1: higher = duller."""
    out = np.empty_like(sound)
    last = 0.0
    keep = strength
    for i, sample in enumerate(sound):
        last = keep * last + (1.0 - keep) * sample
        out[i] = last
    return out


def add(track, sound, at_seconds, level):
    """Mixes `sound` into `track` starting at `at_seconds` (wrapping past the end: loops)."""
    start = int(at_seconds * RATE)
    for i in range(0, len(sound), len(track)):
        piece = sound[i:i + len(track)]
        begin = (start + i) % len(track)
        first = min(len(piece), len(track) - begin)
        track[begin:begin + first] += level * piece[:first]
        track[:len(piece) - first] += level * piece[first:]


def save(name, sound, peak=0.8, loops=False):
    """Writes a 16-bit mono WAV, scaled to `peak`. Sounds that don't loop fade out over their
    last 15 ms, so they don't end with a click."""
    sound = sound / max(1e-9, np.max(np.abs(sound))) * peak
    if not loops:
        fade = int(0.015 * RATE)
        sound[-fade:] *= np.linspace(1.0, 0.0, fade)
    data = (np.clip(sound, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(data.tobytes())


# --- The music -------------------------------------------------------------------------

BPM = 84
BEAT = 60.0 / BPM
BAR = 4 * BEAT
# One chord per 2 bars: root note for the bass, then the chord's notes (MIDI numbers).
CHORDS = [
    (45, [57, 60, 64]),   # A minor
    (41, [57, 60, 65]),   # F major
    (48, [55, 60, 64]),   # C major
    (43, [55, 59, 62]),   # G major
    (45, [57, 60, 64]),   # A minor
    (41, [57, 60, 65]),   # F major
    (38, [57, 62, 65]),   # D minor
    (40, [56, 59, 64]),   # E major (leads back to A minor)
]
ARPEGGIO = [0, 1, 2, 1, 0, 2, 1, 2]   # which chord note each eighth note plays (an octave up)
# The kalimba melody, 8 bars (beat in the bar, MIDI note), A minor pentatonic; played twice,
# the second time an octave higher for the first 4 bars.
MELODY = [
    [(0, 76), (1.5, 74), (2, 72), (3, 69)],
    [(0.5, 72), (1, 74), (2, 76)],
    [(0, 79), (1, 76), (2, 74), (2.5, 72)],
    [(0, 74), (2, 67)],
    [(0, 69), (1, 72), (1.5, 74), (2, 76)],
    [(1, 72), (2, 69)],
    [(0, 74), (1, 72), (2, 69), (3, 67)],
    [(0, 68), (2, 71)],
]


def music():
    bars = 2 * len(CHORDS)
    track = np.zeros(int(bars * BAR * RATE))
    for index, (root, chord) in enumerate(CHORDS):
        start = index * 2 * BAR
        add(track, pad(chord, 2 * BAR + BEAT), start, 0.22)
        for bar in range(2):
            bar_start = start + bar * BAR
            add(track, bass(root, 1.8 * BEAT), bar_start, 0.35)
            add(track, bass(root + 7 if bar == 1 else root, 1.8 * BEAT), bar_start + 2 * BEAT, 0.28)
            for eighth, which in enumerate(ARPEGGIO):
                accent = 1.0 if eighth % 2 == 0 else 0.7
                add(track, pluck(chord[which] + 12, 1.2, 0.8), bar_start + eighth * BEAT / 2, 0.16 * accent)
            for eighth in range(8):  # soft shaker on the off-beats
                if eighth % 2 == 1:
                    hit = low_pass(noise(0.06), 0.3) * np.exp(-time_axis(0.06) * 60.0)
                    add(track, hit, bar_start + eighth * BEAT / 2, 0.05)
    for repeat in range(2):
        for bar, notes in enumerate(MELODY):
            for beat, midi in notes:
                shift = 12 if repeat == 1 and bar < 4 else 0
                add(track, kalimba(midi + shift, 1.6), (repeat * len(MELODY) + bar) * BAR + beat * BEAT, 0.3)
    save("music.wav", track, 0.7, loops=True)


# --- Sound effects -------------------------------------------------------------------------

def spider_death():
    seconds = 0.9
    t = time_axis(seconds)
    crunch = low_pass(noise(seconds), 0.55) * np.exp(-t * 18.0)
    pitch = 900.0 * np.exp(-t * 2.6) + 120.0                  # falls from ~1000 Hz to ~200
    wobble = 1.0 + 0.04 * np.sin(2 * np.pi * 23.0 * t)
    screech = np.sin(2 * np.pi * np.cumsum(pitch * wobble) / RATE)
    screech = (screech + 0.4 * np.sign(screech)) * envelope(seconds, 0.02, 0.4) * np.exp(-t * 2.5)
    thud = np.sin(2 * np.pi * np.cumsum(70.0 * np.exp(-t * 3.0) + 40.0) / RATE) * np.exp(-t * 7.0)
    save("spider_death.wav", 1.0 * crunch + 0.45 * screech + 0.9 * thud, 0.85)


def spider_arrival():
    seconds = 1.3
    sound = np.zeros(int(seconds * RATE))
    for start, midi in [(0.0, 40), (0.45, 41)]:
        length = seconds - start
        t = time_axis(length)
        f = note_hz(midi)
        growl = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * 2 * f * t) + 0.3 * np.sin(2 * np.pi * 3.01 * f * t)
        growl *= 1.0 + 0.3 * np.sin(2 * np.pi * 9.0 * t)       # a rough, buzzing growl
        growl *= envelope(length, 0.03, length * 0.7)
        begin = int(start * RATE)
        sound[begin:begin + len(growl)] += growl[:len(sound) - begin]
    save("spider_arrival.wav", sound, 0.7)


def hatch():
    seconds = 0.18
    t = time_axis(seconds)
    pitch = 350.0 + 1400.0 * (t / seconds) ** 0.6
    pop = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * envelope(seconds, 0.005, 0.12)
    save("hatch.wav", pop, 0.6)


def click():
    seconds = 0.05
    t = time_axis(seconds)
    tick = np.sin(2 * np.pi * 1700.0 * t) * np.exp(-t * 120.0) + 0.3 * low_pass(noise(seconds), 0.2) * np.exp(-t * 200.0)
    save("click.wav", tick, 0.5)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    music()
    spider_death()
    spider_arrival()
    hatch()
    click()
    print("Sounds written to %s/" % OUT)
