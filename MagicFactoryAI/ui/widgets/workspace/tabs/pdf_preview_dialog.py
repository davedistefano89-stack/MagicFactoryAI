"""Print preview dialog for the Book Builder.

Renders each page using the same geometry as BookPDFExporter
(via the shared PageGeometry.compute() helper) so the preview
is pixel-accurate with the exported PDF.
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QPainter, QPixmap
from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from core.theme.colors import Colors
from engine.export.pdf_exporter import (
    MARGIN_PRESETS,
    PAGE_SIZES,
    PageGeometry,
    _DEFAULT_MARGIN,
    _PAGE_NUM_BOTTOM,
    _PAGE_NUM_FONT_SIZE,
)

# Screen DPI used for rendering the page pixmap (72 pt = 1 in)
_PT_TO_PX = 1.0          # 1 pt → 1 px at 72 dpi (baseline)
_BASE_DPI  = 72

# Zoom levels
_ZOOM_LABELS = ["50 %", "75 %", "100 %", "Fit Width", "Fit Page"]
_ZOOM_FIXED  = {"50 %": 0.50, "75 %": 0.75, "100 %": 1.00}


class _PageRenderer:
    """
    Renders a single book page to a QPixmap.

    Uses the same PageGeometry.compute() logic as BookPDFExporter
    so the result is visually identical to the exported PDF.
    """

    def __init__(self, page_w_pt: float, page_h_pt: float, margin_pt: float) -> None:
        self._page_w_pt = page_w_pt
        self._page_h_pt = page_h_pt
        self._margin_pt = margin_pt

    def render(
        self,
        img_path: Path | None,
        zoom: float,
        page_number: int | None,
    ) -> QPixmap:
        """
        Return a QPixmap at *zoom* scale.

        Parameters
        ----------
        img_path    : source image (None → blank page).
        zoom        : scale factor relative to 72 dpi (1.0 = 100 %).
        page_number : drawn bottom-centre when not None.
        """
        pw = int(self._page_w_pt * zoom)
        ph = int(self._page_h_pt * zoom)
        margin = self._margin_pt * zoom

        pixmap = QPixmap(pw, ph)
        pixmap.fill(QColor("white"))

        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)

        if img_path is not None and img_path.exists():
            src = QPixmap(str(img_path))
            if not src.isNull():
                img_w = src.width()
                img_h = src.height()
                geo = PageGeometry.compute(img_w, img_h, pw, ph, margin)
                painter.drawPixmap(
                    int(geo.x), int(ph - geo.y - geo.draw_h),
                    int(geo.draw_w), int(geo.draw_h),
                    src,
                )

        if page_number is not None:
            font = painter.font()
            font.setFamily("Segoe UI")
            font.setPointSize(int(_PAGE_NUM_FONT_SIZE * zoom))
            painter.setFont(font)
            painter.setPen(QColor(100, 100, 100))
            y_num = int(ph - _PAGE_NUM_BOTTOM * zoom)
            painter.drawText(0, y_num, pw, int(_PAGE_NUM_BOTTOM * zoom),
                             Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignBottom,
                             str(page_number))

        painter.end()
        return pixmap


class PDFPreviewDialog(QDialog):
    """
    Print preview dialog — shows pages exactly as they will appear in the PDF.

    Parameters
    ----------
    image_paths     : ordered content-page image paths.
    cover_path      : optional cover image path (page 0, no number).
    page_size_name  : one of the keys in ``PAGE_SIZES``.
    margin_preset   : one of the keys in ``MARGIN_PRESETS``.
    show_page_numbers : mirror the BookPDFExporter setting.
    parent          : Qt parent widget.
    """

    def __init__(
        self,
        image_paths: list[str],
        cover_path: str | None = None,
        page_size_name: str = "8.5 x 11",
        margin_preset: str = "Standard",
        show_page_numbers: bool = True,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle("Print Preview")
        self.setMinimumSize(780, 860)
        self.resize(860, 920)

        page_w_pt, page_h_pt = PAGE_SIZES.get(page_size_name, PAGE_SIZES["8.5 x 11"])
        margin_pt = MARGIN_PRESETS.get(margin_preset, _DEFAULT_MARGIN)

        self._renderer = _PageRenderer(page_w_pt, page_h_pt, margin_pt)
        self._show_nums = show_page_numbers

        # Build ordered page list: [(path_or_None, page_number_or_None)]
        self._pages: list[tuple[Path | None, int | None]] = []
        if cover_path and Path(cover_path).exists():
            self._pages.append((Path(cover_path), None))
        for idx, p in enumerate(image_paths, start=1):
            path = Path(p) if p and Path(p).exists() else None
            num  = idx if show_page_numbers else None
            self._pages.append((path, num))

        self._current = 0
        self._zoom    = 1.0
        self._page_w_pt = page_w_pt
        self._page_h_pt = page_h_pt

        self._build_ui()
        self._update_page()

    # ── UI construction ───────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(12, 12, 12, 12)
        root.setSpacing(10)

        root.addLayout(self._build_toolbar())

        # Scroll area containing the page pixmap
        self._scroll = QScrollArea()
        self._scroll.setWidgetResizable(False)
        self._scroll.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._scroll.setStyleSheet(f"""
            QScrollArea {{
                background-color: {Colors.BACKGROUND};
                border: 1px solid {Colors.BORDER};
                border-radius: 8px;
            }}
        """)

        self._page_label = QLabel()
        self._page_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._page_label.setSizePolicy(
            QSizePolicy.Policy.Fixed, QSizePolicy.Policy.Fixed
        )
        self._scroll.setWidget(self._page_label)
        root.addWidget(self._scroll, stretch=1)

    def _build_toolbar(self) -> QHBoxLayout:
        bar = QHBoxLayout()
        bar.setSpacing(6)

        # Prev
        self._btn_prev = QPushButton("← Prev")
        self._btn_prev.setProperty("cssClass", "ghost")
        self._btn_prev.setFixedHeight(32)
        self._btn_prev.clicked.connect(self._go_prev)
        bar.addWidget(self._btn_prev)

        # Page counter
        self._page_counter = QLabel("Page 1 of 1")
        self._page_counter.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._page_counter.setFixedWidth(120)
        self._page_counter.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-weight: 600;"
            " border: none; background: transparent;"
        )
        bar.addWidget(self._page_counter)

        # Next
        self._btn_next = QPushButton("Next →")
        self._btn_next.setProperty("cssClass", "ghost")
        self._btn_next.setFixedHeight(32)
        self._btn_next.clicked.connect(self._go_next)
        bar.addWidget(self._btn_next)

        bar.addStretch()

        # Zoom combo
        zoom_lbl = QLabel("Zoom:")
        zoom_lbl.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; border: none; background: transparent;"
        )
        bar.addWidget(zoom_lbl)

        self._zoom_combo = QComboBox()
        self._zoom_combo.setFixedWidth(120)
        for label in _ZOOM_LABELS:
            self._zoom_combo.addItem(label)
        self._zoom_combo.setCurrentText("100 %")
        self._zoom_combo.currentTextChanged.connect(self._on_zoom_changed)
        bar.addWidget(self._zoom_combo)

        return bar

    # ── Navigation ────────────────────────────────────────────────────────────

    def _go_prev(self) -> None:
        if self._current > 0:
            self._current -= 1
            self._update_page()

    def _go_next(self) -> None:
        if self._current < len(self._pages) - 1:
            self._current += 1
            self._update_page()

    # ── Zoom ─────────────────────────────────────────────────────────────────

    def _on_zoom_changed(self, label: str) -> None:
        if label in _ZOOM_FIXED:
            self._zoom = _ZOOM_FIXED[label]
        elif label == "Fit Width":
            avail = self._scroll.viewport().width() - 24
            self._zoom = max(0.1, avail / self._page_w_pt)
        elif label == "Fit Page":
            avail_w = self._scroll.viewport().width() - 24
            avail_h = self._scroll.viewport().height() - 24
            self._zoom = max(0.1, min(avail_w / self._page_w_pt,
                                      avail_h / self._page_h_pt))
        self._update_page()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        label = self._zoom_combo.currentText()
        if label in ("Fit Width", "Fit Page"):
            self._on_zoom_changed(label)

    # ── Rendering ─────────────────────────────────────────────────────────────

    def _update_page(self) -> None:
        total = len(self._pages)
        if total == 0:
            self._page_counter.setText("No pages")
            self._btn_prev.setEnabled(False)
            self._btn_next.setEnabled(False)
            self._page_label.setPixmap(QPixmap())
            return

        self._page_counter.setText(f"Page {self._current + 1} of {total}")
        self._btn_prev.setEnabled(self._current > 0)
        self._btn_next.setEnabled(self._current < total - 1)

        img_path, page_number = self._pages[self._current]
        pixmap = self._renderer.render(img_path, self._zoom, page_number)
        self._page_label.setPixmap(pixmap)
        self._page_label.resize(pixmap.size())
