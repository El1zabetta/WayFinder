"""
WayFinder 2.0 — Core Data Schemas
Structured types for the entire intelligence pipeline.
No business logic here — pure data definitions.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class AnalysisMode(str, Enum):
    """Two primary modes the system operates in."""
    NAVIGATION = "navigation"
    ASK = "ask"


@dataclass
class BBox:
    """Normalized bounding box in [0-1000] coordinate space."""
    x1: float
    y1: float
    x2: float
    y2: float

    @property
    def center_x(self) -> float:
        return (self.x1 + self.x2) / 2

    @property
    def center_y(self) -> float:
        return (self.y1 + self.y2) / 2

    @property
    def width(self) -> float:
        return abs(self.x2 - self.x1)

    @property
    def height(self) -> float:
        return abs(self.y2 - self.y1)

    @property
    def area(self) -> float:
        return self.width * self.height

    def to_azimuth(self, fov_deg: float = 90.0) -> float:
        """Horizontal center → azimuth angle for spatial audio."""
        return (self.center_x / 1000.0 - 0.5) * fov_deg

    def to_elevation(self, fov_v_deg: float = 60.0) -> float:
        return (0.5 - self.center_y / 1000.0) * fov_v_deg

    def to_relative_position(self) -> str:
        """Convert bbox center to human-readable relative position."""
        cx = self.center_x / 1000.0  # 0.0 = left edge, 1.0 = right edge
        cy = self.center_y / 1000.0  # 0.0 = top, 1.0 = bottom

        # Horizontal
        if cx < 0.3:
            h = "to your left"
        elif cx < 0.45:
            h = "slightly left"
        elif cx <= 0.55:
            h = "ahead"
        elif cx <= 0.7:
            h = "slightly right"
        else:
            h = "to your right"

        # Vertical (proxy for distance — lower in frame = closer)
        if cy > 0.75:
            v = "very close"
        elif cy > 0.55:
            v = "a short distance"
        elif cy > 0.35:
            v = ""  # mid-range, don't add qualifier
        else:
            v = "farther away"

        if v:
            return f"{v}, {h}"
        return h

    def to_dict(self) -> dict:
        return {
            "x1": self.x1, "y1": self.y1,
            "x2": self.x2, "y2": self.y2,
            "azimuth": round(self.to_azimuth(), 2),
            "elevation": round(self.to_elevation(), 2),
        }


@dataclass
class DetectedObject:
    """A single object detected in the scene."""
    label: str
    bbox: BBox
    is_obstacle: bool = False
    is_on_floor: bool = False

    @property
    def relative_position(self) -> str:
        return self.bbox.to_relative_position()

    def to_dict(self) -> dict:
        return {
            "label": self.label,
            "bbox": self.bbox.to_dict(),
            "is_obstacle": self.is_obstacle,
            "relative_position": self.relative_position,
        }


class ThreatSeverity(str, Enum):
    NONE = "none"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass
class ThreatAssessment:
    """Risk assessment for a single detected object."""
    object: DetectedObject
    severity: ThreatSeverity
    reason: str  # e.g. "obstacle directly ahead at close range"

    def to_dict(self) -> dict:
        return {
            "label": self.object.label,
            "severity": self.severity.value,
            "reason": self.reason,
            "bbox": self.object.bbox.to_dict(),
            "relative_position": self.object.relative_position,
        }


@dataclass
class SceneFacts:
    """
    Structured output from Scene Understanding.
    This is the central data type that flows through the entire pipeline.
    """
    raw_model_output: str
    objects: list[DetectedObject] = field(default_factory=list)
    scene_description: str = ""
    free_path_direction: Optional[str] = None  # "left", "right", "ahead", None
    confidence: float = 0.0
    timestamp: float = field(default_factory=time.time)

    @property
    def has_obstacles(self) -> bool:
        return any(o.is_obstacle for o in self.objects)

    @property
    def obstacle_count(self) -> int:
        return sum(1 for o in self.objects if o.is_obstacle)


@dataclass
class NavigationGuidance:
    """Final navigation output sent to the user."""
    primary_instruction: str  # "Move slightly right."
    scene_summary: str        # "Chair on the left. Path clear ahead."
    alert_level: str          # "LOW" / "MEDIUM" / "HIGH" / "CRITICAL"
    threats: list[ThreatAssessment] = field(default_factory=list)
    audio_cues: list[dict] = field(default_factory=list)
    confidence: float = 0.0

    def to_api_response(self) -> dict:
        return {
            "primary_instruction": self.primary_instruction,
            "scene_summary": self.scene_summary,
            "alert_level": self.alert_level,
            "threats": [t.to_dict() for t in self.threats],
            "audio_cues": self.audio_cues,
            "confidence": self.confidence,
        }


@dataclass
class QAResponse:
    """Response to an Ask-Wayfinder question."""
    question: str
    answer: str
    grounded: bool  # True if answer is based on scene facts, not hallucinated
    confidence: float = 0.0

    def to_api_response(self) -> dict:
        return {
            "question": self.question,
            "answer": self.answer,
            "grounded": self.grounded,
            "confidence": self.confidence,
        }
