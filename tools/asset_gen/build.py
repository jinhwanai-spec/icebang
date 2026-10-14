"""Frost Runner - 얼음땡 캐릭터 에셋 생성기 (numpy만 사용, glTF 2.0 .glb 출력)
좌표계: Y-up, 캐릭터 정면 = +Z, 발바닥 = y 0, 단위 m (키 약 1.25m)
"""
import numpy as np, json, struct, math, sys

# ---------------- 기본 도형 ----------------
def grid_mesh(fn, nu, nv, wrap_u=True):
    us = np.linspace(0, 1, nu + 1)
    vs = np.linspace(0, 1, nv + 1)
    P = np.array([[fn(u, v) for u in us] for v in vs], dtype=np.float64)  # (nv+1, nu+1, 3)
    V = P.reshape(-1, 3)
    idx = []
    W = nu + 1
    for j in range(nv):
        for i in range(nu):
            a = j * W + i; b = a + 1; c = a + W; d = c + 1
            idx += [a, c, b, b, c, d]
    return V, np.array(idx, dtype=np.uint32)

def sphere(r=1.0, scale=(1, 1, 1), nu=30, nv=20, power=1.0):
    sx, sy, sz = scale
    def f(u, v):
        th = u * 2 * math.pi; ph = v * math.pi
        cx, sxp = math.cos(th), math.sin(th)
        cp, sp = math.cos(ph), math.sin(ph)
        sg = lambda t: math.copysign(abs(t) ** power, t)
        return (r * sx * sg(sp) * sg(sxp), r * sy * sg(cp), r * sz * sg(sp) * sg(cx))
    return grid_mesh(f, nu, nv)

def capsule(r, h, nu=20, nv=16, scale=(1, 1, 1)):
    """y축 캡슐, 중심 원점, 직선부 길이 h"""
    V, I = sphere(r, nu=nu, nv=nv)
    V = V.copy()
    V[:, 1] += np.where(V[:, 1] > 0, h / 2, -h / 2)
    V *= np.array(scale)
    return V, I

def torus(R, r, arc=2 * math.pi, start=0.0, nu=48, nv=16, scale_r=(1, 1)):
    """XZ 평면 위 도넛 (y축 기준)"""
    def f(u, v):
        th = start + u * arc; ph = v * 2 * math.pi
        rr = R + r * scale_r[0] * math.cos(ph)
        return (rr * math.sin(th), r * scale_r[1] * math.sin(ph), rr * math.cos(th))
    return grid_mesh(f, nu, nv)

def cylinder(r, h, n=32, r2=None):
    r2 = r if r2 is None else r2
    verts, idx = [], []
    # 옆면
    for k in range(n + 1):
        t = k / n * 2 * math.pi
        verts.append((r * math.sin(t), -h / 2, r * math.cos(t)))
        verts.append((r2 * math.sin(t), h / 2, r2 * math.cos(t)))
    for k in range(n):
        a = 2 * k
        idx += [a, a + 2, a + 1, a + 1, a + 2, a + 3]
    # 뚜껑 (별도 정점 → 각진 모서리)
    for y, rad, flip in ((-h / 2, r, True), (h / 2, r2, False)):
        c = len(verts); verts.append((0, y, 0))
        for k in range(n + 1):
            t = k / n * 2 * math.pi
            verts.append((rad * math.sin(t), y, rad * math.cos(t)))
        for k in range(n):
            tri = [c, c + 1 + k, c + 2 + k]
            idx += (tri[::-1] if flip else tri)
    return np.array(verts, float), np.array(idx, np.uint32)

def crystal(r, h, n=6):
    """얼음 결정 (길쭉한 육각 쌍뿔)"""
    verts = [(0, h, 0), (0, -h * 0.6, 0)]
    for k in range(n):
        t = k / n * 2 * math.pi
        verts.append((r * math.sin(t), 0, r * math.cos(t)))
    idx = []
    for k in range(n):
        a = 2 + k; b = 2 + (k + 1) % n
        idx += [0, a, b, 1, b, a]
    return np.array(verts, float), np.array(idx, np.uint32)

# ---------------- 변환 ----------------
def rot(ax, deg):
    t = math.radians(deg); c, s = math.cos(t), math.sin(t)
    if ax == 'x': return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if ax == 'y': return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

def xf(mesh, R=None, t=(0, 0, 0), s=None):
    V, I = mesh
    V = V.copy()
    if s is not None: V = V * np.array(s)
    if R is not None: V = V @ R.T
    return V + np.array(t), I

def look_rot(n):
    """+Z 를 방향 n 으로 돌리는 회전"""
    n = np.array(n, float); n /= np.linalg.norm(n)
    z = np.array([0, 0, 1.0])
    v = np.cross(z, n); c = z @ n
    if np.linalg.norm(v) < 1e-8: return np.eye(3) if c > 0 else rot('y', 180)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))

def merge(*meshes):
    Vs, Is, off = [], [], 0
    for V, I in meshes:
        Vs.append(V); Is.append(I + off); off += len(V)
    return np.vstack(Vs), np.concatenate(Is).astype(np.uint32)

def normals(V, I, weld=True):
    F = I.reshape(-1, 3)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    key = np.round(V, 5)
    _, inv = np.unique(key, axis=0, return_inverse=True) if weld else (None, np.arange(len(V)))
    inv = inv.reshape(-1)
    acc = np.zeros((inv.max() + 1, 3))
    for k in range(3): np.add.at(acc, inv[F[:, k]], fn)
    N = acc[inv]
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-12)
    return N

# ---------------- 머리 표면 위 배치 도우미 ----------------
HEAD_C = np.array([0, 0.86, 0.0]); HEAD_R = np.array([0.40, 0.355, 0.37])
def on_head(yaw, pitch, lift=0.0):
    """머리 타원체 표면 점 + 법선 (yaw: +면 캐릭터 왼쪽(+x), pitch: +면 위)"""
    a, b = math.radians(yaw), math.radians(pitch)
    d = np.array([math.cos(b) * math.sin(a), math.sin(b), math.cos(b) * math.cos(a)])
    p = d * HEAD_R
    n = d / HEAD_R; n /= np.linalg.norm(n)
    return HEAD_C + p + n * lift, n

# ---------------- 재질 ----------------
def build(palette):
    M = {
        'Skin':      dict(c=palette['skin'], rough=0.55),
        'SkinDark':  dict(c=palette['skin_dark'], rough=0.6),
        'Belly':     dict(c=(1.0, 0.93, 0.82), rough=0.7),
        'Eye':       dict(c=(0.03, 0.03, 0.05), rough=0.15),
        'EyeShine':  dict(c=(1, 1, 1), rough=0.2, e=(0.9, 0.9, 0.9)),
        'Blush':     dict(c=(1.0, 0.45, 0.55), rough=0.8),
        'Mouth':     dict(c=(0.25, 0.05, 0.08), rough=0.5),
        'Scarf':     dict(c=palette['scarf'], rough=0.9),
        'ScarfStripe': dict(c=(0.97, 0.98, 1.0), rough=0.9),
        'Phone':     dict(c=(0.10, 0.11, 0.15), rough=0.35, m=0.4),
        'PhoneGlow': dict(c=palette['glow'], rough=0.3, e=palette['glow']),
        'Ice':       dict(c=(0.75, 0.93, 1.0), rough=0.05, e=(0.25, 0.55, 0.75), a=0.85),
        'Mitten':    dict(c=(0.97, 0.97, 0.95), rough=0.85),
        'Cuff':      dict(c=palette['scarf'], rough=0.9),
        'ShoeUpper': dict(c=palette['shoe'], rough=0.6),
        'ShoeSole':  dict(c=(0.95, 0.95, 0.93), rough=0.7),
        'Bag':       dict(c=palette['bag'], rough=0.7),
        'BagPocket': dict(c=tuple(x * 0.78 for x in palette['bag']), rough=0.75),
        'BagStrap':  dict(c=(0.12, 0.13, 0.18), rough=0.7),
        'Reflector': dict(c=(0.9, 0.95, 1.0), rough=0.25, e=palette['glow']),
    }
    nodes = {}  # name -> dict(pivot, parts{mat: [meshes]}, parent)
    def node(name, pivot, parent=None):
        nodes[name] = dict(pivot=np.array(pivot, float), parts={}, parent=parent)
    def add(name, mat, mesh):
        nodes[name]['parts'].setdefault(mat, []).append(mesh)

    node('Root', (0, 0, 0))
    node('Body', (0, 0.30, 0), 'Root')
    node('Head', (0, 0.60, 0), 'Body')
    node('ArmL', (0.235, 0.47, 0), 'Body')
    node('ArmR', (-0.235, 0.47, 0), 'Body')
    node('LegL', (0.11, 0.20, 0), 'Root')
    node('LegR', (-0.11, 0.20, 0), 'Root')
    node('Backpack', (0, 0.40, -0.20), 'Body')

    # ---- 몸통 ----
    add('Body', 'Skin', xf(sphere(1, (0.25, 0.27, 0.23)), t=(0, 0.38, 0)))
    add('Body', 'Belly', xf(sphere(1, (0.17, 0.17, 0.08)), t=(0, 0.34, 0.165)))
    # 목도리
    add('Body', 'Scarf', xf(torus(0.20, 0.065, nv=18, scale_r=(1, 1.15)), t=(0, 0.585, 0.0), s=(1, 1, 0.95)))
    for k in range(3):  # 흰 줄무늬
        add('Body', 'ScarfStripe', xf(torus(0.205, 0.067, nv=18, arc=0.18, start=0.5 + k * 0.55, nu=6),
                                      t=(0, 0.585, 0), s=(1, 1, 0.95)))
    # 목도리 꼬리 (오른쪽 앞에서 늘어짐, 바람에 날리는 느낌)
    tail_R = rot('z', -18) @ rot('x', -10)
    add('Body', 'Scarf', xf(capsule(0.055, 0.17, scale=(1, 1, 0.42)), R=tail_R, t=(-0.13, 0.47, 0.20)))
    add('Body', 'ScarfStripe', xf(cylinder(0.058, 0.03, n=20), R=tail_R, t=(-0.13, 0.47, 0.20), s=(1, 1, 0.44)))
    for k, dx in enumerate((-0.03, 0.0, 0.03)):  # 술 장식
        add('Body', 'ScarfStripe', xf(capsule(0.012, 0.03), R=tail_R, t=(-0.13 + dx + 0.035, 0.335 + k * 0.004, 0.215)))

    # ---- 머리 ----
    add('Head', 'Skin', xf(sphere(1, tuple(HEAD_R)), t=HEAD_C))
    # 눈 (크고 세로로 긴 타원, 하이라이트 2개)
    for side in (1, -1):
        p, n = on_head(22 * side, 4, lift=-0.012)
        R = look_rot(n)
        add('Head', 'Eye', xf(sphere(1, (0.058, 0.082, 0.03), nu=24, nv=16), R=R, t=p))
        p1, n1 = on_head(22 * side + 4 * side, 10, lift=0.013)
        add('Head', 'EyeShine', xf(sphere(1, (0.022, 0.026, 0.01), nu=14, nv=10), R=look_rot(n1), t=p1))
        p2, n2 = on_head(22 * side - 4 * side, -2, lift=0.012)
        add('Head', 'EyeShine', xf(sphere(1, (0.009, 0.009, 0.006), nu=10, nv=8), R=look_rot(n2), t=p2))
        # 눈썹 (살짝 장난스러운 기울기)
        pb, nb = on_head(22 * side, 21, lift=0.004)
        Rb = look_rot(nb) @ rot('z', 10 * side)
        add('Head', 'SkinDark', xf(capsule(0.011, 0.045), R=Rb @ rot('z', 90), t=pb))
        # 볼터치
        pc, nc = on_head(40 * side, -12, lift=-0.004)
        add('Head', 'Blush', xf(sphere(1, (0.05, 0.03, 0.012), nu=18, nv=10), R=look_rot(nc), t=pc))
    # 입 ( ω 모양 )
    for side in (1, -1):
        pm, nm = on_head(5.2 * side, -13, lift=-0.002)
        Rm = look_rot(nm) @ rot('x', -90)
        add('Head', 'Mouth', xf(torus(0.022, 0.007, arc=math.pi, start=math.pi / 2, nu=14, nv=8), R=Rm, t=pm))
    # 헤드폰 (발소리 메커니즘 상징) — 머리띠 + 이어컵 + 발광 링
    band = torus(0.415, 0.022, arc=math.pi, start=-math.pi / 2, nu=40, nv=12, scale_r=(1.3, 0.7))
    add('Head', 'Phone', xf(band, R=rot('x', -90), t=(0, 0.84, -0.02), s=(1, 0.98, 1)))
    for side in (1, -1):
        cup_t = (0.405 * side, 0.84, -0.02)
        Rc = rot('z', 90)
        add('Head', 'Phone', xf(cylinder(0.105, 0.07, n=36, r2=0.095), R=Rc @ rot('x', 0) if side < 0 else rot('z', -90), t=cup_t))
        add('Head', 'PhoneGlow', xf(torus(0.072, 0.012, nu=36, nv=10), R=rot('z', 90), t=(cup_t[0] + 0.037 * side, 0.84, -0.02)))
        add('Head', 'Phone', xf(sphere(1, (0.012, 0.045, 0.045), nu=20, nv=12), t=(cup_t[0] + 0.04 * side, 0.84, -0.02)))
        # 마이크 붐 (왼쪽만)
        if side > 0:
            a0, a1 = np.array([0.43, 0.80, 0.04]), np.array([0.33, 0.70, 0.26])
            d = a1 - a0; Rmic = look_rot(d) @ rot('x', 90)
            add('Head', 'Phone', xf(capsule(0.009, np.linalg.norm(d)), R=Rmic, t=(a0 + a1) / 2))
            add('Head', 'PhoneGlow', xf(sphere(0.02), t=a1))
    # 얼음 결정 (머리띠 위 – 실루엣 포인트)
    add('Head', 'Ice', xf(crystal(0.045, 0.13), t=(0, 1.27, -0.02)))
    add('Head', 'Ice', xf(crystal(0.028, 0.08), R=rot('z', 35), t=(0.07, 1.24, -0.02)))
    add('Head', 'Ice', xf(crystal(0.024, 0.07), R=rot('z', -40), t=(-0.065, 1.235, -0.02)))

    # ---- 팔 (어깨 피벗, 살짝 벌어짐) ----
    for side, name in ((1, 'ArmL'), (-1, 'ArmR')):
        sh = np.array([0.235 * side, 0.47, 0])
        Ra = rot('z', 28 * side)
        add(name, 'Skin', xf(capsule(0.065, 0.13), R=Ra, t=sh + Ra @ np.array([0, -0.10, 0])))
        add(name, 'Cuff', xf(torus(0.062, 0.022, nv=12), R=Ra, t=sh + Ra @ np.array([0, -0.19, 0])))
        add(name, 'Mitten', xf(sphere(1, (0.085, 0.08, 0.078)), R=Ra, t=sh + Ra @ np.array([0, -0.255, 0.01])))
        add(name, 'Mitten', xf(sphere(1, (0.032, 0.045, 0.032)), R=Ra @ rot('x', -30),
                               t=sh + Ra @ np.array([-0.045 * side * -1, -0.23, 0.07])))  # 엄지

    # ---- 다리 + 운동화 ----
    for side, name in ((1, 'LegL'), (-1, 'LegR')):
        hip = np.array([0.11 * side, 0.20, 0])
        add(name, 'SkinDark', xf(capsule(0.072, 0.08), t=hip + (0, -0.07, 0)))
        foot = hip + np.array([0.01 * side, -0.155, 0.04])
        add(name, 'ShoeUpper', xf(sphere(1, (0.095, 0.075, 0.14)), t=foot + (0, 0.035, 0)))
        add(name, 'ShoeSole', xf(sphere(1, (0.10, 0.03, 0.148), power=0.6), t=foot + (0, -0.012, 0)))
        add(name, 'ShoeSole', xf(sphere(1, (0.06, 0.045, 0.04)), t=foot + (0, 0.03, 0.105)))  # 토캡
        for k in range(2):  # 반사 끈 (어두운 맵에서 발 위치 보이게)
            add(name, 'Reflector', xf(capsule(0.009, 0.06), R=rot('z', 90), t=foot + (0, 0.085 - k * 0.0, 0.035 + k * 0.035) + (0, -k * 0.012, 0)))

    # ---- 배낭 ----
    add('Backpack', 'Bag', xf(sphere(1, (0.17, 0.18, 0.09), power=0.55), t=(0, 0.40, -0.25)))
    add('Backpack', 'BagPocket', xf(sphere(1, (0.12, 0.07, 0.04), power=0.6), t=(0, 0.33, -0.325)))  # 앞주머니
    add('Backpack', 'Reflector', xf(cylinder(0.035, 0.01, n=6), R=rot('x', 90), t=(0, 0.47, -0.336)))  # 육각 반사판
    add('Backpack', 'Ice', xf(crystal(0.018, 0.035), R=rot('x', 90), t=(0, 0.47, -0.345)))
    for side in (1, -1):  # 멜빵
        add('Backpack', 'BagStrap', xf(torus(0.13, 0.016, arc=math.pi * 0.9, start=math.pi * 0.55, nu=24, nv=8),
                                      R=rot('z', 90), t=(0.13 * side, 0.43, -0.03), s=(1, 1.15, 1)))
    return M, nodes

# ---------------- GLB 출력 ----------------
def export_glb(M, nodes, path, name='FrostRunner'):
    mat_names = list(M.keys())
    bin_chunks, bufviews, accessors, meshes, gl_nodes = [], [], [], [], []
    offset = 0
    def push(arr, target, comp, typ, minmax=False):
        nonlocal offset
        data = arr.tobytes()
        pad = (-len(data)) % 4
        bin_chunks.append(data + b'\x00' * pad)
        bufviews.append(dict(buffer=0, byteOffset=offset, byteLength=len(data), target=target))
        offset += len(data) + pad
        acc = dict(bufferView=len(bufviews) - 1, componentType=comp, count=len(arr), type=typ)
        if minmax:
            acc['min'] = arr.min(0).tolist(); acc['max'] = arr.max(0).tolist()
        accessors.append(acc)
        return len(accessors) - 1
    order = list(nodes.keys())
    tri_total = 0
    for nm in order:
        nd = nodes[nm]
        prims = []
        parent_piv = nodes[nd['parent']]['pivot'] if nd['parent'] else np.zeros(3)
        for mat, ms in nd['parts'].items():
            V, I = merge(*ms)
            N = normals(V, I)
            V = (V - nd['pivot']).astype(np.float32)
            tri_total += len(I) // 3
            pa = push(V, 34962, 5126, 'VEC3', True)
            na = push(N.astype(np.float32), 34962, 5126, 'VEC3')
            ia = push(I.astype(np.uint32), 34963, 5125, 'SCALAR')
            prims.append(dict(attributes=dict(POSITION=pa, NORMAL=na), indices=ia, material=mat_names.index(mat)))
        g = dict(name=nm, translation=(nd['pivot'] - parent_piv).tolist())
        if prims:
            meshes.append(dict(name=nm, primitives=prims)); g['mesh'] = len(meshes) - 1
        g['children'] = [order.index(c) for c, cn in nodes.items() if cn['parent'] == nm]
        if not g['children']: del g['children']
        gl_nodes.append(g)
    gl_nodes[0]['name'] = name
    mats = []
    for mn in mat_names:
        d = M[mn]
        c = list(d['c']) + [d.get('a', 1.0)]
        m = dict(name=mn, pbrMetallicRoughness=dict(baseColorFactor=c, metallicFactor=d.get('m', 0.0), roughnessFactor=d['rough']))
        if 'e' in d: m['emissiveFactor'] = list(d['e'])
        if d.get('a', 1.0) < 1: m['alphaMode'] = 'BLEND'
        mats.append(m)
    binary = b''.join(bin_chunks)
    gltf = dict(asset=dict(version='2.0', generator='FrostRunner builder'), scene=0,
                scenes=[dict(name=name, nodes=[0])], nodes=gl_nodes, meshes=meshes, materials=mats,
                accessors=accessors, bufferViews=bufviews, buffers=[dict(byteLength=len(binary))])
    js = json.dumps(gltf, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binary)))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(binary), 0x004E4942)); f.write(binary)
    return tri_total

PALETTES = {
    'red':    dict(skin=(0.86, 0.12, 0.11), skin_dark=(0.55, 0.06, 0.07), scarf=(0.35, 0.80, 0.95), glow=(0.30, 0.95, 1.00), shoe=(0.13, 0.17, 0.32), bag=(1.0, 0.78, 0.18)),
    'blue':   dict(skin=(0.16, 0.42, 0.92), skin_dark=(0.07, 0.20, 0.55), scarf=(1.00, 0.72, 0.20), glow=(1.00, 0.80, 0.30), shoe=(0.85, 0.20, 0.20), bag=(0.95, 0.95, 0.90)),
    'yellow': dict(skin=(0.98, 0.76, 0.12), skin_dark=(0.70, 0.45, 0.05), scarf=(0.55, 0.30, 0.85), glow=(0.80, 0.55, 1.00), shoe=(0.20, 0.20, 0.25), bag=(0.30, 0.75, 0.55)),
    'green':  dict(skin=(0.22, 0.75, 0.38), skin_dark=(0.10, 0.45, 0.20), scarf=(1.00, 0.45, 0.55), glow=(1.00, 0.55, 0.70), shoe=(0.95, 0.60, 0.15), bag=(0.20, 0.35, 0.70)),
}

if __name__ == '__main__':
    for key, pal in PALETTES.items():
        M, nodes = build(pal)
        n = export_glb(M, nodes, f'frost_runner_{key}.glb')
        print(key, 'tris', n)
