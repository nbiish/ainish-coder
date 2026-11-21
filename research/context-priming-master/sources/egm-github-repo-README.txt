# Source: https://github.com/google/elephant-goldfish-model (repo landing page / README)
# Captured 2026-11-21. Canonical reviewer personas are in sources/egm-plugin/persona-*.md.


google

elephant-goldfish-model

Repository navigation

Code

Issues

76

(
76
)

Pull requests

52

(
52
)

Discussions

Actions

Projects

Security and quality

Insights

More
items

elephant-goldfish-model

Public

Notifications

You must be signed in to change notification settings

Fork

1.6k

(
1.6k
)

Star

21.7k

(
21.7k
)

You must be signed in to star a repository

About

Open-source plugin for designing and reviewing software with agents

egm.dev

Topics

agent-skills

ai-agents

antigravity

claude-code

claude-code-plugin

claude-skills

codex

codex-plugin

coding-agents

context-engineering

developer-tools

gemini

llm

multi-agent

prompt-engineering

spec-driven-development

Resources

Readme

Apache-2.0 license

Code of conduct

Code of conduct

Contributing

Contributing

Security policy

Security policy

Accessibility

Accessibility

Activity

Custom properties

Stars

21.7k
stars

Watchers

82
watching

Forks

1.6k

forks

Report repository

main

Branches

Tags

Go to file

Code

Open more actions menu

Latest commit

History

209 Commits

209 Commits

Folders and files

Name

Name

Last commit message

Last commit date

.agents/

plugins

.agents/

plugins

.claude-plugin

.claude-plugin

.codex-plugin

.codex-plugin

.cursor-plugin

.cursor-plugin

.gemini

.gemini

.github

.github

.plugin

.plugin

.vscode

.vscode

.windsurf

.windsurf

adapters/

opencode

adapters/

opencode

agents

agents

assets

assets

com.github.copilot/

agents

com.github.copilot/

agents

docs

docs

resources

resources

scripts

scripts

site

site

skills

skills

tests

tests

.editorconfig

.editorconfig

.gitattributes

.gitattributes

.gitignore

.gitignore

ACCESSIBILITY.md

ACCESSIBILITY.md

AGENTS.md

AGENTS.md

AI_POLICY.md

AI_POLICY.md

CONTRIBUTING.md

CONTRIBUTING.md

LICENSE

LICENSE

README.md

README.md

TESTING.md

TESTING.md

plugin.json

plugin.json

pyproject.toml

pyproject.toml

View all files

Repository files navigation

README

Code of conduct

Contributing

Apache-2.0 license

Security

Accessibility

More
items

Design with an elephant. Review with a goldfish.

Install
·

Quickstart
·

Documentation
·

Website

Develop ideas with context and review documents with fresh eyes. EGM is an open-source plugin for AI assistants.

Elephant
holds your project context and drafts the specification.
Goldfish
reviewers examine the draft and referenced source material without the earlier conversation, helping expose unstated assumptions and blind spots.
You
make the architectural trade-offs and approve the specification before implementing.

The built-in draft and design-review workflow targets software specifications. For other documents, choose reviewers and standards with
/egm-review-loop
. Bootstrap and drift reporting apply to software codebases.

egm-explainer.mp4

Install

Choose your coding agent. Install the complete plugin so its skills can read the reviewer prompts and document standards.

ChatGPT and Codex desktop

Open the
published EGM plugin
in the desktop app and install it. This listing is desktop-only. For Codex CLI, use the commands below.

Antigravity CLI

agy plugin install https://github.com/google/elephant-goldfish-model

For the
Antigravity App
and
Antigravity for IDEs
(Visual Studio Code extension), run
/plugin
or see the
installation instructions
.

Claude Code

claude plugin marketplace add google/elephant-goldfish-model
claude plugin install egm@egm

Codex CLI

codex plugin marketplace add google/elephant-goldfish-model
codex plugin add egm@egm

Start a new session after installation. For
Claude Cowork
and
ChatGPT Work
, see the
setup guide
.

Try a 60-second review on existing code

Review an existing design document, README, or PR plan against the live code. You do not need to write a new specification. The commands below use the
/egm:
prefix for Antigravity (agy CLI) and Claude Code. In Codex, select the corresponding EGM skill from the skill picker.

Review an existing document

/egm:egm-review docs/designs/webhooks.md

Use the path to your design doc, or to a PR plan saved as Markdown. Fresh reviewers check the design, its clarity, its fit with the code, and its implementation plan.

Check for drift

/egm:egm-drift-report docs/designs/

The agent compares each document in the folder with the current source code and reports where they diverge. You decide whether to update the document or the code.

Try your first design

Open your project in your coding agent and choose a feature that needs design decisions. This example adds webhook delivery: what should happen when a delivery fails, or the same event arrives twice?

The commands below are shown without a prefix. In Antigravity (agy CLI) and Claude Code, add the
/egm:
prefix, for example
/egm:egm-brainstorm
. On agy CLI 1.4.10 an unprefixed name is completed to the prefixed command (
#220
), but 1.4.8 does not (
#196
), so keep the prefix. In Codex, select the corresponding EGM skill from the skill picker. Brainstorming and review require a session that can create fresh subagents.

Explore the idea

/egm-brainstorm Add webhook delivery to this project.

Discuss requirements and trade-offs with the agent. Fresh reviewers challenge the proposal, and the agent saves the agreed direction in
concepts_brief.md
.

Draft the specification

/egm-draft

The agent turns the brief into
design_draft.md
, pausing after each section for your feedback in chat.

Review the draft

/egm-review design_draft.md

Use the draft path returned by the agent.

Fresh reviewers check the design, its clarity, its fit with the code, and its implementation plan. Choose which findings to address. When you approve the design, ask your coding agent to implement it.

See the
workflow guide
for the full process, including saving approved specifications under
docs/designs/
.

How it works

Role

Context

Responsibility

Elephant

Your project, requirements, and earlier decisions

Explore the problem and draft the specification.

Goldfish

The document and its referenced source material, without the earlier conversation

Find missing assumptions, unclear requirements, and implementation risks.

You

The goals and constraints that matter

Resolve trade-offs, approve the design, and decide what to build.

Goldfish reviews require fresh subagent contexts. If your agent cannot create them, EGM stops the review. A review does not replace tests or human judgment. See
supported environments and verification limits
.

Choose a skill

You can use each skill when you need it. You do not have to follow the full sequence.

Skill

Use it to…

Brainstorm

Test an idea and write a concept brief.

Draft

Turn a brief or existing notes into a design document.

Resolve

Work through review findings and agree on changes.

Bootstrap

Create or update documentation for an existing codebase.

Lite

Fast-track small iterations, spec revisions, refactors, and bug fixes.

Review

Review a design with fresh agents across five stages.

Review loop

Run a configured group of reviewers for a specific review task.

Drift report

Compare checked-in documents with the current source code.

Learn more

Getting started
: the workflow and project layout.

Setup
: installation, agent capabilities, and known limits.

Architecture
: how skills and reviewers fit together.

Testing
: checks, execution records, and verification limits.

Dave Rensin’s original essay
: the ideas behind EGM.

Contribute

See the
accessibility statement

for accessibility goals, known limits, and how to report barriers.

Read
contributing
for PRs,
issues
for bugs, and
discussions
for questions.

License

Apache 2.0
. This is not an officially supported Google product.

About

Open-source plugin for designing and reviewing software with agents

egm.dev

Topics

agent-skills

ai-agents

antigravity

claude-code

claude-code-plugin

claude-skills

codex

codex-plugin

coding-agents

context-engineering

developer-tools

gemini

llm

multi-agent

prompt-engineering

spec-driven-development

Resources

Readme

Apache-2.0 license

Code of conduct

Code of conduct

Contributing

Contributing

Security policy

Security policy

Accessibility

Accessibility

Activity

Custom properties

Stars

21.7k
stars

Watchers

82
watching

Forks

1.6k

forks

Report repository

Releases

Used by

Contributors

Languages

