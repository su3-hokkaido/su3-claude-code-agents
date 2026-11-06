# developer-set

Subagents, skills and a guardrail hook for the delivery pipeline. Part of the `scrum-ai-ecosystem` marketplace. Version 0.1.0.

## Agents

| Agent | Model | Tools | Role |
|---|---|---|---|
| `project-manager` | opus | Read, Grep, Glob, Write, Edit | Breaks work into tasks, plans sprints, writes status reports. Does not dispatch other agents. |
| `system-architect` | opus | Read, Grep, Glob, Write, Edit | Design documents and ADRs. Edits documents only. |
| `app-developer` | sonnet | Read, Grep, Glob, Edit, Write, Bash | Implements changes, runs tests, writes the PR description. |
| `sre` | sonnet | Read, Grep, Glob, Edit, Write, Bash | IaC, CI/CD, monitoring, runbooks, release readiness, incidents. |
| `aire` | opus | Read, Grep, Glob, Write, Edit | Safety and quality of AI models and agents: eval plans, risk checklists. Edits documents only. |
| `qc` | sonnet | Read, Grep, Glob, Bash, Write | Runs verification and resilience checks, writes defect reports. Does not edit source. |
| `qa` | sonnet | Read, Grep, Glob, Write, Edit | Owns quality standards and the definition of done, runs quality gates. Edits documents only. |

Ownership notes: `qa` owns the definition of done and `qc` verifies against it. `project-manager` applies the report format and coding conventions. `sre` owns CI/CD and infrastructure, `app-developer` hands those changes over.

Every agent loads the `report-format` skill (and others it needs) at startup, and ends its work with a report in that format.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `report-format` | agents, automatic | Standard report: Summary, Done, Decisions, Open questions, Next. |
| `coding-conventions` | agents, automatic | Generic coding defaults. A project's own rules win. |
| `definition-of-done` | agents, automatic | Generic definition of done and quality-gate rules. A project's own rules win. |
| `sprint-plan` | `/developer-set:sprint-plan <goal or backlog> [--parallel\|--sequential]` | `project-manager` → `system-architect` (if needed) → `aire` (if AI) → `qa` → `project-manager`. |
| `design-review` | `/developer-set:design-review <doc or description> [--parallel\|--sequential]` | `system-architect` summary → `sre`, `aire` (if AI), `qa` review → `system-architect` response → `project-manager` verdict. |
| `release-check` | `/developer-set:release-check <scope> [--parallel\|--sequential]` | `qa` criteria → `qc` checks → `sre` readiness → `aire` (if AI) → `qa` gate → `project-manager` go/no-go. Never deploys. |
| `set-language` | `/developer-set:set-language <code> [all]` | Sets `output_language`. |

The three commands run in the main session. They call the agents **one at a time, in the order shown**, and stop for the Commander's decision at the end.

Concurrency is optional and off by default. Add `--parallel` to a run, or set `allow_concurrency` to `true`, to let the independent steps run at the same time: `sprint-plan` steps 2 and 3, the reviewers in `design-review` step 2, and `release-check` steps 2 to 4. `--sequential` turns it off for one run.

## Hook

`hooks/hooks.json` registers one `PreToolUse` hook for Bash (`scripts/guard-bash.sh`). Policy: a developer-set subagent never changes production data or live infrastructure on its own, and never applies version upgrades without a human.

| Class | Examples | Result |
|---|---|---|
| Data changes | SQL writes through `psql`/`mysql`/..., `rails db:migrate`, `prisma migrate`, `alembic upgrade`, backfill and data-patch scripts, `aws s3 rm`, DynamoDB writes | Dry-run form (`--dry-run`, `--check`, or SQL ending in `ROLLBACK;`) is allowed and remembered for the session. The real command without an earlier matching dry-run is **denied**. After one, it **asks** you. Tools with no dry-run mode can only be run by you. |
| Live infrastructure | `terraform apply/destroy`, `kubectl apply/delete`, `helm upgrade`, `pulumi up`, `ansible-playbook`, cloud deletes, deploy commands | Plan and dry-run forms are allowed. The real command **asks** you. |
| Version upgrades | `npm update`, `npm audit fix`, `pip install -U`, `cargo update`, `apt upgrade`, `brew upgrade` | Dry-run forms are allowed. The real command **asks** you, because it may be a minor or major change. |
| Other irreversible | force push, `git reset --hard`, broad `rm -rf`, pipe to shell, `chmod 777`, `sudo`, publish and release | **Asks** you. |

Notes:

- A command that mentions `prod` or `production` gets that noted in the prompt.
- In non-interactive runs (`claude -p`), an ask counts as a denial.
- It does nothing in the main session or for other plugins' agents.
- It is a safety net based on text patterns, not a security boundary. A reworded command can slip past it. Keep real production credentials out of the agent's environment.
- It reads the hook input without `jq`. POSIX sh, macOS and Linux. Tests: `scripts/test-hooks.sh`.

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure developer-set@scrum-ai-ecosystem` or `/developer-set:set-language`. Applies after a restart. |
| `allow_concurrency` | `false` | Allow independent steps of the three commands to run at the same time. Off by default. |

## Prerequisites

None are required. Slack, Jira, Datadog and PagerDuty connectors make `sre` and `project-manager` more useful. MCP servers are not bundled.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install developer-set@scrum-ai-ecosystem
```
