"""
WayFinder 2.0 — Guidance Generator Tests
Tests the deterministic guidance pipeline without model dependency.
"""

import unittest
from api.schemas import BBox, DetectedObject, SceneFacts, ThreatSeverity
from api.guidance import generate_guidance
from api.threat_engine import assess_threats, compute_alert_level


class TestThreatEngine(unittest.TestCase):
    """Test deterministic threat scoring logic."""

    def test_no_obstacles(self):
        """Empty scene → no threats."""
        facts = SceneFacts(raw_model_output="", objects=[])
        threats = assess_threats(facts)
        self.assertEqual(len(threats), 0)
        self.assertEqual(compute_alert_level(threats), "LOW")

    def test_chair_center_close(self):
        """Chair directly ahead and close → MEDIUM+ severity."""
        chair = DetectedObject(
            label="chair",
            bbox=BBox(400, 600, 600, 900),  # centered, low in frame = close
            is_obstacle=True,
        )
        facts = SceneFacts(raw_model_output="", objects=[chair])
        threats = assess_threats(facts)
        self.assertEqual(len(threats), 1)
        self.assertIn(threats[0].severity, (ThreatSeverity.MEDIUM, ThreatSeverity.HIGH, ThreatSeverity.CRITICAL))

    def test_object_to_side(self):
        """Object far to the side → LOW or NONE."""
        bench = DetectedObject(
            label="bench",
            bbox=BBox(0, 400, 150, 650),  # far left
            is_obstacle=True,
        )
        facts = SceneFacts(raw_model_output="", objects=[bench])
        threats = assess_threats(facts)
        # Bench is to the side, not in direct path
        if threats:
            self.assertEqual(threats[0].severity, ThreatSeverity.LOW)

    def test_stairs_ahead(self):
        """Stairs directly ahead → HIGH risk."""
        stairs = DetectedObject(
            label="stairs",
            bbox=BBox(200, 500, 800, 900),
            is_obstacle=True,
        )
        facts = SceneFacts(raw_model_output="", objects=[stairs])
        threats = assess_threats(facts)
        self.assertGreaterEqual(len(threats), 1)
        self.assertIn(threats[0].severity, (ThreatSeverity.HIGH, ThreatSeverity.CRITICAL))

    def test_floor_cable(self):
        """Cable on floor in center → MEDIUM+."""
        cable = DetectedObject(
            label="cable",
            bbox=BBox(350, 700, 550, 800),
            is_obstacle=True,
            is_on_floor=True,
        )
        facts = SceneFacts(raw_model_output="", objects=[cable])
        threats = assess_threats(facts)
        self.assertGreaterEqual(len(threats), 1)
        severity = threats[0].severity
        self.assertIn(severity, (ThreatSeverity.MEDIUM, ThreatSeverity.HIGH))

    def test_multiple_threats_sorted(self):
        """Multiple threats should be sorted by severity then proximity."""
        far_chair = DetectedObject("chair", BBox(400, 200, 600, 400), is_obstacle=True)
        close_box = DetectedObject("box", BBox(400, 700, 600, 900), is_obstacle=True, is_on_floor=True)
        facts = SceneFacts(raw_model_output="", objects=[far_chair, close_box])
        threats = assess_threats(facts)
        self.assertGreaterEqual(len(threats), 2)
        # Closer/more severe should come first
        self.assertGreaterEqual(
            {"critical": 4, "high": 3, "medium": 2, "low": 1, "none": 0}[threats[0].severity.value],
            {"critical": 4, "high": 3, "medium": 2, "low": 1, "none": 0}[threats[1].severity.value],
        )


class TestGuidanceGenerator(unittest.TestCase):
    """Test navigation instruction generation."""

    def test_clear_path(self):
        """No obstacles + clear path → 'Move forward'."""
        facts = SceneFacts(
            raw_model_output="SCENE: Clear path ahead.\nFREE_PATH: ahead",
            objects=[],
            scene_description="Clear path ahead.",
            free_path_direction="ahead",
            confidence=0.8,
        )
        nav = generate_guidance(facts)
        self.assertIn("forward", nav.primary_instruction.lower())
        self.assertEqual(nav.alert_level, "LOW")

    def test_obstacle_guidance(self):
        """Obstacle ahead → instruction mentions caution or avoidance."""
        chair = DetectedObject(
            label="chair",
            bbox=BBox(400, 600, 600, 800),
            is_obstacle=True,
        )
        facts = SceneFacts(
            raw_model_output="",
            objects=[chair],
            free_path_direction="slightly_right",
            confidence=0.7,
        )
        nav = generate_guidance(facts)
        # Should mention the obstacle
        inst_lower = nav.primary_instruction.lower()
        self.assertTrue(
            "chair" in inst_lower or "caution" in inst_lower or "stop" in inst_lower,
            f"Expected obstacle mention in: '{nav.primary_instruction}'"
        )

    def test_no_path_detected(self):
        """free_path=none → stop instruction."""
        facts = SceneFacts(
            raw_model_output="",
            objects=[],
            free_path_direction="none",
            confidence=0.5,
        )
        nav = generate_guidance(facts)
        inst_lower = nav.primary_instruction.lower()
        self.assertTrue(
            "stop" in inst_lower or "no clear" in inst_lower,
            f"Expected stop in: '{nav.primary_instruction}'"
        )

    def test_audio_cues_generated(self):
        """Navigation with obstacles should produce audio cues."""
        obj = DetectedObject("table", BBox(600, 400, 800, 700), is_obstacle=True)
        facts = SceneFacts(
            raw_model_output="",
            objects=[obj],
            free_path_direction="slightly_left",
            confidence=0.7,
        )
        nav = generate_guidance(facts)
        self.assertGreater(len(nav.audio_cues), 0)


class TestBBoxPositions(unittest.TestCase):
    """Test BBox spatial reasoning."""

    def test_center_position(self):
        """Centered box → 'ahead'."""
        bbox = BBox(400, 300, 600, 500)
        pos = bbox.to_relative_position()
        self.assertIn("ahead", pos)

    def test_left_position(self):
        """Left-side box → 'left'."""
        bbox = BBox(50, 300, 200, 500)
        pos = bbox.to_relative_position()
        self.assertIn("left", pos)

    def test_right_close_position(self):
        """Right and low box → 'right' and 'close'."""
        bbox = BBox(750, 800, 950, 950)
        pos = bbox.to_relative_position()
        self.assertIn("right", pos)
        self.assertIn("close", pos.lower())

    def test_azimuth_center(self):
        """Center box → near-zero azimuth."""
        bbox = BBox(450, 300, 550, 500)
        az = bbox.to_azimuth()
        self.assertAlmostEqual(az, 0.0, delta=5.0)

    def test_azimuth_far_left(self):
        """Far left box → negative azimuth."""
        bbox = BBox(0, 300, 100, 500)
        az = bbox.to_azimuth()
        self.assertLess(az, -20.0)


if __name__ == "__main__":
    unittest.main()
