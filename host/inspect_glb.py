"""Quick: dump animations + skins of a glb."""
import sys
from pygltflib import GLTF2

path = sys.argv[1]
g = GLTF2().load(path)
print(f"meshes={len(g.meshes)} nodes={len(g.nodes)}")
print(f"animations={len(g.animations)}")
for i, a in enumerate(g.animations):
    print(f"  [{i}] name={a.name!r} channels={len(a.channels)} samplers={len(a.samplers)}")
    for ch in a.channels[:6]:
        print(f"      ch: target.node={ch.target.node} path={ch.target.path}  sampler={ch.sampler}")
print(f"skins={len(g.skins)}")
for i, s in enumerate(g.skins):
    print(f"  [{i}] joints={len(s.joints)} skeleton={s.skeleton}")
print(f"accessors total={len(g.accessors)}")
