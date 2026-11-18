#!/usr/bin/env python3
"""Ambience v2 (owner, v0.22.4: the old loops sounded synthetic / "too MP3"): layered, filtered noise beds with
natural, non-repeating swells, mixed at 44.1 kHz and made seamless (the tail is cross-faded into the head).

  python3 tools/gen_ambience.py            (needs numpy + scipy)  -> assets/sfx/<name>.wav
  then: ROBLOX_API_KEY=... python3 tools/upload_sfx.py --user 1527424396 --only AmbienceSea,AmbienceIsland,...

  AmbienceSea         open sea from a ship: deep ocean wash, swells rolling past the hull, slaps, spray, wind
  AmbienceIsland      on an island: soft breeze in the leaves, distant surf on the shore, a few far-off birds
  AmbienceUnderwater  under the surface: muffled pressure rumble, slow swells, bubble trickles
  WaterPlunge         dive under: splash, rushing water, a burst of bubbles
  WaterSurface        come up: water breaking + drips
"""
import os
import numpy as np
from scipy.signal import butter, sosfilt, sosfiltfilt
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(20261118)


def n(sec):
    return int(sec * SR)


def white(sec):
    return rng.standard_normal(n(sec))


def brown(sec):
    x = np.cumsum(rng.standard_normal(n(sec)))
    x = x - sosfilt(butter(1, 8, 'hp', fs=SR, output='sos'), x) * 0  # keep
    x = sosfilt(butter(2, 12, 'hp', fs=SR, output='sos'), x)  # remove DC drift
    return x / (np.std(x) + 1e-9)


def pink(sec):
    # Voss-ish: sum of octave-filtered white noise
    w = white(sec)
    out = np.zeros_like(w)
    for k, f in enumerate((40, 120, 360, 1100, 3300, 9000)):
        out += sosfilt(butter(1, f, 'lp', fs=SR, output='sos'), w) * (1.0 / (k + 1) ** 0.15)
    return out / (np.std(out) + 1e-9)


def lp(x, f, order=2):
    return sosfiltfilt(butter(order, f, 'lp', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return sosfiltfilt(butter(order, f, 'hp', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfiltfilt(butter(order, [lo, hi], 'bp', fs=SR, output='sos'), x)


def smooth_env(sec, rate, lo, hi):
    """slow random envelope (values between lo and hi), changes about `rate` times per second"""
    pts = max(4, int(sec * rate) + 4)
    knots = rng.uniform(lo, hi, pts)
    t = np.linspace(0, pts - 1, n(sec))
    i = np.floor(t).astype(int)
    f = t - i
    f = f * f * (3 - 2 * f)
    i2 = np.minimum(i + 1, pts - 1)
    return knots[i] * (1 - f) + knots[i2] * f


def swells(sec, period=(5.5, 9.0), attack=0.35, depth=1.0):
    """wave cycles: each swell rises then falls over a random period (natural, non-repeating)"""
    env = np.zeros(n(sec))
    t = 0.0
    while t < sec:
        per = rng.uniform(*period)
        amp = rng.uniform(0.55, 1.0) * depth
        i0, i1 = n(t), min(n(sec), n(t + per * 1.6))
        tt = (np.arange(i1 - i0) / SR) / per
        rise = np.clip(tt / attack, 0, 1) ** 2
        fall = np.exp(-np.clip(tt - attack, 0, None) * 2.4)
        env[i0:i1] += amp * rise * fall
        t += per
    return env


def bursts(sec, rate, dur=(0.05, 0.25), shape=8.0):
    """random short events (slaps, drips): returns an envelope of decaying bursts"""
    env = np.zeros(n(sec))
    count = int(sec * rate)
    for _ in range(count):
        t0 = rng.uniform(0, sec)
        d = rng.uniform(*dur)
        i0, i1 = n(t0), min(n(sec), n(t0 + d * 3))
        tt = np.arange(i1 - i0) / SR
        env[i0:i1] += rng.uniform(0.4, 1.0) * (1 - np.exp(-tt * 400)) * np.exp(-tt / d * (shape / 4))
    return env


def bubble(dur, f0, f1):
    """one bubble 'bloop': a damped sine sliding up in pitch (Minnaert resonance)"""
    t = np.arange(n(dur)) / SR
    f = f0 + (f1 - f0) * (t / dur) ** 0.6
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / (dur * 0.35)) * (1 - np.exp(-t * 900))


def place(dst, src, t):
    i = n(t)
    j = min(len(dst), i + len(src))
    if i < len(dst):
        dst[i:j] += src[: j - i]


def bird(dur=0.18, f=3200):
    """a soft far-off chirp: quick upward glide with a little vibrato and one harmonic"""
    t = np.arange(n(dur)) / SR
    fr = f * (1 + 0.35 * np.sin(np.pi * t / dur)) * (1 + 0.02 * np.sin(2 * np.pi * 38 * t))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return (np.sin(ph) + 0.18 * np.sin(2 * ph)) * env


def seamless(x, loop_sec, fade_sec):
    """x is loop_sec + fade_sec long: cross-fade the extra tail into the head (equal power)"""
    L, F = n(loop_sec), n(fade_sec)
    out = x[:L].copy()
    k = np.linspace(0, 1, F)
    out[:F] = x[:F] * np.sin(k * np.pi / 2) + x[L:L + F] * np.cos(k * np.pi / 2)
    return out


def save(name, x, peak=0.8):
    x = x - np.mean(x)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print('wrote', name, f'{len(x) / SR:.1f}s')


def sea(loop=48.0, fade=4.0):
    sec = loop + fade
    # deep body of the ocean: brown noise, low-passed, breathing slowly
    body = lp(brown(sec), 420) * (0.55 + 0.45 * smooth_env(sec, 0.15, 0.4, 1.0))
    # swells rolling past the hull: band of mid noise whose loudness AND brightness follow each wave
    sw = swells(sec, (5.0, 8.5), 0.4)
    wash_dark = lp(pink(sec), 900)
    wash_bright = bp(pink(sec), 900, 4200)
    bright = np.clip(sw, 0, 1.2)
    wash = wash_dark * (0.25 + 0.75 * sw) + wash_bright * 0.55 * bright ** 1.6
    # hull slaps and little splashes
    slaps = lp(white(sec), 1600) * bursts(sec, 0.45, (0.06, 0.2))
    spray = hp(white(sec), 5000) * bursts(sec, 0.2, (0.2, 0.6)) * 0.35
    # wind over open water
    wind = bp(white(sec), 300, 1400) * smooth_env(sec, 0.25, 0.05, 0.3)
    x = body * 0.9 + wash * 1.0 + slaps * 0.7 + spray + wind * 0.5
    return seamless(x, loop, fade)


def island(loop=60.0, fade=5.0):
    sec = loop + fade
    gust = smooth_env(sec, 0.18, 0.15, 1.0) ** 1.5
    leaves = bp(pink(sec), 1100, 5200) * (0.08 + 0.5 * gust) * (0.7 + 0.3 * smooth_env(sec, 6, 0.0, 1.0))
    breeze = bp(pink(sec), 150, 900) * (0.12 + 0.35 * gust)
    surf_env = swells(sec, (8.0, 12.0), 0.35, 0.8)
    surf = lp(pink(sec), 1100) * (0.12 + 0.55 * surf_env)
    x = leaves * 0.6 + breeze * 0.6 + surf * 0.9
    # a few far-off birds: short phrases of 2-4 chirps, quiet and low-passed (distance)
    birds = np.zeros(n(sec))
    t = rng.uniform(2, 6)
    while t < loop - 2:
        f = rng.uniform(2400, 4200)
        for k in range(rng.integers(2, 5)):
            place(birds, bird(rng.uniform(0.09, 0.2), f * rng.uniform(0.92, 1.12)), t + k * rng.uniform(0.14, 0.26))
        t += rng.uniform(5, 11)
    x += lp(birds, 5000) * 0.12
    return seamless(x, loop, fade)


def underwater(loop=40.0, fade=4.0):
    sec = loop + fade
    rumble = lp(brown(sec), 220, 4) * (0.6 + 0.4 * smooth_env(sec, 0.12, 0.3, 1.0))
    press = lp(pink(sec), 600, 4) * (0.15 + 0.35 * swells(sec, (6, 10), 0.5, 0.8))
    x = rumble + press * 0.6
    # bubble trickles: little clusters drifting up
    bub = np.zeros(n(sec))
    t = rng.uniform(0.5, 2)
    while t < loop - 1:
        for _ in range(rng.integers(3, 9)):
            f0 = rng.uniform(300, 900)
            place(bub, bubble(rng.uniform(0.04, 0.12), f0, f0 * rng.uniform(1.3, 1.9)) * rng.uniform(0.3, 1.0), t + rng.uniform(0, 0.8))
        t += rng.uniform(1.5, 4.5)
    x += lp(bub, 2500) * 0.35
    return seamless(x, loop, fade)


def plunge():
    sec = 1.6
    t = np.arange(n(sec)) / SR
    splash = bp(white(sec), 500, 6000) * np.exp(-t / 0.12) * (1 - np.exp(-t * 600))
    rush = lp(pink(sec), 700) * np.exp(-t / 0.5) * (1 - np.exp(-t * 30))
    bub = np.zeros(n(sec))
    for _ in range(26):
        f0 = rng.uniform(350, 1200)
        place(bub, bubble(rng.uniform(0.03, 0.09), f0, f0 * 1.7), rng.uniform(0.05, 0.9))
    return splash * 0.9 + rush * 1.2 + lp(bub, 3000) * 0.5


def surface():
    sec = 1.1
    t = np.arange(n(sec)) / SR
    brk = bp(white(sec), 700, 7000) * np.exp(-t / 0.18) * (1 - np.exp(-t * 300))
    drips = np.zeros(n(sec))
    for _ in range(9):
        f0 = rng.uniform(900, 1800)
        place(drips, bubble(rng.uniform(0.02, 0.05), f0, f0 * 1.5), rng.uniform(0.2, 1.0))
    return brk + drips * 0.35


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    save('AmbienceSea', sea(), 0.75)
    save('AmbienceIsland', island(), 0.7)
    save('AmbienceUnderwater', underwater(), 0.75)
    save('WaterPlunge', plunge(), 0.8)
    save('WaterSurface', surface(), 0.75)
