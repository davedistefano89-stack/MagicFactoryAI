"""Retry manager for failed generation tasks."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class RetryPolicy:
    """
    Defines how retries should be handled.
    """

    max_retries: int = 3

    def can_retry(self, current_retry: int) -> bool:
        """
        Returns True if another retry is allowed.
        """
        return current_retry < self.max_retries


class RetryManager:
    """
    Handles retry logic for generation tasks.
    """

    def __init__(
        self,
        max_retries: int = 3,
    ) -> None:

        self._policy = RetryPolicy(
            max_retries=max_retries,
        )

    @property
    def max_retries(self) -> int:
        return self._policy.max_retries

    def can_retry(
        self,
        retries: int,
    ) -> bool:
        """
        Check whether another retry is allowed.
        """
        return self._policy.can_retry(
            retries,
        )

    def next_retry(
        self,
        retries: int,
    ) -> int:
        """
        Returns the next retry number.
        """
        if self.can_retry(retries):
            return retries + 1

        return retries

    def reset(self) -> int:
        """
        Reset retry counter.
        """
        return 0