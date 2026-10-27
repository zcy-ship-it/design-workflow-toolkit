---
name: poster-to-editable-psd
description: Rebuild uploaded poster, flyer, ad, event graphic, product visual, social card, long poster, or screenshot image into a Photoshop 2026 compatible editable layered PSD. Use when the user asks for 海报拆解, 海报复刻, 图片转 PSD, Photoshop 可编辑分层文件, 像素级对齐, 文字可编辑, 元素透明 PNG 导出, 图层预览, or PSD 打开校验.
---

# Poster To Editable PSD

## Goal

Convert the supplied image into a `1080px` wide Photoshop 2026 layered PSD whose visual result closely matches the original while keeping major objects movable and readable text editable.

Core rule: fidelity beats editability. Split only what can be separated cleanly. Prefer fewer intact layers over broken masks, jagged edges, white/black halos, transparent holes, smeared fills, or a collage look.

## Non-Negotiables

- Canvas width must be `1080px`; height is proportional to the source unless the user explicitly requests another height.
- Keep `00_完整原图备份` as the complete, uncropped, bottom-most layer. Do not crop, paint over, mask, or damage it.
- Add `01_干净背景` above the backup. Remove text/logos/foreground only when the repair can look natural. If natural repair is not feasible, keep the original fused background and document it.
- Precisely identify every readable text string before rebuilding. Do not guess, paraphrase, normalize, or substitute visually similar characters. If a character/word is uncertain, mark it low-confidence and ask the user or preserve the original as a visible reference; never silently ship wrong text.
- Recreate all readable text as visible Photoshop native editable text layers whenever possible. Text-effect PNGs may be included as hidden references, but they must not replace editable text as the default visible layer.
- Export every independently split element as a transparent PNG.
- Deliver a PSD, element PNGs, a layer preview, a Photoshop-open verification preview, and a short split report.
- Open the PSD in Photoshop 2026 before delivery when Photoshop is available. The verification preview is the real gate, not file existence.

## Workflow

### 1. Inspect The Source

- Measure source dimensions and compute the final scale to `1080px` width.
- View the image directly; do not rely on OCR or automation alone.
- Run OCR for all visible text, then manually correct missed or stylized text by zooming into the image.
- Create a text inventory before building the PSD: exact text, location, confidence, reading direction, line breaks, and whether it will become a native Photoshop text layer. Verify Chinese characters against the image one by one, especially visually similar characters such as `会/鉴`, `动/劲`, `运/远`, `深/梁`, `由/申`, and any stylized or partially occluded glyphs.
- If OCR and visual inspection disagree, the image wins. If the image is still ambiguous, do not choose a convenient word; mark the text low-confidence in the report and ask the user when possible.
- Identify visual regions: background, subject/object, foreground, decorations, logos/icons/seals, and text groups.
- Make a layer plan before cutting assets. Use the checklist in `references/psd-rebuild-checklist.md` when the image is complex.

### 2. Decide What To Split

Split only elements that satisfy all of these:

- The element is visually complete and can be moved as one object.
- Its edge can be extracted without obvious halos, missing pixels, or torn semi-transparent details.
- Removing it from `01_干净背景` will not create an unnatural hole.

Prioritize:

- Main people, products, buildings, animals, vehicles, or hero objects.
- Foreground and midground objects.
- Logos, seals, icons, badges, decorative marks.
- Large separable background areas such as sky, ground, wall, table, water, mountain, or plants when they are cleanly separable.
- All readable text.

Do not split:

- Hair, glow, smoke, shadows, reflections, complex plants, transparent glass, or soft gradients when extraction causes damage.
- Objects that are deeply fused with texture or lighting.
- Tiny fragments that create many layers but do not improve editability.

If an element is not safely separable, leave it in `01_干净背景` or the nearest intact visual layer and note `未强行拆分`.

### 3. Build Background Layers

- `00_完整原图备份`: place the complete scaled source image at the bottom.
- `01_干净背景`: create the best natural background above it.
- Use content-aware fill, clone/heal, inpainting, painted reconstruction, or retained original background according to risk.
- Never leave transparent gaps in `01_干净背景`.
- Inspect background at 100% zoom for smears, repeated patterns, broken edges, white borders, black borders, and leftover text.

### 4. Extract Movable Elements

- Export each safe split as transparent PNG at final canvas scale.
- Preserve soft shadows with the object when the shadow belongs to the object; keep cast shadows in the background when moving the object would otherwise look fake.
- Use masks with natural feathering only where the source edge is soft. Keep hard graphic edges crisp.
- Keep whole objects intact. Do not cut a face, product, building, logo, or decoration into arbitrary pieces.
- Name layers with clear Chinese numbered names.

Suggested layer order:

```text
00_完整原图备份
01_干净背景
02_背景元素_天空地面墙面等
03_主体元素_自动命名
04_前景元素_自动命名
05_左侧元素_自动命名
06_右侧元素_自动命名
07_装饰元素_自动命名
08_Logo印章图标_自动命名
09_其他可移动元素_自动命名
10_主标题文字_可编辑
11_副标题文字_可编辑
12_正文文字_可编辑
13_小字说明_可编辑
14_其他文字_可编辑
```

Continue numbering when useful, but do not over-split.

### 5. Recreate Editable Text

- Create Photoshop native text layers for every readable text group. These editable text layers should be visible by default unless the report explicitly explains why a specific group cannot be made visible as native text without destroying fidelity.
- The text content must exactly match the source text. Do not auto-correct to a more common phrase, event name, slogan, or brand name. A plausible phrase is still wrong if the source glyphs say something else.
- Match content, position, font style, size, weight, color, tracking, alignment, direction, rotation, and line breaks as closely as possible.
- Separate title, subtitle, body, small print, logo text, seal text, vertical text, and decorative text into separate layers or groups.
- For uncertain OCR, create an editable placeholder at the original location and mark it low-confidence in the notes.
- For effects that Photoshop text cannot reproduce cleanly, use editable text plus separate effect layers when possible.
- If using a PNG/vector effect layer for visual fidelity, keep the editable native text layer paired with it and clearly name both layers, for example `10_主标题文字_可编辑` and `10_主标题原图效果_隐藏参考`. The default visible layer must be editable text unless the report states an unavoidable exception.
- If Photoshop native text is impossible for a text group, provide an extra editable AI/SVG/PDF text template and state which text is covered by it.
- For Chinese text in JSX/automation, protect against garbling by escaping non-ASCII strings or writing JSON with `ensure_ascii=True`.

### 6. Assemble PSD

- Prefer generating Photoshop JSX or using Photoshop scripting so the PSD is actually opened and saved by Photoshop 2026.
- Place images at exact scaled coordinates. Avoid cumulative rounding errors; compute from source coordinates multiplied by the final scale.
- Use layer groups only when they improve editability: `背景`, `主体元素`, `装饰元素`, `可编辑文字`, `参考与校验`.
- Keep Chinese layer names readable in Photoshop.
- Save both the PSD and a flattened layer preview PNG.

### 7. Verify Before Delivery

Open the PSD in Photoshop 2026 and export a verification preview from that opened document. Then visually inspect it.

Check:

- PSD opens in Photoshop 2026.
- `00_完整原图备份` is complete and bottom-most.
- `01_干净背景` covers the canvas and has no transparent holes.
- Main elements can move independently without broken edges.
- Transparent PNGs have no white edge, black edge, jagged edge, or holes.
- Text layers are editable and not garbled.
- All visible rebuilt text layers contain the exact recognized source text. Compare the PSD preview against the text inventory and the source image; reject any wrong, guessed, substituted, or normalized characters.
- Default-visible text should be native Photoshop text, not PNG, unless an exception is explicitly documented.
- Text and elements align to the original at final `1080px` scale.
- No old text residue, wrong overlap, missing layer, or obvious repair mark appears in the preview.

If verification fails, patch and rerun. Do not ship a PSD that only exists on disk but has not been checked, unless Photoshop is unavailable; if unavailable, say so clearly and provide the best alternative validation.

## Deliverables

Save a complete package:

- `*_可编辑分层.psd`
- `png_elements_*/` with `00_完整原图备份_1080px.png` and every independent transparent PNG
- `*_图层预览图.png`
- `*_Photoshop打开校验图.png`
- `*_拆层说明.md`
- Optional `*_文字模板.ai`, `*_文字模板.svg`, or `*_文字模板.pdf` when native Photoshop text cannot cover all text
- Optional generator script/JSX when useful for future fixes

## Split Report

The notes file must briefly include:

- Source size, final canvas size, and scale ratio.
- Split elements with names and coordinates.
- Exact text inventory: every readable string, confidence level, source location, and the corresponding editable text layer name.
- Editable text layers, font fallbacks, and low-confidence text. If any text could not be confidently identified, explain what is ambiguous and how it was handled.
- Elements deliberately left in the background with `未强行拆分` and the reason.
- Any limitations, such as unavailable Photoshop verification or text templates supplied separately.

## Practical Standards

- Pixel-level alignment means final preview should visually overlay the source closely at `1080px` width. Use coordinate math and preview comparison instead of eyeballing everything.
- Natural completeness matters more than maximum layer count.
- When unsure whether a cut is clean, make a conservative layer and explain the tradeoff.
- Never hide defects by placing the original backup above rebuilt layers. The backup is for recovery and comparison only.
