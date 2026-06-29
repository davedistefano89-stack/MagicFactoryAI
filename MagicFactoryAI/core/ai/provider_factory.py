"""Factory for creating AIProvider instances by name."""

from __future__ import annotations

from core.ai.provider_base import AIProvider
from core.ai.openai_provider import OpenAIProvider
from core.ai.mock_provider import MockProvider


class AIProviderFactory:
    """Create AIProvider instances by a short provider name."""

    @staticmethod
    def create(provider_name: str) -> AIProvider:
        if not provider_name:
            raise ValueError("provider_name must be provided")

        name = provider_name.strip().lower()

        if name == "openai":
            return OpenAIProvider()

        if name == "mock":
            return MockProvider()

        raise ValueError(f"Unknown AI provider: '{provider_name}'")
