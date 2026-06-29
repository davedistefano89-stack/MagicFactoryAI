from __future__ import annotations

import base64
import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

logger = logging.getLogger(__name__)


class OpenAIService:
    """
    Central OpenAI service used by the application.

    Responsibilities
    ----------------
    - Build prompts
    - Generate images
    - Return image bytes
    - Save generated images
    - Test API connection
    """

    def __init__(self) -> None:

        load_dotenv()

        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise RuntimeError(
                "OPENAI_API_KEY not found."
            )

        self.client = OpenAI(
            api_key=api_key,
        )

    # ---------------------------------------------------------
    # Prompt Builder
    # ---------------------------------------------------------

    def build_prompt(
        self,
        category: str,
        subject: str,
        age: str = "3-6",
        complexity: str = "simple",
    ) -> str:

        system_prompt = """
You are one of the best prompt engineers in the world.

Create prompts for children's coloring books.

Rules:

- black outlines only
- white background
- no grayscale
- no shadows
- no colors
- thick outlines
- large coloring areas
- centered composition
- printable
- full body
- no text
- suitable for children

Return ONLY the final prompt.
"""

        user_prompt = f"""
Category:
{category}

Subject:
{subject}

Target Age:
{age}

Complexity:
{complexity}
"""

        try:
            response = self.client.chat.completions.create(
                model="gpt-5",
                messages=[
                    {
                        "role": "system",
                        "content": system_prompt,
                    },
                    {
                        "role": "user",
                        "content": user_prompt,
                    },
                ],
            )

            return response.choices[0].message.content.strip()

        except Exception as exc:
            self._handle_api_error(exc)

    # ---------------------------------------------------------
    # Image Generation
    # ---------------------------------------------------------

    def generate_image_bytes(
        self,
        prompt: str,
        size: str = "1024x1024",
    ) -> bytes:
        """
        Generate an image and return PNG bytes.
        """

        logger.info(
            "Generating image bytes..."
        )

        try:
            result = self.client.images.generate(
                model="gpt-image-1",
                prompt=prompt,
                size=size,
            )

            image_base64 = result.data[0].b64_json

            return base64.b64decode(image_base64)

        except Exception as exc:
            self._handle_api_error(exc)

    def generate_image(
        self,
        prompt: str,
        output_folder: Path,
        filename: str,
        size: str = "1024x1024",
    ) -> Path:

        output_folder.mkdir(
            parents=True,
            exist_ok=True,
        )

        image_bytes = self.generate_image_bytes(
            prompt=prompt,
            size=size,
        )

        output_path = output_folder / filename

        with open(
            output_path,
            "wb",
        ) as file:
            file.write(image_bytes)

        logger.info(
            "Image saved: %s",
            output_path,
        )

        return output_path
    
    # ---------------------------------------------------------
    # Complete Workflow
    # ---------------------------------------------------------

    def generate_coloring_page(
        self,
        category: str,
        subject: str,
        output_folder: Path,
        filename: str,
        age: str = "3-6",
        complexity: str = "simple",
    ) -> Path:
        """
        Generate a complete coloring page.
        """

        logger.info("Building AI prompt...")

        prompt = self.build_prompt(
            category=category,
            subject=subject,
            age=age,
            complexity=complexity,
        )

        logger.info("Prompt successfully generated.")

        image = self.generate_image(
            prompt=prompt,
            output_folder=output_folder,
            filename=filename,
        )

        logger.info("Image generation completed.")

        return image

    # ---------------------------------------------------------
    # Connection
    # ---------------------------------------------------------

    def test_connection(self) -> bool:
        try:
            self.client.models.list()
            return True
        except Exception as exc:
            # Log original exception for debugging and return False
            logger.exception(exc)
            return False

    def _handle_api_error(self, exc: Exception) -> None:
        """
        Map common OpenAI errors to user-friendly messages, log the
        original exception, and raise a RuntimeError with the friendly
        message so callers can display it to users.
        """

        # Always log full exception and traceback
        logger.exception(exc)

        msg = str(exc).lower() if exc is not None else ""

        if "insufficient_quota" in msg or "insufficient_quota" in getattr(exc, "code", ""):
            friendly = (
                "Insufficient quota: your OpenAI account has no remaining quota. "
                "Check your billing and subscription settings."
            )
        elif "invalid_api_key" in msg or "invalid_api_key" in getattr(exc, "code", ""):
            friendly = (
                "Invalid API key: please verify your OPENAI_API_KEY environment variable."
            )
        elif "rate_limit_exceeded" in msg or "rate_limit" in msg:
            friendly = (
                "Rate limit exceeded: too many requests. Please wait a moment and try again."
            )
        elif "authentication_error" in msg or "invalid_auth" in msg or "authentication" in msg:
            friendly = (
                "Authentication failed: check your API key and permissions."
            )
        elif "timeout" in msg or "network" in msg or "timed out" in msg:
            friendly = (
                "Network timeout: check your internet connection and try again."
            )
        else:
            friendly = (
                "An error occurred while communicating with the OpenAI API. "
                "See logs for details."
            )

        # Raise a user-facing error while preserving original exception as __cause__
        raise RuntimeError(friendly) from exc

    # ---------------------------------------------------------
    # Presets
    # ---------------------------------------------------------

    def generate_princess(
        self,
        subject: str,
        output_folder: Path,
        filename: str,
    ) -> Path:

        return self.generate_coloring_page(
            category="Princess",
            subject=subject,
            output_folder=output_folder,
            filename=filename,
        )

    def generate_unicorn(
        self,
        subject: str,
        output_folder: Path,
        filename: str,
    ) -> Path:

        return self.generate_coloring_page(
            category="Unicorn",
            subject=subject,
            output_folder=output_folder,
            filename=filename,
        )

    def generate_animal(
        self,
        subject: str,
        output_folder: Path,
        filename: str,
    ) -> Path:

        return self.generate_coloring_page(
            category="Animals",
            subject=subject,
            output_folder=output_folder,
            filename=filename,
        )

    def generate_vehicle(
        self,
        subject: str,
        output_folder: Path,
        filename: str,
    ) -> Path:

        return self.generate_coloring_page(
            category="Vehicles",
            subject=subject,
            output_folder=output_folder,
            filename=filename,
        )

    def generate_dinosaur(
        self,
        subject: str,
        output_folder: Path,
        filename: str,
    ) -> Path:

        return self.generate_coloring_page(
            category="Dinosaurs",
            subject=subject,
            output_folder=output_folder,
            filename=filename,
        )

    def generate_mermaid(
        self,
        subject: str,
        output_folder: Path,
        filename: str,
    ) -> Path:

        return self.generate_coloring_page(
            category="Mermaids",
            subject=subject,
            output_folder=output_folder,
            filename=filename,
        )

    def generate_space(
        self,
        subject: str,
        output_folder: Path,
        filename: str,
    ) -> Path:

        return self.generate_coloring_page(
            category="Space",
            subject=subject,
            output_folder=output_folder,
            filename=filename,
        )