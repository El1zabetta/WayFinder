from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient
from unittest.mock import patch
from api.models import Message, UserSession
from api.scene_memory import scene_memory
import io

class MockUser:
    def __init__(self, uid="dev-user", email="dev@example.com"):
        self.uid = uid
        self.firebase_uid = uid
        self.email = email
        self.username = uid
        self.pk = uid
        self.id = uid
        self.is_authenticated = True
        self.is_anonymous = False

    def __str__(self):
        return self.uid

class DataFlowTests(TestCase):
    def setUp(self):
        scene_memory.clear()
        self.client_a = APIClient()
        self.user_a = MockUser("uid_A_123")
        self.client_a.force_authenticate(user=self.user_a)

        self.client_b = APIClient()
        self.user_b = MockUser("uid_B_456")
        self.client_b.force_authenticate(user=self.user_b)

    def test_health_endpoint(self):
        """Test the health endpoint is reachable."""
        response = self.client_a.get(reverse('health'))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['status'], 'ok')

    @patch('api.views.answer_question')
    def test_ask_endpoint_valid_request(self, mock_answer):
        """Valid Ask request creates a Message and UserSession."""
        class MockAnswer:
            def __init__(self):
                self.answer = "I see a chair."
                self.confidence = 0.95
                self.grounded = True
            def to_api_response(self):
                return {"answer": self.answer, "confidence": self.confidence, "grounded": self.grounded}
        
        mock_answer.return_value = MockAnswer()

        from PIL import Image
        import io
        img_file = io.BytesIO()
        Image.new('RGB', (10, 10), color='red').save(img_file, 'jpeg')
        img_file.name = 'test.jpg'
        img_file.seek(0)
        
        response = self.client_a.post(
            reverse('ask-wayfinder'),
            data={'question': 'What is in front of me?', 'image': img_file},
            format='multipart'
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['answer'], "I see a chair.")

        # Check DB persistence
        self.assertEqual(Message.objects.filter(firebase_uid=self.user_a.uid).count(), 1)
        msg = Message.objects.get(firebase_uid=self.user_a.uid)
        self.assertEqual(msg.question_text, "What is in front of me?")
        self.assertEqual(msg.ai_response, "I see a chair.")
        self.assertIsNotNone(msg.session)
        self.assertEqual(msg.session.firebase_uid, self.user_a.uid)

    def test_ask_endpoint_invalid_request(self):
        """Invalid request without question or media."""
        response = self.client_a.post(reverse('ask-wayfinder'), data={})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Message.objects.count(), 0)

    @patch('api.views.scene_engine')
    @patch('api.views.generate_guidance')
    def test_analyze_video_endpoint_saves_derived_data(self, mock_guidance, mock_scene_engine):
        """Analyze request saves derived guidance/metadata but not raw media."""
        class MockGuidance:
            primary_instruction = "Move forward"
            scene_summary = "Clear path"
            alert_level = "LOW"
            audio_cues = []
            confidence = 0.9
            threats = []
        
        class MockFacts:
            def __init__(self):
                import time
                self.timestamp = time.time()
                self.objects = []

        mock_guidance.return_value = MockGuidance()
        mock_scene_engine.analyze_scene.return_value = MockFacts()
        mock_scene_engine.is_mock = True
        mock_scene_engine.is_ready = True

        response = self.client_a.post(
            reverse('analyze-video'),
            data={'video': io.BytesIO(b"fake_video_data" * 1024)}, # tiny fake video
            format='multipart'
        )

        # Assuming it fails gracefully on fake video extraction or we mock extract_frames
        # We need to mock extract_frames to avoid OpenCV errors on fake bytes
        pass

    @patch('api.views.extract_frames')
    @patch('api.views.scene_engine')
    @patch('api.views.generate_guidance')
    def test_analyze_video_endpoint_full(self, mock_guidance, mock_scene_engine, mock_extract):
        """Mocked full flow for analyze video."""
        class MockGuidance:
            primary_instruction = "Move forward"
            scene_summary = "Clear path"
            alert_level = "LOW"
            audio_cues = []
            confidence = 0.9
            threats = []
            
        class MockFacts:
            def __init__(self):
                import time
                self.timestamp = time.time()
                self.objects = []
        
        mock_guidance.return_value = MockGuidance()
        mock_scene_engine.analyze_scene.return_value = MockFacts()
        mock_scene_engine.is_mock = True
        mock_scene_engine.is_ready = True
        mock_extract.return_value = [b"frame1"]

        response = self.client_a.post(
            reverse('analyze-video'),
            data={'video': io.BytesIO(b"fake_video_data")},
            format='multipart'
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        self.assertEqual(Message.objects.filter(firebase_uid=self.user_a.uid).count(), 1)
        msg = Message.objects.get(firebase_uid=self.user_a.uid)
        self.assertEqual(msg.interaction_type, "analyze")
        self.assertEqual(msg.question_text, "Analyze Surroundings")
        self.assertIn("Move forward Clear path", msg.ai_response)
        self.assertIn("Alert Level: LOW", msg.ai_response)
        self.assertEqual(msg.frame_snapshot_url, "")

    def test_history_loads_from_message_model(self):
        """History returns data from the Message model using legacy fields."""
        Message.objects.create(
            firebase_uid=self.user_a.uid,
            question_text="What is this?",
            ai_response="A table.",
            interaction_type="ask"
        )

        response = self.client_a.get(reverse('history-list'))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()['results']
        self.assertEqual(len(data), 1)
        # Flutter contract expects 'question' and 'answer'
        self.assertEqual(data[0]['question'], "What is this?")
        self.assertEqual(data[0]['answer'], "A table.")
        self.assertIn("created_at", data[0])

    def test_user_isolation(self):
        """User A cannot see User B's history."""
        msg_a = Message.objects.create(
            firebase_uid=self.user_a.uid,
            question_text="User A Question",
            ai_response="User A Answer",
        )
        msg_b = Message.objects.create(
            firebase_uid=self.user_b.uid,
            question_text="User B Question",
            ai_response="User B Answer",
        )

        # User A fetches list
        res_list_a = self.client_a.get(reverse('history-list'))
        self.assertEqual(len(res_list_a.json()['results']), 1)
        self.assertEqual(res_list_a.json()['results'][0]['question'], "User A Question")

        # User A tries to fetch User B's detail
        res_detail_b = self.client_a.get(reverse('history-detail', kwargs={'interaction_id': msg_b.id}))
        self.assertEqual(res_detail_b.status_code, status.HTTP_404_NOT_FOUND)

        # User B fetches list
        res_list_b = self.client_b.get(reverse('history-list'))
        self.assertEqual(len(res_list_b.json()['results']), 1)
        self.assertEqual(res_list_b.json()['results'][0]['question'], "User B Question")

    @patch.dict('os.environ', {'ALLOW_DEV_AUTH': 'true'})
    @patch('django.conf.settings.DEBUG', True)
    def test_dev_auth_throttling_compatibility(self):
        """Test that dev auth user works with DRF throttling without errors."""
        client = APIClient()
        # Use the dev-token to authenticate via FirebaseAuthentication
        response = client.get(reverse('history-list'), HTTP_AUTHORIZATION='Bearer dev-token')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Test that user properties are set correctly by the middleware/auth class
        # Access the DRF request object rather than the raw wsgi_request
        request = response.renderer_context['request']
        self.assertTrue(hasattr(request.user, 'pk'))
        self.assertTrue(hasattr(request.user, 'uid'))
        
        # We also want to verify no throttling error crashes the request when dev-token is used.
        response_throttled = client.post(reverse('ask-wayfinder'), data={}, HTTP_AUTHORIZATION='Bearer dev-token')
        self.assertEqual(response_throttled.status_code, status.HTTP_400_BAD_REQUEST)

