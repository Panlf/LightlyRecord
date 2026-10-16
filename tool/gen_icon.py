# -*- coding: utf-8 -*-
"""生成轻记 App 启动图标（旧版 PNG + Android 8+ 自适应图标）。

主体图形：一支白色羽毛笔（简笔版）。
隐喻——「轻」= 羽毛的轻盈；「记」= 羽毛笔即书写工具。

★ 为什么是「简笔」而不是精细羽毛（血泪教训，别改回去）：
  自适应前景 432px = 108dp，即 1px = 0.25dp。
  早期版本羽片全宽仅 24dp，launcher 再按 66/72 安全区缩一次后，
  落到 48dp 桌面图标上实际只有约 6dp 宽；再开 1 道主脉缝 + 6 条羽枝缝，
  细丝被切成约 1.5dp 的碎段，真机远看就是「一坨白色米粒 / 十字」。
  反复调 VANE_RATIO 和羽枝条数都是白费力气——**细长 + 镂空 = 小尺寸必碎**。

本版遵循三条铁律（方案对比见 tool/gen_icon_variants.py）：
  1. 图形最大边控制在 60dp（安全区 66dp 内留 6dp 余量，防 launcher 二次放大裁切）；
  2. 全图**只有一条镂空**（主脉，固定 2.2px@最终像素），不再有羽枝横纹；
  3. 羽片半宽取羽轴半长的 0.44（48dp 下全宽约 9.5dp），比原版 0.30 粗 47%。

输出：
- android/app/src/main/res/mipmap-*/ic_launcher.png        48/72/96/144/192
- android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
  （108/162/216/324/432，**按密度逐档提供**——曾只放一张 432 在 anydpi-v26，
   部分 OEM launcher 对无密度信息的位图缩放有兼容坑，真机前景不显示）
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(BASE, 'android', 'app', 'src', 'main', 'res')
TOOL = os.path.join(BASE, 'tool')

# 品牌薄荷绿渐变（顶亮底深，保证白色图形在任何位置都有对比）
GRADIENT_TOP = (0x6B, 0xD0, 0xA8)
GRADIENT_BOTTOM = (0x2F, 0x9B, 0x79)
WHITE = (255, 255, 255)
SHADOW_COLOR = (0x11, 0x55, 0x40)

SS = 4            # 超采样倍率（抗锯齿）
FG_PX = 432       # 自适应前景画布（= 108dp）
SAFE_DP = 60.0    # 图形最大边长（dp）：安全区 66dp，留 6dp 余量

# 姿态：羽毛整体倾斜（正 = 羽尖朝右上，笔杆甩向左下）
ANGLE_DEG = 26.0
AXIS_HALF = 0.40  # 羽轴半长（相对 extent）
VANE_RATIO = 0.50  # 羽片最大半宽 / 羽轴半长 —— 比原版 0.30 粗 67%，小尺寸才不碎
VEIN_PX = 2.0     # 主脉宽度（按**最终像素**计，不是超采样坐标）


# ----------------------------------------------------------------- 基础工具

def vgrad(size, top, bottom):
    """竖向线性渐变（RGBA）。"""
    img = Image.new('RGBA', (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        t = t * t * 0.35 + t * 0.65  # 轻微 ease，上半部更亮
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = color + (255,)
    return img


def rounded_mask(size, radius_ratio=0.235):
    """圆角方形遮罩（超采样后降采样 → 边缘平滑）。"""
    big = size * SS
    m = Image.new('L', (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, big - 1, big - 1], radius=int(big * radius_ratio), fill=255
    )
    return m.resize((size, size), Image.LANCZOS)


# ----------------------------------------------------------------- 主体图形

def quill_mask(size):
    """在超采样画布上画出羽毛笔遮罩（L 图，255 = 实体）。"""
    big = size * SS
    mask = Image.new('L', (big, big), 0)
    d = ImageDraw.Draw(mask)

    extent = big * (SAFE_DP / 108.0)
    cx = big / 2.0
    cy = big / 2.0 + extent * 0.01  # 重心略下移，配平偏短笔杆导致的头重

    th = math.radians(ANGLE_DEG)
    ax = (math.sin(th), -math.cos(th))   # 羽轴方向
    pe = (math.cos(th), math.sin(th))    # 羽轴垂线

    L = extent * AXIS_HALF
    W = L * VANE_RATIO

    def point(t):
        """羽轴上 t∈[0,1]（0 = 根部，1 = 羽尖）处的坐标。"""
        s = L * (-1.0 + 2.0 * t)
        return (cx + ax[0] * s, cy + ax[1] * s)

    def width(t):
        """羽片半宽：根部收细 → 中段最宽 → 尖端收尖。"""
        return W * math.sin(math.pi * t ** 0.92) ** 0.85

    # 1) 羽片轮廓（左右两侧采样 + 倒序拼成封闭多边形）
    steps = 200
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        p = point(t)
        w = width(t)
        left.append((p[0] - pe[0] * w, p[1] - pe[1] * w))
        right.append((p[0] + pe[0] * w, p[1] + pe[1] * w))
    d.polygon(left + right[::-1], fill=255)

    # 2) 短笔杆：从羽根**内侧**（t=0.10）起笔，斜向后收尖。
    #    早期版本从羽根端点 t=0 起笔且伸得长，视觉上跟羽片脱开、
    #    三角形的尖端朝外像面小旗子；起点内移 + 缩短后才连成一体。
    base = point(0.10)
    bw = W * 0.30
    tip = (base[0] - ax[0] * L * 0.17, base[1] - ax[1] * L * 0.17)
    d.polygon([
        (base[0] - pe[0] * bw, base[1] - pe[1] * bw),
        (base[0] + pe[0] * bw, base[1] + pe[1] * bw),
        tip,
    ], fill=255)

    # 3) 主脉：全图唯一镂空。宽度固定 VEIN_PX（最终像素），
    #    不按比例给——按比例会算出 ~15px@432，把羽片劈成两半像瓜子。
    d.line([point(0.08), point(0.90)], fill=0, width=int(round(VEIN_PX * SS)))

    return mask


def quill_layer(size, color=WHITE, opacity=1.0, dy=0.0):
    """把羽毛笔渲染成一张 RGBA 图层。dy 用于做极轻微投影。"""
    big = size * SS
    layer = Image.new('RGBA', (big, big), color + (255,))
    mask = quill_mask(size)
    if dy:
        mask = mask.transform(
            (big, big), Image.AFFINE, (1, 0, 0, 0, 1, -dy * SS), resample=Image.BICUBIC
        )
    if opacity < 1.0:
        mask = mask.point(lambda v: int(v * opacity))
    layer.putalpha(mask)
    return layer.resize((size, size), Image.LANCZOS)


# ----------------------------------------------------------------- 图标合成

def build_legacy(size):
    """旧版方形图标：渐变圆角底 + 白色羽毛笔（带一层极淡投影）。"""
    bg = vgrad(size, GRADIENT_TOP, GRADIENT_BOTTOM)
    shadow = quill_layer(size, color=SHADOW_COLOR, opacity=0.30, dy=size * 0.014)
    out = Image.alpha_composite(bg, shadow)
    out = Image.alpha_composite(out, quill_layer(size))
    out.putalpha(rounded_mask(size))
    return out


def build_foreground(size):
    """自适应图标前景：透明底 + 白色羽毛笔（严格落在 66dp 安全区内）。"""
    return quill_layer(size)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, 'PNG')
    print('written:', path)


# ----------------------------------------------------------------- 校验图输出

def _font(px):
    for path in (r'C:\Windows\Fonts\msyh.ttc',
                 r'C:\Windows\Fonts\simhei.ttf',
                 r'C:\Windows\Fonts\msyh.ttf'):
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except OSError:
                pass
    return ImageFont.load_default()


def render_size_check():
    """1:1 真实像素校验图：上排真实尺寸 96/48/24，下排 48px 最近邻放大看像素。

    48px 一栏必须是一整片连贯白形；若出现横向断裂或米粒，
    说明图形又回到「细长 + 多镂空」的坑里。
    """
    zoom = 240
    cell_w = 260
    W, H = cell_w * 3, 168 + zoom + 56
    bg = Image.new('RGBA', (W, H), (238, 242, 245, 255))
    bd = ImageDraw.Draw(bg)
    f = _font(16)

    for i, size in enumerate([96, 48, 24]):
        x0 = i * cell_w
        icon = build_legacy(size)
        bg.alpha_composite(icon, (x0 + (cell_w - size) // 2, 20))
        bd.text((x0 + cell_w // 2, 128), '实际 %d px' % size,
                font=f, fill=(38, 44, 50, 255), anchor='ma')

    for i, size in enumerate([48, 48, 48]):
        x0 = i * cell_w
        icon = build_legacy(size).resize((zoom, zoom), Image.NEAREST)
        bg.alpha_composite(icon, (x0 + (cell_w - zoom) // 2, 168))
    bd.text((W // 2, 168 + zoom + 10), '↑ 三栏均为 48px 放大 5 倍（检查像素是否连贯成片）',
            font=f, fill=(130, 138, 146, 255), anchor='ma')

    path = os.path.join(TOOL, 'icon_size_check.png')
    bg.convert('RGB').save(path, 'PNG')
    print('written:', path)


def main():
    # legacy 合成图标（绿底 + 白羽毛笔，所见即所得）
    for folder, size in [
        ('mipmap-mdpi', 48),
        ('mipmap-hdpi', 72),
        ('mipmap-xhdpi', 96),
        ('mipmap-xxhdpi', 144),
        ('mipmap-xxxhdpi', 192),
    ]:
        save(build_legacy(size), os.path.join(RES, folder, 'ic_launcher.png'))

    # 自适应前景：按标准密度逐档输出（108dp × density/160）。
    # 不再往 anydpi-v26 放单一 432px——该目录的位图在 26+ 设备上优先级
    # 最高，会遮蔽各密度版本，且部分 OEM launcher 对它缩放有兼容坑。
    for folder, size in [
        ('mipmap-mdpi', 108),
        ('mipmap-hdpi', 162),
        ('mipmap-xhdpi', 216),
        ('mipmap-xxhdpi', 324),
        ('mipmap-xxxhdpi', 432),
    ]:
        save(build_foreground(size), os.path.join(RES, folder, 'ic_launcher_foreground.png'))

    # 若历史版本在 anydpi-v26 留过单张前景 PNG，删掉避免遮蔽密度版本
    legacy_fg = os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher_foreground.png')
    if os.path.exists(legacy_fg):
        os.remove(legacy_fg)
        print('removed stale:', legacy_fg)

    preview_path = os.path.join(TOOL, 'icon_preview.png')
    build_legacy(512).save(preview_path, 'PNG')
    print('written preview:', preview_path)

    render_size_check()


if __name__ == '__main__':
    main()
