"""PDF export engine using ReportLab.

Generates one image per page, centred inside the printable area,
on a white background. Supports:
  - Optional cover page (no page number)
  - Configurable margin presets (Standard / KDP)
  - Page numbers bottom-centre, starting after the cover
  - No upscaling of images
  - Three page sizes: 8.5 x 11, A4, 6 x 9
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from reportlab.lib.pagesizes import A4, letter
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas as rl_canvas


# ── Page sizes ────────────────────────────────────────────────────────────────
PAGE_SIZES: dict[str, tuple[float, float]] = {
    "8.5 x 11": letter,           # 612 × 792 pt
    "A4":        A4,              # 595.28 × 841.89 pt
    "6 x 9":     (6 * inch, 9 * inch),
}

# ── Margin presets (points, applied to all four sides) ────────────────────────
MARGIN_PRESETS: dict[str, float] = {
    "Standard": 0.5 * inch,   # 36 pt
    "KDP":      0.75 * inch,  # 54 pt
}

_DEFAULT_MARGIN = 0.5 * inch

# ── Page-number typography ────────────────────────────────────────────────────
_PAGE_NUM_FONT      = "Helvetica"
_PAGE_NUM_FONT_SIZE = 9
_PAGE_NUM_BOTTOM    = 18   # pt above the physical bottom edge


# ── Shared geometry ───────────────────────────────────────────────────────────

@dataclass(frozen=True)
class PageGeometry:
    """
    Computed draw rectangle for one image inside one page.

    All values are in the same unit as the inputs (points for PDF,
    pixels for Qt — callers choose the unit).

    Attributes
    ----------
    x, y        : bottom-left origin of the image (ReportLab convention).
    draw_w      : rendered image width.
    draw_h      : rendered image height.
    page_w      : full page width (same unit).
    page_h      : full page height (same unit).
    """
    x: float
    y: float
    draw_w: float
    draw_h: float
    page_w: float
    page_h: float

    @staticmethod
    def compute(
        img_w: float,
        img_h: float,
        page_w: float,
        page_h: float,
        margin: float,
    ) -> "PageGeometry":
        """
        Return the draw rectangle that centres the image (no upscaling)
        inside the printable area defined by *margin* on all four sides.

        Parameters
        ----------
        img_w, img_h : natural image dimensions (pixels or points).
        page_w, page_h : full page dimensions.
        margin : uniform margin on all sides.
        """
        avail_w = page_w - 2 * margin
        avail_h = page_h - 2 * margin

        fit_scale = min(avail_w / img_w, avail_h / img_h) if (img_w and img_h) else 1.0
        scale    = min(1.0, fit_scale)

        draw_w = img_w * scale
        draw_h = img_h * scale

        x = margin + (avail_w - draw_w) / 2
        y = margin + (avail_h - draw_h) / 2

        return PageGeometry(x=x, y=y, draw_w=draw_w, draw_h=draw_h,
                            page_w=page_w, page_h=page_h)


class BookPDFExporter:
    """
    Export a sequence of image paths as a single multi-page PDF.

    Parameters
    ----------
    page_size_name:
        One of ``"8.5 x 11"``, ``"A4"``, ``"6 x 9"``.  Defaults to ``"8.5 x 11"``.
    margin_preset:
        One of ``"Standard"`` (0.5 in) or ``"KDP"`` (0.75 in).
    """

    def __init__(
        self,
        page_size_name: str = "8.5 x 11",
        margin_preset: str = "Standard",
    ) -> None:
        self._page_size = PAGE_SIZES.get(page_size_name, letter)
        self._margin    = MARGIN_PRESETS.get(margin_preset, _DEFAULT_MARGIN)

    # ── Public API ────────────────────────────────────────────────────────────

    def export(
        self,
        image_paths: Sequence[str | Path],
        output_path: str | Path,
        cover_path: str | Path | None = None,
        show_page_numbers: bool = True,
    ) -> None:
        """
        Write a PDF to *output_path*.

        Parameters
        ----------
        image_paths:
            Ordered list of content-page image paths.
            Paths that do not exist on disk are skipped silently.
        output_path:
            Destination PDF file path.
        cover_path:
            Optional path to a cover image. Rendered as the first page
            with no page number.
        show_page_numbers:
            When ``True``, prints a page number at the bottom-centre of
            every content page (1-based, excludes the cover).

        Raises
        ------
        ValueError
            If there are no renderable pages after filtering.
        """
        valid_content = [Path(p) for p in image_paths if Path(p).exists()]

        cover: Path | None = None
        if cover_path is not None:
            cp = Path(cover_path)
            if cp.exists():
                cover = cp

        if not valid_content and cover is None:
            raise ValueError("No valid image paths provided for PDF export.")

        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        page_w, page_h = self._page_size
        c = rl_canvas.Canvas(str(output_path), pagesize=self._page_size)

        # ── Cover page (no page number) ───────────────────────────────────
        if cover is not None:
            self._draw_page(c, cover, page_w, page_h, page_number=None)
            c.showPage()

        # ── Content pages ─────────────────────────────────────────────────
        for page_num, img_path in enumerate(valid_content, start=1):
            num = page_num if show_page_numbers else None
            self._draw_page(c, img_path, page_w, page_h, page_number=num)
            c.showPage()

        c.save()

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _draw_page(
        self,
        c: rl_canvas.Canvas,
        img_path: Path,
        page_w: float,
        page_h: float,
        page_number: int | None,
    ) -> None:
        """White background, centred image (no upscale), optional page number."""
        c.setPageSize(self._page_size)
        c.setFillColorRGB(1, 1, 1)
        c.rect(0, 0, page_w, page_h, fill=1, stroke=0)

        self._draw_image_centred(c, img_path, page_w, page_h)

        if page_number is not None:
            self._draw_page_number(c, page_number, page_w)

    def _draw_image_centred(
        self,
        c: rl_canvas.Canvas,
        img_path: Path,
        page_w: float,
        page_h: float,
    ) -> None:
        """Centre the image using shared PageGeometry (no upscaling)."""
        try:
            reader = ImageReader(str(img_path))
            img_w_px, img_h_px = reader.getSize()
        except Exception:
            return

        if img_w_px <= 0 or img_h_px <= 0:
            return

        geo = PageGeometry.compute(img_w_px, img_h_px, page_w, page_h, self._margin)
        c.drawImage(reader, geo.x, geo.y,
                    width=geo.draw_w, height=geo.draw_h, mask="auto")

    def _draw_page_number(
        self,
        c: rl_canvas.Canvas,
        number: int,
        page_w: float,
    ) -> None:
        """Print the page number bottom-centre in Helvetica 9 pt."""
        c.setFont(_PAGE_NUM_FONT, _PAGE_NUM_FONT_SIZE)
        c.setFillColorRGB(0.4, 0.4, 0.4)
        c.drawCentredString(page_w / 2, _PAGE_NUM_BOTTOM, str(number))

    """
    Export a sequence of image paths as a single multi-page PDF.

    Parameters
    ----------
    page_size_name:
        One of ``"8.5 x 11"``, ``"A4"``, ``"6 x 9"``.  Defaults to ``"8.5 x 11"``.
    margin_preset:
        One of ``"Standard"`` (0.5 in) or ``"KDP"`` (0.75 in).
    """

    def __init__(
        self,
        page_size_name: str = "8.5 x 11",
        margin_preset: str = "Standard",
    ) -> None:
        self._page_size = PAGE_SIZES.get(page_size_name, letter)
        self._margin    = MARGIN_PRESETS.get(margin_preset, _DEFAULT_MARGIN)

    # ── Public API ────────────────────────────────────────────────────────────

    def export(
        self,
        image_paths: Sequence[str | Path],
        output_path: str | Path,
        cover_path: str | Path | None = None,
        show_page_numbers: bool = True,
    ) -> None:
        """
        Write a PDF to *output_path*.

        Parameters
        ----------
        image_paths:
            Ordered list of content-page image paths.
            Paths that do not exist on disk are skipped silently.
        output_path:
            Destination PDF file path.
        cover_path:
            Optional path to a cover image. Rendered as the first page
            with no page number.
        show_page_numbers:
            When ``True``, prints a page number at the bottom-centre of
            every content page (1-based, excludes the cover).

        Raises
        ------
        ValueError
            If there are no renderable pages after filtering.
        """
        valid_content = [Path(p) for p in image_paths if Path(p).exists()]

        cover: Path | None = None
        if cover_path is not None:
            cp = Path(cover_path)
            if cp.exists():
                cover = cp

        if not valid_content and cover is None:
            raise ValueError("No valid image paths provided for PDF export.")

        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        page_w, page_h = self._page_size
        c = rl_canvas.Canvas(str(output_path), pagesize=self._page_size)

        # ── Cover page (no page number) ───────────────────────────────────
        if cover is not None:
            self._draw_page(c, cover, page_w, page_h, page_number=None)
            c.showPage()

        # ── Content pages ─────────────────────────────────────────────────
        for page_num, img_path in enumerate(valid_content, start=1):
            num = page_num if show_page_numbers else None
            self._draw_page(c, img_path, page_w, page_h, page_number=num)
            c.showPage()

        c.save()

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _draw_page(
        self,
        c: rl_canvas.Canvas,
        img_path: Path,
        page_w: float,
        page_h: float,
        page_number: int | None,
    ) -> None:
        """White background, centred image (no upscale), optional page number."""
        # White background
        c.setPageSize(self._page_size)
        c.setFillColorRGB(1, 1, 1)
        c.rect(0, 0, page_w, page_h, fill=1, stroke=0)

        self._draw_image_centred(c, img_path, page_w, page_h)

        if page_number is not None:
            self._draw_page_number(c, page_number, page_w)

    def _draw_image_centred(
        self,
        c: rl_canvas.Canvas,
        img_path: Path,
        page_w: float,
        page_h: float,
    ) -> None:
        """
        Centre the image inside the printable area.
        Never upscales — if the image is smaller than the area it is
        centred at its natural size.
        """
        try:
            reader = ImageReader(str(img_path))
            img_w_px, img_h_px = reader.getSize()
        except Exception:
            return

        if img_w_px <= 0 or img_h_px <= 0:
            return

        avail_w = page_w - 2 * self._margin
        avail_h = page_h - 2 * self._margin

        # Scale to fit, but never exceed 1.0 (no upscaling)
        fit_scale = min(avail_w / img_w_px, avail_h / img_h_px)
        scale = min(1.0, fit_scale)

        draw_w = img_w_px * scale
        draw_h = img_h_px * scale

        # Centre inside the printable area
        x = self._margin + (avail_w - draw_w) / 2
        y = self._margin + (avail_h - draw_h) / 2

        c.drawImage(reader, x, y, width=draw_w, height=draw_h, mask="auto")

    def _draw_page_number(
        self,
        c: rl_canvas.Canvas,
        number: int,
        page_w: float,
    ) -> None:
        """Print the page number bottom-centre in Helvetica 9 pt."""
        text = str(number)
        c.setFont(_PAGE_NUM_FONT, _PAGE_NUM_FONT_SIZE)
        c.setFillColorRGB(0.4, 0.4, 0.4)
        c.drawCentredString(page_w / 2, _PAGE_NUM_BOTTOM, text)

