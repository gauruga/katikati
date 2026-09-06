"""Play Console のフィーチャーグラフィック（1024x500）を作る。

ストア掲載ページの一番上に出る横長の画像。端がトリミングされることが
あるので、文字とモチーフは中央寄りに置き、周囲に余白を残している。

配色はアプリから採ってあるので、ストアとアプリで見た目が揃う。
  - 背景のグラデーション … ドロワーヘッダと同じ #7C4DFF → #EA80FC
    （lib/home_page.dart の LinearGradient）
  - 下部の色帯 … 小役ボタン9個の実際の色
    （release/screenshots/01-simple.png から採取）

出力:
  release/feature-graphic.png   1024x500 不透明

使い方:
  python tool/build_feature_graphic.py

必要: pip install pillow numpy
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOTIF = os.path.join(ROOT, 'assets', 'icon', 'app_icon_foreground.png')
OUT = os.path.join(ROOT, 'release', 'feature-graphic.png')

W, H = 1024, 500

# ドロワーヘッダと同じグラデーション。
GRAD_L = (0x7C, 0x4D, 0xFF)
GRAD_R = (0xEA, 0x80, 0xFC)

# 小役ボタン9個の実配色。
PALETTE = [
    (0xFF, 0xCD, 0x33), (0xE6, 0x3C, 0x38), (0x6E, 0xBE, 0x71),
    (0xAF, 0x50, 0xBF), (0xFF, 0xAB, 0x31), (0x31, 0xAA, 0x9F),
    (0x83, 0x54, 0xFF), (0x4B, 0xA9, 0xF5), (0xED, 0x4A, 0x81),
]

TITLE = '小役カウンター'
# 機能を1つに絞って言い切る。「攻略」「勝てる」の類は入れない。
TAGLINE = '押しやすさだけを考えました'

# 端がトリミングされても文字が欠けないように残す余白。
MARGIN = 62

FONT_BOLD = 'C:/Windows/Fonts/YuGothB.ttc'
FONT_MED = 'C:/Windows/Fonts/YuGothM.ttc'


def background():
    """左上から右下へ流れるグラデーション。"""
    # 横位置と縦位置を 4:1 で混ぜて、ゆるい斜めにする。
    x = np.linspace(0, 1, W)[None, :]
    y = np.linspace(0, 1, H)[:, None]
    t = np.clip(x * 0.8 + y * 0.2, 0, 1)
    grad = np.zeros((H, W, 3))
    for c in range(3):
        grad[:, :, c] = GRAD_L[c] * (1 - t) + GRAD_R[c] * t
    return Image.fromarray(grad.astype(np.uint8), 'RGB').convert('RGBA')


def add_glow(base):
    """アプリのボタンと同じ、ふわっとした光を散らす。"""
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # 左上と右下に大きめの光、右上に小さい光。
    d.ellipse((-120, -160, 380, 340), fill=(255, 255, 255, 38))
    d.ellipse((700, 300, 1180, 700), fill=(255, 255, 255, 30))
    d.ellipse((830, -80, 1010, 100), fill=(255, 255, 255, 26))
    layer = layer.filter(ImageFilter.GaussianBlur(70))
    base.alpha_composite(layer)
    return base


def trimmed_motif():
    """アイコン素材から透明な余白を落として、モチーフだけ取り出す。"""
    im = Image.open(MOTIF).convert('RGBA')
    box = im.getchannel('A').getbbox()
    return im.crop(box)


def fit_font(path, text, max_width, start_size, index=0, min_size=18):
    """max_width に収まる最大のフォントサイズを選ぶ。

    文字数から目分量で決めると和文の字幅で外すので、実際に測って詰める。
    """
    size = start_size
    while size > min_size:
        font = ImageFont.truetype(path, size, index=index)
        box = font.getbbox(text)
        if box[2] - box[0] <= max_width:
            return font
        size -= 2
    return ImageFont.truetype(path, min_size, index=index)


def draw_palette(d, x, y, size=40, gap=13, radius=11):
    """小役ボタンの色を並べた帯。アプリの画面と印象を揃えるための飾り。"""
    for i, color in enumerate(PALETTE):
        left = x + i * (size + gap)
        d.rounded_rectangle((left, y, left + size, y + size),
                            radius=radius, fill=color + (255,))


def main():
    img = add_glow(background())

    # モチーフは左側。文字に幅を譲るので、高さの 52% に抑える。
    motif = trimmed_motif()
    mh = int(H * 0.52)
    mw = round(motif.width * mh / motif.height)
    motif = motif.resize((mw, mh), Image.LANCZOS)

    # 影を落として、背景のグラデーションから浮かせる。
    shadow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    alpha = motif.getchannel('A').point(lambda a: int(a * 0.17))
    tinted = Image.new('RGBA', motif.size, (58, 18, 108, 0))
    tinted.putalpha(alpha)
    mx, my = MARGIN, (H - mh) // 2
    shadow.alpha_composite(tinted, (mx + 2, my + 14))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(38)))
    img.alpha_composite(motif, (mx, my))

    d = ImageDraw.Draw(img)
    text_x = mx + mw + 54
    text_w = W - MARGIN - text_x

    title_font = fit_font(FONT_BOLD, TITLE, text_w, 84)
    tag_font = fit_font(FONT_MED, TAGLINE, text_w, 32)

    # タイトルにも薄い影を敷いて、背景が明るい側でも読めるようにする。
    d.text((text_x + 3, 148 + 4), TITLE, font=title_font, anchor='la',
           fill=(70, 25, 130, 90))
    d.text((text_x, 148), TITLE, font=title_font, anchor='la',
           fill=(255, 255, 255, 255))
    d.text((text_x, 264), TAGLINE, font=tag_font, anchor='la',
           fill=(255, 255, 255, 235))

    # 色帯も文字幅に収める。
    count = len(PALETTE)
    gap = 13
    box = min(44, (text_w - gap * (count - 1)) // count)
    draw_palette(d, text_x, 336, size=box, gap=gap, radius=box // 4)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.convert('RGB').save(OUT)
    print(f'wrote {os.path.relpath(OUT, ROOT)}  {W}x{H}')


if __name__ == '__main__':
    main()
