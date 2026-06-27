"""Base interface for AI providers."""

from __future__ import annotations

from abc import ABC, abstractmethod
from pathlib import Path


class AIProvider(ABC):
    """Abstract base class for all AI providers."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Provider display name."""
        raise NotImplementedError

    @abstractmethod
    def generate_image(
        self,
        image_path: Path,
        prompt: str,
    ) -> bytes:
        """
        Generate an image.

        Parameters
        ----------
        image_path:
            Source image.

        prompt:
            Final prompt to send to the AI.

        Returns
        -------
        bytes
            Generated image bytes.
        """
        raise NotImplementedError

    @abstractmethod
    def test_connection(self) -> bool:
        """Return True if the provider is configured correctly."""
        raise NotImplementedError