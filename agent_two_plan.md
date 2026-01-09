# Agent Two: OSA Expert Core Implementation Plan

## Status: IN PROGRESS
**Author**: Senior Principal Engineer (OSA System)
**Goal**: Create a self-improving expert system using DSPy, Memori, and Rag-Anything.

## Intelligence Layers
1. **Context (Rag-Anything)**: 
   - **Source**: `HKUDS/RAG-Anything`
   - **Role**: Multimodal indexing of the codebase.
   - **Target**: Index all code, diagrams (images), and design docs (PDFs) into a local vector store.

2. **Memory (Memori)**:
   - **Source**: `GibsonAI/Memori`
   - **Role**: SQL-native persistent memory.
   - **Target**: Store user preferences, "lessons learned" from past edits, and codebase invariants in `.osa/memory.db`.

3. **Brain (DSPy)**:
   - **Source**: `Stanford/DSPy`
   - **Role**: Programmatic prompt optimization.
   - **Target**: Optimize signatures for `Architect`, `SecurityExpert`, and `Refactorer` based on successful task outcomes.

## Implementation Roadmap

### Phase 1: Foundation (In Progress)
- [x] Research SOTA frameworks.
- [x] Initialize `osa_expert/` with `uv`.
- [/] Resolve dependency issues (`raganything` name mismatch).
- [ ] Create `osa_expert/src/osa_expert/cli.py` (CLI Bridge).

### Phase 2: Core Layers
- [ ] Implement `memory.py` (Memori integration).
- [ ] Implement `context.py` (Rag-Anything multimodal indexing).
- [ ] Implement `brain.py` (DSPy role signatures).

### Phase 3: OSA Integration
- [ ] Update `llms.txt` with bootstrap protocol.
- [ ] Update `OSA.md` with Expert Loop patterns.
- [ ] Modify `deploy_osaa.sh` to automate deployment.

## Next Step
Fix `uv` dependencies by using the correct package names for `raganything` and `memori`.
