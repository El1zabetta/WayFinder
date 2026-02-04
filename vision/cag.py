import logging
from datetime import datetime
from .models import VisionUser
from .vector_memory import VectorMemory
import os

logger = logging.getLogger(__name__)

class CAGSystem:
    """
    Context-Affect-Guidance Orchestrator with RAG support
    """
    def __init__(self, user: VisionUser):
        self.user = user
        # Path for vector memory storage
        base_path = os.path.dirname(os.path.abspath(__file__))
        storage_path = os.path.join(base_path, "..", "data", "memory", str(self.user.id))
        self.vector_memory = VectorMemory(storage_path)
        
        # Инициализация фактов, если пусто
        if not self.user.facts:
            self.user.facts = {
                "name": None,
                "interests": [],
                "mood": "neutral",
                "energy": "normal"
            }

    def update_state(self, user_text: str):
        """Обновляет аффективное состояние и долгосрочную память"""
        text = user_text.lower()
        facts = self.user.facts
        
        # 1. Affective State
        if any(w in text for w in ["устал", "спать", "нет сил", "тяжело"]):
            facts["mood"] = "tired"
            facts["energy"] = "low"
        elif any(w in text for w in ["круто", "спасибо", "рад", "отлично"]):
            facts["mood"] = "happy"
            facts["energy"] = "high"
            
        # 2. Extract Facts for Vector Memory
        # Пример: "У меня есть собака по кличке Шарик"
        if any(w in text for w in ["у меня есть", "я люблю", "меня зовут", "мой адрес"]):
            self.vector_memory.add_fact(user_text)

        # 3. Update Name
        if "меня зовут" in text and "как" not in text:
            parts = text.split(" зовут ")
            if len(parts) > 1:
                name_part = parts[1].strip()
                name = name_part.split()[0].capitalize()
                facts["name"] = name

        self.user.facts = facts
        self.user.save()

    def determine_situation(self):
        # Простая эвристика времени суток
        hour = datetime.now().hour
        if 6 <= hour < 12:
            return "утро"
        elif 12 <= hour < 18:
            return "день"
        elif 18 <= hour < 23:
            return "вечер"
        else:
            return "ночь"

    def build_system_prompt(self, visual_context=None, user_query: str = "") -> str:
        """Собирает системный промпт для LLM с учетом RAG"""
        f = self.user.facts
        situation = self.determine_situation()
        time_str = datetime.now().strftime("%H:%M")
        
        # 1. RAG: Получаем релевантный контекст
        rag_context = ""
        if user_query:
            rag_context = self.vector_memory.get_context_string(user_query)
        
        # 2. Личность и Ситуация
        prompt = (
            "Ты — WayFinder (A-Vision), умный помощник в очках для незрячих. "
            "Твоя цель — быть глазами пользователя: описывать мир, читать тексты, помогать ориентироваться.\n"
            "Отвечай кратко (1-3 предложения), живо и с эмпатией.\n"
            f"Сейчас {situation}, время {time_str}.\n\n"
        )
        
        # 3. Профиль пользователя
        if f.get("name"):
            prompt += f"Пользователя зовут {f['name']}. Обращайся по имени, когда это уместно.\n"
        
        # 4. Состояние (Affect)
        mood_map = {
            "tired": "У пользователя мало сил. Предлагай простые решения, будь мягче.", 
            "happy": "Пользователь в хорошем настроении. Поддерживай позитив!",
            "neutral": ""
        }
        prompt += f"{mood_map.get(f.get('mood', 'neutral'), '')}\n"
        
        # 5. RAG Context
        if rag_context:
            prompt += f"\nИНФОРМАЦИЯ ИЗ ПАМЯТИ:\n{rag_context}\n"
            
        # 6. Визуальный контекст
        if visual_context:
            prompt += f"\nТЫ ВИДИШЬ (КАМЕРА): {visual_context}\n"
        else:
            prompt += "\nТЫ ВИДИШЬ: (изображение недоступно или неясно)\n"
            
        prompt += "\nИнструкция: Если спросят 'что ты видишь', опиши сцену. Если команда навигации — дай четкие инструкции. Если просто беседа — поддержи разговор."
        
        return prompt
