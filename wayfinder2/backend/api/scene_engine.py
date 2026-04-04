"""
WayFinder 2.0 — Scene Understanding Engine
Wraps RynnBrain-2B for structured scene analysis.
Single responsibility: frames in → SceneFacts out.
"""

import logging
import re
import threading
import time
from typing import Optional

import torch
from PIL import Image

from .prompts import NAVIGATION_SYSTEM_PROMPT, ASK_SYSTEM_PROMPT, THREAT_ANALYSIS_PROMPT
from .schemas import BBox, DetectedObject, SceneFacts

logger = logging.getLogger(__name__)

# Labels commonly found on floors / walkable hazards
_FLOOR_OBJECTS = {
    "cable", "wire", "cord", "rug", "mat", "shoe", "bag", "box",
    "bottle", "ball", "toy", "step", "curb", "hole", "puddle",
    "manhole", "crack", "threshold",
}

_OBSTACLE_LABELS = {
    "chair", "table", "desk", "stool", "bench", "trash", "bin",
    "bollard", "cone", "pole", "post", "barrier", "fence", "wall",
    "bicycle", "scooter", "stroller", "cart", "ladder", "bucket",
    "box", "crate", "luggage", "suitcase", "bag", "backpack",
    "vehicle", "car", "motorcycle", "cabinet", "shelf", "rack",
    *_FLOOR_OBJECTS,
}


class SceneEngine:
    """
    Singleton engine for RynnBrain-2B scene understanding.
    Handles model loading, prompt construction, inference, and output parsing.
    Does NOT contain business logic — only model interaction.
    """

    _instance: Optional["SceneEngine"] = None
    _lock = threading.Lock()

    def __new__(cls) -> "SceneEngine":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
                    cls._instance._use_mock = False
        return cls._instance

    def initialize(self, model_path: str) -> None:
        """Load RynnBrain-2B model. Called once lazily."""
        if self._initialized:
            return

        with self._lock:
            if self._initialized:
                return

            if not torch.cuda.is_available():
                logger.warning("[SceneEngine] No GPU. Running in mock mode.")
                self._use_mock = True
                self._initialized = True
                return

            try:
                logger.info(f"[SceneEngine] Loading model: {model_path}")
                from transformers import AutoModelForImageTextToText, AutoProcessor

                self._processor = AutoProcessor.from_pretrained(
                    model_path, trust_remote_code=True,
                )
                # Try flash_attention_2 first (faster), fall back to default
                try:
                    self._model = AutoModelForImageTextToText.from_pretrained(
                        model_path,
                        torch_dtype=torch.bfloat16,
                        device_map="auto",
                        trust_remote_code=True,
                        attn_implementation="flash_attention_2",
                    )
                    logger.info("[SceneEngine] Using Flash Attention 2 ✓")
                except Exception:
                    logger.info("[SceneEngine] Flash Attention 2 not available, using default.")
                    self._model = AutoModelForImageTextToText.from_pretrained(
                        model_path,
                        torch_dtype=torch.bfloat16,
                        device_map="auto",
                        trust_remote_code=True,
                    )
                self._model.eval()
                self._initialized = True
                logger.info("[SceneEngine] Model loaded on GPU ✓")

            except Exception as e:
                logger.error(f"[SceneEngine] Model load failed: {e}")
                self._use_mock = True
                self._initialized = True
                logger.warning("[SceneEngine] Falling back to mock mode.")

    @property
    def is_ready(self) -> bool:
        return self._initialized

    @property
    def is_mock(self) -> bool:
        return self._use_mock

    # ─── Primary Interface ───────────────────────────────────────────────

    def analyze_scene(self, frames: list[Image.Image]) -> SceneFacts:
        """Navigation mode: understand the scene for safe walking."""
        return self._run_inference(frames, NAVIGATION_SYSTEM_PROMPT, "Describe the scene for safe navigation.")

    def analyze_threats(self, frames: list[Image.Image]) -> SceneFacts:
        """Deep safety analysis of the scene."""
        return self._run_inference(frames, THREAT_ANALYSIS_PROMPT, "Identify all hazards in this scene.")

    def answer_question(self, frames: list[Image.Image], question: str) -> str:
        """Ask-Wayfinder: answer a user question about the scene."""
        facts = self._run_inference(frames, ASK_SYSTEM_PROMPT, question)
        # For QA, we return the raw text since the model output IS the answer
        return facts.raw_model_output

    # ─── Core Inference ──────────────────────────────────────────────────

    @torch.inference_mode()
    def _run_inference(
        self,
        frames: list[Image.Image],
        system_prompt: str,
        query: str,
        max_new_tokens: int = 300,
    ) -> SceneFacts:
        if not self._initialized:
            raise RuntimeError("SceneEngine not initialized.")

        if self._use_mock:
            return self._mock_inference(frames, system_prompt, query)

        # Build conversation
        content = [{"type": "text", "text": system_prompt + "\n\n"}]
        for idx, frame in enumerate(frames):
            if idx > 0:
                content.append({"type": "text", "text": f"\n[Frame {idx}]:"})
            content.append({"type": "image", "image": frame})
        content.append({"type": "text", "text": f"\n{query}"})

        conversation = [{"role": "user", "content": content}]
        inputs = self._processor.apply_chat_template(
            conversation,
            add_generation_prompt=True,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
        ).to(self._model.device)

        output_ids = self._model.generate(
            **inputs, do_sample=False, max_new_tokens=max_new_tokens,
        )

        input_len = inputs["input_ids"].size(1)
        raw_text = self._processor.decode(
            output_ids[0, input_len:], skip_special_tokens=True
        )

        logger.info(f"[SceneEngine] Raw output ({len(raw_text)} chars): {raw_text[:200]}")
        return self._parse_structured_output(raw_text)

    # ─── Output Parser ───────────────────────────────────────────────────

    def _parse_structured_output(self, raw_text: str) -> SceneFacts:
        """Parse RynnBrain output into structured SceneFacts."""
        objects: list[DetectedObject] = []
        scene_desc = ""
        free_path = None

        for line in raw_text.split("\n"):
            line = line.strip()

            # Parse OBJECT: label at x1,y1,x2,y2
            obj_match = re.match(
                r"(?:OBJECT|OBSTACLE):\s*(.+?)\s+at\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)",
                line, re.IGNORECASE
            )
            if obj_match:
                label = obj_match.group(1).strip().lower()
                bbox = BBox(
                    x1=float(obj_match.group(2)),
                    y1=float(obj_match.group(3)),
                    x2=float(obj_match.group(4)),
                    y2=float(obj_match.group(5)),
                )
                is_obstacle = line.upper().startswith("OBSTACLE") or label in _OBSTACLE_LABELS
                is_on_floor = label in _FLOOR_OBJECTS or bbox.center_y > 700
                objects.append(DetectedObject(
                    label=label, bbox=bbox,
                    is_obstacle=is_obstacle, is_on_floor=is_on_floor,
                ))
                continue

            # Parse SCENE: description
            scene_match = re.match(r"SCENE:\s*(.+)", line, re.IGNORECASE)
            if scene_match:
                scene_desc = scene_match.group(1).strip()
                continue

            # Parse FREE_PATH: direction
            path_match = re.match(r"FREE_PATH:\s*(\w+)", line, re.IGNORECASE)
            if path_match:
                free_path = path_match.group(1).strip().lower()
                continue

        # Fallback: if model didn't use structured format, try <object> tags
        if not objects:
            objects = self._parse_legacy_tags(raw_text)

        # If no scene description, use the first clean sentence
        if not scene_desc:
            for sentence in raw_text.split("."):
                clean = sentence.strip()
                if len(clean) > 10 and "<" not in clean and "OBJECT" not in clean.upper():
                    scene_desc = clean + "."
                    break

        confidence = self._compute_confidence(raw_text, objects)

        return SceneFacts(
            raw_model_output=raw_text,
            objects=objects,
            scene_description=scene_desc or "Scene analyzed.",
            free_path_direction=free_path,
            confidence=confidence,
        )

    def _parse_legacy_tags(self, text: str) -> list[DetectedObject]:
        """Fallback parser for <object>x1,y1,x2,y2</object> format."""
        objects = []
        pattern = r"<object>(.*?)</object>"
        for match in re.finditer(pattern, text, re.IGNORECASE):
            content = match.group(1).strip()
            nums = re.findall(r"-?\d+(?:\.\d+)?", content)
            if len(nums) >= 4:
                bbox = BBox(float(nums[0]), float(nums[1]), float(nums[2]), float(nums[3]))
                # Try to extract label from surrounding text
                label_ctx = text[max(0, match.start() - 40):match.start()]
                label_match = re.search(r"(\w+)\s*$", label_ctx)
                label = label_match.group(1).lower() if label_match else "obstacle"
                objects.append(DetectedObject(
                    label=label, bbox=bbox,
                    is_obstacle=label in _OBSTACLE_LABELS,
                    is_on_floor=label in _FLOOR_OBJECTS or bbox.center_y > 700,
                ))
        return objects

    def _compute_confidence(self, raw_text: str, objects: list[DetectedObject]) -> float:
        """Heuristic confidence: more structure = higher confidence."""
        score = 0.4
        if objects:
            score += min(len(objects) * 0.1, 0.3)
        if "SCENE:" in raw_text.upper():
            score += 0.1
        if "FREE_PATH:" in raw_text.upper():
            score += 0.1
        if len(raw_text) > 50:
            score += 0.1
        return round(min(score, 1.0), 3)

    # ─── Mock Inference ──────────────────────────────────────────────────

    def _mock_inference(
        self, frames: list[Image.Image], system_prompt: str, query: str
    ) -> SceneFacts:
        """
        Mock mode: generates varied but plausible scene analysis.
        Uses frame properties (brightness, color) to create
        non-static responses.
        """
        import random
        import numpy as np

        # Use frame properties to seed variation
        if frames:
            arr = np.array(frames[0])
            brightness = arr.mean()
            # Use brightness to decide indoor/outdoor and scene character
            seed = int(brightness * 100) % 7
        else:
            seed = random.randint(0, 6)

        # If this is a QA question, return a direct answer
        if "ASK" in system_prompt.upper() or "?" in query:
            return self._mock_qa(query, seed)

        # Navigation / threat analysis mock
        mock_scenes = [
            {
                "objects": [
                    DetectedObject("chair", BBox(100, 350, 280, 650), is_obstacle=True),
                    DetectedObject("table", BBox(600, 200, 850, 500), is_obstacle=True),
                ],
                "scene": "Indoor room with furniture. Chair on the left, table on the right.",
                "free_path": "ahead",
            },
            {
                "objects": [
                    DetectedObject("backpack", BBox(350, 500, 550, 750), is_obstacle=True, is_on_floor=True),
                ],
                "scene": "Backpack on the floor ahead. Otherwise clear indoor space.",
                "free_path": "slightly_right",
            },
            {
                "objects": [
                    DetectedObject("door", BBox(300, 50, 650, 800), is_obstacle=False),
                ],
                "scene": "Open doorway ahead leading to another room.",
                "free_path": "ahead",
            },
            {
                "objects": [
                    DetectedObject("wall", BBox(0, 0, 150, 1000), is_obstacle=True),
                    DetectedObject("cable", BBox(400, 700, 600, 800), is_obstacle=True, is_on_floor=True),
                ],
                "scene": "Wall on the left. Cable on the floor ahead.",
                "free_path": "slightly_right",
            },
            {
                "objects": [
                    DetectedObject("stairs", BBox(200, 400, 800, 900), is_obstacle=True),
                ],
                "scene": "Stairs ahead going down. Caution required.",
                "free_path": "none",
            },
            {
                "objects": [],
                "scene": "Open clear space ahead. No obstacles detected.",
                "free_path": "ahead",
            },
            {
                "objects": [
                    DetectedObject("person", BBox(400, 200, 600, 700), is_obstacle=True),
                    DetectedObject("bench", BBox(50, 400, 250, 650), is_obstacle=True),
                ],
                "scene": "Person walking ahead. Bench on the left side.",
                "free_path": "slightly_right",
            },
        ]

        scene = mock_scenes[seed % len(mock_scenes)]

        # Build raw text in structured format
        lines = []
        for obj in scene["objects"]:
            prefix = "OBSTACLE" if obj.is_obstacle else "OBJECT"
            b = obj.bbox
            lines.append(f"{prefix}: {obj.label} at {int(b.x1)},{int(b.y1)},{int(b.x2)},{int(b.y2)}")
        lines.append(f"SCENE: {scene['scene']}")
        lines.append(f"FREE_PATH: {scene['free_path']}")
        raw_text = "\n".join(lines)

        return SceneFacts(
            raw_model_output=raw_text,
            objects=scene["objects"],
            scene_description=scene["scene"],
            free_path_direction=scene["free_path"],
            confidence=0.75,
        )

    def _mock_qa(self, question: str, seed: int) -> SceneFacts:
        """Mock QA: varied answers based on question keywords."""
        q = question.lower()
        if "front" in q or "ahead" in q:
            answer = "There appears to be a clear path ahead with some furniture on the sides."
        elif "left" in q:
            answer = "To your left, I can see a wall and possibly a chair."
        elif "right" in q:
            answer = "To your right, the space looks relatively clear."
        elif "door" in q:
            answer = "I can see what looks like a doorway slightly to the left."
        elif "safe" in q or "clear" in q or "path" in q:
            answer = "The path ahead seems mostly clear. Move forward with caution."
        elif "floor" in q or "ground" in q:
            answer = "The floor ahead appears clear. No obvious obstacles on the ground."
        elif "danger" in q or "hazard" in q or "avoid" in q:
            answer = "I don't see any immediate hazards, but there are objects on the sides."
        else:
            answer = "I can see an indoor space with some objects around. The area ahead is mostly clear."

        return SceneFacts(
            raw_model_output=answer,
            objects=[],
            scene_description=answer,
            confidence=0.6,
        )


# Module-level singleton
scene_engine = SceneEngine()
