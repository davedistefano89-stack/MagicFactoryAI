from __future__ import annotations

import base64
import logging
import os
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

logger = logging.getLogger(__name__)


class OpenAIService:
    def __init__(self):
        load_dotenv()

        api_key = os.getenv("OPENAI_API_KEY")

        if not api_key:
            raise RuntimeError("OPENAI_API_KEY not found.")

        self.client = OpenAI(api_key=api_key)

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

    def generate_image(
        self,
        prompt: str,
        output_folder: Path,
        filename: str,
        size: str = "1024x1024",
    ) -> Path:

        output_folder.mkdir(parents=True, exist_ok=True)

        logger.info("Generating image...")

        result = self.client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            size=size,
        )

        image_base64 = result.data[0].b64_json
        image_bytes = base64.b64decode(image_base64)

        output_path = output_folder / filename

        with open(output_path, "wb") as file:
            file.write(image_bytes)

        return output_path

    def generate_coloring_page(
        self,
        category: str,
        subject: str,
        output_folder: Path,
        filename: str,
        age: str = "3-6",
        complexity: str = "simple",
    ) -> Path:

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

    def test_connection(self) -> bool:
        try:
            self.client.models.list()
            return True

        except Exception as exc:
            logger.exception(exc)
            return False

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