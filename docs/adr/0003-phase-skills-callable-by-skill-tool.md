# 0003. Phase skills are callable through the Skill tool

- Status: Accepted (Commander, 2026-11-10; amended in place 2026-11-09 while Proposed, see Revision log). Accepted ADRs are not edited; change them only by a superseding ADR.
- Date: 2026-11-09
- Deciders: Commander (decision D1 chosen 2026-11-09)
- Supersedes: no ADR. Overrides one part of the CLAUDE.md "Decisions from Phase 1" rule on slash entry points: that the command skills `design-review` and `release-check` are manual-only (`disable-model-invocation: true`). The rest of that rule stays.

## Context

ADR 0002 makes `project-implementation` the top-level skill that runs the loop in the main session and calls, per unit, the phase skills `task-management`, `design-review` (when needed) and `code-implementation`, with `report-format` as the shared report rule. `release-check` is not part of a unit: it runs only on the release route, once per Commander request, in its own release-check directory (decision S3; specified, implemented later, J5), and `project-implementation` calls it then.

Today the command skills `sprint-plan`, `design-review` and `release-check` all carry `disable-model-invocation: true`, following the CLAUDE.md rule that manual-only entry points use the flag.

The Phase 1 spike (`docs/2026-11-09_01_human_on_loop_design_upgrade/10_spike_findings.md`, F1; Claude Code 2.1.319, throwaway plugin loaded with `--plugin-dir`, run with `claude -p`) found:

- A skill **without** `disable-model-invocation` was invoked from inside another skill through the Skill tool and ran (`PHASE_OPEN_OK`).
- A skill **with** `disable-model-invocation: true` was **blocked**; the model reported that only the user can run it with `/name`. This matches the docs ("Claude can't invoke the skill on its own").
- The calling skill also ran one agent twice in order and read each final `STATUS:` line.

So `project-implementation` cannot call the existing phase skills while they keep the flag. Each behavior was tried once or twice; it shows the mechanism, not a statistical result.

## Decision

We remove `disable-model-invocation` from the phase skills that `project-implementation` calls: `task-management`, `design-review`, `code-implementation`, `release-check` (`report-format` is already a normal skill). We keep the flag on the entry points `project-implementation` and `sprint-plan`.

Skills call skills through the Skill tool. Each phase skill's description says it is used by `project-implementation` or runs when the user asks for it, so it remains runnable alone as `/<plugin>:<name>`. The strict-order rule, the optional concurrency switches and the per-skill `${user_config.output_language}` line from CLAUDE.md are unchanged.

The caller passes the unit directory path (repository-relative) as the Skill arguments; the called skill reads mode and policy state from that directory, and a skill whose arguments name no unit directory counts as started alone (ADR 0002 item 7; `20_formats_spec.md` section 11.3). A phase skill finds the shared loop-state helper by the fixed path rule of `20_formats_spec.md` section 9.4 (relative to its own skill directory, through the skill-directory substitution; to be verified in Phase 3a), never by searching.

## Alternatives considered

- **Keep the flag and inline the phase steps into `project-implementation`** (D1 option 2): no change to model invocation, but the phase text is duplicated, the skill grows long (the docs advise under 500 lines), and a phase cannot be run alone without a second copy.
- **Mixed** (D1 option 3): remove the flag only from the new `task-management` and `code-implementation`, and inline `design-review` and `release-check`. Keeps the old skills manual-only but still duplicates two phases and gives two different patterns to maintain.

## Consequences

- One copy of each phase; the Commander can run any phase by itself.
- Risk: the model may start a phase skill on its own when a description matches a request. Mitigation: descriptions name `project-implementation` or an explicit user request as the trigger, and none of the phase skills deploys or changes anything outside the guard rules (`release-check` never deploys).
- CLAUDE.md still describes the old manual-only state for these skills. This ADR does not edit it; updating CLAUDE.md to point here is a separate task for the Commander to approve.
- `validate.sh` may need to know which skills must and must not carry the flag (task 3.8). Assumption: it does not check this today; not verified in this ADR.

## Notes

- **Nested subagents are a platform feature; our rule is a choice.** The docs (not tested in the spike) say a subagent can spawn subagents by default, up to three layers, and `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` turns it off. The CLAUDE.md rule "`project-manager` has no `Agent` tool" is therefore a design choice, not a platform limit. We keep it: it costs nothing and keeps the main session as the single loop runner (ADR 0002).
- **ADR 0001's `mcp__<server>` tools-prefix note should not be relied on.** ADR 0001 lists connector servers in agent `tools` with `mcp__` prefixes and calls the form unverified. The docs show that a subagent `tools` entry for MCP uses `mcp__<server>__*`, and a bare `mcp__<server>` form probably matches nothing (not tested). ADR 0001 is not edited; a fix, if wanted, is a separate change with its own ADR. It has no effect on this project, because URL and connector fetching stays in the main session (Q10, option A).

## Revision log

| Date | Change | Decisions |
|---|---|---|
| 2026-11-09 | Amended in place while Proposed. Context: `release-check` removed from the per-unit sequence (release route only, once per Commander request, own directory). Decision: the unit-directory path is the Skill argument; phase skills find `loop-state.sh` by the fixed path rule of 20 section 9.4. Fixes 23 Y-6 (ADR 0003 part) and Y-2 (reference). | S3, J5, 23 Y-2, Y-6 |
| 2026-11-10 | Status set to Accepted by the Commander (decision O1). | Phase 2 close-out. |
