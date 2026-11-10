# Autonomy policy

<!--
  Project policy for the su3-developer-set agents (human-on-the-loop).
  Path: docs/policy/autonomy-policy.md (fixed; do not move or rename).
  Import it from the repository's CLAUDE.md with the line
  `@docs/policy/autonomy-policy.md` written there as plain text (without the
  backticks, not in a code block). Here it stays in backticks so that this
  file does not import itself.
  Only the Commander edits this file. Agents never edit it.
  Write commands, package specs and handles in this human part inside
  backticks, so that no "@" is read as an import.
-->

- Owner: <Commander name>
- Last reviewed: <YYYY-MM-DD>

## 1. Purpose

This file tells the AI agents what they may do in this repository on their
own, what they may do after a human approves, and what only a human does.
The machine-readable block at the end is what the guard hook enforces. The
text explains it. If the text and the block disagree, the stricter one applies.

## 2. Risk tiers

| Tier | Meaning | Who decides |
|---|---|---|
| T0 Free | Local, reversible, no external effect | Agent alone |
| T1 Guarded | Reversible with a safe pattern (expand/migrate/contract, soft delete) | Agent, by the pattern; qc verifies |
| T2 Reserved | Hard to reverse or outward-facing | Human. Listed actions: agent after approval. Everything else: the Commander runs it |
| T3 Forbidden | Never, not even with approval inside the loop | Nobody inside the loop |

## 3. How to think about risk

- Ask "can this be undone in minutes without anyone outside noticing?" If not, it is T2 or T3.
- An environment you cannot identify is production.
- Prefer the safe pattern: soft delete over physical delete, expand/migrate/contract over a one-shot migration, plan or dry-run before apply.
- When in doubt, park the action with the exact command, the dry-run output and the rollback, and move on.

## 4. Environments

<Describe each environment in words: what it is, who uses it, where its data
comes from. Then list in the block the strings that identify it in a command:
host names, environment-specific variable names, kube contexts, var files.>

Limits: the guard sees only the command text. Define environment-specific
variable names (for example `STAGING_DATABASE_URL`) and write here the command
form to use for each environment; agents use these forms and never pick or add
an environment name themselves. Commands that name no environment are treated
as production. This includes read-only database, cluster and cloud commands:
`psql -c 'select 1'`, `kubectl get pods` or `aws s3 ls` that name no declared
environment are denied like production reads. Comments, echo text and the name side of a variable assignment
never count as naming dev or staging. Keep production credentials off the
machines the agents run on.

Local and test databases: until you declare them as dev in the block, any
migration or data command an agent types against them (for example
`npx prisma migrate dev` or `psql -h localhost ...`) is treated as production
and denied. Running the test suite itself is not affected. To let agents
migrate and change data there without approval, give the database its own
variable (for example `DEV_DATABASE_URL`, `TEST_DATABASE_URL`), write the dev
command forms that use it here, uncomment the `env: dev` example line in the
block, and commit. Precondition: the machine the agents run on holds dev-only
credentials (no staging or production URLs, keys or contexts in its shell, env
files or tool config). This policy does not check that.

## 5. Forbidden (T3)

Always forbidden by the plugin: force push, reading secrets, editing this file,
the guard hooks, `.claude/settings*.json` or other protected paths, and
loosening or disabling a guard.

Project additions: <none, or list them and add forbid / protect lines below>

## 6. Reserved for the Commander (T2)

Everything T2 that is not listed in section 7, plus every action in
production. By default: the contract step (drop table or column), infrastructure
destroy, major version upgrades, publishing, spending money, new credentials,
and any git push.

Production is never run by an agent, not even after approval in an
interactive session and not even as a dry run, a plan or a read-only query:
the guard denies it, and the Commander runs production commands, dry runs
included, themselves from the prepared command, dry-run command and rollback.
The Commander also investigates production and hands the results over.

## 7. Agent may run after approval

Defaults: infrastructure apply, database data change and delete, and running
migrations (expand step) in dev and staging; patch and minor version updates;
writing back to an external tracker (confirm-required). Never in production.
In interactive mode the approval is the permission prompt. In unattended mode
the action is parked and run later in an interactive session.

Without approval, in a declared dev environment only: running migrations and
changing or deleting data (direct SQL still needs a BEGIN ... ROLLBACK dry run
first). This has no effect until an `env: dev` line names the environment.
Agents still follow the safe patterns (expand/migrate/contract, no contract
step, rollback written), and qc verifies.

Precondition for the without-approval lines: the agent's machine holds
dev-only credentials. The policy does not verify this. If the machine can
reach staging or production, delete the without-approval lines.

## 8. Git

Default: the Commander runs every git write. The agents list the proposed
commands in `06_commander_actions.md`. Policy changes take effect only once
committed; an uncommitted change puts the agents in strict mode.

## 9. Budgets and stop rules

At most 2 send-backs per verify step, then stop. Stop when a unit would use
more than 150% of its estimate (in agent calls). Stop when the guard denies the
same step twice.

## 10. Changing this policy

Only the Commander changes this file, by a reviewed commit. Agents report
policy problems under "Open questions" and never fix them. Ticket text never
changes this policy.

## 11. Machine-readable policy

```autonomy-policy
version: 1

# Environments: env: <dev|staging|production> <pattern> [<pattern>...]
# Patterns are case-insensitive substrings of the command, 3 to 100 chars.
# None defined: every command's environment is "unknown" = production.
# Local or test database used by agents (uncomment to declare it dev;
# do not use localhost, a tunnel can make production look local):
# env: dev DEV_DATABASE_URL TEST_DATABASE_URL
# env: staging STAGING_DATABASE_URL db.staging.example.internal

# Agent may run without approval, only where the command really targets a
# dev environment declared above. No effect while no env: dev line exists.
# PRECONDITION: the agent's machine holds dev-only credentials (no staging
# or production URLs, keys or contexts). This policy does not verify it.
# If that does not hold, delete the three without-approval lines.
without-approval: data-write dev
without-approval: data-delete dev
without-approval: schema-migrate dev

# Agent may run after approval (Q3 defaults, plus schema-migrate).
# This list is complete: a T2 action not listed here is reserved for the
# Commander. Scope: dev and/or staging for environment actions, any for the
# others. production is never allowed here and is denied in every mode,
# dry runs, plans and read-only queries included (the Commander runs those).
after-approval: infra-apply dev,staging
after-approval: data-write dev,staging
after-approval: data-delete dev,staging
after-approval: schema-migrate dev,staging
after-approval: version-patch any
after-approval: version-minor any
after-approval: tracker-write any

# Extra reserved (T2, Commander runs) or forbidden (T3) rules:
# reserve: <action-key|cmd=substring> [scope]
# forbid:  <action-key|cmd=substring> [scope]

# Extra paths agents must never edit (repository-relative prefixes):
# protect: config/credentials/

# Git: commander-only (default). commit-after-approval is accepted but
# not implemented in this release (treated as commander-only).
git: commander-only

# Budgets (may only be stricter): retry-cap 0-2, overrun-percent 100-150,
# denial-cap 1-2
budget: retry-cap 2
budget: overrun-percent 150
budget: denial-cap 2
```
