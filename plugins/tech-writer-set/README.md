# tech-writer-set

Scaffold subagents for technical articles and blog posts, with full writer skills. Part of the `scrum-ai-ecosystem` marketplace. Version 0.1.0.

> **Status: scaffold.** Each agent has its role, inputs and outputs, guardrails and TODOs. Templates and integrations listed under TODO in each agent are not built yet.

## Agents

| Agent | Model | Role |
|---|---|---|
| `tech-content-scout` | sonnet | Finds article topics in Scrum artifacts. Read-only. |
| `tech-draft-writer` | opus | Outlines and drafts technical articles. |
| `tech-translator` | sonnet | Japanese and English technical translation. |
| `tech-editor-reviewer` | sonnet | Editorial review, read-only. |

Agents draft and review only. The Commander publishes.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `tech-translation-guidelines` | agents, automatic | Technical JA/EN translation rules: code and identifiers untouched, terminology, versions. |
| `tech-editorial-review` | agents, automatic | Review order, technical checks, terminology consistency, AI slop, report format. |
| `set-language` | `/tech-writer-set:set-language <code> [all]` | Sets `output_language`. |

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure tech-writer-set@scrum-ai-ecosystem` or `/tech-writer-set:set-language`. Applies after a restart. |

## Prerequisites

None required. `tech-content-scout` can read Scrum artifacts from files or exports you give it.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install tech-writer-set@scrum-ai-ecosystem
```
