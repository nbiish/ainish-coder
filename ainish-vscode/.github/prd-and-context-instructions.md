---
alwaysApply: true
---
# PRD - Context - Knowledge Base

All code, features, and implementation decisions MUST strictly follow the Product Requirements Document (PRD)
and be based on foundational knowledge gathered into the project's knowledge base.

Knowledge Base:

- /facts* directories
- /docs* directories
- /usage* directories
- /fix* directories

## Technical/Methodology Choices

- All new features, bugfixes, and refactors must be cross-checked against the PRD and knowledge base for compliance.
- Any deviation or extension must be documented in the PRD and knowledge base before proceeding.
- All planning should happen in the PRD and reference specific content from the knowledge base.

Example Usage:
  // When adding a new feature:
  // 1. Update the knowledge base and PRD with feature details and usage.
  // 2. Gather the facts and context for the knowledge base.
  // 3. Implement code changes to match the documented requirements.
  // 4. Ensure all code aligns with the PRD and knowledge base.
  // 5. Update the PRD and knowledge base with the new feature details and usage.

Example Usage:
  // When fixing a bug:
  // 1. Update the PRD and knowledge base with the bug details and usage.
  // 2. Gather the facts and context for the knowledge base.
  // 3. Implement code changes to fix the bug.
  // 4. Ensure all code aligns with the PRD and knowledge base.
