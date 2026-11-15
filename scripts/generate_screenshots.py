import math, os
from PIL import Image, ImageDraw, ImageFont

FONT_REG = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 13)
FONT_SM = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 11)
FONT_XS = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 9)
FONT_BOLD = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 14)
FONT_TITLE = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 17)
FONT_HEAD = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 20)

def draw_vector_arrow_left(draw, x, y, col=(255, 255, 255, 255), size=12):
    draw.line([(x + size, y), (x + 2, y + size // 2), (x + size, y + size)], fill=col, width=2)
    draw.line([(x + 2, y + size // 2), (x + size + 6, y + size // 2)], fill=col, width=2)

def draw_vector_check(draw, x, y, col=(255, 255, 255, 255), size=10):
    draw.line([(x, y + size // 2), (x + size // 3, y + size), (x + size, y)], fill=col, width=2)

def draw_vector_play(draw, x, y, col=(255, 255, 255, 255), size=12):
    draw.polygon([(x, y), (x + size, y + size // 2), (x, y + size)], fill=col)

def render_equalizer_studio(out_path):
    w, h = 400, 820
    im = Image.new("RGBA", (w, h), (12, 12, 15, 255))
    draw = ImageDraw.Draw(im)

    # Status Bar
    draw.text((22, 12), "9:41", font=FONT_BOLD, fill=(255, 255, 255, 230))
    draw.text((w - 75, 12), "5G  100%", font=FONT_BOLD, fill=(255, 255, 255, 230))

    # App Bar
    draw_vector_arrow_left(draw, 20, 48, (255, 255, 255, 255))
    draw.text((50, 44), "Equalizer Studio", font=FONT_HEAD, fill=(255, 255, 255, 255))

    # AutoEq Active Badge
    badge_rect = [w - 135, 43, w - 20, 71]
    draw.rounded_rectangle(badge_rect, radius=14, fill=(41, 121, 255, 40), outline=(41, 121, 255, 180), width=1)
    draw.ellipse([w - 124, 53, w - 116, 61], fill=(41, 121, 255, 255))
    draw.text((w - 110, 48), "AutoEq Active", font=FONT_SM, fill=(41, 121, 255, 255))

    # EQ Graph Box
    graph_box = [16, 88, w - 16, 318]
    draw.rounded_rectangle(graph_box, radius=16, fill=(20, 20, 26, 255), outline=(255, 255, 255, 25), width=1)

    gx0, gy0, gx1, gy1 = graph_box[0] + 16, graph_box[1] + 20, graph_box[2] - 16, graph_box[3] - 40
    gw = gx1 - gx0
    gh = gy1 - gy0

    mid_y = gy0 + gh / 2
    draw.line([(gx0, mid_y), (gx1, mid_y)], fill=(255, 255, 255, 45), width=1)
    draw.text((gx0 + 4, mid_y - 14), "0 dB Unity", font=FONT_XS, fill=(255, 255, 255, 90))

    draw.line([(gx0, gy0), (gx1, gy0)], fill=(255, 255, 255, 20), width=1)
    draw.text((gx0 + 4, gy0 + 2), "+12 dB Peak", font=FONT_XS, fill=(255, 255, 255, 70))
    draw.line([(gx0, gy1), (gx1, gy1)], fill=(255, 255, 255, 20), width=1)
    draw.text((gx0 + 4, gy1 - 14), "-12 dB Cut", font=FONT_XS, fill=(255, 255, 255, 70))

    gains = [5.2, 2.8, -0.5, 0.2, 2.5, 4.2]
    freq_labels = ["60 Hz", "150 Hz", "400 Hz", "1 kHz", "2.4 kHz", "15 kHz"]
    n = len(gains)
    col_w = gw / (n - 1)

    pts = []
    for i, g in enumerate(gains):
        x = gx0 + i * col_w
        norm = (g + 12.0) / 24.0
        y = gy1 - norm * gh
        pts.append((x, y))

    fine_pts = []
    steps = 160
    for s in range(steps + 1):
        t = s / steps
        idx = t * (n - 1)
        i0 = int(idx)
        t_sub = idx - i0
        if i0 >= n - 1:
            fine_pts.append(pts[-1])
        else:
            mu2 = (1 - math.cos(t_sub * math.pi)) / 2
            x = pts[i0][0] * (1 - mu2) + pts[i0 + 1][0] * mu2
            y = pts[i0][1] * (1 - mu2) + pts[i0 + 1][1] * mu2
            fine_pts.append((x, y))

    poly = [(fine_pts[0][0], gy1 + 10)] + fine_pts + [(fine_pts[-1][0], gy1 + 10)]
    fill_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fill_draw = ImageDraw.Draw(fill_layer)
    fill_draw.polygon(poly, fill=(41, 121, 255, 55))
    im = Image.alpha_composite(im, fill_layer)
    draw = ImageDraw.Draw(im)

    for i in range(len(fine_pts) - 1):
        draw.line([fine_pts[i], fine_pts[i + 1]], fill=(41, 121, 255, 255), width=3)

    for i, (x, y) in enumerate(pts):
        draw.ellipse([x - 12, y - 12, x + 12, y + 12], fill=(41, 121, 255, 50))
        draw.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(255, 255, 255, 255))
        draw.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(41, 121, 255, 255))
        draw.text((x - 14, gy1 + 14), freq_labels[i], font=FONT_SM, fill=(160, 160, 175, 255))

    # Readout Bubble
    bx, by = pts[0][0] + 62, pts[0][1] - 28
    draw.rounded_rectangle([bx - 55, by - 12, bx + 70, by + 12], radius=6, fill=(28, 28, 36, 255), outline=(41, 121, 255, 220), width=1)
    draw.text((bx - 48, by - 8), "+5.2 dB (AutoEq Harman)", font=FONT_XS, fill=(255, 255, 255, 255))

    # Headroom Limiter Guard
    guard_box = [16, 328, w - 16, 368]
    draw.rounded_rectangle(guard_box, radius=10, fill=(18, 28, 20, 255), outline=(76, 175, 80, 140), width=1)
    draw.text((28, 338), "Lossless DSP Guard: -3.7 dB Anti-Clipping Headroom Active", font=FONT_SM, fill=(129, 199, 132, 255))

    # Horizontal Category Chips
    chips = ["All", "AutoEq Studio", "JamesDSP Acoustic", "APO / Loudness"]
    cx = 16
    for i, ch in enumerate(chips):
        is_sel = i == 1
        cw = len(ch) * 7 + 22
        bg = (41, 121, 255, 220) if is_sel else (24, 24, 30, 255)
        fg = (255, 255, 255, 255) if is_sel else (175, 175, 190, 255)
        border = (41, 121, 255, 255) if is_sel else (255, 255, 255, 25)
        draw.rounded_rectangle([cx, 380, cx + cw, 410], radius=15, fill=bg, outline=border, width=1)
        draw.text((cx + 11, 387), ch, font=FONT_SM, fill=fg)
        cx += cw + 8

    # Presets List
    presets = [
        ("AutoEq: Harman Target", "Audiophile in-ear acoustic baseline curve", True),
        ("AutoEq: Audiophile Neutral", "Flat reference sound signature for studio monitors", False),
        ("AutoEq: Harman Bass Boost", "+6.5 dB calibrated sub-bass extension curve", False),
        ("AutoEq: Vocal Forward", "Enhanced midrange presence for acoustic clarity", False),
        ("JamesDSP: Pure Clarity", "Wide spatial presence with transparent treble detail", False),
        ("JamesDSP: Bass Resonance", "Resonant low-end warmth with tube simulation", False),
    ]

    py = 425
    for title, desc, active in presets:
        pbox = [16, py, w - 16, py + 54]
        pbg = (20, 26, 38, 255) if active else (18, 18, 22, 255)
        pborder = (41, 121, 255, 160) if active else (255, 255, 255, 20)
        draw.rounded_rectangle(pbox, radius=12, fill=pbg, outline=pborder, width=1)

        if active:
            draw.ellipse([28, py + 18, 46, py + 36], fill=(41, 121, 255, 255))
            draw_vector_check(draw, 33, py + 23, (255, 255, 255, 255), 8)
        else:
            draw.ellipse([28, py + 18, 46, py + 36], fill=(30, 30, 36, 255), outline=(255, 255, 255, 40), width=1)

        draw.text((58, py + 9), title, font=FONT_BOLD, fill=(255, 255, 255, 255) if active else (220, 220, 230, 255))
        draw.text((58, py + 30), desc, font=FONT_XS, fill=(41, 121, 255, 255) if active else (140, 140, 155, 255))
        py += 62

    # Bottom Mini Player
    player_box = [16, h - 68, w - 16, h - 14]
    draw.rounded_rectangle(player_box, radius=14, fill=(24, 24, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw.rounded_rectangle([24, h - 60, 68, h - 22], radius=6, fill=(41, 121, 255, 180))
    draw_vector_play(draw, 42, h - 46, (255, 255, 255, 255), 10)
    draw.text((76, h - 56), "Summertime Sadness", font=FONT_BOLD, fill=(255, 255, 255, 255))
    draw.text((76, h - 38), "Lana Del Rey | AutoEq Harman", font=FONT_XS, fill=(160, 160, 175, 255))
    draw.ellipse([w - 56, h - 54, w - 28, h - 26], fill=(41, 121, 255, 255))
    draw_vector_play(draw, w - 44, h - 45, (255, 255, 255, 255), 10)

    im.save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path}")

def render_theme_studio(out_path):
    w, h = 400, 820
    im = Image.new("RGBA", (w, h), (12, 12, 15, 255))
    draw = ImageDraw.Draw(im)

    # Status Bar
    draw.text((22, 12), "9:41", font=FONT_BOLD, fill=(255, 255, 255, 230))
    draw.text((w - 75, 12), "5G  100%", font=FONT_BOLD, fill=(255, 255, 255, 230))

    # App Bar
    draw_vector_arrow_left(draw, 20, 48, (255, 255, 255, 255))
    draw.text((50, 44), "Theme & Accent Studio", font=FONT_HEAD, fill=(255, 255, 255, 255))

    # Subtitle
    draw.text((20, 80), "DYNAMIC PALETTES", font=FONT_XS, fill=(41, 121, 255, 255))
    draw.text((20, 98), "Personalize your Sine experience in real-time", font=FONT_REG, fill=(160, 160, 175, 255))

    themes = [
        ("Electric Blue", (41, 121, 255), True),
        ("Emerald Green", (0, 200, 83), False),
        ("Sunset Orange", (255, 109, 0), False),
        ("Crimson Red", (229, 57, 53), False),
        ("Electric Yellow", (255, 214, 0), False),
        ("Neon Purple", (170, 0, 255), False),
        ("Monochrome", (224, 224, 224), False),
        ("Custom Hex", (0, 229, 255), False),
    ]

    grid_x, grid_y = 16, 128
    card_w = (w - 40) // 2
    card_h = 60

    for i, (name, col, active) in enumerate(themes):
        row = i // 2
        col_idx = i % 2
        bx0 = grid_x + col_idx * (card_w + 8)
        by0 = grid_y + row * (card_h + 8)
        bx1 = bx0 + card_w
        by1 = by0 + card_h

        bg = (24, 30, 42, 255) if active else (22, 22, 28, 255)
        border = (col[0], col[1], col[2], 255) if active else (255, 255, 255, 25)
        draw.rounded_rectangle([bx0, by0, bx1, by1], radius=12, fill=bg, outline=border, width=2 if active else 1)

        draw.ellipse([bx0 + 12, by0 + 16, bx0 + 40, by0 + 44], fill=col)
        if active:
            draw_vector_check(draw, bx0 + 21, by0 + 26, (255, 255, 255, 255), 8)

        draw.text((bx0 + 48, by0 + 14), name, font=FONT_BOLD, fill=(255, 255, 255, 255))
        draw.text((bx0 + 48, by0 + 34), "Active" if active else "Tap to apply", font=FONT_XS, fill=(col[0], col[1], col[2], 255) if active else (130, 130, 145, 255))

    # Custom RGB Slider Studio Box
    box_y = 418
    draw.rounded_rectangle([16, box_y, w - 16, box_y + 240], radius=16, fill=(18, 18, 22, 255), outline=(255, 255, 255, 25), width=1)
    draw.text((28, box_y + 14), "Custom Hex & RGB Calibrator", font=FONT_BOLD, fill=(255, 255, 255, 255))
    draw.text((w - 90, box_y + 14), "#2979FF", font=FONT_BOLD, fill=(41, 121, 255, 255))

    channels = [("Red", 41, (239, 83, 80)), ("Green", 121, (102, 187, 106)), ("Blue", 255, (66, 165, 245))]
    sy = box_y + 45
    for cname, cval, ccol in channels:
        draw.text((28, sy), f"{cname} ({cval})", font=FONT_SM, fill=(180, 180, 195, 255))
        draw.rounded_rectangle([28, sy + 18, w - 28, sy + 26], radius=4, fill=(38, 38, 46, 255))
        fill_w = int((w - 56) * (cval / 255.0))
        draw.rounded_rectangle([28, sy + 18, 28 + fill_w, sy + 26], radius=4, fill=ccol)
        draw.ellipse([28 + fill_w - 7, sy + 14, 28 + fill_w + 7, sy + 28], fill=(255, 255, 255, 255))
        sy += 50

    draw.text((28, box_y + 198), "Preview: Reactive Palette", font=FONT_SM, fill=(160, 160, 175, 255))
    draw.rounded_rectangle([190, box_y + 192, w - 28, box_y + 224], radius=10, fill=(41, 121, 255, 255))
    draw.text((215, box_y + 200), "Save Accent Color", font=FONT_BOLD, fill=(255, 255, 255, 255))

    # Bottom Mini Player with theme accent
    player_box = [16, h - 68, w - 16, h - 14]
    draw.rounded_rectangle(player_box, radius=14, fill=(24, 24, 30, 255), outline=(255, 255, 255, 30), width=1)
    draw.rounded_rectangle([24, h - 60, 68, h - 22], radius=6, fill=(41, 121, 255, 180))
    draw_vector_play(draw, 42, h - 46, (255, 255, 255, 255), 10)
    draw.text((76, h - 56), "Blinding Lights", font=FONT_BOLD, fill=(255, 255, 255, 255))
    draw.text((76, h - 38), "The Weeknd | Electric Blue Accent", font=FONT_XS, fill=(41, 121, 255, 255))
    draw.ellipse([w - 56, h - 54, w - 28, h - 26], fill=(41, 121, 255, 255))
    draw_vector_play(draw, w - 44, h - 45, (255, 255, 255, 255), 10)

    im.save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path}")

def render_now_playing(out_path):
    w, h = 400, 820
    im = Image.new("RGBA", (w, h), (14, 16, 24, 255))
    draw = ImageDraw.Draw(im)

    # Ambient Top Glow
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([-50, -50, w + 50, 350], fill=(41, 121, 255, 45))
    im = Image.alpha_composite(im, glow)
    draw = ImageDraw.Draw(im)

    # Status Bar
    draw.text((22, 12), "9:41", font=FONT_BOLD, fill=(255, 255, 255, 230))
    draw.text((w - 75, 12), "5G  100%", font=FONT_BOLD, fill=(255, 255, 255, 230))

    # Top App Bar
    draw_vector_arrow_left(draw, 20, 48, (255, 255, 255, 255))
    draw.text((w // 2 - 40, 46), "Now Playing", font=FONT_BOLD, fill=(255, 255, 255, 200))

    # Vinyl Record Disc Artwork
    disc_cx, disc_cy, r = w // 2, 220, 115
    draw.ellipse([disc_cx - r, disc_cy - r, disc_cx + r, disc_cy + r], fill=(16, 16, 20, 255), outline=(255, 255, 255, 40), width=2)
    for gr in range(40, 110, 14):
        draw.ellipse([disc_cx - gr, disc_cy - gr, disc_cx + gr, disc_cy + gr], outline=(255, 255, 255, 18), width=1)

    art_r = 48
    draw.ellipse([disc_cx - art_r, disc_cy - art_r, disc_cx + art_r, disc_cy + art_r], fill=(37, 99, 235, 255), outline=(41, 121, 255, 255), width=2)
    draw.ellipse([disc_cx - 8, disc_cy - 8, disc_cx + 8, disc_cy + 8], fill=(14, 16, 24, 255))

    # Song Info
    draw.text((24, 375), "Starboy", font=FONT_HEAD, fill=(255, 255, 255, 255))
    draw.text((24, 405), "The Weeknd, Daft Punk", font=FONT_TITLE, fill=(160, 160, 175, 255))

    # Stream Quality Badge & SponsorBlock chip
    draw.rounded_rectangle([24, 442, 118, 468], radius=6, fill=(41, 121, 255, 35), outline=(41, 121, 255, 160), width=1)
    draw.text((32, 448), "Opus 160 kbps", font=FONT_XS, fill=(41, 121, 255, 255))
    draw.rounded_rectangle([126, 442, 250, 468], radius=6, fill=(76, 175, 80, 35), outline=(76, 175, 80, 160), width=1)
    draw.text((134, 448), "SponsorBlock Active", font=FONT_XS, fill=(129, 199, 132, 255))

    # Scrubber Bar
    sy = 492
    draw.rounded_rectangle([24, sy, w - 24, sy + 5], radius=2, fill=(40, 42, 54, 255))
    prog_w = int((w - 48) * 0.42)
    draw.rounded_rectangle([24, sy, 24 + prog_w, sy + 5], radius=2, fill=(41, 121, 255, 255))
    draw.ellipse([24 + prog_w - 6, sy - 4, 24 + prog_w + 6, sy + 9], fill=(255, 255, 255, 255))
    draw.text((24, sy + 12), "1:32", font=FONT_XS, fill=(160, 160, 175, 255))
    draw.text((w - 52, sy + 12), "3:50", font=FONT_XS, fill=(160, 160, 175, 255))

    # Big Play Button
    cy = 560
    draw.ellipse([w // 2 - 28, cy - 14, w // 2 + 28, cy + 42], fill=(41, 121, 255, 255))
    draw_vector_play(draw, w // 2 - 6, cy + 3, (255, 255, 255, 255), 18)

    # Real-Time Synchronized Lyrics Card
    ly_box = [16, 625, w - 16, h - 25]
    draw.rounded_rectangle(ly_box, radius=16, fill=(22, 24, 34, 255), outline=(41, 121, 255, 70), width=1)
    draw.text((28, 636), "REAL-TIME LYRICS", font=FONT_XS, fill=(41, 121, 255, 255))
    draw.text((w - 85, 636), "Tap line to seek", font=FONT_XS, fill=(140, 140, 155, 255))

    draw.text((28, 660), "I'm tryna put you in the worst mood, ah", font=FONT_REG, fill=(140, 140, 155, 255))
    draw.text((28, 688), "P1 cleaner than your church shoes, ah", font=FONT_BOLD, fill=(255, 255, 255, 255))
    draw.text((28, 716), "Milli point two just to hurt you, ah", font=FONT_REG, fill=(140, 140, 155, 255))
    draw.text((28, 744), "All red Lamb' just to tease you, ah", font=FONT_REG, fill=(140, 140, 155, 255))

    im.save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path}")

render_equalizer_studio("docs/screenshots/equalizer_studio.png")
render_theme_studio("docs/screenshots/theme_studio.png")
render_now_playing("docs/screenshots/now_playing.png")
