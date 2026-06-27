"""Application settings screen."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QPushButton,
    QSpinBox,
    QVBoxLayout,
)

from core.settings.manager import SettingsManager
from core.theme.colors import Colors
from ui.screens.base_screen import BaseScreen
from ui.widgets.page_header import PageHeader


class SettingsScreen(BaseScreen):
    screen_id = "settings"

    def __init__(self, controller, parent=None) -> None:
        self._settings = SettingsManager.instance()
        super().__init__(controller, parent)

    def _build_ui(self) -> None:
        self._layout.addWidget(PageHeader(
            title="Settings",
            subtitle="Configure application preferences",
        ))

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

        section = QLabel("Window")
        section.setStyleSheet(
            f"font-size: 16px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
        )
        form_layout.addWidget(section)

        form = QFormLayout()
        form.setSpacing(14)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)

        self._width_spin = QSpinBox()
        self._width_spin.setRange(800, 3840)
        self._width_spin.setValue(int(self._settings.get("app.window_width", 1400)))
        form.addRow("Window Width", self._width_spin)

        self._height_spin = QSpinBox()
        self._height_spin.setRange(600, 2160)
        self._height_spin.setValue(int(self._settings.get("app.window_height", 900)))
        form.addRow("Window Height", self._height_spin)

        self._sidebar_spin = QSpinBox()
        self._sidebar_spin.setRange(180, 400)
        self._sidebar_spin.setValue(int(self._settings.get("app.sidebar_width", 260)))
        form.addRow("Sidebar Width", self._sidebar_spin)

        form_layout.addLayout(form)

        gen_section = QLabel("Generator")
        gen_section.setStyleSheet(
            f"font-size: 16px; font-weight: 600; color: {Colors.TEXT_PRIMARY}; margin-top: 12px;"
        )
        form_layout.addWidget(gen_section)

        gen_form = QFormLayout()
        gen_form.setSpacing(14)
        gen_form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)

        self._gen_width = QSpinBox()
        self._gen_width.setRange(256, 4096)
        self._gen_width.setValue(int(self._settings.get("generator.default_width", 1024)))
        gen_form.addRow("Default Width", self._gen_width)

        self._gen_height = QSpinBox()
        self._gen_height.setRange(256, 4096)
        self._gen_height.setValue(int(self._settings.get("generator.default_height", 1024)))
        gen_form.addRow("Default Height", self._gen_height)

        self._line_thickness = QSpinBox()
        self._line_thickness.setRange(1, 10)
        self._line_thickness.setValue(int(self._settings.get("generator.line_thickness", 2)))
        gen_form.addRow("Line Thickness", self._line_thickness)

        form_layout.addLayout(gen_form)

        btn_row = QHBoxLayout()
        btn_row.addStretch()

        save_btn = QPushButton("Save Settings")
        save_btn.setProperty("cssClass", "primary")
        save_btn.setFixedWidth(140)
        save_btn.clicked.connect(self._on_save)
        btn_row.addWidget(save_btn)

        reset_btn = QPushButton("Reset to Defaults")
        reset_btn.setProperty("cssClass", "ghost")
        reset_btn.clicked.connect(self._on_reset)
        btn_row.addWidget(reset_btn)

        form_layout.addLayout(btn_row)
        self._layout.addWidget(form_frame)
        self._layout.addStretch()

    def _on_save(self) -> None:
        self._settings.set("app.window_width", self._width_spin.value(), persist=False)
        self._settings.set("app.window_height", self._height_spin.value(), persist=False)
        self._settings.set("app.sidebar_width", self._sidebar_spin.value(), persist=False)
        self._settings.set("generator.default_width", self._gen_width.value(), persist=False)
        self._settings.set("generator.default_height", self._gen_height.value(), persist=False)
        self._settings.set("generator.line_thickness", self._line_thickness.value(), persist=False)
        self._settings.save()

        QMessageBox.information(
            self,
            "Settings Saved",
            "Settings saved. Restart the application for window size changes to take effect.",
        )

    def _on_reset(self) -> None:
        reply = QMessageBox.question(
            self,
            "Reset Settings",
            "Reset all settings to defaults?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            from utils.paths import get_data_dir
            user_settings = get_data_dir() / "user_settings.json"
            if user_settings.exists():
                user_settings.unlink()
            self._settings._load()
            self.refresh()

    def refresh(self) -> None:
        self._width_spin.setValue(int(self._settings.get("app.window_width", 1400)))
        self._height_spin.setValue(int(self._settings.get("app.window_height", 900)))
        self._sidebar_spin.setValue(int(self._settings.get("app.sidebar_width", 260)))
        self._gen_width.setValue(int(self._settings.get("generator.default_width", 1024)))
        self._gen_height.setValue(int(self._settings.get("generator.default_height", 1024)))
        self._line_thickness.setValue(int(self._settings.get("generator.line_thickness", 2)))
