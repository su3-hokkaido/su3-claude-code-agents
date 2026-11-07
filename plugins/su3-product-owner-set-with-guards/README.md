# su3-product-owner-set-with-guards

Subagents for Product Owners, with a guard hook. Part of the `su3-hokkaido-ai-ecosystem` marketplace. Version 0.1.0.

> **This is the variant with the guard hook.** It is the same set of agents as [`su3-product-owner-set`](../su3-product-owner-set/README.md), plus a `PreToolUse` command hook. Anthropic's directory accepts command hooks only from Verified organizations, so this variant is distributed through this GitHub marketplace only. Do not install both variants: their agents overlap.

> **Status: templates filled in, not yet used in production.** Each agent has its role, inputs and outputs, guardrails and working templates. The only open TODO is the Claude Design integration for `su3-uiux-designer-with-guards`.

## Agents

| Agent | Model | Role |
|---|---|---|
| `su3-product-strategist-with-guards` | opus | Goals, roadmap, vision. |
| `su3-market-researcher-with-guards` | opus | Collects and analyzes customer requests and bug reports from connected sources (read-only). |
| `su3-security-architect-with-guards` | opus | Outdated dependencies and vulnerabilities; proposes maintenance, never applies it. |
| `su3-uiux-designer-with-guards` | opus | UI/UX flows and review. Claude Design integration is a future TODO. |
| `su3-prototyping-agent-with-guards` | opus | Disposable prototypes under `prototypes/`. |
| `su3-backlog-manager-with-guards` | opus | Backlog deduplication and reprioritization proposals. |

Agents here only read, analyze and draft. They never post to or edit external services. The guard hook below enforces it.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `product-adr` | `su3-product-strategist-with-guards`, `su3-backlog-manager-with-guards`, automatic | How to record a product decision and its history as an ADR under `docs/adr/`. |
| `set-language` | `/su3-product-owner-set-with-guards:set-language <code> [all]` | Sets `output_language`. |

## Hook

`hooks/hooks.json` registers one `PreToolUse` hook (`scripts/guard-po.sh`) for Bash, Write, Edit and connector (MCP) tools. It acts only inside su3-product-owner-set-with-guards subagents.

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
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure su3-product-owner-set-with-guards@su3-hokkaido-ai-ecosystem` or `/su3-product-owner-set-with-guards:set-language`. Applies after a restart. |

## Prerequisites

`su3-market-researcher-with-guards` needs connectors (MCP servers) that you set up yourself for the sources you want analyzed: Slack, Jira, Gmail, Spreadsheet (Google Sheets), Backlog. If one is missing, the agent says so and stops. MCP servers are not bundled.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-product-owner-set-with-guards@su3-hokkaido-ai-ecosystem
```
