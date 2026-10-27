# PSD Rebuild Checklist

Use this checklist for complex poster rebuilds or whenever quality risk is high.

## Input Audit

- Record source file path.
- Record original width and height.
- Compute final canvas: `1080 x round(original_height * 1080 / original_width)`.
- Save a scaled source copy named `00_完整原图备份_1080px.png`.
- Inspect the image at full size and at 100% final scale.
- OCR visible text and manually review missed text.

## Layer Plan

Create a short plan before asset extraction:

| Layer/Group | Content | Action | Risk | Notes |
| --- | --- | --- | --- | --- |
| `01_干净背景` | Background without removable objects | repair / retain | low/medium/high | explain retained regions |
| `03_主体元素_*` | Main subject/product/object | split / retain | low/medium/high | edge notes |
| `08_Logo印章图标_*` | Logos, seals, badges | split / editable text / retain | low/medium/high | OCR notes |
| `10_主标题文字_可编辑` | Main title | native text | low/medium/high | font fallback |

Use `retain` when splitting would create damage. Retained elements must be reported as `未强行拆分`.

## Background Quality Gate

Reject and redo the background if any of these are visible:

- Transparent hole.
- Repeated clone pattern.
- Smeared face/body/product edge.
- White or black fringe.
- Old text residue that competes with rebuilt text.
- Broken texture where a viewer would notice the repair before noticing the design.

If repair cannot pass this gate, keep that area closer to the original and document the limitation.

## Element PNG Gate

Each transparent PNG should pass:

- Object is whole and not arbitrarily chopped.
- Edge is natural at 100% zoom.
- No white/black halo on dark and light backgrounds.
- No missing semi-transparent detail unless intentionally retained with background.
- File name matches the PSD layer name.

## Text Gate

For each readable text group:

- Content is correct or marked low-confidence.
- Photoshop layer is native editable text when possible.
- Font style, size, color, alignment, rotation, direction, and line breaks approximate the source.
- Chinese, Japanese, Korean, punctuation, and special symbols are not garbled.
- Text does not overlap nearby elements after Photoshop opens the PSD.

If a text effect cannot be recreated as native text, add a separate effect/image layer but keep the editable text layer available.

## Photoshop 2026 Verification

Before delivery:

- Open the PSD in Adobe Photoshop 2026.
- Export a flattened verification image from the opened PSD.
- Compare the verification image against the scaled source.
- Check layer names in Photoshop, not only in the generating script.
- Move at least one main object layer mentally or physically to confirm it is an independent layer.
- Confirm `00_完整原图备份` is bottom-most and untouched.

If Photoshop is unavailable, state that final Photoshop-open verification could not be performed and provide the strongest available substitute checks.

## Notes Template

```markdown
# 拆层说明

- 原图尺寸：
- 最终画布：
- 缩放比例：
- PSD 文件：
- Photoshop 打开校验：

## 已拆分元素

- `03_主体元素_*`：
- `04_前景元素_*`：
- `07_装饰元素_*`：
- `08_Logo印章图标_*`：

## 可编辑文字

- `10_主标题文字_可编辑`：
- `11_副标题文字_可编辑`：
- `12_正文文字_可编辑`：
- `13_小字说明_可编辑`：
- 低置信度文字：

## 未强行拆分

- 元素：
- 原因：

## 交付清单

- PSD：
- 透明 PNG：
- 图层预览图：
- Photoshop 打开校验图：
- 文字模板（如有）：
```
