"""OpenAI provider."""

from __future__ import annotations

from pathlib import Path

from core.ai.provider_base import AIProvider
from services.openai_service import OpenAIService


class OpenAIProvider(AIProvider):
    """
    OpenAI implementation of AIProvider.
    """

    def __init__(self) -> None:
        self._service = OpenAIService()

    @property
    def name(self) -> str:
        return "OpenAI"

    def generate_image(
        self,
        image_path: Path,
        prompt: str,
    ) -> bytes:
        """
        Generate an image using OpenAI.

        image_path is currently unused but is kept to
        maintain compatibility with the AIProvider interface.
        """

        return self._service.generate_image_bytes(
            prompt=prompt,
        )

    def test_connection(self) -> bool:
        return self._service.test_connection()

    @property
    def service(self) -> OpenAIService:
        """
        Gives access to the underlying OpenAIService.
        """

        return self._service