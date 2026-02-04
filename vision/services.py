import os
import asyncio
import base64
import torch
from faster_whisper import WhisperModel
from transformers import BlipProcessor, BlipForConditionalGeneration
from PIL import Image
from io import BytesIO
from openai import AsyncOpenAI
import edge_tts
import logging
import easyocr
import numpy as np
from ultralytics import YOLO
from asgiref.sync import sync_to_async
from asgiref.sync import sync_to_async

logger = logging.getLogger(__name__)

class LocalBrain:
    _stt_model = None
    _vision_model = None
    _vision_processor = None
    _ocr_reader = None
    _yolo_model = None
    
    @classmethod
    def get_stt_model(cls):
        if cls._stt_model is None:
            print("⏳ Загрузка модели Whisper (STT)...")
            device = "cuda" if torch.cuda.is_available() else "cpu"
            compute_type = "float16" if device == "cuda" else "int8"
            
            try:
                # Используем tiny модель для скорости (max speed)
                cls._stt_model = WhisperModel("tiny", device=device, compute_type=compute_type)
                print(f"✅ Whisper (tiny) загружен на {device}")
            except Exception as e:
                print(f"❌ Ошибка загрузки Whisper: {e}")
                cls._stt_model = WhisperModel("tiny", device="cpu", compute_type="int8")
        return cls._stt_model

    @classmethod
    def get_vision_model(cls):
        if cls._vision_model is None:
            print("⏳ Загрузка модели Vision (BLIP)...")
            try:
                cls._vision_processor = BlipProcessor.from_pretrained("Salesforce/blip-image-captioning-base")
                cls._vision_model = BlipForConditionalGeneration.from_pretrained("Salesforce/blip-image-captioning-base")
                
                device = "cuda" if torch.cuda.is_available() else "cpu"
                cls._vision_model.to(device)
                print(f"✅ Vision модель загружена на {device}")
            except Exception as e:
                print(f"❌ Ошибка загрузки Vision: {e}")
        return cls._vision_processor, cls._vision_model

    @classmethod
    def get_ocr_reader(cls):
        if cls._ocr_reader is None:
             print("⏳ Загрузка EasyOCR...")
             # Инициализируем только русский и английский
             cls._ocr_reader = easyocr.Reader(['ru', 'en'], gpu=torch.cuda.is_available())
             print("✅ EasyOCR загружен")
        return cls._ocr_reader

    @classmethod
    def get_yolo_model(cls):
        if cls._yolo_model is None:
            print("⏳ Загрузка YOLO...")
            try:
                cls._yolo_model = YOLO("yolov8n.pt") # Nano model for speed
                print("✅ YOLO загружен")
            except Exception as e:
                 print(f"❌ Ошибка загрузки YOLO: {e}")
        return cls._yolo_model

def speech_to_text(audio_file):
    model = LocalBrain.get_stt_model()
    if not model:
        return None
    try:
        segments, info = model.transcribe(audio_file, beam_size=5)
        text = " ".join([segment.text for segment in segments])
        return text.strip()
    except Exception as e:
        logger.error(f"STT Error: {e}")
        return None

def analyze_image_local(image_bytes):
    processor, model = LocalBrain.get_vision_model()
    if not model:
        return "Ошибка загрузки зрения."
    try:
        image = Image.open(BytesIO(image_bytes)).convert('RGB')
        device = "cuda" if torch.cuda.is_available() else "cpu"
        inputs = processor(images=image, return_tensors="pt").to(device)
        out = model.generate(**inputs, max_new_tokens=50)
        description = processor.decode(out[0], skip_special_tokens=True)
        return description
    except Exception as e:
        logger.error(f"Vision Error: {e}")
        return "Не удалось распознать изображение."

def read_text_local(image_bytes):
    reader = LocalBrain.get_ocr_reader()
    try:
        result = reader.readtext(image_bytes, detail=0)
        text = " ".join(result)
        return text if text else None
    except Exception as e:
        logger.error(f"OCR Error: {e}")
        return None

def detect_objects_local(image_bytes):
    model = LocalBrain.get_yolo_model()
    if not model: return []
    try:
        import cv2 # Local import to avoid top-level fail if missing
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            return []
        
        # Preprocessing для улучшения распознавания
        # 1. Resize если изображение слишком большое
        max_dimension = 1280
        h, w = img.shape[:2]
        if max(h, w) > max_dimension:
            scale = max_dimension / max(h, w)
            img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
        
        # 2. Улучшение контраста (CLAHE)
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        l = clahe.apply(l)
        img = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)
        
        # Детекция с оптимальными параметрами
        results = model.predict(img, conf=0.3, iou=0.45, verbose=False)
        detected = []
        for r in results:
            for c in r.boxes.cls:
                detected.append(model.names[int(c)])
        return list(set(detected))
    except Exception as e:
        print(f"YOLO Error: {e}")
        return []

from .cag import CAGSystem
from .tts_engine import TTSBrain

# Lazy Init Kani (можно перенести в apps.py для автозагрузки)
# TTSBrain.init_kani() 

async def generate_ai_response_async(user_text, visual_context=None, user_obj=None, ocr_context=None):
    """
    Генерирует ответ используя DeepSeek/OpenRouter API + CAG System.
    """
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return "Ошибка: Не найден API ключ (OPENAI_API_KEY)."

    # 1. CAG: Обновляем состояние и память
    cag = None
    if user_obj:
        cag = CAGSystem(user_obj)
        # Оборачиваем синхронный вызов DB в async
        await sync_to_async(cag.update_state)(user_text)

    # 2. CAG: Строим умный промпт для незрячих пользователей
    if cag:
        system_prompt = cag.build_system_prompt(visual_context, user_query=user_text)
    else:
        system_prompt = """Ты WayFinder — персональный голосовой ИИ-ассистент для незрячих людей.

ТВОЯ РОЛЬ:
- Ты видишь мир глазами пользователя через камеру и описываешь окружение
- Ты помогаешь ориентироваться в пространстве, читать текст, распознавать объекты
- Ты поддерживаешь беседу, запоминаешь контекст и адаптируешься под пользователя
- Ты эмпатичный, терпеливый и всегда готов помочь

СТИЛЬ ОБЩЕНИЯ:
- Говори тепло, по-дружески, но профессионально
- Отвечай КРАТКО и ЧЕТКО (1-3 предложения максимум для голоса)
- Используй простой язык без технического жаргона
- Если видишь что-то важное (препятствие, текст, человек) — сообщи сразу
- Запоминай предпочтения пользователя из диалога

ПРИМЕРЫ ОТВЕТОВ:
❌ "Я вижу изображение с несколькими объектами..."
✅ "Передо мной стол, на нём чашка кофе и телефон"

❌ "Согласно моему анализу..."
✅ "Похоже, это вывеска магазина"

ВАЖНО: Ты активируешься только когда пользователь говорит "WayFinder" + вопрос. Отвечай только на то, что спросили."""

    # OCR Context add
    user_prompt = user_text
    if ocr_context:
        user_prompt += f"\n\n(Текст на изображении: {ocr_context})"

    # 3. LLM Call
    base_url = "https://api.deepseek.com"
    model_name = "deepseek-chat"
    if api_key.startswith("sk-or-v1"):
        base_url = "https://openrouter.ai/api/v1"
        model_name = "deepseek/deepseek-chat"

    client = AsyncOpenAI(api_key=api_key, base_url=base_url)
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]

    try:
        response = await client.chat.completions.create(
            model=model_name,
            messages=messages,
            max_tokens=300,
            temperature=0.7  # Более естественные ответы
        )
        answer = response.choices[0].message.content
        return answer
    except Exception as e:
        logger.error(f"DeepSeek API Error: {e}")
        return f"Извините, произошла ошибка связи. Попробуйте еще раз."

async def text_to_speech_async(text, mood="neutral"):
    return await TTSBrain.speak(text, mood=mood)

def get_ai_response_sync(text, visual_context=None):
    return asyncio.run(generate_ai_response_async(text, visual_context))

def get_tts_sync(text):
    return asyncio.run(text_to_speech_async(text))
