"""
Perimeter: Warden (Периметр) — 3D Asset Generator for Blender 3.x / 4.x
Generates low-poly stylized game assets for Godot 4:
1. Palisade Wall Module (Заострённый частокол)
2. Fortified Wooden Gate (Укреплённые ворота)
3. Guard Watchtower (Смотровая вышка)
4. Tectonic Amber Spotlight (Янтарный УФ-прожектор)
5. Amber Crystal Cluster (Тектонический янтарь)
6. Spore Canning Jar (Банка со споровыми железами)
7. Warden's Hunting Carbine ТОЗ-16 (Карабин егеря)
8. Steel Bear Trap (Стальной капкан)

Run from command line:
    blender --background --python scripts/blender/generate_perimeter_assets.py
Or open Blender -> Scripting tab -> Run Script.
"""

import bpy
import bmesh
import math
import os

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models"))
os.makedirs(OUTPUT_DIR, exist_ok=True)

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def export_active_object(filepath, obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        use_selection=True,
        export_format='GLB',
        export_apply=True
    )
    print(f"[Blender Export] Generated: {filepath}")

# ------------------------------------------------------------------------------
# 1. ЗАОСТРЁННЫЙ ЧАСТОКОЛ (Palisade Wall)
# ------------------------------------------------------------------------------
def generate_palisade_wall():
    clear_scene()
    bm = bmesh.new()

    # 4 вертикальных бревна со скошенными верхушками
    log_count = 4
    spacing = 0.6
    start_x = - (log_count - 1) * spacing / 2.0

    for i in range(log_count):
        x = start_x + i * spacing
        h = 2.4 + (0.15 if i % 2 == 1 else -0.1)
        # 8-гранный цилиндр бревна
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            cap_tris=False,
            segments=8,
            radius1=0.18,
            radius2=0.04, # Заострение на верхушке
            depth=h,
            matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((x, 0, h / 2.0))
        )

    # 2 горизонтальные поперечины
    for y_offset in [0.7, 1.8]:
        bmesh.ops.create_cube(
            bm,
            size=1.0,
            matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, -0.12, y_offset)) @ mathutils.Matrix.Scale(2.5, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.12, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.12, 4, (0, 0, 1))
        )

    mesh = bpy.data.meshes.new("PalisadeWall_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("PalisadeWall", mesh)
    bpy.context.collection.objects.link(obj)
    export_active_object(os.path.join(OUTPUT_DIR, "palisade_wall.glb"), obj)

# ------------------------------------------------------------------------------
# 2. УКРЕПЛЁННЫЕ ВОРОТА С ЗАСОВОМ (Fortified Gate)
# ------------------------------------------------------------------------------
def generate_fortified_gate():
    clear_scene()
    bm = bmesh.new()

    # Опорные массивные столбы
    for x in [-1.4, 1.4]:
        bmesh.ops.create_cube(
            bm,
            size=1.0,
            matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((x, 0, 1.5)) @ mathutils.Matrix.Scale(0.35, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.35, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(3.0, 4, (0, 0, 1))
        )

    # Верхняя арка / балка
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0, 2.9)) @ mathutils.Matrix.Scale(3.2, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.4, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.3, 4, (0, 0, 1))
    )

    # Полотно ворот с железной оковкой
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0, 1.35)) @ mathutils.Matrix.Scale(2.4, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.15, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(2.5, 4, (0, 0, 1))
    )

    # Диагональные балки жесткости (Z-распорка)
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0.1, 1.35)) @ mathutils.Matrix.Rotation(math.radians(35), 4, 'Y') @ mathutils.Matrix.Scale(2.8, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.08, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.18, 4, (0, 0, 1))
    )

    mesh = bpy.data.meshes.new("FortifiedGate_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("FortifiedGate", mesh)
    bpy.context.collection.objects.link(obj)
    export_active_object(os.path.join(OUTPUT_DIR, "fortified_gate.glb"), obj)

# ------------------------------------------------------------------------------
# 3. СМОТРОВАЯ ВЫШКА (Watchtower)
# ------------------------------------------------------------------------------
def generate_watchtower():
    clear_scene()
    bm = bmesh.new()

    h = 4.8
    # 4 угловых столба
    for x in [-1.3, 1.3]:
        for z in [-1.3, 1.3]:
            bmesh.ops.create_cube(
                bm,
                size=1.0,
                matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((x, z, h / 2.0)) @ mathutils.Matrix.Scale(0.25, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.25, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(h, 4, (0, 0, 1))
            )

    # Настил платформы
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0, h)) @ mathutils.Matrix.Scale(3.2, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(3.2, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.2, 4, (0, 0, 1))
    )

    # Перила
    for x, z, sx, sy in [(0, 1.5, 3.2, 0.1), (0, -1.5, 3.2, 0.1), (1.5, 0, 0.1, 3.0), (-1.5, 0, 0.1, 3.0)]:
        bmesh.ops.create_cube(
            bm,
            size=1.0,
            matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((x, z, h + 0.6)) @ mathutils.Matrix.Scale(sx, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(sy, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(1.0, 4, (0, 0, 1))
        )

    mesh = bpy.data.meshes.new("Watchtower_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("Watchtower", mesh)
    bpy.context.collection.objects.link(obj)
    export_active_object(os.path.join(OUTPUT_DIR, "watchtower.glb"), obj)

# ------------------------------------------------------------------------------
# 4. ТЕКТОНИЧЕСКИЙ ЯНТАРЬ (Amber Crystal Cluster)
# ------------------------------------------------------------------------------
def generate_amber_crystal():
    clear_scene()
    bm = bmesh.new()

    # Центральный крупный кристалл
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=6,
        radius1=0.25,
        radius2=0.02,
        depth=0.9,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0, 0.45))
    )

    # 3 боковых кристалла поменьше
    angles = [0.0, 2.1, 4.2]
    for ang in angles:
        cx = math.cos(ang) * 0.2
        cy = math.sin(ang) * 0.2
        rot = mathutils.Matrix.Rotation(math.radians(25), 4, (math.sin(ang), -math.cos(ang), 0))
        trans = mathutils.Matrix.Translation((cx, cy, 0.25))
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            segments=5,
            radius1=0.14,
            radius2=0.01,
            depth=0.55,
            matrix=bpy.context.scene.cursor.matrix @ trans @ rot
        )

    mesh = bpy.data.meshes.new("AmberCrystal_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("AmberCrystal", mesh)
    bpy.context.collection.objects.link(obj)
    export_active_object(os.path.join(OUTPUT_DIR, "amber_crystal.glb"), obj)

# ------------------------------------------------------------------------------
# 5. СТАЛЬНОЙ КАПКАН (Bear Trap)
# ------------------------------------------------------------------------------
def generate_bear_trap():
    clear_scene()
    bm = bmesh.new()

    # Круглое основание
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=12,
        radius1=0.45,
        radius2=0.45,
        depth=0.04,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0, 0.02))
    )

    # Центральная нажимная тарелка
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=10,
        radius1=0.2,
        radius2=0.2,
        depth=0.06,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0, 0.04))
    )

    # Зубчатые челюсти
    for side in [-0.35, 0.35]:
        bmesh.ops.create_cube(
            bm,
            size=1.0,
            matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((side, 0, 0.1)) @ mathutils.Matrix.Scale(0.1, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.7, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.12, 4, (0, 0, 1))
        )

    mesh = bpy.data.meshes.new("BearTrap_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("BearTrap", mesh)
    bpy.context.collection.objects.link(obj)
    export_active_object(os.path.join(OUTPUT_DIR, "beartrap.glb"), obj)

# ------------------------------------------------------------------------------
# 6. ОХОТНИЧИЙ КАРАБИН ТОЗ-16 (Hunting Carbine)
# ------------------------------------------------------------------------------
def generate_hunting_carbine():
    clear_scene()
    bm = bmesh.new()

    # Деревянное ложе / приклад
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0.15, -0.05)) @ mathutils.Matrix.Scale(0.06, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.48, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.14, 4, (0, 0, 1))
    )

    # Стальной ствол
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=8,
        radius1=0.022,
        radius2=0.018,
        depth=0.85,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, -0.32, 0.03)) @ mathutils.Matrix.Rotation(math.radians(90), 4, 'X')
    )

    # Ствольная коробка и затвор
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, 0.05, 0.03)) @ mathutils.Matrix.Scale(0.05, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.22, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.06, 4, (0, 0, 1))
    )

    # Мушка (прицел)
    bmesh.ops.create_cube(
        bm,
        size=1.0,
        matrix=bpy.context.scene.cursor.matrix @ mathutils.Matrix.Translation((0, -0.72, 0.06)) @ mathutils.Matrix.Scale(0.015, 4, (1, 0, 0)) @ mathutils.Matrix.Scale(0.02, 4, (0, 1, 0)) @ mathutils.Matrix.Scale(0.04, 4, (0, 0, 1))
    )

    mesh = bpy.data.meshes.new("Carbine_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("HuntingCarbine", mesh)
    bpy.context.collection.objects.link(obj)
    export_active_object(os.path.join(OUTPUT_DIR, "hunting_carbine.glb"), obj)

def main():
    import mathutils
    globals()['mathutils'] = mathutils
    print("=== PERIMETER BLENDER ASSET PIPELINE STARTING ===")
    generate_palisade_wall()
    generate_fortified_gate()
    generate_watchtower()
    generate_amber_crystal()
    generate_bear_trap()
    generate_hunting_carbine()
    print("=== PERIMETER BLENDER ASSET PIPELINE FINISHED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
