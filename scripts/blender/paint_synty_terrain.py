"""
Perimeter: Warden (Периметр) — Synty-Style Terrain Painter & Exporter
Applies iconic Synty Studios low-poly coloring based on height and slope:
- Saturated, clean low-poly color palette
- Slope-aware cliff detection (steep slopes turn to rocky slate)
- Color Attributes (Vertex/Loop Colors) baked into mesh
- Flat Shading enabled
- Export to GLB with vertex colors and materials
"""

import bpy
import bmesh
import math
import os

BLEND_PATH = r"D:\GodotProjects\perimeter\blender_templates\terrain_template.blend"
GLB_PATH = r"D:\GodotProjects\perimeter\assets\terrain_sculpt.glb"

def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return (
        c1[0] + (c2[0] - c1[0]) * t,
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        1.0
    )

def get_synty_color(z, normal_z):
    # normal_z: 1.0 = flat floor, 0.0 = vertical wall
    slope = 1.0 - max(0.0, min(1.0, normal_z))

    # --- 1. РЕЧНОЕ ДНО И ЗАЛИВЫ (Z < -8.0) ---
    if z < -8.0:
        c_flat = (0.22, 0.20, 0.16, 1.0) # темный речной ил
        c_cliff = (0.32, 0.28, 0.22, 1.0) # влажные речные камни
        return lerp_color(c_flat, c_cliff, slope * 1.5)

    # --- 2. БЕРЕГ И ПЕСОК ПОЙМЫ (Z in [-8.0, -1.0]) ---
    elif z < -1.0:
        t_z = (z - (-8.0)) / 7.0
        c_deep = (0.48, 0.42, 0.32, 1.0) # мокрый прибрежный песок
        c_dry = (0.78, 0.70, 0.48, 1.0) # золотистый песок Synty
        base_sand = lerp_color(c_deep, c_dry, t_z)
        c_rock = (0.50, 0.44, 0.36, 1.0) # песчаниковые береговые уступы
        return lerp_color(base_sand, c_rock, slope * 1.6)

    # --- 3. СОЧНЫЙ ЛУГ ДОЛИНЫ И БАЗА ЛЕСНИКА (Z in [-1.0, 14.0]) ---
    elif z < 14.0:
        t_z = (z - (-1.0)) / 15.0
        c_low = (0.38, 0.70, 0.24, 1.0) # сочная свежая зелень долины
        c_high = (0.32, 0.62, 0.22, 1.0) # травянистая поляна
        base_green = lerp_color(c_low, c_high, t_z)

        # Скальные выступы на крутых склонах
        if slope > 0.45:
            c_cliff = (0.48, 0.45, 0.40, 1.0)
            return lerp_color(base_green, c_cliff, (slope - 0.45) / 0.35)
        return base_green

    # --- 4. ВЕКОВАЯ ТАЙГА И ХОЛМЫ (Z in [14.0, 42.0]) ---
    elif z < 42.0:
        t_z = (z - 14.0) / 28.0
        c_pine = (0.20, 0.48, 0.20, 1.0) # густая таежная хвоя Synty
        c_hill = (0.26, 0.44, 0.22, 1.0) # подножия холмов
        base_taiga = lerp_color(c_pine, c_hill, t_z)

        if slope > 0.40:
            c_cliff = (0.46, 0.45, 0.42, 1.0) # скальные обрывы
            return lerp_color(base_taiga, c_cliff, (slope - 0.40) / 0.35)
        return base_taiga

    # --- 5. ПРЕДГОРЬЯ И СКАЛЬНЫЕ ХРЕБТЫ (Z in [42.0, 75.0]) ---
    elif z < 75.0:
        t_z = (z - 42.0) / 33.0
        c_moss_rock = (0.36, 0.44, 0.32, 1.0) # замшелые камни
        c_rock = (0.48, 0.47, 0.45, 1.0) # теплый горный сланец
        base_rock = lerp_color(c_moss_rock, c_rock, t_z)

        if slope > 0.35:
            c_cliff = (0.42, 0.41, 0.40, 1.0)
            return lerp_color(base_rock, c_cliff, (slope - 0.35) / 0.35)
        return base_rock

    # --- 6. ВЫСОКОГОРНЫЙ ГРАНИТ И ИЗВЕСТНЯК (Z in [75.0, 120.0]) ---
    elif z < 120.0:
        t_z = (z - 75.0) / 45.0
        c_slate = (0.52, 0.55, 0.58, 1.0) # холодный горный гранит
        c_light_rock = (0.64, 0.67, 0.70, 1.0) # светлые скалы
        return lerp_color(c_slate, c_light_rock, t_z)

    # --- 7. ПРИВЕРШИННЫЙ ФРОСТ И МОРОЗНЫЕ КАРНИЗЫ (Z in [120.0, 145.0]) ---
    elif z < 145.0:
        t_z = (z - 120.0) / 25.0
        c_ice_rock = (0.72, 0.76, 0.82, 1.0)
        c_snow_rock = (0.86, 0.89, 0.94, 1.0)
        return lerp_color(c_ice_rock, c_snow_rock, t_z)

    # --- 8. ВЕЧНЫЕ СНЕЖНЫЕ ПИКИ (Z >= 145.0) ---
    else:
        c_snow_base = (0.92, 0.94, 0.98, 1.0)
        c_snow_crest = (0.98, 0.99, 1.0, 1.0)
        t_z = min(1.0, (z - 145.0) / 40.0)
        return lerp_color(c_snow_base, c_snow_crest, t_z)

def process_terrain():
    print(f"[Synty Painter] Opening {BLEND_PATH}...")
    bpy.ops.wm.open_mainfile(filepath=BLEND_PATH)

    obj = bpy.data.objects.get("Terrain_1000x1000")
    if not obj:
        raise ValueError("Terrain_1000x1000 not found in scene!")

    mesh = obj.data

    # Включаем плоское затенение (Flat Shading)
    for p in mesh.polygons:
        p.use_smooth = False

    # Очищаем старые атрибуты цвета и создаем чистый POINT-слой
    while mesh.color_attributes:
        mesh.color_attributes.remove(mesh.color_attributes[0])

    color_layer = mesh.color_attributes.new(
        name="Color",
        type='FLOAT_COLOR',
        domain='POINT'
    )
    mesh.color_attributes.active_color = color_layer

    # Заполняем цвета для каждой вершины
    for i, v in enumerate(mesh.vertices):
        z = v.co.z
        norm_z = v.normal.z
        col = get_synty_color(z, norm_z)
        color_layer.data[i].color = col

    print(f"[Synty Painter] Painted {len(mesh.polygons)} polygons across {len(mesh.vertices)} vertices.")

    # Настраиваем материал под отображение Color Attribute в Blender
    mat_name = "M_Terrain_Synty"
    mat = bpy.data.materials.get(mat_name)
    if not mat:
        mat = bpy.data.materials.new(name=mat_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    attr_node = nodes.new(type="ShaderNodeAttribute")
    attr_node.attribute_name = "Color"
    attr_node.location = (-300, 200)

    bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    bsdf.inputs['Roughness'].default_value = 0.88
    bsdf.inputs['Specular IOR Level'].default_value = 0.15
    bsdf.location = (0, 200)

    out = nodes.new(type="ShaderNodeOutputMaterial")
    out.location = (300, 200)

    links.new(attr_node.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])

    if len(mesh.materials) == 0:
        mesh.materials.append(mat)
    else:
        mesh.materials[0] = mat

    # Сохраняем обновленный .blend
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print(f"[Synty Painter] Saved .blend: {BLEND_PATH}")

    # Экспортируем в GLB с вертексными цветами
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        use_selection=True,
        export_format='GLB',
        export_apply=True,
        export_attributes=True
    )
    print(f"[Synty Painter] Exported GLB: {GLB_PATH}")

if __name__ == "__main__":
    process_terrain()
