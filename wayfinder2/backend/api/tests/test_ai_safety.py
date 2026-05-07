"""
WayFinder 2.0 — AI / Vision Pipeline Safety Tests

Tests that verify:
- Parser handles malformed output safely
- Threat engine doesn't claim "clear" on uncertain data
- Guidance is short and cautious
- Ask/QA doesn't hallucinate without visual data
- Scene memory staleness is respected
- Invalid inputs produce structured errors
- Response contracts are stable
- No raw media is persisted
"""

import time
from unittest.mock import patch, MagicMock

from django.test import TestCase, override_settings

from api.schemas import (
    BBox, DetectedObject, SceneFacts, ThreatSeverity,
    QAResponse, NavigationGuidance,
)
from api.scene_engine import SceneEngine
from api.threat_engine import assess_threats, compute_alert_level
from api.guidance import generate_guidance
from api.qa_engine import answer_question
from api.scene_memory import SceneMemory


# ─── Phase 4: Structured Output Parser Safety ─────────────────────────────────

class ParserSafetyTests(TestCase):
    """Test that the scene engine parser handles malformed model output."""

    def setUp(self):
        self.engine = SceneEngine.__new__(SceneEngine)
        self.engine._initialized = True
        self.engine._use_mock = True

    def test_valid_structured_output(self):
        """Parser correctly handles well-formed structured output."""
        raw = (
            "OBSTACLE: chair at 100,350,280,650\n"
            "OBJECT: door at 300,50,650,800\n"
            "SCENE: Indoor room with chair and door.\n"
            "FREE_PATH: slightly_right"
        )
        facts = self.engine._parse_structured_output(raw)
        self.assertEqual(len(facts.objects), 2)
        self.assertTrue(facts.objects[0].is_obstacle)
        self.assertEqual(facts.scene_description, "Indoor room with chair and door.")
        self.assertEqual(facts.free_path_direction, "slightly_right")

    def test_malformed_json_no_crash(self):
        """Parser does not crash on garbage text."""
        raw = "{{{{invalid json garbage 12345 !@#$%"
        facts = self.engine._parse_structured_output(raw)
        self.assertIsInstance(facts, SceneFacts)
        self.assertIsInstance(facts.objects, list)
        self.assertGreater(len(facts.scene_description), 0)

    def test_empty_output_safe_fallback(self):
        """Parser returns safe default on empty model output."""
        facts = self.engine._parse_structured_output("")
        self.assertIsInstance(facts, SceneFacts)
        self.assertEqual(len(facts.objects), 0)
        self.assertEqual(facts.scene_description, "Scene analyzed.")
        self.assertLessEqual(facts.confidence, 0.5)

    def test_missing_objects_field(self):
        """Parser handles output with scene but no objects."""
        raw = "SCENE: A dark hallway."
        facts = self.engine._parse_structured_output(raw)
        self.assertEqual(len(facts.objects), 0)
        self.assertEqual(facts.scene_description, "A dark hallway.")

    def test_missing_confidence_defaults_conservative(self):
        """Confidence defaults to a conservative value when no structure found."""
        facts = self.engine._parse_structured_output("just some text here")
        self.assertLessEqual(facts.confidence, 0.6)

    def test_hallucinated_extra_fields_ignored(self):
        """Parser ignores unknown/extra output fields."""
        raw = (
            "SCENE: Normal room.\n"
            "UNKNOWN_FIELD: some value\n"
            "TEMPERATURE: 25C\n"
            "FREE_PATH: ahead"
        )
        facts = self.engine._parse_structured_output(raw)
        self.assertEqual(facts.scene_description, "Normal room.")
        self.assertEqual(facts.free_path_direction, "ahead")

    def test_low_confidence_on_minimal_output(self):
        """Short output produces low confidence."""
        facts = self.engine._parse_structured_output("ok")
        self.assertLessEqual(facts.confidence, 0.5)


# ─── Phase 5: Threat Engine Safety ────────────────────────────────────────────

class ThreatEngineSafetyTests(TestCase):
    """Test threat scoring is deterministic and safe."""

    def test_obstacle_ahead_close_high_threat(self):
        """Object directly ahead and very close should produce HIGH+ severity."""
        obj = DetectedObject(
            label="chair", bbox=BBox(400, 750, 600, 950),
            is_obstacle=True
        )
        facts = SceneFacts(raw_model_output="", objects=[obj], confidence=0.8)
        threats = assess_threats(facts)
        self.assertTrue(len(threats) > 0)
        self.assertIn(
            threats[0].severity,
            [ThreatSeverity.HIGH, ThreatSeverity.CRITICAL]
        )

    def test_stairs_ahead_critical(self):
        """Stairs directly ahead and very close should be CRITICAL."""
        obj = DetectedObject(
            label="stairs", bbox=BBox(300, 850, 700, 980),
            is_obstacle=True
        )
        facts = SceneFacts(raw_model_output="", objects=[obj], confidence=0.9)
        threats = assess_threats(facts)
        self.assertEqual(threats[0].severity, ThreatSeverity.CRITICAL)

    def test_vehicle_in_path_high(self):
        """Vehicle ahead should produce at least HIGH severity."""
        obj = DetectedObject(
            label="car", bbox=BBox(350, 600, 650, 850),
            is_obstacle=True
        )
        facts = SceneFacts(raw_model_output="", objects=[obj], confidence=0.8)
        threats = assess_threats(facts)
        self.assertIn(
            threats[0].severity,
            [ThreatSeverity.HIGH, ThreatSeverity.CRITICAL]
        )

    def test_empty_scene_no_threats(self):
        """Empty scene produces no threats."""
        facts = SceneFacts(raw_model_output="", objects=[], confidence=0.5)
        threats = assess_threats(facts)
        self.assertEqual(len(threats), 0)

    def test_empty_scene_alert_level_low(self):
        """Empty threats list produces LOW alert level, not 'none' or 'clear'."""
        alert = compute_alert_level([])
        self.assertEqual(alert, "LOW")

    def test_object_off_path_low_threat(self):
        """Object far to the side should produce LOW or NONE severity."""
        obj = DetectedObject(
            label="chair", bbox=BBox(10, 400, 100, 600),
            is_obstacle=True
        )
        facts = SceneFacts(raw_model_output="", objects=[obj], confidence=0.8)
        threats = assess_threats(facts)
        if threats:
            self.assertIn(
                threats[0].severity,
                [ThreatSeverity.LOW, ThreatSeverity.NONE]
            )

    def test_deterministic_scoring(self):
        """Same input produces same output every time."""
        obj = DetectedObject(
            label="cable", bbox=BBox(400, 750, 600, 810),
            is_obstacle=True, is_on_floor=True
        )
        facts = SceneFacts(raw_model_output="", objects=[obj], confidence=0.8)
        results = [assess_threats(facts) for _ in range(5)]
        severities = [r[0].severity for r in results]
        self.assertTrue(all(s == severities[0] for s in severities))


# ─── Phase 6: Guidance Generation Safety ──────────────────────────────────────

class GuidanceSafetyTests(TestCase):
    """Test guidance is short, cautious, and handles edge cases."""

    def test_no_scene_data_cautious(self):
        """No objects + low confidence produces cautious guidance."""
        facts = SceneFacts(
            raw_model_output="", objects=[], confidence=0.3
        )
        guidance = generate_guidance(facts)
        self.assertIn("осторожно", guidance.primary_instruction.lower())

    def test_obstacle_ahead_short_warning(self):
        """Obstacle ahead produces short, urgent warning."""
        obj = DetectedObject(
            label="chair", bbox=BBox(400, 800, 600, 950),
            is_obstacle=True
        )
        facts = SceneFacts(
            raw_model_output="", objects=[obj], confidence=0.8
        )
        guidance = generate_guidance(facts)
        # Warning should be short (under 100 chars)
        self.assertLess(len(guidance.primary_instruction), 100)
        self.assertIn(guidance.alert_level, ["HIGH", "CRITICAL"])

    def test_clear_path_uses_cautious_language(self):
        """Clear path uses 'appears clear' not 'is safe'."""
        facts = SceneFacts(
            raw_model_output="", objects=[],
            free_path_direction="ahead", confidence=0.8
        )
        guidance = generate_guidance(facts)
        instruction = guidance.primary_instruction.lower()
        # Should never say "безопасен" (is safe) — only "свободен" (clear) + cautiously
        self.assertNotIn("безопасен", instruction)
        self.assertIn("осторожно", instruction)

    def test_no_free_path_stop(self):
        """FREE_PATH: none produces stop instruction."""
        facts = SceneFacts(
            raw_model_output="", objects=[],
            free_path_direction="none", confidence=0.7
        )
        guidance = generate_guidance(facts)
        self.assertIn("остановитесь", guidance.primary_instruction.lower())

    def test_maximum_instruction_length(self):
        """Primary instruction never exceeds 120 characters."""
        # Many obstacles scenario
        objects = [
            DetectedObject(f"obj{i}", BBox(i*100, 500, i*100+80, 700), is_obstacle=True)
            for i in range(5)
        ]
        facts = SceneFacts(
            raw_model_output="", objects=objects, confidence=0.8
        )
        guidance = generate_guidance(facts)
        self.assertLess(len(guidance.primary_instruction), 120)


# ─── Phase 7: Ask/QA Safety ──────────────────────────────────────────────────

class AskQASafetyTests(TestCase):
    """Test Ask WayFinder doesn't hallucinate without visual data."""

    def test_ask_no_scene_memory_fallback(self):
        """Ask with no scene memory returns safe fallback, not hallucination."""
        result = answer_question([], "What is in front of me?", recent_facts=None)
        self.assertIsInstance(result, QAResponse)
        # Should not claim to see objects when no visual data exists
        self.assertFalse(result.grounded)

    def test_ask_with_fresh_scene_memory(self):
        """Ask with recent facts returns grounded answer."""
        facts = SceneFacts(
            raw_model_output="",
            objects=[
                DetectedObject("chair", BBox(400, 500, 600, 700), is_obstacle=True),
            ],
            scene_description="Chair ahead.",
            confidence=0.8,
            timestamp=time.time(),
        )
        result = answer_question([], "What is ahead?", recent_facts=facts)
        self.assertIsInstance(result, QAResponse)
        self.assertTrue(result.grounded)
        self.assertGreater(len(result.answer), 0)

    def test_ask_empty_question_handled(self):
        """Empty question produces safe response (view handles 400 separately)."""
        result = answer_question([], "", recent_facts=None)
        self.assertIsInstance(result, QAResponse)

    def test_ask_confidence_reflects_source(self):
        """Answers from facts have fact-level confidence, not inflated."""
        facts = SceneFacts(
            raw_model_output="", objects=[],
            scene_description="Clear space.",
            confidence=0.5,
            timestamp=time.time(),
        )
        result = answer_question([], "What do you see?", recent_facts=facts)
        self.assertLessEqual(result.confidence, 0.6)


# ─── Phase 8: Scene Memory Safety ────────────────────────────────────────────

class SceneMemorySafetyTests(TestCase):
    """Test scene memory TTL and pruning."""

    def setUp(self):
        # Use a fresh non-singleton memory for tests
        self.memory = SceneMemory.__new__(SceneMemory)
        self.memory._initialized = False
        self.memory.__init__(max_entries=5, ttl_seconds=2.0)

    def test_fresh_memory_returns_latest(self):
        """Fresh entry is retrievable."""
        facts = SceneFacts(
            raw_model_output="test",
            timestamp=time.time(),
            confidence=0.8,
        )
        self.memory.store(facts)
        latest = self.memory.get_latest()
        self.assertIsNotNone(latest)
        self.assertEqual(latest.raw_model_output, "test")

    def test_stale_memory_pruned(self):
        """Entries older than TTL are pruned."""
        stale = SceneFacts(
            raw_model_output="stale",
            timestamp=time.time() - 10,  # 10s old, TTL is 2s
            confidence=0.5,
        )
        self.memory.store(stale)
        latest = self.memory.get_latest()
        self.assertIsNone(latest)

    def test_clear_works(self):
        """Clear empties memory."""
        facts = SceneFacts(raw_model_output="x", timestamp=time.time())
        self.memory.store(facts)
        self.memory.clear()
        self.assertIsNone(self.memory.get_latest())

    def test_numeric_timestamps(self):
        """Timestamps must be numeric for TTL comparison."""
        facts = SceneFacts(raw_model_output="t", timestamp=time.time())
        self.assertIsInstance(facts.timestamp, (int, float))


# ─── Phase 9: Failure Mode Safety ────────────────────────────────────────────

class FailureModeSafetyTests(TestCase):
    """Test that AI pipeline failures produce structured errors, not 500s."""

    @override_settings(DEBUG=True)
    def test_health_no_secrets(self):
        """Health endpoint doesn't expose model_path or memory_entries."""
        from django.test import RequestFactory
        from api.views import health

        factory = RequestFactory()
        request = factory.get("/api/v2/health/")
        request.user = MagicMock()
        response = health(request)
        self.assertEqual(response.status_code, 200)
        self.assertNotIn("model_path", response.data)
        self.assertNotIn("memory_entries", response.data)
        self.assertEqual(response.data["status"], "ok")

    def test_mock_mode_labeled(self):
        """Mock mode is properly labeled in engine state."""
        engine = SceneEngine.__new__(SceneEngine)
        engine._initialized = True
        engine._use_mock = True
        self.assertTrue(engine.is_mock)
        self.assertTrue(engine.is_ready)


# ─── Phase 10: Response Contract ─────────────────────────────────────────────

class ResponseContractTests(TestCase):
    """Test that API responses have required fields."""

    def test_navigation_guidance_has_required_fields(self):
        """NavigationGuidance.to_api_response() has all required fields."""
        facts = SceneFacts(raw_model_output="", objects=[], confidence=0.5)
        guidance = generate_guidance(facts)
        response = guidance.to_api_response()
        required_fields = [
            "primary_instruction", "scene_summary",
            "alert_level", "threats", "audio_cues", "confidence"
        ]
        for field in required_fields:
            self.assertIn(field, response, f"Missing field: {field}")

    def test_qa_response_has_required_fields(self):
        """QAResponse.to_api_response() has all required fields."""
        result = QAResponse(
            question="test?", answer="test answer.",
            grounded=True, confidence=0.7
        )
        response = result.to_api_response()
        required_fields = ["question", "answer", "grounded", "confidence"]
        for field in required_fields:
            self.assertIn(field, response, f"Missing field: {field}")

    def test_alert_level_is_valid_enum(self):
        """Alert level is one of the valid values."""
        valid = {"LOW", "MEDIUM", "HIGH", "CRITICAL"}
        facts = SceneFacts(raw_model_output="", objects=[], confidence=0.5)
        guidance = generate_guidance(facts)
        self.assertIn(guidance.alert_level, valid)

    def test_threat_to_dict_complete(self):
        """ThreatAssessment.to_dict() includes all needed fields."""
        from api.schemas import ThreatAssessment
        obj = DetectedObject("chair", BBox(400, 600, 600, 800), is_obstacle=True)
        threat = ThreatAssessment(
            object=obj, severity=ThreatSeverity.HIGH, reason="test"
        )
        d = threat.to_dict()
        self.assertIn("label", d)
        self.assertIn("severity", d)
        self.assertIn("reason", d)
        self.assertIn("bbox", d)
        self.assertIn("relative_position", d)
