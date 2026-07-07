"""
Professional toolbar for the Library module.

MagicFactoryAI
"""

from __future__ import annotations

from typing import Iterable

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QComboBox,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QSizePolicy,
    QSpacerItem,
    QWidget,
)


class LibraryToolbar(QFrame):
    """
    Professional toolbar used by LibraryTab.

    Emits signals only.
    Does not know anything about assets or controllers.
    """

    # --------------------------------------------------
    # Signals
    # --------------------------------------------------

    searchChanged = Signal(str)

    statusChanged = Signal(str)

    categoryChanged = Signal(str)

    tagChanged = Signal(str)

    importClicked = Signal()

    refreshClicked = Signal()

    gridViewClicked = Signal()

    listViewClicked = Signal()

    duplicateFinderClicked = Signal()

    similarFinderClicked = Signal()

    exportClicked = Signal()

    datasetClicked = Signal()

    # --------------------------------------------------

    STATUS_VALUES = [
        "All",
        "Pending",
        "Generated",
        "Approved",
        "Rejected",
        "Exported",
    ]

    # --------------------------------------------------

    def __init__(self, parent=None):

        super().__init__(parent)

        self.setObjectName("LibraryToolbar")

        self.setFrameShape(QFrame.NoFrame)

        self.setMinimumHeight(56)

        self.setMaximumHeight(56)

        self._build_ui()

        self._connect_signals()

    # --------------------------------------------------

    def _build_ui(self):

        layout = QHBoxLayout(self)

        layout.setContentsMargins(12, 8, 12, 8)

        layout.setSpacing(8)

        #
        # Search
        #

        self.search_edit = QLineEdit()

        self.search_edit.setPlaceholderText(
            "Search assets, prompt, tags..."
        )

        self.search_edit.setClearButtonEnabled(True)

        self.search_edit.setMinimumWidth(280)

        layout.addWidget(self.search_edit)

        #
        # Status
        #

        layout.addWidget(QLabel("Status"))

        self.status_combo = QComboBox()

        self.status_combo.addItems(self.STATUS_VALUES)

        self.status_combo.setMinimumWidth(140)

        layout.addWidget(self.status_combo)

        #
        # Category
        #

        layout.addWidget(QLabel("Category"))

        self.category_combo = QComboBox()

        self.category_combo.addItem("All Categories")

        self.category_combo.setMinimumWidth(170)

        layout.addWidget(self.category_combo)

        #
        # Tag
        #

        layout.addWidget(QLabel("Tag"))

        self.tag_combo = QComboBox()

        self.tag_combo.addItem("All Tags")

        self.tag_combo.setMinimumWidth(170)

        layout.addWidget(self.tag_combo)

        #
        # Spacer
        #

        layout.addItem(
            QSpacerItem(
                40,
                20,
                QSizePolicy.Expanding,
                QSizePolicy.Minimum,
            )
        )