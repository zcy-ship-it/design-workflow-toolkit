# Poster To Editable PSD

Convert poster, flyer, ad, social-card, product, event, and long-screenshot images into Photoshop 2026 compatible editable layered PSD packages.

## What It Does

`poster-to-editable-psd` is a Codex skill for rebuilding a supplied image as a `1080px` wide Photoshop document while keeping the visual result close to the original.

It is built around a conservative rule:

> Fidelity beats editability.

The skill splits only what can be separated cleanly. It prefers a smaller number of intact, usable layers over fragile masks, broken edges, halos, transparent holes, smeared repairs, or collage-like results.

## Best For

- Poster rebuilds
- Flyer and event graphics
- Product visuals
- Ad images
- Xiaohongshu / Rednote cards
- Long poster screenshots
- Images that need editable Chinese text in Photoshop

Use prompts like:

```text
Use $poster-to-editable-psd to rebuild this uploaded poster image as a Photoshop 2026 editable layered PSD.
```

Chinese triggers include:

```text
海报拆解
海报复刻
图片转 PSD
Photoshop 可编辑分层文件
像素级对齐
文字可编辑
元素透明 PNG 导出
PSD 打开校验
```

## Deliverables

The skill asks Codex to create a full rebuild package:

- `*_可编辑分层.psd`
- `png_elements_*/` with transparent movable elements
- `*_图层预览图.png`
- `*_Photoshop打开校验图.png`
- `*_拆层说明.md`
- Optional text templates when native Photoshop text cannot cover everything

## Quality Principles

- Keep `00_完整原图备份` as the complete bottom-most reference layer.
- Build `01_干净背景` without transparent gaps.
- Identify every readable text string before rebuilding.
- Recreate readable text as Photoshop native editable text whenever possible.
- Export independently split elements as transparent PNGs.
- Verify the PSD by opening it in Photoshop 2026 when Photoshop is available.

## Repository Layout

```text
.
├── SKILL.md
├── references/
│   └── psd-rebuild-checklist.md
├── agents/
│   └── openai.yaml
└── docs/
    └── images/
        └── poster-to-editable-psd-xhs-card.png
```

## Installation

Copy this folder into your Codex skills directory:

```bash
mkdir -p ~/.codex/skills
cp -R poster-to-editable-psd ~/.codex/skills/
```

Then invoke it in Codex with:

```text
$poster-to-editable-psd
```

## Notes

This skill does not guarantee perfect automatic extraction for every image. Hair, smoke, glow, reflections, glass, dense plants, shadows, and heavily fused textures may be retained in the background when splitting would damage the image.

That restraint is intentional. A clean, believable PSD is more useful than a maximal layer count.

## License

MIT
