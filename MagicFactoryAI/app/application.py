"""QApplication bootstrap and main window lifecycle."""

from __future__ import annotations

import sys

from PySide6.QtGui import QFont
from PySide6.QtWidgets import QApplication

from app.controllers.app_controller import AppController
from core.settings.manager import SettingsManager
from core.theme.styles import ThemeManager
from ui.main_window import MainWindow
from utils.logger import get_logger, setup_logging

logger = get_logger(__name__)


class MagicFactoryApp:
    """Application entry point managing Qt lifecycle."""

    def __init__(self) -> None:
        self._settings = SettingsManager.instance()
        setup_logging(level=self._settings.log_level)
        self._controller = AppController.instance()
        self._app: QApplication | None = None
        self._window: MainWindow | None = None

    def run(self) -> int:
        self._app = QApplication(sys.argv)
        self._app.setApplicationName(self._settings.app_name)
        self._app.setApplicationVersion(str(self._settings.get("app.version", "1.0.0")))
        self._app.setOrganizationName("Magic Factory")

        font = QFont("Segoe UI", 10)
        self._app.setFont(font)

        ThemeManager.apply(self._app)

        self._window = MainWindow(self._controller)
        width, height = self._settings.window_size
        self._window.resize(width, height)
        self._window.show()

        logger.info("Magic Factory AI started")
        exit_code = self._app.exec()
        self._controller.shutdown()
        return exit_code
