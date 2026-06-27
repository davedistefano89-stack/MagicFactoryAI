"""Central AI manager."""

from __future__ import annotations

from core.ai.models import AIRequest, AIResult
from core.ai.prompt_builder import PromptBuilder
from core.ai.provider_base import AIProvider


class AIManager:
    """Coordinates AI providers."""

    def __init__(self, provider: AIProvider) -> None:
        self._provider = provider

    @property
    def provider(self) -> AIProvider:
        return self._provider

    @provider.setter
    def provider(self, provider: AIProvider) -> None:
        self._provider = provider

    def generate(self, request: AIRequest) -> AIResult:
        """
        Generate an image using the active provider.
        """

        final_prompt = PromptBuilder.build(
            user_prompt=request.prompt
        )

        try:

            image = self._provider.generate_image(
                image_path=request.image_path,
                prompt=final_prompt,
            )

            return AIResult(
                success=True,
                image_bytes=image,
                provider=self._provider.name,
                model=request.model,
            )

        except Exception as exc:

            return AIResult(
                success=False,
                error=str(exc),
                provider=self._provider.name,
                model=request.model,
            )

    def test_connection(self) -> bool:
        return self._provider.test_connection()