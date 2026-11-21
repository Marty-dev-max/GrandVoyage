"""Island export (tools/export_island.luau JSON) -> island-local coordinates, plus a walk check.

python3 tools/island_local.py <in.json> <out.json> <x> <z> <yaw> [route]

Undoes WorldBuilder's turn (T = CFrame(x,0,z) * Angles(0,yaw,0) * CFrame(-x,0,0)) and moves the island to the
origin, so tools/blender/render_island.py shots line up. `route` = "x,z x,z ..." in island-local coordinates: the
script walks it in 0.5-stud steps on the highest floor under the feet and fails if a rise is taller than a step
(1.6) or something solid stands at body height (a wall, a stall, a house) in the way. It stands in for walking it in
Studio: no humanoid physics, CanCollide is not exported, so a decor part in the way also counts as blocked.
"""
import json, math, sys

src, dst, X, Z, YAW = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
route = [tuple(map(float, p.split(","))) for p in sys.argv[6].split()] if len(sys.argv) > 6 else []
c, s = math.cos(-YAW), math.sin(-YAW)
RY = [[c, 0, s], [0, 1, 0], [-s, 0, c]]  # Roblox CFrame.Angles(0, -yaw, 0)


def mul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def local_pos(p):
    x, y, z = p[0] - X, p[1], p[2] - Z
    return [RY[0][0] * x + RY[0][2] * z, y, RY[2][0] * x + RY[2][2] * z]


def local_cf(cf):
    R = [cf[3:6], cf[6:9], cf[9:12]]
    R2 = mul(RY, R)
    return local_pos(cf[:3]) + R2[0] + R2[1] + R2[2]


d = json.load(open(src))
for part in d["parts"] + d["envparts"]:
    part["cf"] = local_cf(part["cf"])
for prop in d["props"]:
    prop["base"] = local_pos(prop["base"])
json.dump(d, open(dst, "w"))

if route:
    solids = []
    for part in d["parts"]:
        if part.get("t", 0) >= 0.95:
            continue
        cf, size = part["cf"], part["size"]
        R = [cf[3:6], cf[6:9], cf[9:12]]
        solids.append((cf[:3], R, [v / 2 for v in size]))

    def column(x, z):
        """(bottom, top) of every part whose box covers the point (x, z)."""
        out = []
        for p, R, h in solids:
            dx, dz = x - p[0], z - p[2]
            # local x/z of the point (R columns are the part's axes); vertical extent from the box's corners
            ext = sum(abs(R[1][k]) * h[k] for k in range(3))
            n = (R[0][1], R[1][1], R[2][1])  # the part's local up axis
            if abs(n[1]) > 0.7 and (abs(R[1][0]) > 0.01 or abs(R[1][2]) > 0.01):  # ramp (gangplank, sloped deck): walk on its tilted top face
                sgn = 1 if n[1] > 0 else -1
                p0 = [p[i] + sgn * n[i] * h[1] for i in range(3)]
                y = p0[1] - (n[0] * (x - p0[0]) + n[2] * (z - p0[2])) / n[1]
                d = (x - p[0], y - p[1], z - p[2])
                lx = sum(R[i][0] * d[i] for i in range(3))
                lz = sum(R[i][2] * d[i] for i in range(3))
                if abs(lx) <= h[0] + 0.6 and abs(lz) <= h[2] + 0.6:
                    out.append((y - 2 * h[1] / abs(n[1]), y))
                continue
            ok = True
            for k in range(3):
                v = abs(R[1][k])
                if v < 0.01:  # horizontal axis: inside its half size (+0.6: feet span plank gaps)
                    ok = ok and abs(R[0][k] * dx + R[2][k] * dz) <= h[k] + 0.6
                elif v < 0.99:  # tilted part (ramps, roofs): crude bounding circle
                    ok = ok and dx * dx + dz * dz < max(h) ** 2 * 0.5
            if ok:
                out.append((p[1] - ext, p[1] + ext))
        return out

    foot = max(t for b, t in column(*route[0]) if t < 40)
    bad = 0
    for (ax, az), (bx, bz) in zip(route, route[1:]):
        n = max(1, int(math.hypot(bx - ax, bz - az) / 0.5))
        for i in range(1, n + 1):
            x, z = ax + (bx - ax) * i / n, az + (bz - az) * i / n
            col = column(x, z)
            floors = [t for b, t in col if t <= foot + 1.6]
            new = max(floors) if floors else foot
            wall = [(b, t) for b, t in col if t > foot + 1.6 and b < new + 5]
            if wall and bad < 12:
                print(f"BLOCKED at ({x:.1f}, {z:.1f}) foot {foot:.1f}: part {wall[0][0]:.1f}..{wall[0][1]:.1f}")
            bad += bool(wall)
            foot = new
    print(f"route end at floor {foot:.1f}, {bad} blocked samples")
    sys.exit(1 if bad else 0)
