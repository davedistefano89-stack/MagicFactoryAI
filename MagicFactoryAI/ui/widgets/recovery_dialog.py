"""Recovery dialog shown at startup when an unsaved snapshot is detected."""

from __future__ import annotations

from datetime import datetime

from PySide6.QtWidgets import (
    QDialog,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
)


class RecoveryDialog(QDialog):
    """Confirm whether to recover an unsaved snapshot or discard it.

    Exposes a ``recover`` boolean: ``True`` if the user chose Recover,
    ``False`` if they chose Discard (or closed the dialog).
    """

    def __init__(
        self,
        project_name: str,
        recovery_at: datetime,
        project_saved_at: datetime,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self._recover: bool = False

        self.setWindowTitle("Recupera progetto?")
        self.setModal(True)
        self.setMinimumWidth(440)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 18, 20, 18)
        layout.setSpacing(12)

        header = QLabel("🛟  Lavoro non salvato rilevato")
        header.setStyleSheet("font-size: 15px; font-weight: 600;")
        layout.addWidget(header)

        body = QLabel(
            "Uno snapshot di salvataggio automatico di questa sessione è più "
            "recente dell'ultimo salvataggio manuale.\n\n"
            f"Progetto:           {project_name}\n"
            f"Snapshot:           {recovery_at.strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"Ultimo salvataggio: {project_saved_at.strftime('%Y-%m-%d %H:%M:%S')}\n\n"
            "Recuperare il lavoro non salvato, oppure scartare lo snapshot e "
            "continuare dall'ultimo salvataggio manuale?"
        )
        body.setWordWrap(True)
        body.setStyleSheet("font-size: 13px;")
        layout.addWidget(body)

        btn_row = QHBoxLayout()
        btn_row.setSpacing(8)
        btn_row.addStretch()

        discard_btn = QPushButton("Scarta")
        discard_btn.setProperty("cssClass", "ghost")
        discard_btn.setFixedWidth(110)
        discard_btn.setFixedHeight(34)
        discard_btn.clicked.connect(self.reject)
        btn_row.addWidget(discard_btn)

        recover_btn = QPushButton("Recupera")
        recover_btn.setProperty("cssClass", "primary")
        recover_btn.setFixedWidth(110)
        recover_btn.setFixedHeight(34)
        recover_btn.setDefault(True)
        recover_btn.clicked.connect(self._on_recover)
        btn_row.addWidget(recover_btn)

        layout.addLayout(btn_row)

    def _on_recover(self) -> None:
        self._recover = True
        self.accept()

    @property
    def recover(self) -> bool:
        return self._recover
