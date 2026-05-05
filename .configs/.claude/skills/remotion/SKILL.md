---
name: remotion
description: Programmatic video creation using Remotion and React. Use when the user asks to create videos, motion graphics, animations, or render video content from code. Supports AI-driven prompt-to-video workflows with Claude Code, Codex, and OpenCode.
---

# Remotion — Programmatic Video Creation

## Purpose
Guide the agent to scaffold, develop, and render programmatic videos using Remotion (React-based video framework). This skill covers the full workflow from project setup through rendering.

## Instructions

### Step 1: Fetch Latest Knowledge
Before implementing, use your web reading tools to visit:
- **Official AI Docs**: `https://www.remotion.dev/docs/ai/coding-agents`
- **Skills Reference**: `https://www.remotion.dev/docs/ai/skills`
- **System Prompt**: `https://www.remotion.dev/docs/ai/generate`
- **MCP Server**: `https://www.remotion.dev/docs/ai/mcp`
- **Upstream Skills Repo**: `https://github.com/remotion-dev/skills` (the canonical `SKILL.md` and `rules/` directory)

Read these to update your knowledge on the latest APIs, best practices, and skill structure.

### Step 2: Project Setup
Scaffold a new Remotion project:
```bash
npx create-video@latest --yes --blank --no-tailwind my-video
```
- Select the **Blank** template.
- Optionally enable TailwindCSS if the user wants it.
- Install the official Remotion agent skills:
```bash
npx skills add remotion-dev/skills
```

### Step 3: Core Concepts
- **`useCurrentFrame()`** and **`interpolate()`**: The fundamental animation primitives.
- **`<Sequence>`**: Delay and limit duration of elements.
- **`<AbsoluteFill>`**: Full-frame container.
- **`<Composition>`** in `src/Root.tsx`: Defines width, height, fps, and duration.
- **`staticFile()`**: Reference assets from the `public/` folder.
- **`<Img>`, `<Video>`, `<Audio>`**: Media components (`<Video>` and `<Audio>` from `@remotion/media`).
- **CSS transitions/animations are FORBIDDEN** — they will not render correctly.
- **Tailwind animation class names are FORBIDDEN** — they will not render correctly.

### Step 4: Preview and Render
```bash
# Preview in Remotion Studio
npx remotion studio

# Sanity-check a single frame
npx remotion still [composition-id] --scale=0.25 --frame=30

# Full render
npx remotion render [composition-id]
```

### Step 5: Advanced Topics (Progressive Disclosure)
Consult the upstream `remotion-dev/skills` repo's `rules/` directory on-demand:

| Topic | Reference File |
|-------|---------------|
| 3D (Three.js / R3F) | `rules/3d.md` |
| Animations | `rules/animations.md` |
| Assets | `rules/assets.md` |
| Audio (trim, volume, speed, pitch) | `rules/audio.md` |
| Audio Visualization | `rules/audio-visualization.md` |
| Captions / Subtitles | `rules/subtitles.md` |
| Charts & Data Viz | `rules/charts.md` |
| Compositions & Stills | `rules/compositions.md` |
| Dynamic Metadata | `rules/calculate-metadata.md` |
| FFmpeg Operations | `rules/ffmpeg.md` |
| GIFs | `rules/gifs.md` |
| Google Fonts | `rules/google-fonts.md` |
| Local Fonts | `rules/local-fonts.md` |
| Light Leaks | `rules/light-leaks.md` |
| Lottie Animations | `rules/lottie.md` |
| Maps (Mapbox) | `rules/maps.md` |
| Measuring Text | `rules/measuring-text.md` |
| Parameters (Zod schemas) | `rules/parameters.md` |
| Sequencing | `rules/sequencing.md` |
| Silence Detection | `rules/silence-detection.md` |
| Sound Effects | `rules/sfx.md` |
| TailwindCSS | `rules/tailwind.md` |
| Text Animations | `rules/text-animations.md` |
| Timing & Easing | `rules/timing.md` |
| Transitions | `rules/transitions.md` |
| Transparent Videos | `rules/transparent-videos.md` |
| Trimming | `rules/trimming.md` |
| Videos (advanced) | `rules/videos.md` |
| Voiceover (ElevenLabs TTS) | `rules/voiceover.md` |

### Step 6: MCP Integration (Optional)
Remotion provides an MCP server for real-time documentation queries:
```json
{
  "mcpServers": {
    "remotion-documentation": {
      "command": "npx",
      "args": ["@remotion/mcp@latest"]
    }
  }
}
```

## Guardrail
Do NOT install Remotion inside the `ainish-coder` codebase. This codebase is strictly a tool orchestrator. This skill is meant for target repositories where the agent is deployed.

## Examples
- "Create a 10-second explainer video with a dark theme and typewriter text effect."
- "Build a motion graphics intro with a 3D rotation transition."
- "Generate a data-driven video from a JSON API endpoint."
- "Add captions to an existing Remotion project."

## Guidelines
- Always consult the live Remotion docs for the most current API surface.
- Use `interpolate()` and `spring()` for all animations — never CSS transitions.
- Keep compositions modular: one React component per scene.
- Use `<Sequence>` for timing, not manual frame math.
- Render a single still frame to sanity-check before full render.

## Resources
- **Docs**: https://www.remotion.dev/docs/ai
- **Skills Repo**: https://github.com/remotion-dev/skills
- **MCP Package**: `@remotion/mcp@latest`
- **Tutorial Video**: https://www.youtube.com/watch?v=5NRAOnKc3c8
