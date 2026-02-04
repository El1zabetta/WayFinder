import os
import json
import base64
import asyncio
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Integration with Django logic
import sys
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(project_root)

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
import django
django.setup()

from vision.services import detect_objects_local, analyze_image_local, generate_ai_response_async, text_to_speech_async
from vision.models import VisionUser
from asgiref.sync import sync_to_async

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("WayFinderWS")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

manager = ConnectionManager()

@app.websocket("/ws/vision/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(websocket)
    logger.info(f"User {user_id} connected via WebSocket")
    
    # Get or create vision user
    vision_user_tuple = await sync_to_async(VisionUser.objects.get_or_create)(telegram_id=user_id)
    vision_user = vision_user_tuple[0]

    try:
        while True:
            # Receive data from client
            # Expected format: {"image": "base64...", "text": "...", "mode": "..."}
            data = await websocket.receive_text()
            message = json.loads(data)
            
            image_b64 = message.get("image")
            text_input = message.get("text", "")
            mode = message.get("mode", "navigator")
            
            response_data = {}
            
            if image_b64:
                # Process image
                image_bytes = base64.b64decode(image_b64)
                
                # 1. Fast YOLO for HUD
                detected_objects = await sync_to_async(detect_objects_local)(image_bytes)
                response_data["detected_objects"] = detected_objects
                
                # Check for danger (simplified: car, truck, bus, motorcycle nearby)
                danger_objs = {'car', 'truck', 'bus', 'motorcycle', 'bicycle', 'person'}
                is_danger = any(obj in danger_objs for obj in detected_objects)
                response_data["is_danger"] = is_danger
                
                if mode == "vision" or text_input:
                    # Comprehensive analysis
                    visual_description = await sync_to_async(analyze_image_local)(image_bytes)
                    
                    if text_input:
                        # LLM Response
                        ai_response = await generate_ai_response_async(
                            text_input, 
                            visual_context=visual_description, 
                            user_obj=vision_user
                        )
                        response_data["message"] = ai_response
                        
                        # TTS
                        mood = vision_user.facts.get('mood', 'neutral')
                        audio_content = await text_to_speech_async(ai_response, mood=mood)
                        if audio_content:
                            response_data["audio"] = base64.b64encode(audio_content).decode('utf-8')
                    else:
                        response_data["message"] = visual_description
            
            # Send result back
            await websocket.send_text(json.dumps(response_data))

    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info(f"User {user_id} disconnected")
    except Exception as e:
        logger.error(f"Error in websocket loop: {e}")
        manager.disconnect(websocket)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
