"""
WayFinder 2.0 — Short-Term Scene Memory
Stores recent SceneFacts to reduce flicker and provide context.
Thread-safe single-writer, multiple-reader buffer.
"""

import threading
import time
from collections import deque
from typing import Optional

from .schemas import SceneFacts, DetectedObject


class SceneMemory:
    """
    Rolling buffer of recent scene analyses.
    Used for:
    - Providing recent context to QA engine
    - Stabilizing navigation guidance across frames
    - Tracking persistent objects across short time windows
    """

    _instance: Optional["SceneMemory"] = None
    _lock = threading.Lock()

    def __new__(cls) -> "SceneMemory":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self, max_entries: int = 10, ttl_seconds: float = 30.0):
        if self._initialized:
            return
        self._entries: deque[SceneFacts] = deque(maxlen=max_entries)
        self._ttl = ttl_seconds
        self._initialized = True

    def store(self, facts: SceneFacts) -> None:
        """Add a new SceneFacts snapshot."""
        with self._lock:
            self._entries.append(facts)

    def get_latest(self) -> Optional[SceneFacts]:
        """Return the most recent SceneFacts, or None if empty/stale."""
        self._prune()
        with self._lock:
            if self._entries:
                return self._entries[-1]
        return None

    def get_recent(self, n: int = 3) -> list[SceneFacts]:
        """Return up to N most recent valid SceneFacts."""
        self._prune()
        with self._lock:
            return list(self._entries)[-n:]

    def get_persistent_objects(self) -> list[DetectedObject]:
        """
        Return objects seen in 2+ of the last 5 analyses.
        These are more likely to be real (not noise / hallucination).
        """
        recent = self.get_recent(5)
        if len(recent) < 2:
            return self.get_latest().objects if self.get_latest() else []

        # Count label occurrences
        label_counts: dict[str, list[DetectedObject]] = {}
        for facts in recent:
            for obj in facts.objects:
                key = obj.label.lower()
                if key not in label_counts:
                    label_counts[key] = []
                label_counts[key].append(obj)

        # Objects seen 2+ times are "persistent"
        persistent = []
        for label, instances in label_counts.items():
            if len(instances) >= 2:
                # Use the most recent instance
                persistent.append(instances[-1])

        return persistent

    def get_context_summary(self) -> str:
        """
        Build a short text summary of recent scene context.
        Used for injecting into RynnBrain prompts.
        """
        latest = self.get_latest()
        if not latest:
            return ""

        persistent = self.get_persistent_objects()
        if not persistent:
            return ""

        lines = ["[Recent scene context]"]
        for obj in persistent[:5]:
            lines.append(f"- {obj.label} {obj.relative_position}")
        return "\n".join(lines) + "\n"

    def _prune(self) -> None:
        """Remove entries older than TTL."""
        now = time.time()
        with self._lock:
            while self._entries and (now - self._entries[0].timestamp) > self._ttl:
                self._entries.popleft()

    def clear(self) -> None:
        """Reset memory."""
        with self._lock:
            self._entries.clear()


# Module-level singleton
scene_memory = SceneMemory()
