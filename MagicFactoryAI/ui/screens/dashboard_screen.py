"""Dashboard overview screen."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QFrame, QGridLayout, QHBoxLayout, QLabel, QPushButton, QVBoxLayout

from app.controllers.dashboard_controller import DashboardController
from core.theme.colors import Colors
from ui.screens.base_screen import BaseScreen
from ui.widgets.page_header import PageHeader
from ui.widgets.stat_card import StatCard


class DashboardScreen(BaseScreen):
    screen_id = "dashboard"

    def __init__(self, controller, parent=None) -> None:
        self._dash_ctrl = DashboardController(controller)
        self._stat_cards: dict[str, StatCard] = {}
        super().__init__(controller, parent)

    def _build_ui(self) -> None:
        self._layout.addWidget(PageHeader(
            title="Dashboard",
            subtitle="Overview of your coloring book asset pipeline",
        ))

        grid = QGridLayout()
        grid.setSpacing(16)

        cards = [
            ("projects", "Projects", "0", Colors.PRIMARY, "📂"),
            ("categories", "Categories", "0", Colors.CARD_PURPLE, "📁"),
            ("prompts", "Prompts", "0", Colors.SECONDARY, "💬"),
            ("assets", "Total Assets", "0", Colors.ACCENT, "🖼"),
            ("pending", "Pending Review", "0", Colors.WARNING, "⏳"),
            ("approved", "Approved", "0", Colors.SUCCESS, "✅"),
        ]

        for i, (key, label, value, color, icon) in enumerate(cards):
            card = StatCard(label, value, color, icon)
            self._stat_cards[key] = card
            grid.addWidget(card, i // 3, i % 3)

        self._layout.addLayout(grid)

        self._layout.addWidget(self._build_recent_projects())
        self._layout.addStretch()

    def _build_recent_projects(self) -> QFrame:
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
        layout.setSpacing(12)

        header = QLabel("Recent Projects")
        header.setStyleSheet(
            f"font-size: 16px; font-weight: 600; color: {Colors.TEXT_PRIMARY};"
        )
        layout.addWidget(header)

        self._recent_list = QVBoxLayout()
        self._recent_list.setSpacing(8)
        layout.addLayout(self._recent_list)

        return frame

    def refresh(self) -> None:
        stats = self._dash_ctrl.get_stats()
        self._stat_cards["projects"].set_value(str(stats.total_projects))
        self._stat_cards["categories"].set_value(str(stats.total_categories))
        self._stat_cards["prompts"].set_value(str(stats.total_prompts))
        self._stat_cards["assets"].set_value(str(stats.total_assets))
        self._stat_cards["pending"].set_value(str(stats.pending_assets))
        self._stat_cards["approved"].set_value(str(stats.approved_assets))

        while self._recent_list.count():
            item = self._recent_list.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        projects = self._dash_ctrl.get_recent_projects()
        if not projects:
            empty = QLabel("No projects yet. Create one from New Project.")
            empty.setStyleSheet(f"color: {Colors.TEXT_MUTED}; padding: 8px 0;")
            self._recent_list.addWidget(empty)
        else:
            for project in projects:
                wrapper = QFrame()
                wrapper.setCursor(Qt.CursorShape.PointingHandCursor)
                wrapper.setStyleSheet(f"""
                    QFrame {{
                        background-color: {Colors.BACKGROUND};
                        border-radius: 8px;
                        padding: 4px 12px;
                    }}
                    QFrame:hover {{
                        background-color: {Colors.SURFACE_LIGHT};
                    }}
                """)

                row = QHBoxLayout(wrapper)
                row.setContentsMargins(8, 6, 8, 6)

                name = QLabel(project.name)
                name.setStyleSheet(f"color: {Colors.TEXT_PRIMARY}; font-weight: 500;")
                status = QLabel(project.status.value.upper())
                status.setStyleSheet(f"""
                    color: {Colors.ACCENT};
                    background-color: {Colors.SURFACE_LIGHT};
                    padding: 2px 10px;
                    border-radius: 4px;
                    font-size: 11px;
                    font-weight: 600;
                """)
                status.setAlignment(Qt.AlignmentFlag.AlignRight)

                open_btn = QPushButton("Open")
                open_btn.setProperty("cssClass", "ghost")
                open_btn.setFixedWidth(60)
                open_btn.clicked.connect(
                    lambda _, pid=project.id: self.controller.workspace.request_open_workspace(pid)
                )

                row.addWidget(name)
                row.addStretch()
                row.addWidget(status)
                row.addWidget(open_btn)

                self._recent_list.addWidget(wrapper)
