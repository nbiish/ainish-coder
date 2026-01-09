import dspy
from typing import List, Optional, Dict, Any
from .memory import MemoryManager
from .context import ContextManager

class OrchestratorPlanSignature(dspy.Signature):
    """
    You are the OSA Strategic Architect. Based on deep codebase context 
    and past history, design a high-level orchestration plan for a complex task.
    The plan should be optimized for the Ralph-Trunk pattern, delegating work 
    to sub-agents (Gemini, Qwen, Opencode).
    """
    context = dspy.InputField(desc="Codebase architectural context")
    history = dspy.InputField(desc="Relevant lessons learned and past solutions")
    task_request = dspy.InputField(desc="The user's high-level task request")
    
    strategic_plan = dspy.OutputField(desc="A step-by-step strategy for Ralph to execute")
    delegation_directives = dspy.OutputField(desc="Specific instructions for Gemini (Logic) and Qwen (Review/Summary)")

class ExpertBrain:
    def __init__(self, role: str, memory: MemoryManager, context: ContextManager):
        self.role = role
        self.memory = memory
        self.context = context
        
        # Configure DSPy
        lm = dspy.LM('openai/gpt-4o') # Use a stronger model for strategic planning
        dspy.settings.configure(lm=lm)
        
        self.orchestrator_planner = dspy.ChainOfThought(OrchestratorPlanSignature)

    def think(self, request: str) -> Dict[str, str]:
        """
        Think as an architect and provide a strategic plan for Ralph.
        """
        # 1. Retrieve Context from RAG (LightRAG hybrid search)
        rag_context = self.context.query(request, mode="hybrid")
        
        # 2. Retrieve History from Memori (Structured SQL)
        recent_lessons = self.memory.get_recent_lessons(limit=5)
        history_str = "\n".join([
            f"- Issue: {l['user_correction']}\n  Solution: {l['winning_solution']}" 
            for l in recent_lessons
        ]) if recent_lessons else "No prior history available."
        
        # 3. Process through DSPy optimized signatures
        prediction = self.orchestrator_planner(
            context=rag_context,
            history=history_str,
            task_request=request
        )
        
        return {
            "analysis": prediction.strategic_plan,
            "directives": prediction.delegation_directives
        }

    def optimize(self):
        """
        Runs DSPy BootstrapFewShot optimization using successful outcomes from Memori.
        """
        training_data = self.memory.get_training_examples()
        if not training_data:
            print("⚠️ No training data available in Memori for optimization.")
            return

        trainset = [
            dspy.Example(
                context="N/A", # Retrieval handles this at runtime
                history="N/A",
                task_request=item['user_correction'],
                strategic_plan=item['winning_solution'],
                delegation_directives="N/A" # Could be improved with more granular tracking
            ).with_inputs('context', 'history', 'task_request')
            for item in training_data
        ]

        from dspy.teleprompt import BootstrapFewShot
        optimizer = BootstrapFewShot(metric=lambda x, y: True) 
        
        print("🚀 Compiling Expert Brain with DSPy (Self-Improvement)...")
        self.orchestrator_planner = optimizer.compile(self.orchestrator_planner, trainset=trainset)
        print("✅ Optimization complete.")
