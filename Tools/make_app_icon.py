import math, subprocess
from PIL import Image, ImageDraw

def drop_path(cx, cy, s):
    top = cy - s * 1.55
    return (f"M {cx} {top} C {cx + s*0.35} {cy - s*0.95}, {cx + s} {cy - s*0.35}, {cx + s} {cy + s*0.15} "
            f"A {s} {s} 0 1 1 {cx - s} {cy + s*0.15} C {cx - s} {cy - s*0.35}, {cx - s*0.35} {cy - s*0.95}, {cx} {top} Z")

def frame(inner, p):
    cx = cy = 512; r = 330
    def pt(a): return cx + r*math.cos(math.radians(a)), cy + r*math.sin(math.radians(a))
    x1, y1 = pt(-90); x2, y2 = pt(190)
    bg = "" if p.get("nobg") else '<rect width="1024" height="1024" fill="url(#bg)"/>'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{p['bg_a']}"/><stop offset="1" stop-color="{p['bg_b']}"/></linearGradient>
<linearGradient id="ring" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{p['ring']}"/><stop offset="1" stop-color="{p['ring_end']}"/></linearGradient>
<linearGradient id="apple" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{p['food']}"/><stop offset="1" stop-color="{p['food_end']}"/></linearGradient></defs>
{bg}
<circle cx="512" cy="512" r="{r}" fill="none" stroke="{p['track']}" stroke-width="64"/>
<path d="M {x1:.1f} {y1:.1f} A {r} {r} 0 1 1 {x2:.1f} {y2:.1f}" fill="none" stroke="url(#ring)" stroke-width="64" stroke-linecap="round"/>
<circle cx="512" cy="512" r="250" fill="{p['plate']}"/>
{inner(p)}
</svg>'''

def apple(p):
    body = ("M 512 452 C 470 418, 372 420, 364 515 C 356 610, 426 690, 470 698 "
            "C 492 702, 500 690, 512 690 C 524 690, 532 702, 554 698 "
            "C 598 690, 668 610, 660 515 C 652 420, 554 418, 512 452 Z")
    leaf = f'<path d="{drop_path(0, 0, 44)}" fill="{p["drop"]}" transform="translate(566 382) rotate(38)"/>'
    stem = f'<path d="M 512 455 Q 506 410 520 380" fill="none" stroke="{p["stem"]}" stroke-width="16" stroke-linecap="round"/>'
    shine = f'<ellipse cx="432" cy="540" rx="20" ry="52" fill="{p["shine"]}" transform="rotate(14 432 540)"/>'
    return stem + f'<path d="{body}" fill="url(#apple)"/>' + leaf + shine

def fork_drop(p):
    c = p["fork"]
    fork = (f'<g stroke="{c}" stroke-linecap="round" fill="none">'
            f'<line x1="400" y1="380" x2="400" y2="470" stroke-width="20"/>'
            f'<line x1="440" y1="380" x2="440" y2="470" stroke-width="20"/>'
            f'<line x1="480" y1="380" x2="480" y2="470" stroke-width="20"/>'
            f'<path d="M 400 470 Q 400 525 440 530 Q 480 525 480 470" stroke-width="20"/>'
            f'<line x1="440" y1="530" x2="440" y2="650" stroke-width="30"/></g>')
    drop = f'<path d="{drop_path(588, 560, 74)}" fill="{p["drop"]}"/>'
    shine = f'<ellipse cx="560" cy="572" rx="14" ry="30" fill="{p["shine"]}" transform="rotate(20 560 572)"/>'
    return fork + drop + shine

themes = {
 "light":  dict(bg_a="#3BD1C2", bg_b="#0B8F85", track="rgba(255,255,255,0.28)", ring="#FFB062", ring_end="#E8590C",
                plate="#FFFFFF", food="#FFB062", food_end="#E8590C", drop="#0E9F94", stem="#7A4A1E", fork="#0A6E66", shine="rgba(255,255,255,0.5)"),
 "dark":   dict(bg_a="#10302C", bg_b="#06140F", track="rgba(255,255,255,0.10)", ring="#FFAD5C", ring_end="#FF7A33",
                plate="#16413B", food="#FFAD5C", food_end="#FF7A33", drop="#2CC4B6", stem="#C98A4B", fork="#5EDBCF", shine="rgba(255,255,255,0.35)"),
 "tinted": dict(bg_a="#000000", bg_b="#000000", track="rgba(255,255,255,0.18)", ring="#FFFFFF", ring_end="#D0D0D0",
                plate="#3A3A3A", food="#E8E8E8", food_end="#BDBDBD", drop="#FFFFFF", stem="#9A9A9A", fork="#FFFFFF", shine="rgba(0,0,0,0.2)"),
}
for cname, fn in [("apple", apple), ("fork", fork_drop)]:
    for t, p in themes.items():
        open(f"{cname}_{t}.svg", "w").write(frame(fn, p))
        subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", f"{cname}_{t}.svg", "-o", f"{cname}_{t}.png"], check=True)

def tile(path, s, tint=False):
    img = Image.open(path).convert("RGB")
    if tint:
        g = img.convert("L"); img = Image.merge("RGB", (g.point(lambda v: int(v*0.35)), g.point(lambda v: int(v*0.85)), g.point(lambda v: int(v*0.8))))
    img = img.convert("RGBA").resize((s, s), Image.LANCZOS)
    m = Image.new("L", (s, s), 0); ImageDraw.Draw(m).rounded_rectangle([0,0,s-1,s-1], radius=int(s*0.225), fill=255)
    out = Image.new("RGBA", (s, s), (0,0,0,0)); out.paste(img, (0,0), m); return out

prev = Image.new("RGBA", (1240, 640), (242, 242, 247, 255))
d = ImageDraw.Draw(prev)
for row, cname in enumerate(["apple", "fork"]):
    y = 30 + row*310
    d.text((20, y + 120), "A" if row == 0 else "B", fill=(60,60,60))
    for i, t in enumerate(["light", "dark", "tinted"]):
        prev.alpha_composite(tile(f"{cname}_{t}.png", 250, t == "tinted"), (60 + i*280, y))
    prev.alpha_composite(tile(f"{cname}_light.png", 120), (920, y + 65))
    prev.alpha_composite(tile(f"{cname}_light.png", 60), (1070, y + 95))
    prev.alpha_composite(tile(f"{cname}_light.png", 40), (1160, y + 105))
prev.save("/mnt/user-data/outputs/appicon/AppIcon-options.png")
print("ok")
