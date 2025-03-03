# MAI-Cursor Configuration

This directory contains configuration files for the [Cursor IDE](https://cursor.sh/), which helps customize AI-assisted coding behavior.

## Files

- `.cursorignore` - Excludes sensitive files from both AI features and indexing
- `.cursorindexingignore` - Controls which files are indexed for search and context features
- `.cursorrules` - Customizes AI behavior for this codebase

## Usage

When using Cursor IDE with this project, these configuration files will:

1. Prevent AI from accessing sensitive files like environment variables and credentials
2. Improve indexing performance by excluding large binary files
3. Provide project-specific context to the AI to generate better code suggestions

## Installation

These files will be automatically used by Cursor IDE when you open the project. No additional setup is required.

## Learn More

- [Cursor Documentation](https://docs.cursor.com/context/ignore-files)
- [Rules for AI in Cursor](https://docs.cursor.com/context/rules-for-ai)
