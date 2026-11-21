"""Three music states for the relay, synthesised once and written to disk.

calm  — the room waiting: a low pad, a projector tick, one motif every four bars
tense — a ghost close by: the same motif over an eighth-note bass pulse
halt  — the take is over: the pad falls, the tape slows down

Deterministic: fixed seeds, fixed tempo, so a rebuild sounds the same. Mono,
44.1 kHz, 16-bit; loops are rendered with their tails folded back into the head
so they repeat without a click.
"""
import os
import numpy as np
from scipy.io import wavfile

SR = 44100
OUT = r"C:\Users\11ee11\Documents\deepseek-harness\default-workspace\roll-cut-die\assets\audio"
BPM = 72.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
# D minor, the four notes the whole score is made of.
MOTIF = [146.83, 174.61, 220.00, 261.63]  # D3 F3 A3 C4


def env(n, attack, decay, amp=1.0):
    a = max(1, int(attack * SR))
    d = max(1, n - a)
    e = np.concatenate([np.linspace(0, 1, a) ** 1.5, np.exp(-np.arange(d) / (decay * SR))])
    return e[:n] * amp


def tone(freq, dur, detune=0.0, decay=0.6, amp=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + detune)
    sig = np.sin(2 * np.pi * f * t) * 0.6
    sig += np.sin(2 * np.pi * f * 2.0 * t) * 0.18
    sig += np.sin(2 * np.pi * f * 3.01 * t) * 0.08
    return sig * env(n, 0.02, decay, amp)


def add(buf, sig, at):
    i = int(at * SR) % buf.size
    n = sig.size
    if i + n <= buf.size:
        buf[i:i + n] += sig
    else:
        head = buf.size - i
        buf[i:] += sig[:head]
        buf[: n - head] += sig[head:]


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.size):
        acc = a * acc + (1 - a) * x[i]
        y[i] = acc
    return y


def reverb(x, mix=0.22, taps=((0.031, 0.5), (0.073, 0.32), (0.121, 0.2))):
    out = x.copy()
    for delay, gain in taps:
        d = int(delay * SR)
        y = np.concatenate([np.zeros(d), x[:-d]]) * gain
        out += y
    return out / (1.0 + mix * 3)


def pad(dur, amp=0.16):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for f, a in ((73.42, 0.5), (110.00, 0.28), (146.83, 0.22)):
        sig += a * np.sin(2 * np.pi * f * t + np.sin(2 * np.pi * 0.07 * t))
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * 0.05 * t)
    return sig * lfo * amp


def projector_tick(amp=0.10):
    n = int(0.045 * SR)
    rng = np.random.default_rng(3)
    noise = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.006 * SR))
    click = np.sin(2 * np.pi * 180.0 * np.arange(n) / SR) * np.exp(-np.arange(n) / (0.02 * SR))
    return (noise * 0.6 + click * 0.4) * amp


def bars(n):
    return n * BAR


def calm():
    length = bars(4)
    buf = np.zeros(int(length * SR))
    buf += pad(length, 0.15)
    # Motif once per four bars, each note left to ring.
    for i, f in enumerate(MOTIF):
        add(buf, tone(f, 2.4, detune=0.0009 * i, decay=1.1, amp=0.16), i * BEAT)
        add(buf, tone(f, 2.4, detune=-0.0007 * i, decay=1.1, amp=0.10), i * BEAT + 0.012)
    # Projector ticks: one per bar, slightly late, like a real machine.
    for b in range(4):
        add(buf, projector_tick(0.085), b * BAR + 0.11)
    buf = lowpass(buf, 5200)
    buf = reverb(buf, 0.24)
    return buf


def tense():
    length = bars(4)
    buf = np.zeros(int(length * SR))
    buf += pad(length, 0.12)
    # Eighth-note bass pulse on D, the clock you can feel.
    for step in range(4 * 8):
        at = step * BEAT * 0.5
        f = 55.0 if step % 4 else 41.2
        add(buf, tone(f, 0.34, decay=0.12, amp=0.30), at)
    # The same motif, but twice and shorter: it is running out of time.
    for rep in range(2):
        for i, f in enumerate(MOTIF):
            at = rep * bars(2) + i * BEAT * 0.5
            add(buf, tone(f, 1.0, detune=0.001 * i, decay=0.42, amp=0.13), at)
    for b in range(8):
        add(buf, projector_tick(0.06), b * BEAT * 0.5)
    buf = lowpass(buf, 4600)
    buf = reverb(buf, 0.18)
    return buf


def halt():
    length = 5.0
    n = int(length * SR)
    buf = np.zeros(n)
    t = np.arange(n) / SR
    # A pad that falls in pitch, like a tape losing its capstan.
    glide = 73.42 * (1.0 - 0.34 * (t / length) ** 1.4)
    phase = 2 * np.pi * np.cumsum(glide) / SR
    buf += np.sin(phase) * np.exp(-t / 1.6) * 0.22
    buf += np.sin(phase * 2.0) * np.exp(-t / 0.9) * 0.08
    add(buf, projector_tick(0.09), 0.02)
    buf = lowpass(buf, 3800)
    return buf


def write(name, sig, peak=0.72):
    sig = sig / max(1e-9, np.abs(sig).max()) * peak
    pcm = np.clip(sig, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype(np.int16)
    path = os.path.join(OUT, name)
    wavfile.write(path, SR, pcm)
    print(name, round(len(pcm) / SR, 2), "s", os.path.getsize(path), "bytes")


def main():
    os.makedirs(OUT, exist_ok=True)
    write("bed_calm.wav", calm())
    write("bed_tense.wav", tense())
    write("bed_halt.wav", halt(), 0.62)


if __name__ == "__main__":
    main()
