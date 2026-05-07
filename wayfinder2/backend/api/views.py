"""
WayFinder 2.0 — REST API Views (Inference Orchestrator)
Routes requests to Scene Engine, Threat Engine, Guidance Generator, and QA Engine.

Endpoints:
  POST /api/v2/analyze/video/   — Navigation mode: scene → guidance
  POST /api/v2/analyze/image/   — Quick single-frame analysis
  POST /api/v2/navigate/        — Navigation guidance (alias)
  POST /api/v2/threats/         — Deep threat analysis
  POST /api/v2/search/          — Object search
  POST /api/v2/ask/             — Ask-Wayfinder: natural language QA
  GET  /api/v2/health/          — Backend health check
  GET  /api/v2/history/         — User's Q&A history
  GET  /api/v2/history/<id>/    — Single interaction detail
"""

import logging
import time

from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view, parser_classes, permission_classes, authentication_classes
from rest_framework.parsers import MultiPartParser, JSONParser
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response

from .scene_engine import scene_engine
from .scene_memory import scene_memory
from .guidance import generate_guidance
from .qa_engine import answer_question
from .threat_engine import assess_threats, compute_alert_level
from .video_processor import extract_frames, extract_single_image

# Backward compat: keep old engine importable for existing tests
from .rynnbrain_engine import InferenceMode, engine

logger = logging.getLogger(__name__)


def _ensure_engine_ready():
    """Initialize scene engine on first request."""
    if not scene_engine.is_ready:
        model_path = settings.RYNNBRAIN_MODEL_PATH
        scene_engine.initialize(model_path)
    # Also initialize legacy engine for backward compat
    if not engine.is_ready:
        engine.initialize(settings.RYNNBRAIN_MODEL_PATH)


# ─── Navigation: Video Analysis ──────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser])
def analyze_video(request: Request) -> Response:
    """
    POST /api/v2/analyze/video/

    Primary navigation mode. Accepts a short video clip.
    Returns: structured navigation guidance with threats, audio cues, and instructions.
    """
    t0 = time.monotonic()

    video_file = request.FILES.get("video")
    if not video_file:
        return Response(
            {"error": "No video file provided. Use field name 'video'."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    max_bytes = settings.MAX_VIDEO_SIZE_MB * 1024 * 1024
    if video_file.size > max_bytes:
        return Response(
            {"error": f"Video too large. Maximum: {settings.MAX_VIDEO_SIZE_MB} MB"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        _ensure_engine_ready()

        video_bytes = video_file.read()
        frames = extract_frames(
            video_bytes,
            target_fps=settings.VIDEO_FPS,
            max_frames=settings.VIDEO_MAX_FRAMES,
        )

        if not frames:
            return Response(
                {"error": "Could not extract frames from video."},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        # ── Pipeline: Scene → Threats → Guidance ──
        facts = scene_engine.analyze_scene(frames)
        scene_memory.store(facts)
        nav = generate_guidance(facts)

        elapsed = round((time.monotonic() - t0) * 1000, 1)

        # Build response compatible with existing Flutter frontend
        response_data = {
            # New structured fields
            "primary_instruction": nav.primary_instruction,
            "scene_summary": nav.scene_summary,
            "alert_level": nav.alert_level,

            # Legacy-compatible fields (Flutter expects these)
            "mode": "nav",
            "raw_text": nav.primary_instruction + " " + nav.scene_summary,
            "navigation_action": _instruction_to_action(nav.primary_instruction),
            "spatial_points": [],
            "threats": [t.to_dict() for t in nav.threats],
            "audio_cues": nav.audio_cues,
            "confidence": nav.confidence,

            # Metadata
            "frames_analyzed": len(frames),
            "inference_ms": elapsed,
            "engine_mode": "mock" if scene_engine.is_mock else "gpu",
        }

        logger.debug(f"[analyze_video] Request successful for {getattr(request.user, 'uid', 'anonymous')}")
        
        # Save to database (derived text only)
        _save_analyze_interaction(
            request=request,
            guidance_text=nav.primary_instruction + " " + nav.scene_summary,
            threat_level=nav.alert_level,
            source="mock" if scene_engine.is_mock else "gpu",
            confidence=nav.confidence,
            elapsed=elapsed
        )

        return Response(response_data)

    except RuntimeError as e:
        logger.error(f"[analyze_video] RuntimeError: {e}")
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    except Exception as e:
        logger.exception("[analyze_video] Unexpected error")
        return Response(
            {"error": "Internal server error during video analysis."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


# ─── Image Analysis ──────────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser])
def analyze_image(request: Request) -> Response:
    """
    POST /api/v2/analyze/image/

    Single-frame analysis for quick scene check.
    """
    t0 = time.monotonic()

    image_file = request.FILES.get("image")
    if not image_file:
        return Response(
            {"error": "No image file provided. Use field name 'image'."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        _ensure_engine_ready()
        img = extract_single_image(image_file.read())
        facts = scene_engine.analyze_scene([img])
        scene_memory.store(facts)
        nav = generate_guidance(facts)

        response_data = {
            "primary_instruction": nav.primary_instruction,
            "scene_summary": nav.scene_summary,
            "alert_level": nav.alert_level,
            "mode": "nav",
            "raw_text": nav.primary_instruction + " " + nav.scene_summary,
            "navigation_action": _instruction_to_action(nav.primary_instruction),
            "spatial_points": [],
            "threats": [t.to_dict() for t in nav.threats],
            "audio_cues": nav.audio_cues,
            "confidence": nav.confidence,
            "inference_ms": round((time.monotonic() - t0) * 1000, 1),
        }

        logger.debug(f"[analyze_image] Request successful for {getattr(request.user, 'uid', 'anonymous')}")

        # Save to database
        _save_analyze_interaction(
            request=request,
            guidance_text=nav.primary_instruction + " " + nav.scene_summary,
            threat_level=nav.alert_level,
            source="mock" if scene_engine.is_mock else "gpu",
            confidence=nav.confidence,
            elapsed=round((time.monotonic() - t0) * 1000, 1)
        )

        return Response(response_data)

    except Exception as e:
        logger.exception("[analyze_image] Error")
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ─── Navigation Endpoint ─────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser])
def navigate(request: Request) -> Response:
    """
    POST /api/v2/navigate/

    Dedicated navigation guidance. Same pipeline as analyze_video
    but response shaped for navigation consumer.
    """
    video_file = request.FILES.get("video")
    if not video_file:
        return Response(
            {"error": "Video file required for navigation."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        _ensure_engine_ready()
        frames = extract_frames(video_file.read(), target_fps=settings.VIDEO_FPS, max_frames=8)
        if not frames:
            return Response(
                {"error": "Could not extract frames."},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        facts = scene_engine.analyze_scene(frames)
        scene_memory.store(facts)
        nav = generate_guidance(facts)

        return Response({
            "action": _instruction_to_action(nav.primary_instruction),
            "guidance_text": nav.primary_instruction + " " + nav.scene_summary,
            "audio_cues": nav.audio_cues,
            "obstacles": [t.to_dict() for t in nav.threats],
            "confidence": nav.confidence,
        })

    except RuntimeError as e:
        logger.error(f"[navigate] Extraction failed: {e}")
        return Response({"error": f"Invalid video: {e}"}, status=status.HTTP_422_UNPROCESSABLE_ENTITY)
    except Exception as e:
        logger.exception("[navigate] Error")
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ─── Threat Detection ────────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser])
def detect_threats(request: Request) -> Response:
    """
    POST /api/v2/threats/

    Deep threat/hazard analysis of the scene.
    """
    video_file = request.FILES.get("video")
    if not video_file:
        return Response(
            {"error": "Video file required for threat detection."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        _ensure_engine_ready()
        frames = extract_frames(video_file.read(), target_fps=settings.VIDEO_FPS, max_frames=12)
        if not frames:
            return Response(
                {"error": "Could not extract frames."},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        facts = scene_engine.analyze_threats(frames)
        scene_memory.store(facts)
        threats = assess_threats(facts)
        alert_level = compute_alert_level(threats)

        return Response({
            "threats": [t.to_dict() for t in threats],
            "analysis_text": facts.scene_description,
            "alert_level": alert_level,
            "audio_cues": generate_guidance(facts).audio_cues,
            "confidence": facts.confidence,
        })

    except RuntimeError as e:
        logger.error(f"[detect_threats] Extraction failed: {e}")
        return Response({"error": f"Invalid video: {e}"}, status=status.HTTP_422_UNPROCESSABLE_ENTITY)
    except Exception as e:
        logger.exception("[detect_threats] Error")
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ─── Object Search ───────────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser])
def search_object(request: Request) -> Response:
    """
    POST /api/v2/search/

    Search for a specific object in the scene.
    Uses QA engine with a targeted question.
    """
    video_file = request.FILES.get("video")
    target = request.data.get("target", "")

    if not video_file:
        return Response({"error": "Video file required."}, status=status.HTTP_400_BAD_REQUEST)
    if not target:
        return Response({"error": "Target object required."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        _ensure_engine_ready()
        frames = extract_frames(video_file.read(), target_fps=settings.VIDEO_FPS, max_frames=8)
        if not frames:
            return Response(
                {"error": "Could not extract frames."},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        # Use QA engine for object search
        qa_response = answer_question(
            frames,
            question=f"Can you see a {target}? Where is it? Give directions to reach it.",
            recent_facts=scene_memory.get_latest(),
        )

        # Also run scene analysis to check for object in detected objects
        facts = scene_engine.analyze_scene(frames)
        scene_memory.store(facts)

        # Check if target was found in scene objects
        target_lower = target.lower()
        matched = [o for o in facts.objects if target_lower in o.label.lower()]
        found = len(matched) > 0
        primary = matched[0] if matched else None

        return Response({
            "target": target,
            "found": found,
            "location": {
                "x": primary.bbox.center_x,
                "y": primary.bbox.center_y,
                "azimuth": round(primary.bbox.to_azimuth(), 2),
                "elevation": round(primary.bbox.to_elevation(), 2),
                "relative_position": primary.relative_position,
            } if primary else None,
            "instructions": qa_response.answer,
            "audio_cues": [{
                "message": f"{target} {primary.relative_position}",
                "azimuth": round(primary.bbox.to_azimuth(), 2),
                "elevation": 0.0,
                "priority": "MEDIUM",
                "type": "SEARCH",
            }] if primary else [],
            "all_points": [
                {"x": o.bbox.center_x, "y": o.bbox.center_y, "azimuth": round(o.bbox.to_azimuth(), 2)}
                for o in matched
            ],
            "confidence": qa_response.confidence,
        })

    except RuntimeError as e:
        return Response({"error": f"Invalid video: {e}"}, status=status.HTTP_422_UNPROCESSABLE_ENTITY)
    except Exception as e:
        logger.exception("[search_object] Error")
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ─── Ask-Wayfinder (NEW) ─────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([MultiPartParser, JSONParser])
def ask_wayfinder(request: Request) -> Response:
    """
    POST /api/v2/ask/

    Ask-Wayfinder mode: natural language questions about the scene.
    Accepts video/image + question. Returns grounded answer.

    Body:
      - video OR image: media file
      - question: natural language question (e.g., "What is in front of me?")
    """
    t0 = time.monotonic()

    question = request.data.get("question", "")
    if not question:
        return Response(
            {"error": "Question is required. Provide 'question' field."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Accept either video or image
    video_file = request.FILES.get("video")
    image_file = request.FILES.get("image")

    if not video_file and not image_file:
        # Try answering from memory if no media provided
        recent = scene_memory.get_latest()
        if recent:
            qa_resp = answer_question([], question, recent_facts=recent)
            elapsed = round((time.monotonic() - t0) * 1000, 1)
            source = "memory"
            response_data = {
                **qa_resp.to_api_response(),
                "source": source,
                "inference_ms": elapsed,
            }
            _save_interaction(request, question, qa_resp, source, elapsed)
            return Response(response_data)
        return Response(
            {"error": "Provide a video or image file, or ask after a recent analysis."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        _ensure_engine_ready()

        if video_file:
            frames = extract_frames(
                video_file.read(),
                target_fps=settings.VIDEO_FPS,
                max_frames=4,  # Fewer frames for faster QA
            )
        else:
            frames = [extract_single_image(image_file.read())]

        if not frames:
            return Response(
                {"error": "Could not extract frames."},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )

        recent_facts = scene_memory.get_latest()
        qa_resp = answer_question(frames, question, recent_facts=recent_facts)
        elapsed = round((time.monotonic() - t0) * 1000, 1)
        source = "model" if not recent_facts else "model+memory"

        response_data = {
            **qa_resp.to_api_response(),
            "source": source,
            "inference_ms": elapsed,
        }
        _save_interaction(request, question, qa_resp, source, elapsed)
        return Response(response_data)

    except Exception as e:
        logger.exception("[ask_wayfinder] Error")
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ─── History ──────────────────────────────────────────────────────────────────

@api_view(["GET"])
def history_list(request: Request) -> Response:
    """
    GET /api/v2/history/

    Returns the authenticated user's Q&A history, most recent first.
    Query params: ?limit=N (default 50)
    """
    from .models import Message
    from .serializers import InteractionListSerializer

    uid = request.user.uid
    limit = min(int(request.query_params.get("limit", 50)), 200)

    logger.debug(f"[history_list] Fetching history for {uid[:8]}")

    interactions = Message.objects.filter(
        firebase_uid=uid
    )[:limit]

    serializer = InteractionListSerializer(interactions, many=True)
    return Response({
        "count": len(serializer.data),
        "results": serializer.data,
    })


@api_view(["GET"])
def history_detail(request: Request, interaction_id: int) -> Response:
    """
    GET /api/v2/history/<id>/

    Returns detail for a single interaction, scoped to the authenticated user.
    """
    from .models import Message
    from .serializers import InteractionDetailSerializer

    uid = request.user.uid

    logger.debug(f"[history_detail] Fetching interaction {interaction_id} for {uid[:8]}")

    try:
        interaction = Message.objects.get(
            id=interaction_id,
            firebase_uid=uid,
        )
    except Message.DoesNotExist:
        return Response(
            {"error": "Interaction not found."},
            status=status.HTTP_404_NOT_FOUND,
        )

    serializer = InteractionDetailSerializer(interaction)
    return Response(serializer.data)


# ─── Health Check ─────────────────────────────────────────────────────────────

@api_view(["GET"])
@authentication_classes([])
@permission_classes([AllowAny])
def health(request: Request) -> Response:
    """GET /api/v2/health/ — System health check."""
    import torch

    gpu_available = torch.cuda.is_available()
    gpu_name = torch.cuda.get_device_name(0) if gpu_available else None

    return Response({
        "status": "ok",
        "version": "2.1.0",
        "model": "RynnBrain-2B",
        "engine_ready": scene_engine.is_ready,
        "engine_mode": "gpu" if (scene_engine.is_ready and not scene_engine.is_mock) else "mock",
        "gpu_available": gpu_available,
        "gpu_name": gpu_name,
        "model_path": settings.RYNNBRAIN_MODEL_PATH,
        "memory_entries": len(scene_memory.get_recent(100)),
        "endpoints": [
            "POST /api/v2/analyze/video/",
            "POST /api/v2/analyze/image/",
            "POST /api/v2/navigate/",
            "POST /api/v2/threats/",
            "POST /api/v2/search/",
            "POST /api/v2/ask/",
            "GET  /api/v2/health/",
        ],
    })


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _save_interaction(request, question, qa_resp, source, elapsed):
    """Persist a successful Q&A interaction to both legacy and new models."""
    from .models import AssistantInteraction, Message, UserSession

    try:
        uid = getattr(request.user, 'uid', None)
        if not uid:
            return  # Anonymous — skip

        # Legacy model (backward compat)
        AssistantInteraction.objects.create(
            firebase_uid=uid,
            question=question,
            answer=qa_resp.answer,
            confidence=qa_resp.confidence,
            grounded=getattr(qa_resp, 'grounded', False),
            source=source or "",
            interaction_type="ask",
            inference_ms=elapsed,
        )

        # New Message model (with session link if available)
        session_id = request.data.get("session_id")
        if session_id:
            try:
                session = UserSession.objects.get(id=session_id, firebase_uid=uid)
            except UserSession.DoesNotExist:
                session = UserSession.get_or_create_active_session(uid)
        else:
            session = UserSession.get_or_create_active_session(uid)

        Message.objects.create(
            firebase_uid=uid,
            session=session,
            question_text=question,
            ai_response=qa_resp.answer,
            confidence=qa_resp.confidence,
            grounded=getattr(qa_resp, 'grounded', False),
            source=source or "",
            interaction_type="ask",
            inference_ms=elapsed,
        )

        logger.debug(f"[ask_wayfinder] Saved interaction for {uid[:8]}")
    except Exception as e:
        logger.warning(f"[ask_wayfinder] Failed to save interaction: {e}")

def _save_analyze_interaction(request, guidance_text, threat_level, source, confidence, elapsed):
    """Persist an analysis interaction to the new Message model."""
    from .models import Message, UserSession

    try:
        uid = getattr(request.user, 'uid', None)
        if not uid:
            return  # Anonymous — skip

        session_id = request.data.get("session_id")
        if session_id:
            try:
                session = UserSession.objects.get(id=session_id, firebase_uid=uid)
            except UserSession.DoesNotExist:
                session = UserSession.get_or_create_active_session(uid)
        else:
            session = UserSession.get_or_create_active_session(uid)

        # We format ai_response to include guidance and threat level
        ai_response = f"{guidance_text} (Alert Level: {threat_level})"

        Message.objects.create(
            firebase_uid=uid,
            session=session,
            question_text="Analyze Surroundings",  # Standardized input for analyze
            ai_response=ai_response,
            confidence=confidence,
            grounded=True,
            source=source or "",
            interaction_type="analyze",
            inference_ms=elapsed,
        )

        logger.debug(f"[analyze] Saved interaction for {uid[:8]}")
    except Exception as e:
        logger.warning(f"[analyze] Failed to save interaction: {e}")


def _instruction_to_action(instruction: str) -> str:
    """
    Convert guidance instruction to legacy action code for Flutter.
    """
    inst = instruction.lower()
    if "stop" in inst:
        return "STOP"
    if "left" in inst and "move" in inst:
        return "TURN_LEFT"
    if "right" in inst and "move" in inst:
        return "TURN_RIGHT"
    if "forward" in inst or "clear" in inst or "move" in inst:
        return "MOVE_FORWARD"
    if "caution" in inst or "careful" in inst:
        return "MOVE_FORWARD"
    return "STOP"


# ─── Sessions & Messages ─────────────────────────────────────────────────────

@api_view(["POST"])
@parser_classes([JSONParser])
def session_start(request: Request) -> Response:
    """
    POST /api/v2/session/start/

    Create a new user session. Returns the session_id to attach to messages.

    Body (optional):
      - device_info: string — device name or model
    """
    from .models import UserSession
    from .serializers import SessionSerializer

    uid = request.user.uid
    device_info = request.data.get("device_info", "")

    session = UserSession.objects.create(
        firebase_uid=uid,
        device_info=device_info,
    )

    logger.info(f"[session_start] Created session {session.id} for {uid[:8]}")
    return Response(SessionSerializer(session).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
def session_end(request: Request, session_id: int) -> Response:
    """
    POST /api/v2/session/<id>/end/

    Mark a session as ended.
    """
    from .models import UserSession
    from django.utils import timezone

    uid = request.user.uid

    try:
        session = UserSession.objects.get(id=session_id, firebase_uid=uid)
    except UserSession.DoesNotExist:
        return Response({"error": "Session not found."}, status=status.HTTP_404_NOT_FOUND)

    session.is_active = False
    session.ended_at = timezone.now()
    session.save(update_fields=["is_active", "ended_at"])

    logger.info(f"[session_end] Ended session {session_id} for {uid[:8]}")
    return Response({"status": "ended", "session_id": session_id})


@api_view(["POST"])
@parser_classes([MultiPartParser, JSONParser])
def message_save(request: Request) -> Response:
    """
    POST /api/v2/message/save/

    Explicitly save a question + AI response.

    Body:
      - question_text: string (required)
      - ai_response: string (required)
      - session_id: int (optional)
      - frame_snapshot_url: string (optional)
      - confidence: float (optional)
      - interaction_type: string (optional, default "ask")
    """
    from .models import Message
    from .serializers import MessageSerializer

    uid = request.user.uid
    question_text = request.data.get("question_text", "")
    ai_response = request.data.get("ai_response", "")

    if not question_text or not ai_response:
        return Response(
            {"error": "Both 'question_text' and 'ai_response' are required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    msg = Message.objects.create(
        firebase_uid=uid,
        session_id=request.data.get("session_id"),
        question_text=question_text,
        ai_response=ai_response,
        frame_snapshot_url=request.data.get("frame_snapshot_url", ""),
        confidence=float(request.data.get("confidence", 0.0)),
        grounded=request.data.get("grounded", False) in (True, "true", "True", "1"),
        source=request.data.get("source", ""),
        interaction_type=request.data.get("interaction_type", "ask"),
        inference_ms=float(request.data.get("inference_ms", 0)) or None,
    )

    logger.debug(f"[message_save] Saved message {msg.id} for {uid[:8]}")
    return Response(MessageSerializer(msg).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
def messages_history(request: Request) -> Response:
    """
    GET /api/v2/messages/?limit=20&session_id=N

    Returns the authenticated user's message history, most recent first.
    Query params:
      - limit: int (default 20, max 200)
      - session_id: int (optional, filter by session)
    """
    from .models import Message
    from .serializers import MessageListSerializer

    uid = request.user.uid
    limit = min(int(request.query_params.get("limit", 20)), 200)
    session_id = request.query_params.get("session_id")

    qs = Message.objects.filter(firebase_uid=uid)
    if session_id:
        qs = qs.filter(session_id=session_id)
    messages = qs[:limit]

    serializer = MessageListSerializer(messages, many=True)
    return Response({
        "count": len(serializer.data),
        "results": serializer.data,
    })


@api_view(["GET"])
def message_detail(request: Request, message_id: int) -> Response:
    """
    GET /api/v2/messages/<id>/

    Returns detail for a single message, scoped to the authenticated user.
    """
    from .models import Message
    from .serializers import MessageSerializer

    uid = request.user.uid

    try:
        msg = Message.objects.get(id=message_id, firebase_uid=uid)
    except Message.DoesNotExist:
        return Response({"error": "Message not found."}, status=status.HTTP_404_NOT_FOUND)

    return Response(MessageSerializer(msg).data)

