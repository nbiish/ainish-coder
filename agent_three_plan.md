# Agent Three: SOTA Expert System Integration Plan

## Research & Knowledge Base

### 1. The SOTA Stack (2026)
- **Intelligence Core**: `DSPy` (`dspy-ai`). Programmatic Prompt Optimization. Defines agent "Signatures" that are compiled into optimized instructions.
- **Context Layer**: `LightRAG` (`lightrag-hku`). Knowledge Graph-based RAG.
    - **Hybrid Retrieval**: Balances Local (entities) and Global (architecture) context.
    - **Multimodal**: Integrates `Rag-Anything` for image/document parsing.
- **Memory Layer**: `Memori` (GibsonAI). SQL-native persistence for "Cognitive Continuity".
- **Interoperability Layer**: 
    - **MCP (Model Context Protocol)**: The "Hands". Exposes the LightRAG Knowledge Graph and Memori as tools.
    - **Agent Skills (Anthropic Standard)**: The "Instruction Manual". Packages OSA orchestration patterns (Sequential, Parallel, Loop) into a portable standard that any agent can "load".
- **Bootstrapping**: `llms.txt`. The Project Manifest and entry point.

### 2. Propositions for OSA 4.0

#### A. The "Skills + MCP" Hybrid Architecture
We will not just build a tool; we will build a **Portable Expert**.
- **The Skills**: A `osa-skills.json` (following the open Agent Skills standard) that defines the expert procedures for code refactoring, security audits, and orchestration.
- **The Tools**: An MCP server that allows the agent to `query_knowledge_graph` and `retrieve_memory`.

#### B. The "Cognitive Memory" Feedback Loop
We will define a custom SQL schema in Memori to track **"Lessons Learned"**:
| Field | Purpose |
|-------|---------|
| `context_hash` | Unique ID for the code state |
| `user_correction` | What the user asked to fix |
| `winning_solution` | The code that eventually passed tests |
| `dspy_example` | Boolean: Is this suitable for DSPy few-shot training? |

#### C. The @llms.txt Agent Manifest
`llms.txt` will now serve as the **Bootloader**:
```markdown
# Project Manifest
[BOOTSTRAP]: `ainish-coder --osa --init`
[SKILLS]: `./.osa/skills/osa-expert.json`
[MCP]: `npx osa-mcp-server`
```

## The Plan: Step-by-Step

### 1. Foundation (Python & Environment)
- Create `osa_expert/` as a modular Python package.
- Use `uv` for dependency management.
- Initialize `.osa/` for state (SQLite, Knowledge Graph, Agent Skills).

### 2. Knowledge Graph & MCP
- Implement `context.py` using `LightRAG`.
- Create a lightweight MCP server wrapper to expose LightRAG tools.

### 3. Memory & Skills
- Implement `memory.py` using `Memori`.
- Author the `osa-expert.json` Agent Skills file.

### 4. Reasoning Core
- Implement `brain.py` with DSPy Signatures.
- Create `optimizer.py` to refine skills based on Memori logs.

### 5. Deployment Molecule
- Update `dna/molecules/deploy_osa.sh` to automate the deployment of the Expert Core and the initialization of the Agent Skills.

---
*Status: Research complete. Ready to build the "Portable Expert" architecture.*
