# general-writer-set

Scaffold subagents for general-audience writing, with full writer skills. Part of the `scrum-ai-ecosystem` marketplace. Version 0.1.0.

> **Status: scaffold.** Each agent has its role, inputs and outputs, guardrails and TODOs. Templates and integrations listed under TODO in each agent are not built yet.

## Agents

| Agent | Model | Role |
|---|---|---|
| `general-drafter` | sonnet | Drafts general-audience content. |
| `translator` | sonnet | Japanese and English translation. |
| `editor-reviewer` | sonnet | Polish and editorial review, read-only. Checks Japanese ra-nuki and i-nuki. |

Agents draft and review only. The Commander publishes.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `translation-guidelines` | agents, automatic | JA/EN translation rules for general readers. |
| `editorial-review` | agents, automatic | Review order, ra-nuki and i-nuki checks, AI slop, report format. |
| `set-language` | `/general-writer-set:set-language <code> [all]` | Sets `output_language`. |

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure general-writer-set@scrum-ai-ecosystem` or `/general-writer-set:set-language`. Applies after a restart. |

## Prerequisites

None required.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install general-writer-set@scrum-ai-ecosystem
```
