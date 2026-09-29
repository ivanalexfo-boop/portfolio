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


def highpass(sig: np.ndarray, cutoff: float) -> np.ndarray:
    return sig - lowpass(sig, cutoff)


def sweep_filter(sig: np.ndarray, f0: float, f1: float) -> np.ndarray:
    """Фильтр, который открывается от f0 до f1 — основа «вжуха»."""
    cut = f0 * (f1 / f0) ** np.linspace(0, 1, len(sig))
    a = np.exp(-2 * np.pi * cut / SR)
    out = np.empty_like(sig)
    y = 0.0
    for i, v in enumerate(sig):
        y = (1 - a[i]) * v + a[i] * y
        out[i] = y
    return out


def click(dur: float, body: float, ping: float, snap: float = 0.6) -> np.ndarray:
    """Сухой пластиковый щелчок: шумовой удар + короткий звон + «тело»."""
    x = t(dur)
    n = len(x)
    burst = highpass(rng.standard_normal(n), 1800) * env(n, 0.0003, 0.0025) * snap
    ring = np.sin(2 * np.pi * ping * x) * env(n, 0.0005, 0.007) * 0.8
    thump = np.sin(2 * np.pi * body * x) * env(n, 0.0008, 0.011)
    return burst + ring + thump


def clink(freq: float, decay: float) -> np.ndarray:
    """Звон монеты: негармоничные обертоны, быстро гаснут."""
    x = t(decay * 6)
    out = np.zeros_like(x)
    for mult, amp in ((1.0, 1.0), (1.52, 0.7), (2.34, 0.45), (3.1, 0.3)):
        out += amp * np.sin(2 * np.pi * freq * mult * x + rng.uniform(0, 6.28)) * env(len(x), 0.0004, decay / mult**0.5)
    return out


def whoosh(dur: float, f0: float, f1: float) -> np.ndarray:
    x = t(dur)
    shape = np.clip(x / dur, 0, 1) ** 1.6
    return sweep_filter(rng.standard_normal(len(x)), f0, f1) * shape


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


# тик ленты, как в рулетке кейсов: сухой пластиковый щелчок на каждом предмете
save("snd_tick", finish(lowpass(click(0.045, 720, 2600), 9000), 0.6))

# продажа — звон нескольких монет
coin = mix(0.55, [(k * 0.045 + rng.uniform(0, 0.02), clink(rng.uniform(2300, 3400), rng.uniform(0.05, 0.09)), rng.uniform(0.5, 1.0)) for k in range(6)])
save("snd_coin", finish(reverb(lowpass(coin, 9000), 0.15), 0.6))

# выигрыш — мажорное арпеджио до-ми-соль-до
win = mix(1.4, [(i * 0.075, bell(note(n), 1.2, 0.45), g) for i, (n, g) in enumerate((("C5", 0.8), ("E5", 0.8), ("G5", 0.85), ("C6", 1.0)))])
save("snd_win", finish(reverb(lowpass(win, 6500)), 0.7))

# редкий дроп: нарастающий «вжух» → удар → яркий аккорд с блёстками
x = t(0.5)
boom = np.sin(2 * np.pi * (55 + 40 * np.exp(-x / 0.05)) * x) * env(len(x), 0.002, 0.18)
hit = lowpass(rng.standard_normal(len(x)), 3000) * env(len(x), 0.001, 0.03)
chord = [(0.32, bell(note(n), 1.6, 0.6, 1.4), 0.55) for n in ("C6", "E6", "G6", "C7")]
sparkles = [(0.36 + 0.07 * k + rng.uniform(0, 0.03), bell(rng.choice([note("E7"), note("G7"), note("C8")]), 0.3, 0.07, 0.3), 0.2) for k in range(12)]
big = mix(2.0, [(0.0, whoosh(0.34, 400, 6000), 0.35), (0.32, boom, 0.9), (0.32, hit, 0.5)] + chord + sparkles)
save("snd_win_big", finish(reverb(big, 0.28), 0.75))

# дешёвый дроп: короткий глухой «тук» и тихий блип вниз
x = t(0.3)
thud = np.sin(2 * np.pi * (110 + 70 * np.exp(-x / 0.03)) * x) * env(len(x), 0.001, 0.07)
blip = soft(note("A4"), 0.25, 0.06) * np.exp(-t(0.25) / 0.2)
blip2 = soft(note("E4"), 0.35, 0.09)
lose = mix(0.6, [(0.0, thud, 1.0), (0.0, lowpass(rng.standard_normal(len(x)), 1500) * env(len(x), 0.001, 0.012), 0.4), (0.07, blip, 0.35), (0.15, blip2, 0.4)])
save("snd_lose", finish(reverb(lowpass(lose, 3000), 0.12), 0.55))

# открытие кейса: щелчок-щелчок замка → нарастающий «вжух» в раскрутку
latch1 = click(0.06, 380, 1500, 0.8)
latch2 = click(0.08, 300, 1200, 0.9)
x = t(0.55)
riser = np.sin(2 * np.pi * np.cumsum(200 * 3 ** (x / 0.55)) / SR) * np.clip(x / 0.55, 0, 1) ** 2 * 0.25
opening = mix(0.8, [(0.0, latch1, 0.9), (0.08, latch2, 1.0), (0.12, whoosh(0.55, 300, 4500), 0.45), (0.12, riser, 1.0)])
save("snd_open", finish(reverb(lowpass(opening, 9000), 0.12), 0.6))
