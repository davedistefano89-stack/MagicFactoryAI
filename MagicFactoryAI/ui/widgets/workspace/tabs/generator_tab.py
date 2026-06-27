"""Generator tab within the project workspace."""

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
    QLineEdit,
    QMessageBox,
    QPushButton,
    QSlider,
    QVBoxLayout,
)

from app.controllers.generator_controller import GeneratorController
from app.controllers.prompt_controller import PromptController
from core.theme.colors import Colors
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


class GeneratorTab(WorkspaceTabBase):
    """Generate line-art assets from source images and prompts."""

    def _build_ui(self) -> None:
        self._gen_ctrl = GeneratorController(self.controller)
        self._prompt_ctrl = PromptController(self.controller)

        form_frame = QFrame()
        form_frame.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)
        form_layout = QVBoxLayout(form_frame)
        form_layout.setContentsMargins(28, 24, 28, 24)
        form_layout.setSpacing(16)

        intro = QLabel(
            "Convert a source image into coloring book line art. "
            "Optionally link a prompt template to the generated asset."
        )
        intro.setWordWrap(True)
        intro.setStyleSheet(f"color: {Colors.TEXT_SECONDARY};")
        form_layout.addWidget(intro)

        form = QFormLayout()
        form.setSpacing(12)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)

        self._name_input = QLineEdit()
        self._name_input.setPlaceholderText("Asset name")
        form.addRow("Asset Name", self._name_input)

        source_row = QHBoxLayout()
        self._source_label = QLabel("No file selected")
        self._source_label.setStyleSheet(f"color: {Colors.TEXT_MUTED};")
        browse_btn = QPushButton("Browse...")
        browse_btn.setProperty("cssClass", "secondary")
        browse_btn.clicked.connect(self._on_browse)
        source_row.addWidget(self._source_label, stretch=1)
        source_row.addWidget(browse_btn)
        form.addRow("Source Image", source_row)

        self._prompt_combo = QComboBox()
        self._prompt_combo.addItem("— No prompt —", None)
        form.addRow("Prompt Template", self._prompt_combo)

        threshold_row = QHBoxLayout()
        self._threshold_slider = QSlider(Qt.Orientation.Horizontal)
        self._threshold_slider.setRange(50, 255)
        self._threshold_slider.setValue(128)
        self._threshold_label = QLabel("128")
        self._threshold_slider.valueChanged.connect(
            lambda v: self._threshold_label.setText(str(v))
        )
        threshold_row.addWidget(self._threshold_slider)
        threshold_row.addWidget(self._threshold_label)
        form.addRow("Edge Threshold", threshold_row)

        form_layout.addLayout(form)

        self._status_label = QLabel("")
        self._status_label.setStyleSheet(f"color: {Colors.TEXT_SECONDARY};")
        form_layout.addWidget(self._status_label)

        btn_row = QHBoxLayout()
        btn_row.addStretch()
        generate_btn = QPushButton("Generate Line Art")
        generate_btn.setProperty("cssClass", "primary")
        generate_btn.setFixedWidth(180)
        generate_btn.clicked.connect(self._on_generate)
        btn_row.addWidget(generate_btn)
        form_layout.addLayout(btn_row)

        self._layout.addWidget(form_frame)
        self._layout.addStretch()
        self._source_path: Path | None = None

    def _on_browse(self) -> None:
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Select Source Image", "",
            "Images (*.png *.jpg *.jpeg *.webp *.bmp)",
        )
        if file_path:
            self._source_path = Path(file_path)
            self._source_label.setText(self._source_path.name)
            if not self._name_input.text().strip():
                self._name_input.setText(self._source_path.stem)

    def _on_generate(self) -> None:
        if not self.workspace.project_id:
            QMessageBox.warning(self, "No Project", "Open a project first.")
            return
        if not self._source_path or not self._source_path.exists():
            QMessageBox.warning(self, "No Source", "Select a source image first.")
            return

        name = self._name_input.text().strip()
        if not name:
            QMessageBox.warning(self, "Validation", "Asset name is required.")
            return

        try:
            asset = self._gen_ctrl.generate_from_image(
                source_path=self._source_path,
                name=name,
                project_id=self.workspace.project_id,
                category_id=self.workspace.category_id,
                prompt_id=self._prompt_combo.currentData(),
                threshold=self._threshold_slider.value(),
            )
            self._status_label.setText(
                f"Generated '{asset.name}' ({asset.width}×{asset.height}) — "
                "view in Library or Review tab."
            )
            self._name_input.clear()
            self._source_path = None
            self._source_label.setText("No file selected")
            self.workspace.workspace_refresh.emit()
        except Exception as exc:
            QMessageBox.critical(self, "Generation Failed", str(exc))

    def refresh(self) -> None:

        self._prompt_combo.clear()
        self._prompt_combo.addItem("— No prompt —", None)

        # Carica TUTTI i prompt globali
        for prompt in self._prompt_ctrl.get_all():
            self._prompt_combo.addItem(prompt.title, prompt.id)

        # Carica anche quelli della categoria corrente
        if self.workspace.category_id is not None:

            for prompt in self._prompt_ctrl.get_all(
                category_id=self.workspace.category_id
            ):

                if self._prompt_combo.findData(prompt.id) == -1:
                    self._prompt_combo.addItem(
                        prompt.title,
                        prompt.id,
                    )