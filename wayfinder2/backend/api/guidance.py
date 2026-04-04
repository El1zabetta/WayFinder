"""
WayFinder 2.0 — Navigation Guidance Generator
Converts SceneFacts + ThreatAssessments into short, actionable guidance text.
Deterministic, template-based. Minimizes cognitive load.
"""

from .schemas import (
    DetectedObject, NavigationGuidance, SceneFacts, ThreatAssessment, ThreatSeverity,
)
from . import threat_engine


def generate_guidance(facts: SceneFacts) -> NavigationGuidance:
    """
    Full guidance pipeline:
    SceneFacts → threats → instruction + summary + audio cues.
    """
    threats = threat_engine.assess_threats(facts)
    alert_level = threat_engine.compute_alert_level(threats)

    instruction = _build_instruction(facts, threats)
    summary = _build_summary(facts, threats)
    audio_cues = _build_audio_cues(facts, threats)

    return NavigationGuidance(
        primary_instruction=instruction,
        scene_summary=summary,
        alert_level=alert_level,
        threats=threats,
        audio_cues=audio_cues,
        confidence=facts.confidence,
    )


def _build_instruction(facts: SceneFacts, threats: list[ThreatAssessment]) -> str:
    """
    Generate the single most important instruction.
    This is what gets spoken first — must be short and safe.
    """
    # Critical/high threats take absolute priority
    critical = [t for t in threats if t.severity in (ThreatSeverity.CRITICAL, ThreatSeverity.HIGH)]
    if critical:
        top = critical[0]
        obj = top.object
        pos = obj.relative_position

        if top.severity == ThreatSeverity.CRITICAL:
            return f"Stop. {obj.label.capitalize()} {pos}."

        # High severity: warn + suggest direction
        avoid_dir = _suggest_avoidance(obj, facts)
        if avoid_dir:
            return f"Caution. {obj.label.capitalize()} {pos}. {avoid_dir}"
        return f"Caution. {obj.label.capitalize()} {pos}."

    # Medium threats: gentle guidance
    medium = [t for t in threats if t.severity == ThreatSeverity.MEDIUM]
    if medium:
        top = medium[0]
        pos = top.object.relative_position
        return f"{top.object.label.capitalize()} {pos}. Move carefully."

    # No significant threats — use free path
    if facts.free_path_direction:
        direction = facts.free_path_direction.replace("_", " ")
        if direction == "ahead":
            return "Path clear. Move forward."
        elif direction == "none":
            return "No clear path detected. Please stop and reassess."
        else:
            return f"Move {direction}."

    # Fallback — low confidence
    if facts.confidence < 0.5:
        return "Scene unclear. Proceed with caution."

    return "Move forward carefully."


def _build_summary(facts: SceneFacts, threats: list[ThreatAssessment]) -> str:
    """
    Build a concise scene summary. 2–3 sentences max.
    Lists key objects with positions.
    """
    if facts.scene_description and facts.scene_description != "Scene analyzed.":
        return facts.scene_description

    parts = []
    for obj in facts.objects[:3]:  # Max 3 objects in summary
        parts.append(f"{obj.label.capitalize()} {obj.relative_position}.")

    if not parts:
        return "No notable objects detected."

    return " ".join(parts)


def _suggest_avoidance(obj: DetectedObject, facts: SceneFacts) -> str:
    """Suggest which direction to move to avoid an obstacle."""
    cx = obj.bbox.center_x / 1000.0

    # Use free_path_direction if available
    if facts.free_path_direction and facts.free_path_direction != "none":
        direction = facts.free_path_direction.replace("_", " ")
        return f"Move {direction}."

    # Otherwise infer from obstacle position
    if cx < 0.4:
        return "Move slightly right."
    elif cx > 0.6:
        return "Move slightly left."
    else:
        # Obstacle is centered — harder call
        return "Step to the side."


def _build_audio_cues(facts: SceneFacts, threats: list[ThreatAssessment]) -> list[dict]:
    """
    Generate spatial audio cues for the mobile app.
    Each cue has: message, azimuth, priority.
    """
    cues = []

    # Threat cues (highest priority)
    for threat in threats[:3]:
        if threat.severity in (ThreatSeverity.NONE,):
            continue
        obj = threat.object
        azimuth = obj.bbox.to_azimuth()
        priority = {
            ThreatSeverity.CRITICAL: "CRITICAL",
            ThreatSeverity.HIGH: "HIGH",
            ThreatSeverity.MEDIUM: "MEDIUM",
            ThreatSeverity.LOW: "LOW",
        }.get(threat.severity, "LOW")

        cues.append({
            "message": f"{obj.label} {obj.relative_position}",
            "azimuth": round(azimuth, 2),
            "elevation": round(obj.bbox.to_elevation(), 2),
            "priority": priority,
            "type": "THREAT",
        })

    # Free path cue
    if facts.free_path_direction and facts.free_path_direction != "none":
        dir_to_azimuth = {
            "left": -45.0, "slightly_left": -22.0,
            "ahead": 0.0,
            "slightly_right": 22.0, "right": 45.0,
        }
        az = dir_to_azimuth.get(facts.free_path_direction, 0.0)
        cues.append({
            "message": "Safe path",
            "azimuth": az,
            "elevation": 0.0,
            "priority": "LOW",
            "type": "NAV",
        })

    return cues
