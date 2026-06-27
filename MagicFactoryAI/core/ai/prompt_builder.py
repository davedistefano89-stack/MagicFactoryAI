"""Build optimized prompts for AI image generation."""

from __future__ import annotations


class PromptBuilder:
    """Creates high-quality prompts for coloring book generation."""

    @staticmethod
    def build(
        user_prompt: str,
        style: str = "",
    ) -> str:
        """
        Build the final prompt sent to the AI.
        """

        base_prompt = f"""
Create a professional black and white coloring book page.

Subject:
{user_prompt}

Style:
{style}

Requirements:

- Pure black outlines
- White background
- No grayscale
- No shadows
- No colors
- Thick clean lines
- Closed shapes
- High detail
- Child friendly
- Printable
- Centered composition
- No watermark
- No text
- No signature
- High resolution
- Suitable for coloring books
"""

        return base_prompt.strip()