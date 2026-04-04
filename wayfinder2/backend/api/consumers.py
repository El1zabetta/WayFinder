"""
WayFinder 2.0 — WebSocket Consumer
Real-time video streaming channel for continuous navigation assistance.
Receives base64-encoded frames from Flutter app, runs RynnBrain inference,
and pushes back spatial audio cues + navigation commands instantly.
"""

import asyncio
import base64
import io
import json
import logging
import time

from channels.generic.websocket import AsyncWebsocketConsumer
from PIL import Image

logger = logging.getLogger(__name__)

# Max concurrent frames being processed (backpressure control)
MAX_QUEUE_SIZE = 3


class NavigationConsumer(AsyncWebsocketConsumer):
    """
    WebSocket endpoint: ws://host/ws/navigate/

    Protocol (JSON messages):
      Client → Server:
        { "type": "frame", "data": "<base64_jpg>", "mode": "nav", "query": "..." }
        { "type": "ping" }

      Server → Client:
        { "type": "analysis", "action": "MOVE_FORWARD", "audio_cues": [...], "threats": [...], ... }
        { "type": "error", "message": "..." }
        { "type": "pong" }
    """

    async def connect(self):
        self._active = True
        
        # Create a unique room for this connection
        self.room_group_name = f"nav_{self.channel_name.split('!')[-1]}"
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)

        await self.accept()
        logger.info(f"[WS] Client connected: {self.channel_name}")

        await self.send_json({"type": "connected", "model": "RynnBrain-2B", "version": "2.0"})

    async def disconnect(self, close_code):
        self._active = False
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)
        logger.info(f"[WS] Client disconnected: {self.channel_name} (code={close_code})")

    async def receive(self, text_data=None, bytes_data=None):
        try:
            if text_data:
                data = json.loads(text_data)
            elif bytes_data:
                data = json.loads(bytes_data.decode())
            else:
                return

            msg_type = data.get("type", "")

            if msg_type == "ping":
                await self.send_json({"type": "pong", "ts": time.time()})

            elif msg_type == "frame":
                # Ensure we have required data
                frame_b64 = data.get("data", "")
                if not frame_b64:
                    return

                mode_str = data.get("mode", "nav")
                query = data.get("query", "Analyze scene and provide navigation guidance.")

                # Dispatch directly to Redis task queue via Celery
                from .tasks import process_video_frame
                process_video_frame.delay(
                    frame_b64=frame_b64,
                    mode_str=mode_str,
                    query=query,
                    room_group_name=self.room_group_name,
                    enqueue_time=time.monotonic()
                )
                
                # Acknowledge queuing
                await self.send_json({"type": "queued", "ts": time.time()})

        except json.JSONDecodeError:
            await self.send_json({"type": "error", "message": "Invalid JSON"})
        except Exception as e:
            logger.error(f"[WS] receive error: {e}")

    async def send_analysis(self, event):
        """Handler for 'send_analysis' events triggered by Celery worker over channel layer."""
        await self.send_json(event["analysis"])

    async def send_json(self, data: dict):
        """Helper: send JSON message."""
        await self.send(text_data=json.dumps(data))
