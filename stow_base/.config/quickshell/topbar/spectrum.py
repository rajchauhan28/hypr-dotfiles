#!/usr/bin/env python3
"""System-audio spectrum for the Media tab's visualiser.

    spectrum.py [bands] [fps]

Prints one JSON array per frame -- integers 0..100, low frequency first -- to
stdout, line-buffered, for a Quickshell SplitParser to read.

It taps the default sink's *monitor* rather than any one player, so it reacts to
whatever is actually audible: Spotify, a YouTube tab, a game. Same approach as
walllust's src/daemon/audio.rs (Hann window, log-spaced bands, auto-gain), but
kept out-of-process so a stall can never block the panel's event loop.
"""
import json
import os
import shutil
import signal
import subprocess
import sys

import numpy as np

RATE = 44100
FFT = 2048          # ~46ms window: enough bass resolution without smearing beats


def default_monitor():
    """The monitor source of the current default sink, or a sensible fallback."""
    try:
        sink = subprocess.run(["pactl", "get-default-sink"],
                              capture_output=True, text=True, timeout=4).stdout.strip()
        if sink:
            return sink + ".monitor"
    except (OSError, subprocess.SubprocessError):
        pass
    return "@DEFAULT_MONITOR@"


def band_edges(bands):
    """Log-spaced FFT bin edges from ~40Hz to ~16kHz.

    Linear bins would give the bottom two bars every instrument and leave the
    rest flat, because pitch is logarithmic.
    """
    lo, hi = 40.0, 16000.0
    freqs = lo * (hi / lo) ** (np.arange(bands + 1) / bands)
    edges = (freqs / (RATE / 2.0) * (FFT // 2)).astype(int)
    # Guarantee every band owns at least one bin, even at high band counts.
    for i in range(1, len(edges)):
        edges[i] = max(edges[i], edges[i - 1] + 1)
    return np.clip(edges, 1, FFT // 2 - 1)


def main():
    bands = int(sys.argv[1]) if len(sys.argv) > 1 else 28
    fps = int(sys.argv[2]) if len(sys.argv) > 2 else 40

    if shutil.which("parec") is None:
        print(json.dumps([0] * bands), flush=True)
        return 1

    hop = max(256, RATE // fps)
    edges = band_edges(bands)
    window = np.hanning(FFT).astype(np.float32)
    ring = np.zeros(FFT, dtype=np.float32)

    smooth = np.zeros(bands, dtype=np.float32)
    # Auto-gain: a slowly decaying peak so quiet tracks still fill the bars and
    # a loud transient doesn't permanently flatten everything after it.
    ceiling = 1e-6

    proc = subprocess.Popen(
        ["parec", "--format=s16le", f"--rate={RATE}", "--channels=1",
         "--latency-msec=30", "-d", default_monitor()],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    # Die with the panel rather than lingering as an orphan holding the monitor.
    signal.signal(signal.SIGTERM, lambda *_: (proc.kill(), sys.exit(0)))

    nbytes = hop * 2
    try:
        while True:
            raw = proc.stdout.read(nbytes)
            if not raw or len(raw) < nbytes:
                break

            chunk = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
            ring = np.concatenate((ring[len(chunk):], chunk))

            spec = np.abs(np.fft.rfft(ring * window))
            vals = np.array([spec[edges[i]:edges[i + 1]].mean()
                             for i in range(bands)], dtype=np.float32)
            # Perceptual: loudness is logarithmic, and a linear bar chart of raw
            # magnitudes looks dead except on kick drums.
            vals = np.log1p(vals * 12.0)

            peak = float(vals.max())
            ceiling = max(peak, ceiling * 0.995)
            norm = vals / max(ceiling, 1e-6)

            # Asymmetric smoothing: snap up on transients, fall away gently, so
            # bars feel percussive instead of mushy.
            rising = norm > smooth
            smooth = np.where(rising,
                              smooth + (norm - smooth) * 0.55,
                              smooth + (norm - smooth) * 0.18)

            out = np.clip(smooth * 100.0, 0, 100).astype(int)
            print(json.dumps(out.tolist()), flush=True)
    except (BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        proc.kill()
    return 0


if __name__ == "__main__":
    sys.exit(main())
