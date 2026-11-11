# su3-developer-set

Subagents and skills for the delivery pipeline. Part of the `su3-hokkaido-ai-ecosystem` marketplace. Version 0.1.0.

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
| `project-implementation` | `/su3-developer-set:project-implementation <tickets, backlog file or description>` | The implementation loop above. Manual only. |
| `task-management` | phase skill (`/su3-developer-set:task-management <unit dir>`) | Writes `01_project_plan.md`: `su3-project-manager` plans, `su3-qa` sets criteria. |
| `code-implementation` | phase skill | Runs the route and the verify loop for a unit. |
| `autonomy-policy` | agents and main session, automatic | Explains the policy file; creates it from the template only in an interactive session after your yes. |
| `safe-data-change` | agents, automatic | Dry-run first, rollback, never production. |
| `sprint-plan` | `/su3-developer-set:sprint-plan <goal or backlog> [--parallel\|--sequential]` | `su3-project-manager` → `su3-system-architect` (if needed) → `su3-aire` (if AI) → `su3-qa` → `su3-project-manager`. |
| `design-review` | `/su3-developer-set:design-review <doc or description> [--parallel\|--sequential]` | `su3-system-architect` summary → `su3-sre`, `su3-aire` (if AI), `su3-qa` review → `su3-system-architect` response → `su3-project-manager` verdict. |
| `release-check` | `/su3-developer-set:release-check <scope> [--parallel\|--sequential]` | `su3-qa` criteria → `su3-qc` checks → `su3-sre` readiness → `su3-aire` (if AI) → `su3-qa` gate → `su3-project-manager` go/no-go. Never deploys. |
| `set-language` | `/su3-developer-set:set-language <code> [all]` | Sets `output_language`. |

The three commands run in the main session. They call the agents **one at a time, in the order shown**, and stop for the Commander's decision at the end.

Concurrency is optional and off by default. Add `--parallel` to a run, or set `allow_concurrency` to `true`, to let the independent steps run at the same time: `sprint-plan` steps 2 and 3, the reviewers in `design-review` step 2, and `release-check` steps 2 to 4. `--sequential` turns it off for one run.

## Hooks

None. The guard hook that denies or asks before data changes, live infrastructure changes, version upgrades and other irreversible commands is in `su3-developer-set-with-guards`. Here, the agents are told to follow those rules themselves, and the Commander is the only safeguard.

## The implementation loop (human on the loop)

`/su3-developer-set:project-implementation <tickets, a backlog file, or a description of the work>` runs a plan, design, implement, verify, report pipeline for each ticket and leaves the supervision to you. It is manual-only. The phases are also skills (`task-management`, `code-implementation`, `design-review`, `release-check`) that you or the model can start on their own.

1. **Snapshot.** Each ticket becomes a directory `docs/<YYYY-MM-DD>_<NNN>_<slug>/` with `00_request.md` (the request and its acceptance criteria) and `01_project_plan.md` (status table, route, budget).
2. **Route.** ``su3-project-manager`` plans, ``su3-qa`` writes the criteria, then the steps of the ticket's route run **one at a time, in order**: ``su3-system-architect`` (design), ``su3-app-developer`` (implement), ``su3-qc`` (verify), ``su3-sre`` and ``su3-aire`` where the route names them. A failed verify sends the work back to the author step; the retry cap (default 2 send-backs) and the budget come from the policy and are applied by the main session by the written rules of `formats.md` (no helper script in this plain variant; only `su3-developer-set-with-guards` enforces the caps mechanically through a small shell helper).
3. **Park and continue.** An agent never asks and never waits. An action it may not take becomes a Parked action block, and the ticket carries on with other work. At the end you find `05_completion_report.md` (what happened, what is open) and `06_commander_actions.md` (every parked or denied action, with command, dry-run result and rollback) in each ticket directory.
4. **You decide.** You run or reject each item of `06`. Production work is always yours. Nothing is deployed, deleted or published by the loop.

### Modes

The `autonomy_mode` option is `interactive` (default) or `unattended`. Interactive: a person is watching; a question is asked once and the answer is recorded. Unattended: nobody is watching; no question is ever asked, blocked work is parked, and a runaway loop stops at the retry cap or the budget. Only the exact value `unattended` (white space ignored) counts; anything else is interactive. Set it with `/plugin configure su3-developer-set@su3-hokkaido-ai-ecosystem` (applies after a restart).

### Risk tiers

| Tier | What | Rule |
|---|---|---|
| T0 | Reads and edits inside the project, tests, dry runs in dev | The agent does it. |
| T1 | Routine writes to dev or staging that the policy lists as `without-approval` | The agent does it and records it. |
| T2 | Data, schema, infrastructure, version, git, tracker and publishing actions; everything touching production or an unknown environment | Parked. For items the policy lists as `after-approval` (dev/staging only), an agent may run the exact approved item `A-NNN` of `06` once you approve it in an interactive session. Production is always run by you. |
| T3 | Secrets and credentials, force push, anything the policy forbids | Never run, never approved. |

### The policy file

`docs/policy/autonomy-policy.md` (template: `skills/autonomy-policy/autonomy-policy.template.md`) holds a human part and one fenced `autonomy-policy` block: which environments are `dev`, `staging`, `production`, which actions need approval, budgets, `forbid:` and `reserve:` lines, `protect` paths. It can only make the plugin defaults stricter, plus the narrow loosenings the template lists. Import it in `CLAUDE.md` with the line `@docs/policy/autonomy-policy.md`. Agents never create or edit it; the main session creates it from the template only after you say yes. Protect it with `CODEOWNERS`. Without a policy file the defaults apply and every command that does not clearly target `dev` is treated as production.

### What backs the rules up

**This plugin has no hook.** The rules above are agent text only: nothing blocks a command, and you are the safeguard. The main session names an approved item to an agent only after your own "approved" message in the session. For enforcement install `su3-developer-set-with-guards` instead (not both).

Do these whatever variant you use, because a hook is a safety net, not a boundary:

- **No production credentials on the machine where agents run**: no production database URL, no kube context or cloud profile that reaches production, not even a read-only role. This covers what any text-based guard cannot see.
- **Database roles** for dev and staging without `DELETE`, `TRUNCATE`, `DROP` or DDL grants where the project allows it.
- **`permissions.deny` rules** in `.claude/settings.json` (a hook never overrides a deny rule; the rules add to it). Example, adapt to the project:

  ```json
  {
    "permissions": {
      "deny": [
        "Edit(/docs/policy/**)",
        "Edit(/.claude/settings.json)",
        "Edit(/.claude/settings.local.json)",
        "Edit(/.git/**)",
        "Read(.env)",
        "Read(.env.*)",
        "Read(!.env.example)",
        "Read(**/*.pem)",
        "Read(~/.ssh/**)",
        "Bash(git push --force *)",
        "Bash(git push -f *)",
        "Bash(terraform apply *)",
        "Bash(kubectl delete *)"
      ]
    }
  }
  ```

  Limits: a Bash rule matches the text Claude writes and does not stop `/bin/rm`, `bash -c '...'` or `git -C . push`; `Read` rules apply to `Grep` and `Glob` on a best-effort basis; carve-outs (`!`) must come after the rule they carve from. Whether the rules apply to subagent calls exactly as to the main session is assumed, not yet verified. For rules that an agent or project cannot loosen, use managed settings. Connector (MCP) write tools are not covered by the Bash guard: add a `deny` entry per write tool (`mcp__<server>__<tool>`; syntax to be checked against the current permissions page).
- **Sandboxing** where you need filesystem and network limits that do not depend on command text.

### Known limits (accepted residual risks)

- **R1** A determined or confused agent can get around a text-pattern guard (interpreters, scripts, indirection). The plain variant has text rules only.
- **R2** A runaway loop inside one agent call is bounded only by a text rule and platform limits.
- **R3** The main session runs the loop and applies the caps and verdicts by hand in this variant and may misjudge them; use a strong model for it, or use `su3-developer-set-with-guards`, whose helper counts them.
- **R4** Commands, dry-run outputs and rollbacks in `06` are written by agents and only partly verified. Read them before you run them.
- **R5** Agents keep their own bookkeeping: inconsistencies are detected, false claims are not. ``su3-qc`` re-runs checks independently.

Minimum Claude Code version: 2.1.295 for the guard hooks and the loop (`set-language` needs 2.1.285).

## Settings

| Option | Default | Description |
|---|---|---|
| `output_language` | `auto` | Reply language: `auto`, `en`, `ja` or any BCP-47 code. Change it with `/plugin configure su3-developer-set@su3-hokkaido-ai-ecosystem` or `/su3-developer-set:set-language`. Applies after a restart. |
| `autonomy_mode` | `interactive` | `interactive` or `unattended` (see Modes). Change it with `/plugin configure su3-developer-set@su3-hokkaido-ai-ecosystem`. |
| `allow_concurrency` | `false` | Allow independent steps of the three commands to run at the same time. Off by default. |

## Prerequisites

None are required. Slack, Jira, Datadog and PagerDuty connectors make `su3-sre` and `su3-project-manager` more useful. MCP servers are not bundled.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-developer-set@su3-hokkaido-ai-ecosystem
```
