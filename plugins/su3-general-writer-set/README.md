# su3-general-writer-set

Subagents for general-audience writing, with full writer skills. Part of the `scrum-ai-ecosystem` marketplace. Version 0.1.0.

> **Status: templates filled in, not yet used in production.** Each agent has its role, inputs and outputs, guardrails and working templates.

## Agents

| Agent | Model | Role |
|---|---|---|
| `su3-general-drafter` | sonnet | Drafts general-audience content. |
| `su3-translator` | sonnet | Japanese and English translation. |
| `su3-editor-reviewer` | sonnet | Polish and editorial review, read-only. Checks Japanese ra-nuki and i-nuki. |

Agents draft and review only. The Commander publishes.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `translation-guidelines` | agents, automatic | JA/EN translation rules for general readers. |
| `editorial-review` | agents, automatic | Review order, ra-nuki and i-nuki checks, AI slop, report format. |
| `set-language` | `/su3-general-writer-set:set-language <code> [all]` | Sets `output_language`. |

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure su3-general-writer-set@scrum-ai-ecosystem` or `/su3-general-writer-set:set-language`. Applies after a restart. |

## Prerequisites

None required.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-general-writer-set@scrum-ai-ecosystem
```
