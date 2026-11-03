import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def make_feature_graphic(input_path, title_main, title_sub, tagline, genre_tag, output_path, target_size=(1024, 500)):
    base = Image.open(input_path).convert("RGBA")
    
    bw, bh = base.size
    target_aspect = target_size[0] / float(target_size[1])
    current_aspect = bw / float(bh)

    if current_aspect > target_aspect:
        new_w = int(bh * target_aspect)
        left = (bw - new_w) // 2
        base = base.crop((left, 0, left + new_w, bh))
    else:
        new_h = int(bw / target_aspect)
        top = (bh - new_h) // 2
        base = base.crop((0, top, bw, top + new_h))

    base = base.resize(target_size, Image.Resampling.LANCZOS)
    overlay = Image.new("RGBA", target_size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Left-side atmospheric dark vignette for text contrast
    vignette_w = int(target_size[0] * 0.55)
    for x in range(vignette_w):
        ratio = x / float(vignette_w)
        alpha = int(225 * (1.0 - (ratio ** 1.6)))
        draw.line([(x, 0), (x, target_size[1])], fill=(5, 8, 12, alpha))

    # Top & bottom subtle edge vignettes
    for y in range(60):
        alpha = int(120 * (1.0 - (y / 60.0)))
        draw.line([(0, y), (target_size[0], y)], fill=(5, 8, 12, alpha))
        draw.line([(0, target_size[1] - 1 - y), (target_size[0], target_size[1] - 1 - y)], fill=(5, 8, 12, alpha))

    # Load typography fonts
    try:
        font_main = ImageFont.truetype("C:/Windows/Fonts/impact.ttf", 74)
        font_sub = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 28)
        font_tag = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 16)
        font_badge = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 14)
    except Exception:
        font_main = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 70)
        font_sub = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 28)
        font_tag = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 16)
        font_badge = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 14)

    x_pos = 65
    y_center = 175

    # Badge / Category
    badge_bg = [x_pos - 4, y_center - 48, x_pos + 185, y_center - 22]
    draw.rectangle(badge_bg, fill=(20, 26, 34, 200), outline=(225, 130, 25, 180), width=1)
    draw.text((x_pos + 12, y_center - 46), genre_tag.upper(), font=font_badge, fill=(245, 165, 45, 255))

    # Main Title (with multi-layer 3D shadow for impact)
    for off in [(4, 4), (3, 3), (2, 2), (1, 1), (-1, 1), (1, -1)]:
        draw.text((x_pos + off[0], y_center + off[1]), title_main.upper(), font=font_main, fill=(0, 0, 0, 230))
    draw.text((x_pos, y_center), title_main.upper(), font=font_main, fill=(255, 255, 255, 255))

    # Subtitle bar and text
    sub_y = y_center + 82
    draw.line([(x_pos, sub_y - 8), (x_pos + 320, sub_y - 8)], fill=(225, 130, 25, 240), width=3)
    draw.line([(x_pos, sub_y - 7), (x_pos + 140, sub_y - 7)], fill=(255, 195, 65, 180), width=1)

    draw.text((x_pos + 2, sub_y + 2), title_sub.upper(), font=font_sub, fill=(0, 0, 0, 230))
    draw.text((x_pos, sub_y), title_sub.upper(), font=font_sub, fill=(245, 160, 45, 255))

    # Tagline description
    tag_y = sub_y + 46
    draw.text((x_pos + 1, tag_y + 1), tagline, font=font_tag, fill=(0, 0, 0, 210))
    draw.text((x_pos, tag_y), tagline, font=font_tag, fill=(215, 225, 235, 245))

    result = Image.alpha_composite(base, overlay).convert("RGB")
    result.save(output_path, "PNG", quality=95)
    print(f"Generated Feature Graphic: {output_path} ({target_size[0]}x{target_size[1]})")

def make_app_icon(input_path, output_path, target_size=(512, 512)):
    base = Image.open(input_path).convert("RGBA")
    # Crop around the character & amber spores on right side
    bw, bh = base.size
    # Character is located around x = 0.65 to 0.95
    crop_size = min(bw, bh)
    crop_x = int(bw * 0.58)
    crop_y = int(bh * 0.15)
    
    # Adjust crop box
    box = (crop_x, crop_y, min(bw, crop_x + int(bh * 0.85)), min(bh, crop_y + int(bh * 0.85)))
    icon_crop = base.crop(box).resize(target_size, Image.Resampling.LANCZOS)

    overlay = Image.new("RGBA", target_size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Rounded border with amber glow
    border_w = 6
    draw.rectangle([0, 0, target_size[0]-1, target_size[1]-1], outline=(225, 130, 25, 220), width=border_w)

    result = Image.alpha_composite(icon_crop, overlay).convert("RGB")
    result.save(output_path, "PNG", quality=95)
    print(f"Generated App Icon: {output_path} ({target_size[0]}x{target_size[1]})")

if __name__ == "__main__":
    in_file = "d:/GodotProjects/perimeter/screenshots/google_play_cover_base.jpg"
    out_dir = "d:/GodotProjects/perimeter/screenshots"

    # 1. Russian Feature Graphic (1024x500)
    make_feature_graphic(
        in_file,
        title_main="ПЕРИМЕТР",
        title_sub="ЕГЕРЬ",
        tagline="Выживание и оборона в зараженной сибирской тайге",
        genre_tag="TAIGA SURVIVAL",
        output_path=os.path.join(out_dir, "google_play_cover_ru.png")
    )

    # 2. English Feature Graphic (1024x500)
    make_feature_graphic(
        in_file,
        title_main="PERIMETER",
        title_sub="WARDEN",
        tagline="Survive and hold the line in the spore-infected wilderness",
        genre_tag="TAIGA SURVIVAL",
        output_path=os.path.join(out_dir, "google_play_cover_en.png")
    )

    # 3. App Icon (512x512)
    make_app_icon(
        in_file,
        os.path.join(out_dir, "google_play_icon_512.png")
    )

    print("Google Play store assets generated successfully!")
