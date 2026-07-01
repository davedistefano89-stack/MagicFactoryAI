"""Workspace header showing project metadata and stats."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)

from app.controllers.workspace_controller import WorkspaceController
from core.theme.colors import Colors
from models.project import ProjectStatus


class WorkspaceHeader(QFrame):
    """Displays project name, status, dates, asset counts, and the
    global Undo / Redo toolbar."""

    def __init__(self, workspace: WorkspaceController, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._workspace = workspace
        self._undo_btn: QPushButton | None = None
        self._redo_btn: QPushButton | None = None
        self._undo_label: QLabel | None = None
        self._redo_label: QLabel | None = None
        self._build_ui()
        self._connect_undo_signals()

    def _connect_undo_signals(self) -> None:
        # Only wire signals when an AppController instance is reachable,
        # otherwise this header still renders fine in isolation.
        controller = getattr(self._workspace, "_app", None)
        manager = getattr(controller, "undo_manager", None) if controller else None
        if manager is None:
            # Hide the toolbar if no manager is available (defensive).
            return
        manager.history_changed.connect(self._refresh_undo_controls)
        if self._undo_btn is not None:
            self._undo_btn.clicked.connect(manager.undo)
        if self._redo_btn is not None:
            self._redo_btn.clicked.connect(manager.redo)
        self._refresh_undo_controls()

    def _refresh_undo_controls(self) -> None:
        controller = getattr(self._workspace, "_app", None)
        manager = getattr(controller, "undo_manager", None) if controller else None
        if manager is None:
            return
        if self._undo_btn is not None:
            self._undo_btn.setEnabled(manager.can_undo)
        if self._redo_btn is not None:
            self._redo_btn.setEnabled(manager.can_redo)
        if self._undo_label is not None:
            self._undo_label.setText(
                manager.undo_label or "Nothing to undo"
            )
            self._undo_label.setStyleSheet(
                f"color: {Colors.TEXT_SECONDARY if manager.can_undo else Colors.TEXT_MUTED};"
                " font-size: 11px; border: none; background: transparent;"
            )
        if self._redo_label is not None:
            self._redo_label.setText(
                manager.redo_label or "Nothing to redo"
            )
            self._redo_label.setStyleSheet(
                f"color: {Colors.TEXT_SECONDARY if manager.can_redo else Colors.TEXT_MUTED};"
                " font-size: 11px; border: none; background: transparent;"
            )

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

        self._name_label = QLabel("Nessun progetto selezionato")
        self._name_label.setStyleSheet(
            f"font-size: 22px; font-weight: 700; color: {Colors.TEXT_PRIMARY};"
        )
        self._title_col.addWidget(self._name_label)

        self._desc_label = QLabel("Seleziona un progetto per aprire l'area di lavoro")
        self._desc_label.setStyleSheet(f"color: {Colors.TEXT_SECONDARY}; font-size: 13px;")
        self._title_col.addWidget(self._desc_label)

        layout.addLayout(self._title_col, stretch=2)
        layout.addStretch()

        self._meta_labels: dict[str, QLabel] = {}
        meta_items = [
            ("status", "Stato"),
            ("created", "Creato"),
            ("total", "Risorse totali"),
            ("approved", "Approvati"),
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

        # ── Sprint: Global Undo / Redo toolbar ────────────────────────────────
        try:
            self._build_undo_toolbar(layout)
        except Exception:
            pass

    def _build_undo_toolbar(self, parent_layout: QHBoxLayout) -> None:
        """Insert the ↶ / ↷ buttons + status labels into the header layout."""
        spacer = QFrame()
        spacer.setFixedWidth(1)
        spacer.setStyleSheet("background: transparent; border: none;")
        spacer.setFixedHeight(54)
        parent_layout.addWidget(spacer)

        col = QFrame()
        col.setStyleSheet(
            "background: transparent; border: none;"
        )
        col_v = QVBoxLayout(col)
        col_v.setContentsMargins(0, 0, 0, 0)
        col_v.setSpacing(4)

        row = QHBoxLayout()
        row.setSpacing(6)

        self._undo_btn = QPushButton("\u21B6  Annulla")
        self._undo_btn.setProperty("cssClass", "ghost")
        self._undo_btn.setFixedHeight(30)
        self._undo_btn.setToolTip("Annulla (Ctrl+Z)")
        font = QFont()
        font.setPointSize(11)
        self._undo_btn.setFont(font)
        self._undo_btn.setEnabled(False)

        self._redo_btn = QPushButton("\u21B7  Ripeti")
        self._redo_btn.setProperty("cssClass", "ghost")
        self._redo_btn.setFixedHeight(30)
        self._redo_btn.setToolTip("Ripeti (Ctrl+Shift+Z)")
        self._redo_btn.setFont(font)
        self._redo_btn.setEnabled(False)

        row.addWidget(self._undo_btn)
        row.addWidget(self._redo_btn)
        col_v.addLayout(row)

        self._undo_label = QLabel("Niente da annullare")
        self._undo_label.setAlignment(
            Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter
        )
        self._undo_label.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 11px; border: none;"
            " background: transparent;"
        )

        self._redo_label = QLabel("Niente da ripetere")
        self._redo_label.setAlignment(
            Qt.AlignmentFlag.AlignCenter | Qt.AlignmentFlag.AlignVCenter
        )
        self._redo_label.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 11px; border: none;"
            " background: transparent;"
        )

        label_row = QVBoxLayout()
        label_row.setContentsMargins(0, 0, 0, 0)
        label_row.setSpacing(0)
        label_row.addWidget(self._undo_label)
        label_row.addWidget(self._redo_label)
        col_v.addLayout(label_row)

        parent_layout.addWidget(col)

    def refresh(self) -> None:
        project = self._workspace.current_project
        if not project:
            self._name_label.setText("Nessun progetto selezionato")
            self._desc_label.setText("Seleziona un progetto per aprire l'area di lavoro")
            for lbl in self._meta_labels.values():
                lbl.setText("—")
            return

        stats = self._workspace.get_stats()
        self._name_label.setText(project.name)
        self._desc_label.setText(
            project.description or "Area di lavoro del progetto"
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
