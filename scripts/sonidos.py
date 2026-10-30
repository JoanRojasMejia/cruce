"""Sintetiza los seis sonidos de Cruce (los mismos que se escogieron en la demo) y los guarda en WAV."""
import math, random, struct, sys, wave

SR = 44100
MASTER = 0.55
random.seed(7)

def env(n, attack, d, v):
    t = n / SR
    lo = 0.0001
    if t < attack:
        return lo * (v / lo) ** (t / attack)
    if t < d:
        return v * (lo / v) ** ((t - attack) / (d - attack))
    return 0.0

def tone(buf, f, start, d, kind="triangle", v=0.4, to=None, lp=None):
    s0 = int(start * SR)
    total = int((d + 0.03) * SR)
    phase = 0.0
    q = 0.75
    for n in range(total):
        t = n / SR
        freq = f * (to / f) ** (min(t, d) / d) if to else f
        phase += 2 * math.pi * freq / SR
        if kind == "sine":
            x = math.sin(phase)
        else:
            x = 0.0
            k = 1
            while k * freq < 18000:
                w = 1.0
                if lp:
                    r = k * freq / lp
                    w = 1 / math.sqrt((1 - r * r) ** 2 + (r / q) ** 2)
                if kind == "triangle":
                    if k % 2:
                        x += (8 / math.pi ** 2) * (-1) ** ((k - 1) // 2) * math.sin(k * phase) / k ** 2 * w
                elif kind == "square":
                    if k % 2:
                        x += (4 / math.pi) * math.sin(k * phase) / k * w
                elif kind == "sawtooth":
                    x += (2 / math.pi) * (-1) ** (k + 1) * math.sin(k * phase) / k * w
                k += 1
        buf[s0 + n] += x * env(n, 0.006, d, v)

def noise(buf, start, d, f, to=None, q=1.0, v=0.3):
    s0 = int(start * SR)
    x1 = x2 = y1 = y2 = 0.0
    for n in range(int(d * SR)):
        t = n / SR
        fc = f * (to / f) ** (t / d) if to else f
        w0 = 2 * math.pi * fc / SR
        alpha = math.sin(w0) / (2 * q)
        a0 = 1 + alpha
        b0, b2 = alpha / a0, -alpha / a0
        a1, a2 = -2 * math.cos(w0) / a0, (1 - alpha) / a0
        x = random.uniform(-1, 1)
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        buf[s0 + n] += y * env(n, 0.004, d, v)

def new(seconds):
    return [0.0] * int(seconds * SR)

sounds = {}
b = new(0.3); tone(b, 660, 0, .08, to=880); tone(b, 990, .07, .13, to=1320); sounds["gasto-guardado"] = b
b = new(0.4); tone(b, 988, 0, .07, "square", .14, lp=4000); tone(b, 1319, .07, .28, "square", .14, lp=4000); sounds["pago-anotado"] = b
b = new(0.6)
for i, f in enumerate([523, 659, 784, 1047]):
    tone(b, f, i * .08, .26, v=.3)
sounds["paz-y-salvo"] = b
b = new(0.25); noise(b, 0, .18, 4000, to=600, q=.8, v=.35); sounds["gasto-borrado"] = b
b = new(0.35); tone(b, 180, 0, .1, "square", .15, lp=1200); tone(b, 150, .12, .17, "square", .15, lp=1200); sounds["error"] = b
b = new(0.65); tone(b, 784, 0, .12); tone(b, 659, .1, .12); tone(b, 523, .2, .38, v=.35); sounds["parche-cerrado"] = b

# Una sola ganancia para todos: se conserva el volumen de uno frente a otro, como en la demo.
peak = max(abs(x) * MASTER for s in sounds.values() for x in s)
gain = MASTER * 0.89 / peak
out = sys.argv[1]
for name, s in sounds.items():
    with wave.open(f"{out}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * gain)) * 32767)) for x in s))
    print(name, round(max(abs(x) for x in s) * gain, 3))
