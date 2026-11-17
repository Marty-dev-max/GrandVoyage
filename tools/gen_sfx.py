#!/usr/bin/env python3
"""Synthesizes the placeholder SFX/music pack into assets/sfx/*.wav (22.05 kHz mono, 16-bit).
Upload them to Roblox (Creator Hub > Audio) and paste the asset ids into src/shared/Config/Sounds.lua."""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=None, curve=4.0):
    x = np.ones(n); ai = max(1, int(a * SR)); x[:ai] = np.linspace(0, 1, ai)
    tail = np.linspace(0, 1, n - ai); x[ai:] *= np.exp(-curve * tail)
    return x
def tone(f, d, wave_='sine', a=0.005, curve=4.0, vib=0.0):
    tt = t(d); ph = 2 * np.pi * f * tt + vib * np.sin(2 * np.pi * 6 * tt)
    if wave_ == 'sine': s = np.sin(ph)
    elif wave_ == 'square': s = np.sign(np.sin(ph)) * 0.5
    elif wave_ == 'tri': s = 2 / np.pi * np.arcsin(np.sin(ph))
    elif wave_ == 'bell': s = np.sin(ph) + 0.5 * np.sin(2.76 * ph) + 0.25 * np.sin(5.4 * ph)
    return s * env(len(tt), a, curve=curve)
def sweep(f0, f1, d, wave_='sine', curve=3.0):
    tt = t(d); f = np.linspace(f0, f1, len(tt)); ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) if wave_ == 'sine' else np.sign(np.sin(ph)) * 0.5
    return s * env(len(tt), 0.01, curve=curve)
def noise(d, curve=4.0, a=0.002): n = rng.uniform(-1, 1, int(SR * d)); return n * env(len(n), a, curve=curve)
def lowpass(x, k):  # simple moving-average low-pass (k = window)
    k = max(1, int(k)); return np.convolve(x, np.ones(k) / k, mode='same')
def mix(*parts):
    n = max(int(off * SR) + len(p) for off, p in parts); out = np.zeros(n)
    for off, p in parts:
        o = int(off * SR); out[o:o + len(p)] += p[: n - o]
    return out
def pad(x, d): return np.concatenate([x, np.zeros(int(d * SR))])
def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    x = np.clip(x, -1, 1); data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

N = lambda m: 440 * 2 ** ((m - 69) / 12)  # midi -> Hz
# --- UI ---
save('UIHover', tone(1900, 0.04, 'sine', curve=12) * 0.6, 0.35)
save('UIClick', mix((0, tone(1100, 0.07, 'tri', curve=10)), (0.012, tone(1650, 0.06, 'sine', curve=12))), 0.6)
save('UIOpen', mix((0, sweep(400, 1200, 0.18)), (0, lowpass(noise(0.2, 6), 8) * 0.4)), 0.55)
save('UIClose', mix((0, sweep(1100, 380, 0.16)), (0, lowpass(noise(0.15, 7), 8) * 0.3)), 0.5)
save('Error', mix((0, tone(180, 0.12, 'square', curve=3)), (0.13, tone(150, 0.16, 'square', curve=3))), 0.45)
save('Coin', mix((0, tone(N(88), 0.12, 'bell', curve=6)), (0.07, tone(N(93), 0.35, 'bell', curve=5))), 0.6)
save('Purchase', mix((0, tone(N(76), 0.1, 'bell')), (0.08, tone(N(81), 0.1, 'bell')), (0.16, tone(N(88), 0.4, 'bell', curve=4))), 0.6)
save('Equip', mix((0, lowpass(noise(0.08, 20), 4)), (0.02, tone(N(79), 0.25, 'bell', curve=7))), 0.6)
# --- progression ---
lv = [N(m) for m in (72, 76, 79, 84, 88)]
save('LevelUp', mix(*[(i * 0.09, tone(f, 0.5, 'bell', curve=4)) for i, f in enumerate(lv)], (0.45, tone(N(91), 0.9, 'bell', curve=3)), (0.45, lowpass(noise(0.9, 3), 2) * 0.15)), 0.7)
# rarity reveals: more notes, higher, longer as tier rises
tiers = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Secret']
for i, name in enumerate(tiers):
    base = 64 + i * 2
    notes = [base, base + 4, base + 7, base + 12, base + 16, base + 19, base + 24][: 2 + i]
    parts = [(k * 0.07, tone(N(m), 0.6 + i * 0.1, 'bell', curve=4)) for k, m in enumerate(notes)]
    if i >= 4: parts.append((len(notes) * 0.07, mix(*[(0, tone(N(m), 1.4, 'bell', curve=2.2)) for m in (notes[-1], notes[-1] - 5, notes[-1] - 12)])))
    if i >= 5: parts.append((0, lowpass(noise(1.6, 1.5), 2) * 0.12))
    if i == 6: parts.append((0.3, mix(*[(k * 0.04, tone(N(96 + (k % 5) * 2), 0.3, 'sine', curve=6)) for k in range(18)]) * 0.5))
    save('Rarity' + name, mix(*parts), 0.75)
save('CardDrop', mix((0, lowpass(noise(0.4, 5), 3) * 0.3), *[(k * 0.05, tone(N(84 + k * 3), 0.4, 'bell', curve=5)) for k in range(6)]), 0.7)
save('RefineSuccess', mix((0, lowpass(noise(0.05, 30), 2)), (0, tone(1800, 0.6, 'bell', curve=5) * 0.7), (0.15, tone(N(88), 0.7, 'bell', curve=3))), 0.7)
save('RefineFail', mix((0, lowpass(noise(0.12, 12), 10)), (0.05, sweep(400, 120, 0.4, 'square', 4) * 0.5)), 0.6)
save('RefineBreak', mix((0, noise(0.6, 6)), (0, sweep(1600, 300, 0.5) * 0.4)), 0.65)
# --- combat ---
save('Hit', mix((0, lowpass(noise(0.12, 25), 6)), (0, tone(140, 0.12, 'sine', curve=14))), 0.6)
save('Crit', mix((0, lowpass(noise(0.15, 18), 4)), (0, tone(110, 0.15, 'sine', curve=10)), (0.02, tone(2400, 0.25, 'bell', curve=8) * 0.5)), 0.7)
save('Slash', mix((0, lowpass(noise(0.18, 10), 2) * np.linspace(0.2, 1, int(SR * 0.18))[::-1])), 0.5)
save('Whoosh', lowpass(noise(0.35, 3), 12) * np.sin(np.linspace(0, np.pi, int(SR * 0.35))), 0.5)
save('MagicCast', mix((0, sweep(300, 1400, 0.4) * 0.5), *[(k * 0.03, tone(N(84 + (k * 5) % 12), 0.25, 'sine', curve=7) * 0.4) for k in range(10)]), 0.55)
save('Heal', mix(*[(k * 0.06, tone(N(m), 0.6, 'bell', curve=4) * 0.6) for k, m in enumerate((79, 83, 86, 91))]), 0.5)
save('MonsterDie', mix((0, sweep(500, 90, 0.3, 'square', 3) * 0.4), (0, lowpass(noise(0.25, 8), 6) * 0.6)), 0.55)
save('BossRoar', mix((0, lowpass(noise(1.4, 1.5), 30) * 1.2), (0, sweep(110, 60, 1.4, 'square', 1.5) * 0.6)), 0.75)
# --- sea / ships ---
boom = lambda d: mix((0, lowpass(noise(d, 3.5), 40) * 1.5), (0, sweep(90, 35, d, 'sine', 3)))
save('Cannon', mix((0, boom(1.1)), (0, lowpass(noise(0.05, 30), 2) * 0.5)), 0.85)
save('Explosion', mix((0, boom(1.6)), (0.05, lowpass(noise(1.2, 3), 6) * 0.5)), 0.85)
save('Splash', mix((0, lowpass(noise(0.9, 3), 9)), (0, lowpass(noise(0.12, 20), 2) * 0.4)), 0.6)
save('ShipHit', mix((0, lowpass(noise(0.3, 9), 20)), (0, tone(95, 0.35, 'sine', curve=6))), 0.7)
save('ShipCreak', mix(*[(k * 0.25, sweep(180 + k * 20, 140, 0.3, 'square', 5) * 0.25) for k in range(3)]), 0.4)
save('Bell', mix((0, tone(N(81), 1.8, 'bell', curve=2)), (0.6, tone(N(81), 1.8, 'bell', curve=2))), 0.6)
# --- ambience (looping) ---
d = 8.0; n = int(SR * d); tt = np.arange(n) / SR
waves = lowpass(rng.uniform(-1, 1, n), 60) * (0.55 + 0.45 * np.sin(2 * np.pi * tt / d * 2) ** 2)
gulls = mix(*[(o, sweep(1500, 1100, 0.25, 'sine', 4) * 0.15) for o in (1.3, 1.6, 5.2)])
amb = waves + np.pad(gulls, (0, n - len(gulls)))[:n]
fade = int(SR * 0.3); amb[:fade] *= np.linspace(0, 1, fade); amb[-fade:] *= np.linspace(1, 0, fade)
save('AmbienceSea', amb, 0.5)
wind = lowpass(rng.uniform(-1, 1, n), 25) * (0.4 + 0.6 * np.sin(2 * np.pi * tt / 4) ** 2)
wind[:fade] *= np.linspace(0, 1, fade); wind[-fade:] *= np.linspace(1, 0, fade)
save('AmbienceWind', wind, 0.45)
# --- music loop: breezy pentatonic sea shanty (16 beats x 2 bars) ---
bpm = 112; beat = 60 / bpm
mel = [67, 69, 72, 74, 76, 74, 72, 69, 67, 72, 74, 76, 79, 76, 74, 72, 74, 76, 74, 72, 69, 67, 69, 72, 74, 72, 69, 67, 64, 67, 69, 67]
bass = [43, 43, 48, 48, 45, 45, 40, 43]
parts = []
for i, m in enumerate(mel): parts.append((i * beat / 2, tone(N(m), beat * 0.9, 'tri', curve=3) * 0.5))
for i, m in enumerate(bass): parts.append((i * beat * 2, tone(N(m), beat * 1.9, 'sine', curve=1.5) * 0.7))
for i in range(32): parts.append((i * beat / 2, lowpass(noise(0.05, 30), 2) * (0.25 if i % 2 == 0 else 0.12)))
music = pad(mix(*parts), 0)[: int(SR * beat * 16)]
save('MusicIsland', music, 0.55)
print('wrote', len(os.listdir(OUT)), 'files to', os.path.abspath(OUT))
# (appended last so the noise of the older sounds stays identical)
# anvil: a few inharmonic metal partials with a hard click on top (the Forge plays three of these)
clang = mix((0, lowpass(noise(0.03, 40), 2) * 0.8), *[(0, tone(f, 0.9, 'sine', a=0.001, curve=c) * g) for f, c, g in ((523, 5, 0.6), (1393, 6, 0.5), (2411, 8, 0.35), (3557, 10, 0.25), (787, 4, 0.3))])
save('AnvilClang', clang, 0.7)
