"""
WayFinder 2.0 — Ask-Wayfinder QA Engine
Handles natural-language questions about the current scene.
Grounded in actual visual context, with safety fallbacks.
"""

import logging

from PIL import Image

from .scene_engine import scene_engine
from .schemas import QAResponse, SceneFacts

logger = logging.getLogger(__name__)

# Questions that should be answered from scene facts rather than re-running the model
_STRUCTURAL_QUESTIONS = {
    "what is in front", "what is ahead", "what do you see",
    "is it safe", "is the path clear", "any obstacles",
    "what is on the left", "what is on the right",
    "what should i avoid",
}


def answer_question(
    frames: list[Image.Image],
    question: str,
    recent_facts: SceneFacts | None = None,
) -> QAResponse:
    """
    Answer a user's question about the scene.

    Strategy:
    1. If we have recent SceneFacts and the question is structural,
       answer from facts (faster, grounded).
    2. Otherwise, run the scene engine in QA mode (slower, model-driven).
    """
    q_lower = question.lower().strip()

    # Try to answer from existing scene facts (grounded, fast)
    if recent_facts and _can_answer_from_facts(q_lower):
        answer = _answer_from_facts(q_lower, recent_facts)
        if answer:
            return QAResponse(
                question=question,
                answer=answer,
                grounded=True,
                confidence=recent_facts.confidence,
            )

    # Fall through to model-based QA
    try:
        raw_answer = scene_engine.answer_question(frames, question)

        # Safety: check if model output is too short or likely hallucinated
        if len(raw_answer.strip()) < 5:
            raw_answer = "I cannot clearly make out what you're asking about from this view."

        return QAResponse(
            question=question,
            answer=_clean_answer(raw_answer),
            grounded=True,
            confidence=0.7 if not scene_engine.is_mock else 0.5,
        )

    except Exception as e:
        logger.error(f"[QA] Inference failed: {e}")
        return QAResponse(
            question=question,
            answer="I'm having trouble analyzing the scene right now. Please try again.",
            grounded=False,
            confidence=0.0,
        )


def _can_answer_from_facts(question: str) -> bool:
    """Check if question can be answered from existing SceneFacts."""
    return any(kw in question for kw in _STRUCTURAL_QUESTIONS)


def _answer_from_facts(question: str, facts: SceneFacts) -> str | None:
    """Build an answer directly from SceneFacts without re-running the model."""

    # "What is in front / ahead?"
    if "front" in question or "ahead" in question or "see" in question:
        if not facts.objects:
            return "The area ahead appears clear. No obstacles detected."
        center_objects = [o for o in facts.objects if 0.25 < o.bbox.center_x / 1000 < 0.75]
        if center_objects:
            descs = [f"{o.label} {o.relative_position}" for o in center_objects[:3]]
            return "Ahead I can see: " + ", ".join(descs) + "."
        return facts.scene_description or "The path ahead seems mostly clear."

    # "Is it safe? / Is the path clear?"
    if "safe" in question or "clear" in question:
        obstacles = [o for o in facts.objects if o.is_obstacle]
        center_obstacles = [o for o in obstacles if 0.25 < o.bbox.center_x / 1000 < 0.75]
        if not center_obstacles:
            return "The path ahead appears clear for walking."
        close = [o for o in center_obstacles if o.bbox.center_y > 600]
        if close:
            return f"Caution. {close[0].label.capitalize()} detected ahead, close to you."
        return f"There is a {center_obstacles[0].label} ahead, but it's not immediately close."

    # "What is on the left / right?"
    if "left" in question:
        left_objs = [o for o in facts.objects if o.bbox.center_x / 1000 < 0.35]
        if not left_objs:
            return "I don't see anything notable on your left."
        descs = [f"{o.label}" for o in left_objs[:2]]
        return "To your left: " + ", ".join(descs) + "."

    if "right" in question:
        right_objs = [o for o in facts.objects if o.bbox.center_x / 1000 > 0.65]
        if not right_objs:
            return "I don't see anything notable on your right."
        descs = [f"{o.label}" for o in right_objs[:2]]
        return "To your right: " + ", ".join(descs) + "."

    # "Any obstacles? / What should I avoid?"
    if "obstacle" in question or "avoid" in question:
        obstacles = [o for o in facts.objects if o.is_obstacle]
        if not obstacles:
            return "No obstacles detected in the visible area."
        descs = [f"{o.label} {o.relative_position}" for o in obstacles[:3]]
        return "Watch out for: " + ", ".join(descs) + "."

    return None


def _clean_answer(text: str) -> str:
    """Clean model output for user-facing answer."""
    import re
    # Remove any structured format markers if model accidentally used them
    text = re.sub(r"(OBJECT|OBSTACLE|SCENE|FREE_PATH):\s*", "", text)
    # Remove tags
    text = re.sub(r"<[^>]+>", "", text)
    # Clean whitespace
    text = re.sub(r"\s+", " ", text).strip()
    # Ensure it ends with punctuation
    if text and text[-1] not in ".!?":
        text += "."
    return text
