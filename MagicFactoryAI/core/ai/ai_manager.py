"""Central AI manager."""

from __future__ import annotations

from pathlib import Path

from core.ai.models import AIRequest, AIResult
from core.ai.prompt_builder import PromptBuilder
from core.ai.provider_base import AIProvider


class AIManager:
    """
    Coordinates all AI providers.

    Controllers communicate only with AIManager.
    AIManager is responsible for building prompts,
    selecting the provider and returning AIResult.
    """

    def __init__(self, provider: AIProvider) -> None:
        self._provider = provider

    @property
    def provider(self) -> AIProvider:
        return self._provider

    @provider.setter
    def provider(self, provider: AIProvider) -> None:
        self._provider = provider

    # ---------------------------------------------------------
    # High level API
    # ---------------------------------------------------------

    def create_request(
        self,
        *,
        prompt: str,
        model: str = "gpt-image-1",
        image_path: Path | None = None,
    ) -> AIRequest:
        """
        Build an AIRequest from simple parameters.
        """

        return AIRequest(
            prompt=prompt,
            model=model,
            image_path=image_path,
        )

    # ---------------------------------------------------------
    # Main generation
    # ---------------------------------------------------------

    def generate(
        self,
        request: AIRequest,
    ) -> AIResult:
        """
        Generate an image using the active provider.
        """

        final_prompt = PromptBuilder.build(
            user_prompt=request.prompt,
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

    # ---------------------------------------------------------
    # Convenience API
    # ---------------------------------------------------------

    def generate_from_prompt(
        self,
        prompt: str,
        model: str = "gpt-image-1",
    ) -> AIResult:
        """
        Generate directly from a prompt.
        """

        request = self.create_request(
            prompt=prompt,
            model=model,
        )

        return self.generate(request)

    # ---------------------------------------------------------
    # Connection
    # ---------------------------------------------------------

    def test_connection(self) -> bool:
        return self._provider.test_connection()