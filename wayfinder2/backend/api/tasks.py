import base64
import io
import time
import logging

from celery import shared_task
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from PIL import Image

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=0)
def process_video_frame(self, frame_b64: str, mode_str: str, query: str, room_group_name: str, enqueue_time: float, client_sent_at: float = 0, received_at: float = 0):
    """
    Celery task to run RynnBrain inference on a single frame from the WebSocket.
    """
    t_start = time.monotonic()
    inference_started_at = time.time() * 1000
    wait_time = t_start - enqueue_time

    # If the frame has been waiting in the queue for too long (> 1 second), drop it
    # to prevent a massive backlog of outdated frames building up.
    if wait_time > 1.0:
        logger.warning(f"Dropping frame: waited {wait_time:.1f}s in queue.")
        return

    try:
        frame_bytes = base64.b64decode(frame_b64)
        img = Image.open(io.BytesIO(frame_bytes)).convert("RGB")
        # Ensure it's 480p or smaller
        img.thumbnail((640, 480))

        from . import rynnbrain_engine as rbe
        from .rynnbrain_engine import InferenceMode

        mode = InferenceMode(mode_str)
        eng = rbe.engine

        if not eng.is_ready:
            from django.conf import settings
            eng.initialize(settings.RYNNBRAIN_MODEL_PATH)

        resp = eng.infer(frames=[img], query=query, mode=mode)
        t_finished = time.monotonic()
        inference_finished_at = time.time() * 1000
        inference_ms = round((t_finished - t_start) * 1000, 1)
        total_latency_ms = round((time.time() * 1000 - client_sent_at), 1) if client_sent_at else 0

        result_payload = {
            "type": "send_analysis",
            "analysis": {
                "type": "analysis",
                "action": resp.navigation_action,
                "guidance": resp.raw_text,
                "audio_cues": resp.audio_cues,
                "threats": [
                    {
                        "bbox": t["bbox"],
                        "azimuth": round(t["center"].to_audio_angle(), 2),
                    }
                    for t in resp.threats
                ],
                "spatial_points": [
                    {"x": p.x, "y": p.y, "azimuth": round(p.to_audio_angle(), 2)}
                    for p in resp.spatial_points
                ],
                "confidence": resp.confidence,
                "latency_ms": inference_ms,
                "queue_wait_ms": round(wait_time * 1000, 1),
                "total_latency_ms": total_latency_ms,
                "received_at": received_at,
                "inference_started_at": inference_started_at,
                "inference_finished_at": inference_finished_at,
                "response_sent_at": time.time() * 1000,
                "processed_at": time.time()
            }
        }

        # Send back to WebSocket
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            room_group_name,
            result_payload
        )

    except Exception as e:
        logger.error(f"[tasks.process_video_frame] Error: {e}")
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            room_group_name,
            {
                "type": "send_analysis",
                "analysis": {
                    "type": "error",
                    "message": str(e)
                }
            }
        )
