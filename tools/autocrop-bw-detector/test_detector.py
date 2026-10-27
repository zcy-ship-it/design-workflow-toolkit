"""Synthetic border and rejection cases; no private images required."""
from pathlib import Path
import tempfile
import unittest
import sys

import cv2
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
import detect


class DetectorTests(unittest.TestCase):
    def test_centered_rotated_frames(self):
        for size, angle, inverted in [
            ((800, 530), 0, False),
            ((800, 530), 5, False),
            ((530, 800), -4, False),
            ((630, 630), 3, False),
            ((800, 530), -5, True),
        ]:
            with self.subTest(size=size, angle=angle, inverted=inverted):
                image = np.full((1100, 1200, 3), 8, np.uint8)
                rect = ((600, 550), size, angle)
                mask = np.zeros(image.shape[:2], np.uint8)
                cv2.fillConvexPoly(mask, cv2.boxPoints(rect).round().astype(np.int32), 255)
                y, x = np.mgrid[:1100, :1200]
                texture = (110 + 35 * np.sin(x / 41) * np.cos(y / 27)).astype(np.uint8)
                image[mask != 0] = np.repeat(texture[:, :, None], 3, axis=2)[mask != 0]
                for px in range(220, 1000, 100):
                    cv2.rectangle(image, (px, 40), (px + 35, 70), (250, 250, 250), -1)
                if inverted:
                    image = 255 - image
                with tempfile.TemporaryDirectory() as folder:
                    path = Path(folder) / 'sample.jpg'
                    cv2.imencode('.jpg', image)[1].tofile(path)
                    got = detect.process(path)
                    expected = detect.lr_coordinates(rect, image.shape)
                    self.assertLess(max(abs(got[i] - expected[i]) for i in range(4)), .015)
                    self.assertLess(abs(got[4] - angle), .3)

    def test_blank_rejected_and_stale_output_removed(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'blank.jpg'
            result = Path(str(path) + '.txt')
            cv2.imencode('.jpg', np.full((500, 600, 3), 100, np.uint8))[1].tofile(path)
            result.write_text('stale crop', encoding='ascii')
            with self.assertRaises(ValueError):
                detect.process(path)
            self.assertFalse(result.exists())


if __name__ == '__main__':
    unittest.main()
