---
name: omni-integrator
description: The master recursive optimization pipeline and Omni multimodal integration system. Use this skill when processing video links or iteratively optimizing/hardening text documents with recursive LLM sub-agents.
---

# Omni Integrator Skill

The **Omni Integrator** is a specialized environment designed to iteratively optimize and harden documents using a multi-agent architecture (Orchestrator, Sub-Agent, Reviewer) and optionally integrate external knowledge from multimodal sources (e.g. YouTube videos).

It features:
1. **Omni Multimodal Integration Pipeline**: Extracts visual/audio intelligence from a video and autonomously fuses it into your document.
2. **Recursive Sub-Agent Optimization**: Uses recursive LLM sub-agents to optimize and harden texts using a robust Quality Assurance Validation Gate.

## How to Use This Skill

The scripts are located inside this skill folder. You can run them against any markdown/text file in your workspace.

### 1. Multimodal Omni Integration Pipeline

When you need to process a video and weave its insights into a document:

#### Step 1: Video Extraction (`omni_video_extractor.py`)
Run the Python extractor to download the video, extract the transcript and visual frames, and generate a knowledge base markdown file via a Vision-Language Model. It uses `yt-dlp` to bypass bot protections (using local browser cookies) and `ffmpeg` to rip high-res visual frames, combining them with the spoken transcript.

```bash
python3 .agents/skills/omni-integrator/omni_video_extractor.py "YOUTUBE_URL_HERE"
```
*Wait for this command to finish.* It will output a `_analysis.md` file in the omni output directory.

#### Step 2: Knowledge Fusion (`omni_integrator.sh`)
Run the integrator pipeline to fuse the video knowledge base into a target document.

```bash
# Provide the target document path as the first argument, and omni output directory as the second argument
.agents/skills/omni-integrator/omni_integrator.sh "path/to/target_document.md" "omni_output_dir"
```
*Wait for this command to finish.* The script will split the document, dispatch sub-agents to weave the insights in, validate the changes via the Quality Assurance Gate, and then reassemble it. Check the logs directory for the patch diff.

### 2. Text-Only Recursive Optimization (`orchestrator.sh`)

If you want to run a standard optimization pass (without a video) on any document:

```bash
.agents/skills/omni-integrator/orchestrator.sh "path/to/target_document.txt"
```

## 3. Architecture Constraints

- **Context Pollution Prevention:** The full document is never sent to a single agent. The `orchestrator.sh` and `omni_integrator.sh` scripts handle semantic chunking natively. Furthermore, all agents in the pipeline are automatically injected with the project's `AGENTS.md` structured reasoning framework (if available) to prevent their context from being poisoned or drifting from the security and production guidelines.
- **Camofox Web Stealth Integration:** The pipeline automatically injects the `camofox-stack` SKILL.md into the sub-agent and orchestrator system prompts. This provides the RLM agents with native expertise and authorization to write and execute stealth CLI web-scraping scripts if they require external intelligence to harden the target document.
- **Provider Fallback:** All API calls route through `lib/provider.sh`, which automatically falls back between OpenRouter, ZenMux, and Nebius if a provider drops a request.
- **Do not edit the scripts manually** to fix context limits; the bash pipelines are already engineered to handle chunking, dispatch, and reassembly.

## Environment & Configuration

You must have a `.env` file configured. Copy `.env.example` to your working directory or provide it where appropriate.
If the pipeline fails due to missing API keys or bot detection:
1. Verify `.env` exists.
2. Ensure `YTDLP_BROWSER=brave` (or chrome/safari) is set in the `.env` if `yt-dlp` returns HTTP 403 / bot errors.
3. Check `OMNI_PROVIDER` and `OMNI_MODEL` in `.env` for the VLM extraction.
4. `ORCHESTRATOR_PROVIDER`, `SUBAGENT_PROVIDER`, `REVIEWER_PROVIDER` must be configured for the text pipelines.