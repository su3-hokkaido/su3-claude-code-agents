# su3-developer-set

Subagents and skills for the delivery pipeline. Part of the `scrum-ai-ecosystem` marketplace. Version 0.1.0.

> **No hooks.** This plugin ships no hook, so it can be listed in Anthropic's directory (which accepts command hooks only from Verified organizations). Nothing blocks a dangerous command automatically: the agents' guardrails are instructions only. For the same agents with a guard hook, install [`su3-developer-set-with-guards`](../su3-developer-set-with-guards/README.md) instead. Do not install both: their commands and agents overlap.

## Agents

| Agent | Model | Tools | Role |
|---|---|---|---|
| `su3-project-manager` | opus | Read, Grep, Glob, Write, Edit | Breaks work into tasks, plans sprints, writes status reports. Does not dispatch other agents. |
| `su3-system-architect` | opus | Read, Grep, Glob, Write, Edit | Design documents and ADRs. Edits documents only. |
| `su3-app-developer` | sonnet | Read, Grep, Glob, Edit, Write, Bash | Implements changes, runs tests, writes the PR description. |
| `su3-sre` | sonnet | Read, Grep, Glob, Edit, Write, Bash | IaC, CI/CD, monitoring, runbooks, release readiness, incidents. |
| `su3-aire` | opus | Read, Grep, Glob, Write, Edit | Safety and quality of AI models and agents: eval plans, risk checklists. Edits documents only. |
| `su3-qc` | sonnet | Read, Grep, Glob, Bash, Write | Runs verification and resilience checks, writes defect reports. Does not edit source. |
| `su3-qa` | sonnet | Read, Grep, Glob, Write, Edit | Owns quality standards and the definition of done, runs quality gates. Edits documents only. |

Ownership notes: `su3-qa` owns the definition of done and `su3-qc` verifies against it. `su3-project-manager` applies the report format and coding conventions. `su3-sre` owns CI/CD and infrastructure, `su3-app-developer` hands those changes over.

Every agent loads the `report-format` skill (and others it needs) at startup, and ends its work with a report in that format.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `report-format` | agents, automatic | Standard report: Summary, Done, Decisions, Open questions, Next. |
| `coding-conventions` | agents, automatic | Generic coding defaults. A project's own rules win. |
| `definition-of-done` | agents, automatic | Generic definition of done and quality-gate rules. A project's own rules win. |
| `sprint-plan` | `/su3-developer-set:sprint-plan <goal or backlog> [--parallel\|--sequential]` | `su3-project-manager` → `su3-system-architect` (if needed) → `su3-aire` (if AI) → `su3-qa` → `su3-project-manager`. |
| `design-review` | `/su3-developer-set:design-review <doc or description> [--parallel\|--sequential]` | `su3-system-architect` summary → `su3-sre`, `su3-aire` (if AI), `su3-qa` review → `su3-system-architect` response → `su3-project-manager` verdict. |
| `release-check` | `/su3-developer-set:release-check <scope> [--parallel\|--sequential]` | `su3-qa` criteria → `su3-qc` checks → `su3-sre` readiness → `su3-aire` (if AI) → `su3-qa` gate → `su3-project-manager` go/no-go. Never deploys. |
| `set-language` | `/su3-developer-set:set-language <code> [all]` | Sets `output_language`. |

The three commands run in the main session. They call the agents **one at a time, in the order shown**, and stop for the Commander's decision at the end.

Concurrency is optional and off by default. Add `--parallel` to a run, or set `allow_concurrency` to `true`, to let the independent steps run at the same time: `sprint-plan` steps 2 and 3, the reviewers in `design-review` step 2, and `release-check` steps 2 to 4. `--sequential` turns it off for one run.

## Hooks

None. The guard hook that denies or asks before data changes, live infrastructure changes, version upgrades and other irreversible commands is in `su3-developer-set-with-guards`. Here, the agents are told to follow those rules themselves, and the Commander is the only safeguard.

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure su3-developer-set@scrum-ai-ecosystem` or `/su3-developer-set:set-language`. Applies after a restart. |
| `allow_concurrency` | `false` | Allow independent steps of the three commands to run at the same time. Off by default. |

## Prerequisites

None are required. Slack, Jira, Datadog and PagerDuty connectors make `su3-sre` and `su3-project-manager` more useful. MCP servers are not bundled.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-developer-set@scrum-ai-ecosystem
```
