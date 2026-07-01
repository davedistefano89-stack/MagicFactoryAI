"""Amazon KDP Export Wizard — 3-step dialog.

Step 1  Book Information   (trim size, interior type, bleed, paper colour)
Step 2  Validation         (page count, cover, images, missing assets)
Step 3  Summary + Export   (overview then export via BookPDFExporter)

No PDF-generation logic lives here; everything is delegated to BookPDFExporter.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

from PySide6.QtCore import Qt
from PySide6.QtGui import QImage
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

from core.theme.colors import Colors


# ── Wizard data ───────────────────────────────────────────────────────────────

@dataclass
class _WizardData:
    """Mutable bag of all data collected across wizard steps."""
    # Inputs supplied by caller
    image_paths: list[str]
    cover_path: str | None
    book_properties: dict

    # Chosen on Step 1
    trim_size: str = "8.5 x 11"
    interior_type: str = "Black & White"
    bleed: bool = False
    paper_color: str = "White"


# ── Shared style helpers ──────────────────────────────────────────────────────

_LABEL_STYLE = (
    f"color: {Colors.TEXT_MUTED}; font-size: 11px; font-weight: 500;"
    " border: none; background: transparent;"
)
_VALUE_STYLE = (
    f"color: {Colors.TEXT_PRIMARY}; font-size: 13px;"
    " border: none; background: transparent;"
)
_SECTION_STYLE = (
    f"color: {Colors.TEXT_PRIMARY}; font-size: 14px; font-weight: 700;"
    " border: none; background: transparent;"
)


def _make_card() -> QFrame:
    card = QFrame()
    card.setStyleSheet(f"""
        QFrame {{
            background-color: {Colors.SURFACE};
            border: 1px solid {Colors.BORDER};
            border-radius: 12px;
        }}
    """)
    return card


def _field_combo(
    layout: QVBoxLayout,
    label_text: str,
    options: list[str],
    default: str = "",
) -> QComboBox:
    lbl = QLabel(label_text)
    lbl.setStyleSheet(_LABEL_STYLE)
    layout.addWidget(lbl)

    combo = QComboBox()
    for opt in options:
        combo.addItem(opt)
    if default:
        idx = combo.findText(default)
        if idx >= 0:
            combo.setCurrentIndex(idx)
    layout.addWidget(combo)
    return combo


# ── Step 1: Book Information ──────────────────────────────────────────────────

class _Step1Widget(QWidget):
    """Collect KDP-specific book parameters; pre-filled from Book Properties."""

    def __init__(self, data: _WizardData, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._data = data
        self._build_ui()

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(16)

        # Header
        hdr = QLabel("Step 1 — Book Information")
        hdr.setStyleSheet(
            f"font-size: 17px; font-weight: 700; color: {Colors.TEXT_PRIMARY};"
            " background: transparent; border: none;"
        )
        outer.addWidget(hdr)

        sub = QLabel("Review and confirm KDP printing parameters.")
        sub.setStyleSheet(
            f"font-size: 13px; color: {Colors.TEXT_MUTED};"
            " background: transparent; border: none;"
        )
        outer.addWidget(sub)

        card = _make_card()
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(24, 20, 24, 20)
        card_layout.setSpacing(14)

        # Trim Size
        self._trim_combo = _field_combo(
            card_layout,
            "Trim Size",
            ["8.5 x 11", "A4", "6 x 9"],
            default=self._data.book_properties.get("paper_size", "8.5 x 11"),
        )

        # Interior Type
        self._interior_combo = _field_combo(
            card_layout,
            "Interior Type",
            ["Black & White", "Premium Color"],
            default=self._data.book_properties.get("interior_type", "Black & White"),
        )

        # Bleed
        bleed_lbl = QLabel("Bleed")
        bleed_lbl.setStyleSheet(_LABEL_STYLE)
        card_layout.addWidget(bleed_lbl)

        self._bleed_check = QCheckBox("Include 0.125″ bleed")
        self._bleed_check.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 13px;"
            " background: transparent; border: none;"
        )
        card_layout.addWidget(self._bleed_check)

        # Paper Color
        self._paper_color_combo = _field_combo(
            card_layout,
            "Paper Color",
            ["White", "Cream"],
            default="White",
        )

        outer.addWidget(card)
        outer.addStretch()

    def commit(self) -> None:
        """Write widget values back into _WizardData."""
        self._data.trim_size = self._trim_combo.currentText()
        self._data.interior_type = self._interior_combo.currentText()
        self._data.bleed = self._bleed_check.isChecked()
        self._data.paper_color = self._paper_color_combo.currentText()


# ── Step 2: Validation ────────────────────────────────────────────────────────

@dataclass
class _Check:
    icon: str          # "✅" or "⚠️"
    message: str


class _Step2Widget(QWidget):
    """Run validation checks and display warnings (no blocking)."""

    def __init__(self, data: _WizardData, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._data = data
        self._build_ui()

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(16)

        # Header
        hdr = QLabel("Step 2 — Validation")
        hdr.setStyleSheet(
            f"font-size: 17px; font-weight: 700; color: {Colors.TEXT_PRIMARY};"
            " background: transparent; border: none;"
        )
        outer.addWidget(hdr)

        sub = QLabel(
            "Warnings are shown for reference only — export is never blocked."
        )
        sub.setWordWrap(True)
        sub.setStyleSheet(
            f"font-size: 13px; color: {Colors.TEXT_MUTED};"
            " background: transparent; border: none;"
        )
        outer.addWidget(sub)

        self._card = _make_card()
        self._card_layout = QVBoxLayout(self._card)
        self._card_layout.setContentsMargins(24, 20, 24, 20)
        self._card_layout.setSpacing(10)

        outer.addWidget(self._card)
        outer.addStretch()

    def refresh(self) -> None:
        """(Re-)run all checks and repopulate the card."""
        # Clear old rows
        while self._card_layout.count():
            item = self._card_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        checks = self._run_checks()
        for chk in checks:
            row = QHBoxLayout()
            row.setSpacing(10)

            icon_lbl = QLabel(chk.icon)
            icon_lbl.setStyleSheet(
                "font-size: 15px; border: none; background: transparent;"
            )
            icon_lbl.setFixedWidth(22)
            row.addWidget(icon_lbl)

            msg_lbl = QLabel(chk.message)
            msg_lbl.setWordWrap(True)
            msg_lbl.setStyleSheet(
                f"color: {Colors.TEXT_PRIMARY}; font-size: 13px;"
                " border: none; background: transparent;"
            )
            row.addWidget(msg_lbl, stretch=1)

            wrapper = QWidget()
            wrapper.setStyleSheet("background: transparent;")
            wrapper.setLayout(row)
            self._card_layout.addWidget(wrapper)

    # ── Checks ────────────────────────────────────────────────────────────────

    def _run_checks(self) -> list[_Check]:
        checks: list[_Check] = []

        n = len(self._data.image_paths)
        if n == 0:
            checks.append(_Check("⚠️", "No content pages found in the book."))
        else:
            checks.append(_Check("✅", f"Content pages: {n} page(s)"))

        if self._data.cover_path and Path(self._data.cover_path).exists():
            checks.append(_Check("✅", "Cover image is present."))
        else:
            checks.append(_Check("⚠️", "No cover image selected in the Cover Builder."))

        # Check every image exists on disk
        missing: list[str] = [
            p for p in self._data.image_paths if not Path(p).exists()
        ]
        if missing:
            checks.append(
                _Check(
                    "⚠️",
                    f"{len(missing)} image file(s) are missing on disk "
                    f"and will be skipped during export.",
                )
            )
        else:
            checks.append(_Check("✅", "All content images found on disk."))

        # KDP minimum page count (24 pages for most trim sizes)
        total = n + (1 if self._data.cover_path else 0)
        if total > 0 and total < 24:
            checks.append(
                _Check(
                    "⚠️",
                    f"Total page count ({total}) is below the KDP minimum of 24 pages.",
                )
            )
        elif total >= 24:
            checks.append(_Check("✅", f"Total page count ({total}) meets KDP minimum."))

        # Bleed note
        if self._data.bleed:
            checks.append(
                _Check(
                    "⚠️",
                    "Bleed is enabled, but this export does not add bleed "
                    "area to images. Ensure source images have built-in bleed.",
                )
            )

        return checks


# ── Step 3: Summary ───────────────────────────────────────────────────────────

class _Step3Widget(QWidget):
    """Show export summary before final export."""

    def __init__(self, data: _WizardData, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._data = data
        self._build_ui()

    def _build_ui(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(16)

        hdr = QLabel("Step 3 — Summary")
        hdr.setStyleSheet(
            f"font-size: 17px; font-weight: 700; color: {Colors.TEXT_PRIMARY};"
            " background: transparent; border: none;"
        )
        outer.addWidget(hdr)

        sub = QLabel("Review the export settings then click Export.")
        sub.setStyleSheet(
            f"font-size: 13px; color: {Colors.TEXT_MUTED};"
            " background: transparent; border: none;"
        )
        outer.addWidget(sub)

        self._card = _make_card()
        self._card_layout = QVBoxLayout(self._card)
        self._card_layout.setContentsMargins(24, 20, 24, 20)
        self._card_layout.setSpacing(8)

        outer.addWidget(self._card)
        outer.addStretch()

    def refresh(self) -> None:
        """Repopulate the summary card from current _WizardData."""
        while self._card_layout.count():
            item = self._card_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        content_count = len(
            [p for p in self._data.image_paths if Path(p).exists()]
        )
        cover_present = bool(
            self._data.cover_path and Path(self._data.cover_path).exists()
        )
        total_pages = content_count + (1 if cover_present else 0)

        est_bytes = self._estimate_pdf_size()
        est_label = self._format_size(est_bytes)

        rows = [
            ("Total Pages",    str(total_pages)),
            ("Cover",          "Yes" if cover_present else "No"),
            ("Trim Size",      self._data.trim_size),
            ("Interior Type",  self._data.interior_type),
            ("Bleed",          "0.125″ bleed" if self._data.bleed else "No bleed"),
            ("Paper Color",    self._data.paper_color),
            ("Est. PDF Size",  est_label),
        ]

        for label_text, value_text in rows:
            row_widget = QWidget()
            row_widget.setStyleSheet("background: transparent;")
            row_h = QHBoxLayout(row_widget)
            row_h.setContentsMargins(0, 0, 0, 0)
            row_h.setSpacing(12)

            lbl = QLabel(label_text)
            lbl.setStyleSheet(_LABEL_STYLE)
            lbl.setFixedWidth(130)
            row_h.addWidget(lbl)

            val = QLabel(value_text)
            val.setStyleSheet(_VALUE_STYLE)
            row_h.addWidget(val, stretch=1)

            self._card_layout.addWidget(row_widget)

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _estimate_pdf_size(self) -> int:
        """Sum of source image file sizes as a rough PDF size estimate."""
        total = 0
        if self._data.cover_path:
            try:
                total += os.path.getsize(self._data.cover_path)
            except OSError:
                pass
        for p in self._data.image_paths:
            try:
                total += os.path.getsize(p)
            except OSError:
                pass
        return total

    @staticmethod
    def _format_size(n: int) -> str:
        if n == 0:
            return "unknown"
        if n < 1024:
            return f"{n} B"
        if n < 1024 ** 2:
            return f"{n / 1024:.1f} KB"
        return f"{n / (1024 ** 2):.1f} MB"


# ── Main Wizard Dialog ────────────────────────────────────────────────────────

class KDPExportWizard(QDialog):
    """
    3-step Amazon KDP Export Wizard.

    Parameters
    ----------
    image_paths:
        Ordered list of resolved content-page image paths (may include
        non-existent paths; validation step reports them).
    cover_path:
        Optional cover image path (from Cover Builder).
    book_properties:
        Dict produced by ``BookBuilderTab._collect_properties()``.
    parent:
        Parent widget.
    """

    def __init__(
        self,
        image_paths: list[str],
        cover_path: str | None,
        book_properties: dict,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self.setWindowTitle("📦  KDP Export")
        self.setMinimumSize(560, 520)
        self.setModal(True)
        self.setStyleSheet(f"background-color: {Colors.BACKGROUND};")

        self._data = _WizardData(
            image_paths=image_paths,
            cover_path=cover_path,
            book_properties=book_properties,
        )
        self._build_ui()

    # ── UI ────────────────────────────────────────────────────────────────────

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 20)
        root.setSpacing(20)

        # Step indicator
        self._step_label = QLabel()
        self._step_label.setAlignment(Qt.AlignmentFlag.AlignRight)
        self._step_label.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 12px;"
            " background: transparent; border: none;"
        )
        root.addWidget(self._step_label)

        # Content stack
        self._stack = QStackedWidget()

        self._step1 = _Step1Widget(self._data)
        self._step2 = _Step2Widget(self._data)
        self._step3 = _Step3Widget(self._data)

        self._stack.addWidget(self._step1)   # index 0
        self._stack.addWidget(self._step2)   # index 1
        self._stack.addWidget(self._step3)   # index 2

        root.addWidget(self._stack, stretch=1)

        # Separator
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet(f"color: {Colors.BORDER};")
        root.addWidget(sep)

        # Button bar
        btn_row = QHBoxLayout()
        btn_row.setSpacing(8)

        self._btn_cancel = QPushButton("Cancel")
        self._btn_cancel.setProperty("cssClass", "ghost")
        self._btn_cancel.setFixedHeight(36)
        self._btn_cancel.clicked.connect(self.reject)

        btn_row.addWidget(self._btn_cancel)
        btn_row.addStretch()

        self._btn_back = QPushButton("← Back")
        self._btn_back.setProperty("cssClass", "ghost")
        self._btn_back.setFixedHeight(36)
        self._btn_back.setEnabled(False)
        self._btn_back.clicked.connect(self._go_back)

        self._btn_next = QPushButton("Next →")
        self._btn_next.setProperty("cssClass", "primary")
        self._btn_next.setFixedHeight(36)
        self._btn_next.clicked.connect(self._go_next)

        self._btn_export = QPushButton("📦  Export")
        self._btn_export.setProperty("cssClass", "primary")
        self._btn_export.setFixedHeight(36)
        self._btn_export.setVisible(False)
        self._btn_export.clicked.connect(self._do_export)

        btn_row.addWidget(self._btn_back)
        btn_row.addWidget(self._btn_next)
        btn_row.addWidget(self._btn_export)

        root.addLayout(btn_row)

        self._go_to(0)

    # ── Navigation ────────────────────────────────────────────────────────────

    def _go_to(self, index: int) -> None:
        self._stack.setCurrentIndex(index)
        total = self._stack.count()
        self._step_label.setText(f"Step {index + 1} of {total}")
        self._btn_back.setEnabled(index > 0)
        on_last = (index == total - 1)
        self._btn_next.setVisible(not on_last)
        self._btn_export.setVisible(on_last)

        # Refresh data-dependent steps
        if index == 1:
            self._step2.refresh()
        elif index == 2:
            self._step3.refresh()

    def _go_back(self) -> None:
        idx = self._stack.currentIndex()
        if idx > 0:
            self._go_to(idx - 1)

    def _go_next(self) -> None:
        idx = self._stack.currentIndex()
        # Commit editable step before advancing
        if idx == 0:
            self._step1.commit()
        if idx < self._stack.count() - 1:
            self._go_to(idx + 1)

    # ── Export ────────────────────────────────────────────────────────────────

    def _do_export(self) -> None:
        """Ask for a package folder then build the publishing package."""
        folder_str = QFileDialog.getExistingDirectory(
            self,
            "KDP Export — Choose Package Folder",
            "",
        )
        if not folder_str:
            return

        try:
            self._build_publishing_package(Path(folder_str))
            QMessageBox.information(
                self,
                "KDP Export",
                f"Publishing package created in:\n{folder_str}\n\n"
                "Files: Book.pdf, Cover.pdf, manifest.json, preview.jpg",
            )
            self.accept()
        except Exception as exc:
            QMessageBox.critical(self, "Export Error", str(exc))

    def _build_publishing_package(self, folder: Path) -> None:
        """
        Write the four publishing artefacts into *folder*:

        Book.pdf     — content pages (no cover), via BookPDFExporter
        Cover.pdf    — cover page only, via BookPDFExporter
        manifest.json — book metadata
        preview.jpg  — cover image thumbnail (800 px wide)
        """
        from engine.export.pdf_exporter import BookPDFExporter

        folder.mkdir(parents=True, exist_ok=True)

        props = self._data.book_properties
        exporter = BookPDFExporter(
            page_size_name=self._data.trim_size,
            margin_preset=props.get("margin_preset", "Standard"),
        )

        valid_content = [p for p in self._data.image_paths if Path(p).exists()]
        cover: Path | None = None
        if self._data.cover_path and Path(self._data.cover_path).exists():
            cover = Path(self._data.cover_path)

        # ── Book.pdf (content pages only) ────────────────────────────────
        if valid_content:
            exporter.export(
                valid_content,
                folder / "Book.pdf",
                cover_path=None,
                show_page_numbers=True,
            )

        # ── Cover.pdf (cover page only) ───────────────────────────────────
        if cover is not None:
            exporter.export(
                [],
                folder / "Cover.pdf",
                cover_path=cover,
                show_page_numbers=False,
            )

        # ── manifest.json ─────────────────────────────────────────────────
        total_pages = len(valid_content) + (1 if cover else 0)
        manifest = {
            "title":         props.get("title", ""),
            "subtitle":      props.get("subtitle", ""),
            "author":        props.get("author", ""),
            "trim_size":     self._data.trim_size,
            "bleed":         self._data.bleed,
            "interior_type": self._data.interior_type,
            "paper_color":   self._data.paper_color,
            "page_count":    total_pages,
            "export_timestamp": datetime.now(timezone.utc).isoformat(),
        }
        (folder / "manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

        # ── preview.jpg (cover thumbnail, 800 px wide) ────────────────────
        if cover is not None:
            img = QImage(str(cover))
            if not img.isNull():
                target_w = 800
                if img.width() > target_w:
                    img = img.scaledToWidth(
                        target_w,
                        Qt.TransformationMode.SmoothTransformation,
                    )
                img.save(str(folder / "preview.jpg"), "JPEG", 90)

