# 1. Orchestration Command (Claude)

```bash
claude --dangerously-skip-permissions -p "
  ROLE: Research Director
  GOAL: Produce 'social_media_native_issues_jan13_2026.md'
  STRATEGY: YOLO Swarm
  
  1. SPAWN Gemini (Context):
     'gemini --yolo -p \"Search for social media privacy trends 2025-2026, EU AI Act 2026 deadlines, and Incogni 2025 report. Summarize top 5 friction points.\"'
     
  2. SPAWN Qwen (Drafting):
     'qwen -y -p \"Read Gemini summary. Draft a markdown report focusing on AI Consent, Dead Internet Theory, and Age Assurance. Style: Professional, alarming but grounded.\"'
     
  3. SPAWN Opencode (Verification):
     'opencode run \"Check draft for factual hallucinations against the Gemini summary. Fix dates (e.g., EU AI Act deadline).\"'
     
  4. MERGE & FINALIZE.
"
```
