"""Prompts tab within the project workspace."""

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
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase


class PromptsTab(WorkspaceTabBase):
    """Manage prompts inside the workspace."""

    def _build_ui(self) -> None:

        self._prompt_ctrl = PromptController(self.controller)
        self._editing_id = None

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
        left_layout.setContentsMargins(16, 16, 16, 16)

        self._search_input = QLineEdit()
        self._search_input.setPlaceholderText("Search prompts...")
        self._search_input.textChanged.connect(self._on_search)

        left_layout.addWidget(self._search_input)

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
        right_layout.setContentsMargins(24, 20, 24, 20)

        form = QFormLayout()

        self._title_input = QLineEdit()
        form.addRow("Title", self._title_input)

        self._type_combo = QComboBox()

        for pt in PromptType:
            self._type_combo.addItem(
                pt.value.title(),
                pt,
            )

        form.addRow(
            "Type",
            self._type_combo,
        )

        self._tags_input = QLineEdit()
        form.addRow(
            "Tags",
            self._tags_input,
        )

        self._character_input = QLineEdit()
        self._character_input.setPlaceholderText("Character")
        self._character_input.textChanged.connect(self._update_prompt_preview)
        form.addRow("Character", self._character_input)

        self._style_input = QLineEdit()
        self._style_input.setPlaceholderText("Style")
        self._style_input.textChanged.connect(self._update_prompt_preview)
        form.addRow("Style", self._style_input)

        self._background_input = QLineEdit()
        self._background_input.setPlaceholderText("Background")
        self._background_input.textChanged.connect(self._update_prompt_preview)
        form.addRow("Background", self._background_input)

        self._prompt_preview = QTextEdit()
        self._prompt_preview.setReadOnly(True)
        self._prompt_preview.setMaximumHeight(100)
        form.addRow("Final Prompt Preview", self._prompt_preview)

        self._content_input = QTextEdit()
        self._content_input.setMinimumHeight(160)

        form.addRow(
            "Content",
            self._content_input,
        )

        right_layout.addLayout(form)

        buttons = QHBoxLayout()

        save = QPushButton("Save Prompt")
        save.clicked.connect(self._on_save)

        clear = QPushButton("Clear")
        clear.clicked.connect(self._clear_form)

        self._delete_btn = QPushButton("Delete")
        self._delete_btn.clicked.connect(self._on_delete)
        self._delete_btn.setEnabled(False)

        buttons.addWidget(save)
        buttons.addWidget(clear)
        buttons.addStretch()
        buttons.addWidget(self._delete_btn)

        right_layout.addLayout(buttons)

        splitter.addWidget(right)
        splitter.setSizes([380, 520])

        self._layout.addWidget(splitter)

    def _build_prompt_preview(self) -> str:
        parts = []

        character = self._character_input.text().strip()
        style = self._style_input.text().strip()
        background = self._background_input.text().strip()

        if character:
            parts.append(f"Character: {character}")
        if style:
            parts.append(f"Style: {style}")
        if background:
            parts.append(f"Background: {background}")

        return "\n".join(parts)

    def _update_prompt_preview(self) -> None:
        self._prompt_preview.setPlainText(
            self._build_prompt_preview()
        )

    def _load_prompts(self):

        if self.workspace.category_id is not None:
            return self._prompt_ctrl.get_all(
              
               category_id=self.workspace.category_id
            )

        return self._prompt_ctrl.get_all()


    def _on_search(self, text: str):

        if text.strip():
            prompts = self._prompt_ctrl.search(
                text.strip()
            )
        else:
            prompts = self._load_prompts()

        self._populate_table(prompts)


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
                for p in self._load_prompts()
                if p.id == prompt_id
            ),
            None,
        )

        if prompt is None:
            return

        self._editing_id = prompt.id

        self._title_input.setText(prompt.title)
        self._content_input.setPlainText(prompt.content)
        self._tags_input.setText(prompt.tags)

        idx = self._type_combo.findData(
            prompt.prompt_type
        )

        if idx >= 0:
            self._type_combo.setCurrentIndex(idx)

        self._delete_btn.setEnabled(True)

    def _on_save(self):

        title = self._title_input.text().strip()
        content = self._content_input.toPlainText().strip()

        if not title or not content:
            QMessageBox.warning(
                self,
                "Validation",
                "Title and content are required.",
            )
            return

        prompt_type = self._type_combo.currentData()
        tags = self._tags_input.text().strip()

        if self._editing_id is None:

            self._prompt_ctrl.create_prompt(
                title=title,
                content=content,
                prompt_type=prompt_type,
                tags=tags,
            )

        else:

            prompt = next(
                (
                    p
                    for p in self._load_prompts()
                    if p.id == self._editing_id
                ),
                None,
            )

            if prompt:
                prompt.title = title
                prompt.content = content
                prompt.prompt_type = prompt_type
                prompt.tags = tags

                self._prompt_ctrl.update_prompt(prompt)

        self._clear_form()
        self.refresh()

    def _on_delete(self):

        if self._editing_id is None:
            return

        reply = QMessageBox.question(
            self,
            "Delete Prompt",
            "Delete this prompt?",
            QMessageBox.StandardButton.Yes
            | QMessageBox.StandardButton.No,
        )

        if reply == QMessageBox.StandardButton.Yes:

            self._prompt_ctrl.delete_prompt(
                self._editing_id
            )

            self._clear_form()
            self.refresh()


    def _clear_form(self):

        self._editing_id = None

        self._title_input.clear()
        self._content_input.clear()
        self._tags_input.clear()
        self._character_input.clear()
        self._style_input.clear()
        self._background_input.clear()
        self._prompt_preview.clear()

        self._type_combo.setCurrentIndex(0)

        self._delete_btn.setEnabled(False)

        self._table.clearSelection()

    def _populate_table(self, prompts):

        self._table.setRowCount(len(prompts))

        for row, prompt in enumerate(prompts):

            title_item = QTableWidgetItem(prompt.title)
            title_item.setData(
                Qt.ItemDataRole.UserRole,
                prompt.id,
            )

            self._table.setItem(
                row,
                0,
                title_item,
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


    def refresh(self):

        self._search_input.blockSignals(True)
        self._search_input.clear()
        self._search_input.blockSignals(False)

        self._populate_table(
            self._load_prompts()
        )
