"""Blender headless script: bake PBR rendered color to texture.

Usage:
    blender.exe -b -P bake_pbr.py -- <input.glb> <output.glb>

输出: 新 GLB 文件, baseColor texture 已被 Blender Cycles bake 过的 IBL+PBR
渲染色替换. 板子端 voxelize_mesh 取该 texture 时拿到的就是 3D Viewer 风格
的鲜艳颜色 (金黄头发, 深蓝披风, 黑剑).
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

# 3. 设置 World 环境光: 上方天空蓝亮 + 下方暖光地面 (类似 3D Viewer studio HDR)
print("[bake] set up IBL environment...")
world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
bpy.context.scene.world = world
world.use_nodes = True
nt = world.node_tree
nt.nodes.clear()
out_node = nt.nodes.new("ShaderNodeOutputWorld")
# 用 SkyTexture (Nishita) 做天空 + ground gradient
sky = nt.nodes.new("ShaderNodeTexSky")
sky.sky_type = 'NISHITA'
sky.sun_elevation = 0.6   # 太阳偏上
sky.sun_intensity = 0.5
bg = nt.nodes.new("ShaderNodeBackground")
bg.inputs["Strength"].default_value = 1.0   # 适度 IBL
nt.links.new(sky.outputs[0], bg.inputs["Color"])
nt.links.new(bg.outputs[0], out_node.inputs[0])

# 4. 设置渲染器 Cycles + Filmic tonemapping (让 HDR 颜色映射成鲜艳 SDR)
print("[bake] configuring Cycles + Filmic...")
scn = bpy.context.scene
scn.render.engine = 'CYCLES'
scn.cycles.device = 'CPU'
scn.cycles.samples = 32
scn.cycles.use_denoising = True
scn.view_settings.view_transform = 'Standard'   # 不做 Filmic, 保留 baseColor 鲜艳
scn.view_settings.look = 'None'
scn.view_settings.exposure = 0.0

# 5. 找到所有 mesh objects 并联合 bake
mesh_objs = [obj for obj in bpy.data.objects if obj.type == 'MESH']
if not mesh_objs:
    print("[bake] no mesh objects found!")
    sys.exit(1)
print(f"[bake] found {len(mesh_objs)} mesh objects")

# 处理每个 mesh: 创建 bake target image + 切换 material 节点
BAKE_RES = 1024
processed_materials = set()

for obj in mesh_objs:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    # 确保有 UV layer (anime GLB 一般有, 但安全起见)
    if not obj.data.uv_layers:
        print(f"[bake] {obj.name}: no UV, smart unwrap")
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.uv.smart_project()
        bpy.ops.object.mode_set(mode='OBJECT')

    # 处理每个 material slot: 给材质添加 bake 目标 image
    for slot in obj.material_slots:
        mat = slot.material
        if not mat or mat.name in processed_materials:
            continue
        processed_materials.add(mat.name)

        if not mat.use_nodes:
            mat.use_nodes = True

        nt = mat.node_tree
        # 创建 bake image (per-material)
        img = bpy.data.images.new(name=f"bake_{mat.name}",
                                   width=BAKE_RES, height=BAKE_RES, alpha=False)
        # 加 Image Texture 节点指向该 image
        img_node = nt.nodes.new("ShaderNodeTexImage")
        img_node.image = img
        img_node.label = "BAKE_TARGET"
        # 选中 + 激活该节点 (Blender bake 写到 active node)
        for n in nt.nodes:
            n.select = False
        img_node.select = True
        nt.nodes.active = img_node
        print(f"[bake]   added bake target image to material '{mat.name}'")

    obj.select_set(False)

# 6. Bake 每个 object (Combined: 包含 IBL + diffuse + specular + emissive)
print("[bake] running bake...")
for obj in mesh_objs:
    for o in bpy.data.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    print(f"[bake]   baking '{obj.name}' (DIFFUSE)...")
    try:
        # DIFFUSE: 只保留 baseColor × diffuse lighting, 不含 specular 高光
        # (specular 会让所有面发白丢失色彩)
        bpy.ops.object.bake(type='DIFFUSE',
                            pass_filter={'COLOR', 'DIRECT', 'INDIRECT'},
                            use_clear=True, margin=4)
    except Exception as e:
        print(f"[bake]   failed: {e}")

# 7. 替换每个 material 的 baseColor 为 baked image
print("[bake] rewiring materials to use baked texture...")
for obj in mesh_objs:
    for slot in obj.material_slots:
        mat = slot.material
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        # 找 BAKE_TARGET image 节点
        bake_node = None
        for n in nt.nodes:
            if n.label == "BAKE_TARGET":
                bake_node = n; break
        if bake_node is None:
            continue
        # 找 Principled BSDF 节点
        bsdf = None
        for n in nt.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                bsdf = n; break
        if bsdf is None:
            continue
        # 断开原 baseColor 连接，连接 baked image
        bc_input = bsdf.inputs.get("Base Color")
        if bc_input is None:
            continue
        for link in list(bc_input.links):
            nt.links.remove(link)
        nt.links.new(bake_node.outputs["Color"], bc_input)
        # 把 metallic/roughness 设为非金属保留色彩
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.0
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 1.0

# 8. Export 新 GLB
print(f"[bake] exporting to {out_glb}...")
bpy.ops.export_scene.gltf(
    filepath=out_glb,
    export_format='GLB',
    export_image_format='AUTO',
    export_yup=True,
)
print(f"[bake] done: {out_glb}")
