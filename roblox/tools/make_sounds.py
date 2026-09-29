"""Генератор мягких звуков для Roblox-версии «Битвы Аур».

Запуск: python roblox/tools/make_sounds.py
Пишет WAV-файлы в roblox/assets (snd_tap.mp3 — звук кликера — не трогает).
После генерации файлы загружаются в Roblox вручную, а id вписываются в Config.SOUNDS.
"""
from pathlib import Path
import wave

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets"
rng = np.random.default_rng(7)


def note(name: str) -> float:
    names = {"C": -9, "C#": -8, "D": -7, "Eb": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "Ab": -1, "A": 0, "Bb": 1, "B": 2}
    return 440.0 * 2 ** ((names[name[:-1]] + 12 * (int(name[-1]) - 4)) / 12)


def t(sec: float) -> np.ndarray:
    return np.arange(int(sec * SR)) / SR


def env(n: int, attack: float, decay: float) -> np.ndarray:
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)


def bell(freq: float, dur: float, decay: float, bright: float = 1.0) -> np.ndarray:
    """Мягкий колокольчик: основной тон + приглушённые обертоны, высокие гаснут быстрее."""
    x = t(dur)
    out = np.zeros_like(x)
    for mult, amp, dmul in ((1.0, 1.0, 1.0), (2.0, 0.28 * bright, 0.55), (3.0, 0.1 * bright, 0.35), (4.16, 0.05 * bright, 0.25)):
        out += amp * np.sin(2 * np.pi * freq * mult * x) * env(len(x), 0.004, decay * dmul)
    return out


def soft(freq: float, dur: float, decay: float) -> np.ndarray:
    """Тёплый тон без звона (для проигрыша)."""
    x = t(dur)
    s = np.sin(2 * np.pi * freq * x) + 0.18 * np.sin(2 * np.pi * freq * 2 * x)
    return s * env(len(x), 0.02, decay)


def mix(total: float, parts) -> np.ndarray:
    out = np.zeros(int(total * SR))
    for start, sig, gain in parts:
        i = int(start * SR)
        seg = sig[: max(0, len(out) - i)]
        out[i : i + len(seg)] += gain * seg
    return out


def reverb(sig: np.ndarray, wet: float = 0.22) -> np.ndarray:
    """Лёгкое «помещение»: несколько затухающих задержек, без металлического звона."""
    out = sig.copy()
    for ms, g in ((29, 0.5), (41, 0.42), (53, 0.36), (71, 0.3), (97, 0.22), (131, 0.15)):
        d = int(SR * ms / 1000)
        tail = np.zeros_like(sig)
        tail[d:] = sig[:-d] * g
        out += wet * tail
    return out


def lowpass(sig: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.empty_like(sig)
    y = 0.0
    for i, v in enumerate(sig):
        y = (1 - a) * v + a * y
        out[i] = y
    return out


def finish(sig: np.ndarray, peak: float = 0.7) -> np.ndarray:
    fade = min(len(sig), int(0.03 * SR))
    sig = sig.copy()
    sig[-fade:] *= np.linspace(1, 0, fade)
    sig[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return sig / np.max(np.abs(sig)) * peak


def save(name: str, sig: np.ndarray) -> None:
    data = (np.clip(sig, -1, 1) * 32767).astype("<i2")
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{path.name}: {len(sig) / SR:.2f} c")


# тик прокрутки — короткий мягкий «тук», как маримба, без щелчка
x = t(0.07)
tick = (np.sin(2 * np.pi * 1050 * x) + 0.25 * np.sin(2 * np.pi * 2100 * x)) * env(len(x), 0.0015, 0.014)
save("snd_tick", finish(lowpass(tick, 5000), 0.55))

# монеты — два светлых колокольчика вверх
coin = mix(0.6, [(0.0, bell(note("B5"), 0.5, 0.12), 0.8), (0.075, bell(note("E6"), 0.5, 0.2), 1.0)])
save("snd_coin", finish(reverb(lowpass(coin, 7000), 0.18), 0.6))

# выигрыш — мажорное арпеджио до-ми-соль-до
win = mix(1.4, [(i * 0.075, bell(note(n), 1.2, 0.45), g) for i, (n, g) in enumerate((("C5", 0.8), ("E5", 0.8), ("G5", 0.85), ("C6", 1.0)))])
save("snd_win", finish(reverb(lowpass(win, 6500)), 0.7))

# большой выигрыш — арпеджио на две октавы + мерцающий аккорд + искорки
arp = [(i * 0.06, bell(note(n), 1.6, 0.5), 0.75) for i, n in enumerate(("C5", "E5", "G5", "C6", "E6", "G6", "C7"))]
x = t(1.7)
pad = sum(np.sin(2 * np.pi * note(n) * x * (1 + 0.003 * np.sin(2 * np.pi * 5 * x))) for n in ("C4", "E4", "G4", "C5"))
pad *= np.clip(x / 0.25, 0, 1) * np.exp(-x / 0.7)
sparkles = [(0.45 + 0.09 * k + rng.uniform(0, 0.04), bell(rng.choice([note("C7"), note("E7"), note("G7")]), 0.4, 0.1, 0.3), 0.25) for k in range(10)]
big = mix(2.3, arp + [(0.4, pad, 0.22)] + sparkles)
save("snd_win_big", finish(reverb(lowpass(big, 7500), 0.28), 0.72))

# проигрыш — два тёплых тона вниз, тихо и без «грустного тромбона»
lose = mix(1.0, [(0.0, soft(note("E4"), 0.6, 0.22), 0.9), (0.16, soft(note("C4"), 0.8, 0.32), 1.0)])
save("snd_lose", finish(reverb(lowpass(lose, 2200), 0.15), 0.5))

# открытие разлома — мягкий восходящий шелест с мерцанием
x = t(0.9)
freq = 300 * (4 ** (x / 0.9))
phase = 2 * np.pi * np.cumsum(freq) / SR
shape = np.sin(np.pi * np.clip(x / 0.9, 0, 1)) ** 1.5
sweep = (np.sin(phase) + 0.3 * np.sin(2 * phase)) * shape * (0.8 + 0.2 * np.sin(2 * np.pi * 14 * x))
noise = lowpass(lowpass(rng.standard_normal(len(x)), 1100), 1100) * shape
opening = mix(1.1, [(0.0, sweep, 0.5), (0.0, noise / np.max(np.abs(noise)), 0.35), (0.78, bell(note("G6"), 0.3, 0.1, 0.4), 0.25)])
save("snd_open", finish(reverb(lowpass(lowpass(opening, 4000), 4000), 0.2), 0.5))
