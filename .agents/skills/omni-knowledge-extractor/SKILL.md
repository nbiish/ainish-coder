---
name: omni-knowledge-extractor
description: Extracts high-fidelity multimodal knowledge bases from YouTube videos by combining spoken transcripts with sequential visual frames using an Omni VLM.
---

# Omni Knowledge Extractor Skill

The **Omni Knowledge Extractor** is a standalone, multimodal data extraction pipeline. It solves the problem of "lossy" video transcription by combining exact spoken subtitles with sequential visual frames and running both through an Omni Vision-Language Model (VLM) like `Nemotron-3-Nano-Omni` or `Gemini-2.5-Pro`.

This allows agents to build incredibly deep, contextual markdown knowledge bases from high-level technical presentations, lectures, and documentaries where the visuals (slides, terminal screens, diagrams) are just as important as the spoken words.

## Capabilities

- **Bot Protection Bypass:** Uses `yt-dlp` with browser cookies to bypass YouTube's aggressive bot protections.
- **Multimodal Context:** Downloads auto-subtitles (via `.vtt` parsing) and exact visual frames (via `ffmpeg`).
- **Semantic Chunking:** Splits videos into chapters (or 3-minute chunks) and processes them sequentially to avoid context limits.
- **Actionable Markdown Output:** Produces a comprehensive `_analysis.md` file that weaves the visuals and spoken transcript into a factual knowledge base.

## Prerequisites

1. Ensure the host system has `ffmpeg` installed.
2. Ensure the following Python packages are available: `yt-dlp`
3. A `.env` file containing the VLM provider credentials.

## Required Environment Variables

The script requires a `.env` file containing:

```bash
# Omni (Video/Audio/Image) Multimodal model
OMNI_PROVIDER=nebius  # or openrouter, zenmux
OMNI_MODEL=nvidia/Nemotron-3-Nano-Omni

# Credentials for your chosen provider
NEBIUS_API_KEY=your_key_here
NEBIUS_BASE_URL=https://api.studio.nebius.com/v1

# Browser to extract YouTube cookies from for yt-dlp (chrome, brave, safari, firefox, edge)
# Set to 'none' if you do not want to use cookies.
YTDLP_BROWSER=brave
```

## How to Use

Invoke the script from the skill's `scripts/` directory:

```bash
python3 .agents/skills/omni-knowledge-extractor/scripts/omni_video_extractor.py "YOUTUBE_URL" [OUTPUT_DIR] [ENV_FILE_PATH] [SYSTEM_PROMPT_ADDENDUM]
```

### Arguments

1. `YOUTUBE_URL`: The full URL of the video to process.
2. `OUTPUT_DIR` (Optional): The directory to save the video, frames, and markdown output. Defaults to `./omni_output`.
3. `ENV_FILE_PATH` (Optional): Path to the `.env` file. Defaults to `./.env`.
4. `SYSTEM_PROMPT_ADDENDUM` (Optional): Additional instructions to append to the VLM's system prompt to focus the analysis (e.g., "Focus specifically on identifying cybersecurity CVEs and exploit methodologies").

### Example

```bash
python3 .agents/skills/omni-knowledge-extractor/scripts/omni_video_extractor.py \
  "https://www.youtube.com/watch?v=qjA__5-Bybs" \
  "./research_output" \
  "./.env" \
  "Focus heavily on the structural architecture diagrams shown on screen."
```

## How it Works

1. **Info & Subtitles:** Calls `yt-dlp` to get video duration, chapters, and download the `.en.vtt` transcript.
2. **Video Download:** Downloads the video file directly.
3. **Extraction:** For each chapter (or 3-min chunk), `ffmpeg` extracts 8 sequential frames.
4. **VLM Call:** The script sends the spoken transcript for that specific chunk + the 8 base64-encoded visual frames to the OMNI model.
5. **Knowledge Base:** The VLM's analysis is appended sequentially to `[VIDEO_ID]_analysis.md` in the output directory.
