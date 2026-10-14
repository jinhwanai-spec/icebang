"""버려진 밤 도시 건물 키트 (얼음땡)
- 외벽 모듈 3m x 3m, 1층 모듈 3m x 3.6m (level_builder 의 창문 시작 높이 3.6m 와 맞춤)
- 모듈 원점 = 벽 뒷면 아래 가운데. 뒷면은 z=0, 앞(바깥)은 +z. 건물 상자 표면에 붙이면 됨.
- 'Wall' 재질은 게임 쪽에서 건물별 노이즈 재질로 덮어써도 되도록 이름을 분리.
"""
import numpy as np, math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import build as B
from build import sphere, cylinder, torus, rot, xf, merge, look_rot
from build import capsule as _cap
capsule = lambda r, h, **k: _cap(r, h, nu=8, nv=6)

_orig = B.__dict__.setdefault('_normals_orig', B.normals)
B.normals = lambda V, I: _orig(V, I, weld=False)  # 건물은 각진 면(평면 셰이딩)

OUT = 'city_kit'
os.makedirs(OUT, exist_ok=True)

# ---------------- 도형 ----------------
_FACES = [((1, 0, 0), [(1, 0, 1), (1, 0, 0), (1, 1, 0), (1, 1, 1)]),
          ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
          ((0, 1, 0), [(0, 1, 1), (1, 1, 1), (1, 1, 0), (0, 1, 0)]),
          ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
          ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
          ((0, 0, -1), [(1, 0, 0), (0, 0, 0), (0, 1, 0), (1, 1, 0)])]

def box(lo, hi):
    lo, hi = np.array(lo, float), np.array(hi, float)
    V, I = [], []
    for n, cs in _FACES:
        b = len(V)
        for c in cs: V.append(lo + (hi - lo) * np.array(c))
        I += [b, b + 1, b + 2, b, b + 2, b + 3]
    V = np.array(V); I = np.array(I, np.uint32)
    F = I.reshape(-1, 3)  # 바깥쪽을 보도록 자동 보정
    ctr = (lo + hi) / 2
    for k, f in enumerate(F):
        nrm = np.cross(V[f[1]] - V[f[0]], V[f[2]] - V[f[0]])
        if nrm @ (V[f].mean(0) - ctr) < 0: F[k] = f[::-1]
    return V, F.reshape(-1).astype(np.uint32)

def cbox(c, s, R=None):
    c, s = np.array(c, float), np.array(s, float)
    m = box(-s / 2, s / 2)
    return xf(m, R=R, t=c)

def prism(pts2d, z0, z1):
    """XY 평면 다각형을 z 방향으로 뽑아낸 판 (유리 파편 등)"""
    P = np.array(pts2d, float); n = len(P)
    V, I = [], []
    for z in (z0, z1):
        for p in P: V.append((p[0], p[1], z))
    for k in range(1, n - 1):
        I += [0, k + 1, k, n, n + k, n + k + 1]
    for k in range(n):
        a, b = k, (k + 1) % n
        I += [a, b, n + b, a, n + b, n + a]
    return np.array(V, float), np.array(I, np.uint32)

# ---------------- 재질 ----------------
MATS = {
    'Wall':        dict(c=(0.50, 0.47, 0.42), rough=0.92),
    'WallTrim':    dict(c=(0.64, 0.61, 0.56), rough=0.9),
    'Brick':       dict(c=(0.47, 0.26, 0.21), rough=0.95),
    'Concrete':    dict(c=(0.38, 0.38, 0.37), rough=0.95),
    'Frame':       dict(c=(0.20, 0.22, 0.26), rough=0.6),
    'GlassDark':   dict(c=(0.04, 0.06, 0.09), rough=0.08, m=0.4),
    'GlassWarm':   dict(c=(1.0, 0.70, 0.38), rough=0.3, e=(1.0, 0.55, 0.22)),
    'GlassCool':   dict(c=(0.55, 0.82, 1.0), rough=0.3, e=(0.30, 0.55, 0.85)),
    'Curtain':     dict(c=(0.52, 0.22, 0.24), rough=0.9, e=(0.25, 0.07, 0.05)),
    'Interior':    dict(c=(0.03, 0.03, 0.04), rough=1.0),
    'Wood':        dict(c=(0.45, 0.31, 0.19), rough=0.9),
    'WoodDark':    dict(c=(0.30, 0.20, 0.13), rough=0.9),
    'Metal':       dict(c=(0.28, 0.30, 0.33), rough=0.45, m=0.7),
    'Rust':        dict(c=(0.43, 0.24, 0.14), rough=0.8, m=0.3),
    'Shutter':     dict(c=(0.50, 0.52, 0.53), rough=0.5, m=0.55),
    'Awning':      dict(c=(0.12, 0.42, 0.46), rough=0.85),
    'AwningStripe': dict(c=(0.88, 0.86, 0.78), rough=0.85),
    'NeonPink':    dict(c=(1.0, 0.35, 0.65), rough=0.3, e=(1.0, 0.25, 0.6)),
    'NeonGreen':   dict(c=(0.35, 1.0, 0.55), rough=0.3, e=(0.2, 1.0, 0.45)),
    'NeonCyan':    dict(c=(0.4, 0.95, 1.0), rough=0.3, e=(0.3, 0.9, 1.0)),
    'SignBoard':   dict(c=(0.08, 0.09, 0.12), rough=0.6),
    'Lamp':        dict(c=(1.0, 0.85, 0.6), rough=0.3, e=(1.0, 0.7, 0.4)),
    'Plastic':     dict(c=(0.05, 0.05, 0.06), rough=0.25),
    'PlasticBlue': dict(c=(0.10, 0.20, 0.42), rough=0.3),
    'Hazard':      dict(c=(0.95, 0.70, 0.08), rough=0.6),
    'HazardWhite': dict(c=(0.92, 0.92, 0.9), rough=0.5, e=(0.15, 0.15, 0.15)),
    'Cone':        dict(c=(0.98, 0.38, 0.08), rough=0.6),
    'Rubber':      dict(c=(0.06, 0.06, 0.06), rough=0.9),
    'Moss':        dict(c=(0.22, 0.32, 0.12), rough=1.0),
}

class Model:
    def __init__(self, name): self.name = name; self.parts = {}
    def add(self, mat, mesh):
        assert mat in MATS, mat
        self.parts.setdefault(mat, []).append(mesh); return self
    def extend(self, other, R=np.eye(3), t=(0, 0, 0), remap=None):
        for mat, ms in other.parts.items():
            for m in ms: self.add((remap or {}).get(mat, mat), xf(m, R=R, t=t))
        return self
    def save(self, collision=None):
        nodes = {'Root': dict(pivot=np.zeros(3), parts=self.parts, parent=None)}
        if collision is not None:  # Godot: '-colonly' 노드는 충돌 모양으로만 가져옴
            nodes['Collision-colonly'] = dict(pivot=np.zeros(3), parts={'Concrete': [collision]}, parent='Root')
        names = set(self.parts) | ({'Concrete'} if collision is not None else set())
        used = {k: MATS[k] for k in MATS if k in names}
        tris = B.export_glb(used, nodes, f'{OUT}/{self.name}.glb', name=self.name)
        return tris

# =============== 외벽 모듈 (3m x 3m) ===============
W, FH, T = 3.0, 3.0, 0.22     # 폭, 층 높이, 벽 두께
WIN_W, WIN_H, SILL = 1.5, 1.65, 0.85

def wall_with_hole(m, x0, x1, y0, y1, mat='Wall', h=FH, recess=0.14):
    """구멍 뚫린 벽 + 안쪽 턱"""
    m.add(mat, box((-W / 2, 0, 0), (x0, h, T)))
    m.add(mat, box((x1, 0, 0), (W / 2, h, T)))
    m.add(mat, box((x0, 0, 0), (x1, y0, T)))
    m.add(mat, box((x0, y1, 0), (x1, h, T)))
    # 안쪽 벽(턱 깊이감)
    return T - recess

def floor_band(m, h=0.16):
    m.add('WallTrim', box((-W / 2, 0, T), (W / 2, h, T + 0.05)))

def window_frame(m, x0, x1, y0, y1, zg, glass='GlassDark', mullion=True):
    m.add(glass, box((x0, y0, zg - 0.02), (x1, y1, zg)))
    fw = 0.07
    for a, b in (((x0, y0), (x1, y0 + fw)), ((x0, y1 - fw), (x1, y1)), ((x0, y0), (x0 + fw, y1)), ((x1 - fw, y0), (x1, y1))):
        m.add('Frame', box((a[0], a[1], zg), (b[0], b[1], zg + 0.05)))
    if mullion:
        xm = (x0 + x1) / 2
        m.add('Frame', box((xm - 0.03, y0, zg), (xm + 0.03, y1, zg + 0.04)))
        ym = y0 + (y1 - y0) * 0.62
        m.add('Frame', box((x0, ym - 0.025, zg), (x1, ym + 0.025, zg + 0.04)))
    # 창턱 + 창 위 인방
    m.add('WallTrim', box((x0 - 0.12, y0 - 0.1, 0), (x1 + 0.12, y0, T + 0.12)))
    m.add('WallTrim', box((x0 - 0.08, y1, T), (x1 + 0.08, y1 + 0.14, T + 0.05)))

def win_base(name, glass, curtain=False):
    m = Model(name)
    x0, x1, y0, y1 = -WIN_W / 2, WIN_W / 2, SILL, SILL + WIN_H
    zg = wall_with_hole(m, x0, x1, y0, y1)
    floor_band(m)
    window_frame(m, x0, x1, y0, y1, zg, glass)
    if curtain:  # 반쯤 친 커튼
        m.add('Curtain', box((x0 + 0.07, y0 + 0.5, zg - 0.05), (x0 + 0.55, y1 - 0.07, zg - 0.025)))
        m.add('Curtain', box((x1 - 0.35, y0 + 0.3, zg - 0.05), (x1 - 0.07, y1 - 0.07, zg - 0.025)))
    return m, (x0, x1, y0, y1, zg)

def mod_window_lit():
    return win_base('wall_window_lit', 'GlassWarm', curtain=True)[0]
def mod_window_cool():
    return win_base('wall_window_tv', 'GlassCool', curtain=True)[0]
def mod_window_dark():
    return win_base('wall_window_dark', 'GlassDark')[0]

def mod_window_boarded():
    m, (x0, x1, y0, y1, zg) = win_base('wall_window_boarded', 'Interior')
    for k, (yy, ang) in enumerate(((y0 + 0.35, 6), (y0 + 0.85, -4), (y0 + 1.3, 9))):
        m.add('Wood' if k != 1 else 'WoodDark', cbox((0.05 * (k - 1), yy, T + 0.06), (WIN_W + 0.35, 0.22, 0.04), R=rot('z', ang)))
    for x in (-0.65, 0.62):  # 못
        m.add('Metal', cbox((x, y0 + 0.85, T + 0.09), (0.04, 0.04, 0.02)))
    return m

def mod_window_broken():
    m, (x0, x1, y0, y1, zg) = win_base('wall_window_broken', 'Interior')
    shards = [[(x0 + .07, y1 - .07), (x0 + .55, y1 - .07), (x0 + .2, y1 - .5)],
              [(x1 - .07, y1 - .07), (x1 - .07, y1 - .7), (x1 - .4, y1 - .07)],
              [(x0 + .07, y0 + .07), (x0 + .45, y0 + .07), (x0 + .07, y0 + .55)],
              [(x1 - .07, y0 + .07), (x1 - .5, y0 + .07), (x1 - .2, y0 + .3), (x1 - .07, y0 + .6)]]
    for s in shards: m.add('GlassDark', prism(s, zg + 0.005, zg + 0.02))
    return m

def mod_balcony():
    m = Model('wall_balcony')
    x0, x1, y0, y1 = -0.55, 0.55, 0.0, 2.25
    zg = wall_with_hole(m, x0, x1, y0 + 0.16, y1)
    floor_band(m)
    window_frame(m, x0, x1, y0 + 0.16, y1, zg, 'GlassWarm', mullion=True)
    m.add('Curtain', box((x0 + .07, .5, zg - .05), (x0 + .4, y1 - .07, zg - .025)))
    # 슬래브 + 난간
    m.add('Concrete', box((-1.3, 0.0, T), (1.3, 0.16, T + 0.95)))
    m.add('Metal', box((-1.3, 1.0, T + 0.9), (1.3, 1.06, T + 0.95)))
    for side in (-1, 1):
        m.add('Metal', box((1.25 * side - 0.025, 1.0, T), (1.25 * side + 0.025, 1.06, T + 0.95)))
    for k in range(11):
        x = -1.25 + k * 0.25
        m.add('Metal', box((x - 0.015, 0.16, T + 0.9), (x + 0.015, 1.0, T + 0.93)))
    for side in (-1, 1):
        for k in range(4):
            z = T + 0.12 + k * 0.25
            m.add('Metal', box((1.25 * side - 0.015, 0.16, z), (1.25 * side + 0.015, 1.0, z + 0.03)))
    # 화분 + 말라 죽은 식물
    m.add('Rust', cbox((0.95, 0.3, T + 0.55), (0.35, 0.28, 0.3)))
    m.add('Moss', xf(sphere(1, (0.2, 0.16, 0.18), nu=10, nv=6), t=(0.95, 0.5, T + 0.55)))
    return m

def mod_wall_ac():
    m = Model('wall_ac')
    x0, x1, y0, y1 = -1.05, -0.25, 1.4, 2.4
    zg = wall_with_hole(m, x0, x1, y0, y1)
    floor_band(m)
    window_frame(m, x0, x1, y0, y1, zg, 'GlassDark', mullion=False)
    # 실외기 + 받침대 + 배수 호스
    m.add('WallTrim', box((0.15, 0.95, T), (1.25, 1.6, T + 0.55)))
    m.add('Frame', box((0.25, 1.05, T + 0.55), (0.85, 1.5, T + 0.56)))
    for k in range(5):
        y = 1.1 + k * 0.08
        m.add('Metal', box((0.25, y, T + 0.555), (0.85, y + 0.03, T + 0.575)))
    m.add('Metal', xf(cylinder(0.17, 0.02, n=16), R=rot('x', 90), t=(0.55, 1.275, T + 0.57)))
    for x in (0.25, 1.15):
        m.add('Rust', box((x - 0.03, 0.85, T), (x + 0.03, 0.9, T + 0.6)))
    m.add('Plastic', box((1.28, 0.2, T + 0.05), (1.32, 1.2, T + 0.09)))
    m.add('Plastic', box((1.1, 1.18, T + 0.05), (1.32, 1.22, T + 0.09)))
    return m

def mod_wall_pipe():
    m = Model('wall_pipe')
    m.add('Wall', box((-W / 2, 0, 0), (W / 2, FH, T)))
    floor_band(m)
    m.add('Metal', xf(cylinder(0.07, FH, n=12), t=(1.05, FH / 2, T + 0.1)))
    for y in (0.6, 2.2):
        m.add('Metal', box((0.95, y, T), (1.15, y + 0.06, T + 0.18)))
    # 환풍구 + 이끼 얼룩
    m.add('Frame', box((-0.6, 1.6, T), (0.0, 2.05, T + 0.04)))
    for k in range(4):
        m.add('Metal', box((-0.57, 1.66 + k * 0.1, T + 0.04), (-0.03, 1.69 + k * 0.1, T + 0.07)))
    m.add('Moss', xf(sphere(1, (0.35, 0.18, 0.03), nu=12, nv=6), t=(-0.9, 0.2, T)))
    return m

def mod_fire_escape():
    m, (x0, x1, y0, y1, zg) = win_base('wall_fire_escape', 'GlassDark')
    D = 1.0
    m.add('Metal', box((-1.45, -0.02, T), (1.45, 0.06, T + D)))  # 발판
    for k in range(9):
        x = -1.4 + k * 0.35
        m.add('Rust', box((x, 0.06, T + 0.05), (x + 0.03, 0.08, T + D)))
    m.add('Metal', box((-1.45, 1.0, T + D - 0.05), (1.45, 1.05, T + D)))
    for x in (-1.42, 1.42):
        m.add('Metal', box((x - 0.025, 0.0, T + D - 0.05), (x + 0.025, 1.05, T + D)))
        m.add('Metal', box((x - 0.025, 1.0, T), (x + 0.025, 1.05, T + D)))
    for k in range(12):
        x = -1.35 + k * 0.245
        m.add('Metal', box((x, 0.06, T + D - 0.04), (x + 0.02, 1.0, T + D - 0.02)))
    # 다음 층으로 이어지는 사다리 (위층 모듈의 발판에 닿음)
    for x in (0.9, 1.25):
        m.add('Metal', box((x - 0.02, 0.06, T + D - 0.25), (x + 0.02, FH, T + D - 0.21)))
    for k in range(9):
        y = 0.35 + k * 0.3
        m.add('Metal', box((0.9, y, T + D - 0.25), (1.25, y + 0.03, T + D - 0.21)))
    # 받침 브래킷
    for x in (-1.2, 1.2):
        m.add('Rust', xf(cbox((0, 0, 0), (0.05, 0.05, 0.95)), R=rot('x', -40), t=(x, -0.3, T + 0.38)))
    return m

# =============== 1층 모듈 (3m x 3.6m) ===============
GH = 3.6

def ground_base(name, x0, x1, y1):
    m = Model(name)
    m.add('Concrete', box((-W / 2, 0, 0), (W / 2, 0.35, T + 0.06)))  # 걸레받이
    m.add('Wall', box((-W / 2, 0.35, 0), (x0, GH, T)))
    m.add('Wall', box((x1, 0.35, 0), (W / 2, GH, T)))
    m.add('Wall', box((x0, y1, 0), (x1, GH, T)))
    m.add('WallTrim', box((-W / 2, GH - 0.25, T), (W / 2, GH, T + 0.1)))  # 1층 위 띠
    return m

def mod_shutter(open_ratio=0.0, name='ground_shutter'):
    x0, x1, top = -1.3, 1.3, 2.75
    m = ground_base(name, x0, x1, top)
    m.add('Concrete', box((x0, 0, 0), (x1, 0.35, 0.05)))
    m.add('Interior', box((x0, 0.0, 0.02), (x1, top, 0.05)))
    bottom = 0.0 + open_ratio * (top - 0.3)
    n = int((top - bottom) / 0.12)
    for k in range(n):
        y = bottom + k * 0.12
        m.add('Shutter', box((x0 + 0.05, y, 0.06), (x1 - 0.05, y + 0.1, 0.14)))
        m.add('Shutter', box((x0 + 0.05, y + 0.1, 0.07), (x1 - 0.05, y + 0.12, 0.12)))
    m.add('Metal', box((x0 + 0.05, bottom, 0.06), (x1 - 0.05, bottom + 0.06, 0.18)))  # 하단 바
    m.add('Metal', box((-0.15, bottom + 0.15, 0.14), (0.15, bottom + 0.2, 0.2)))  # 손잡이
    m.add('Shutter', box((x0 - 0.05, top, 0.0), (x1 + 0.05, top + 0.4, 0.38)))  # 셔터 통
    for x in (x0 - 0.04, x1 - 0.04):
        m.add('Metal', box((x, 0, 0.0), (x + 0.08, top, 0.16)))  # 레일
    m.add('Rust', box((x0 + 0.3, bottom + 0.06, 0.141), (x0 + 0.9, bottom + 0.5, 0.142)))
    if open_ratio > 0:  # 안쪽에서 새어나오는 빛
        m.add('GlassWarm', box((x0 + 0.1, 0.02, 0.03), (x1 - 0.1, 0.05, 0.6)))
    return m

def mod_door():
    x0, x1, top = -0.55, 0.55, 2.35
    m = ground_base('ground_door', x0, x1, top)
    m.add('Wall', box((-W / 2, 0, 0), (x0, 0.35, T)))
    m.add('Wall', box((x1, 0, 0), (W / 2, 0.35, T)))
    m.add('Concrete', box((x0 - 0.3, 0, T), (x1 + 0.3, 0.16, T + 0.45)))  # 계단
    m.add('Metal', box((x0, 0.0, 0.03), (x1, top, 0.09)))  # 철문
    for y in (0.5, 1.2, 1.9):
        m.add('Frame', box((x0 + 0.08, y, 0.09), (x1 - 0.08, y + 0.45, 0.11)))
    m.add('GlassWarm', box((x0 + 0.15, 1.9, 0.11), (x1 - 0.15, 2.2, 0.12)))
    m.add('Rust', box((x1 - 0.18, 1.0, 0.09), (x1 - 0.1, 1.12, 0.16)))  # 손잡이
    for a, b in (((x0 - 0.1, 0), (x0, top + 0.1)), ((x1, 0), (x1 + 0.1, top + 0.1)), ((x0 - 0.1, top), (x1 + 0.1, top + 0.1))):
        m.add('WallTrim', box((a[0], a[1], T), (b[0], b[1], T + 0.06)))
    # 출입구 등 + 작은 차양 + 번지판
    m.add('Metal', box((-0.8, 2.6, T), (0.8, 2.66, T + 0.6)))
    m.add('Lamp', xf(sphere(0.07, nu=12, nv=8), t=(0, 2.55, T + 0.25)))
    m.add('PlasticBlue', box((0.75, 1.7, T), (1.15, 1.95, T + 0.03)))
    m.add('HazardWhite', box((0.82, 1.76, T + 0.03), (1.08, 1.89, T + 0.035)))
    return m

def mod_shopfront():
    x0, x1, top = -1.35, 1.35, 2.5
    m = ground_base('ground_shop', x0, x1, top)
    m.add('Frame', box((x0, 0, 0), (x1, 0.35, T)))
    m.add('GlassCool', box((x0 + 0.05, 0.35, 0.06), (x1 - 0.05, top, 0.08)))
    for x in (x0, -0.3, x1 - 0.08):
        m.add('Frame', box((x, 0.35, 0.08), (x + 0.08, top, 0.14)))
    m.add('Frame', box((x0, 1.85, 0.08), (x1, 1.9, 0.13)))
    # 안쪽 선반 실루엣
    for k in range(3):
        m.add('Interior', box((x0 + 0.15, 0.6 + k * 0.42, 0.0), (x1 - 0.15, 0.64 + k * 0.42, 0.055)))
    # 줄무늬 차양 (기울어짐 + 한쪽 찢김)
    R = rot('x', 28)
    for k in range(10):
        x = x0 - 0.15 + k * 0.3
        mat = 'Awning' if k % 2 == 0 else 'AwningStripe'
        L = 1.05 if k != 7 else 0.7
        m.add(mat, xf(box((0, -0.02, 0), (0.3, 0.02, L)), R=R, t=(x, 2.95, T + 0.02)))
    for k in range(10):  # 앞자락
        x = x0 - 0.15 + k * 0.3
        if k == 7: continue
        m.add('Awning' if k % 2 == 0 else 'AwningStripe', box((x, 2.25, T + 0.93), (x + 0.3, 2.47, T + 0.96)))
    # 네온 간판 (글자 대신 컵 아이콘 + 물결)
    m.add('SignBoard', box((-1.1, 3.0, T + 0.1), (1.1, 3.45, T + 0.16)))
    m.add('NeonPink', xf(torus(0.13, 0.018, arc=math.pi * 1.6, start=-math.pi * 0.3, nu=20, nv=6), R=rot('x', 90), t=(-0.75, 3.22, T + 0.19)))
    m.add('NeonPink', box((-0.62, 3.12, T + 0.17), (-0.55, 3.32, T + 0.2)))
    for k in range(6):
        y = 3.22 + 0.06 * (1 if k % 2 else -1)
        m.add('NeonCyan', xf(capsule(0.016, 0.12), R=rot('z', 90 + (35 if k % 2 else -35)), t=(-0.25 + k * 0.17, y, T + 0.19)))
    return m

# =============== 모서리 / 옥상 ===============
def mod_corner(h=FH, name='corner_pillar'):
    m = Model(name)
    m.add('Wall', box((-0.3, 0, -0.3), (0.3, h, 0.3)))
    for k in range(int(h / 0.5)):  # 모서리 돌(퀸 스톤)
        y = k * 0.5
        w = 0.42 if k % 2 == 0 else 0.3
        m.add('WallTrim', box((0.3 - w, y + 0.03, 0.3 - 0.0), (0.33, y + 0.45, 0.33)))
        m.add('WallTrim', box((0.3, y + 0.03, 0.3 - w), (0.33, y + 0.45, 0.33)))
    return m

def mod_roof_edge():
    m = Model('roof_parapet')
    m.add('Wall', box((-W / 2, 0, 0), (W / 2, 0.75, T)))
    m.add('WallTrim', box((-W / 2, 0.0, T), (W / 2, 0.12, T + 0.12)))      # 코니스
    m.add('WallTrim', box((-W / 2, 0.12, T), (W / 2, 0.2, T + 0.06)))
    m.add('WallTrim', box((-W / 2, 0.75, -0.04), (W / 2, 0.85, T + 0.06)))  # 갓돌
    m.add('Moss', box((-0.9, 0.85, 0.02), (0.1, 0.88, T)))
    return m

def roof_water_tank():
    m = Model('roof_water_tank')
    for x in (-0.6, 0.6):
        for z in (-0.6, 0.6):
            m.add('Rust', box((x - 0.06, 0, z - 0.06), (x + 0.06, 1.2, z + 0.06)))
    m.add('Rust', box((-0.66, 0.5, -0.66), (0.66, 0.56, 0.66)))
    m.add('Wood', xf(cylinder(0.9, 1.6, n=20, r2=0.85), t=(0, 2.0, 0)))
    for y in (1.45, 2.0, 2.55):
        m.add('Metal', xf(torus(0.9, 0.025, nu=24, nv=6), t=(0, y, 0)))
    m.add('WoodDark', xf(cylinder(0.92, 0.5, n=20, r2=0.05), t=(0, 3.05, 0)))
    m.add('Metal', box((-0.03, 1.2, 0.85), (0.03, 2.6, 0.9)))
    return m

def roof_ac():
    m = Model('roof_ac_unit')
    m.add('WallTrim', box((-0.7, 0.1, -0.5), (0.7, 0.9, 0.5)))
    m.add('Frame', xf(cylinder(0.38, 0.05, n=20), t=(0, 0.92, 0)))
    for k in range(4):
        m.add('Metal', cbox((0, 0.95, 0), (0.7, 0.02, 0.1), R=rot('y', k * 45)))
    m.add('Metal', box((-0.75, 0, -0.55), (0.75, 0.1, 0.55)))
    for k in range(6):
        m.add('Metal', box((-0.6 + k * 0.22, 0.2, 0.5), (-0.55 + k * 0.22, 0.8, 0.52)))
    m.add('Metal', xf(cylinder(0.06, 1.2, n=10), R=rot('z', 90), t=(-1.3, 0.4, 0)))
    return m

def roof_antenna():
    m = Model('roof_antenna')
    m.add('Concrete', box((-0.3, 0, -0.3), (0.3, 0.15, 0.3)))
    m.add('Metal', xf(cylinder(0.035, 3.2, n=8), t=(0, 1.75, 0)))
    for k, (y, L) in enumerate(((2.4, 1.4), (2.85, 1.1), (3.2, 0.8))):
        m.add('Metal', cbox((0, y, 0), (L, 0.03, 0.03)))
        for x in np.linspace(-L / 2, L / 2, 5):
            m.add('Metal', cbox((x, y, 0.15), (0.02, 0.02, 0.3)))
    m.add('Metal', xf(sphere(0.35, (1, 0.35, 1), nu=16, nv=8), R=rot('x', 60), t=(0.0, 1.4, 0.3)))  # 위성 접시
    m.add('NeonPink', xf(sphere(0.05, nu=8, nv=6), t=(0, 3.4, 0)))  # 항공 경고등
    return m

# =============== 거리 소품 ===============
def prop_streetlamp():
    m = Model('prop_streetlamp')
    m.add('Concrete', xf(cylinder(0.22, 0.3, n=12, r2=0.18), t=(0, 0.15, 0)))
    m.add('Metal', xf(cylinder(0.09, 4.6, n=12, r2=0.06), t=(0, 2.6, 0)))
    m.add('Metal', cbox((0, 5.08, 0.22), (0.09, 0.09, 0.62), R=rot('x', -38)))  # 비스듬한 팔
    m.add('Metal', cbox((0, 5.3, 0.62), (0.08, 0.08, 0.35)))
    m.add('Metal', box((-0.2, 5.28, 0.4), (0.2, 5.42, 1.15)))
    m.add('Lamp', box((-0.15, 5.22, 0.5), (0.15, 5.28, 1.05)))
    m.add('Rust', box((-0.1, 1.2, 0.08), (0.1, 1.8, 0.1)))  # 붙은 전단지 자리
    return m

def prop_dumpster():
    m = Model('prop_dumpster')
    m.add('Rust', box((-0.95, 0.15, -0.55), (0.95, 1.2, 0.55)))
    m.add('PlasticBlue', box((-0.97, 0.9, -0.57), (0.97, 1.05, 0.57)))
    m.add('Plastic', xf(box((-0.96, 0, -0.58), (0.96, 0.05, 0.58)), R=rot('x', -12), t=(0, 1.2, 0.0)))  # 살짝 열린 뚜껑
    for x in (-0.75, 0.75):
        for z in (-0.4, 0.4):
            m.add('Rubber', xf(cylinder(0.1, 0.07, n=10), R=rot('x', 90), t=(x, 0.1, z)))
    m.add('Metal', box((-0.97, 0.55, 0.55), (0.97, 0.6, 0.62)))
    m.add('Plastic', xf(sphere(1, (0.3, 0.22, 0.25), nu=12, nv=8), t=(0.5, 1.25, 0.1)))  # 넘친 봉투
    return m

def prop_trash_bags():
    m = Model('prop_trash_bags')
    rng = np.random.default_rng(3)
    for k, (x, z, s) in enumerate(((0, 0, 0.38), (0.5, 0.15, 0.32), (0.2, 0.5, 0.3), (-0.4, 0.3, 0.27), (0.25, 0.2, 0.25))):
        y = s * 0.75 + (0.4 if k == 4 else 0)
        m.add('Plastic' if k != 2 else 'PlasticBlue', xf(sphere(1, (s, s * 0.8, s * 0.95), nu=14, nv=10), R=rot('y', rng.uniform(0, 90)), t=(x, y, z)))
        m.add('Plastic' if k != 2 else 'PlasticBlue', xf(capsule(0.04, 0.08), t=(x, y + s * 0.8, z)))
    return m

def prop_barrier():
    m = Model('prop_barrier')
    for x in (-0.9, 0.9):
        m.add('Metal', box((x - 0.04, 0, -0.04), (x + 0.04, 1.0, 0.04)))
        m.add('Metal', box((x - 0.04, 0, -0.3), (x + 0.04, 0.05, 0.3)))
    for y in (0.85, 0.45):
        for k in range(6):
            mat = 'Hazard' if k % 2 == 0 else 'HazardWhite'
            m.add(mat, xf(box((-0.15, -0.09, -0.02), (0.15, 0.09, 0.02)), R=rot('z', -20), t=(-0.75 + k * 0.3, y, 0)))
    m.add('Lamp', xf(cylinder(0.07, 0.08, n=10), t=(-0.9, 1.08, 0)))
    return m

def prop_cone():
    m = Model('prop_cone')
    m.add('Rubber', box((-0.22, 0, -0.22), (0.22, 0.05, 0.22)))
    m.add('Cone', xf(cylinder(0.18, 0.65, n=16, r2=0.03), t=(0, 0.375, 0)))
    m.add('HazardWhite', xf(cylinder(0.143, 0.1, n=16, r2=0.12), t=(0, 0.42, 0)))
    return m

def prop_crates():
    m = Model('prop_crates')
    for (cx, cy, cz, s, a) in ((-0.5, 0.55, 0, 1.1, 0), (0.5, 0.45, 0, 0.9, 12), (-0.45, 1.5, 0.05, 0.8, -8)):
        R = rot('y', a); c = np.array((cx, cy, cz))
        m.add('Wood', cbox(c, (s, s, s), R=R))
        for dy in (-s / 2 + 0.06, s / 2 - 0.06):
            m.add('WoodDark', cbox(c + R @ np.array((0, dy, s / 2 + 0.01)), (s + 0.02, 0.1, 0.03), R=R))
        m.add('WoodDark', cbox(c + R @ np.array((0, 0, s / 2 + 0.01)), (s * 1.3, 0.1, 0.03), R=R @ rot('z', 45)))
    return m

def prop_utility_pole():
    m = Model('prop_utility_pole')
    m.add('Concrete', xf(cylinder(0.16, 8.0, n=12, r2=0.12), t=(0, 4.0, 0)))
    for y, L in ((7.2, 2.2), (6.4, 1.6)):
        m.add('Metal', box((-L / 2, y, -0.06), (L / 2, y + 0.1, 0.06)))
        for x in np.linspace(-L / 2 + 0.1, L / 2 - 0.1, 4):
            m.add('HazardWhite', xf(cylinder(0.04, 0.14, n=8), t=(x, y + 0.17, 0)))
    m.add('Metal', xf(cylinder(0.3, 0.8, n=14), t=(0.0, 5.3, 0.38)))  # 변압기
    m.add('Metal', box((-0.05, 5.0, 0.1), (0.05, 5.6, 0.2)))
    for y in np.arange(2.2, 6.0, 0.4):  # 발판 못
        m.add('Metal', box((-0.25, y, -0.02), (0.25, y + 0.04, 0.02)) if int(y * 5) % 2 else box((-0.02, y, -0.25), (0.02, y + 0.04, 0.25)))
    m.add('Hazard', xf(cylinder(0.165, 0.5, n=12), t=(0, 1.5, 0)))
    m.add('Rubber', xf(cylinder(0.168, 0.12, n=12), t=(0, 1.55, 0)))
    return m

def prop_neon_sign(mat='NeonGreen', name='prop_neon_sign'):
    """level_builder 의 _sign 크기(2.6 x 0.8 x 0.2)와 같음. 원점=가운데"""
    m = Model(name)
    m.add('SignBoard', box((-1.3, -0.4, -0.1), (1.3, 0.4, 0.1)))
    m.add('Metal', box((-1.32, -0.42, -0.1), (1.32, -0.38, 0.12)))
    m.add('Metal', box((-1.32, 0.38, -0.1), (1.32, 0.42, 0.12)))
    # 추상 기호 (별 + 물결 + 점) — 실제 상표/글자 없음
    for k in range(5):
        m.add(mat, xf(capsule(0.02, 0.22), R=rot('z', k * 36), t=(-0.95, 0, 0.12)))
    for k in range(7):
        m.add(mat, xf(capsule(0.02, 0.14), R=rot('z', 90 + (40 if k % 2 else -40)), t=(-0.55 + k * 0.17, 0.05 * (1 if k % 2 else -1), 0.12)))
    m.add('NeonPink', xf(sphere(0.06, nu=10, nv=6), t=(0.95, 0, 0.12)))
    m.add(mat, box((-0.6, -0.27, 0.11), (0.65, -0.24, 0.14)))
    return m

# =============== 조립 건물 ===============
def assemble(name, cols, depth_cols, floors, pattern, ground, roof_items, seed, wall='Wall'):
    """cols x depth_cols (각 3m) 바닥, floors 층(1층 포함)"""
    rng = np.random.default_rng(seed)
    bw, bd = cols * W, depth_cols * W
    h = GH + (floors - 1) * FH
    m = Model(name)
    rm = {'Wall': wall}
    m.add(wall, box((-bw / 2, 0, -bd / 2), (bw / 2, h, bd / 2)))  # 몸통(빈 공간 메움)
    m.add('Concrete', box((-bw / 2 + 0.2, h, -bd / 2 + 0.2), (bw / 2 - 0.2, h + 0.05, bd / 2 - 0.2)))
    faces = [(rot('y', 0), (0, 0, bd / 2), cols, True), (rot('y', 180), (0, 0, -bd / 2), cols, False),
             (rot('y', 90), (bw / 2, 0, 0), depth_cols, False), (rot('y', -90), (-bw / 2, 0, 0), depth_cols, False)]
    for R, origin, n, front in faces:
        origin = np.array(origin, float)
        for i in range(n):
            off = R @ np.array(((i - (n - 1) / 2) * W, 0, 0))
            g = ground[i % len(ground)] if front else rng.choice([MODS['wall_pipe'], MODS['wall_window_dark'], MODS['ground_shutter']])
            if not front and g is MODS['ground_shutter']: g = MODS['ground_shutter']
            gm = g if g.name.startswith('ground') else None
            if gm is None:  # 옆/뒤 1층에 위층 모듈 쓰면 높이 맞춤용 받침
                m.add('Concrete', xf(box((-W / 2, 0, 0), (W / 2, GH - FH, T + 0.06)), R=R, t=origin + off))
                m.extend(g, R=R, t=origin + off + np.array((0, GH - FH, 0)), remap=rm)
            else:
                m.extend(g, R=R, t=origin + off, remap=rm)
            for f in range(1, floors):
                col_pat = pattern(i, f, front, rng)
                m.extend(MODS[col_pat], R=R, t=origin + off + np.array((0, GH + (f - 1) * FH, 0)), remap=rm)
            m.extend(MODS['roof_parapet'], R=R, t=origin + off + np.array((0, h, 0)), remap=rm)
    corner = mod_corner(h + 0.75, 'c')
    for sx in (-1, 1):
        for sz in (-1, 1):
            R = rot('y', {(1, 1): 0, (1, -1): 90, (-1, -1): 180, (-1, 1): 270}[(sx, sz)])
            m.extend(corner, R=R, t=(sx * (bw / 2), 0, sz * (bd / 2)), remap=rm)
    for item, (x, z, a) in roof_items:
        m.extend(MODS[item], R=rot('y', a), t=(x, h + 0.05, z), remap=rm)
    col = box((-bw / 2 - 0.25, 0, -bd / 2 - 0.25), (bw / 2 + 0.25, h + 0.85, bd / 2 + 0.25))
    return m, col

MODS = {}
def register(m): MODS[m.name] = m; return m

if __name__ == '__main__':
    mods = [mod_window_lit(), mod_window_cool(), mod_window_dark(), mod_window_boarded(), mod_window_broken(),
            mod_balcony(), mod_wall_ac(), mod_wall_pipe(), mod_fire_escape(),
            mod_shutter(), mod_shutter(0.55, 'ground_shutter_open'), mod_door(), mod_shopfront(),
            mod_corner(), mod_roof_edge(), roof_water_tank(), roof_ac(), roof_antenna(),
            prop_streetlamp(), prop_dumpster(), prop_trash_bags(), prop_barrier(), prop_cone(), prop_crates(),
            prop_utility_pole(), prop_neon_sign(), prop_neon_sign('NeonCyan', 'prop_neon_sign_blue')]
    for m in mods:
        register(m)
        print(f'{m.name:24s}', m.save())

    def pat_a(i, f, front, rng):
        return rng.choice(['wall_window_lit', 'wall_window_dark', 'wall_window_dark', 'wall_window_boarded', 'wall_window_tv', 'wall_ac'])
    def pat_b(i, f, front, rng):
        if front and i % 2 == 1: return 'wall_balcony'
        return rng.choice(['wall_window_lit', 'wall_window_dark', 'wall_window_broken', 'wall_ac', 'wall_window_tv'])
    def pat_c(i, f, front, rng):
        if front and i == 1: return 'wall_fire_escape'
        return rng.choice(['wall_window_dark', 'wall_window_boarded', 'wall_window_broken', 'wall_window_lit', 'wall_pipe'])

    S, D, O, SH = MODS['ground_shutter'], MODS['ground_door'], MODS['ground_shutter_open'], MODS['ground_shop']
    blds = [
        assemble('building_shops_3f', 3, 3, 3, pat_a, [S, SH, O], [('roof_ac_unit', (-2.5, -2, 0)), ('roof_antenna', (2.5, 2, 0))], 1, wall='Brick'),
        assemble('building_apart_4f', 4, 3, 4, pat_b, [D, S, SH, S], [('roof_ac_unit', (3, -2.5, 90)), ('roof_ac_unit', (-1, -2.5, 90)), ('roof_antenna', (-4, 2, 0))], 2),
        assemble('building_tall_5f', 2, 3, 5, pat_c, [O, D], [('roof_water_tank', (0, -1.5, 0))], 3, wall='Concrete'),
    ]
    for m, col in blds:
        register(m)
        print(f'{m.name:24s}', m.save(collision=col))
