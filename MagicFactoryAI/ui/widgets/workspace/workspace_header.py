"""Workspace header showing project metadata and stats."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QVBoxLayout, QWidget

from app.controllers.workspace_controller import WorkspaceController
from core.theme.colors import Colors
from models.project import ProjectStatus


class WorkspaceHeader(QFrame):
    """Displays project name, status, dates, and asset counts."""

    def __init__(self, workspace: WorkspaceController, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._workspace = workspace
        self._build_ui()

    def _build_ui(self) -> None:
        self.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(24, 16, 24, 16)
        layout.setSpacing(24)

        self._title_col = QVBoxLayout()
        self._title_col.setSpacing(4)

        self._name_label = QLabel("No Project Selected")
        self._name_label.setStyleSheet(
            f"font-size: 22px; font-weight: 700; color: {Colors.TEXT_PRIMARY};"
        )
        self._title_col.addWidget(self._name_label)

        self._desc_label = QLabel("Select a project to open the workspace")
        self._desc_label.setStyleSheet(f"color: {Colors.TEXT_SECONDARY}; font-size: 13px;")
        self._title_col.addWidget(self._desc_label)

        layout.addLayout(self._title_col, stretch=2)
        layout.addStretch()

        self._meta_labels: dict[str, QLabel] = {}
        meta_items = [
            ("status", "Status"),
            ("created", "Created"),
            ("total", "Total Assets"),
            ("approved", "Approved"),
        ]

        for key, title in meta_items:
            col = QVBoxLayout()
            col.setSpacing(2)

            title_lbl = QLabel(title)
            title_lbl.setStyleSheet(
                f"color: {Colors.TEXT_MUTED}; font-size: 11px; font-weight: 600;"
            )
            title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)

            value_lbl = QLabel("—")
            value_lbl.setStyleSheet(
                f"color: {Colors.TEXT_PRIMARY}; font-size: 15px; font-weight: 600;"
            )
            value_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)

            col.addWidget(title_lbl)
            col.addWidget(value_lbl)
            layout.addLayout(col)
            self._meta_labels[key] = value_lbl

    def refresh(self) -> None:
        project = self._workspace.current_project
        if not project:
            self._name_label.setText("No Project Selected")
            self._desc_label.setText("Select a project to open the workspace")
            for lbl in self._meta_labels.values():
                lbl.setText("—")
            return

        stats = self._workspace.get_stats()
        self._name_label.setText(project.name)
        self._desc_label.setText(
            project.description or "Project workspace"
        )

        status_colors = {
            ProjectStatus.DRAFT: Colors.TEXT_MUTED,
            ProjectStatus.ACTIVE: Colors.SUCCESS,
            ProjectStatus.ARCHIVED: Colors.WARNING,
        }
        status_color = status_colors.get(project.status, Colors.TEXT_SECONDARY)
        self._meta_labels["status"].setText(project.status.value.upper())
        self._meta_labels["status"].setStyleSheet(
            f"color: {status_color}; font-size: 13px; font-weight: 700;"
        )

        created = project.created_at.strftime("%b %d, %Y")
        self._meta_labels["created"].setText(created)
        self._meta_labels["total"].setText(str(stats.total_assets))
        self._meta_labels["approved"].setText(str(stats.approved_assets))
