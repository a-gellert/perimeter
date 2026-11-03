import os
from PIL import Image, ImageDraw, ImageFont

def render_store_screenshot(input_path, badge, title, subtitle, output_path):
    img = Image.open(input_path).convert("RGBA")
    w, h = 1920, 1080
    img = img.resize((w, h), Image.Resampling.LANCZOS)

    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Gradient header bar at top with deep dark tones
    header_h = 168
    for y in range(header_h):
        ratio = y / float(header_h)
        # Deep dark blue/charcoal atmosphere
        alpha = int(245 * (1.0 - (ratio ** 2.0)))
        draw.line([(0, y), (w, y)], fill=(6, 8, 12, alpha))

    # Amber branding accent strip
    accent_y = 144
    draw.line([(0, accent_y), (w, accent_y)], fill=(225, 125, 30, 230), width=3)
    draw.line([(0, accent_y + 1), (w, accent_y + 1)], fill=(255, 170, 50, 140), width=1)

    # Load system fonts
    try:
        font_badge = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 20)
        font_title = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 45)
        font_sub = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 23)
        font_brand = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 20)
    except Exception:
        font_badge = ImageFont.load_default()
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()
        font_brand = ImageFont.load_default()

    # Draw Badge
    draw.text((80, 20), badge.upper(), font=font_badge, fill=(245, 155, 45, 245))

    # Draw Title with drop shadow
    shadow = 2
    draw.text((80 + shadow, 48 + shadow), title.upper(), font=font_title, fill=(0, 0, 0, 220))
    draw.text((80, 48), title.upper(), font=font_title, fill=(255, 255, 255, 255))

    # Draw Subtitle with subtle shadow
    draw.text((80 + shadow, 104 + shadow), subtitle, font=font_sub, fill=(0, 0, 0, 200))
    draw.text((80, 104), subtitle, font=font_sub, fill=(220, 228, 235, 245))

    # Right-aligned game title badge
    brand_text = "PERIMETER: WARDEN"
    brand_bbox = draw.textbbox((0, 0), brand_text, font=font_brand)
    brand_w = brand_bbox[2] - brand_bbox[0]
    draw.text((w - 80 - brand_w, 22), brand_text, font=font_brand, fill=(245, 155, 45, 210))

    # Combine and save
    result = Image.alpha_composite(img, overlay).convert("RGB")
    result.save(output_path, "PNG", quality=95)
    print(f"Generated: {output_path}")

cards = [
    {
        "file": "dark_crafting.jpg",
        "ru": {
            "badge": "Укрепление периметра",
            "title": "Крафт и оборона базы",
            "subtitle": "Возводите частокол и обустраивайте кордон до наступления смертоносной тьмы"
        },
        "en": {
            "badge": "Base Fortification",
            "title": "Craft & Fortify Your Base",
            "subtitle": "Erect heavy log palisades and prepare your outpost before darkness falls"
        },
        "prefix": "dark_promo_01_crafting"
    },
    {
        "file": "dark_forest.jpg",
        "ru": {
            "badge": "Открытый мир тайги",
            "title": "Исследование зараженного леса",
            "subtitle": "Сквозь холодный туман и ядовитые споры — вглубь дикой сибирской глуши"
        },
        "en": {
            "badge": "Infected Wilderness",
            "title": "Explore the Spore-Ridden Taiga",
            "subtitle": "Trek through chilling mists and toxic spore growth across the northern wilderness"
        },
        "prefix": "dark_promo_02_forest"
    },
    {
        "file": "dark_fishing.jpg",
        "ru": {
            "badge": "Промысел и выживание",
            "title": "Рыбалка в ледяных водах",
            "subtitle": "Добывайте скудное пропитание на пустынном пирсе в глухом речном тумане"
        },
        "en": {
            "badge": "Survival Foraging",
            "title": "Glacial River Fishing",
            "subtitle": "Catch vital food from freezing mountain waters shrouded in desolate mist"
        },
        "prefix": "dark_promo_03_fishing"
    },
    {
        "file": "dark_zombies.jpg",
        "ru": {
            "badge": "Ночной кошмар",
            "title": "Отстрел споровых мутантов",
            "subtitle": "Сдерживайте натиск орды в свете прожекторов, выстрелов карабина и капканов"
        },
        "en": {
            "badge": "Nocturnal Defense",
            "title": "Repel the Spore Horde",
            "subtitle": "Survive midnight swarms of mutants with rifle fire, searchlights, and bear traps"
        },
        "prefix": "dark_promo_04_zombies"
    }
]

base_dir = "d:/GodotProjects/perimeter/screenshots"
for card in cards:
    in_img = os.path.join(base_dir, card["file"])
    # Russian
    out_ru = os.path.join(base_dir, f"{card['prefix']}_ru.png")
    render_store_screenshot(in_img, card["ru"]["badge"], card["ru"]["title"], card["ru"]["subtitle"], out_ru)
    # English
    out_en = os.path.join(base_dir, f"{card['prefix']}_en.png")
    render_store_screenshot(in_img, card["en"]["badge"], card["en"]["title"], card["en"]["subtitle"], out_en)

print("All dark atmospheric bilingual store screenshots successfully generated!")
