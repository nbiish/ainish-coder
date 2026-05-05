---
name: camoufox
description: Implements anti-detect browser automation and web scraping using Camoufox. Use when the user asks to scrape a website, bypass bot detection, or automate a browser.
---

# Camoufox Integration

## Purpose
Guide the agent to use the Camoufox library for web scraping and browser automation tasks that require bypassing anti-bot systems.

## Instructions
When invoked to set up or implement web scraping/browser automation:
1. **Fetch Latest Docs**: Use your web reading tools to visit `https://github.com/jo-inc/camofox-browser`. Read the README to update your knowledge on the latest installation steps, Playwright integration, and configuration options.
2. **Implementation**: Use the acquired knowledge to implement the solution in the current codebase.
3. **Guardrail**: Do NOT attempt to install or implement Camoufox inside the `ainish-coder` codebase itself, as it is strictly an orchestrator for other repositories. This skill is meant to be utilized in the target repositories where the agent is deployed.

## Examples
- When a user asks: "Set up a web scraper that won't get blocked by Cloudflare."
- When a user asks: "Integrate an anti-detect browser for our Playwright tests."

## Guidelines
- Always rely on the live GitHub repository for the most accurate and up-to-date API usage.
- Ensure proper configuration of anti-detect features as detailed in the upstream documentation.
