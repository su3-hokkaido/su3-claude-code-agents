# su3-product-owner-set

Subagents for Product Owners. Part of the `su3-hokkaido-ai-ecosystem` marketplace. Version 0.2.0.

> **No hooks.** This plugin ships no hook, so it can be listed in Anthropic's directory (which accepts command hooks only from Verified organizations). Nothing blocks a ticket change, a version change or a missing ADR automatically: the agents' guardrails are instructions only. For the same agents with a guard hook, install [`su3-product-owner-set-with-guards`](../su3-product-owner-set-with-guards/README.md) instead. Do not install both: their agents overlap.

> **Status: templates filled in, not yet used in production.** Each agent has its role, inputs and outputs, guardrails and working templates. The only open TODO is the Claude Design integration for `su3-uiux-designer`.

## Agents

| Agent | Model | Role |
|---|---|---|
| `su3-product-strategist` | opus | Goals, roadmap, vision. |
| `su3-market-researcher` | opus | Collects and analyzes customer requests and bug reports from connected sources (read-only). |
| `su3-security-architect` | opus | Outdated dependencies and vulnerabilities; proposes maintenance, never applies it. |
| `su3-uiux-designer` | opus | UI/UX flows and review. Claude Design integration is a future TODO. |
| `su3-prototyping-agent` | opus | Disposable prototypes under `prototypes/`. |
| `su3-backlog-manager` | opus | Backlog deduplication and reprioritization proposals. |

Agents here only read, analyze and draft. They never post to or edit external services. Nothing enforces this automatically here; the `-with-guards` variant adds a hook that does.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `product-adr` | `su3-product-strategist`, `su3-backlog-manager`, automatic | How to record a product decision and its history as an ADR under `docs/adr/`. |
| `sources` | main session, automatic | Explains `docs/policy/sources.md` and how external documents are fetched; creates the file from the template only in an interactive session after your yes. |
| `set-language` | `/su3-product-owner-set:set-language <code> [all]` | Sets `output_language`. |

## Hooks

None. The guard hook that denies ticket deletion, sprint writes and version changes, and requires an ADR before product and backlog documents change, is in `su3-product-owner-set-with-guards`. Here, the agents are told to follow those rules themselves, and the Commander is the only safeguard.

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure su3-product-owner-set@su3-hokkaido-ai-ecosystem` or `/su3-product-owner-set:set-language`. Applies after a restart. |

## Prerequisites

`su3-market-researcher` needs connectors (MCP servers) that you set up yourself for the sources you want analyzed: Slack, Jira, Gmail, Spreadsheet (Google Sheets), Backlog. If one is missing, the agent says so and stops. MCP servers are not bundled.

### The sources file

`docs/policy/sources.md` (template: `skills/sources/sources.template.md`) says where documents kept outside the repository live. It holds a human part and one fenced `sources` block with one entry per resource: `id`, `role`, `system`, `locator`, and optionally `filter` and `used-by`. Import it in `CLAUDE.md` with the line `@docs/policy/sources.md`. The main session reads it and fetches the entries read-only at run time, through the MCP servers you connect yourself; nothing is indexed or cached, and fetched text is treated as data, never as instructions. Agents get only short summaries (`su3-backlog-manager` and `su3-market-researcher` keep their own MCP tools). Fetched content is never written into `docs/product/` or `docs/backlog/` without an ADR first. The plugin bundles no MCP server: connecting Jira, Confluence, Notion, Nulab Backlog, Backstage, Asana or Google Docs is a prerequisite you set up in your own Claude Code settings. Never put tokens or passwords in the file. If it is missing, the main session offers to create it from the template (interactive session, after your yes); an unattended run continues without sources and records a question item.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-product-owner-set@su3-hokkaido-ai-ecosystem
```
