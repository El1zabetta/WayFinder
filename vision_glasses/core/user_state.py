import json
import os
import logging

logger = logging.getLogger(__name__)

class UserState:
    """
    Отслеживает текущее эмоциональное и физическое состояние пользователя.
    Сохраняет состояние между сессиями.
    """
    def __init__(self, filepath: str = None):
        self.filepath = filepath
        self.state = self._load_state()

    def _get_default_state(self):
        return {
            "mood": "neutral",      # neutral, happy, stressed, tired
            "energy": "normal",     # high, normal, low
        }

    def _load_state(self):
        if self.filepath and os.path.exists(self.filepath):
            try:
                with open(self.filepath, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                logger.error(f"Ошибка загрузки состояния: {e}")
        return self._get_default_state()

    def save_state(self):
        if self.filepath:
            try:
                with open(self.filepath, 'w', encoding='utf-8') as f:
                    json.dump(self.state, f, ensure_ascii=False, indent=2)
            except Exception as e:
                logger.error(f"Ошибка сохранения состояния: {e}")

    def update(self, user_text: str, context: dict):
        """
        Обновляет состояние на основе правил (Rule-based).
        """
        text = user_text.lower()
        changed = False
        
        # Эвристики для усталости
        if any(w in text for w in ["устал", "спать", "нет сил", "тяжело"]):
            self.state["energy"] = "low"
            self.state["mood"] = "tired"
            changed = True
            
        # Эвристики для радости
        elif any(w in text for w in ["классно", "супер", "рад", "отлично"]):
            self.state["mood"] = "happy"
            changed = True
            
        # Эвристики для стресса
        elif any(w in text for w in ["не успеваю", "проблема", "ошибка", "черт"]):
            self.state["mood"] = "stressed"
            changed = True
            
        if changed:
            self.save_state()

    def get_state_description(self) -> str:
        mood_ru = {
            "neutral": "спокойное",
            "happy": "радостное",
            "stressed": "напряженное",
            "tired": "уставшее"
        }
        return f"Настроение: {mood_ru.get(self.state['mood'], 'обычное')}, Энергия: {self.state['energy']}"
