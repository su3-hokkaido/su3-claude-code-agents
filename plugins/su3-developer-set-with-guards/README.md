# su3-developer-set-with-guards

Subagents, skills and a guardrail hook for the delivery pipeline. Part of the `scrum-ai-ecosystem` marketplace. Version 0.1.0.

> **This is the variant with the guard hook.** It is the same set of agents as [`su3-developer-set`](../su3-developer-set/README.md), plus a `PreToolUse` command hook. Anthropic's directory accepts command hooks only from Verified organizations, so this variant is distributed through this GitHub marketplace only. Do not install both variants: their commands and agents overlap.

## Agents

| Agent | Model | Tools | Role |
|---|---|---|---|
| `su3-project-manager-with-guards` | opus | Read, Grep, Glob, Write, Edit | Breaks work into tasks, plans sprints, writes status reports. Does not dispatch other agents. |
| `su3-system-architect-with-guards` | opus | Read, Grep, Glob, Write, Edit | Design documents and ADRs. Edits documents only. |
| `su3-app-developer-with-guards` | sonnet | Read, Grep, Glob, Edit, Write, Bash | Implements changes, runs tests, writes the PR description. |
| `su3-sre-with-guards` | sonnet | Read, Grep, Glob, Edit, Write, Bash | IaC, CI/CD, monitoring, runbooks, release readiness, incidents. |
| `su3-aire-with-guards` | opus | Read, Grep, Glob, Write, Edit | Safety and quality of AI models and agents: eval plans, risk checklists. Edits documents only. |
| `su3-qc-with-guards` | sonnet | Read, Grep, Glob, Bash, Write | Runs verification and resilience checks, writes defect reports. Does not edit source. |
| `su3-qa-with-guards` | sonnet | Read, Grep, Glob, Write, Edit | Owns quality standards and the definition of done, runs quality gates. Edits documents only. |

Ownership notes: `su3-qa-with-guards` owns the definition of done and `su3-qc-with-guards` verifies against it. `su3-project-manager-with-guards` applies the report format and coding conventions. `su3-sre-with-guards` owns CI/CD and infrastructure, `su3-app-developer-with-guards` hands those changes over.

Every agent loads the `report-format` skill (and others it needs) at startup, and ends its work with a report in that format.

## Skills

| Skill | Invocation | Purpose |
|---|---|---|
| `report-format` | agents, automatic | Standard report: Summary, Done, Decisions, Open questions, Next. |
| `coding-conventions` | agents, automatic | Generic coding defaults. A project's own rules win. |
| `definition-of-done` | agents, automatic | Generic definition of done and quality-gate rules. A project's own rules win. |
| `sprint-plan` | `/su3-developer-set-with-guards:sprint-plan <goal or backlog> [--parallel\|--sequential]` | `su3-project-manager-with-guards` → `su3-system-architect-with-guards` (if needed) → `su3-aire-with-guards` (if AI) → `su3-qa-with-guards` → `su3-project-manager-with-guards`. |
| `design-review` | `/su3-developer-set-with-guards:design-review <doc or description> [--parallel\|--sequential]` | `su3-system-architect-with-guards` summary → `su3-sre-with-guards`, `su3-aire-with-guards` (if AI), `su3-qa-with-guards` review → `su3-system-architect-with-guards` response → `su3-project-manager-with-guards` verdict. |
| `release-check` | `/su3-developer-set-with-guards:release-check <scope> [--parallel\|--sequential]` | `su3-qa-with-guards` criteria → `su3-qc-with-guards` checks → `su3-sre-with-guards` readiness → `su3-aire-with-guards` (if AI) → `su3-qa-with-guards` gate → `su3-project-manager-with-guards` go/no-go. Never deploys. |
| `set-language` | `/su3-developer-set-with-guards:set-language <code> [all]` | Sets `output_language`. |

The three commands run in the main session. They call the agents **one at a time, in the order shown**, and stop for the Commander's decision at the end.

Concurrency is optional and off by default. Add `--parallel` to a run, or set `allow_concurrency` to `true`, to let the independent steps run at the same time: `sprint-plan` steps 2 and 3, the reviewers in `design-review` step 2, and `release-check` steps 2 to 4. `--sequential` turns it off for one run.

## Hook

`hooks/hooks.json` registers one `PreToolUse` hook for Bash (`scripts/guard-bash.sh`). Policy: a su3-developer-set-with-guards subagent never changes production data or live infrastructure on its own, and never applies version upgrades without a human.

| Class | Examples | Result |
|---|---|---|
| Data changes | SQL writes through `psql`/`mysql`/..., `rails db:migrate`, `prisma migrate`, `alembic upgrade`, backfill and data-patch scripts, `aws s3 rm`, DynamoDB writes | Dry-run form (`--dry-run`, `--check`, or SQL ending in `ROLLBACK;`) is allowed and remembered for the session (in `/tmp/developer-set-guard-dry-runs`). The real command without an earlier matching dry-run is **denied**. After one, it **asks** you. Tools with no dry-run mode can only be run by you. |
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
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure su3-developer-set-with-guards@scrum-ai-ecosystem` or `/su3-developer-set-with-guards:set-language`. Applies after a restart. |
| `allow_concurrency` | `false` | Allow independent steps of the three commands to run at the same time. Off by default. |

## Prerequisites

None are required. Slack, Jira, Datadog and PagerDuty connectors make `su3-sre-with-guards` and `su3-project-manager-with-guards` more useful. MCP servers are not bundled.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-developer-set-with-guards@scrum-ai-ecosystem
```
