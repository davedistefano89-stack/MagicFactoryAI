"""
Magic Factory AI

OpenAI Service

Handles:

- Prompt generation
- Image generation
- Image saving
"""

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
            raise RuntimeError(
                "OPENAI_API_KEY not found inside .env"
            )

        self.client = OpenAI(
            api_key=api_key,
        )

    # --------------------------------------------------

    def build_prompt(

        self,

        category: str,

        subject: str,

        age: str = "3-6",

        complexity: str = "simple",

    ) -> str:

        system = """
You are an expert prompt engineer.

You create prompts for children's coloring books.

Rules:

- black outlines only

- white background

- no gray

- no colors

- no shadows

- thick outlines

- large coloring areas

- simple composition

- centered character

- full body

- no text

- printable

Return ONLY the final prompt.
"""

        user = f"""

Category:

{category}

Subject:

{subject}

Target age:

{age}

Complexity:

{complexity}

"""

        response = self.client.chat.completions.create(

            model="gpt-5",

            messages=[

                {

                    "role": "system",

                    "content": system,

                },

                {

                    "role": "user",

                    "content": user,

                },

            ],

        )

        return (

            response

            .choices[0]

            .message

            .content

            .strip()

        )
            # --------------------------------------------------
    # IMAGE GENERATION
    # --------------------------------------------------

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

        logger.info(
            "Generating image with OpenAI..."
        )

        response = self.client.images.generate(

            model="gpt-image-1",

            prompt=prompt,

            size=size,
        )

        if not response.data:
            raise RuntimeError(
                "OpenAI returned no image."
            )

        image_base64 = response.data[0].b64_json

        image_bytes = base64.b64decode(
            image_base64
        )

        output_path = output_folder / filename

        with open(
            output_path,
            "wb",
        ) as file:

            file.write(image_bytes)

        logger.info(
            "Image saved to %s",
            output_path,
        )

        return output_path

    # --------------------------------------------------
    # COMPLETE PIPELINE
    # --------------------------------------------------

    def generate_coloring_page(

        self,

        category: str,

        subject: str,

        output_folder: Path,

        filename: str,

        age: str = "3-6",

        complexity: str = "simple",

    ) -> Path:

        logger.info(
            "Building prompt..."
        )

        prompt = self.build_prompt(

            category=category,

            subject=subject,

            age=age,

            complexity=complexity,

        )

        logger.info(
            "Prompt created successfully."
        )

        logger.debug(prompt)

        return self.generate_image(

            prompt=prompt,

            output_folder=output_folder,

            filename=filename,

        )
            # --------------------------------------------------
    # HEALTH CHECK
    # --------------------------------------------------

    def is_available(self) -> bool:
        """
        Returns True if the OpenAI client is available.
        """

        return self.client is not None

    # --------------------------------------------------
    # SAFE PIPELINE
    # --------------------------------------------------

    def generate_safe(

        self,

        category: str,

        subject: str,

        output_folder: Path,

        filename: str,

        age: str = "3-6",

        complexity: str = "simple",

    ) -> Path:

        try:

            return self.generate_coloring_page(

                category=category,

                subject=subject,

                output_folder=output_folder,

                filename=filename,

                age=age,

                complexity=complexity,

            )

        except Exception as exc:

            logger.exception(exc)

            raise RuntimeError(

                f"OpenAI generation failed: {exc}"

            ) from exc

    # --------------------------------------------------
    # QUICK TEST
    # --------------------------------------------------

    def test_connection(self) -> bool:
        """
        Performs a simple request to verify that
        the API key works.
        """

        try:

            self.client.models.list()

            logger.info(
                "OpenAI connection OK"
            )

            return True

        except Exception as exc:

            logger.exception(exc)

            return False

    # --------------------------------------------------
    # DEFAULT PROMPTS
    # --------------------------------------------------

    def generate_princess(

        self,

        subject: str,

        output_folder: Path,

        filename: str,

    ) -> Path:

        return self.generate_safe(

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

        return self.generate_safe(

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

        return self.generate_safe(

            category="Animals",

            subject=subject,

            output_folder=output_folder,

            filename=filename,

        )