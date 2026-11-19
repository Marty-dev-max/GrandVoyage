#!/usr/bin/env python3
"""Blocky, satisfying UI sounds for the voxel look (v0.24.0, owner): wooden-block knocks + short 8-bit square blips.
   python3 tools/gen_ui_sfx.py   -> assets/sfx/Blk*.wav
   ROBLOX_API_KEY=... python3 tools/upload_sfx.py --user 1527424396 --only BlkHover,BlkClick,...
Config/Sounds maps the UI sounds onto these with `prefer`."""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(24)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.002, curve=8.0):
    x = np.ones(n)
    ai = max(1, int(a * SR))
    x[:ai] = np.linspace(0, 1, ai)
    x[ai:] *= np.exp(-curve * np.linspace(0, 1, n - ai))
    return x


def square(f, d, duty=0.5, curve=8.0, slide=0.0):
    tt = t(d)
    freq = f * (1 + slide * tt / d)
    ph = np.cumsum(freq) / SR
    s = np.where((ph % 1.0) < duty, 1.0, -1.0) * 0.5
    return s * env(len(tt), curve=curve)


def knock(f, d=0.07, bright=1.0):
    """a wooden block knock: a fast-decaying sine pair + a tiny noise click"""
    tt = t(d)
    body = np.sin(2 * np.pi * f * tt) + 0.55 * np.sin(2 * np.pi * f * 2.71 * tt) * bright
    body *= env(len(tt), 0.0008, curve=26)
    click = rng.uniform(-1, 1, len(tt)) * env(len(tt), 0.0003, curve=180) * 0.6
    return body + click


def mix(*parts):
    n = max(int(o * SR) + len(p) for o, p in parts)
    out = np.zeros(n)
    for o, p in parts:
        i = int(o * SR)
        out[i:i + len(p)] += p
    return out


def soften(x, k=3):
    return np.convolve(x, np.ones(k) / k, mode='same')


def save(name, x, gain=0.85):
    x = soften(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), int(0.004 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    # hover: a tiny high wooden tick + soft blip
    save('BlkHover', mix((0, knock(1400, 0.05, 0.6) * 0.7), (0.004, square(1568, 0.035, 0.25, curve=14) * 0.25)), 0.55)
    # click: chunky block knock + 8-bit pop up a fifth
    save('BlkClick', mix((0, knock(620, 0.09)), (0.0, square(784, 0.05, 0.5, curve=12) * 0.35), (0.035, square(1175, 0.06, 0.5, curve=12) * 0.3)))
    # drop into a slot: two knocks (block set down) + low thunk
    save('BlkDrop', mix((0, knock(420, 0.12)), (0.045, knock(700, 0.08) * 0.8), (0, np.sin(2 * np.pi * 110 * t(0.12)) * env(int(SR * 0.12), 0.001, 18) * 0.7)))
    # swap: a quick down-up 8-bit slide + knock
    save('BlkSwap', mix((0, square(880, 0.06, 0.5, 10, -0.3) * 0.5), (0.05, square(660, 0.07, 0.5, 10, 0.5) * 0.5), (0.02, knock(900, 0.06) * 0.6)))
    # window open: rising three-note arpeggio on top of a block clack
    save('BlkOpen', mix((0, knock(520, 0.08)), (0.0, square(523, 0.06, 0.5, 9) * 0.35), (0.05, square(659, 0.06, 0.5, 9) * 0.35), (0.10, square(784, 0.1, 0.5, 7) * 0.35)))
    # window close: falling two notes + soft knock
    save('BlkClose', mix((0, square(659, 0.06, 0.5, 9) * 0.35), (0.05, square(440, 0.09, 0.5, 8) * 0.35), (0.04, knock(380, 0.09) * 0.8)))
    # toggle: crisp double click
    save('BlkToggle', mix((0, knock(980, 0.05)), (0.04, knock(1320, 0.05) * 0.8), (0.02, square(1046, 0.04, 0.25, 14) * 0.25)))
    # color pick / spin tick: very short bright blip
    save('BlkTick', mix((0, square(1760, 0.03, 0.5, 18) * 0.5), (0, knock(1600, 0.03, 0.4) * 0.4)), 0.5)
    # spin land / reward: rising 8-bit fanfare
    notes = [523, 659, 784, 1046]
    save('BlkReward', mix(*[(i * 0.07, square(f, 0.12 if i < 3 else 0.3, 0.5, 6 if i < 3 else 3) * 0.4) for i, f in enumerate(notes)], (0, knock(520, 0.1))))
    # LEVEL UP (owner: make it stand out and feel great, like levelling up in block games): a bright bell arpeggio
    # climbing an octave + a sparkling shimmer tail + a soft bass under it
    def bell(f, d, curve=4.0):
        tt = t(d)
        s = np.sin(2 * np.pi * f * tt) + 0.45 * np.sin(2 * np.pi * f * 2.0 * tt) + 0.22 * np.sin(2 * np.pi * f * 3.01 * tt) + 0.1 * np.sin(2 * np.pi * f * 4.2 * tt)
        return s * env(len(tt), 0.003, curve)
    arp = [784, 988, 1175, 1568]
    parts = [(i * 0.085, bell(f, 0.9 if i == 3 else 0.5, 3.5 if i == 3 else 6) * (0.7 if i < 3 else 1.0)) for i, f in enumerate(arp)]
    parts.append((0.255, bell(2093, 1.1, 3.0) * 0.35))
    shimmer = np.zeros(int(SR * 1.2))
    for k in range(22):
        o = int(SR * (0.25 + k * 0.035))
        f = 2600 + (k % 5) * 420
        b = bell(f, 0.12, 14) * 0.12 * (1 - k / 24)
        shimmer[o:o + len(b)] += b[: len(shimmer) - o]
    parts.append((0, shimmer))
    parts.append((0, np.sin(2 * np.pi * 196 * t(0.6)) * env(int(SR * 0.6), 0.005, 5) * 0.45))
    save('BlkLevelUp', mix(*parts), 0.9)
    print('wrote Blk* ui sounds')


if __name__ == '__main__':
    main()
