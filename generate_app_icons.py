import os
import math
from PIL import Image, ImageDraw, ImageFilter

def create_unified_smart_home_icon(size=2048, is_round=False):
    # 1. Base Image
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    
    # 2. Draw Deep Space Background with Radial Gradient
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    bg_draw = ImageDraw.Draw(bg)
    
    cx, cy = size // 2, size // 2
    max_radius = int(size * 0.72)
    
    # Render smooth cosmic gradient
    for r in range(max_radius, 0, -8):
        t = r / max_radius
        # Interpolate between deep space black (5, 8, 18) and midnight cyan-navy (18, 30, 62)
        red = int(5 * t + 22 * (1 - t))
        green = int(8 * t + 36 * (1 - t))
        blue = int(18 * t + 78 * (1 - t))
        bg_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(red, green, blue, 255))
        
    # 3. Add Ambient Ecosystem Glows (Auras)
    aura = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    
    # Samsung Cyan Aura (Top)
    aura_draw.ellipse([cx - 450, cy - 650, cx + 450, cy + 250], fill=(0, 229, 255, 60))
    # LG Ruby Aura (Bottom Left)
    aura_draw.ellipse([cx - 650, cy - 200, cx + 150, cy + 600], fill=(255, 42, 109, 50))
    # Philips Hue Golden Ambient Glow (Center Core)
    aura_draw.ellipse([cx - 300, cy - 100, cx + 300, cy + 500], fill=(255, 180, 0, 70))
    # Matter Emerald Aura (Right)
    aura_draw.ellipse([cx + 50, cy - 150, cx + 650, cy + 450], fill=(0, 230, 118, 40))
    
    aura = aura.filter(ImageFilter.GaussianBlur(radius=110))
    bg.alpha_composite(aura)
    
    # 4. Concentric Matter / Smart Mesh Rings
    mesh_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mesh_draw = ImageDraw.Draw(mesh_layer)
    
    # Outer mesh orbit ring
    mesh_draw.ellipse([cx - 720, cy - 720, cx + 720, cy + 720], outline=(255, 255, 255, 25), width=4)
    mesh_draw.ellipse([cx - 560, cy - 560, cx + 560, cy + 560], outline=(0, 229, 255, 35), width=3)
    
    # Diagonal connection axes (45 deg)
    axis_color = (255, 255, 255, 30)
    mesh_draw.line([cx - 600, cy - 600, cx + 600, cy + 600], fill=axis_color, width=2)
    mesh_draw.line([cx - 600, cy + 600, cx + 600, cy - 600], fill=axis_color, width=2)
    
    bg.alpha_composite(mesh_layer)
    
    # 5. 3D Isometric Spatial Glass House
    house_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(house_layer)
    
    # Geometric Coordinates for Isometric Pavilion
    # Scale relative to 2048
    s = size / 2048.0
    
    top_v = (1024 * s, 480 * s)
    left_v = (560 * s, 750 * s)
    right_v = (1488 * s, 750 * s)
    center_v = (1024 * s, 1020 * s)
    bot_left_v = (560 * s, 1310 * s)
    bot_right_v = (1488 * s, 1310 * s)
    bot_v = (1024 * s, 1580 * s)
    
    # A. Top Facet / Roof (Samsung SmartThings Electric Cyan & Apple Spatial Glass)
    # Polygon: top_v -> right_v -> center_v -> left_v
    roof_poly = [top_v, right_v, center_v, left_v]
    h_draw.polygon(roof_poly, fill=(0, 200, 255, 210))
    
    # Internal roof gradient highlights
    for i in range(1, 30):
        factor = i / 30.0
        p1 = (top_v[0] + (left_v[0] - top_v[0]) * factor, top_v[1] + (left_v[1] - top_v[1]) * factor)
        p2 = (top_v[0] + (right_v[0] - top_v[0]) * factor, top_v[1] + (right_v[1] - top_v[1]) * factor)
        p3 = (center_v[0] + (right_v[0] - center_v[0]) * (1 - factor), center_v[1] + (right_v[1] - center_v[1]) * (1 - factor))
        p4 = (center_v[0] + (left_v[0] - center_v[0]) * (1 - factor), center_v[1] + (left_v[1] - center_v[1]) * (1 - factor))
        
        red = int(0 + 20 * factor)
        green = int(240 - 70 * factor)
        blue = int(255)
        alpha = int(210 - 60 * factor)
        h_draw.polygon([p1, p2, p3, p4], fill=(red, green, blue, alpha))
        
    # B. Left Facet / Wall (LG ThinQ Ruby / Rose Magenta Glass)
    # Polygon: left_v -> center_v -> bot_v -> bot_left_v
    left_poly = [left_v, center_v, bot_v, bot_left_v]
    h_draw.polygon(left_poly, fill=(230, 20, 80, 220))
    
    for i in range(1, 25):
        factor = i / 25.0
        p1 = (left_v[0] + (center_v[0] - left_v[0]) * factor, left_v[1] + (center_v[1] - left_v[1]) * factor)
        p2 = (bot_left_v[0] + (bot_v[0] - bot_left_v[0]) * factor, bot_left_v[1] + (bot_v[1] - bot_left_v[1]) * factor)
        red = int(255 - 75 * factor)
        green = int(40 + 20 * factor)
        blue = int(110 - 40 * factor)
        alpha = int(220 - 40 * factor)
        h_draw.polygon([left_v, p1, p2, bot_left_v], fill=(red, green, blue, alpha))
        
    # C. Right Facet / Wall (Deep Obsidian Sapphire Glass with Interior Reflections)
    # Polygon: center_v -> right_v -> bot_right_v -> bot_v
    right_poly = [center_v, right_v, bot_right_v, bot_v]
    h_draw.polygon(right_poly, fill=(15, 30, 60, 230))
    
    for i in range(1, 25):
        factor = i / 25.0
        p1 = (center_v[0] + (right_v[0] - center_v[0]) * factor, center_v[1] + (right_v[1] - center_v[1]) * factor)
        p2 = (bot_v[0] + (bot_right_v[0] - bot_v[0]) * factor, bot_v[1] + (bot_right_v[1] - bot_v[1]) * factor)
        red = int(15 + 20 * factor)
        green = int(35 + 40 * factor)
        blue = int(75 + 75 * factor)
        alpha = int(230 - 30 * factor)
        h_draw.polygon([center_v, p1, p2, bot_v], fill=(red, green, blue, alpha))
        
    # D. Inner Frosted Cutaway Living Room Window (Left Wall)
    # Luminous warm amber home interior
    w_top = (left_v[0] + (center_v[0] - left_v[0]) * 0.28, left_v[1] + (center_v[1] - left_v[1]) * 0.28 + 60 * s)
    w_right = (left_v[0] + (center_v[0] - left_v[0]) * 0.75, left_v[1] + (center_v[1] - left_v[1]) * 0.75 + 60 * s)
    w_bot = (bot_left_v[0] + (bot_v[0] - bot_left_v[0]) * 0.75, bot_left_v[1] + (bot_v[1] - bot_left_v[1]) * 0.75 - 60 * s)
    w_left = (bot_left_v[0] + (bot_v[0] - bot_left_v[0]) * 0.28, bot_left_v[1] + (bot_v[1] - bot_left_v[1]) * 0.28 - 60 * s)
    
    h_draw.polygon([w_top, w_right, w_bot, w_left], fill=(255, 185, 30, 240))
    
    # E. Inner Glass Facet Edge Outlines & Bevel Highlights (Specular Refractions)
    edge_color_bright = (255, 255, 255, 240)
    edge_color_cyan = (0, 229, 255, 220)
    edge_color_ruby = (255, 64, 129, 200)
    
    # Outer silhouette edges
    h_draw.line([top_v, right_v], fill=edge_color_bright, width=int(7 * s))
    h_draw.line([top_v, left_v], fill=edge_color_bright, width=int(7 * s))
    h_draw.line([left_v, center_v], fill=edge_color_bright, width=int(5 * s))
    h_draw.line([right_v, center_v], fill=edge_color_bright, width=int(5 * s))
    h_draw.line([center_v, bot_v], fill=edge_color_bright, width=int(8 * s))
    h_draw.line([left_v, bot_left_v], fill=edge_color_ruby, width=int(6 * s))
    h_draw.line([bot_left_v, bot_v], fill=edge_color_ruby, width=int(6 * s))
    h_draw.line([right_v, bot_right_v], fill=edge_color_cyan, width=int(6 * s))
    h_draw.line([bot_right_v, bot_v], fill=edge_color_cyan, width=int(6 * s))
    
    bg.alpha_composite(house_layer)
    
    # 6. Central Quantum Smart Nexus Core (Floating Radiant Fusion Core)
    core_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    core_draw = ImageDraw.Draw(core_layer)
    
    core_cx = int(center_v[0])
    core_cy = int(center_v[1] + 130 * s)
    core_rad = int(140 * s)
    
    # Outer bloom
    for cr in range(core_rad + 100, core_rad, -5):
        alpha = int(120 * (1.0 - (cr - core_rad) / 100.0))
        core_draw.ellipse([core_cx - cr, core_cy - cr, core_cx + cr, core_cy + cr], fill=(255, 170, 0, alpha))
        
    # Solid luminous core
    core_draw.ellipse([core_cx - core_rad, core_cy - core_rad, core_cx + core_rad, core_cy + core_rad], fill=(255, 235, 170, 255))
    
    # Smart Home Roof Icon Silhouette Inside Core
    # Subtle crisp icon of a house inside the quantum sun
    hs_top = (core_cx, core_cy - int(60 * s))
    hs_left = (core_cx - int(60 * s), core_cy)
    hs_right = (core_cx + int(60 * s), core_cy)
    hs_bot_left = (core_cx - int(45 * s), core_cy + int(50 * s))
    hs_bot_right = (core_cx + int(45 * s), core_cy + int(50 * s))
    
    core_draw.polygon([hs_top, hs_right, (core_cx + int(45 * s), core_cy), hs_bot_right, hs_bot_left, (core_cx - int(45 * s), core_cy), hs_left], fill=(20, 25, 45, 240))
    
    # 7. Interconnected Satellite Brand Nodes (SmartThings, ThinQ, Matter, Hue)
    nodes = [
        # (x, y, color, size, label)
        (core_cx, int(top_v[1] - 40 * s), (0, 229, 255, 255), 45 * s),      # Top: SmartThings Cyan
        (int(left_v[0] - 80 * s), int(left_v[1] + 80 * s), (255, 42, 109, 255), 42 * s),  # Left: LG ThinQ Ruby
        (int(right_v[0] + 80 * s), int(right_v[1] + 80 * s), (0, 230, 118, 255), 42 * s), # Right: Matter / Tuya Emerald
        (core_cx, int(bot_v[1] + 90 * s), (255, 180, 0, 255), 40 * s),      # Bottom: Philips Hue Amber
    ]
    
    for nx, ny, ncol, nrad in nodes:
        # Connecting trace line
        core_draw.line([core_cx, core_cy, nx, ny], fill=(ncol[0], ncol[1], ncol[2], 90), width=int(4 * s))
        # Node glow
        core_draw.ellipse([nx - nrad * 1.8, ny - nrad * 1.8, nx + nrad * 1.8, ny + nrad * 1.8], fill=(ncol[0], ncol[1], ncol[2], 60))
        # Node solid center
        core_draw.ellipse([nx - nrad, ny - nrad, nx + nrad, ny + nrad], fill=ncol)
        core_draw.ellipse([nx - nrad * 0.45, ny - nrad * 0.45, nx + nrad * 0.45, ny + nrad * 0.45], fill=(255, 255, 255, 255))
        
    bg.alpha_composite(core_layer)
    
    # 8. Apple VisionOS / iOS 26 Liquid Glass Bevel & Frosted Mask
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    
    if is_round:
        # Perfectly round icon for Android round icon
        mask_draw.ellipse([32 * s, 32 * s, size - 32 * s, size - 32 * s], fill=255)
    else:
        # Modern continuous squircle with 22.5% radius
        corner_r = int(size * 0.22)
        mask_draw.rounded_rectangle([32 * s, 32 * s, size - 32 * s, size - 32 * s], radius=corner_r, fill=255)
        
    # Apply Mask to get pristine icon edges
    final_icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final_icon.paste(bg, (0, 0), mask)
    
    # Specular Glass Bevel Stroke around Squircle
    bevel_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bevel_draw = ImageDraw.Draw(bevel_layer)
    
    if is_round:
        bevel_draw.ellipse([32 * s, 32 * s, size - 32 * s, size - 32 * s], outline=(255, 255, 255, 75), width=int(6 * s))
    else:
        bevel_draw.rounded_rectangle([32 * s, 32 * s, size - 32 * s, size - 32 * s], radius=corner_r, outline=(255, 255, 255, 75), width=int(6 * s))
        
    final_icon.alpha_composite(bevel_layer)
    
    return final_icon

def export_all_icon_densities(master_square, master_round, res_root):
    densities = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    
    for folder, dim in densities.items():
        out_dir = os.path.join(res_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        
        sq = master_square.resize((dim, dim), Image.Resampling.LANCZOS)
        sq.save(os.path.join(out_dir, 'ic_launcher.png'), 'PNG', optimize=True)
        
        rd = master_round.resize((dim, dim), Image.Resampling.LANCZOS)
        rd.save(os.path.join(out_dir, 'ic_launcher_round.png'), 'PNG', optimize=True)
        print(f'Exported {folder}: {dim}x{dim}')
        
    # Also save master 1024 and 512
    assets_dir = os.path.join(res_root, '..', '..', '..', '..', 'assets', 'icon')
    os.makedirs(assets_dir, exist_ok=True)
    
    m1024 = master_square.resize((1024, 1024), Image.Resampling.LANCZOS)
    m1024.save(os.path.join(assets_dir, 'app_icon_1024.png'), 'PNG', optimize=True)
    
    m512 = master_square.resize((512, 512), Image.Resampling.LANCZOS)
    m512.save(os.path.join(assets_dir, 'app_icon_512.png'), 'PNG', optimize=True)
    print('Master 1024 and 512 saved in assets/icon/')

if __name__ == '__main__':
    print('Generating Ultra-Luxury 2048x2048 Unified Smart Home Icons...')
    sq = create_unified_smart_home_icon(2048, is_round=False)
    rd = create_unified_smart_home_icon(2048, is_round=True)
    
    res_dir = r'c:\Users\ghans\Documents\antigravity\nifty-kepler\unified_home\android\app\src\main\res'
    export_all_icon_densities(sq, rd, res_dir)
    print('Icon generation complete!')
