"""Synthesize the film's soundtrack from scratch: an original music bed plus UI sound effects.

Everything is generated here (no samples), so the output is free to ship with the repo.
Timing is locked to the storyboard in packages/thesis-film/src/render.ts at 30 fps:
112.5 BPM makes one beat exactly 16 frames.

    uv run --with numpy --with scipy audio/make_soundtrack.py
"""
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, fftconvolve, sosfilt

SR = 48000
FPS = 30
TOTAL_FRAMES = 1408
BEAT_F = 16                      # frames per beat (112.5 BPM)
N = int(TOTAL_FRAMES / FPS * SR)
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(7)


def fr(frame: float) -> int:
    return int(round(frame / FPS * SR))


def beat(b: float) -> int:
    return fr(b * BEAT_F)


def lp(x, hz, order=2):
    return sosfilt(butter(order, hz, "low", fs=SR, output="sos"), x)


def hp(x, hz, order=2):
    return sosfilt(butter(order, hz, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def env(n, a, d, s, r, sustain_len=None):
    """ADSR in samples-seconds; sustain_len defaults to fill n."""
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    hold = max(0, n - a - d - r) if sustain_len is None else int(sustain_len * SR)
    e = np.concatenate([np.linspace(0, 1, a, endpoint=False), np.linspace(1, s, d, endpoint=False),
                        np.full(hold, s), np.linspace(s, 0, r)])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def add(buf, sig, at):
    n = buf.shape[-1]
    if at >= n:
        return
    end = min(n, at + sig.shape[-1])
    buf[..., at:end] += sig[..., : end - at]


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def reverb_ir(seconds=2.4, decay=3.2):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.stack([rng.standard_normal(n), rng.standard_normal(n)]) * np.exp(-decay * t)
    ir[:, : int(0.012 * SR)] = 0                      # pre-delay
    ir = lp(ir, 6500)
    return ir / np.abs(ir).sum(axis=1, keepdims=True).max() * 9


IR = reverb_ir()


def wet(x, amount):
    if x.ndim == 1:
        x = np.stack([x, x])
    y = np.stack([fftconvolve(x[i], IR[i])[: x.shape[1]] for i in range(2)])
    return x + amount * y


def pan(x, p):
    """p in [-1, 1]."""
    return np.stack([x * np.sqrt((1 - p) / 2), x * np.sqrt((1 + p) / 2)])


# ---------------------------------------------------------------- harmony
# Fmaj9 – Am7 – Dm9 – Bbmaj7(#11), one bar each, warm and unresolved; resolves to F at the outro.
CHORDS = [
    [53, 57, 60, 64, 67],   # Fmaj9 (F A C E G)
    [57, 60, 64, 67, 71],   # Am7(9)
    [50, 57, 60, 64, 65],   # Dm9
    [46, 53, 57, 62, 64],   # Bbmaj7#11-ish
]
ROOTS = [41, 45, 38, 46]
BARS = TOTAL_FRAMES // (BEAT_F * 4) + 1      # 22 bars + spare
DROP_BEAT = 9                                # product section starts ≈ frame 144 (cut is 140)
OUTRO_BEAT = 80                              # frame 1280 (outro starts 1276)
END_BEAT = TOTAL_FRAMES / BEAT_F             # 88


def chord_at(b):
    return CHORDS[int(b // 4) % 4], ROOTS[int(b // 4) % 4]


# ---------------------------------------------------------------- instruments
def pad_note(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * f * (1 + det) * t + rng.uniform(0, 6.28)) for det in (-0.004, 0, 0.0035))
    x += 0.35 * sum(np.sin(2 * np.pi * 2 * f * (1 + det) * t) for det in (-0.003, 0.003))
    return lp(x, 2200) * env(n, 0.6, 0.4, 0.8, 0.9)


def pluck(f, dur=0.9, bright=4200):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 9) \
        + 0.18 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 14)
    x = lp(x, bright) * np.exp(-t * 4.2) * np.minimum(1, t / 0.003)
    return x


def epiano(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * t) * 1.4 * np.exp(-t * 4) + np.sin(2 * np.pi * f * 14 * t) * 0.22 * np.exp(-t * 22)
    x = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 1.6)
    x += 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 3)
    return x * env(n, 0.004, 0.2, 0.7, 0.35) * (1 + 0.04 * np.sin(2 * np.pi * 5 * t))


def sub(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * 2 * f * t)
    return x * env(n, 0.01, 0.1, 0.85, 0.12)


def kick():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 46 + 110 * np.exp(-t * 32)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7.5)
    x += 0.25 * lp(rng.standard_normal(n), 3000) * np.exp(-t * 180)
    return np.tanh(1.4 * x)


def clap():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    noise = bp(rng.standard_normal(n), 900, 5200)
    e = np.zeros(n)
    for k, o in enumerate((0, 0.009, 0.019)):
        i = int(o * SR)
        e[i:] += np.exp(-(t[: n - i]) * (60 if k < 2 else 16)) * (0.7 if k < 2 else 1)
    return noise * e * 0.6


def hat(open_=False):
    n = int((0.22 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    return hp(rng.standard_normal(n), 7500) * np.exp(-t * (18 if open_ else 70)) * 0.5


def shaker():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    return bp(rng.standard_normal(n), 5000, 11000) * np.sin(np.pi * t / t[-1]) ** 2 * 0.35


# ---------------------------------------------------------------- music bed
music = np.zeros((2, N))
pads = np.zeros(N)
keys = np.zeros((2, N))
arp = np.zeros((2, N))
bass = np.zeros(N)
drums = np.zeros((2, N))
duck = np.ones(N)            # sidechain envelope from kicks

beat_s = BEAT_F / FPS
for bar in range(BARS):
    b0 = bar * 4
    if b0 >= END_BEAT:
        break
    notes, root = chord_at(b0)
    final = b0 >= OUTRO_BEAT
    if final:
        notes, root = [53, 57, 60, 64, 69], 41       # F add9 home
    dur = beat_s * (8 if final else 4) + 0.6
    for m in notes:
        add(pads, pad_note(hz(m), dur) * 0.032, beat(b0))
    if final:
        # one sustained piano voicing to land on, then stop writing bars
        for i, m in enumerate([41, 53, 60, 64, 67, 72]):
            add(keys, pan(epiano(hz(m), 4.2) * 0.12, -0.2 + 0.08 * i), beat(b0) + int(i * 0.018 * SR))
        break
    # electric piano: chord stabs on 1 and the "and" of 2
    if b0 >= DROP_BEAT - 1:
        for off, vel in ((0, 0.11), (1.5, 0.07), (3, 0.05)):
            for i, m in enumerate(notes[1:]):
                add(keys, pan(epiano(hz(m), beat_s * 1.4) * vel, -0.3 + 0.2 * i), beat(b0 + off) + int(i * 0.006 * SR))
    # 16th-note pluck arpeggio, enters with the product section
    if b0 >= DROP_BEAT - 1:
        seq = [notes[1] + 12, notes[3], notes[2] + 12, notes[4], notes[1] + 12, notes[3] + 12, notes[2], notes[4]]
        for s in range(16):
            b = b0 + s * 0.5
            if b < DROP_BEAT - 1:
                continue
            m = seq[s % 8]
            vel = 0.12 if s % 2 == 0 else 0.08
            add(arp, pan(pluck(hz(m), 0.5) * vel, 0.45 if s % 2 else -0.45), beat(b))
    # sub bass: root on 1, octave pickup on 4+
    if b0 >= DROP_BEAT - 1:
        add(bass, sub(hz(root), beat_s * 2.6) * 0.26, beat(b0))
        add(bass, sub(hz(root), beat_s * 0.9) * 0.24, beat(b0 + 3))
        add(bass, sub(hz(root + 12), beat_s * 0.45) * 0.16, beat(b0 + 3.5))

# hook: sparse piano motif over the pad (one note per character beat), sets up the question
for b, m in ((0, 72), (1.5, 69), (3, 67), (4, 65), (5.5, 64), (7, 60)):
    add(keys, pan(epiano(hz(m), 1.6) * 0.09, 0.15), beat(b))

# drums from the drop to the outro
for b in np.arange(DROP_BEAT - 1, OUTRO_BEAT, 0.5):
    i = beat(b)
    whole = abs(b - round(b)) < 1e-6
    if whole and int(b) % 2 == 0:
        add(drums, pan(kick() * 0.5, 0), i)
        e = np.ones(int(0.32 * SR))
        e[: int(0.3 * SR)] = 1 - 0.55 * np.exp(-np.linspace(0, 1, int(0.3 * SR)) * 5)
        duck[i: i + len(e)] = np.minimum(duck[i: i + len(e)], e[: max(0, min(len(e), N - i))])
    if whole and int(b) % 2 == 1 and b >= DROP_BEAT + 7:
        add(drums, pan(clap() * 0.32, 0.05), i)
    if not whole:
        add(drums, pan(hat(open_=(int(b) % 4 == 3)) * 0.16, 0.25), i)
    add(drums, pan(shaker() * 0.18, -0.35), i + beat(0.25) - beat(0))

# build: rising filtered noise into the drop and into the outro
for target in (DROP_BEAT - 1, OUTRO_BEAT):
    n = beat(4) - beat(0)
    t = np.linspace(0, 1, n)
    x = bp(rng.standard_normal(n), 1500, 9000) * t ** 2.5 * 0.08
    add(drums, pan(x, 0), beat(target - 4))

stereo_pad = wet(pan(pads, 0) * duck, 0.55)
mix = stereo_pad + wet(keys, 0.35) + wet(arp * duck, 0.3) + pan(lp(bass, 220) * duck, 0) + wet(drums, 0.08)
# gentle master fade at the very end
fade = np.ones(N)
fn = fr(26)
fade[-fn:] = np.linspace(1, 0, fn) ** 1.5
mix *= fade
music = mix

# ---------------------------------------------------------------- sound effects
fx = np.zeros((2, N))


def whoosh(dur=0.42, lo=500, hi=6000, gain=0.22, direction=-1):
    """Card push: filtered noise sweep, panned in the direction of travel."""
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    x = rng.standard_normal(n)
    out = np.zeros(n)
    steps = 24
    for k in range(steps):
        a, b = k * n // steps, (k + 1) * n // steps
        c = lo * (hi / lo) ** (k / steps)
        out[a:b] = bp(x, c * 0.7, min(c * 1.4, 20000))[a:b]
    e = np.sin(np.pi * t) ** 1.8
    x = out * e * gain
    return np.stack([x * (0.5 - 0.35 * direction * (t - 0.5) * 2 / 2 + 0.25), x * (0.5 + 0.35 * direction * (t - 0.5) * 2 / 2 + 0.25)])


def tick(f=2600, gain=0.12):
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t) * np.exp(-t * 120) * gain


def chime(notes=(84, 88, 91), gain=0.08):
    n = int(1.6 * SR)
    out = np.zeros(n)
    for i, m in enumerate(notes):
        t = np.arange(n) / SR
        s = np.sin(2 * np.pi * hz(m) * t) * np.exp(-t * 3) + 0.3 * np.sin(2 * np.pi * hz(m) * 2.01 * t) * np.exp(-t * 6)
        o = int(i * 0.06 * SR)
        out[o:] += s[: n - o]
    return out * gain


def zoom(gain=0.1):
    """Camera punch-in: short rising tone + air."""
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f = 380 + 900 * (t / t[-1]) ** 2
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / t[-1]) * 0.6
    x += hp(rng.standard_normal(n), 4000) * np.sin(np.pi * t / t[-1]) ** 2 * 0.25
    return x * gain


# beat starts (frames), computed exactly as render.ts lays them out
HOOK = 140
BEAT_DURS = {"home": 120, "chat": 166, "profile": 152, "order": 144, "watch": 170, "banner": 96, "review": 174, "theses": 114}
TRANS = {"home": "rise", "chat": "push", "profile": "fade", "order": "fade", "watch": "push", "banner": "push", "review": "push", "theses": "push"}
PUNCH = {"chat": [70], "profile": [104], "order": [8, 40], "watch": [28], "banner": [36], "review": [8, 108], "theses": [26]}
starts, c = {}, HOOK
for k, d in BEAT_DURS.items():
    starts[k] = c
    c += d

add(fx, whoosh(0.6, 300, 4000, 0.16, direction=0), fr(HOOK - 10))          # hook lifts away, phone rises
for k, s in starts.items():
    if TRANS[k] == "push":
        add(fx, whoosh(), fr(s - 3))
    elif TRANS[k] == "fade":
        add(fx, whoosh(0.5, 900, 3000, 0.08, direction=0), fr(s - 4))
    for p in PUNCH.get(k, []):
        add(fx, pan(zoom(), 0), fr(s + p))
# step-rail dot pops when the step changes, the ring on the probability line, captions' key word ticks
for k in ("chat", "profile", "watch", "banner"):
    add(fx, pan(tick(2400, 0.07), 0.4), fr(starts[k] + 6))
add(fx, pan(chime((79, 84, 88), 0.07), 0.1), fr(starts["chat"] + 90))       # ring around "your edge vs market"
add(fx, pan(tick(1800, 0.12) + tick(3600, 0.05), 0), fr(starts["order"] + 60))   # long-press fill
add(fx, pan(chime((88, 91, 96), 0.06), -0.1), fr(starts["watch"] + 44))     # invalidation alert banner
add(fx, pan(chime((76, 81, 84, 88), 0.08), 0), fr(TOTAL_FRAMES - 132 + 10))  # outro mark
fx = wet(fx, 0.25)

# ---------------------------------------------------------------- write
OUT.mkdir(parents=True, exist_ok=True)


def write(name, x, peak=0.89):
    x = x / max(1e-9, np.abs(x).max()) * peak
    wavfile.write(OUT / name, SR, (x.T * 32767).astype(np.int16))
    print(name, f"{x.shape[1] / SR:.2f}s")


m_peak = np.abs(music).max()
write("music.wav", music, 0.80)
write("sfx.wav", fx * (0.80 / m_peak), peak=float(np.abs(fx).max() * (0.80 / m_peak)))
