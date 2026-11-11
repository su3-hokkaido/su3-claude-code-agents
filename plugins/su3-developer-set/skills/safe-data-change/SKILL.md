---
name: safe-data-change
description: How to change stored data or a schema safely - expand, migrate, contract; soft delete; dry-run evidence; rollback. Use when a task touches a database, a migration, a backfill, a data patch or a bulk delete.
---

# Safe data change

For every change to stored data or schema. **A project's own data rules win** (its CLAUDE.md, `docs/`, migration tool conventions); follow them and say so. Production is never touched by an agent, not even a dry run or a read (autonomy rules 2 and 3): prepare the command, the dry-run command and the rollback for the Commander.

## Three steps, never one

1. **Expand**: add what the new code needs without removing anything. A nullable column, a new table, a new index, a compatible default. Old and new code both keep working. This is the step an agent may run in dev, and in staging when the policy lists it.
2. **Migrate**: move the data. Backfill in small batches, idempotent and resumable, with a dry-run mode that prints the row count and a sample of what it would change. The code reads the new place and writes both until the move is verified.
3. **Contract**: remove the old column, table or code path. It cannot be undone, so it is T2 and the Commander's. Do not run it: deliver it as a Parked action block with the exact command, the dry-run result and the rollback. A contract step is never loosened to run without approval.

A change that cannot be split this way (for example a rename) is designed as expand (add the new name), migrate (copy), contract (drop the old name).

## Deletes

- Prefer a soft delete: a `deleted_at` or status column set by the application. Reads filter it out. Physical deletion is a later contract step.
- A physical delete (`DELETE`, `TRUNCATE`, `DROP`, bulk removal) is T2. Give the Commander the row-count query for the affected rows next to the command.

## Dry-run evidence

- SQL: run the statement once as `BEGIN; <statement>; ROLLBACK;` in a single `-c` or `-e` argument, with no `COMMIT`, no comments and no second command. Keep the raw output.
- Tools: use the tool's own dry-run form (`--dry-run`, `--check`, `plan`). A tool with no such form has no dry run: say `No dry-run form: <reason>` and do not invent one.
- Quote the raw output starting with the `$ <command>` line. In reports it counts as agent-reported evidence, not as verified.
- Always add a before-and-after row-count query for the affected rows.

## Rollback

Write it before the change, in the Parked action block or the report:

- **Capture**: how the affected rows or schema are saved first (snapshot, export, `CREATE TABLE ... AS SELECT`).
- **Undo**: the exact inverse command or migration.
- **Verify**: the query whose result shows the original state again.

If no rollback exists (a physical delete without a capture), the step is a contract step and belongs to the Commander.

## Who does what

- `system-architect`: the plan, split into expand, migrate and contract, with the rollback.
- `app-developer`: the expand step and the migrate code with its dry-run mode, in dev.
- `sre`: rollback, monitoring and the release order; migrations as part of a release.
- `qc`: re-runs the dry run and the row-count queries independently.
