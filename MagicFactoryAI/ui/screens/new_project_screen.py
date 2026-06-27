"""New project creation screen."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
)

from app.controllers.project_controller import ProjectController
from core.theme.colors import Colors
from ui.screens.base_screen import BaseScreen
from ui.widgets.page_header import PageHeader


class NewProjectScreen(BaseScreen):
    screen_id = "new_project"

    def __init__(self, controller, parent=None) -> None:
        self._project_ctrl = ProjectController(controller)
        super().__init__(controller, parent)

    def _build_ui(self) -> None:
        self._layout.addWidget(PageHeader(
            title="New Project",
            subtitle="Create a new coloring book asset project",
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

        form = QFormLayout()
        form.setSpacing(12)
        form.setLabelAlignment(Qt.AlignmentFlag.AlignRight)

        self._name_input = QLineEdit()
        self._name_input.setPlaceholderText("e.g. Forest Animals Pack")
        form.addRow("Project Name", self._name_input)

        self._desc_input = QTextEdit()
        self._desc_input.setPlaceholderText("Describe the theme, target audience, art style...")
        self._desc_input.setMaximumHeight(120)
        form.addRow("Description", self._desc_input)

        form_layout.addLayout(form)

        btn_row = QVBoxLayout()
        btn_row.setAlignment(Qt.AlignmentFlag.AlignRight)

        create_btn = QPushButton("Create Project")
        create_btn.setProperty("cssClass", "primary")
        create_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        create_btn.setFixedWidth(160)
        create_btn.clicked.connect(self._on_create)
        btn_row.addWidget(create_btn)

        form_layout.addLayout(btn_row)
        self._layout.addWidget(form_frame)

        self._layout.addWidget(self._build_project_list())
        self._layout.addStretch()

    def _build_project_list(self) -> QFrame:
        frame = QFrame()
        frame.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)
        layout = QVBoxLayout(frame)
        layout.setContentsMargins(24, 20, 24, 20)

        header = QLabel("Existing Projects")
        header.setStyleSheet(
            f"font-size: 16px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
        )
        layout.addWidget(header)

        self._project_list_layout = QVBoxLayout()
        layout.addLayout(self._project_list_layout)

        return frame

    def _on_create(self) -> None:
        name = self._name_input.text().strip()
        if not name:
            QMessageBox.warning(self, "Validation", "Project name is required.")
            return

        description = self._desc_input.toPlainText().strip()
        project = self._project_ctrl.create_project(name, description)

        QMessageBox.information(
            self,
            "Project Created",
            f"Project '{project.name}' created successfully.",
        )
        self._name_input.clear()
        self._desc_input.clear()
        self.refresh()
        self.controller.workspace.request_open_workspace(project.id)

    def refresh(self) -> None:
        while self._project_list_layout.count():
            item = self._project_list_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        projects = self._project_ctrl.get_all_projects()
        if not projects:
            empty = QLabel("No projects yet.")
            empty.setStyleSheet(f"color: {Colors.TEXT_MUTED};")
            self._project_list_layout.addWidget(empty)
            return

        for project in projects:
            wrapper = QFrame()
            wrapper.setCursor(Qt.CursorShape.PointingHandCursor)
            wrapper.setStyleSheet(f"""
                QFrame {{
                    background-color: {Colors.BACKGROUND};
                    border-radius: 6px;
                }}
                QFrame:hover {{
                    background-color: {Colors.SURFACE_LIGHT};
                }}
            """)

            row = QHBoxLayout(wrapper)
            row.setContentsMargins(12, 8, 12, 8)

            label = QLabel(f"{project.name}  —  {project.status.value}")
            label.setStyleSheet(f"color: {Colors.TEXT_SECONDARY};")

            open_btn = QPushButton("Open")
            open_btn.setProperty("cssClass", "ghost")
            open_btn.setFixedWidth(60)
            open_btn.clicked.connect(
                lambda _, pid=project.id: self.controller.workspace.request_open_workspace(pid)
            )

            row.addWidget(label)
            row.addStretch()
            row.addWidget(open_btn)

            self._project_list_layout.addWidget(wrapper)
