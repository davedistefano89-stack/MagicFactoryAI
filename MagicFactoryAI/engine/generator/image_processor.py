"""Image processing utilities using Pillow and OpenCV."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

import cv2
import numpy as np
from PIL import Image, ImageFilter

from utils.logger import get_logger

logger = get_logger(__name__)


@dataclass
class ProcessResult:
    success: bool
    output_path: Optional[Path] = None
    width: int = 0
    height: int = 0
    error: str = ""


class ImageProcessor:
    """Processes coloring book line art assets."""

    def __init__(self, line_thickness: int = 2) -> None:
        self.line_thickness = line_thickness

    def create_canvas(
        self,
        width: int,
        height: int,
        background: str = "white",
    ) -> Image.Image:
        return Image.new("RGB", (width, height), background)

    def convert_to_line_art(
        self,
        input_path: Path,
        output_path: Path,
        threshold: int = 128,
    ) -> ProcessResult:
        """Convert a photo or sketch into clean black-and-white line art."""
        try:
            img = cv2.imread(str(input_path), cv2.IMREAD_GRAYSCALE)
            if img is None:
                return ProcessResult(success=False, error=f"Could not read image: {input_path}")

            blurred = cv2.GaussianBlur(img, (5, 5), 0)
            edges = cv2.Canny(blurred, threshold // 2, threshold)
            inverted = cv2.bitwise_not(edges)

            output_path.parent.mkdir(parents=True, exist_ok=True)
            cv2.imwrite(str(output_path), inverted)

            h, w = inverted.shape[:2]
            logger.info("Line art created: %s (%dx%d)", output_path, w, h)
            return ProcessResult(success=True, output_path=output_path, width=w, height=h)

        except Exception as exc:
            logger.exception("Line art conversion failed")
            return ProcessResult(success=False, error=str(exc))

    def create_thumbnail(
        self,
        input_path: Path,
        output_path: Path,
        size: Tuple[int, int] = (256, 256),
    ) -> ProcessResult:
        """Generate a thumbnail for library display."""
        try:
            with Image.open(input_path) as img:
                img.thumbnail(size, Image.Resampling.LANCZOS)
                output_path.parent.mkdir(parents=True, exist_ok=True)
                img.save(output_path, optimize=True)

            logger.info("Thumbnail created: %s", output_path)
            return ProcessResult(
                success=True,
                output_path=output_path,
                width=img.width,
                height=img.height,
            )
        except Exception as exc:
            logger.exception("Thumbnail creation failed")
            return ProcessResult(success=False, error=str(exc))

    def resize(
        self,
        input_path: Path,
        output_path: Path,
        width: int,
        height: int,
    ) -> ProcessResult:
        """Resize an image to exact dimensions."""
        try:
            with Image.open(input_path) as img:
                resized = img.resize((width, height), Image.Resampling.LANCZOS)
                output_path.parent.mkdir(parents=True, exist_ok=True)
                resized.save(output_path, optimize=True)

            return ProcessResult(success=True, output_path=output_path, width=width, height=height)
        except Exception as exc:
            logger.exception("Resize failed")
            return ProcessResult(success=False, error=str(exc))

    def get_dimensions(self, image_path: Path) -> Tuple[int, int]:
        with Image.open(image_path) as img:
            return img.size

    def validate_coloring_asset(self, image_path: Path) -> dict:
        """Analyze an asset for coloring book suitability."""
        img = cv2.imread(str(image_path), cv2.IMREAD_GRAYSCALE)
        if img is None:
            return {"valid": False, "reason": "Unreadable image"}

        h, w = img.shape
        unique_values = len(np.unique(img))
        white_ratio = np.sum(img > 200) / img.size
        black_ratio = np.sum(img < 50) / img.size

        is_valid = unique_values <= 256 and white_ratio > 0.3 and black_ratio > 0.01

        return {
            "valid": is_valid,
            "width": w,
            "height": h,
            "unique_values": unique_values,
            "white_ratio": round(white_ratio, 3),
            "black_ratio": round(black_ratio, 3),
        }

    def add_border(
        self,
        input_path: Path,
        output_path: Path,
        border_width: int = 20,
        border_color: str = "white",
    ) -> ProcessResult:
        """Add a uniform border around an asset."""
        try:
            with Image.open(input_path) as img:
                new_w = img.width + border_width * 2
                new_h = img.height + border_width * 2
                canvas = Image.new(img.mode, (new_w, new_h), border_color)
                canvas.paste(img, (border_width, border_width))
                output_path.parent.mkdir(parents=True, exist_ok=True)
                canvas.save(output_path, optimize=True)

            return ProcessResult(
                success=True,
                output_path=output_path,
                width=new_w,
                height=new_h,
            )
        except Exception as exc:
            logger.exception("Border addition failed")
            return ProcessResult(success=False, error=str(exc))

    def smooth_lines(
        self,
        input_path: Path,
        output_path: Path,
        blur_radius: int = 1,
    ) -> ProcessResult:
        """Apply slight smoothing to reduce jagged line art edges."""
        try:
            with Image.open(input_path) as img:
                smoothed = img.filter(ImageFilter.GaussianBlur(radius=blur_radius))
                output_path.parent.mkdir(parents=True, exist_ok=True)
                smoothed.save(output_path, optimize=True)

            return ProcessResult(
                success=True,
                output_path=output_path,
                width=img.width,
                height=img.height,
            )
        except Exception as exc:
            logger.exception("Line smoothing failed")
            return ProcessResult(success=False, error=str(exc))
