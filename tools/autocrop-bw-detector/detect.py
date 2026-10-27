"""Headless black-and-white adaptation of stecman's CC0 AutoCrop detector.

Only confident near-rectangular central frames are accepted. A rejected image
produces no crop file, so Lightroom keeps its original settings.
"""
import argparse
from pathlib import Path
import math
import sys
import cv2
import numpy as np


def normalized_rect(rect):
    (cx, cy), (w, h), angle = rect
    while angle > 45:
        angle -= 90
        w, h = h, w
    while angle < -45:
        angle += 90
        w, h = h, w
    return (cx, cy), (w, h), angle


def find_frame(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    height, width = gray.shape
    image_area = width * height
    if np.percentile(gray, 99) - np.percentile(gray, 1) < 12:
        raise ValueError('Low contrast / blank preview: frame not found')
    # Both polarities: negative before inversion, or a positive after inversion.
    # Unlike upstream, no saturation mask is used (it excludes B&W film).
    candidates = []
    for polarity in (cv2.THRESH_BINARY, cv2.THRESH_BINARY_INV):
        for threshold in range(15, 241, 5):
            _, mask = cv2.threshold(gray, threshold, 255, polarity)
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
            for contour in cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[-2]:
                area = cv2.contourArea(contour)
                if not 0.25 * image_area < area < 0.92 * image_area:
                    continue
                rect = normalized_rect(cv2.minAreaRect(contour))
                (cx, cy), (w, h), angle = rect
                if min(w, h) < 40 or abs(angle) > 15:
                    continue
                fill = area / (w * h)
                if fill < 0.92 or max(w, h) / min(w, h) > 2.8:
                    continue
                if abs(cx / width - 0.5) > 0.18 or abs(cy / height - 0.5) > 0.18:
                    continue
                box = cv2.boxPoints(rect)
                margin = min(width, height) * 0.008
                if box[:, 0].min() < margin or box[:, 1].min() < margin:
                    continue
                if box[:, 0].max() > width - margin or box[:, 1].max() > height - margin:
                    continue
                perimeter = cv2.arcLength(contour, True)
                approx = cv2.approxPolyDP(contour, 0.015 * perimeter, True)
                if len(approx) != 4 or not cv2.isContourConvex(approx):
                    continue
                candidates.append(rect)
    if not candidates:
        raise ValueError('No clear rectangular film frame; crop unchanged')
    # Cluster stable boundaries across thresholds. Avoid a single accidental
    # rectangle formed by subject detail. Prefer supported central boundaries.
    groups = []
    for rect in candidates:
        (cx, cy), (w, h), angle = rect
        vector = np.array([cx / width, cy / height, w / width, h / height, angle / 90])
        for group in groups:
            if np.max(np.abs(vector - group[0])) < 0.012:
                group[1].append(rect)
                break
        else:
            groups.append([vector, [rect]])
    groups.sort(key=lambda group: len(group[1]), reverse=True)
    if len(groups[0][1]) < 3:
        raise ValueError('Frame detection unstable across thresholds; crop unchanged')
    if len(groups) > 1 and len(groups[1][1]) >= 0.8 * len(groups[0][1]):
        raise ValueError('Multiple plausible borders; crop unchanged')
    rows = np.array([[r[0][0], r[0][1], r[1][0], r[1][1], r[2]] for r in groups[0][1]])
    cx, cy, w, h, angle = np.median(rows, axis=0)
    # 0.5% inset on each edge, without forcing 35mm's 3:2 ratio.
    inset = 0.005 * min(w, h)
    return (float(cx), float(cy)), (float(w - 2 * inset), float(h - 2 * inset)), float(angle)


def lr_coordinates(rect, shape):
    (cx, cy), (w, h), angle = rect
    a = math.radians(angle)
    # Lightroom stores rotated top-left and bottom-right corners, in the
    # un-oriented source pixel coordinate system (Adobe SDK crop convention).
    dx = (w * math.cos(a) - h * math.sin(a)) / 2
    dy = (w * math.sin(a) + h * math.cos(a)) / 2
    height, width = shape[:2]
    values = [(cx - dx) / width, (cx + dx) / width,
              (cy - dy) / height, (cy + dy) / height, angle]
    if not (0 <= values[0] < values[1] <= 1 and 0 <= values[2] < values[3] <= 1):
        raise ValueError('Detected crop is outside the image')
    return values


def process(filename, debug=False):
    path = Path(filename)
    result = Path(str(path) + '.txt')
    result.unlink(missing_ok=True)
    img = cv2.imdecode(np.fromfile(path, dtype=np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError('Could not read preview')
    rect = find_frame(img)
    values = lr_coordinates(rect, img.shape)
    result.write_text('\n'.join(f'{v:.10f}' for v in values), encoding='ascii')
    if debug:
        cv2.drawContours(img, [cv2.boxPoints(rect).round().astype(np.int32)], -1, (0, 255, 0), 2)
        ok, encoded = cv2.imencode('.jpg', img)
        if ok:
            encoded.tofile(str(path) + '-analysis.jpg')
    return values


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('filename')
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()
    try:
        print(*process(args.filename, args.debug), sep='\n')
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(5)
