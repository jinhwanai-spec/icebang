"""풀이 자란 버려진 도시 - 자연 키트 (얼음땡)
나무/덤불/담쟁이/덩굴/쓰러진 통나무/빛나는 버섯 등. 원점 = 바닥 가운데, 단위 m.
건물 키트(kit.py)와 같은 각진 로우폴리 스타일.
"""
import numpy as np, math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import kit
from kit import Model, box, cbox, prism, MATS
from build import sphere, cylinder, rot, xf, look_rot

kit.OUT = 'nature_kit'
os.makedirs(kit.OUT, exist_ok=True)

MATS.update({
    'Bark':       dict(c=(0.29, 0.20, 0.13), rough=0.95),
    'BarkPale':   dict(c=(0.80, 0.78, 0.72), rough=0.9),
    'BarkMark':   dict(c=(0.12, 0.11, 0.10), rough=0.9),
    'Leaf':       dict(c=(0.17, 0.34, 0.15), rough=0.85),
    'LeafLight':  dict(c=(0.27, 0.46, 0.18), rough=0.85),
    'LeafDark':   dict(c=(0.10, 0.22, 0.12), rough=0.9),
    'LeafAutumn': dict(c=(0.62, 0.38, 0.12), rough=0.85),
    'Pine':       dict(c=(0.08, 0.24, 0.17), rough=0.9),
    'Grass':      dict(c=(0.30, 0.47, 0.17), rough=0.9),
    'GrassDry':   dict(c=(0.56, 0.50, 0.27), rough=0.9),
    'Ivy':        dict(c=(0.14, 0.33, 0.13), rough=0.8),
    'IvyLight':   dict(c=(0.24, 0.44, 0.15), rough=0.8),
    'Vine':       dict(c=(0.22, 0.24, 0.11), rough=0.9),
    'FlowerWhite': dict(c=(0.95, 0.94, 0.88), rough=0.7, e=(0.12, 0.12, 0.1)),
    'FlowerYellow': dict(c=(1.0, 0.82, 0.2), rough=0.7, e=(0.15, 0.1, 0.0)),
    'FlowerPink': dict(c=(1.0, 0.55, 0.7), rough=0.7, e=(0.12, 0.04, 0.06)),
    'Stem':       dict(c=(0.85, 0.85, 0.80), rough=0.8),
    'ShroomGlow': dict(c=(0.45, 0.90, 1.0), rough=0.4, e=(0.25, 0.75, 1.0)),
    'ShroomRed':  dict(c=(0.85, 0.16, 0.12), rough=0.5),
    'Spots':      dict(c=(0.97, 0.96, 0.9), rough=0.6),
    'Wood':       MATS['Wood'], 'Moss': MATS['Moss'],
})

# ---------------- 유기 형태 도우미 ----------------
def explode(mesh):
    """정점을 삼각형마다 따로 → 각진(로우폴리) 음영"""
    V, I = mesh
    return V[I].copy(), np.arange(len(I), dtype=np.uint32)

def lumpy(mesh, center, amp, seed, freq=3.0):
    V, I = mesh
    rng = np.random.default_rng(seed)
    d = V - np.array(center, float)
    n = d / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-9)
    f = np.zeros(len(V))
    for _ in range(4):
        k = rng.normal(size=3); k /= np.linalg.norm(k)
        f += np.sin(n @ k * freq * rng.uniform(0.7, 1.4) + rng.uniform(0, 6.28))
    return V + n * (amp * f / 2)[:, None], I

def blob(c, r, seed, squash=(1, 0.85, 1), amp=0.14, res=(9, 6)):
    m = xf(sphere(r, squash, nu=res[0], nv=res[1]), t=c)
    return explode(lumpy(m, c, r * amp, seed))

def limb(p0, p1, r0, r1, n=7):
    p0, p1 = np.array(p0, float), np.array(p1, float)
    d = p1 - p0; L = np.linalg.norm(d)
    m = cylinder(r0, L, n=n, r2=r1)
    R = look_rot(d) @ rot('x', 90)
    return explode(xf(m, R=R, t=(p0 + p1) / 2))

def blade(base, h, w, lean, yaw, seed):
    """풀잎 한 장 (휘어진 얇은 판, 양면)"""
    rng = np.random.default_rng(seed)
    pts = [(-w / 2, 0), (w / 2, 0), (w * 0.15, h * 0.7), (lean * 0.3, h)]
    m = prism(pts, -0.008, 0.008)
    R = rot('y', yaw) @ rot('x', -lean * 25)
    return xf(m, R=R, t=base)

def tree_collision(r=0.25, h=3.0):
    return box((-r, 0, -r), (r, h, r))

# ---------------- 나무 ----------------
def tree_round(name, seed, leaf_mats=('Leaf', 'LeafLight', 'LeafDark'), scale=1.0):
    rng = np.random.default_rng(seed)
    m = Model(name)
    top = np.array((rng.uniform(-0.15, 0.15), 2.5 * scale, rng.uniform(-0.15, 0.15)))
    m.add('Bark', limb((0, 0, 0), (0, 1.2 * scale, 0), 0.3 * scale, 0.22 * scale))
    m.add('Bark', limb((0, 1.15 * scale, 0), top, 0.22 * scale, 0.15 * scale))
    for k in range(4):  # 뿌리 퍼짐
        a = k * 90 + rng.uniform(-20, 20)
        d = np.array((math.sin(math.radians(a)), 0, math.cos(math.radians(a))))
        m.add('Bark', limb(d * 0.05 + (0, 0.35, 0), d * 0.55 + (0, 0.0, 0), 0.13, 0.04, n=5))
    ends = []
    for k in range(4):
        a = k * 90 + rng.uniform(0, 60)
        d = np.array((math.sin(math.radians(a)), 0, math.cos(math.radians(a))))
        y0 = rng.uniform(1.7, 2.3) * scale
        e = d * rng.uniform(1.0, 1.5) * scale + (0, y0 + rng.uniform(0.7, 1.2) * scale, 0)
        m.add('Bark', limb((0, y0, 0), e, 0.12 * scale, 0.05 * scale, n=6))
        ends.append(e)
    ends.append(top + (0, 1.0 * scale, 0))
    for k, e in enumerate(ends):
        r = rng.uniform(1.0, 1.35) * scale
        m.add(leaf_mats[k % len(leaf_mats)], blob(e + (0, 0.3, 0), r, seed * 10 + k))
    # 큰 덩어리 사이 작은 잎뭉치
    for k in range(5):
        e = ends[k % 4] * 0.6 + top * 0.4 + rng.normal(0, 0.3, 3)
        m.add(leaf_mats[(k + 1) % len(leaf_mats)], blob(e + (0, 0.8, 0), rng.uniform(0.55, 0.8) * scale, seed * 20 + k))
    m.save_col = tree_collision(0.28 * scale, 3.0)
    return m

def tree_pine(name, seed, tiers=5, h=6.2):
    rng = np.random.default_rng(seed)
    m = Model(name)
    m.add('Bark', limb((0, 0, 0), (0, h * 0.75, 0), 0.22, 0.08))
    for k in range(tiers):
        t = k / (tiers - 1)
        y = 1.3 + t * (h - 2.2)
        r = 1.7 * (1 - t) + 0.45
        ht = 1.7 - 0.6 * t
        cone = cylinder(r, ht, n=9, r2=0.05)
        cone = lumpy(cone, (0, 0, 0), 0.1, seed * 7 + k, freq=4)
        m.add('Pine' if k % 2 == 0 else 'LeafDark', explode(xf(cone, R=rot('y', rng.uniform(0, 40)), t=(0, y + ht / 2, 0))))
    m.save_col = tree_collision(0.25, 3.0)
    return m

def tree_dead(name, seed):
    rng = np.random.default_rng(seed)
    m = Model(name)
    def grow(p, d, r, L, depth):
        e = p + d * L
        m.add('Bark', limb(p, e, r, r * 0.65, n=6))
        if depth == 0 or r < 0.025:
            return
        for _ in range(3):
            nd = d * 0.6 + rng.normal(0, 0.8, 3); nd[1] = abs(nd[1]) * 0.5 + 0.2
            nd /= np.linalg.norm(nd)
            grow(e, nd, r * 0.68, L * rng.uniform(0.65, 0.85), depth - 1)
    p = np.zeros(3); d = np.array((0, 1.0, 0)); r = 0.3
    for k in range(3):  # 휘어진 줄기
        nd = d + np.array((rng.normal(0, 0.18), 0, rng.normal(0, 0.18))); nd /= np.linalg.norm(nd)
        e = p + nd * 1.0
        m.add('Bark', limb(p, e, r, r * 0.85, n=7))
        p, d, r = e, nd, r * 0.85
    grow(p, d, r, 1.4, 4)
    for k in range(3):  # 이끼 덩어리
        m.add('Moss', blob(p * rng.uniform(0.2, 0.9) + (rng.uniform(-.2, .2), 0, 0.15), 0.18, seed + k, squash=(1, 0.6, 1)))
    m.save_col = tree_collision(0.3, 3.0)
    return m

def tree_birch(name, seed):
    rng = np.random.default_rng(seed)
    m = Model(name)
    for k, (x, z, h, lean) in enumerate(((0, 0, 5.5, 0.05), (0.5, 0.3, 4.6, 0.15), (-0.35, 0.4, 4.0, -0.12))):
        base = np.array((x, 0, z)); top = base + (lean * h, h, lean * h * 0.4)
        m.add('BarkPale', limb(base, top, 0.13, 0.07, n=7))
        for j in range(6):  # 자작나무 무늬
            t = rng.uniform(0.1, 0.8); p = base + (top - base) * t
            m.add('BarkMark', cbox(p + (0, 0, 0.11 - 0.02 * t), (0.12, 0.04, 0.02)))
        for j in range(3):
            c = top - (top - base) * (j * 0.18) + rng.normal(0, 0.25, 3)
            m.add(('LeafLight', 'Leaf', 'LeafAutumn')[(k + j) % 3] if j < 2 or k != 2 else 'LeafAutumn',
                  blob(c, rng.uniform(0.6, 0.85), seed * 30 + k * 5 + j, squash=(1, 1.3, 1)))
    m.save_col = tree_collision(0.4, 3.0)
    return m

def sapling(name, seed):
    rng = np.random.default_rng(seed)
    m = Model(name)
    m.add('Bark', limb((0, 0, 0), (0.1, 1.6, 0), 0.06, 0.03, n=5))
    for k in range(3):
        c = np.array((0.1, 1.5, 0)) + rng.normal(0, 0.25, 3) + (0, 0.25, 0)
        m.add(('LeafLight', 'Leaf')[k % 2], blob(c, rng.uniform(0.35, 0.5), seed + k))
    return m

# ---------------- 덤불 / 풀 ----------------
def bush(name, seed, flowers=None, n=5, size=0.7):
    rng = np.random.default_rng(seed)
    m = Model(name)
    cs = []
    for k in range(n):
        a = k / n * 6.28 + rng.uniform(-.3, .3)
        c = np.array((math.sin(a) * size * 0.7, size * rng.uniform(0.55, 0.8), math.cos(a) * size * 0.7)) if k else np.array((0, size, 0))
        r = size * rng.uniform(0.6, 0.85) if k else size
        m.add(('Leaf', 'LeafLight', 'LeafDark')[k % 3], blob(c, r, seed * 9 + k, squash=(1, 0.8, 1)))
        cs.append((c, r))
    if flowers:
        for k in range(26):
            c, r = cs[rng.integers(len(cs))]
            d = rng.normal(size=3); d[1] = abs(d[1]) + 0.3; d /= np.linalg.norm(d)
            p = c + d * r * np.array((1, 0.8, 1)) * 1.02
            m.add(flowers[k % len(flowers)], explode(xf(sphere(0.055, nu=5, nv=3), t=p)))
    return m

def hedge(name, seed, length=3.0):
    rng = np.random.default_rng(seed)
    m = Model(name)
    for k in range(7):
        x = -length / 2 + 0.25 + k * (length - 0.5) / 6
        m.add(('Leaf', 'LeafDark', 'LeafLight')[k % 3], blob((x, 0.6, rng.uniform(-.1, .1)), rng.uniform(0.5, 0.65), seed + k, squash=(1, 1.15, 0.8)))
    m.save_col = box((-length / 2, 0, -0.45), (length / 2, 1.3, 0.45))
    return m

def grass_clump(name, seed, n=16, h=0.5, mats=('Grass', 'GrassDry')):
    rng = np.random.default_rng(seed)
    m = Model(name)
    for k in range(n):
        p = rng.normal(0, 0.12, 3); p[1] = 0
        m.add(mats[0] if rng.random() > 0.25 else mats[1],
              blade(p, h * rng.uniform(0.6, 1.2), 0.07, rng.uniform(-1, 1), rng.uniform(0, 360), k))
    return m

def reeds(name, seed):
    m = grass_clump(name, seed, n=22, h=1.3, mats=('GrassDry', 'Grass'))
    rng = np.random.default_rng(seed)
    for k in range(6):  # 이삭
        p = rng.normal(0, 0.1, 3); p[1] = 1.2 + rng.uniform(0, 0.3)
        m.add('Wood', explode(xf(sphere(1, (0.03, 0.12, 0.03), nu=6, nv=4), t=p)))
        m.add('GrassDry', limb((p[0], 0, p[2]), p, 0.01, 0.008, n=4))
    return m

def weeds_crack(name, seed, length=2.0):
    """보도 틈에서 자란 잡초 줄"""
    rng = np.random.default_rng(seed)
    m = Model(name)
    for k in range(9):
        x = -length / 2 + k * length / 8 + rng.uniform(-.08, .08)
        for j in range(rng.integers(3, 6)):
            m.add('Grass' if rng.random() > .3 else 'GrassDry',
                  blade((x + rng.uniform(-.06, .06), 0, rng.uniform(-.05, .05)), rng.uniform(0.12, 0.32), 0.05, rng.uniform(-1, 1), rng.uniform(0, 360), k * 10 + j))
        if k % 4 == 1:
            m.add('FlowerYellow', explode(xf(sphere(0.04, nu=5, nv=3), t=(x, 0.3, 0))))
    return m

def flower_patch(name, seed):
    rng = np.random.default_rng(seed)
    m = grass_clump(name, seed, n=14, h=0.3)
    for k in range(9):
        p = rng.normal(0, 0.28, 3); p[1] = rng.uniform(0.25, 0.4)
        m.add('Grass', limb((p[0], 0, p[2]), p, 0.008, 0.006, n=4))
        col = ('FlowerWhite', 'FlowerYellow', 'FlowerPink')[k % 3]
        for j in range(5):
            a = j * 72
            m.add(col, explode(xf(sphere(1, (0.035, 0.012, 0.02), nu=5, nv=3), R=rot('y', a), t=p + rot('y', a) @ np.array((0.035, 0, 0)))))
        m.add('FlowerYellow', explode(xf(sphere(0.02, nu=5, nv=3), t=p + (0, 0.01, 0))))
    return m

# ---------------- 바닥 소품 ----------------
def log_fallen(name, seed):
    rng = np.random.default_rng(seed)
    m = Model(name)
    m.add('Bark', explode(lumpy(xf(cylinder(0.32, 3.2, n=9, r2=0.26), R=rot('z', 90) @ rot('y', 0), t=(0, 0.3, 0)), (0, 0.3, 0), 0.03, seed, 6)))
    for x in (-1.6, 1.6):  # 나이테 단면
        m.add('Wood', explode(xf(cylinder(0.27 if x < 0 else 0.22, 0.02, n=9), R=rot('z', 90), t=(x + 0.005 * np.sign(x), 0.3, 0))))
    m.add('Bark', limb((0.6, 0.45, 0.1), (0.9, 0.95, 0.5), 0.07, 0.03, n=5))  # 부러진 가지
    for k in range(5):
        m.add('Moss', blob((rng.uniform(-1.3, 1.3), 0.58, rng.uniform(-.1, .1)), rng.uniform(0.15, 0.28), seed + k, squash=(1.4, 0.4, 1)))
    shroom_cluster(m, (0.9, 0.0, 0.33), 3, seed + 3, scale=0.6)
    m.save_col = box((-1.6, 0, -0.33), (1.6, 0.62, 0.33))
    return m

def stump(name, seed):
    rng = np.random.default_rng(seed)
    m = Model(name)
    m.add('Bark', explode(lumpy(xf(cylinder(0.42, 0.55, n=10, r2=0.36), t=(0, 0.275, 0)), (0, 0.27, 0), 0.03, seed, 6)))
    m.add('Wood', explode(xf(cylinder(0.33, 0.02, n=10), t=(0, 0.555, 0))))
    m.add('WoodDark' if 'WoodDark' in MATS else 'Bark', explode(xf(cylinder(0.18, 0.005, n=10), t=(0, 0.567, 0))))
    for k in range(4):
        a = k * 90 + 30; d = np.array((math.sin(math.radians(a)), 0, math.cos(math.radians(a))))
        m.add('Bark', limb(d * 0.3 + (0, 0.2, 0), d * 0.7, 0.1, 0.03, n=5))
    m.add('Moss', blob((0.25, 0.4, 0.25), 0.15, seed, squash=(1, 0.5, 1)))
    shroom_cluster(m, (-0.4, 0, 0.25), 4, seed + 1, scale=0.7)
    m.save_col = box((-0.42, 0, -0.42), (0.42, 0.58, 0.42))
    return m

def shroom_cluster(m, at, n, seed, scale=1.0, mat='ShroomGlow'):
    rng = np.random.default_rng(seed)
    at = np.array(at, float)
    for k in range(n):
        p = at + np.array((rng.uniform(-.15, .15), 0, rng.uniform(-.15, .15))) * scale * 1.5
        h = rng.uniform(0.12, 0.3) * scale; r = rng.uniform(0.07, 0.13) * scale
        tilt = rot('z', rng.uniform(-15, 15)) @ rot('x', rng.uniform(-15, 15))
        m.add('Stem', explode(xf(cylinder(r * 0.35, h, n=6, r2=r * 0.28), R=tilt, t=p + tilt @ np.array((0, h / 2, 0)))))
        cap = sphere(r, (1, 0.6, 1), nu=8, nv=5)
        V, I = cap; V = V.copy(); V[:, 1] = np.maximum(V[:, 1], -r * 0.1)
        m.add(mat, explode(xf((V, I), R=tilt, t=p + tilt @ np.array((0, h, 0)))))
        if mat == 'ShroomRed':
            for j in range(3):
                a = rng.uniform(0, 6.28)
                m.add('Spots', explode(xf(sphere(r * 0.18, nu=5, nv=3), R=tilt, t=p + tilt @ np.array((math.sin(a) * r * 0.6, h + r * 0.4, math.cos(a) * r * 0.6)))))
    return m

def mushrooms(name, seed, mat):
    m = Model(name)
    shroom_cluster(m, (0, 0, 0), 7, seed, scale=1.4, mat=mat)
    m.add('Moss', blob((0, 0.0, 0), 0.35, seed, squash=(1, 0.2, 1)))
    return m

def leaf_pile(name, seed):
    rng = np.random.default_rng(seed)
    m = Model(name)
    for k in range(4):
        m.add(('LeafAutumn', 'GrassDry', 'LeafAutumn', 'Bark')[k], blob((rng.uniform(-.4, .4), 0.02, rng.uniform(-.4, .4)), rng.uniform(0.35, 0.55), seed + k, squash=(1.3, 0.3, 1.1)))
    for k in range(14):  # 흩어진 낙엽
        p = rng.normal(0, 0.6, 3); p[1] = 0.01
        m.add('LeafAutumn' if k % 3 else 'GrassDry', xf(prism([(-0.05, 0), (0, 0.04), (0.05, 0), (0, -0.04)], 0, 0.01), R=rot('x', -90) @ rot('z', rng.uniform(0, 180)), t=p))
    return m

# ---------------- 건물용 덩굴 ----------------
def ivy_wall(name, seed, w=3.0, h=3.0):
    """건물 외벽 모듈(3x3m) 앞에 겹쳐 붙이는 담쟁이. 원점 = 아래 가운데, 벽 앞면 z=0.22 기준"""
    rng = np.random.default_rng(seed)
    m = Model(name)
    z0 = kit.T + 0.01
    for s in range(4):  # 덩굴 줄기가 아래에서 위로 구불구불
        p = np.array((rng.uniform(-w / 2 + 0.3, w / 2 - 0.3), 0.0, z0))
        steps = rng.integers(8, 14)
        for k in range(steps):
            d = np.array((rng.uniform(-0.25, 0.25), rng.uniform(0.18, 0.3), 0))
            e = p + d; e[0] = np.clip(e[0], -w / 2 + 0.05, w / 2 - 0.05)
            if e[1] > h: break
            m.add('Vine', limb(p, e, 0.02, 0.016, n=4))
            for j in range(3):  # 잎 (벽에 납작하게 붙은 하트형 판)
                q = e + np.array((rng.uniform(-0.18, 0.18), rng.uniform(-0.12, 0.12), 0.012))
                s_ = rng.uniform(0.07, 0.12) * (1.25 - e[1] / h * 0.5)
                pts = [(0, -s_), (s_, 0.1 * s_), (0.5 * s_, s_), (0, 0.6 * s_), (-0.5 * s_, s_), (-s_, 0.1 * s_)]
                m.add('Ivy' if rng.random() > .35 else 'IvyLight',
                      xf(prism(pts, 0, 0.012), R=rot('z', rng.uniform(-40, 40)) @ rot('y', rng.uniform(-20, 20)), t=q))
            p = e
    return m

def vines_hanging(name, seed, w=3.0):
    """옥상 난간에서 늘어지는 덩굴. 원점 = 난간 윗면 앞 가운데"""
    rng = np.random.default_rng(seed)
    m = Model(name)
    for s in range(9):
        x = -w / 2 + 0.2 + s * (w - 0.4) / 8 + rng.uniform(-.1, .1)
        L = rng.uniform(0.6, 2.6)
        p = np.array((x, 0, 0.05))
        segs = int(L / 0.25)
        for k in range(segs):
            e = p + np.array((math.sin(k * 0.9 + s) * 0.04, -0.25, 0.01))
            m.add('Vine', limb(p, e, 0.014, 0.011, n=4))
            if k % 1 == 0:
                for j in range(2):
                    sz = 0.07 * (1 - k / segs * 0.5)
                    m.add('Ivy' if (k + j) % 3 else 'IvyLight',
                          xf(prism([(0, -sz), (sz, 0), (0, sz * 0.8), (-sz, 0)], 0, 0.01),
                             R=rot('y', rng.uniform(-50, 50)) @ rot('z', rng.uniform(0, 180)), t=e + (rng.uniform(-.06, .06), 0, 0.03)))
            p = e
    for k in range(7):  # 위쪽 잎뭉치
        m.add(('Ivy', 'IvyLight', 'LeafDark')[k % 3], blob((-w / 2 + 0.25 + k * (w - 0.5) / 6, 0.02, 0.1), rng.uniform(0.16, 0.26), seed + k, squash=(1.3, 0.7, 1)))
    return m


def build_all():
    out = [
        tree_round('tree_round_a', 1), tree_round('tree_round_b', 7),
        tree_round('tree_round_autumn', 4, leaf_mats=('LeafAutumn', 'Leaf', 'LeafAutumn')),
        tree_pine('tree_pine', 2), tree_dead('tree_dead', 5), tree_birch('tree_birch', 6),
        sapling('tree_sapling', 8),
        bush('bush_round', 3), bush('bush_flower', 9, flowers=('FlowerWhite', 'FlowerPink')), bush('bush_small', 11, n=3, size=0.4),
        hedge('hedge_3m', 12),
        grass_clump('grass_clump', 13), reeds('grass_reeds', 14), weeds_crack('weeds_crack', 15), flower_patch('flower_patch', 16),
        log_fallen('log_fallen', 17), stump('stump', 18),
        mushrooms('mushrooms_glow', 19, 'ShroomGlow'), mushrooms('mushrooms_red', 20, 'ShroomRed'), leaf_pile('leaf_pile', 21),
        ivy_wall('ivy_wall_3x3', 22), vines_hanging('vines_hanging_3m', 23),
    ]
    return out

if __name__ == '__main__':
    for m in build_all():
        print(f'{m.name:22s}', m.save(collision=getattr(m, 'save_col', None)))
