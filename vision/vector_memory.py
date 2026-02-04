import os
import json
import logging
import numpy as np
from typing import List, Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)

class VectorMemory:
    """
    Упрощенная векторная память на основе косинусного сходства.
    В будущем может быть заменена на ChromaDB или FAISS.
    """
    def __init__(self, persistence_path: str):
        self.persistence_path = persistence_path
        self.kb_path = os.path.join(persistence_path, "knowledge_base.json")
        self.data = self._load()
        
    def _load(self):
        if os.path.exists(self.kb_path):
            with open(self.kb_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        return []

    def _save(self):
        os.makedirs(self.persistence_path, exist_ok=True)
        with open(self.kb_path, 'w', encoding='utf-8') as f:
            json.dump(self.data, f, ensure_ascii=False, indent=2)

    def add_fact(self, text: str, metadata: Dict[str, Any] = None):
        """Добавляет факт в базу знаний."""
        entry = {
            "text": text,
            "metadata": metadata or {},
            "timestamp": datetime.now().isoformat(),
            # В реальном приложении здесь был бы эмбеддинг
        }
        self.data.append(entry)
        self._save()
        logger.info(f"Добавлен новый факт в память: {text[:50]}...")

    def search(self, query: str, top_k: int = 3) -> List[Dict[str, Any]]:
        """
        Поиск релевантных фактов. 
        Пока реализован простой текстовый поиск (в будущем - векторный).
        """
        query_words = set(query.lower().split())
        scored_results = []
        
        for entry in self.data:
            text = entry["text"].lower()
            score = sum(1 for word in query_words if word in text)
            if score > 0:
                scored_results.append((score, entry))
        
        # Сортировка по весу
        scored_results.sort(key=lambda x: x[0], reverse=True)
        return [res[1] for res in scored_results[:top_k]]

    def get_context_string(self, query: str) -> str:
        results = self.search(query)
        if not results:
            return ""
        
        context = "Известные факты из прошлого:\n"
        for i, res in enumerate(results):
            context += f"{i+1}. {res['text']}\n"
        return context
