"""Prompt template management screen."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QSplitter,
    QTableWidget,
    QTableWidgetItem,
    QTextEdit,
    QVBoxLayout,
)

from app.controllers.prompt_controller import PromptController
from core.theme.colors import Colors
from models.prompt import PromptType
from ui.screens.base_screen import BaseScreen
from ui.widgets.page_header import PageHeader


class PromptManagerScreen(BaseScreen):
    """Global prompt manager."""

    screen_id = "prompts"

    def _build_ui(self) -> None:

        self._prompt_ctrl = PromptController(self.controller)
        self._editing_id: int | None = None

        self._layout.addWidget(
            PageHeader(
                "Prompt Manager",
                "Create and manage reusable AI prompts.",
            )
        )

        splitter = QSplitter(Qt.Orientation.Horizontal)

        # ---------------- LEFT ----------------

        left = QFrame()
        left.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        left_layout = QVBoxLayout(left)
        left_layout.setContentsMargins(16,16,16,16)

        self._search = QLineEdit()
        self._search.setPlaceholderText("Search prompts...")
        self._search.textChanged.connect(self._on_search)

        left_layout.addWidget(self._search)

        self._table = QTableWidget()
        self._table.setColumnCount(3)
        self._table.setHorizontalHeaderLabels(
            [
                "Title",
                "Type",
                "★",
            ]
        )

        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.verticalHeader().setVisible(False)
        self._table.setSelectionBehavior(
            QTableWidget.SelectionBehavior.SelectRows
        )
        self._table.setEditTriggers(
            QTableWidget.EditTrigger.NoEditTriggers
        )
        self._table.itemSelectionChanged.connect(
            self._on_select
        )

        left_layout.addWidget(self._table)

        splitter.addWidget(left)
        # ---------------- RIGHT ----------------

        right = QFrame()
        right.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(24,20,24,20)

        form = QFormLayout()

        self._title = QLineEdit()
        form.addRow("Title", self._title)

        self._type = QComboBox()

        for pt in PromptType:
            self._type.addItem(
                pt.value.title(),
                pt,
            )

        form.addRow(
            "Type",
            self._type,
        )

        self._tags = QLineEdit()
        form.addRow(
            "Tags",
            self._tags,
        )

        self._content = QTextEdit()
        self._content.setMinimumHeight(180)
        form.addRow(
            "Content",
            self._content,
        )

        right_layout.addLayout(form)

        buttons = QHBoxLayout()

        save = QPushButton("Save Prompt")
        save.setProperty("cssClass","primary")
        save.clicked.connect(self._on_save)

        clear = QPushButton("Clear")
        clear.clicked.connect(self._clear)

        self._delete = QPushButton("Delete")
        self._delete.setProperty("cssClass","danger")
        self._delete.clicked.connect(self._on_delete)
        self._delete.setEnabled(False)

        buttons.addWidget(save)
        buttons.addWidget(clear)
        buttons.addStretch()
        buttons.addWidget(self._delete)

        right_layout.addLayout(buttons)

        splitter.addWidget(right)
        splitter.setSizes([380,520])

        self._layout.addWidget(splitter)

        self.refresh()

    def _load(self):
        return self._prompt_ctrl.get_all()

    def _on_search(self, text: str):

        if text.strip():
            prompts = self._prompt_ctrl.search(text.strip())
        else:
            prompts = self._load()

        self._populate(prompts)

    def _on_select(self):

        rows = self._table.selectionModel().selectedRows()

        if not rows:
            return

        prompt_id = self._table.item(
            rows[0].row(),
            0,
        ).data(Qt.ItemDataRole.UserRole)

        prompt = next(
            (
                p
                for p in self._load()
                if p.id == prompt_id
            ),
            None,
        )

        if prompt is None:
            return

        self._editing_id = prompt.id

        self._title.setText(prompt.title)
        self._content.setPlainText(prompt.content)
        self._tags.setText(prompt.tags)

        idx = self._type.findData(prompt.prompt_type)

        if idx >= 0:
            self._type.setCurrentIndex(idx)

        self._delete.setEnabled(True)

    
    def _on_save(self):

        title = self._title.text().strip()
        content = self._content.toPlainText().strip()

        if not title or not content:
            QMessageBox.warning(
                self,
                "Validation",
                "Title and Content are required.",
            )
            return

        if self._editing_id is None:

            self._prompt_ctrl.create_prompt(
                title=title,
                content=content,
                prompt_type=PromptType(self._type.currentData()),
                tags=self._tags.text().strip(),
            )

        else:

            prompt = next(
                (
                    p
                    for p in self._load()
                    if p.id == self._editing_id
                ),
                None,
            )

            if prompt:

                prompt.title = title
                prompt.content = content
                prompt.prompt_type = self._type.currentData()
                prompt.tags = self._tags.text().strip()

                self._prompt_ctrl.update_prompt(prompt)

        self._clear()
        self.refresh()

    def _on_delete(self):

        if self._editing_id is None:
            return

        if QMessageBox.question(
            self,
            "Delete Prompt",
            "Delete selected prompt?",
        ) == QMessageBox.StandardButton.Yes:

            self._prompt_ctrl.delete_prompt(
                self._editing_id
            )

            self._clear()
            self.refresh()

    def _clear(self):

        self._editing_id = None

        self._title.clear()
        self._tags.clear()
        self._content.clear()

        self._type.setCurrentIndex(0)

        self._delete.setEnabled(False)

        self._table.clearSelection()

    def _populate(self, prompts):

        self._table.setRowCount(len(prompts))

        for row, prompt in enumerate(prompts):

            title = QTableWidgetItem(prompt.title)
            title.setData(
                Qt.ItemDataRole.UserRole,
                prompt.id,
            )

            self._table.setItem(
                row,
                0,
                title,
            )

            self._table.setItem(
                row,
                1,
                QTableWidgetItem(
                    prompt.prompt_type.value.title()
                ),
            )

            self._table.setItem(
                row,
                2,
                QTableWidgetItem(
                    "★" if prompt.is_favorite else ""
                ),
            )

        self._table.resizeColumnsToContents()

    def refresh(self) -> None:

        self._search.blockSignals(True)
        self._search.clear()
        self._search.blockSignals(False)

        self._populate(
            self._load()
        )