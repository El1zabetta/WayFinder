import sys
import os
import logging

# Ensure project root is in path to import vision_glasses
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vision_glasses.core.user_memory import UserMemory
from vision_glasses.core.user_state import UserState
from vision_glasses.core.context_manager import ContextManager
from vision_glasses.core.dialog_manager import DialogManager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Brain:
    def __init__(self):
        # Initialize Core Components
        self.memory_file = os.path.join(os.path.dirname(__file__), "user_profile.json")
        self.memory = UserMemory(self.memory_file)
        
        # Determine a state file path
        self.state_file = os.path.join(os.path.dirname(__file__), "user_state.json")
        self.state = UserState(self.state_file)
        
        self.context_manager = ContextManager()
        self.dialog_manager = DialogManager(self.memory, self.state)
        
        logger.info("Brain initialized with Memory, State, and DialogManager.")

    def process(self, text):
        """
        Processes user input using the advanced DialogManager pipeline.
        """
        logger.info(f"Brain processing: {text}")
        
        # 1. Update Context (Simplified for text-only input for now)
        self.context_manager.update_speech(text)
        # Assuming no vision input for this simple text interface yet
        self.context_manager.update_vision(objects=[], ocr_text="") 
        
        context_dict = self.context_manager.build_context_dict()
        
        # 2. Generate Response
        response = self.dialog_manager.generate_response(context_dict)
        
        return response

if __name__ == "__main__":
    # Simple test
    brain = Brain()
    print("Bot: " + brain.process("Привет, меня зовут Алекс"))
    print("Bot: " + brain.process("Который час?"))
