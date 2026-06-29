"""Asset Inspector PRO — read-only two-panel viewer dialog."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Optional

from PySide6.QtCore import Qt, QSize
from PySide6.QtGui import QPixmap, QGuiApplication
from PySide6.QtWidgets import (
    QDialog,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from models.asset import Asset


class AssetInspectorDialog(QDialog):
    """Professional read-only Asset Inspector with split-panel layout."""

    def __init__(self, asset: Asset, controller, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self._asset = asset
        self._controller = controller
        self._zoom_factor: float = 1.0
        self._original_pixmap: Optional[QPixmap] = None

        self.setWindowTitle(f"Asset Inspector — {asset.name}")
        self.setMinimumSize(1100, 680)
        self.resize(1200, 720)
        self.setModal(True)

        self._build_ui()
        self._load_image()
        self._populate_metadata()

    def _build_ui(self) -> None:
        root_layout = QVBoxLayout(self)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(1)

        splitter.addWidget(self._build_left_panel())
        splitter.addWidget(self._build_right_panel())
        splitter.setSizes([560, 540])
        splitter.setStretchFactor(0, 1)
        splitter.setStretchFactor(1, 0)

        root_layout.addWidget(splitter, 1)
        root_layout.addWidget(self._build_footer())

    def _build_left_panel(self) -> QWidget:
        panel = QWidget()
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(16, 16, 8, 16)
        layout.setSpacing(10)

        toolbar = QHBoxLayout()
        toolbar.setSpacing(8)

        self._zoom_in_btn = QPushButton("🔍 +")
        self._zoom_out_btn = QPushButton("🔍 −")
        self._fit_btn = QPushButton("⊡ Fit")
        self._reset_btn = QPushButton("1:1")

        for btn in (self._zoom_in_btn, self._zoom_out_btn, self._fit_btn, self._reset_btn):
            btn.setFixedHeight(30)
            btn.setProperty("cssClass", "ghost")
            toolbar.addWidget(btn)

        toolbar.addStretch()

        self._zoom_label = QLabel("100%")
        self._zoom_label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        self._zoom_label.setFixedWidth(50)
        toolbar.addWidget(self._zoom_label)

        layout.addLayout(toolbar)

        self._image_scroll = QScrollArea()
        self._image_scroll.setWidgetResizable(False)
        self._image_scroll.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._image_scroll.setFrameShape(QFrame.Shape.StyledPanel)
        self._image_scroll.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )

        self._image_label = QLabel()
        self._image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._image_label.setSizePolicy(
            QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Ignored
        )
        self._image_scroll.setWidget(self._image_label)

        layout.addWidget(self._image_scroll, 1)

        self._zoom_in_btn.clicked.connect(self._on_zoom_in)
        self._zoom_out_btn.clicked.connect(self._on_zoom_out)
        self._fit_btn.clicked.connect(self._on_fit)
        self._reset_btn.clicked.connect(self._on_reset_zoom)

        return panel

    def _build_right_panel(self) -> QWidget:
        outer = QScrollArea()
        outer.setWidgetResizable(True)
        outer.setFrameShape(QFrame.Shape.NoFrame)
        outer.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        container = QWidget()
        layout = QVBoxLayout(container)
        layout.setContentsMargins(8, 16, 16, 16)
        layout.setSpacing(14)

        layout.addWidget(self._build_metadata_group())
        layout.addWidget(self._build_prompt_group())
        layout.addWidget(self._build_neg_prompt_group())
        layout.addWidget(self._build_technical_group())
        layout.addStretch()

        outer.setWidget(container)
        return outer

    def _build_metadata_group(self) -> QGroupBox:
        box = QGroupBox("Metadata")
        layout = QVBoxLayout(box)
        layout.setSpacing(6)

        self._meta_filename = self._meta_row(layout, "File name")
        self._meta_category = self._meta_row(layout, "Category")
        self._meta_status = self._meta_row(layout, "Status")
        self._meta_resolution = self._meta_row(layout, "Resolution")
        self._meta_provider = self._meta_row(layout, "Provider")
        self._meta_model = self._meta_row(layout, "Model")
        self._meta_created = self._meta_row(layout, "Created")

        return box

    def _build_prompt_group(self) -> QGroupBox:
        box = QGroupBox("Prompt")
        layout = QVBoxLayout(box)
        layout.setSpacing(6)

        self._prompt_edit = QTextEdit()
        self._prompt_edit.setReadOnly(True)
        self._prompt_edit.setFixedHeight(90)
        self._prompt_edit.setPlaceholderText("No prompt recorded.")
        layout.addWidget(self._prompt_edit)

        copy_btn = QPushButton("Copy Prompt")
        copy_btn.setProperty("cssClass", "ghost")
        copy_btn.setFixedHeight(28)
        copy_btn.clicked.connect(lambda: self._copy_text(self._prompt_edit.toPlainText()))
        layout.addWidget(copy_btn)

        return box

    def _build_neg_prompt_group(self) -> QGroupBox:
        box = QGroupBox("Negative Prompt")
        layout = QVBoxLayout(box)
        layout.setSpacing(6)

        self._neg_prompt_edit = QTextEdit()
        self._neg_prompt_edit.setReadOnly(True)
        self._neg_prompt_edit.setFixedHeight(90)
        self._neg_prompt_edit.setPlaceholderText("No negative prompt recorded.")
        layout.addWidget(self._neg_prompt_edit)

        copy_btn = QPushButton("Copy Negative Prompt")
        copy_btn.setProperty("cssClass", "ghost")
        copy_btn.setFixedHeight(28)
        copy_btn.clicked.connect(lambda: self._copy_text(self._neg_prompt_edit.toPlainText()))
        layout.addWidget(copy_btn)

        return box

    def _build_technical_group(self) -> QGroupBox:
        box = QGroupBox("Technical")
        layout = QVBoxLayout(box)
        layout.setSpacing(6)

        self._tech_size = self._meta_row(layout, "Image size")
        self._tech_format = self._meta_row(layout, "Format")
        self._tech_width = self._meta_row(layout, "Width")
        self._tech_height = self._meta_row(layout, "Height")

        return box

    def _build_footer(self) -> QWidget:
        footer = QFrame()
        footer.setFrameShape(QFrame.Shape.NoFrame)
        footer.setFixedHeight(56)

        layout = QHBoxLayout(footer)
        layout.setContentsMargins(16, 8, 16, 8)
        layout.addStretch()

        close_btn = QPushButton("Close")
        close_btn.setFixedWidth(100)
        close_btn.clicked.connect(self.accept)
        layout.addWidget(close_btn)

        return footer

    def _meta_row(self, parent_layout: QVBoxLayout, label: str) -> QLabel:
        row = QHBoxLayout()
        row.setSpacing(8)

        lbl = QLabel(f"{label}:")
        lbl.setFixedWidth(110)
        lbl.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop)

        value_lbl = QLabel("—")
        value_lbl.setWordWrap(True)
        value_lbl.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)

        row.addWidget(lbl)
        row.addWidget(value_lbl, 1)
        parent_layout.addLayout(row)

        return value_lbl

    def _load_image(self) -> None:
        file_path = self._asset.file_path
        if file_path and Path(file_path).exists():
            pixmap = QPixmap(file_path)
            if not pixmap.isNull():
                self._original_pixmap = pixmap
                self._on_fit()
                return

        self._image_label.setText("Image not available")

    def _apply_zoom(self) -> None:
        if self._original_pixmap is None:
            return

        new_w = int(self._original_pixmap.width() * self._zoom_factor)
        new_h = int(self._original_pixmap.height() * self._zoom_factor)

        scaled = self._original_pixmap.scaled(
            new_w, new_h,
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        )
        self._image_label.setPixmap(scaled)
        self._image_label.resize(scaled.size())
        self._zoom_label.setText(f"{int(self._zoom_factor * 100)}%")

    def _on_zoom_in(self) -> None:
        self._zoom_factor = min(self._zoom_factor * 1.25, 8.0)
        self._apply_zoom()

    def _on_zoom_out(self) -> None:
        self._zoom_factor = max(self._zoom_factor * 0.8, 0.05)
        self._apply_zoom()

    def _on_fit(self) -> None:
        if self._original_pixmap is None:
            return
        vp = self._image_scroll.viewport().size()
        scale_w = vp.width() / self._original_pixmap.width()
        scale_h = vp.height() / self._original_pixmap.height()
        self._zoom_factor = min(scale_w, scale_h) * 0.97
        self._apply_zoom()

    def _on_reset_zoom(self) -> None:
        self._zoom_factor = 1.0
        self._apply_zoom()

    def _populate_metadata(self) -> None:
        asset = self._asset
        meta = {}
        try:
            meta = json.loads(asset.metadata_json or "{}")
        except (json.JSONDecodeError, TypeError):
            pass

        file_path = asset.file_path or ""
        self._meta_filename.setText(Path(file_path).name if file_path else "—")

        category_name = "—"
        if asset.category_id is not None:
            try:
                cat = self._controller.categories.get_by_id(asset.category_id)
                if cat:
                    category_name = cat.name
            except Exception:
                category_name = str(asset.category_id)
        self._meta_category.setText(category_name)

        self._meta_status.setText(asset.status.value.title() if asset.status else "—")

        if asset.width and asset.height:
            self._meta_resolution.setText(f"{asset.width} × {asset.height} px")
        else:
            self._meta_resolution.setText("—")

        self._meta_provider.setText(meta.get("provider") or "—")
        self._meta_model.setText(meta.get("model") or "—")
        self._meta_created.setText(
            asset.created_at.strftime("%Y-%m-%d %H:%M") if asset.created_at else "—"
        )

        self._prompt_edit.setPlainText(meta.get("prompt") or "")
        self._neg_prompt_edit.setPlainText(meta.get("negative_prompt") or "")

        if file_path and Path(file_path).exists():
            size_kb = os.path.getsize(file_path) / 1024
            self._tech_size.setText(f"{size_kb:.1f} KB")
            suffix = Path(file_path).suffix.lstrip(".").upper() or "—"
            self._tech_format.setText(suffix)
        else:
            self._tech_size.setText("—")
            self._tech_format.setText("—")

        self._tech_width.setText(f"{asset.width} px" if asset.width else "—")
        self._tech_height.setText(f"{asset.height} px" if asset.height else "—")

    @staticmethod
    def _copy_text(text: str) -> None:
        if text.strip():
            QGuiApplication.clipboard().setText(text)
