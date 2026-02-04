from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.views import View
from .yolo import model
import cv2
import numpy as np
from PIL import Image
import io

# Маппинг классов на русский
CLASS_NAMES_RU = {
    'person': 'человек',
    'bicycle': 'велосипед',
    'car': 'автомобиль',
    'motorcycle': 'мотоцикл',
    'airplane': 'самолет',
    'bus': 'автобус',
    'train': 'поезд',
    'truck': 'грузовик',
    'boat': 'лодка',
    'traffic light': 'светофор',
    'fire hydrant': 'пожарный гидрант',
    'stop sign': 'знак стоп',
    'parking meter': 'парвокочный автомат',
    'bench': 'скамейка',
    'bird': 'птица',
    'cat': 'кошка',
    'dog': 'собака',
    'horse': 'лошадь',
    'sheep': 'овца',
    'cow': 'корова',
    'elephant': 'слон',
    'bear': 'медведь',
    'zebra': 'зебра',
    'giraffe': 'жираф',
    'backpack': 'рюкзак',
    'umbrella': 'зонтик',
    'handbag': 'сумка',
    'tie': 'галстук',
    'suitcase': 'чемодан',
    'frisbee': 'фрисби',
    'skis': 'лыжи',
    'snowboard': 'сноуборд',
    'sports ball': 'мяч',
    'kite': 'воздушный змей',
    'baseball bat': 'бейсбольная бита',
    'baseball glove': 'бейсбольная перчатка',
    'skateboard': 'скейтборд',
    'surfboard': 'серфборд',
    'tennis racket': 'теннисная ракетка',
    'bottle': 'бутылка',
    'wine glass': 'бокал вина',
    'cup': 'чашка',
    'fork': 'вилка',
    'knife': 'нож',
    'spoon': 'ложка',
    'bowl': 'миска',
    'banana': 'банан',
    'apple': 'яблоко',
    'sandwich': 'сэндвич',
    'orange': 'апельсин',
    'broccoli': 'брокколи',
    'carrot': 'морковь',
    'hot dog': 'хот-дог',
    'pizza': 'пицца',
    'donut': 'пончик',
    'cake': 'торт',
    'chair': 'стул',
    'couch': 'диван',
    'potted plant': 'растение в горшке',
    'bed': 'кровать',
    'dining table': 'обеденный стол',
    'toilet': 'туалет',
    'tv': 'телевизор',
    'laptop': 'ноутбук',
    'mouse': 'мышь',
    'remote': 'пульт',
    'keyboard': 'клавиатура',
    'cell phone': 'телефон',
    'microwave': 'микроволновка',
    'oven': 'печь',
    'toaster': 'тостер',
    'sink': 'раковина',
    'refrigerator': 'холодильник',
    'book': 'книга',
    'clock': 'часы',
    'vase': 'ваза',
    'scissors': 'ножницы',
    'teddy bear': 'плюшевый мишка',
    'hair drier': 'фен',
    'toothbrush': 'зубная щетка'
}

@method_decorator(csrf_exempt, name='dispatch')
class DetectAPIView(View):
    def post(self, request, *args, **kwargs):
        if 'image' not in request.FILES:
            return JsonResponse({'message': 'Нет изображения'}, status=400)

        # Читаем изображение
        image_file = request.FILES['image']
        image_bytes = image_file.read()
        
        # Конвертируем в OpenCV формат
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            return JsonResponse({'message': 'Ошибка обработки изображения'}, status=400)

        # Preprocessing для улучшения распознавания
        # 1. Resize если изображение слишком большое (оптимизация)
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

        # Детекция (понижаем confidence для лучшего обнаружения)
        results = model.predict(img, conf=0.3, iou=0.45)
        
        detected_objects = []
        for result in results:
            for box in result.boxes:
                class_id = int(box.cls[0])
                class_name = model.names[class_id]
                ru_name = CLASS_NAMES_RU.get(class_name, class_name)
                if ru_name not in detected_objects:
                    detected_objects.append(ru_name)

        if not detected_objects:
            message = "Путь свободен"
        else:
            message = "Впереди: " + ", ".join(detected_objects)

        return JsonResponse({'message': message})


from .services import speech_to_text, analyze_image_local, generate_ai_response_async, text_to_speech_async, read_text_local, detect_objects_local
from .models import VisionUser
import base64
import json
from asgiref.sync import sync_to_async

@method_decorator(csrf_exempt, name='dispatch')
class SmartAnalyzeView(View):
    async def post(self, request, *args, **kwargs):
        import asyncio
        
        # 1. Проверка аутентификации (опционально для совместимости)
        user = None
        if request.user.is_authenticated:
            user = request.user
            # Проверка лимитов
            if not await sync_to_async(user.can_make_request)():
                return JsonResponse({
                    'error': 'Daily limit reached',
                    'subscription_type': user.subscription_type,
                    'upgrade_message': 'Upgrade to Premium for unlimited requests'
                }, status=429)
        
        # 2. Получаем данные
        image_file = request.FILES.get('image')
        audio_file = request.FILES.get('audio')
        text_input = request.POST.get('text', '')
        user_id = request.POST.get('user_id', 'anonymous')
        mode = request.POST.get('mode', 'chat') # 'chat' or 'navigator'

        # 3. Получаем пользователя (для обратной совместимости с Telegram)
        user_tuple = await sync_to_async(VisionUser.objects.get_or_create)(telegram_id=user_id)
        vision_user = user_tuple[0]

        # Подготовка тасков
        stt_task = None
        vision_task = None
        image_bytes = None

        # Запускаем STT
        if audio_file:
            # Важно: если audio_file это InMemoryUploadedFile, передача его в другой поток может быть tricky,
            # но faster_whisper обычно принимает путь или file-like.
            # Для надежности читаем в BytesIO если это не путь
            stt_task = sync_to_async(speech_to_text)(audio_file)

        # Подготовка изображения (Resize)
        if image_file:
            image_bytes = image_file.read()
            # Оптимизация размера ПЕРЕД отправкой в модели (снижаем нагрузку на BLIP/OCR)
            # Сделаем resize тут, в памяти
            def optimize_image(img_data):
                nparr = np.frombuffer(img_data, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                if img is None: return img_data
                
                # Max dimension 640 for speed
                max_dim = 640
                h, w = img.shape[:2]
                if max(h, w) > max_dim:
                    scale = max_dim / max(h, w)
                    img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
                    # Encode back to bytes
                    _, encoded_img = cv2.imencode('.jpg', img, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
                    return encoded_img.tobytes()
                return img_data

            # Запускаем оптимизацию и Vision параллельно
            # Но Vision требует байты. Лучше сначала оптимизировать (быстро), потом Vision.
            # optimize_image - CPU bound, sync.
            image_bytes = await sync_to_async(optimize_image)(image_bytes)

            if mode == 'navigator':
                 # Fast YOLO only
                 # Мы можем запустить это сразу
                 vision_task = sync_to_async(detect_objects_local)(image_bytes)
            else:
                 # BLIP
                 vision_task = sync_to_async(analyze_image_local)(image_bytes)

        # Запускаем задачи параллельно
        # Структура tasks: [stt_task (optional), yolo_task (optional), blip_task (optional)]
        tasks = []
        task_map = {} # map task name to index

        if stt_task:
            task_map['stt'] = len(tasks)
            tasks.append(stt_task)
            
        if image_bytes:
            # Always run YOLO for HUD info
            yolo_task = sync_to_async(detect_objects_local)(image_bytes)
            task_map['yolo'] = len(tasks)
            tasks.append(yolo_task)
            
            if mode != 'navigator':
                blip_task = sync_to_async(analyze_image_local)(image_bytes)
                task_map['blip'] = len(tasks)
                tasks.append(blip_task)

        results = await asyncio.gather(*tasks)

        # Разбираем результаты
        transcript = results[task_map['stt']] if 'stt' in task_map else None
        
        # YOLO result: list of strings
        detected_objects = results[task_map['yolo']] if 'yolo' in task_map else []
        
        # BLIP result: string description
        visual_description = results[task_map['blip']] if 'blip' in task_map else None
        
        # Обновляем текст
        if transcript:
            text_input = f"{text_input} {transcript}".strip()

        # Если режим навигатора - возвращаем быстрый ответ
        if mode == 'navigator':
            if detected_objects:
                 response_text = ", ".join(detected_objects)
            else:
                 response_text = "Путь свободен"
            
            return JsonResponse({
                'message': response_text, 
                'audio': None,
                'detected_objects': detected_objects
            })

        # Режим чата
        visual_description = visual_result
        ocr_text = None

        # Теперь, имея полный текст, решаем про OCR
        # OCR все еще может быть долгой, но она нужна только по запросу
        if image_bytes and any(w in text_input.lower() for w in ['читай', 'прочти', 'текст', 'написано', 'цифры']):
             ocr_text = await sync_to_async(read_text_local)(image_bytes)

        if not text_input:
             # Если текста нет, но есть картинка -> "Что изображено?"
             if visual_description:
                 text_input = "Что изображено?"
             else:
                 return JsonResponse({'message': 'Не удалось распознать запрос.', 'audio': None})

        # Сохраняем запрос
        if vision_user:
            await sync_to_async(vision_user.add_message)("user", text_input)

        # 5. LLM - передаем vision_user только если он существует
        response_text = await generate_ai_response_async(
            text_input, 
            visual_context=visual_description, 
            user_obj=vision_user if vision_user else None,
            ocr_context=ocr_text
        )

        # Сохраняем ответ
        if vision_user:
            await sync_to_async(vision_user.add_message)("assistant", response_text)
        
        # Увеличиваем счетчик для аутентифицированных пользователей
        if user:
            await sync_to_async(user.increment_request_count)()

        # 6. TTS with Mood
        mood = vision_user.facts.get('mood', 'neutral') if vision_user else 'neutral'
        audio_content = await text_to_speech_async(response_text, mood=mood)
        audio_b64 = None
        if audio_content:
            audio_b64 = base64.b64encode(audio_content).decode('utf-8')

        return JsonResponse({
            'message': response_text,
            'audio': audio_b64,
            'debug_vision': visual_description,
            'detected_objects': detected_objects
        })

def index(request):
    from django.shortcuts import render
    return render(request, 'index.html')


@method_decorator(csrf_exempt, name='dispatch')
class NavigationView(View):
    """
    Endpoint для навигации.
    Принимает голосовой запрос типа "как дойти до Турусбекова 109"
    и возвращает инструкции для навигации.
    """
    async def post(self, request, *args, **kwargs):
        audio_file = request.FILES.get('audio')
        text_input = request.POST.get('text', '')
        user_id = request.POST.get('user_id', 'anonymous')
        current_lat = request.POST.get('current_lat')
        current_lon = request.POST.get('current_lon')
        
        # Получаем пользователя
        user_tuple = await sync_to_async(VisionUser.objects.get_or_create)(telegram_id=user_id)
        user = user_tuple[0]
        
        # Обработка аудио
        if audio_file:
            transcript = await sync_to_async(speech_to_text)(audio_file)
            if transcript:
                text_input = f"{text_input} {transcript}".strip()
        
        if not text_input:
            return JsonResponse({'error': 'No input provided'}, status=400)
        
        # Используем AI для извлечения адреса из запроса
        destination = await self._extract_destination(text_input)
        
        if not destination:
            response_text = "Извините, я не смог определить адрес назначения. Попробуйте сказать, например: 'Как дойти до улицы Турусбекова, дом 109'"
            audio_content = await text_to_speech_async(response_text)
            audio_b64 = base64.b64encode(audio_content).decode('utf-8') if audio_content else None
            return JsonResponse({
                'message': response_text,
                'audio': audio_b64,
                'destination': None
            })
        
        # Возвращаем адрес для построения маршрута на клиенте
        # Клиент использует NavigationService для построения маршрута
        response_text = f"Строю маршрут до {destination}. Подождите..."
        audio_content = await text_to_speech_async(response_text)
        audio_b64 = base64.b64encode(audio_content).decode('utf-8') if audio_content else None
        
        return JsonResponse({
            'message': response_text,
            'audio': audio_b64,
            'destination': destination,
            'action': 'build_route'
        })
    
    async def _extract_destination(self, text):
        """
        Использует AI для извлечения адреса из естественного языка.
        """
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            # Fallback: простой парсинг
            return self._simple_address_extraction(text)
        
        base_url = "https://api.deepseek.com"
        model_name = "deepseek-chat"
        if api_key.startswith("sk-or-v1"):
            base_url = "https://openrouter.ai/api/v1"
            model_name = "deepseek/deepseek-chat"
        
        from openai import AsyncOpenAI
        client = AsyncOpenAI(api_key=api_key, base_url=base_url)
        
        try:
            response = await client.chat.completions.create(
                model=model_name,
                messages=[
                    {
                        "role": "system",
                        "content": "Ты помощник для извлечения адресов. Извлеки адрес назначения из запроса пользователя. Верни ТОЛЬКО адрес, без дополнительного текста. Если адрес не найден, верни 'NOT_FOUND'."
                    },
                    {
                        "role": "user",
                        "content": f"Запрос: {text}"
                    }
                ],
                max_tokens=100
            )
            
            result = response.choices[0].message.content.strip()
            if result == 'NOT_FOUND' or not result:
                return None
            return result
        except Exception as e:
            logger.error(f"AI address extraction error: {e}")
            return self._simple_address_extraction(text)
    
    def _simple_address_extraction(self, text):
        """
        Простое извлечение адреса по ключевым словам.
        """
        import re
        
        # Паттерны для поиска адресов
        patterns = [
            r'до\s+(.+?)(?:\s+дом\s+\d+|\s+\d+)?$',
            r'на\s+(.+?)(?:\s+дом\s+\d+|\s+\d+)?$',
            r'улиц[аы]\s+(.+?)(?:\s+дом\s+\d+|\s+\d+)?$',
        ]
        
        text_lower = text.lower()
        for pattern in patterns:
            match = re.search(pattern, text_lower)
            if match:
                return match.group(1).strip()
        
        return None
