"""Prompts tab within the project workspace."""

from __future__ import annotations

from typing import List, Optional

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox,
    QFormLayout,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QSplitter,
    QTableWidget,
    QTableWidgetItem,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from app.controllers.prompt_controller import PromptController
from core.theme.colors import Colors
from models.prompt import Prompt, PromptType
from ui.widgets.prompt_collection_utils import (
    collect_all_prompt_collections,
    get_display_tags,
    get_prompt_collections,
    set_prompt_collections,
)
from ui.widgets.workspace.tabs.base_tab import WorkspaceTabBase

_COLLECTION_BTN_STYLE = (
    "QPushButton { background-color: transparent; border: none; border-radius: 6px;"
    " padding: 3px 8px; font-size: 12px; color: #94A3B8; text-align: left; }"
    " QPushButton:checked { background-color: #6366F122; color: #818CF8;"
    " font-weight: 600; }"
    " QPushButton:hover:!checked { background-color: #334155; color: #F8FAFC; }"
)

_CHIP_STYLE = (
    "QPushButton { background-color: #334155; border: 1px solid #475569;"
    " border-radius: 12px; padding: 3px 12px; font-size: 12px; color: #F8FAFC; }"
    " QPushButton:hover { background-color: #EF4444; border-color: #EF4444; color: #FFFFFF; }"
)


class PromptsTab(WorkspaceTabBase):
    """Manage prompts inside the workspace."""

    def _build_ui(self) -> None:

        self._prompt_ctrl = PromptController(self.controller)
        self._editing_id: Optional[int] = None
        self._all_prompts: List[Prompt] = []
        self._selected_collection: Optional[str] = None
        self._known_collections: List[str] = []
        self._applying_recovery: bool = False

        # ── Outer horizontal layout: sidebar | splitter ───────────────────
        outer = QHBoxLayout()
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(12)
        outer.addWidget(self._build_collections_sidebar())

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
        self._search_input.setPlaceholderText("Search prompts, tags or collections…")
        self._search_input.textChanged.connect(self._apply_filters)

        left_layout.addWidget(self._search_input)

        self._table = QTableWidget()
        self._table.setColumnCount(3)
        self._table.setHorizontalHeaderLabels(["Title", "Type", "★"])

        self._table.horizontalHeader().setStretchLastSection(True)
        self._table.verticalHeader().setVisible(False)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.setSelectionMode(QTableWidget.SelectionMode.ExtendedSelection)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.itemSelectionChanged.connect(self._on_select)

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
            self._type_combo.addItem(pt.value.title(), pt)

        form.addRow("Type", self._type_combo)

        self._tags_input = QLineEdit()
        form.addRow("Tags", self._tags_input)

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
        form.addRow("Content", self._content_input)

        right_layout.addLayout(form)

        # Collections inspector group
        right_layout.addWidget(self._build_collections_inspector())

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

        outer.addWidget(splitter, stretch=1)
        self._layout.addLayout(outer, stretch=1)

        # Sprint: register prompt-form draft for crash recovery and mark dirty
        # whenever the user types in the form fields.
        try:
            self.workspace.register_recovery_section(
                "prompt_edit", self._collect_prompt_recovery_draft
            )
            self.workspace.register_recovery_apply(
                "prompt_edit", self._apply_prompt_recovery_draft
            )
        except Exception:
            pass
        for _w in (
            self._title_input,
            self._tags_input,
            self._character_input,
            self._style_input,
            self._background_input,
        ):
            _w.textChanged.connect(lambda *_: self._on_prompt_field_dirty())
        self._content_input.textChanged.connect(
            lambda *_: self._on_prompt_field_dirty()
        )

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


    def _apply_filters(self) -> None:
        """Filter _all_prompts by search text and selected collection, then render."""
        query = self._search_input.text().lower().strip()
        result: List[Prompt] = []
        for p in self._all_prompts:
            cols = get_prompt_collections(p)
            if self._selected_collection:
                col_lower = self._selected_collection.lower()
                if col_lower not in {c.lower() for c in cols}:
                    continue
            if query:
                col_str = " ".join(c.lower() for c in cols)
                searchable = (
                    p.title.lower()
                    + " "
                    + (get_display_tags(p) or "").lower()
                    + " "
                    + p.content.lower()
                    + " "
                    + col_str
                )
                if query not in searchable:
                    continue
            result.append(p)
        self._populate_table(result)

    # Keep old name as alias so any external callers are not broken
    def _on_search(self, _text: str = "") -> None:
        self._apply_filters()


    def _on_select(self):

        rows = self._table.selectionModel().selectedRows()

        if not rows:
            return

        prompt_id = self._table.item(
            rows[0].row(),
            0,
        ).data(Qt.ItemDataRole.UserRole)

        prompt = next(
            (p for p in self._all_prompts if p.id == prompt_id),
            None,
        )

        if prompt is None:
            return

        self._editing_id = prompt.id

        self._title_input.setText(prompt.title)
        self._content_input.setPlainText(prompt.content)
        # Show display tags only (no __col__: entries)
        self._tags_input.setText(get_display_tags(prompt))

        idx = self._type_combo.findData(prompt.prompt_type)
        if idx >= 0:
            self._type_combo.setCurrentIndex(idx)

        self._delete_btn.setEnabled(True)
        self._refresh_collections_inspector(prompt)

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
        display_tags = self._tags_input.text().strip()

        if self._editing_id is None:
            # New prompt — no undo record yet (entity didn't exist before).
            created = self._prompt_ctrl.create_prompt(
                title=title,
                content=content,
                prompt_type=prompt_type,
                tags=display_tags,
            )
            self._record_prompt_create(created)
        else:
            prompt = next(
                (p for p in self._all_prompts if p.id == self._editing_id),
                None,
            )

            if prompt:
                old_title = prompt.title
                old_content = prompt.content
                old_type = prompt.prompt_type
                old_display_tags = prompt.tags  # includes __col__: entries
                # Preserve __col__: entries; replace display portion only
                existing_cols = get_prompt_collections(prompt)
                new_tags = display_tags
                set_prompt_collections(prompt, existing_cols)
                new_full_tags = prompt.tags

                if self._prompt_ctrl.save_prompt(
                    prompt.id, title, content, prompt_type, new_full_tags
                ):
                    self._record_prompt_edit(
                        prompt_id=prompt.id,
                        old=(old_title, old_content, old_type, old_display_tags),
                        new=(title, content, prompt_type, new_full_tags),
                        title_label=title,
                    )

        self._clear_form()
        self.refresh()

    def _record_prompt_create(self, prompt) -> None:
        """Record an undoable create: undo re-deletes, redo re-creates."""
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None:
            return
        ctrl = self._prompt_ctrl
        snapshot = {
            "title": prompt.title,
            "content": prompt.content,
            "prompt_type": prompt.prompt_type,
            "tags": prompt.tags,
            "category_id": prompt.category_id,
        }
        new_id = prompt.id

        def _undo_create() -> None:
            if new_id is not None:
                try:
                    ctrl.delete_prompt(new_id)
                except Exception:
                    pass

        def _redo_create() -> None:
            try:
                ctrl.create_prompt(
                    title=snapshot["title"],
                    content=snapshot["content"],
                    prompt_type=snapshot["prompt_type"],
                    tags=snapshot["tags"],
                    category_id=snapshot.get("category_id"),
                )
            except Exception:
                pass

        manager.record(
            "Create prompt",
            undo=_undo_create,
            redo=_redo_create,
            context=snapshot["title"],
        )

    def _record_prompt_edit(
        self,
        prompt_id: int,
        old: tuple,
        new: tuple,
        title_label: str,
    ) -> None:
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None:
            return
        ctrl = self._prompt_ctrl
        old_title, old_content, old_type, old_tags = old
        new_title, new_content, new_type, new_tags = new

        def _undo_edit() -> None:
            ctrl.save_prompt(
                prompt_id, old_title, old_content, old_type, old_tags
            )

        def _redo_edit() -> None:
            ctrl.save_prompt(
                prompt_id, new_title, new_content, new_type, new_tags
            )

        manager.record(
            "Edit prompt",
            undo=_undo_edit,
            redo=_redo_edit,
            context=title_label,
        )

    def _on_delete(self):

        if self._editing_id is None:
            return

        prompt = next(
            (p for p in self._all_prompts if p.id == self._editing_id), None
        )
        if prompt is None:
            return

        reply = QMessageBox.question(
            self,
            "Delete Prompt",
            "Delete this prompt?",
            QMessageBox.StandardButton.Yes
            | QMessageBox.StandardButton.No,
        )

        if reply != QMessageBox.StandardButton.Yes:
            return

        # Snapshot the prompt so undo can restore it via re-creation
        # (a new id will be assigned; tags / title / content preserved).
        snapshot = {
            "title": prompt.title,
            "content": prompt.content,
            "prompt_type": prompt.prompt_type,
            "tags": prompt.tags,
            "category_id": prompt.category_id,
        }
        title_label = snapshot["title"]
        prompt_id = self._editing_id
        manager = getattr(self.controller, "undo_manager", None)
        ctrl = self._prompt_ctrl

        if manager is not None:
            def _undo_delete() -> None:
                try:
                    ctrl.create_prompt(
                        title=snapshot["title"],
                        content=snapshot["content"],
                        prompt_type=snapshot["prompt_type"],
                        tags=snapshot["tags"],
                        category_id=snapshot.get("category_id"),
                    )
                except Exception:
                    pass

            def _redo_delete() -> None:
                try:
                    ctrl.delete_prompt(prompt_id)
                except Exception:
                    pass

            manager.record(
                "Delete prompt",
                undo=_undo_delete,
                redo=_redo_delete,
                context=title_label,
            )

        self._prompt_ctrl.delete_prompt(prompt_id)
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
        self._refresh_collections_inspector(None)

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

        self._all_prompts = self._load_prompts()
        self._rebuild_collection_sidebar()
        self._apply_filters()

    # ── Collections sidebar ───────────────────────────────────────────────────

    def _build_collections_sidebar(self) -> QFrame:
        frame = QFrame()
        frame.setFixedWidth(164)
        frame.setStyleSheet(f"""
            QFrame {{
                background-color: {Colors.SURFACE};
                border: 1px solid {Colors.BORDER};
                border-radius: 12px;
            }}
        """)

        layout = QVBoxLayout(frame)
        layout.setContentsMargins(10, 14, 10, 14)
        layout.setSpacing(4)

        hdr = QHBoxLayout()
        hdr.setSpacing(4)
        title = QLabel("Collections")
        title.setStyleSheet(
            f"font-size: 12px; font-weight: 600; color: {Colors.TEXT_SECONDARY};"
        )
        hdr.addWidget(title)
        hdr.addStretch()

        new_btn = QPushButton("+")
        new_btn.setProperty("cssClass", "ghost")
        new_btn.setFixedSize(22, 22)
        new_btn.setToolTip("New Collection")
        new_btn.clicked.connect(self._on_new_collection)
        hdr.addWidget(new_btn)
        layout.addLayout(hdr)

        self._col_all_btn = QPushButton("All Prompts")
        self._col_all_btn.setCheckable(True)
        self._col_all_btn.setChecked(True)
        self._col_all_btn.setFixedHeight(30)
        self._col_all_btn.setStyleSheet(_COLLECTION_BTN_STYLE)
        self._col_all_btn.clicked.connect(lambda: self._select_collection(None))
        layout.addWidget(self._col_all_btn)

        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet(f"color: {Colors.BORDER};")
        layout.addWidget(sep)

        col_scroll = QScrollArea()
        col_scroll.setWidgetResizable(True)
        col_scroll.setFrameShape(QFrame.Shape.NoFrame)
        col_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self._col_list_widget = QWidget()
        self._col_list_widget.setStyleSheet("background: transparent;")
        self._col_list_layout = QVBoxLayout(self._col_list_widget)
        self._col_list_layout.setContentsMargins(0, 0, 0, 0)
        self._col_list_layout.setSpacing(2)
        self._col_list_layout.addStretch()
        col_scroll.setWidget(self._col_list_widget)

        layout.addWidget(col_scroll, stretch=1)
        return frame

    def _rebuild_collection_sidebar(self) -> None:
        while self._col_list_layout.count() > 1:
            item = self._col_list_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        from_prompts = collect_all_prompt_collections(self._all_prompts)
        merged = list(from_prompts)
        for c in self._known_collections:
            if c.lower() not in {x.lower() for x in merged}:
                merged.append(c)
        merged.sort(key=str.lower)
        self._known_collections = merged

        self._col_all_btn.setChecked(self._selected_collection is None)

        for col in merged:
            btn = QPushButton(col)
            btn.setCheckable(True)
            btn.setChecked(
                self._selected_collection is not None
                and self._selected_collection.lower() == col.lower()
            )
            btn.setFixedHeight(28)
            btn.setStyleSheet(_COLLECTION_BTN_STYLE)
            btn.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
            btn.customContextMenuRequested.connect(
                lambda _pos, c=col, b=btn: self._collection_context_menu(c, b)
            )
            btn.clicked.connect(lambda _checked, c=col: self._select_collection(c))
            self._col_list_layout.insertWidget(
                self._col_list_layout.count() - 1, btn
            )

    def _select_collection(self, name: Optional[str]) -> None:
        self._selected_collection = name
        self._col_all_btn.setChecked(name is None)
        for i in range(self._col_list_layout.count()):
            item = self._col_list_layout.itemAt(i)
            if item and item.widget() and isinstance(item.widget(), QPushButton):
                btn = item.widget()
                btn.setChecked(
                    name is not None and btn.text().lower() == name.lower()
                )
        self._apply_filters()

    def _collection_context_menu(self, col_name: str, btn: QPushButton) -> None:
        from PySide6.QtWidgets import QMenu
        menu = QMenu(self)
        rename_act = menu.addAction("✏️  Rename")
        delete_act = menu.addAction("🗑  Delete")
        action = menu.exec(btn.mapToGlobal(btn.rect().bottomLeft()))
        if action == rename_act:
            self._on_rename_collection(col_name)
        elif action == delete_act:
            self._on_delete_collection(col_name)

    def _on_new_collection(self) -> None:
        name, ok = QInputDialog.getText(self, "New Collection", "Collection name:")
        if ok and name.strip():
            name = name.strip()
            if name.lower() not in {c.lower() for c in self._known_collections}:
                self._known_collections.append(name)
            self._rebuild_collection_sidebar()

    def _on_rename_collection(self, old_name: str) -> None:
        new_name, ok = QInputDialog.getText(
            self, "Rename Collection", "New name:", text=old_name
        )
        if not ok or not new_name.strip():
            return
        new_name = new_name.strip()
        if new_name.lower() == old_name.lower():
            return
        # Sprint: Global Undo / Redo PRO #1 — snapshot pre-state so the
        # bulk rename across all prompts can be reverted cleanly.
        snapshots = [
            (prompt.id, list(get_prompt_collections(prompt)))
            for prompt in self._all_prompts
        ]
        for prompt in self._all_prompts:
            cols = get_prompt_collections(prompt)
            updated = [new_name if c.lower() == old_name.lower() else c for c in cols]
            if updated != cols:
                set_prompt_collections(prompt, updated)
                self._prompt_ctrl.update_prompt(prompt)
        if (
            self._selected_collection
            and self._selected_collection.lower() == old_name.lower()
        ):
            self._selected_collection = new_name
        self._record_collection_rename(
            snapshots=snapshots,
            old_name=old_name,
            new_name=new_name,
        )
        self.refresh()

    def _record_collection_rename(
        self,
        snapshots: list,
        old_name: str,
        new_name: str,
    ) -> None:
        """Push a bulk collection rename onto the global undo stack.

        ``snapshots`` is ``[(prompt_id, old_collections_list), ...]``
        captured BEFORE the rename. Undo restores the prior lists,
        redo re-applies the rename across the same prompt set.
        """
        manager = getattr(self.controller, "undo_manager", None)
        if manager is None:
            return
        ctrl = self._prompt_ctrl
        snap = [
            (pid, list(cols))
            for pid, cols in snapshots
            if pid is not None
        ]
        if not snap:
            return

        def _undo() -> None:
            try:
                for pid, old_cols in snap:
                    inst = ctrl.get_by_id(pid)
                    if inst is None:
                        continue
                    set_prompt_collections(inst, list(old_cols))
                    ctrl.update_prompt(inst)
                if (
                    self._selected_collection
                    and self._selected_collection.lower() == new_name.lower()
                ):
                    self._selected_collection = old_name
            except Exception:
                pass

        def _redo() -> None:
            try:
                for pid, _old_cols in snap:
                    inst = ctrl.get_by_id(pid)
                    if inst is None:
                        continue
                    cols = get_prompt_collections(inst)
                    updated = [
                        new_name if c.lower() == old_name.lower() else c
                        for c in cols
                    ]
                    if updated != cols:
                        set_prompt_collections(inst, updated)
                        ctrl.update_prompt(inst)
                if (
                    self._selected_collection
                    and self._selected_collection.lower() == old_name.lower()
                ):
                    self._selected_collection = new_name
            except Exception:
                pass

        manager.record(
            f"Rename collection ({len(snap)} prompt(s))",
            undo=_undo,
            redo=_redo,
            context=f"{old_name} -> {new_name}",
        )

    def _on_delete_collection(self, name: str) -> None:
        reply = QMessageBox.question(
            self,
            "Delete Collection",
            f"Remove collection '{name}'?\n\nPrompts will NOT be deleted.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        for prompt in self._all_prompts:
            cols = get_prompt_collections(prompt)
            updated = [c for c in cols if c.lower() != name.lower()]
            if updated != cols:
                set_prompt_collections(prompt, updated)
                self._prompt_ctrl.update_prompt(prompt)
        if (
            self._selected_collection
            and self._selected_collection.lower() == name.lower()
        ):
            self._selected_collection = None
        self._known_collections = [
            c for c in self._known_collections if c.lower() != name.lower()
        ]
        self.refresh()

    # ── Collections inspector (inside right panel) ────────────────────────────

    def _build_collections_inspector(self) -> QGroupBox:
        box = QGroupBox("Collections")
        layout = QVBoxLayout(box)
        layout.setSpacing(8)

        self._insp_cols_scroll = QScrollArea()
        self._insp_cols_scroll.setWidgetResizable(True)
        self._insp_cols_scroll.setFixedHeight(46)
        self._insp_cols_scroll.setFrameShape(QFrame.Shape.NoFrame)
        self._insp_cols_scroll.setVerticalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )

        self._insp_cols_widget = QWidget()
        self._insp_cols_layout = QHBoxLayout(self._insp_cols_widget)
        self._insp_cols_layout.setContentsMargins(0, 4, 0, 4)
        self._insp_cols_layout.setSpacing(6)
        self._insp_cols_layout.addStretch()
        self._insp_cols_scroll.setWidget(self._insp_cols_widget)
        layout.addWidget(self._insp_cols_scroll)

        add_btn = QPushButton("+ Add to Collection")
        add_btn.setProperty("cssClass", "ghost")
        add_btn.setFixedHeight(28)
        add_btn.clicked.connect(self._on_add_to_collection)
        layout.addWidget(add_btn)

        return box

    def _refresh_collections_inspector(self, prompt: Optional[Prompt]) -> None:
        while self._insp_cols_layout.count() > 1:
            item = self._insp_cols_layout.takeAt(0)
            if item and item.widget():
                item.widget().deleteLater()

        if prompt is None:
            return

        for col in get_prompt_collections(prompt):
            chip = QPushButton(f"{col}  ×")
            chip.setFixedHeight(26)
            chip.setStyleSheet(_CHIP_STYLE)
            chip.clicked.connect(
                lambda _, c=col, p=prompt: self._on_remove_from_collection(p, c)
            )
            self._insp_cols_layout.insertWidget(
                self._insp_cols_layout.count() - 1, chip
            )

    def _on_add_to_collection(self) -> None:
        if self._editing_id is None:
            QMessageBox.information(
                self, "Add to Collection", "Select a prompt first."
            )
            return

        prompt = next(
            (p for p in self._all_prompts if p.id == self._editing_id), None
        )
        if prompt is None:
            return

        all_cols = collect_all_prompt_collections(self._all_prompts)
        for c in self._known_collections:
            if c.lower() not in {x.lower() for x in all_cols}:
                all_cols.append(c)
        all_cols.sort(key=str.lower)

        name, ok = QInputDialog.getItem(
            self,
            "Add to Collection",
            "Add prompt to collection:",
            all_cols,
            editable=True,
        )
        if not ok or not name.strip():
            return
        name = name.strip()

        current = get_prompt_collections(prompt)
        if name.lower() in {c.lower() for c in current}:
            return
        current.append(name)
        set_prompt_collections(prompt, current)
        self._prompt_ctrl.update_prompt(prompt)

        if name.lower() not in {c.lower() for c in self._known_collections}:
            self._known_collections.append(name)

        self._refresh_collections_inspector(prompt)
        self._rebuild_collection_sidebar()

    def _on_remove_from_collection(self, prompt: Prompt, col: str) -> None:
        current = [c for c in get_prompt_collections(prompt) if c != col]
        set_prompt_collections(prompt, current)
        self._prompt_ctrl.update_prompt(prompt)
        self._refresh_collections_inspector(prompt)
        self._rebuild_collection_sidebar()
