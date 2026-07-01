"""Custom-painted chart widgets for the Dashboard PRO #3 section.

Each widget paints itself inside ``paintEvent`` using :class:`QPainter`
directly, so the dashboard ships without any 3rd‑party chart dependency.
Importers in ``ui/screens/project_dashboard_screen.py`` only call
``set_data(...)`` / ``set_value(...)`` — the widgets repaint themselves.

Sprint: Dashboard PRO #3 — production analytics.
"""

from __future__ import annotations

from typing import Iterable, List, Optional, Tuple

from PySide6.QtCore import (
    Property,
    QEasingCurve,
    QPointF,
    QPropertyAnimation,
    QRect,
    QRectF,
    QSize,
    Qt,
    Signal,
)
from PySide6.QtGui import QColor, QFont, QPainter, QPainterPath
from PySide6.QtWidgets import (
    QButtonGroup,
    QFrame,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QSizePolicy,
    QVBoxLayout,
    QWidget,
)

from app.controllers.project_dashboard_controller import TimeFilter
from core.theme.colors import Colors


# ── Bar chart ────────────────────────────────────────────────────────────


class BarChart(QWidget):
    """Compact horizontal bar chart with grid lines and per-bar labels.

    The widget accepts three iterables of equal length via
    :meth:`set_data` — ``labels`` for the x‑axis, ``values`` for the
    bar heights and ``colors`` for per-bar fill colours. Missing or
    empty ``values`` are rendered as a 2px ghost bar so the visual
    scale stays consistent across refreshes.
    """

    def __init__(
        self,
        title: str,
        accent: str,
        parent: Optional[QWidget] = None,
    ) -> None:
        super().__init__(parent)
        self._title = title
        self._accent = accent
        self._labels: List[str] = []
        self._values: List[int] = []
        self._colors: List[str] = []
        self.setMinimumHeight(160)
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )

    # ── Public API ──

    def set_data(
        self,
        labels: Iterable[str],
        values: Iterable[int],
        colors: Optional[Iterable[str]] = None,
    ) -> None:
        self._labels = [str(x) for x in labels]
        self._values = [int(x) for x in values]
        if colors is None:
            self._colors = [self._accent] * len(self._values)
        else:
            self._colors = [
                c if c else self._accent for c in colors
            ]
        self.update()

    def sizeHint(self) -> QSize:  # type: ignore[override]
        return QSize(640, 180)

    # ── Painting ──

    def paintEvent(self, event) -> None:  # type: ignore[override]
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        rect = self.rect()
        if rect.width() <= 0 or rect.height() <= 0:
            return

        # Title bar.
        title_font = QFont(painter.font())
        title_font.setPointSize(10)
        title_font.setBold(True)
        painter.setFont(title_font)
        painter.setPen(QColor(Colors.TEXT_SECONDARY))
        title_rect = QRect(0, 4, rect.width(), 22)
        painter.drawText(
            title_rect,
            int(Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft),
            self._title,
        )

        # Plot region.
        plot_top = 32
        plot_bottom = rect.height() - 28
        plot_left = 36
        plot_right = rect.width() - 14
        plot_width = max(plot_right - plot_left, 1)
        plot_height = max(plot_bottom - plot_top, 1)

        if not self._values:
            painter.setPen(QColor(Colors.TEXT_MUTED))
            empty_rect = QRectF(0, plot_top, rect.width(), plot_height)
            painter.drawText(
                empty_rect,
                int(Qt.AlignmentFlag.AlignCenter),
                "No data yet",
            )
            return

        max_val = max(self._values) or 1

        # Horizontal grid lines + max/half/min value labels.
        grid_font = QFont(painter.font())
        grid_font.setPointSize(8)
        grid_font.setBold(False)
        painter.setFont(grid_font)
        grid_steps = 4
        for i in range(grid_steps + 1):
            y = plot_top + plot_height * i / grid_steps
            painter.setPen(QColor(Colors.BORDER))
            painter.drawLine(plot_left, int(y), plot_right, int(y))
            label_val = int(round(max_val * (grid_steps - i) / grid_steps))
            label_box = QRectF(0, int(y) - 6, plot_left - 6, 12)
            painter.setPen(QColor(Colors.TEXT_MUTED))
            painter.drawText(
                label_box,
                int(
                    Qt.AlignmentFlag.AlignRight
                    | Qt.AlignmentFlag.AlignVCenter
                ),
                str(label_val),
            )

        # Bars.
        n = len(self._values)
        slot_w = plot_width / max(n, 1)
        gap = max(slot_w * 0.18, 4.0)
        bar_w = max(slot_w - gap, 4.0)

        label_font = QFont(painter.font())
        label_font.setPointSize(9)
        label_font.setBold(True)
        painter.setFont(label_font)

        for idx, val in enumerate(self._values):
            x = plot_left + idx * slot_w + gap / 2
            ratio = val / max_val if max_val > 0 else 0
            h = max(int(plot_height * ratio), 2)
            y = plot_bottom - h
            # Bar with rounded top, flat bottom.
            path = QPainterPath()
            path.addRoundedRect(QRectF(x, y, bar_w, h), 4.0, 4.0)
            painter.setPen(_NO_PEN)
            painter.setBrush(QColor(self._colors[idx]))
            painter.drawPath(path)

            # Value above bar (only for non-zero).
            if val > 0:
                painter.setPen(QColor(Colors.TEXT_PRIMARY))
                value_box = QRectF(x - 6, y - 20, bar_w + 12, 16)
                painter.drawText(
                    value_box,
                    int(
                        Qt.AlignmentFlag.AlignHCenter
                        | Qt.AlignmentFlag.AlignBottom
                    ),
                    str(val),
                )
            # X‑axis label below bar.
            painter.setPen(QColor(Colors.TEXT_MUTED))
            axis_box = QRectF(x - 6, plot_bottom + 4, bar_w + 12, 20)
            painter.drawText(
                axis_box,
                int(
                    Qt.AlignmentFlag.AlignHCenter
                    | Qt.AlignmentFlag.AlignTop
                ),
                self._labels[idx],
            )


_NO_PEN = Qt.PenStyle.NoPen


# ── Donut chart ──────────────────────────────────────────────────────────


class DonutChart(QWidget):
    """Donut chart with an inline legend on the right.

    Each slice is ``(label, value, color_hex)``. Empty slices
    (``value <= 0``) are skipped, so the donut handles zero‑state
    projects without breaking.
    """

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self._slices: List[Tuple[str, int, str]] = []
        self.setMinimumHeight(220)
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )

    def set_slices(
        self,
        slices: Iterable[Tuple[str, int, str]],
    ) -> None:
        self._slices = list(slices)
        self.update()

    def sizeHint(self) -> QSize:  # type: ignore[override]
        return QSize(420, 220)

    def paintEvent(self, event) -> None:  # type: ignore[override]
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        rect = self.rect()
        if rect.width() <= 0 or rect.height() <= 0:
            return

        # Donut on the left.
        donut_size = min(rect.height() - 12, 200, rect.width() // 2 - 6)
        donut_rect = QRectF(
            8.0,
            (rect.height() - donut_size) / 2,
            donut_size,
            donut_size,
        )

        total = sum(v for _, v, _ in self._slices) or 1
        start_angle = 90.0  # -90 ⇒ start at 12 o'clock

        # Background ring (subtle base for empty areas).
        painter.setPen(_NO_PEN)
        painter.setBrush(QColor(Colors.SURFACE))
        painter.drawEllipse(donut_rect)

        # Slice pyramids.
        cursor = start_angle
        for label, value, color_hex in self._slices:
            if value <= 0:
                continue
            span = 360.0 * value / total
            color = QColor(color_hex)
            painter.setBrush(color)
            painter.setPen(color.darker(120))
            painter.drawPie(
                donut_rect,
                int((-cursor) * 16),
                int(span * 16),
            )
            cursor -= span

        # Donut hole in the centre to convert the pie into a donut.
        hole_d = donut_size * 0.58
        hole_rect = QRectF(
            donut_rect.center().x() - hole_d / 2,
            donut_rect.center().y() - hole_d / 2,
            hole_d,
            hole_d,
        )
        painter.setBrush(QColor(Colors.BACKGROUND))
        painter.setPen(_NO_PEN)
        painter.drawEllipse(hole_rect)

        # Total in the centre.
        centre_font = QFont(painter.font())
        centre_font.setPointSize(13)
        centre_font.setBold(True)
        painter.setFont(centre_font)
        painter.setPen(QColor(Colors.TEXT_PRIMARY))
        painter.drawText(
            hole_rect,
            int(Qt.AlignmentFlag.AlignCenter),
            str(total),
        )

        # Legend on the right.
        legend_left = donut_rect.right() + 28
        if legend_left < rect.right() - 80:
            row_h = 22
            legend_top = (rect.height() - len(self._slices) * row_h) / 2
            name_font = QFont(painter.font())
            name_font.setPointSize(10)
            name_font.setBold(False)
            for label, value, color_hex in self._slices:
                dot_rect = QRectF(legend_left, legend_top + 5, 10, 10)
                painter.setBrush(QColor(color_hex))
                painter.setPen(_NO_PEN)
                painter.drawEllipse(dot_rect)

                painter.setFont(name_font)
                painter.setPen(QColor(Colors.TEXT_PRIMARY))
                painter.drawText(
                    QRectF(legend_left + 18, legend_top, 110, row_h),
                    int(
                        Qt.AlignmentFlag.AlignVCenter
                        | Qt.AlignmentFlag.AlignLeft
                    ),
                    label.capitalize(),
                )

                pct = int(round(100.0 * value / total)) if total else 0
                pct_font = QFont(painter.font())
                pct_font.setBold(True)
                painter.setFont(pct_font)
                painter.setPen(QColor(Colors.TEXT_SECONDARY))
                painter.drawText(
                    QRectF(legend_left + 18, legend_top, rect.right() - (legend_left + 18) - 6, row_h),
                    int(
                        Qt.AlignmentFlag.AlignVCenter
                        | Qt.AlignmentFlag.AlignRight
                    ),
                    f"{value} · {pct}%",
                )
                legend_top += row_h


# ── Sparkline ────────────────────────────────────────────────────────────


class Sparkline(QWidget):
    """Tiny line chart with a gradient fill below the line.

    Designed to be embedded in a KPI tile — its preferred size is
    100×35px but it stretches to whatever the layout assigns.
    """

    def __init__(self, accent: str, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self._accent = accent
        self._values: List[int] = []
        self.setMinimumHeight(28)
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )

    def set_values(self, values: Iterable[int]) -> None:
        self._values = [int(v) for v in values]
        self.update()

    def sizeHint(self) -> QSize:  # type: ignore[override]
        return QSize(120, 36)

    def paintEvent(self, event) -> None:  # type: ignore[override]
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        rect = self.rect()
        if len(self._values) < 2:
            # Placeholder dot.
            painter.setPen(_NO_PEN)
            painter.setBrush(QColor(self._accent))
            cx, cy = rect.center().x(), rect.center().y()
            painter.drawEllipse(QPointF(cx, cy), 2.0, 2.0)
            return

        pad_x = 4.0
        pad_y = 6.0
        plot_w = max(rect.width() - pad_x * 2, 1.0)
        plot_h = max(rect.height() - pad_y * 2, 1.0)
        max_v = max(self._values) or 1
        n = len(self._values)

        points: List[QPointF] = []
        for i, val in enumerate(self._values):
            x = pad_x + plot_w * i / (n - 1)
            y = pad_y + plot_h * (1 - val / max_v)
            points.append(QPointF(x, y))

        # Gradient fill below the line.
        fill_path = QPainterPath()
        fill_path.moveTo(points[0].x(), rect.height() - pad_y)
        for pt in points:
            fill_path.lineTo(pt)
        fill_path.lineTo(points[-1].x(), rect.height() - pad_y)
        fill_path.closeSubpath()

        from PySide6.QtGui import QLinearGradient

        gradient = QLinearGradient(
            0, pad_y, 0, rect.height() - pad_y
        )
        accent_color = QColor(self._accent)
        top = QColor(accent_color)
        top.setAlpha(110)
        bottom = QColor(accent_color)
        bottom.setAlpha(0)
        gradient.setColorAt(0.0, top)
        gradient.setColorAt(1.0, bottom)
        painter.setPen(_NO_PEN)
        painter.setBrush(gradient)
        painter.drawPath(fill_path)

        # Line on top.
        line_color = QColor(self._accent)
        line_color.setAlpha(230)
        from PySide6.QtGui import QPen

        pen = QPen(line_color)
        pen.setWidthF(2.0)
        pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
        pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        painter.setPen(pen)
        painter.setBrush(_NO_PEN)
        painter.drawPolyline(points)

        # Highlight last point.
        last = points[-1]
        painter.setPen(_NO_PEN)
        painter.setBrush(QColor(self._accent))
        painter.drawEllipse(last, 3.0, 3.0)


# ── Animated KPI tile ─────────────────────────────────────────────────────


class _Counter(QWidget):
    """Small QWidget with a Property(int) we can animate.

    Used as the value backing-store for :class:`AnimatedKpiTile`. The
    :class:`QPropertyAnimation` calls on ``value`` and the tile calls
    :meth:`display` whenever the property changes.
    """

    valueChanged = Signal(int)

    def __init__(self, parent: Optional[QWidget] = None) -> None:
        super().__init__(parent)
        self._v = 0

    def get_value(self) -> int:
        return self._v

    def set_value(self, v: int) -> None:
        if v != self._v:
            self._v = v
            self.valueChanged.emit(v)

    value = Property(int, get_value, set_value, notify=valueChanged)


class AnimatedKpiTile(QFrame):
    """Premium KPI tile with smooth count‑up + sparkline + delta badge.

    Visual:
        ┌──────────────────────────────┐
        │ ●  GENERATED                  │
        │ 42   ↗ +14.3%   ─╱╲──╱─       │
        │ vs prev period                │
        └──────────────────────────────┘
    """

    def __init__(
        self,
        key: str,
        label: str,
        accent: str,
        parent: Optional[QWidget] = None,
    ) -> None:
        super().__init__(parent)
        self._key = key
        self._label = label
        self._accent = accent
        self._delta_pct: float = 0.0
        self._trend: str = "flat"
        self._display_value: int = 0

        self.setObjectName("AnimatedKpiTile")
        self.setStyleSheet(self._base_css())
        self.setMinimumHeight(120)
        self.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )

        # Top accent stripe via inline border-top only.
        # Let Qt draw a 3-px stripe via border? Simpler: paint a coloured
        # bar at the top of paintEvent via composition. For now we just
        # border-top: 3px solid in the QSS.
        self.setStyleSheet(self._base_css())

        outer = QVBoxLayout(self)
        outer.setContentsMargins(18, 14, 18, 14)
        outer.setSpacing(6)

        # Header row.
        header = QHBoxLayout()
        header.setSpacing(8)
        dot = QFrame()
        dot.setFixedSize(8, 8)
        dot.setStyleSheet(
            f"background-color: {accent}; border-radius: 4px; border: none;"
        )
        header.addWidget(dot)
        label_lbl = QLabel(label.upper())
        label_lbl.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 10px; font-weight: 800;"
            " letter-spacing: 1.4px; background: transparent; border: none;"
        )
        header.addWidget(label_lbl)
        header.addStretch(1)
        outer.addLayout(header)

        # Big value + trend chip in a row so the count animates next to
        # its delta percentage.
        value_row = QHBoxLayout()
        value_row.setSpacing(10)
        value_row.setAlignment(Qt.AlignmentFlag.AlignVCenter)

        self._value_lbl = QLabel("0")
        self._value_lbl.setStyleSheet(
            f"color: {Colors.TEXT_PRIMARY}; font-size: 32px; font-weight: 800;"
            " background: transparent; border: none;"
        )
        value_row.addWidget(self._value_lbl)
        self._value_lbl.setMinimumWidth(54)

        self._delta_chip = QLabel("—")
        self._delta_chip.setStyleSheet(
            f"color: {Colors.TEXT_SECONDARY}; font-size: 12px; font-weight: 700;"
            " padding: 4px 8px; border-radius: 10px; background: transparent;"
            " border: none;"
        )
        value_row.addWidget(self._delta_chip)
        value_row.addStretch(1)
        outer.addLayout(value_row)

        # Sparkline + caption.
        bottom = QHBoxLayout()
        bottom.setSpacing(8)
        self._sparkline = Sparkline(accent)
        bottom.addWidget(self._sparkline, stretch=1)
        bottom.addStretch(0)
        outer.addLayout(bottom)

        # Hidden caption "vs prev period".
        caption = QLabel("vs prev period")
        caption.setStyleSheet(
            f"color: {Colors.TEXT_MUTED}; font-size: 10px;"
            " background: transparent; border: none;"
        )
        outer.addWidget(caption)

        # Counter and animation machinery.
        self._counter = _Counter(self)
        self._counter.valueChanged.connect(self._on_counter_changed)
        self._anim = QPropertyAnimation(self._counter, b"value")
        self._anim.setDuration(550)
        self._anim.setEasingCurve(QEasingCurve.Type.OutCubic)

    # ── Public API ──

    def set_value(
        self,
        value: int,
        delta_pct: float,
        trend: str,
        sparkline: List[int],
    ) -> None:
        self._delta_pct = float(delta_pct)
        self._trend = trend
        # Refresh delta chip + sparkline immediately.
        self._refresh_delta_chip()
        self._sparkline.set_values(sparkline or [0])
        # Animate the big number from the previous display to the new.
        self._anim.stop()
        self._anim.setStartValue(self._counter.get_value())
        self._anim.setEndValue(int(value))
        self._anim.start()

    @property
    def key(self) -> str:
        return self._key

    # ── Internals ──

    def _on_counter_changed(self, v: int) -> None:
        self._display_value = v
        self._value_lbl.setText(str(v))

    def _refresh_delta_chip(self) -> None:
        if self._delta_pct == 0:
            arrow = "→"
            color = Colors.TEXT_MUTED
        elif self._delta_pct > 0:
            arrow = "↗"
            color = self._accent
        else:
            arrow = "↘"
            color = Colors.ERROR
        text = f"{arrow} {self._delta_pct:+.1f}%"
        self._delta_chip.setText(text)
        self._delta_chip.setStyleSheet(
            f"color: {color}; font-size: 12px; font-weight: 800;"
            f" padding: 4px 9px; border-radius: 10px;"
            f" background-color: rgba(255,255,255,0.04);"
            " border: none;"
        )

    def _base_css(self) -> str:
        return f"""
        QFrame#AnimatedKpiTile {{
            background-color: {Colors.SURFACE};
            border: 1px solid {Colors.BORDER};
            border-top: 3px solid {self._accent};
            border-radius: 14px;
        }}
        QFrame#AnimatedKpiTile:hover {{
            border: 1px solid {self._accent};
            background-color: {Colors.SURFACE_LIGHT};
        }}
        """


# ── Time filter bar ──────────────────────────────────────────────────────


class TimeFilterBar(QFrame):
    """Segmented control with one option per :class:`TimeFilter`.

    Emits :pyattr:`filter_changed` whenever a different segment is
    selected. The current selection is reflected both via the button's
    ``checked`` state and via a coloured bottom border on the active
    segment (visual sweet-spot per the thinker's recommendation).
    """

    filter_changed = Signal(object)  # emits TimeFilter

    _OPTIONS: List[Tuple[str, TimeFilter]] = [
        ("Today", TimeFilter.TODAY),
        ("Week", TimeFilter.WEEK),
        ("Month", TimeFilter.MONTH),
        ("All Time", TimeFilter.ALL),
    ]

    def __init__(
        self,
        initial: TimeFilter = TimeFilter.WEEK,
        accent: str = Colors.PRIMARY,
        parent: Optional[QWidget] = None,
    ) -> None:
        super().__init__(parent)
        self._accent = accent
        self.setObjectName("TimeFilterBar")

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(4)

        # The button row.
        body = QFrame()
        body.setStyleSheet(
            f"background-color: {Colors.SURFACE}; border: 1px solid {Colors.BORDER};"
            " border-radius: 12px;"
        )
        row = QHBoxLayout(body)
        row.setContentsMargins(6, 6, 6, 6)
        row.setSpacing(2)

        self._group = QButtonGroup(self)
        self._group.setExclusive(True)
        self._buttons: dict = {}

        for idx, (text, tf) in enumerate(self._OPTIONS):
            btn = QPushButton(text)
            btn.setCheckable(True)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.setMinimumHeight(30)
            btn.setStyleSheet(self._button_css())
            btn.toggled.connect(
                lambda checked, tf=tf, btn=btn: self._on_toggle(tf, btn, checked)
            )
            self._group.addButton(btn, idx)
            self._buttons[tf] = btn
            row.addWidget(btn)
        outer.addWidget(body)

        # Active-segment underline (drawn by paintEvent using a small
        # accent rectangle aligned to the active button).
        underline_holder = QFrame()
        underline_holder.setFixedHeight(3)
        underline_holder.setStyleSheet("background: transparent; border: none;")
        u_row = QHBoxLayout(underline_holder)
        u_row.setContentsMargins(6, 0, 6, 0)
        u_row.setSpacing(2)
        self._underline_bars: dict = {}
        for idx, (_, tf) in enumerate(self._OPTIONS):
            bar = QFrame()
            bar.setFixedHeight(3)
            bar.setStyleSheet("background: transparent; border: none;")
            u_row.addWidget(bar)
            self._underline_bars[tf] = bar
        outer.addWidget(underline_holder)

        # Default highlight.
        self.set_filter(initial, emit=False)

    # ── Public API ──

    def set_filter(
        self,
        tf: TimeFilter,
        emit: bool = True,
    ) -> None:
        btn = self._buttons.get(tf)
        if btn is None:
            return
        if btn.isChecked():
            # Already selected — repaint underline for safety.
            self._refresh_underline(tf)
            return
        btn.setChecked(True)
        if emit:
            self.filter_changed.emit(tf)

    def current_filter(self) -> TimeFilter:
        checked = self._group.checkedButton()
        if checked is None:
            return TimeFilter.WEEK
        for tf, btn in self._buttons.items():
            if btn is checked:
                return tf
        return TimeFilter.WEEK

    # ── Internals ──

    def _on_toggle(
        self, tf: TimeFilter, btn: QPushButton, checked: bool
    ) -> None:
        if not checked:
            return
        self._refresh_underline(tf)
        self.filter_changed.emit(tf)

    def _refresh_underline(self, tf: TimeFilter) -> None:
        for key, bar in self._underline_bars.items():
            if key == tf:
                bar.setStyleSheet(
                    f"background-color: {self._accent}; border: none;"
                    " border-top-left-radius: 2px; border-top-right-radius: 2px;"
                )
            else:
                bar.setStyleSheet("background: transparent; border: none;")

    def _button_css(self) -> str:
        return f"""
        QPushButton {{
            background-color: transparent;
            border: none;
            color: {Colors.TEXT_SECONDARY};
            padding: 6px 16px;
            border-radius: 10px;
            font-size: 12px;
            font-weight: 700;
            letter-spacing: 0.4px;
        }}
        QPushButton:hover {{
            background-color: {Colors.SURFACE_LIGHT};
            color: {Colors.TEXT_PRIMARY};
        }}
        QPushButton:checked {{
            background-color: {Colors.PRIMARY};
            color: {Colors.TEXT_ON_PRIMARY};
        }}
        QPushButton:checked:hover {{
            background-color: {Colors.PRIMARY_LIGHT};
        }}
        """
