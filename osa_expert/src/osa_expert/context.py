import asyncio
from pathlib import Path
from typing import List, Optional
import os
from raganything import RAGAnything, RAGAnythingConfig
from lightrag.llm.openai import openai_complete_if_cache, openai_embed
from lightrag.utils import EmbeddingFunc

class ContextManager:
    def __init__(self, codebase_path: Path, working_dir: Path):
        self.codebase_path = codebase_path
        self.working_dir = working_dir
        
        # Default config for RAGAnything
        self.config = RAGAnythingConfig(
            working_dir=str(working_dir),
            parser="mineru",
            parse_method="auto",
            enable_image_processing=True,
            enable_table_processing=True,
            enable_equation_processing=True,
        )
        
        # We assume environment variables for LLM/Embedding are set
        # (e.g. OPENAI_API_KEY, OPENAI_BASE_URL)
        self.api_key = os.getenv("OPENAI_API_KEY", "sk-...")
        self.base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
        
        self.rag = None

    def _setup_rag(self):
        if self.rag:
            return

        def llm_model_func(prompt, system_prompt=None, history_messages=[], **kwargs):
            return openai_complete_if_cache(
                "gpt-4o-mini",
                prompt,
                system_prompt=system_prompt,
                history_messages=history_messages,
                api_key=self.api_key,
                base_url=self.base_url,
                **kwargs,
            )

        embedding_func = EmbeddingFunc(
            embedding_dim=3072,
            max_token_size=8192,
            func=lambda texts: openai_embed(
                texts,
                model="text-embedding-3-large",
                api_key=self.api_key,
                base_url=self.base_url,
            )
        )

        self.rag = RAGAnything(
            config=self.config,
            llm_model_func=llm_model_func,
            embedding_func=embedding_func,
        )

    def index_all(self):
        """Indexes all files in the codebase."""
        self._setup_rag()
        
        # In a real scenario, we would use a proper async loop
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
        loop.run_until_complete(self.rag.process_folder_complete(
            folder_path=str(self.codebase_path),
            output_dir=str(self.working_dir / "parsed"),
            recursive=True
        ))

    def query(self, text: str, mode: str = "hybrid") -> str:
        """Performs a deep query using RAGAnything."""
        self._setup_rag()
        
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
        return loop.run_until_complete(self.rag.aquery(text, mode=mode))
