# su3-tech-writer-set

Subagents for technical articles and blog posts, with full writer skills. Part of the `scrum-ai-ecosystem` marketplace. Version 0.1.0.

> **Status: templates filled in, not yet used in production.** Each agent has its role, inputs and outputs, guardrails and working templates.

## Agents

| Agent | Model | Role |
|---|---|---|
| `su3-tech-content-scout` | sonnet | Finds article topics in Scrum artifacts. Read-only. |
| `su3-tech-draft-writer` | opus | Outlines and drafts technical articles. |
| `su3-tech-translator` | sonnet | Japanese and English technical translation. |
| `su3-tech-editor-reviewer` | sonnet | Editorial review, read-only. |

Agents draft and review only. The Commander publishes.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `tech-translation-guidelines` | agents, automatic | Technical JA/EN translation rules: code and identifiers untouched, terminology, versions. |
| `tech-editorial-review` | agents, automatic | Review order, technical checks, terminology consistency, AI slop, report format. |
| `set-language` | `/su3-tech-writer-set:set-language <code> [all]` | Sets `output_language`. |

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure su3-tech-writer-set@scrum-ai-ecosystem` or `/su3-tech-writer-set:set-language`. Applies after a restart. |

## Prerequisites

None required. `su3-tech-content-scout` can read Scrum artifacts from files or exports you give it.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-tech-writer-set@scrum-ai-ecosystem
```
