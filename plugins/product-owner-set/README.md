# product-owner-set

Subagents for Product Owners. Part of the `scrum-ai-ecosystem` marketplace. Version 0.2.2.

> **Status: templates filled in, not yet used in production.** Each agent has its role, inputs and outputs, guardrails and working templates. The only open TODO is the Claude Design integration for `uiux-designer`.

## Agents

| Agent | Model | Role |
|---|---|---|
| `product-strategist` | opus | Goals, roadmap, vision. |
| `market-researcher` | opus | Collects and analyzes customer requests and bug reports from connected sources (read-only). |
| `security-architect` | opus | Outdated dependencies and vulnerabilities; proposes maintenance, never applies it. |
| `uiux-designer` | opus | UI/UX flows and review. Claude Design integration is a future TODO. |
| `prototyping-agent` | opus | Disposable prototypes under `prototypes/`. |
| `backlog-manager` | opus | Backlog deduplication and reprioritization proposals. |

Agents here only read, analyze and draft. They never post to or edit external services. The guard hook below enforces it.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `product-adr` | `product-strategist`, `backlog-manager`, automatic | How to record a product decision and its history as an ADR under `docs/adr/`. |
| `set-language` | `/product-owner-set:set-language <code> [all]` | Sets `output_language`. |

## Hook

`hooks/hooks.json` registers one `PreToolUse` hook (`scripts/guard-po.sh`) for Bash, Write, Edit and connector (MCP) tools. It acts only inside product-owner-set subagents.

| Area | Rule | Result |
|---|---|---|
| Connector tools (Jira, Slack, Backlog, ...) | Judged by the verb in the tool name. Reads (get, list, search) pass. | |
| | Delete, remove, archive | **Denied** |
| | Any write that mentions a sprint (in the tool name or its input) | **Denied**. An active or past sprint cannot be restored and the hook cannot see its state. |
| | Other writes (create, update, edit, transition, assign, comment, send) | **Asks** you |
| Bash | `gh issue/project`, `gh api -X ...`, `jira`/`acli`, `curl -X POST/PUT/PATCH/DELETE`: same rules as connector tools | Deny or ask |
| | Version changes: `npm update`, `npm audit fix`, `pip install -U`, `cargo update`, `apt upgrade`, `--fix`, `--force` | **Denied**. These agents only propose them. |
| | Installing packages | **Asks** you |
| Decision records | A write under `docs/product/` or `docs/backlog/` unless an ADR under `docs/adr/` was written in the last 120 minutes (judged by file modification time; the hook keeps no state) | **Denied** |
| | Overwriting or editing an ADR older than 120 minutes, and removing or moving ADR files | **Denied**. Add a new ADR that supersedes it. |

Notes:

- In non-interactive runs (`claude -p`), an ask counts as a denial.
- The tool verb is read from the tool name. A connector whose names do not follow common verbs may slip through, and a write tool with a name like `...Dataset...` is judged by its verbs only.
- It is a safety net based on text patterns, not a security boundary. Give the connectors read-only credentials where you can.
- POSIX sh, no `jq`, macOS and Linux. Tests: `scripts/test-hooks.sh`.

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure product-owner-set@scrum-ai-ecosystem` or `/product-owner-set:set-language`. Applies after a restart. |

## Prerequisites

`market-researcher` needs connectors (MCP servers) that you set up yourself for the sources you want analyzed: Slack, Jira, Gmail, Spreadsheet (Google Sheets), Backlog. If one is missing, the agent says so and stops. MCP servers are not bundled.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install product-owner-set@scrum-ai-ecosystem
```
