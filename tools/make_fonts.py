"""Generate the bold bitmap fonts (BMFont text format) used by the data field.

The Edge 830 has no bold text font, so the zone labels ("Z3") and the
numbers (zone times, cell values) use these fonts. Glyphs are rendered
without anti-aliasing and the vertical metrics are tight: the top of the
capitals/digits is 1 px below the draw position, so layouts are exact.

Usage: python3 tools/make_fonts.py   (needs Pillow)
"""
from PIL import Image, ImageDraw, ImageFont

TTF = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
CHARS = "Z0123456789:%- "
OUT = "resources/fonts"
# resource id -> height of capitals/digits in pixels
FONTS = {"bold20": 20, "bold17": 17}


def font_for_cap(cap):
    size = cap
    while True:
        f = ImageFont.truetype(TTF, size)
        if -f.getbbox("Z", anchor="ls")[1] >= cap:
            return f
        size += 1


def make(name, cap):
    f = font_for_cap(cap)
    base = cap + 1
    glyphs = []
    for ch in CHARS:
        l, t, r, b = f.getbbox(ch, anchor="ls")
        adv = round(f.getlength(ch))
        glyphs.append((ch, l, t, r, b, adv))
    line_h = base + max(2, max(g[4] for g in glyphs))
    pad = 2
    width = sum(max(1, g[3] - g[1]) + pad for g in glyphs) + pad
    height = max(g[4] - g[2] for g in glyphs) + 2 * pad
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    lines = []
    x = pad
    for ch, l, t, r, b, adv in glyphs:
        w = max(1, r - l)
        h = max(1, b - t)
        if ch != " ":
            # render in 1-bit mode: no anti-aliasing
            mask = Image.new("1", (w, h), 0)
            ImageDraw.Draw(mask).text((-l, -t), ch, font=f, fill=1, anchor="ls")
            img.paste((255, 255, 255, 255), (x, pad), mask)
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
            % (ord(ch), x, pad, w, h, l, base + t, adv)
        )
        x += w + pad
    png = name + ".png"
    img.save("%s/%s" % (OUT, png))
    fnt = [
        'info face="LiberationSansBold" size=%d bold=1 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1'
        % f.size,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (line_h, base, width, height),
        'page id=0 file="%s"' % png,
        "chars count=%d" % len(glyphs),
    ] + lines
    open("%s/%s.fnt" % (OUT, name), "w").write("\n".join(fnt) + "\n")
    print(name, "size", f.size, "cap", cap, "lineHeight", line_h,
          "width 88:88 =", sum(round(f.getlength(c)) for c in "88:88"))


for n, c in FONTS.items():
    make(n, c)
