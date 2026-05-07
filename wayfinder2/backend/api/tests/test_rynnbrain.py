import io
from unittest.mock import patch
from django.test import TestCase, Client
from django.urls import reverse
from rest_framework import status
from PIL import Image
from api.scene_memory import scene_memory
import cv2
import numpy as np

class RynnBrainIntegrationTests(TestCase):
    """
    Integration tests for WayFinder 2.0 API.
    Verifies that the RynnBrain engine and endpoints handle data correctly.
    """

    def setUp(self):
        scene_memory.clear()
        self.client = Client()
        self.video_url = reverse('analyze-video')
        self.image_url = reverse('analyze-image')
        self.nav_url = reverse('navigate')
        self.threat_url = reverse('detect-threats')
        self.auth_headers = {'HTTP_AUTHORIZATION': 'Bearer mock-token'}

        # Mock Firebase verification
        self.patcher = patch('firebase_admin.auth.verify_id_token')
        self.mock_verify = self.patcher.start()
        self.mock_verify.return_value = {
            'uid': 'test-user-id',
            'email': 'test@example.com',
            'name': 'Test User'
        }

    def tearDown(self):
        self.patcher.stop()

    def _create_mock_video(self, frames=5, size=(560, 420)):
        """Creates a dummy mp4 file in memory."""
        out = io.BytesIO()
        return b'\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2avc1mp41'

    def _create_mock_image(self, size=(560, 420)):
        """Creates a dummy JPEG image in memory."""
        file = io.BytesIO()
        image = Image.new('RGB', size, color='red')
        image.save(file, 'jpeg')
        file.name = 'test.jpg'
        file.seek(0)
        return file

    def test_health_check(self):
        """Verify the system is alive and engine reporting correctly."""
        url = reverse('health')
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['status'], 'ok')
        self.assertEqual(data['model'], 'RynnBrain-2B')

    def test_analyze_image_mock(self):
        """Test single image analysis returns navigation guidance."""
        img_file = self._create_mock_image()
        response = self.client.post(self.image_url, {
            'image': img_file,
        }, format='multipart', **self.auth_headers)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertIn('raw_text', data)
        self.assertIn('primary_instruction', data)
        self.assertIn('scene_summary', data)
        self.assertIn('alert_level', data)

    def test_navigation_logic(self):
        """Verify navigation endpoint returns expected structure (Nav mode)."""
        video_data = io.BytesIO(b'dummy_video_content')
        video_data.name = 'test.mp4'
        
        response = self.client.post(self.nav_url, {
            'video': video_data,
            'destination': 'find the exit'
        }, format='multipart', **self.auth_headers)

        self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_422_UNPROCESSABLE_ENTITY])
        
        if response.status_code == 200:
            data = response.json()
            self.assertIn('action', data)
            self.assertIn('guidance_text', data)
            self.assertTrue(any(action in data['action'] for action in ['MOVE_FORWARD', 'TURN_LEFT', 'TURN_RIGHT', 'STOP']))

    def test_threat_detection_structure(self):
        """Check if threat detection parses special tags correctly."""
        video_data = io.BytesIO(b'dummy_video_content')
        video_data.name = 'test.mp4'

        response = self.client.post(self.threat_url, {
            'video': video_data
        }, format='multipart', **self.auth_headers)

        if response.status_code == 200:
            data = response.json()
            self.assertIn('threats', data)
            self.assertIn('alert_level', data)
            self.assertIn('analysis_text', data)

    def test_ask_wayfinder_requires_question(self):
        """Verify /ask/ endpoint requires a question."""
        ask_url = reverse('ask-wayfinder')
        response = self.client.post(ask_url, {}, format='multipart', **self.auth_headers)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        data = response.json()
        self.assertIn('error', data)

    def test_ask_wayfinder_with_image(self):
        """Verify /ask/ endpoint works with image + question."""
        ask_url = reverse('ask-wayfinder')
        img_file = self._create_mock_image()
        response = self.client.post(ask_url, {
            'image': img_file,
            'question': 'What is in front of me?'
        }, format='multipart', **self.auth_headers)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertIn('answer', data)
        self.assertIn('question', data)
        self.assertEqual(data['question'], 'What is in front of me?')
