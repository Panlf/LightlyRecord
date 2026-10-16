# -*- coding: utf-8 -*-
"""候选启动图标方案对比（只输出到 tool/，绝不碰 res 目录）。

背景：反复出现「小尺寸糊成白色米粒 / 十字」，根因不是参数而是图形选型。
  432px 自适应前景 = 108dp，即 1px = 0.25dp；
  原羽毛羽片全宽仅 24dp，落到 48dp 桌面图标上约 6dp 宽，
  再开主脉缝 + 羽枝缝 → 被切成 1.5dp 的细丝，远看即米粒/十字。
结论：小尺寸图标必须「宽胖 + 少镂空 + 轮廓封闭」。

本脚本生成 5 个候选（含现状对照），并渲染成 1:1 真实像素的
模拟桌面对比图，供人眼在「远看」条件下直接判优。
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(BASE, 'tool')

GRADIENT_TOP = (0x6B, 0xD0, 0xA8)
GRADIENT_BOTTOM = (0x2F, 0x9B, 0x79)
WHITE = (255, 255, 255)

SS = 4          # 超采样倍率
FG_PX = 432     # 自适应前景画布（= 108dp，1px = 0.25dp）
SAFE_DP = 60.0  # 图形最大边长（dp）。安全区 66dp，留 6dp 余量给各家 launcher 的二次缩放


# --------------------------------------------------------------------- 基础工具

def vgrad(size, top, bottom):
    img = Image.new('RGBA', (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        t = t * t * 0.35 + t * 0.65
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = color + (255,)
    return img


def rounded_mask(size, radius_ratio=0.235):
    big = size * SS
    m = Image.new('L', (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, big - 1, big - 1], radius=int(big * radius_ratio), fill=255
    )
    return m.resize((size, size), Image.LANCZOS)


def _blank(size):
    big = size * SS
    m = Image.new('L', (big, big), 0)
    return m, ImageDraw.Draw(m)


def _finish(mask, size, color=WHITE):
    layer = Image.new('RGBA', (size * SS, size * SS), color + (255,))
    layer.putalpha(mask)
    return layer.resize((size, size), Image.LANCZOS)


def _bezier_quad(p0, p1, p2, steps=90):
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        out.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return out


def _arrow(size_deg, cx, cy, r):
    """返回轴向单位向量 (sinθ, -cosθ) 与其垂线。θ 为顺时针倾角。"""
    th = math.radians(size_deg)
    ax = (math.sin(th), -math.cos(th))
    pe = (math.cos(th), math.sin(th))
    return ax, pe


# --------------------------------------------------------------------- 方案图形
# 全部返回 L 模式遮罩，画布为 FG_PX 逻辑尺寸、内部按 SS 超采样。
# 设计约束（针对 48dp 小尺寸）：
#   1. 轮廓封闭、无细长延伸段；
#   2. 最窄处 ≥ 图形最大边长的 18%；
#   3. 镂空仅保留「一条主轴」，且宽度按最终像素 ≥ 1.8px 设定。

def _leaf_body(d, cx, cy, extent, half_w_ratio, drop=0.0):
    """在 draw 上画一个两端收尖、底部略鼓的柳叶（尖头朝上）。

    half_w_ratio = 半宽 / extent。0.24 左右最雅致，>0.30 会显胖。
    drop 为整体下移量（相对 extent），用于配平视觉重心。
    """
    hh = extent * 0.46
    hw = extent * half_w_ratio
    cy = cy + extent * drop
    left = _bezier_quad((cx - hw, cy + hh), (cx - hw, cy - hh * 0.06), (cx, cy - hh))
    right = _bezier_quad((cx, cy - hh), (cx + hw, cy - hh * 0.06), (cx + hw, cy + hh))
    bottom = _bezier_quad((cx + hw, cy + hh), (cx, cy + hh * 1.30), (cx - hw, cy + hh))
    d.polygon(left + right + bottom, fill=255)
    return hh


def shape_leaf(size):
    """A. 柳叶 + 一条主脉：小尺寸稳定，剪影有细节。"""
    mask, d = _blank(size)
    big = size * SS
    cx = cy = big / 2.0
    extent = big * (SAFE_DP / 108.0)
    hh = _leaf_body(d, cx, cy, extent, 0.245)

    # 唯一镂空：主脉。宽度按**最终像素**固定 2.0px，
    # 之前按 extent 比例给（≈15px@432）会把叶子劈成两半，像瓜子。
    d.line([(cx, cy + hh * 0.82), (cx, cy - hh * 0.74)],
           fill=0, width=int(round(2.0 * SS)))
    return mask


def shape_leaf_solid(size):
    """E. 实心柳叶 + 尖端 V 形分叉：零内部镂空，小尺寸绝不可能碎。

    尖端的分叉缺口是叶子/羽毛最强的识别特征，且只需保留中央一小段，
    缺口两侧的叶尖在小尺寸下依然连成一体，不会断笔。
    """
    mask, d = _blank(size)
    big = size * SS
    cx = big / 2.0
    cy = big / 2.0 + big * 0.008
    extent = big * (SAFE_DP / 108.0)
    hh = _leaf_body(d, cx, cy, extent, 0.255)

    # 尖端分叉：从叶尖往下切一个窄 V，只切掉最上面一小段
    notch_h = hh * 0.30           # 缺口深度
    notch_w = extent * 0.085      # 缺口半宽
    top = cy - hh
    d.polygon([
        (cx, top + notch_h),                # V 底
        (cx - notch_w, top - notch_h * 0.5),
        (cx - notch_w * 0.55, top - notch_h * 0.95),   # 左叶尖（略短）
        (cx, top - notch_h * 0.62),         # 中间小平台，避免 V 太尖
        (cx + notch_w * 0.55, top - notch_h * 0.95),   # 右叶尖
        (cx + notch_w, top - notch_h * 0.5),
    ], fill=0)
    return mask


def shape_coin(size):
    """B. 硬币圆环 + 中心点：厚环在 48dp 下依然清晰，天然「记账」语义。"""
    mask, d = _blank(size)
    big = size * SS
    cx = cy = big / 2.0
    extent = big * (SAFE_DP / 108.0)
    r_out = extent * 0.46
    ring_w = extent * 0.115                 # 环厚 → 48dp 下约 6.4dp，清晰
    r_in = r_out - ring_w * 2

    d.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=255)
    d.ellipse([cx - r_in, cy - r_in, cx + r_in, cy + r_in], fill=0)
    # 中心实心点，填补「空洞显得脏」的观感，指向钱币中心
    r_dot = r_in * 0.52
    d.ellipse([cx - r_dot, cy - r_dot, cx + r_dot, cy + r_dot], fill=255)
    return mask


def shape_tag(size):
    """C. 圆角便签 + 角孔：一眼是「标签/分类」，几何封闭，绝不碎。"""
    mask, d = _blank(size)
    big = size * SS
    cx = cy = big / 2.0
    extent = big * (SAFE_DP / 108.0)
    w = extent * 0.62
    h = extent * 0.86
    radius = extent * 0.14

    d.rounded_rectangle([cx - w, cy - h, cx + w, cy + h], radius=int(radius), fill=255)
    # 左上角打孔（便签的装订孔）
    r_hole = extent * 0.085
    hx, hy = cx - w * 0.46, cy - h * 0.62
    d.ellipse([hx - r_hole, hy - r_hole, hx + r_hole, hy + r_hole], fill=0)
    return mask


def shape_quill(size):
    """D. 简笔羽毛笔：柳叶羽片 + 短笔杆，倾斜 26°。保留「轻/笔」隐喻但不加羽枝纹。"""
    mask, d = _blank(size)
    big = size * SS
    cx = big / 2.0 + big * 0.01
    cy = big / 2.0 + big * 0.01
    extent = big * (SAFE_DP / 108.0)
    ax, pe = _arrow(26.0, cx, cy, extent)

    L = extent * 0.40       # 羽轴半长
    W = L * 0.44            # 羽片半宽 → 48dp 下全宽约 9.5dp，够粗

    def point(t):
        s = L * (-1.0 + 2.0 * t)
        return (cx + ax[0] * s, cy + ax[1] * s)

    def width(t):
        return W * math.sin(math.pi * t ** 0.92) ** 0.85

    steps = 200
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        p = point(t)
        w = width(t)
        left.append((p[0] - pe[0] * w, p[1] - pe[1] * w))
        right.append((p[0] + pe[0] * w, p[1] + pe[1] * w))
    d.polygon(left + right[::-1], fill=255)

    # 短笔杆：只伸出一小截，不再是长尖细条
    base = point(0.0)
    bw = W * 0.34
    tip = (base[0] - ax[0] * L * 0.26, base[1] - ax[1] * L * 0.26)
    d.polygon([
        (base[0] - pe[0] * bw, base[1] - pe[1] * bw),
        (base[0] + pe[0] * bw, base[1] + pe[1] * bw),
        tip,
    ], fill=255)

    # 唯一镂空：主脉，固定 2.2px@最终像素（不按比例，避免劈成两半）
    d.line([point(0.08), point(0.90)], fill=0, width=int(round(2.2 * SS)))
    return mask


def shape_current(size):
    """A0. 现状对照：带主脉 + 羽枝缝的老羽毛（即用户看到糊成米粒的那版）。"""
    mask, d = _blank(size)
    big = size * SS
    cx = big / 2.0
    cy = big / 2.0 + big * 0.02
    L = big * 0.37
    W = L * 0.30
    ax, pe = _arrow(22.0, cx, cy, L)

    def point(t):
        s = L * (-0.58 + 1.16 * t)
        return (cx + ax[0] * s, cy + ax[1] * s)

    def width(t):
        return W * (0.10 + 0.90 * math.sin(math.pi * t ** 1.15)) * (1 - t ** 2.3)

    steps = 200
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        p = point(t)
        w = width(t)
        left.append((p[0] - pe[0] * w, p[1] - pe[1] * w))
        right.append((p[0] + pe[0] * w, p[1] + pe[1] * w))
    d.polygon(left + right[::-1], fill=255)

    base = point(0.0)
    bw = W * 0.15
    tip = (base[0] - ax[0] * L * 0.24, base[1] - ax[1] * L * 0.24)
    d.polygon([
        (base[0] - pe[0] * bw, base[1] - pe[1] * bw),
        (base[0] + pe[0] * bw, base[1] + pe[1] * bw),
        tip,
    ], fill=255)

    d.line([point(0.05), point(0.94)], fill=0, width=int(round(max(2.4 * SS, W * 0.11))))
    for side in (-1, 1):
        for i in range(6):
            t = 0.24 + i * (0.58 / 5) + (0.07 if side > 0 else 0.0)
            if t > 0.90:
                continue
            p = point(t)
            w = width(t)
            k = max(1.7 * SS, w * 0.18)
            outer = (p[0] + side * pe[0] * w * 1.06, p[1] + side * pe[1] * w * 1.06)
            q = point(max(0.0, t - 0.22))
            inner = (q[0] + side * pe[0] * w * 0.06, q[1] + side * pe[1] * w * 0.06)
            d.line([outer, inner], fill=0, width=int(round(k)))
    return mask


CANDIDATES = [
    ('A0', '现状对照', shape_current),
    ('A', '柳叶+主脉', shape_leaf),
    ('B', '硬币圆环', shape_coin),
    ('C', '圆角便签', shape_tag),
    ('D', '羽毛笔', shape_quill),
    ('E', '实心柳叶', shape_leaf_solid),
]


# --------------------------------------------------------------------- 图标合成

def build_legacy(mask_fn, size):
    bg = vgrad(size, GRADIENT_TOP, GRADIENT_BOTTOM)
    mask = mask_fn(size)
    layer = Image.new('RGBA', (size * SS, size * SS), WHITE + (255,))
    layer.putalpha(mask)
    main = layer.resize((size, size), Image.LANCZOS)
    out = Image.alpha_composite(bg, main)
    out.putalpha(rounded_mask(size))
    return out


def build_foreground(mask_fn, size):
    mask = mask_fn(size)
    layer = Image.new('RGBA', (size * SS, size * SS), WHITE + (255,))
    layer.putalpha(mask)
    return layer.resize((size, size), Image.LANCZOS)


# --------------------------------------------------------------------- 对比图

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


def render_desktop_compare():
    """1:1 真实像素的模拟桌面：每个方案给 48dp 图标 + 24dp「眯眼远看」缩略。"""
    cell_w, cell_h = 150, 196
    pad_top = 16
    W, H = cell_w * len(CANDIDATES), cell_h + pad_top + 8
    # 浅色壁纸渐变 + 顶部一道极淡高光，模拟真实桌面而非纯色底
    bg = Image.new('RGBA', (W, H), (238, 242, 245, 255))
    bd = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / H
        c = tuple(round(240 - 18 * t) for _ in range(3))
        bd.line([(0, y), (W, y)], fill=c + (255,))

    f_name = _font(17)
    f_tag = _font(13)

    for i, (code, name, fn) in enumerate(CANDIDATES):
        x0 = i * cell_w
        icon = build_legacy(fn, 48)
        bg.alpha_composite(icon, (x0 + (cell_w - 48) // 2, pad_top + 26))
        # 24dp：模拟用户远看 / 抽屉小图标
        tiny = icon.resize((24, 24), Image.LANCZOS)
        bg.alpha_composite(tiny, (x0 + (cell_w - 24) // 2, pad_top + 106))
        # 96dp：模拟应用商店 / 设置列表大图标
        big = icon.resize((96, 96), Image.LANCZOS)
        bg.alpha_composite(big, (x0 + (cell_w - 96) // 2, pad_top + 4))

        bd.text((x0 + cell_w // 2, pad_top + 138), '%s %s' % (code, name),
                font=f_name, fill=(38, 44, 50, 255), anchor='ma')
        bd.text((x0 + cell_w // 2, pad_top + 164),
                '96 / 48 / 24 px', font=f_tag, fill=(140, 148, 156, 255), anchor='ma')

    path = os.path.join(TOOL, 'icon_variants_desktop.png')
    bg.convert('RGB').save(path, 'PNG')
    print('written:', path)


def render_zoom_compare():
    """像素级检查：每个方案的 48px 最近邻放大 4 倍，看真实像素是否成片。"""
    cell_w, cell_h = 176, 232
    W = cell_w * len(CANDIDATES)
    H = cell_h
    bg = Image.new('RGBA', (W, H), (22, 22, 22, 255))
    bd = ImageDraw.Draw(bg)
    f = _font(16)

    for i, (code, name, fn) in enumerate(CANDIDATES):
        x0 = i * cell_w
        icon = build_legacy(fn, 48).resize((192, 192), Image.NEAREST)
        bg.alpha_composite(icon, (x0 + (cell_w - 192) // 2, 8))
        bd.text((x0 + cell_w // 2, 210), '%s %s' % (code, name),
                font=f, fill=(220, 224, 228, 255), anchor='ma')

    path = os.path.join(TOOL, 'icon_variants_zoom.png')
    bg.convert('RGB').save(path, 'PNG')
    print('written:', path)


def render_preview(mask_fn, path):
    build_legacy(mask_fn, 512).save(path, 'PNG')
    print('written:', path)


def main():
    render_desktop_compare()
    render_zoom_compare()
    for code, name, fn in CANDIDATES:
        render_preview(fn, os.path.join(TOOL, 'cand_%s.png' % code))
    print('--- 注意：本脚本不写入 res 目录，选定方案后再落地。')


if __name__ == '__main__':
    main()
