"""Synthesize the two call tones as mono 16-bit PCM WAV. Standard library only.

call_ringtone.wav  the callee's ring: a soft four-note chime, then a pause.
                   Plays on a loop until the call is answered, declined or
                   ends — the server ends an unanswered ring after 45 s.
call_ringback.wav  what the caller hears while it rings: the classic
                   440 + 480 Hz ringback, one burst then silence.

Each file is exactly one loop period, so `LoopMode.one` repeats it on the
beat. Re-run after changing anything here; the output is deterministic.
"""

import math
import struct
import wave
from pathlib import Path

DEST = Path(__file__).resolve().parents[1] / 'assets' / 'sounds'


def write(name, rate, samples, gain):
    DEST.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(str(DEST / name), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(b''.join(struct.pack('<h', int(s / peak * gain * 32767)) for s in samples))


def ringtone():
    rate = 22050
    period = 2.6
    # E5 G5 B5 G5 — a bright, unhurried arpeggio that reads as "incoming".
    notes = [(0.00, 659.25), (0.16, 783.99), (0.32, 987.77), (0.48, 783.99)]
    samples = [0.0] * int(rate * period)
    for start, freq in notes:
        begin = int(start * rate)
        for i in range(int(rate * 0.9)):
            if begin + i >= len(samples):
                break
            t = i / rate
            # A struck-bell envelope: instant attack, exponential decay, with a
            # little of the octave and twelfth so it isn't a bare sine.
            env = math.exp(-t * 5.5) * min(1.0, t * 400)
            tone = math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(4 * math.pi * freq * t)
            tone += 0.12 * math.sin(6 * math.pi * freq * t)
            samples[begin + i] += env * tone
    write('call_ringtone.wav', rate, samples, gain=0.8)


def ringback():
    rate = 8000
    period = 4.0
    burst = 1.5
    samples = []
    for i in range(int(rate * period)):
        t = i / rate
        if t >= burst:
            samples.append(0.0)
            continue
        # 20 ms ramps on both edges so the burst does not click.
        env = min(1.0, t / 0.02, (burst - t) / 0.02)
        samples.append(env * (math.sin(2 * math.pi * 440 * t) + math.sin(2 * math.pi * 480 * t)))
    # Quieter than the ringtone: the caller is holding the phone to their ear.
    write('call_ringback.wav', rate, samples, gain=0.4)


if __name__ == '__main__':
    ringtone()
    ringback()
