import logging
import os
import io
from vision.tts_system.manager import TTSManager
from vision.tts_system.config import TTSConfig

logger = logging.getLogger(__name__)

class TTSBrain:
    """
    Фасад для TTSManager. Обеспечивает обратную совместимость с text_to_speech_async,
    возвращая байты, но внутри использует файловую систему и KaniTTS.
    """
    
    @classmethod
    async def speak(cls, text: str, mood: str = "neutral") -> bytes:
        """
        Генерирует речь и возвращает байты (WAV).
        """
        manager = TTSManager() # Singleton, загрузит модель если надо
        
        # 1. Генерируем файл
        # Возвращает URL типа /media/tts/file.wav
        media_url = await manager.generate_speech(text, mood=mood)
        
        if not media_url:
            return None
            
        # 2. Получаем физический путь из URL
        # media_url = /media/tts/xyz.wav
        # filename = xyz.wav
        filename = media_url.split('/')[-1]
        file_path = os.path.join(TTSConfig.OUTPUT_PATH, filename)
        
        # 3. Читаем файл в байты (для совместимости с views.py)
        try:
            with open(file_path, 'rb') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading generated TTS file: {e}")
            return None

