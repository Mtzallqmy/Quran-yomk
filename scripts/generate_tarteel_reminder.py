#!/usr/bin/env python3
"""Reproduce Tarteel's original offline notification chime (CC0-1.0).

No samples or voice recordings are used. This script and its generated audio
are dedicated to the public domain under CC0 1.0:
https://creativecommons.org/publicdomain/zero/1.0/
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'apps/mobile/assets/audio/reminder.wav'
MANIFEST = ROOT / 'apps/mobile/assets/audio/manifest.json'
SAMPLE_RATE = 22050
DURATION = 1.25


def render() -> bytes:
    samples = []
    for sample in range(int(SAMPLE_RATE * DURATION)):
        time = sample / SAMPLE_RATE
        value = 0.0
        for start, frequency in [(0, 659.255), (0.27, 783.991)]:
            elapsed = time - start
            if elapsed >= 0:
                value += (0.22 * min(elapsed / 0.012, 1)
                          * math.exp(-5.5 * elapsed)
                          * math.sin(2 * math.pi * frequency * elapsed))
        value *= min((DURATION - time) / 0.05, 1)
        samples.append(struct.pack('<h', int(max(-1, min(1, value)) * 32767)))
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(b''.join(samples))
    return buffer.getvalue()


def generate(target: Path = TARGET) -> None:
    target.write_bytes(render())


def check() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    for asset in manifest['assets']:
        path = ROOT / 'apps/mobile' / asset['path']
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != asset['sha256']:
            raise ValueError(f"Audio checksum mismatch: {asset['path']}")
    if TARGET.read_bytes() != render():
        raise ValueError('Bundled reminder differs from its reproducible generator')
    native_adhan = ROOT / 'apps/mobile/android/app/src/main/res/raw/adhan.ogg'
    bundled_adhan = ROOT / 'apps/mobile/assets/audio/adhan.ogg'
    if native_adhan.read_bytes() != bundled_adhan.read_bytes():
        raise ValueError('Android and Flutter bundled adhan assets differ')
    print('Audio checksums, reproducible reminder, and Android adhan copy verified.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true',
                        help='Verify all bundled audio without modifying files')
    arguments = parser.parse_args()
    try:
        check() if arguments.check else generate()
    except (OSError, KeyError, ValueError) as error:
        parser.exit(1, f'Audio validation failed: {error}\n')
