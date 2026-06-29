from __future__ import annotations

from PySide6.QtCore import QObject, Signal, Slot

from app.controllers.ai_generator_controller import AIGeneratorController


class AIGenerationWorker(QObject):
    """
    Background worker responsible for AI image generation.

    The worker performs generation outside the GUI thread
    and notifies the interface through Qt signals.
    """

    started = Signal()

    progress = Signal(int)

    status = Signal(str)

    finished = Signal(object)

    error = Signal(str)

    def __init__(
        self,
        controller: AIGeneratorController,
    ) -> None:

        super().__init__()

        self._controller = controller

        self._cancel_requested = False

    def cancel(self) -> None:
        """
        Request cancellation.
        """

        self._cancel_requested = True

    @Slot(dict)
    def generate(
        self,
        request: dict,
    ) -> None:
        """
        Execute one AI generation request.
        """

        self.started.emit()

        try:

            self.status.emit(
                "Preparing generation..."
            )

            self.progress.emit(5)

            if self._cancel_requested:
                self.status.emit("Cancelled")
                return

            asset = self._controller.generate(
                category=request["category"],
                subject=request["subject"],
                project_id=request["project_id"],
                category_id=request.get("category_id"),
                prompt_id=request.get("prompt_id"),
                age=request["age"],
                complexity=request["complexity"],
            )

            if self._cancel_requested:
                self.status.emit("Cancelled")
                return

            self.progress.emit(100)

            self.status.emit(
                "Generation completed."
            )

            self.finished.emit(asset)

        except Exception as exc:

            self.error.emit(str(exc))