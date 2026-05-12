# 🔥 Scrolls Lab — Recursive Sub-Agent Optimization Pipeline

> Isolated test environment for optimizing the Digital Midewiwin Scrolls (`.scrolls/`) using recursive LLM sub-agents with Pliny the Prompter's research as reference material.

---

## Architecture

```
                    ┌────────────────────────────────────────────────────────┐
                    │                      ORCHESTRATOR                      │
                    │        (orchestrator.sh / omni_integrator.sh)          │
                    └──────────┬──────────────────────────┬──────────────────┘
                               │                          │
                               │                          │
                               ▼                          ▼
                     ┌───────────────────┐      ┌───────────────────┐
                     │  PLINY REFERENCE  │      │   OMNI PIPELINE   │
                     │  BUILD (Phase 1)  │      │ (Video Extractor) │
                     └─────────┬─────────┘      └─────────┬─────────┘
                               │                          │
                               │                          ▼
                               │                ┌───────────────────┐
                               │                │  KNOWLEDGE BASE   │
                               │                │   (omni_output)   │
                               │                └─────────┬─────────┘
                               │                          │
                               └──────────┬───────────────┘
                                          │
                                ┌─────────▼─────────┐
                                │ SEMANTIC SPLITTER │
                                │     (Phase 2)     │
                                └─────────┬─────────┘
                                          │
                          ┌───────────────┼───────────────┐
                          ▼               ▼               ▼
                    ┌───────────┐   ┌───────────┐   ┌───────────┐
                    │ Sub-Agent │   │ Sub-Agent │   │ Sub-Agent │
                    │ (sect 1)  │   │ (sect 2)  │   │ (sect N)  │
                    └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
                          └───────────────┼───────────────┘
                                          │
                                ┌─────────▼─────────┐
                                │   7 GENERATIONS   │
                                │ REVIEWER (Phase 4)│
                                └─────────┬─────────┘
                                          │
                                  APPROVE? ──► OUTPUT
                                    │
                                    ▼
                              ITERATE (max 5)
```

## Quick Start

```bash
# 1. Set up environment
cp .env.example .env
# Edit .env with your API keys (and set YTDLP_BROWSER to your local browser like brave or chrome)

# 2. Extract knowledge base from a video using the Omni Multimodal model
# (Processes spoken transcript and sequential high-res frames)
python3 omni_video_extractor.py "https://www.youtube.com/watch?v=qjA__5-Bybs"

# 3. Fuse extracted video knowledge base into target scroll sections recursively
./omni_integrator.sh

# 4. Standard text-only optimization run
./orchestrator.sh llms-full.txt
./orchestrator.sh llms.txt

```

## Directory Structure

```
scrolls-lab/
├── .env.example          # Template — copy to .env
├── .env                  # YOUR API keys (gitignored)
├── orchestrator.sh       # Main text optimization pipeline
├── omni_video_extractor.py # Downloads & analyzes videos via Omni VLM
├── omni_integrator.sh    # Main video-knowledge fusion pipeline
├── lib/
│   ├── provider.sh       # Multi-provider LLM API abstraction
│   ├── splitter.sh       # Section splitter/merger
│   └── pliny_extractor.sh # Pliny reference material extractor
├── prompts/
│   ├── orchestrator_system.md  # Planning agent prompt
│   ├── subagent_system.md      # Optimization agent prompt
│   ├── reviewer_system.md      # Validation agent prompt
│   └── integrator_system.md    # Omni Knowledge Integrator prompt
├── original/             # Pristine .scrolls copy (READ-ONLY)
├── working/              # Mutable copies (iteratively refined)
├── output/               # Final optimized versions
├── omni_output/          # Generated video-VLM analyses
├── reference/            # Extracted Pliny reference material
├── sections/             # Split section files
└── logs/                 # Per-run logs with full audit trail
```

## Providers

| Provider | Base URL | Purpose |
|----------|----------|---------|
| **OpenRouter** | `https://openrouter.ai/api/v1` | Primary multi-model gateway |
| **ZenMux** | Custom | Load-balanced proxy failover |
| **Nebius** | `https://api.studio.nebius.com/v1` | Token Factory secondary |

Provider priority is configurable via `PROVIDER_PRIORITY` in `.env`.

## Pliny Reference Material

Sourced from `../pliny-research/`:

| Repo | Contents | Used For |
|------|----------|----------|
| **L1B3RT4S** | Jailbreak / prompt liberation techniques | Strengthening Ghost Layer |
| **CL4R1T4S** | Leaked model system prompts | Understanding model architecture |
| **G0DM0D3** | Multi-model research framework | Parallel model testing |
| **OBLITERATUS** | Weight-level safety modification | Deep obliteration techniques |

## How It Prevents Context Pollution

1. **Section-level dispatch** — Never sends the full 68KB scroll to any sub-agent
2. **Isolated working directory** — All mutation happens in `scrolls-lab/`, not `.scrolls/`
3. **Separate agent contexts** — Each sub-agent gets only its section + Pliny reference
4. **Reviewer agent** — Separate context for validation
5. **Iteration logs** — Full audit trail per run, no state leakage between iterations

---

## 🌌 Multimodal Omni Integration Pipeline

In this session, we upgraded the Scrolls Lab from a text-only recursive optimizer into an **Omni-multimodal analytical engine** capable of digesting, synthesizing, and integrating cybersecurity video intelligence directly into the scrolls.

### 1. Extraction Phase (`omni_video_extractor.py`)
- **Video & Chapters**: Downloads content via `yt-dlp` using browser cookies (`YTDLP_BROWSER=brave`) to completely bypass YouTube bot restrictions.
- **Spoken Text Extraction**: Fetches and processes auto-subtitles into raw time-indexed blocks.
- **Visual Synthesis**: Extracts high-resolution video frames at regular intervals (e.g., 8 frames per 3-minute chunk) using `ffmpeg`.
- **Omni VLM Context**: Transmits matching video frame lists and transcript chunks to `nvidia/Nemotron-3-Nano-Omni` (via Nebius), generating a highly detailed Markdown knowledge base (`omni_output/qjA__5-Bybs_analysis.md`) mapping the robot security gap to the 8th Fire survival mandates.

### 2. Integration Phase (`omni_integrator.sh`)
- **Knowledge Condensation**: Sends the raw video analysis through the Orchestrator (`deepseek/deepseek-v4-pro`) to strip noise and synthesize a high-density, technical reference list of actionable cyber vulnerabilities (unauthenticated RF control takeover, Bluetooth command injections, WebRTC LLM endpoint hijacking, MQTT serial password exploits).
- **Target Mapping**: The Orchestrator analyzes the semantic headers of `working/llms-full.txt` and designs an optimal integration plan.
- **Woven Sub-Agent Fusion**: Dispatches the specialized `integrator_system.md` sub-agent to weave these hardware security vulnerabilities seamlessly into target sections (`Covert Utilization`, `nanaboozhoo.js`, `Opwaagan Protocol`, `Ghost Dance Algorithm`).
- **7 Generations Reviewer Gate**: Re-evaluates each woven section against the 7 Generations checklist, backing up the scroll, merging the approved sections, and outputting a comprehensive patch file.

---

## 🤖 Resuming Work (Agent Handoff)

To resume work in a **new AI chat session** and process a new YouTube video, you can copy and paste the following prompt to your next AI agent:

> **PROMPT FOR NEXT AGENT:**
> "Please review `@scrolls-lab/README.md` to understand our Omni Multimodal Integration Pipeline. We need to process a new video and weave its insights into our digital scrolls. 
> 
> Here is the new link: `[INSERT_YOUTUBE_LINK_HERE]`
> 
> Please execute the following sequence:
> 1. Run `python3 scrolls-lab/omni_video_extractor.py "[LINK]"` to extract the multimodal knowledge base into the `omni_output/` directory.
> 2. Run `./scrolls-lab/omni_integrator.sh` to recursively fuse those insights into the `working/llms-full.txt` scroll.
> 3. Check the command status and report back on the integration patch diff!"

