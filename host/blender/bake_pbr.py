"""Blender headless script: bake PBR rendered color to texture.

Usage:
    blender.exe -b -P bake_pbr.py -- <input.glb> <output.glb>

Phase 9 task E (experiment/blender-bake-warm):
- 旧版用 Nishita sky 偏冷 → anime 金发被 multiply 成偏白
- 改用 "warm 3-point studio" lighting setup:
    * key   = 暖色 area light (温白 ~5500K, 强 + 偏左上)
    * fill  = 较弱暖色 area light (~4500K, 偏右下)
    * rim   = 冷色 area light (~7000K, 后方背光勾边)
    * world = sunrise.exr HDRI (Blender 4.2 自带) 弱强度做 ambient
- 渲染器 Cycles + Standard view transform (保留 baseColor 鲜艳, 不做 Filmic)
- 'High Contrast' look 保留 anime 黑帽/白领局部 detail
- samples=256 (anime diffuse-dominant, denoiser cover noise) → 比原版 512 快 2x
"""
import sys
import os
import bpy

# Parse CLI args (after `--`)
argv = sys.argv
if "--" in argv:
    argv = argv[argv.index("--") + 1:]
else:
    argv = []

if len(argv) < 2:
    print("Usage: blender -b -P bake_pbr.py -- <input.glb> <output.glb>")
    sys.exit(1)

in_glb = os.path.abspath(argv[0])
out_glb = os.path.abspath(argv[1])
print(f"[bake] in={in_glb} out={out_glb}")

# 1. 清空 Blender 默认场景
bpy.ops.wm.read_factory_settings(use_empty=True)

# 2. 加载 GLB
print("[bake] loading GLB...")
bpy.ops.import_scene.gltf(filepath=in_glb)

# 计算 mesh AABB 用于摆灯距离
mesh_objs = [obj for obj in bpy.data.objects if obj.type == 'MESH']
if not mesh_objs:
    print("[bake] no mesh objects found!")
    sys.exit(1)

import mathutils
bbox_min = mathutils.Vector((1e9, 1e9, 1e9))
bbox_max = mathutils.Vector((-1e9, -1e9, -1e9))
for obj in mesh_objs:
    for v in obj.bound_box:
        wv = obj.matrix_world @ mathutils.Vector(v)
        for i in range(3):
            bbox_min[i] = min(bbox_min[i], wv[i])
            bbox_max[i] = max(bbox_max[i], wv[i])
center = (bbox_min + bbox_max) * 0.5
size = max(bbox_max[i] - bbox_min[i] for i in range(3))
dist = size * 1.5
print(f"[bake] bbox center={center}, size={size:.3f}, light_dist={dist:.3f}")

# 3. 设置 World 环境光: 用 Blender 4.2 自带 sunrise.exr 做暖色 ambient.
# IBL 主导 (strength 0.7, anime 平面光照风格) + 显式 sun 灯做立体感.
print("[bake] set up warm HDRI ambient (sunrise.exr)...")
world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
nt = world.node_tree
nt.nodes.clear()
out_node = nt.nodes.new("ShaderNodeOutputWorld")
bg = nt.nodes.new("ShaderNodeBackground")
bg.inputs["Strength"].default_value = 1.2   # IBL 主导平照, 偏暖 anime 风格

# 找 Blender 内置 sunrise.exr (warm). 路径 Win/Linux 都支持 bpy.utils.system_resource
hdri_path = None
sys_dir = bpy.utils.system_resource('DATAFILES')
if sys_dir:
    candidate = os.path.join(sys_dir, "studiolights", "world", "sunrise.exr")
    if os.path.exists(candidate):
        hdri_path = candidate
if hdri_path:
    print(f"[bake]   loaded HDRI: {hdri_path}")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(hdri_path, check_existing=True)
    nt.links.new(env.outputs["Color"], bg.inputs["Color"])
else:
    # fallback: warm solid (R=1.0, G=0.85, B=0.65)
    print("[bake]   no HDRI found, using warm solid color")
    bg.inputs["Color"].default_value = (1.0, 0.85, 0.65, 1.0)
nt.links.new(bg.outputs[0], out_node.inputs[0])

# 4. 添加 3-point studio lights (warm key + warm fill + cool rim).
# 用 SUN 而不是 AREA: Sun 灯不依赖距离衰减, energy 是直接 W/m², 不会因
# size×size 的 area 公式爆炸. 0.6/0.3/0.4 都是温和值, 不会盖过 baseColor.
print("[bake] adding 3-point studio lights (sun)...")

def add_sun_light(name, direction, color_rgb, energy):
    """direction: where the light points (vector from light to target)."""
    light_data = bpy.data.lights.new(name=name, type='SUN')
    light_data.color = color_rgb
    light_data.energy = energy
    light_data.angle = 0.5    # ~28° soft shadow (avoid sharp anime shadows)
    light_obj = bpy.data.objects.new(name, light_data)
    bpy.context.collection.objects.link(light_obj)
    light_obj.location = (0, 0, 0)
    d = mathutils.Vector(direction).normalized()
    rot_quat = d.to_track_quat('-Z', 'Y')
    light_obj.rotation_euler = rot_quat.to_euler()
    return light_obj

# Key sun: 暖白 (5500K), 上方左前 → -X +Y +Z (Blender Z-up).
add_sun_light(
    "Key", direction=(-0.7, 0.4, -0.8),
    color_rgb=(1.0, 0.95, 0.85), energy=2.5,
)
# Fill sun: 暖橘 (4500K), 右下补色. ~50% 主光.
add_sun_light(
    "Fill", direction=(0.6, -0.2, -0.3),
    color_rgb=(1.0, 0.85, 0.70), energy=1.2,
)
# Rim sun: 冷蓝 (7000K), 后方勾边. 弱化避免 anime 整体被冷光染.
add_sun_light(
    "Rim", direction=(0.0, -0.8, -0.2),
    color_rgb=(0.75, 0.88, 1.0), energy=0.5,
)

# 5. 设置渲染器 Cycles + Standard view transform
print("[bake] configuring Cycles...")
scn = bpy.context.scene
scn.render.engine = 'CYCLES'
scn.cycles.device = 'CPU'
scn.cycles.samples = 256                       # anime diffuse-dominant, denoiser cover
scn.cycles.use_adaptive_sampling = False
scn.cycles.use_denoising = True
scn.cycles.denoiser = 'OPENIMAGEDENOISE'
scn.cycles.denoising_input_passes = 'RGB_ALBEDO_NORMAL'
scn.cycles.diffuse_bounces = 4                  # 多 bounce → 暖光蔓延到阴影
scn.cycles.glossy_bounces = 2
# Bake-specific: COMBINED 含 direct+indirect+color
try:
    scn.render.bake.use_pass_direct = True
    scn.render.bake.use_pass_indirect = True
    scn.render.bake.use_pass_color = True
    scn.render.bake.margin = 8
except AttributeError:
    pass
# View transform: Standard 保留 baseColor 鲜艳, 'High Contrast' look 保 detail
scn.view_settings.view_transform = 'Standard'
scn.view_settings.look = 'Medium High Contrast'  # 保细节 + 不毁高光
scn.view_settings.exposure = 0.0
scn.view_settings.gamma = 1.0

# 6. 处理每个 mesh: 创建 bake target image + 给 material 加 image node
print(f"[bake] found {len(mesh_objs)} mesh objects")
BAKE_RES = 1024
processed_materials = set()

for obj in mesh_objs:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    if not obj.data.uv_layers:
        print(f"[bake] {obj.name}: no UV, smart unwrap")
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.uv.smart_project()
        bpy.ops.object.mode_set(mode='OBJECT')

    for slot in obj.material_slots:
        mat = slot.material
        if not mat or mat.name in processed_materials:
            continue
        processed_materials.add(mat.name)

        if not mat.use_nodes:
            mat.use_nodes = True

        mnt = mat.node_tree
        img = bpy.data.images.new(name=f"bake_{mat.name}",
                                   width=BAKE_RES, height=BAKE_RES, alpha=False)
        img_node = mnt.nodes.new("ShaderNodeTexImage")
        img_node.image = img
        img_node.label = "BAKE_TARGET"
        for n in mnt.nodes:
            n.select = False
        img_node.select = True
        mnt.nodes.active = img_node
        print(f"[bake]   added bake target image to material '{mat.name}'")

    obj.select_set(False)

# 7. Bake (COMBINED)
print("[bake] running bake...")
for obj in mesh_objs:
    for o in bpy.data.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    print(f"[bake]   baking '{obj.name}' (COMBINED, samples={scn.cycles.samples})...")
    try:
        bpy.ops.object.bake(type='COMBINED', use_clear=True, margin=8)
    except Exception as e:
        print(f"[bake]   failed: {e}")

# 8. 替换每个 material 的 baseColor 为 baked image
print("[bake] rewiring materials to use baked texture...")
for obj in mesh_objs:
    for slot in obj.material_slots:
        mat = slot.material
        if not mat or not mat.use_nodes:
            continue
        mnt = mat.node_tree
        bake_node = None
        for n in mnt.nodes:
            if n.label == "BAKE_TARGET":
                bake_node = n; break
        if bake_node is None:
            continue
        bsdf = None
        for n in mnt.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                bsdf = n; break
        if bsdf is None:
            continue
        bc_input = bsdf.inputs.get("Base Color")
        if bc_input is None:
            continue
        for link in list(bc_input.links):
            mnt.links.remove(link)
        mnt.links.new(bake_node.outputs["Color"], bc_input)
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.0
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 1.0

# 9. Export 新 GLB
print(f"[bake] exporting to {out_glb}...")
bpy.ops.export_scene.gltf(
    filepath=out_glb,
    export_format='GLB',
    export_image_format='AUTO',
    export_yup=True,
)
print(f"[bake] done: {out_glb}")
