"""Application color palette."""

from __future__ import annotations


class Colors:
    """Modern colorful palette for Magic Factory AI."""

    # Brand
    PRIMARY = "#6366F1"
    PRIMARY_LIGHT = "#818CF8"
    PRIMARY_DARK = "#4F46E5"

    SECONDARY = "#EC4899"
    SECONDARY_LIGHT = "#F472B6"
    SECONDARY_DARK = "#DB2777"

    ACCENT = "#14B8A6"
    ACCENT_LIGHT = "#2DD4BF"
    ACCENT_DARK = "#0D9488"

    WARNING = "#F59E0B"
    SUCCESS = "#10B981"
    ERROR = "#EF4444"
    INFO = "#3B82F6"

    # Surfaces
    BACKGROUND = "#0F172A"
    SURFACE = "#1E293B"
    SURFACE_LIGHT = "#334155"
    SURFACE_HOVER = "#475569"

    # Sidebar
    SIDEBAR_BG = "#1A1F35"
    SIDEBAR_ACTIVE = "#6366F1"
    SIDEBAR_HOVER = "#2A3050"

    # Text
    TEXT_PRIMARY = "#F8FAFC"
    TEXT_SECONDARY = "#94A3B8"
    TEXT_MUTED = "#64748B"
    TEXT_ON_PRIMARY = "#FFFFFF"

    # Borders
    BORDER = "#334155"
    BORDER_LIGHT = "#475569"

    # Card accent colors for dashboard stats
    CARD_PURPLE = "#8B5CF6"
    CARD_PINK = "#EC4899"
    CARD_TEAL = "#14B8A6"
    CARD_AMBER = "#F59E0B"
    CARD_BLUE = "#3B82F6"
    CARD_GREEN = "#10B981"

    @classmethod
    def category_palette(cls) -> list[str]:
        return [
            cls.PRIMARY,
            cls.SECONDARY,
            cls.ACCENT,
            cls.CARD_PURPLE,
            cls.CARD_PINK,
            cls.CARD_TEAL,
            cls.CARD_AMBER,
            cls.CARD_BLUE,
            cls.CARD_GREEN,
            cls.WARNING,
        ]
