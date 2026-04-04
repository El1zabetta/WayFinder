"""
WayFinder 2.0 — Threat & Risk Engine
Deterministic hazard analysis from SceneFacts.
No model calls — pure logic and rules.
"""

from .schemas import (
    DetectedObject, SceneFacts, ThreatAssessment, ThreatSeverity, BBox,
)


# Objects that are universally dangerous for blind navigation
_HIGH_RISK_LABELS = {
    "stairs", "staircase", "step", "curb", "hole", "manhole",
    "construction", "vehicle", "car", "motorcycle", "bicycle",
    "scooter", "ladder", "open door",
}

_MEDIUM_RISK_LABELS = {
    "cable", "wire", "cord", "wet floor", "puddle", "rug",
    "mat", "pet", "dog", "cat", "stroller", "cart",
}


def assess_threats(facts: SceneFacts) -> list[ThreatAssessment]:
    """
    Analyze SceneFacts and produce a ranked list of threats.
    Pure deterministic logic — no ML involved.
    """
    threats: list[ThreatAssessment] = []

    for obj in facts.objects:
        if not obj.is_obstacle:
            continue

        severity, reason = _score_object(obj)
        if severity != ThreatSeverity.NONE:
            threats.append(ThreatAssessment(
                object=obj, severity=severity, reason=reason,
            ))

    # Sort: CRITICAL first, then HIGH, etc. Within same severity, closer = first.
    severity_order = {
        ThreatSeverity.CRITICAL: 4,
        ThreatSeverity.HIGH: 3,
        ThreatSeverity.MEDIUM: 2,
        ThreatSeverity.LOW: 1,
        ThreatSeverity.NONE: 0,
    }
    threats.sort(key=lambda t: (
        -severity_order[t.severity],
        -t.object.bbox.center_y,  # lower in frame = closer = more urgent
    ))

    return threats


def compute_alert_level(threats: list[ThreatAssessment]) -> str:
    """Determine overall alert level from threat list."""
    if not threats:
        return "LOW"

    max_severity = max(threats, key=lambda t: {
        ThreatSeverity.CRITICAL: 4, ThreatSeverity.HIGH: 3,
        ThreatSeverity.MEDIUM: 2, ThreatSeverity.LOW: 1,
        ThreatSeverity.NONE: 0,
    }[t.severity])

    return {
        ThreatSeverity.CRITICAL: "CRITICAL",
        ThreatSeverity.HIGH: "HIGH",
        ThreatSeverity.MEDIUM: "MEDIUM",
        ThreatSeverity.LOW: "LOW",
        ThreatSeverity.NONE: "LOW",
    }[max_severity.severity]


def _score_object(obj: DetectedObject) -> tuple[ThreatSeverity, str]:
    """
    Score a single obstacle's threat level based on:
    1. What it is (label)
    2. Where it is (position relative to walking path)
    3. How close it is (vertical position in frame)
    """
    label = obj.label.lower()
    bbox = obj.bbox
    cx = bbox.center_x / 1000.0  # 0.0=left, 1.0=right
    cy = bbox.center_y / 1000.0  # 0.0=top, 1.0=bottom (closer)

    # Position analysis
    is_center = 0.25 < cx < 0.75          # In the walking path
    is_close = cy > 0.6                    # Lower half = close
    is_very_close = cy > 0.8              # Bottom of frame = immediate
    is_on_floor = obj.is_on_floor or cy > 0.7

    # ── Scoring Rules ────────────────────────────────────────────────

    # High-risk objects directly ahead and close
    if label in _HIGH_RISK_LABELS:
        if is_center and is_very_close:
            return ThreatSeverity.CRITICAL, f"{label} directly ahead, very close"
        if is_center and is_close:
            return ThreatSeverity.HIGH, f"{label} ahead, approaching"
        if is_center:
            return ThreatSeverity.MEDIUM, f"{label} ahead"
        return ThreatSeverity.LOW, f"{label} to the side"

    # Floor-level obstacles in path
    if is_on_floor and is_center:
        if is_very_close:
            return ThreatSeverity.HIGH, f"low {label} on floor directly ahead"
        if is_close:
            return ThreatSeverity.MEDIUM, f"{label} on the floor ahead"
        return ThreatSeverity.LOW, f"{label} on the floor"

    # Medium-risk objects
    if label in _MEDIUM_RISK_LABELS:
        if is_center and is_close:
            return ThreatSeverity.MEDIUM, f"{label} in your path"
        return ThreatSeverity.LOW, f"{label} nearby"

    # General obstacles
    if is_center and is_very_close:
        return ThreatSeverity.HIGH, f"obstacle ({label}) directly ahead, very close"
    if is_center and is_close:
        return ThreatSeverity.MEDIUM, f"{label} ahead"
    if is_center:
        return ThreatSeverity.LOW, f"{label} ahead"

    # Not in direct path
    if is_close:
        return ThreatSeverity.LOW, f"{label} to the side, close"

    return ThreatSeverity.NONE, ""
