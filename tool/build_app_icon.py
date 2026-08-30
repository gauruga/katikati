"""image/app_icon.png（生成AIの元絵）から、アプリアイコン用の素材を作る。

元絵は「角丸スクエア＋その外側の白い余白」という構図で出てくるが、
iOS も Android も OS 側が角丸に切り抜くため、素材は角丸なし・余白なしの
正方形でなければならない（そうしないと角丸が二重にかかる）。

出力:
  assets/icon/app_icon.png             1024x1024 不透明。iOS と旧 Android 用
  assets/icon/app_icon_foreground.png  1024x1024 透過。Android アダプティブ用

使い方:
  python tool/build_app_icon.py
  flutter pub run flutter_launcher_icons
  git checkout -- ios/Runner.xcodeproj/project.pbxproj   # ツールの不具合の戻し

必要: pip install pillow numpy
"""
from PIL import Image
import numpy as np
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'image', 'app_icon.png')
OUT_DIR = os.path.join(ROOT, 'assets', 'icon')

SIZE = 1024
# 元絵の背景（フラットな薄いグレー）。元絵を差し替えたら実測して直すこと。
BG = np.array([244.0, 243.4, 244.3])
# 置き換える背景グラデーション（上→下）。
# 元の #F4F3F4 は真っ白なストアページ上で輪郭が消えるので、わずかに紫へ寄せる。
TOP = (251, 250, 254)
BOTTOM = (234, 230, 246)

# メインアイコンでモチーフが占める割合（長辺）
MAIN_RATIO = 0.80
# アダプティブで最終的に 108dp カンバスの何割にしたいか
# （表示されるのは中央 72dp = 66.7% なので、その中で約 78% に見える）
ADAPTIVE_RATIO = 0.52
# flutter_launcher_icons が生成する ic_launcher.xml が前景に inset 16%
# （＝カンバスの 68% に縮小）を掛けるので、その分を先に割り戻しておく
INSET_SCALE = 0.68


def main():
    im = Image.open(SRC).convert('RGB')
    a = np.asarray(im).astype(np.float64)

    # モチーフの外接矩形は「彩度のある画素」で取る。
    # 白い 4.1 はダイヤルの内側にあるので外接矩形には影響しない。
    sat = a.max(axis=2) - a.min(axis=2)
    ys, xs = np.where(sat > 25)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()

    pad = 8
    crop = a[max(0, y0 - pad):min(a.shape[0], y1 + 1 + pad),
             max(0, x0 - pad):min(a.shape[1], x1 + 1 + pad)]

    # フラットな背景色からの距離でアルファを作る。
    # 背景ノイズは ±3 程度、純白の数字は距離 11 なので 4〜10 のランプで分離できる。
    dist = np.abs(crop - BG).max(axis=2)
    alpha = np.clip((dist - 4.0) / 6.0, 0, 1)
    safe = np.maximum(alpha, 1e-6)[..., None]
    fg = np.clip(BG + (crop - BG) / safe, 0, 255)
    motif = Image.fromarray(
        np.dstack([fg, alpha * 255]).astype(np.uint8), 'RGBA')

    def compose(canvas, ratio):
        scale = (SIZE * ratio) / max(motif.size)
        w, h = round(motif.size[0] * scale), round(motif.size[1] * scale)
        canvas.alpha_composite(motif.resize((w, h), Image.LANCZOS),
                               ((SIZE - w) // 2, (SIZE - h) // 2))
        return canvas

    t = np.linspace(0, 1, SIZE)[:, None]
    grad = np.zeros((SIZE, SIZE, 3))
    for c in range(3):
        grad[:, :, c] = TOP[c] * (1 - t) + BOTTOM[c] * t
    bg = Image.fromarray(grad.astype(np.uint8), 'RGB').convert('RGBA')

    os.makedirs(OUT_DIR, exist_ok=True)
    compose(bg, MAIN_RATIO).convert('RGB').save(
        os.path.join(OUT_DIR, 'app_icon.png'))
    compose(Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0)),
            ADAPTIVE_RATIO / INSET_SCALE).save(
        os.path.join(OUT_DIR, 'app_icon_foreground.png'))
    print('wrote app_icon.png / app_icon_foreground.png')


if __name__ == '__main__':
    main()
