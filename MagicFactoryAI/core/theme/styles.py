"""Global QSS stylesheet generation."""

from __future__ import annotations

from core.theme.colors import Colors


class ThemeManager:
    """Generates and applies the application-wide stylesheet."""

    @staticmethod
    def get_stylesheet() -> str:
        c = Colors
        return f"""
        /* ── Global ── */
        QWidget {{
            background-color: {c.BACKGROUND};
            color: {c.TEXT_PRIMARY};
            font-family: "Segoe UI", "Inter", sans-serif;
            font-size: 13px;
        }}

        QMainWindow {{
            background-color: {c.BACKGROUND};
        }}

        /* ── Scrollbars ── */
        QScrollBar:vertical {{
            background: {c.SURFACE};
            width: 8px;
            border-radius: 4px;
        }}
        QScrollBar::handle:vertical {{
            background: {c.SURFACE_LIGHT};
            border-radius: 4px;
            min-height: 30px;
        }}
        QScrollBar::handle:vertical:hover {{
            background: {c.SURFACE_HOVER};
        }}
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
            height: 0;
        }}
        QScrollBar:horizontal {{
            background: {c.SURFACE};
            height: 8px;
            border-radius: 4px;
        }}
        QScrollBar::handle:horizontal {{
            background: {c.SURFACE_LIGHT};
            border-radius: 4px;
            min-width: 30px;
        }}
        QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {{
            width: 0;
        }}

        /* ── Inputs ── */
        QLineEdit, QTextEdit, QPlainTextEdit, QSpinBox, QComboBox {{
            background-color: {c.SURFACE};
            border: 1px solid {c.BORDER};
            border-radius: 8px;
            padding: 8px 12px;
            color: {c.TEXT_PRIMARY};
            selection-background-color: {c.PRIMARY};
        }}
        QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus,
        QSpinBox:focus, QComboBox:focus {{
            border: 1px solid {c.PRIMARY};
        }}
        QLineEdit:hover, QTextEdit:hover, QPlainTextEdit:hover {{
            border: 1px solid {c.BORDER_LIGHT};
        }}

        QComboBox::drop-down {{
            border: none;
            width: 24px;
        }}
        QComboBox QAbstractItemView {{
            background-color: {c.SURFACE};
            border: 1px solid {c.BORDER};
            selection-background-color: {c.PRIMARY};
        }}

        /* ── Buttons ── */
        QPushButton {{
            background-color: {c.SURFACE_LIGHT};
            border: 1px solid {c.BORDER};
            border-radius: 8px;
            padding: 8px 16px;
            color: {c.TEXT_PRIMARY};
            font-weight: 500;
        }}
        QPushButton:hover {{
            background-color: {c.SURFACE_HOVER};
            border-color: {c.BORDER_LIGHT};
        }}
        QPushButton:pressed {{
            background-color: {c.SURFACE};
        }}
        QPushButton:disabled {{
            color: {c.TEXT_MUTED};
            background-color: {c.SURFACE};
        }}

        QPushButton[cssClass="primary"] {{
            background-color: {c.PRIMARY};
            border: none;
            color: {c.TEXT_ON_PRIMARY};
            font-weight: 600;
        }}
        QPushButton[cssClass="primary"]:hover {{
            background-color: {c.PRIMARY_LIGHT};
        }}
        QPushButton[cssClass="primary"]:pressed {{
            background-color: {c.PRIMARY_DARK};
        }}

        QPushButton[cssClass="secondary"] {{
            background-color: {c.SECONDARY};
            border: none;
            color: {c.TEXT_ON_PRIMARY};
            font-weight: 600;
        }}
        QPushButton[cssClass="secondary"]:hover {{
            background-color: {c.SECONDARY_LIGHT};
        }}

        QPushButton[cssClass="danger"] {{
            background-color: {c.ERROR};
            border: none;
            color: {c.TEXT_ON_PRIMARY};
        }}

        QPushButton[cssClass="ghost"] {{
            background-color: transparent;
            border: 1px solid {c.BORDER};
        }}
        QPushButton[cssClass="ghost"]:hover {{
            background-color: {c.SURFACE};
            border-color: {c.PRIMARY};
            color: {c.PRIMARY_LIGHT};
        }}

        /* ── Labels ── */
        QLabel[cssClass="title"] {{
            font-size: 24px;
            font-weight: 700;
            color: {c.TEXT_PRIMARY};
        }}
        QLabel[cssClass="subtitle"] {{
            font-size: 14px;
            color: {c.TEXT_SECONDARY};
        }}
        QLabel[cssClass="section-header"] {{
            font-size: 16px;
            font-weight: 600;
            color: {c.TEXT_PRIMARY};
        }}
        QLabel[cssClass="stat-value"] {{
            font-size: 28px;
            font-weight: 700;
        }}
        QLabel[cssClass="stat-label"] {{
            font-size: 12px;
            color: {c.TEXT_SECONDARY};
            font-weight: 500;
        }}

        /* ── Tables ── */
        QTableWidget, QTableView {{
            background-color: {c.SURFACE};
            border: 1px solid {c.BORDER};
            border-radius: 8px;
            gridline-color: {c.BORDER};
            selection-background-color: {c.PRIMARY};
            selection-color: {c.TEXT_ON_PRIMARY};
        }}
        QTableWidget::item, QTableView::item {{
            padding: 8px;
        }}
        QHeaderView::section {{
            background-color: {c.SURFACE_LIGHT};
            color: {c.TEXT_SECONDARY};
            border: none;
            border-bottom: 1px solid {c.BORDER};
            padding: 10px 8px;
            font-weight: 600;
            font-size: 12px;
        }}

        /* ── List Widget ── */
        QListWidget {{
            background-color: {c.SURFACE};
            border: 1px solid {c.BORDER};
            border-radius: 8px;
            outline: none;
        }}
        QListWidget::item {{
            padding: 10px 12px;
            border-bottom: 1px solid {c.BORDER};
        }}
        QListWidget::item:selected {{
            background-color: {c.PRIMARY};
            color: {c.TEXT_ON_PRIMARY};
        }}
        QListWidget::item:hover {{
            background-color: {c.SURFACE_LIGHT};
        }}

        /* ── Group Box ── */
        QGroupBox {{
            border: 1px solid {c.BORDER};
            border-radius: 8px;
            margin-top: 12px;
            padding-top: 16px;
            font-weight: 600;
        }}
        QGroupBox::title {{
            subcontrol-origin: margin;
            left: 12px;
            padding: 0 6px;
            color: {c.TEXT_SECONDARY};
        }}

        /* ── Tab Widget ── */
        QTabWidget::pane {{
            border: 1px solid {c.BORDER};
            border-radius: 8px;
            background: {c.SURFACE};
        }}
        QTabBar::tab {{
            background: {c.SURFACE};
            color: {c.TEXT_SECONDARY};
            padding: 8px 20px;
            border-top-left-radius: 8px;
            border-top-right-radius: 8px;
            margin-right: 2px;
        }}
        QTabBar::tab:selected {{
            background: {c.PRIMARY};
            color: {c.TEXT_ON_PRIMARY};
        }}
        QTabBar::tab:hover {{
            background: {c.SURFACE_LIGHT};
        }}

        /* ── Tooltips ── */
        QToolTip {{
            background-color: {c.SURFACE_LIGHT};
            color: {c.TEXT_PRIMARY};
            border: 1px solid {c.BORDER};
            border-radius: 4px;
            padding: 6px 10px;
        }}

        /* ── Splitter ── */
        QSplitter::handle {{
            background-color: {c.BORDER};
        }}

        /* ── Progress Bar ── */
        QProgressBar {{
            background-color: {c.SURFACE};
            border: none;
            border-radius: 4px;
            height: 8px;
            text-align: center;
        }}
        QProgressBar::chunk {{
            background-color: {c.PRIMARY};
            border-radius: 4px;
        }}

        /* ── Check Box ── */
        QCheckBox {{
            spacing: 8px;
        }}
        QCheckBox::indicator {{
            width: 18px;
            height: 18px;
            border-radius: 4px;
            border: 2px solid {c.BORDER_LIGHT};
            background: {c.SURFACE};
        }}
        QCheckBox::indicator:checked {{
            background: {c.PRIMARY};
            border-color: {c.PRIMARY};
        }}
        """

    @staticmethod
    def apply(app) -> None:
        app.setStyleSheet(ThemeManager.get_stylesheet())
