"""
Perimeter: Warden (Периметр) — Landscape Sculpting Template Generator
Creates a production-ready 1000x1000m terrain template in Blender:
- Subdivided landscape mesh with valley topography (Northern ridge, Riverbed, Outpost plateau)
- Vertex Groups for sculpting masks (Base_Outpost, North_Ridge, River_Bed, West_Town, East_Taiga)
- POI Markers (Empties) for visual landmark orientation
- Viewport shader with flat shading & altitude color gradient matching Godot valley_terrain.gdshader
- Camera and viewport clip distances configured for 1000m scale

Usage:
    blender --background --python scripts/blender/create_terrain_template.py
"""

import bpy
import bmesh
import math
import os

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)

def create_terrain_template():
    clear_scene()

    # 1. Создаем коллекцию Guides и POI
    poi_col = bpy.data.collections.new("POI_Guides")
    bpy.context.scene.collection.children.link(poi_col)

    # Список ключевых точек (Blender coords: X=Godot X, Y=-Godot Z, Z=Godot Y)
    pois = [
        ("POI_Дом_Егеря (Base)", (320.0, -120.0, 0.0), (0.2, 0.9, 0.3)),
        ("POI_Серные_Штольни", (40.0, 380.0, 24.0), (0.9, 0.8, 0.2)),
        ("POI_Пещера_Шнека", (-120.0, 440.0, 18.5), (0.7, 0.3, 0.9)),
        ("POI_Рыбацкие_Мостки", (15.0, -310.0, -8.0), (0.2, 0.6, 1.0)),
        ("POI_АЗС_Северная", (-320.0, 40.0, 1.2), (0.9, 0.4, 0.2)),
        ("POI_Медвежий_Бурелом", (380.0, 80.0, 3.0), (0.1, 0.5, 0.2)),
    ]

    for name, loc, color in pois:
        empty = bpy.data.objects.new(name, None)
        empty.empty_display_type = 'SPHERE'
        empty.empty_display_size = 25.0
        empty.location = loc
        poi_col.objects.link(empty)

    # 2. Создаем меш ландшафта 1000х1000 м
    # Сетка 140х140 вершин (~7.1 м на грань) — идеальный баланс детализации и производительности
    res = 140
    size = 1000.0
    half_size = size / 2.0
    step = size / float(res - 1)

    mesh = bpy.data.meshes.new("Terrain_1000x1000")
    obj = bpy.data.objects.new("Terrain_1000x1000", mesh)
    bpy.context.scene.collection.objects.link(obj)

    # Подготавливаем вершины и полигоны
    verts = []
    uvs = []

    # Функция базовой высоты (Godot coords: x, z = -y)
    def calc_base_height(x, y_blender):
        z_godot = -y_blender

        # База лесника (320, 120) - ровная площадка
        dist_outpost = max(abs(x - 320.0), abs(z_godot - 120.0))
        outpost_mask = max(0.0, min(1.0, (dist_outpost - 45.0) / 25.0))

        # Северные горы (Z_godot < -70 -> Y_blender > 70)
        north_h = 0.0
        if z_godot < -70.0:
            n_fac = max(0.0, min(1.0, (-z_godot - 70.0) / 380.0))
            # Проходы
            cave_pass = max(0.0, min(1.0, abs(x - (-120.0)) / 65.0))
            sulfur_pass = max(0.0, min(1.0, abs(x - 40.0) / 65.0))
            v_pass = min(cave_pass, sulfur_pass)
            crags = math.sin(x * 0.02) * math.cos(z_godot * 0.016) * 20.0 + math.sin(x * 0.05) * 8.0
            north_h = (n_fac * 55.0 + crags * (0.4 + 0.6 * v_pass)) * n_fac

        # Западные горы (X < -260)
        west_h = 0.0
        if x < -260.0:
            w_fac = max(0.0, min(1.0, (-x - 260.0) / 200.0))
            pass_z = max(0.0, min(1.0, abs(z_godot - (-15.0)) / 65.0))
            west_h = (w_fac * 48.0 + math.sin(z_godot * 0.02) * 10.0) * w_fac * pass_z

        # Восточный хребет (X > 350)
        east_h = 0.0
        if x > 350.0:
            e_fac = max(0.0, min(1.0, (x - 350.0) / 140.0))
            east_h = (e_fac * 52.0 + math.sin(z_godot * 0.018) * 10.0) * e_fac

        # Река на юге (Z_godot > 380 -> Y_blender < -380)
        river_depth = 0.0
        if z_godot > 380.0:
            s_fac = max(0.0, min(1.0, (z_godot - 380.0) / 100.0))
            river_depth = -10.0 * s_fac
        elif z_godot > 230.0:
            # Залив реки по центру
            dist_inlet = abs(x - 15.0)
            if dist_inlet < 36.0:
                inlet_norm = dist_inlet / 36.0
                z_inlet = max(0.0, min(1.0, (z_godot - 230.0) / 70.0))
                river_depth = -9.0 * (1.0 - inlet_norm * inlet_norm) * z_inlet

        total_h = (max(north_h, max(west_h, east_h)) + river_depth) * outpost_mask
        return total_h

    # Генерация вершин сетки
    for iz in range(res):
        y_b = half_size - float(iz) * step
        for ix in range(res):
            x_b = -half_size + float(ix) * step
            z_b = calc_base_height(x_b, y_b)
            verts.append((x_b, y_b, z_b))
            uvs.append((float(ix) / (res - 1), float(iz) / (res - 1)))

    faces = []
    for iz in range(res - 1):
        for ix in range(res - 1):
            i0 = iz * res + ix
            i1 = i0 + 1
            i2 = (iz + 1) * res + ix + 1
            i3 = (iz + 1) * res + ix
            faces.append((i0, i1, i2, i3))

    mesh.from_pydata(verts, [], faces)
    mesh.update()

    # 3. Назначение плоского затенения (Flat Shading)
    for p in mesh.polygons:
        p.use_smooth = False

    # 4. Вертексные группы (маски для скульптинга)
    vg_outpost = obj.vertex_groups.new(name="Base_Outpost_Lock")
    vg_north = obj.vertex_groups.new(name="Zone_North_Ridge")
    vg_river = obj.vertex_groups.new(name="Zone_River_Bed")
    vg_town = obj.vertex_groups.new(name="Zone_West_Town")
    vg_taiga = obj.vertex_groups.new(name="Zone_East_Taiga")

    for i, (x_b, y_b, z_b) in enumerate(verts):
        z_godot = -y_b
        # База (квадрат 100х100м вокруг 320, 120)
        dist_outpost = max(abs(x_b - 320.0), abs(z_godot - 120.0))
        if dist_outpost <= 55.0:
            weight = 1.0 - max(0.0, min(1.0, (dist_outpost - 45.0) / 10.0))
            vg_outpost.add([i], weight, 'REPLACE')

        # Север
        if z_godot < -100.0:
            vg_north.add([i], 1.0, 'REPLACE')
        # Река
        if z_godot > 240.0:
            vg_river.add([i], 1.0, 'REPLACE')
        # Поселок
        if x_b < -170.0 and 160.0 < z_godot < 400.0:
            vg_town.add([i], 1.0, 'REPLACE')
        # Тайга
        if x_b > 100.0:
            vg_taiga.add([i], 1.0, 'REPLACE')

    # 5. Стилизованный шейдер долины для вьюпорта Blender
    mat = bpy.data.materials.new(name="M_Terrain_Valley")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    # Создаем ноды: Geometry -> Separate XYZ (высота Z) -> ColorRamp -> Principled BSDF -> Output
    geom_node = nodes.new(type="ShaderNodeNewGeometry")
    geom_node.location = (-600, 200)

    sep_node = nodes.new(type="ShaderNodeSeparateXYZ")
    sep_node.location = (-400, 200)

    ramp_node = nodes.new(type="ShaderNodeValToRGB")
    ramp_node.location = (-180, 200)
    ramp_node.color_ramp.interpolation = 'CONSTANT' # Flat banded colors

    # Градиент биомов по высоте (как в Godot valley_terrain.gdshader)
    # Позиция 0.0 (-15м): Вода / Речной ил (0.12, 0.16, 0.14)
    # Позиция 0.2 (0..4м): Свежая луговая зелень (0.34, 0.44, 0.22)
    # Позиция 0.5 (15..35м): Скалистые склоны (0.42, 0.38, 0.32)
    # Позиция 0.8 (>36м): Белоснежные известняковые пики (0.86, 0.88, 0.90)
    ramp = ramp_node.color_ramp
    ramp.elements[0].position = 0.12
    ramp.elements[0].color = (0.62, 0.56, 0.40, 1.0) # Песчаный берег
    ramp.elements[1].position = 0.22
    ramp.elements[1].color = (0.28, 0.42, 0.20, 1.0) # Сочная трава долины

    e2 = ramp.elements.new(0.48)
    e2.color = (0.38, 0.35, 0.30, 1.0) # Горные скалы

    e3 = ramp.elements.new(0.72)
    e3.color = (0.88, 0.90, 0.92, 1.0) # Снежные вершины

    # Нормализатор высоты (-15м .. +95м -> 0.0 .. 1.0)
    map_node = nodes.new(type="ShaderNodeMapRange")
    map_node.location = (-380, 200)
    map_node.inputs['From Min'].default_value = -12.0
    map_node.inputs['From Max'].default_value = 85.0
    map_node.inputs['To Min'].default_value = 0.0
    map_node.inputs['To Max'].default_value = 1.0

    links.new(geom_node.outputs['Position'], sep_node.inputs['Vector'])
    links.new(sep_node.outputs['Z'], map_node.inputs['Value'])
    links.new(map_node.outputs['Result'], ramp_node.inputs['Fac'])

    bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    bsdf.location = (150, 200)
    bsdf.inputs['Roughness'].default_value = 0.9
    links.new(ramp_node.outputs['Color'], bsdf.inputs['Base Color'])

    out_node = nodes.new(type="ShaderNodeOutputMaterial")
    out_node.location = (450, 200)
    links.new(bsdf.outputs['BSDF'], out_node.inputs['Surface'])

    obj.data.materials.append(mat)

    # 6. Настройка камеры и вьюпорта
    cam_data = bpy.data.cameras.new("OverviewCamera")
    cam_data.clip_end = 3500.0
    cam_obj = bpy.data.objects.new("OverviewCamera", cam_data)
    cam_obj.location = (0.0, -850.0, 650.0)
    cam_obj.rotation_euler = (math.radians(55.0), 0.0, 0.0)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    # Направленный свет (Солнце)
    sun_data = bpy.data.lights.new(name="SunLight", type='SUN')
    sun_data.energy = 2.5
    sun_data.color = (1.0, 0.92, 0.8)
    sun_obj = bpy.data.objects.new("SunLight", sun_data)
    sun_obj.rotation_euler = (math.radians(45.0), math.radians(25.0), math.radians(-35.0))
    bpy.context.scene.collection.objects.link(sun_obj)

    # Выделяем меш и делаем его активным для мгновенного входа в Sculpt Mode
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    return obj

if __name__ == "__main__":
    obj = create_terrain_template()

    # Сохраняем .blend шаблон
    project_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    assets_dir = os.path.join(project_dir, "assets")
    os.makedirs(assets_dir, exist_ok=True)

    blend_path = os.path.join(assets_dir, "terrain_template.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"[Blender Template] Saved: {blend_path}")

    # Экспортируем стартовый .glb для Godot
    glb_path = os.path.join(assets_dir, "terrain_sculpt.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        use_selection=True,
        export_format='GLB',
        export_apply=True
    )
    print(f"[Blender Template] Exported GLB: {glb_path}")
