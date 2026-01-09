import asyncio
from typing import Optional, List, Dict, Any
from mcp.server.fastmcp import FastMCP
from pathlib import Path
from .memory import MemoryManager
from .context import ContextManager
from .brain import ExpertBrain

# Initialize FastMCP server
mcp = FastMCP("osa-expert")

# Paths (assumed to be relative to the codebase root)
OSA_DIR = Path(".osa")
CODEBASE_PATH = Path(".")

# Managers (initialized lazily)
_memory: Optional[MemoryManager] = None
_context: Optional[ContextManager] = None
_brain: Optional[ExpertBrain] = None

def get_managers():
    global _memory, _context, _brain
    if not OSA_DIR.exists():
        OSA_DIR.mkdir(exist_ok=True)
    
    if _memory is None:
        _memory = MemoryManager(OSA_DIR / "memory.db")
    if _context is None:
        _context = ContextManager(CODEBASE_PATH, OSA_DIR / "vector_store")
    return _memory, _context

@mcp.tool()
def query_expert_strategy(query: str, role: str = "Architect") -> Dict[str, str]:
    """
    Query the Expert Core for a high-level strategic plan and sub-agent directives.
    Returns a 'strategic_plan' for the Trunk Orchestrator and 'directives' for sub-agents.
    """
    global _brain
    memory, context = get_managers()
    
    if _brain is None:
        _brain = ExpertBrain(role, memory, context)
    
    return _brain.think(query)

@mcp.tool()
def store_lesson_learned(user_correction: str, winning_solution: str, context_hash: Optional[str] = None):
    """
    Store a lesson learned from a user correction. 
    This helps the expert system improve its future recommendations.
    """
    memory, _ = get_managers()
    memory.add_lesson(
        context_hash=context_hash or "manual",
        user_correction=user_correction,
        winning_solution=winning_solution,
        dspy_example=True
    )
    return "✅ Lesson stored in Memori."

@mcp.tool()
def retrieve_recent_memory(limit: int = 5) -> List[Dict[str, Any]]:
    """
    Retrieve recent interactions and lessons learned from the expert's memory.
    """
    memory, _ = get_managers()
    return memory.get_recent_lessons(limit=limit)

if __name__ == "__main__":
    mcp.run()
