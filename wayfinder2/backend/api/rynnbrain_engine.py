"""
WayFinder 2.0 — RynnBrain 2B Engine
Core AI inference module using the RynnBrain-2B model (Qwen3-VL-2B-Instruct based).

Supports three specialized modes:
  - RynnBrain-Nav: Vision-language navigation (route planning through physical objects)
  - RynnBrain-CoP: Chain-of-Point reasoning (spatial threat analysis, trajectory prediction)
  - RynnBrain-Plan: Task planning (object search, free space detection)
"""

import logging
import re
import threading
from dataclasses import dataclass
from enum import Enum
from typing import Optional

import numpy as np
import torch
from PIL import Image

logger = logging.getLogger(__name__)


class InferenceMode(str, Enum):
    """RynnBrain specialized inference modes."""
    NAV = "nav"      # RynnBrain-Nav: navigation, route through obstacles
    COP = "cop"      # RynnBrain-CoP: chain-of-point, threat & trajectory analysis
    PLAN = "plan"    # RynnBrain-Plan: object search, free space, affordance
    BASE = "base"    # Base egocentric understanding (general QA)


@dataclass
class SpatialCoordinate:
    """Normalized spatial coordinate [0–1000] as used by RynnBrain's grounding format."""
    x: float
    y: float

    def to_audio_angle(self, fov_deg: float = 90.0) -> float:
        """
        Converts horizontal position → azimuth angle for 3D spatial audio.
        center=0°, left=-45°, right=+45° (for 90° FOV camera).
        """
        return (self.x / 1000.0 - 0.5) * fov_deg

    def to_elevation_angle(self, fov_v_deg: float = 60.0) -> float:
        """Converts vertical position → elevation angle."""
        return (0.5 - self.y / 1000.0) * fov_v_deg


@dataclass
class RynnBrainResponse:
    """Structured response from RynnBrain 2B."""
    mode: InferenceMode
    raw_text: str
    spatial_points: list[SpatialCoordinate]
    navigation_action: Optional[str]  # ←, →, ↑, STOP, etc.
    threats: list[dict]               # detected danger objects w/ locations
    audio_cues: list[dict]            # 3D audio guidance cues
    confidence: float


# ─── System Prompts per mode ────────────────────────────────────────────────
_SYSTEM_PROMPTS = {
    InferenceMode.BASE: (
        "You are WayFinder's vision assistant. Analyze the egocentric video and "
        "answer questions about the physical scene. Be concise and accurate."
    ),
    InferenceMode.NAV: (
        "You are RynnBrain-Nav, an embodied navigation assistant for visually impaired users. "
        "Analyze the egocentric video and provide safe navigation instructions. "
        "Identify walkable paths, obstacles, and physical affordances. "
        "Output navigation actions using: MOVE FORWARD (↑), TURN LEFT (←), TURN RIGHT (→), STOP. "
        "Describe obstacles with their spatial coordinates as <area> x,y </area> tags."
    ),
    InferenceMode.COP: (
        "You are RynnBrain-CoP (Chain-of-Point), a physical-space reasoning assistant. "
        "Analyze egocentric video to detect potential hazards and predict trajectories. "
        "Use interleaved textual and spatial reasoning. "
        "Mark dangerous objects with <object> x1,y1,x2,y2 </object> tags. "
        "Predict motion trajectories with <trajectory> x1,y1,...,xn,yn </trajectory> tags. "
        "Always ground your reasoning in physical coordinates."
    ),
    InferenceMode.PLAN: (
        "You are RynnBrain-Plan, a task planning and object search assistant. "
        "Analyze egocentric video to find objects, free spaces, and doorways. "
        "Locate items with <object> x1,y1,x2,y2 </object> for bounding boxes. "
        "Mark areas with <area> x1,y1,...,xn,yn </area> for regions. "
        "Provide step-by-step physical action plans."
    ),
}


@dataclass
class SemanticObject:
    """Persistent object in Advanced CAG memory."""
    id: int
    label: str
    type: str  # object, area, trajectory
    coords: str
    center: tuple[float, float]
    first_seen: float
    last_seen: float
    frequency: int = 1

class AdvancedSpatialMemory:
    """
    Advanced Context-Aware Grounding (CAG) Memory.
    Performs spatial merging (IoU-like distance) and semantic tracking
    to build an 'Ego-centric World Model'.
    """
    def __init__(self, ttl: float = 12.0, proximity_threshold: float = 150.0):
        self.objects: dict[int, SemanticObject] = {}
        self._next_id = 1
        self.ttl = ttl
        self.proximity_threshold = proximity_threshold # Pixels [0-1000 scale]
        self._last_summary = ""

    def update(self, raw_text: str):
        import time
        now = time.time()
        
        # 1. Parse all spatial tags
        # Format: <type> label [x,y,x,y] </type>
        tags = re.findall(r"<(object|area|trajectory)>(.*?)</\1>", raw_text, re.DOTALL | re.IGNORECASE)
        
        for tag_type, content in tags:
            # Extract numbers for center calculation
            nums = [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?", content)]
            if not nums: continue
            
            # Simple center calculation
            if len(nums) >= 4:
                center = ((nums[0] + nums[2]) / 2, (nums[1] + nums[3]) / 2)
            elif len(nums) >= 2:
                center = (nums[0], nums[1])
            else: continue

            # Try to extract a label name if present before the coordinates
            label_match = re.search(r"([a-z\s]+)", content.lower())
            label = label_match.group(1).strip() if label_match else "unknown"

            # 2. Merge with existing object or create new
            matched_id = None
            for oid, obj in self.objects.items():
                dist = ((obj.center[0] - center[0])**2 + (obj.center[1] - center[1])**2)**0.5
                if dist < self.proximity_threshold:
                    matched_id = oid
                    break
            
            tag_full = f"<{tag_type}>{content}</{tag_type}>"
            
            if matched_id is not None:
                obj = self.objects[matched_id]
                obj.coords = tag_full
                obj.center = center
                obj.last_seen = now
                obj.frequency += 1
                if obj.label == "unknown": obj.label = label
            else:
                self.objects[self._next_id] = SemanticObject(
                    id=self._next_id,
                    label=label,
                    type=tag_type,
                    coords=tag_full,
                    center=center,
                    first_seen=now,
                    last_seen=now
                )
                self._next_id += 1

        self._prune()
        self._generate_episodic_summary(raw_text)

    def _prune(self):
        import time
        now = time.time()
        self.objects = {oid: obj for oid, obj in self.objects.items() if now - obj.last_seen < self.ttl}

    def _generate_episodic_summary(self, raw_text: str):
        """Maintains a short natural language summary of recent events."""
        sentences = re.split(r'[.!?]', raw_text)
        # Grab the most descriptive sentence
        for s in reversed(sentences):
            if len(s.strip()) > 20 and "<" not in s:
                self._last_summary = s.strip()
                break

    def get_context(self) -> str:
        """Returns a sophisticated Environment Report for RynnBrain's prompt."""
        self._prune()
        if not self.objects and not self._last_summary:
            return ""
        
        report = ["\n[ADVANCED CAG ENVIROMENT REPORT]"]
        if self._last_summary:
            report.append(f"- Recent Context: {self._last_summary}")
        
        if self.objects:
            report.append("- Persistent Spatial Map (update current positions if shifted):")
            # Sort by frequency (most reliable objects first)
            sorted_objs = sorted(self.objects.values(), key=lambda x: x.frequency, reverse=True)[:6]
            for obj in sorted_objs:
                report.append(f"  * ID {obj.id}: {obj.label} at {obj.coords}")
        
        return "\n".join(report) + "\n"


class RynnBrainEngine:
    """
    Singleton engine wrapping RynnBrain-2B for WayFinder 2.0.
    Includes CAG (Context-Aware Grounding) for high-speed spatial consistency.
    """

    _instance: Optional["RynnBrainEngine"] = None
    _lock = threading.Lock()

    def __new__(cls) -> "RynnBrainEngine":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
                    cls._instance._memory = AdvancedSpatialMemory(ttl=15.0) # 15s persistence for 'real' awareness
        return cls._instance

    def initialize(self, model_path: str) -> None:
        """Load RynnBrain-2B model and processor. Called once on first request."""
        if self._initialized:
            return

        with self._lock:
            if self._initialized:
                return

            if not torch.cuda.is_available():
                logger.warning("[RynnBrain] No GPU detected. Skipping heavy model load on CPU.")
                self._use_mock = True
                self._initialized = True
                return

            try:
                logger.info(f"[RynnBrain] Loading model from: {model_path}")
                from transformers import AutoModelForImageTextToText, AutoProcessor

                self._processor = AutoProcessor.from_pretrained(
                    model_path,
                    trust_remote_code=True,
                )

                device = "cuda"
                dtype = torch.bfloat16

                # Try flash_attention_2 first (faster), fall back to default
                try:
                    self._model = AutoModelForImageTextToText.from_pretrained(
                        model_path,
                        torch_dtype=dtype,
                        device_map="auto",
                        trust_remote_code=True,
                        attn_implementation="flash_attention_2",
                    )
                    logger.info("[RynnBrain] Using Flash Attention 2 ✓")
                except Exception:
                    logger.info("[RynnBrain] Flash Attention 2 not available, using default.")
                    self._model = AutoModelForImageTextToText.from_pretrained(
                        model_path,
                        torch_dtype=dtype,
                        device_map="auto",
                        trust_remote_code=True,
                    )
                self._model.eval()
                self._device = device
                self._initialized = True
                logger.info(f"[RynnBrain] Model loaded on {device} ✓")

            except Exception as e:
                logger.error(f"[RynnBrain] Failed to load model: {e}")
                # Fallback: use mock mode for development/testing
                self._use_mock = True
                self._initialized = True
                logger.warning("[RynnBrain] Running in MOCK mode (no GPU/model available)")

    @property
    def is_ready(self) -> bool:
        return self._initialized

    @torch.inference_mode()
    def infer(
        self,
        frames: list[Image.Image],
        query: str,
        mode: InferenceMode = InferenceMode.BASE,
        max_new_tokens: int = 256,
        temperature: float = 0.0,
    ) -> RynnBrainResponse:
        """
        Run RynnBrain-2B inference on a sequence of egocentric frames.

        Args:
            frames: List of PIL images (video frames at 2 FPS)
            query: Natural language query/instruction
            mode: Inference specialization mode
            max_new_tokens: Max tokens to generate
            temperature: Sampling temperature (0.0 = deterministic)

        Returns:
            RynnBrainResponse with spatial coordinates and audio cues
        """
        if not self._initialized:
            raise RuntimeError("RynnBrain engine not initialized. Call initialize() first.")

        if hasattr(self, "_use_mock") and self._use_mock:
            return self._mock_infer(frames, query, mode)

        # Inject CAG (Context-Aware Grounding) memory for consistency
        cag_context = self._memory.get_context()
        system_prompt = _SYSTEM_PROMPTS[mode] + cag_context

        # Build conversation in RynnBrain's conversation format
        # Frames are tagged with <frame N> for spatiotemporal grounding
        content = [{"type": "text", "text": system_prompt + "\n\n"}]

        for idx, frame in enumerate(frames):
            content.append({"type": "text", "text": f"<frame {idx}>:"})
            content.append({"type": "image", "image": frame})

        content.append({"type": "text", "text": f"\n{query}"})

        conversation = [{"role": "user", "content": content}]

        inputs = self._processor.apply_chat_template(
            conversation,
            add_generation_prompt=True,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
        )
        inputs = inputs.to(self._model.device)

        sampling_kwargs = {"do_sample": False} if temperature == 0.0 else {
            "do_sample": True,
            "temperature": temperature,
            "top_p": 0.9,
        }

        output_ids = self._model.generate(
            **inputs,
            **sampling_kwargs,
            max_new_tokens=max_new_tokens,
        )

        input_len = inputs["input_ids"].size(1)
        raw_text = self._processor.decode(
            output_ids[0, input_len:], skip_special_tokens=True
        )

        # Update CAG memory for the next frame sequence
        self._memory.update(raw_text)

        return self._parse_response(raw_text, mode, cag_context)

    def _audit_log(self, mode: InferenceMode, cag_context: str, raw_text: str):
        """Append the exact AI "thoughts" and output to a readable audit file."""
        import os, datetime
        log_file = os.path.join(os.path.dirname(__file__), "..", "..", "rynnbrain_audit.log")
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"\n{'='*50}\n")
            f.write(f"[{timestamp}] RynnBrain Analysis (Mode: {mode.value.upper()})\n")
            f.write(f"{'-'*50}\n")
            f.write("🧠 CAG MEMORY (What I remembered before analyzing):\n")
            f.write(f"{cag_context.strip() if cag_context else 'None'}\n\n")
            f.write("👁️ RAW OUTPUT (What I actually 'saw' and decided):\n")
            f.write(f"{raw_text}\n")
            f.write(f"{'='*50}\n")

    def _parse_response(self, raw_text: str, mode: InferenceMode, cag_context: str = "") -> RynnBrainResponse:
        """Parse RynnBrain's structured output into WayFinder response format."""
        # Save to Truth Tracker Audit Log
        self._audit_log(mode, cag_context, raw_text)

        spatial_points = self._extract_spatial_points(raw_text)
        threats = self._extract_threats(raw_text)
        nav_action = self._extract_nav_action(raw_text, mode)
        audio_cues = self._build_audio_cues(raw_text, spatial_points, threats, mode)
        confidence = self._estimate_confidence(raw_text, spatial_points)

        return RynnBrainResponse(
            mode=mode,
            raw_text=raw_text,
            spatial_points=spatial_points,
            navigation_action=nav_action,
            threats=threats,
            audio_cues=audio_cues,
            confidence=confidence,
        )

    def _extract_spatial_points(self, text: str) -> list[SpatialCoordinate]:
        """Extract (x, y) coordinates from RynnBrain's <object>/<area>/<trajectory> tags."""
        point_pattern = r"\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)"
        matches = re.findall(point_pattern, text)
        return [SpatialCoordinate(float(x), float(y)) for x, y in matches]

    def _extract_threats(self, text: str) -> list[dict]:
        """Extract threat objects with bounding boxes from CoP output."""
        threats = []
        # Object tags: <object> x1,y1,x2,y2 </object>
        obj_pattern = r"<object>(.*?)</object>"
        for match in re.finditer(obj_pattern, text, re.IGNORECASE):
            content = match.group(1).strip()
            nums = re.findall(r"-?\d+(?:\.\d+)?", content)
            if len(nums) >= 4:
                threats.append({
                    "type": "obstacle",
                    "bbox": [float(n) for n in nums[:4]],
                    "center": SpatialCoordinate(
                        (float(nums[0]) + float(nums[2])) / 2,
                        (float(nums[1]) + float(nums[3])) / 2,
                    ),
                })
        return threats

    def _extract_nav_action(self, text: str, mode: InferenceMode) -> Optional[str]:
        """Extract the primary navigation action from Nav mode output."""
        if mode != InferenceMode.NAV:
            return None
        action_map = {
            "↑": "MOVE_FORWARD",
            "←": "TURN_LEFT",
            "→": "TURN_RIGHT",
            "STOP": "STOP",
            "MOVE FORWARD": "MOVE_FORWARD",
            "TURN LEFT": "TURN_LEFT",
            "TURN RIGHT": "TURN_RIGHT",
        }
        for symbol, action in action_map.items():
            if symbol in text:
                return action
        return None

    def _build_audio_cues(
        self,
        text: str,
        points: list[SpatialCoordinate],
        threats: list[dict],
        mode: InferenceMode,
    ) -> list[dict]:
        """
        Build 3D spatial audio cues from spatial coordinates.
        Each cue has: message, azimuth (°), elevation (°), priority, distance_estimate.
        """
        cues = []

        # Threat cues (highest priority)
        for threat in threats:
            center = threat["center"]
            azimuth = center.to_audio_angle()
            cues.append({
                "message": "Obstacle detected",
                "azimuth": azimuth,
                "elevation": 0.0,
                "priority": "HIGH",
                "type": "THREAT",
            })

        # Navigation cues from extracted text keywords
        nav_keywords = {
            "left": -45.0,
            "right": 45.0,
            "ahead": 0.0,
            "forward": 0.0,
            "behind": 180.0,
        }
        text_lower = text.lower()
        for kw, az in nav_keywords.items():
            if kw in text_lower and mode == InferenceMode.NAV:
                cues.append({
                    "message": f"Direction: {kw}",
                    "azimuth": az,
                    "elevation": 0.0,
                    "priority": "MEDIUM",
                    "type": "NAV",
                })
                break  # Only one primary direction

        return cues

    def _estimate_confidence(self, text: str, points: list[SpatialCoordinate]) -> float:
        """Simple heuristic confidence score based on output richness."""
        has_coords = len(points) > 0
        has_grounding = any(tag in text for tag in ["<object>", "<area>", "<trajectory>"])
        length_score = min(len(text) / 200.0, 1.0)
        base = 0.6 + (0.2 if has_coords else 0) + (0.1 if has_grounding else 0)
        return round(min(base + length_score * 0.1, 1.0), 3)

    def _mock_infer(
        self, frames: list[Image.Image], query: str, mode: InferenceMode
    ) -> RynnBrainResponse:
        """Mock inference for development without GPU/model."""
        mock_responses = {
            InferenceMode.NAV: (
                "I can see a clear path ahead (↑). There appears to be a chair "
                "to your left <object>(150,400,300,600)</object>. "
                "Move forward and slightly right to avoid it. →↑↑"
            ),
            InferenceMode.COP: (
                "Hazard analysis: Open manhole cover detected "
                "<object>(450,650,550,750)</object> with high risk. "
                "Moving vehicle trajectory predicted <trajectory>(300,200),(350,400),(400,600)</trajectory>. "
                "Immediate stop recommended."
            ),
            InferenceMode.PLAN: (
                "Object search result: Keys located on the table "
                "<object>(400,300,600,450)</object>. "
                "Door visible at <area>(800,200,900,800)</area>. "
                "Navigate: ↑ → ↑ to reach destination."
            ),
            InferenceMode.BASE: (
                "Scene analysis: Indoor environment, well-lit room with furniture. "
                "Path ahead is clear for approximately 3 meters."
            ),
        }
        raw_text = mock_responses.get(mode, "Scene analyzed.")
        cag_context = self._memory.get_context()
        self._memory.update(raw_text)
        return self._parse_response(raw_text, mode, cag_context)


# Module-level singleton
engine = RynnBrainEngine()
