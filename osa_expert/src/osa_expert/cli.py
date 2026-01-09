import typer
import os
from pathlib import Path
from typing import Optional
from .memory import MemoryManager
from .context import ContextManager
from .brain import ExpertBrain

app = typer.Typer(help="OSA Expert Core CLI")

@app.command()
def bootstrap(
    path: Path = typer.Option(Path("."), help="Path to the codebase to index"),
    force: bool = typer.Option(False, help="Force re-indexing if .osa already exists")
):
    """
    Bootstrap the OSA Expert environment for a codebase.
    Indexes the code, documents, and images using Rag-Anything.
    """
    typer.echo(f"🚀 Bootstrapping OSA Expert for: {path.absolute()}")
    
    osa_dir = path / ".osa"
    if osa_dir.exists() and not force:
        typer.echo("⚠️  .osa directory already exists. Use --force to re-bootstrap.")
        return

    osa_dir.mkdir(exist_ok=True)
    
    # Initialize Memory
    typer.echo("🧠 Initializing Long-term Memory (Memori)...")
    memory = MemoryManager(osa_dir / "memory.db")
    memory.initialize()
    
    # Initialize Context (RAG)
    typer.echo("📚 Indexing Codebase (Rag-Anything)...")
    context = ContextManager(path, osa_dir / "vector_store")
    context.index_all()
    
    typer.echo("✅ OSA Expert initialized successfully!")

@app.command()
def query(
    text: str = typer.Argument(..., help="The query or question for the Expert Core"),
    role: str = typer.Option("Architect", help="The expert role to assume")
):
    """
    Query the Expert Core for deep codebase intelligence.
    Uses RAG context, Memori history, and DSPy reasoning.
    """
    typer.echo(f"🔍 Querying as {role}: {text}")
    
    osa_dir = Path(".osa")
    if not osa_dir.exists():
        typer.echo("❌ .osa not found. Please run 'osa-expert bootstrap' first.")
        raise typer.Exit(1)
        
    # Load state
    memory = MemoryManager(osa_dir / "memory.db")
    context = ContextManager(Path("."), osa_dir / "vector_store")
    brain = ExpertBrain(role, memory, context)
    
    result = brain.think(text)
    typer.echo("\n--- Expert Analysis ---")
    typer.echo(result)

@app.command()
def commit(
    task: str = typer.Argument(..., help="The task completed"),
    outcome: str = typer.Option("Success", help="The outcome of the task"),
    lesson: Optional[str] = typer.Option(None, help="Key lesson learned for Memori"),
    optimize: bool = typer.Option(True, help="Mark this lesson for DSPy optimization")
):
    """
    Commit new knowledge or task outcomes to Memori.
    Helps the system improve over time.
    """
    typer.echo(f"💾 Committing task: {task}")
    
    osa_dir = Path(".osa")
    memory = MemoryManager(osa_dir / "memory.db")
    
    if lesson:
        # If it's a specific lesson with a correction/solution, use the structured format
        # For simplicity in CLI, we'll treat 'task' as context/request if lesson is present
        memory.add_lesson(
            context_hash="cli",
            user_correction=task,
            winning_solution=lesson,
            dspy_example=optimize
        )
    else:
        memory.add_interaction(task, outcome, lesson)
    
    typer.echo("✅ Knowledge committed to Memori.")

@app.command()
def optimize():
    """
    Trigger the DSPy optimization loop using lessons stored in Memori.
    """
    typer.echo("🚀 Starting Self-Improvement Loop...")
    
    osa_dir = Path(".osa")
    if not osa_dir.exists():
        typer.echo("❌ .osa not found. Please run 'osa-expert bootstrap' first.")
        raise typer.Exit(1)
        
    memory = MemoryManager(osa_dir / "memory.db")
    context = ContextManager(Path("."), osa_dir / "vector_store")
    brain = ExpertBrain("Architect", memory, context)
    
    brain.optimize()
    typer.echo("✨ Self-improvement complete. Expert signatures are now more refined.")

if __name__ == "__main__":
    app()
