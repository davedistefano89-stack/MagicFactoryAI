"""Export tab within the project workspace."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox,
    QFileDialog,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QSpinBox,
    QVBoxLayout,
)

from app.controllers.export_controller import ExportController
from core.theme.colors import Colors
from engine.export.exporter import ExportOptions
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


class ExportTab(WorkspaceTabBase):
    """Export approved assets for the current project."""

    def _build_ui(self) -> None:
        self._export_ctrl = ExportController(self.controller)

        form_frame = QFrame()
        form_frame.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)
        form_layout = QVBoxLayout(form_frame)
        form_layout.setContentsMargins(32, 28, 32, 28)
        form_layout.setSpacing(20)

        intro = QLabel(
            "Export approved assets from this project for Magic Colors Adventure. "
            "A pack.json manifest is generated automatically."
        )
        intro.setWordWrap(True)
        intro.setStyleSheet(f"color: {Colors.TEXT_SECONDARY};")
        form_layout.addWidget(intro)

        form = QFormLayout()
        form.setSpacing(14)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)

        self._format_combo = QComboBox()
        self._format_combo.addItems(["png", "jpg", "webp"])
        form.addRow("Format", self._format_combo)

        self._dpi_spin = QSpinBox()
        self._dpi_spin.setRange(72, 600)
        self._dpi_spin.setValue(300)
        form.addRow("DPI", self._dpi_spin)

        self._width_spin = QSpinBox()
        self._width_spin.setRange(0, 4096)
        self._width_spin.setValue(0)
        self._width_spin.setSpecialValueText("Original")
        form.addRow("Resize Width", self._width_spin)

        self._height_spin = QSpinBox()
        self._height_spin.setRange(0, 4096)
        self._height_spin.setValue(0)
        self._height_spin.setSpecialValueText("Original")
        form.addRow("Resize Height", self._height_spin)

        form_layout.addLayout(form)

        self._status_label = QLabel("")
        self._status_label.setStyleSheet(f"color: {Colors.TEXT_SECONDARY};")
        form_layout.addWidget(self._status_label)

        btn_row = QHBoxLayout()
        btn_row.addStretch()

        export_btn = QPushButton("Export Project Assets")
        export_btn.setProperty("cssClass", "primary")
        export_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        export_btn.setFixedWidth(200)
        export_btn.clicked.connect(self._on_export)
        btn_row.addWidget(export_btn)

        form_layout.addLayout(btn_row)
        self._layout.addWidget(form_frame)
        self._layout.addStretch()

    def _on_export(self) -> None:
        if not self.workspace.project_id:
            QMessageBox.warning(self, "No Project", "Open a project first.")
            return

        output_dir = QFileDialog.getExistingDirectory(self, "Select Export Directory")
        if not output_dir:
            return

        resize_w = self._width_spin.value() or None
        resize_h = self._height_spin.value() or None

        options = ExportOptions(
            output_dir=Path(output_dir),
            format=self._format_combo.currentText(),
            dpi=self._dpi_spin.value(),
            resize_width=resize_w,
            resize_height=resize_h,
        )

        result = self._export_ctrl.export_project(self.workspace.project_id, options)

        if result.exported_count > 0:
            msg = f"Exported {result.exported_count} asset(s) to:\n{result.output_dir}"
            if result.failed_count:
                msg += f"\n\n{result.failed_count} failed."
            QMessageBox.information(self, "Export Complete", msg)
        else:
            QMessageBox.warning(
                self, "Nothing to Export",
                "No approved assets found for this project.",
            )
        self.refresh()

    def refresh(self) -> None:
        if not self.workspace.project_id:
            self._status_label.setText("No project open")
            return
        count = len(self._export_ctrl.get_exportable_assets(self.workspace.project_id))
        self._status_label.setText(f"{count} approved asset(s) ready for export")
