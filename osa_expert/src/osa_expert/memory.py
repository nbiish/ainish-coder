from pathlib import Path
from typing import Optional, List, Dict, Any
from memori import Memori
import sqlite3
import os

class MemoryManager:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.memori = Memori()
        # Initialize the underlying SQLite connection for "Lessons Learned"
        self.conn = sqlite3.connect(db_path)
        self._create_tables()

    def _create_tables(self):
        cursor = self.conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS lessons_learned (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                context_hash TEXT,
                user_correction TEXT,
                winning_solution TEXT,
                dspy_example BOOLEAN DEFAULT 0,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS interactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task TEXT,
                outcome TEXT,
                lesson TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        self.conn.commit()

    def initialize(self):
        # Memori specific initialization if needed
        pass

    def add_interaction(self, task: str, outcome: str, lesson: Optional[str] = None):
        cursor = self.conn.cursor()
        cursor.execute(
            "INSERT INTO interactions (task, outcome, lesson) VALUES (?, ?, ?)",
            (task, outcome, lesson)
        )
        self.conn.commit()
        
        # If lesson is provided, also treat it as a potential fact for Memori
        if lesson:
            # We can use Memori's attribution or fact extraction here if we had an LLM client
            # For now, we store it in our structured table
            pass

    def add_lesson(self, context_hash: str, user_correction: str, winning_solution: str, dspy_example: bool = False):
        cursor = self.conn.cursor()
        cursor.execute(
            "INSERT INTO lessons_learned (context_hash, user_correction, winning_solution, dspy_example) VALUES (?, ?, ?, ?)",
            (context_hash, user_correction, winning_solution, 1 if dspy_example else 0)
        )
        self.conn.commit()

    def get_recent_lessons(self, limit: int = 5) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT context_hash, user_correction, winning_solution FROM lessons_learned ORDER BY timestamp DESC LIMIT ?",
            (limit,)
        )
        columns = [column[0] for column in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]

    def get_training_examples(self) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute(
            "SELECT user_correction, winning_solution FROM lessons_learned WHERE dspy_example = 1"
        )
        columns = [column[0] for column in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]
