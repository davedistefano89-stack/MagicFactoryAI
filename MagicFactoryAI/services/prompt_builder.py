"""
Prompt Builder

Transforms a simple user idea into a professional prompt
for GPT Image generation.
"""

from __future__ import annotations


class PromptBuilder:

    BASE_STYLE = """
Create a children's coloring book illustration.

Rules:

- black outlines only
- pure white background
- no shadows
- no grayscale
- no colors
- thick outlines
- centered composition
- large coloring areas
- simple shapes
- suitable for children age 3-6
- no text
- no watermark
- full body character
"""

    def build(
        self,
        category: str,
        subject: str,
        age: str = "3-6",
        complexity: str = "simple",
    ) -> str:

        prompt = f"""
Category:
{category}

Subject:
{subject}

Target age:
{age}

Complexity:
{complexity}

{self.BASE_STYLE}

Return ONE single illustration.
"""

        return prompt.strip()
    def build_princess_prompt(
        self,
        subject: str,
    ) -> str:

        return self.build(
            category="Princess",
            subject=subject,
        )

    def build_unicorn_prompt(
        self,
        subject: str,
    ) -> str:

        return self.build(
            category="Unicorn",
            subject=subject,
        )

    def build_animal_prompt(
        self,
        subject: str,
    ) -> str:

        return self.build(
            category="Animals",
            subject=subject,
        )

    def build_vehicle_prompt(
        self,
        subject: str,
    ) -> str:

        return self.build(
            category="Vehicles",
            subject=subject,
        )

    def build_dinosaur_prompt(
        self,
        subject: str,
    ) -> str:

        return self.build(
            category="Dinosaurs",
            subject=subject,
        )

    def build_space_prompt(
        self,
        subject: str,
    ) -> str:

        return self.build(
            category="Space",
            subject=subject,
        )

    def build_mermaid_prompt(
        self,
        subject: str,
    ) -> str:

        return self.build(
            category="Mermaids",
            subject=subject,
        )

    def build_random_prompt(
        self,
        category: str,
        subjects: list[str],
    ) -> str:

        import random

        return self.build(
            category=category,
            subject=random.choice(subjects),
        )
        