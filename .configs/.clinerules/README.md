# Cline Rules Template

<!-- This file serves as a template for .clinerules -->
<!-- When deployed, this will be replaced with merged AGENTS.md + MAIRULES.md -->

## Usage

The `.clinerules` file is Cline's instruction manual for your project.

### Deployment

When you run `ainish-coder --cline`, it will:
1. Merge AGENTS.md and MAIRULES.md into a single `.clinerules` file
2. Place it at the project root
3. Cline will automatically read and apply these rules

### Customization

After deployment, you can customize `.clinerules` by:
- Adding project-specific conventions
- Defining conditional rules for different directories
- Specifying technology stack preferences

### Workflows

Cline has built-in workflow support via slash commands:
- `/newtask` - Start a new task session
- `/newrule` - Create a new rule

The workflows in `.configs/.clinerules/workflows/` are reference examples that can be:
- Manually copied into your `.clinerules` file
- Used as templates for Cline's `/newrule` command
- Adapted for your project's needs

## Example Conditional Rules

```markdown
# When working on /packages/ui
- Use Tailwind CSS only (no custom CSS)
- Components must be fully accessible (WCAG 2.1 AA)
- Include Storybook stories for all components

# When working on /packages/api
- All endpoints must have OpenAPI documentation
- Implement rate limiting on all routes
```

## Technology Stack Preferences

```markdown
# Preferred Stack
- Language: TypeScript
- Framework: Next.js
- Styling: Tailwind CSS
- Testing: Vitest + Testing Library
```
