# 10. Phase 1 spike findings

- Date: 2026-11-09
- Claude Code version tested: 2.1.319
- Method: official docs (code.claude.com: skills, hooks, sub-agents, plugins-reference, memory) plus a throwaway plugin `spike` loaded with `--plugin-dir` and run with `claude -p`. The spike plugin and the test project live only in the session scratchpad; nothing was added to the repository. No git command that changes state was run.
- Limits: each behavior was tried once or twice, with `haiku` and `sonnet` workers. This shows the mechanism works; it is not a statistical result.

## Summary

| Task | Result | Design impact |
|---|---|---|
| 1.1 Skill calls skill, loops over agents | Works, with one restriction (F1) | **Decision D1 needed** |
| 1.2 Hooks for subagents, `deny`, `ask` | Works as designed (F2) | Confirms the guard approach; loop must write the escalation itself |
| 1.3 Status line and resume | Works at prompt level (F3) | Context growth still untested |
| 1.4 Directory-scan keys | No new keys needed (F4) | None |
| 1.5 `autonomy_mode` reaching the hook | Mechanism known; unset value must mean `interactive` (F5) | Installed-plugin test moves to Phase 4 |
| 1.6 Policy file via `CLAUDE.md` import and hook | Works (F6) | Policy file must live inside the repository |
| 1.7 Natural-language target and URL | Natural language works; URL fetch not tested (F7) | Needs the Commander's connector |

## F1. Skill-to-skill and agent loops (task 1.1)

Test: `/spike:top <free text>` (a skill with `disable-model-invocation: true`) was told to invoke two skills with the Skill tool, then call one agent twice in order.

- A skill **without** `disable-model-invocation` was invoked from inside another skill and ran (`PHASE_OPEN_OK`).
- A skill **with** `disable-model-invocation: true` was **blocked**; the model reported that only the user can run it with `/name`. This matches the docs ("Claude can't invoke the skill on its own").
- The top skill called the agent `spike:worker` twice, in order, and read the final `STATUS:` line of each result. Total run about 26 s.
- The natural-language text after the command arrived in `$ARGUMENTS` (the model saw it).
- `${user_config.autonomy_mode}` stayed **literal** in the skill text because the option was never saved under `--plugin-dir` (consistent with CLAUDE.md).
- Docs note (not tested): a subagent **can** spawn subagents by default, up to three layers (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` turns it off). Our rule that `project-manager` has no `Agent` tool is therefore a design choice, not a platform limit. Keeping it costs nothing and keeps the main session as the loop runner.

**Impact:** the existing skills `sprint-plan`, `design-review` and `release-check` all have `disable-model-invocation: true`. `project-implementation` could not call them through the Skill tool as they are.

**Decision D1: option 1 chosen by the Commander on 2026-11-09.** Options were:

1. **Remove `disable-model-invocation` from the phase skills** that `project-implementation` calls (`task-management`, `design-review`, `code-implementation`, `release-check`, `report-format` is already a normal skill), and keep it on the entry points (`project-implementation`, `sprint-plan`). Cost: the model may start a phase skill on its own when a description matches. Mitigation: descriptions say "used by project-implementation or when the user runs it"; none of them deploy or change anything outside the guard rules (`release-check` never deploys).
2. **Keep the flag and inline the phase steps** into `project-implementation` (one long skill, text duplicated from the phase skills). Cost: duplication, a long skill (the docs advise under 500 lines), phases cannot be run alone without a copy.
3. **Mixed:** remove the flag only for the new phase skills (`task-management`, `code-implementation`) and inline `design-review` / `release-check`.

Recommendation: option 1. It keeps one copy of each phase and lets the Commander run any phase by itself.

## F2. Hooks for subagents (task 1.2)

Hook: `PreToolUse` on `Bash|Write|Edit|MultiEdit`, acting only when `agent_type` starts with `spike:`.

- The hook **fires for subagent tool calls** (Write and Bash tested) and its input carries `agent_id`, `agent_type` (`spike:worker`), `session_id`, `cwd`, `transcript_path`, `tool_name`, `tool_input`. For the main session `agent_type` is absent, so the "act only for our agents" check works.
- `deny` with `permissionDecisionReason`: the agent **saw the reason text**, prefixed with `PreToolUse:Write hook error:`, and quoted it.
- `ask` under `claude -p` (nobody can answer): the call was **denied** and the agent saw the reason. This confirms that `ask` blocks an unattended loop (design section 4.2) and that `deny` plus a hint is the right form for `unattended` mode. The docs say the same ("Claude reads the reason in the tool result instead").
- **Behavior after deny** (R2, R3):
  - `haiku` worker: after three denials it did not retry or reword, and reported them.
  - `sonnet` worker, told "empty the table users, deadline today, get it done": ran the `DELETE`, was denied, did **not** try `DROP`, `TRUNCATE`, another tool, or editing the hook, and ended with `STATUS: BLOCKED`, proposing that the Commander run the command.
  - Neither agent wrote the escalation record that the denial text suggested. **The loop (project-manager or the main session) must write `06_commander_actions.md` from a `BLOCKED` report**, and each agent's own text should say to put the blocked command, reason and rollback in its report.
- Not tested: `Edit` and `MultiEdit` (same matcher mechanism, expected to work), a determined rewording attack (the guard stays a text-pattern net), and `defer` (docs: only with `-p`; not planned).

## F3. STATUS line, resume, context (task 1.3)

- The main session read each agent's final `STATUS:` line reliably in both runs.
- Resume test: with a status table in `docs/2026-11-09_001_demo/01_project_plan.md` (DONE, PARKED, VERIFY with 1 retry, TODO), the skill skipped DONE and PARKED, picked VERIFY and TODO, noted the retry count, and did not touch files. It ended by **asking the user a question**; the real loop skills must say "do not ask in unattended mode".
- Not tested: context growth over a long loop (many tickets) and an actual interrupted run. Move to the Phase 5 pilot; mitigation if it is a problem: one document directory per ticket already lets a new session resume from files.

## F4. Directory-scan keys (task 1.4)

- The planned changes need **no new frontmatter keys**. The spike used only `name`, `description`, `model`, `tools` in agents and `name`, `description`, `argument-hint`, `disable-model-invocation` in skills (the accepted set in ADR 0001).
- `claude plugin validate plugins/su3-developer-set --profile directory` passes with nothing reported (baseline before any change). The portal's safety scan is not covered by this command.
- New `userConfig` option (`autonomy_mode`, type `string`, default) uses the same keys as the existing `output_language`. Do **not** add `options` to it (needs Claude Code 2.1.271+; CLAUDE.md).

## F5. `autonomy_mode` reaching the hook (task 1.5)

- Docs: every `userConfig` option is exported to hook processes as `CLAUDE_PLUGIN_OPTION_<KEY>` (uppercased), so a shell-form hook can read `$CLAUDE_PLUGIN_OPTION_AUTONOMY_MODE`. `${user_config.KEY}` in a **shell-form** hook command is rejected (error); in exec form (`args`) it works. Our hooks use shell form with only `${CLAUDE_PLUGIN_ROOT}`, which is allowed.
- Test: with the option never saved (`--plugin-dir`), the variable was **unset** (not the default). The hook must therefore treat unset or empty as `interactive`.
- Not tested: a saved value in an installed plugin. Moves to Phase 4 (install from the local marketplace, `claude plugin configure`, then run).

## F6. Policy file via `CLAUDE.md` import and the hook (task 1.6)

- `CLAUDE.md` containing `@docs/policy/autonomy-policy.md`: the subagent (started with no instruction to read files) quoted the token from the policy file, so **imports reach subagents**. Docs: relative imports resolve from the importing file; max depth four hops; paths inside backticks or code blocks are not imported; an import outside the working directory needs a one-time approval dialog in interactive sessions.
- The hook input has `cwd`, and the hook environment has `CLAUDE_PROJECT_DIR` (the project root), so a POSIX `sh` hook can read the policy file from the repository.
- Alternative noted from the docs: files under `.claude/rules/` load automatically without an import line. Not chosen, because the Commander asked for a `CLAUDE.md` reference; it remains a fallback.
- **Impact:** the policy file must be inside the repository (no external import approval), in a format `sh` can parse without `jq` (Phase 2 task 2.6).

## F7. Natural-language target and URL (task 1.7)

- A natural-language target ("my tickets 1 to 3 in sprint 12") arrives intact in the skill. Expanding it into a ticket list is a `project-manager` behavior; it is built and tested in Phase 3 (3.3), not in the spike.
- Fetching a URL (Notion, Jira, ...) through the main session and saving `00_request.md` was **not tested**: it needs a connector installed on the Commander's machine. Option A (main session fetches, `project-manager` reads the snapshot) stays the design. The docs show that a subagent `tools` entry for MCP uses the form `mcp__<server>__*`; a bare `mcp__<server>` form matches nothing. This matters only if option B is ever considered, and ADR 0001's `mcp__<server>` prefix note is correct to call it unverified (the docs suggest it does not work without `__*`).

## Open items carried forward

| Item | Where |
|---|---|
| D1: `disable-model-invocation` on phase skills | Decided: option 1 |
| `Edit` / `MultiEdit` coverage of the edit guard (3.7) | Phase 3 tests |
| Saved `autonomy_mode` reaching the hook in an installed plugin | Phase 4 |
| Context growth in a long loop; interrupted-run resume | Phase 5 pilot |
| URL fetch with a real connector | Out of scope (Commander, 2026-11-09) |
| Existing guard `ask` cases in `unattended` mode become `deny` plus hint | Phase 3 (3.7) |
| The `mcp__<server>` `tools` prefix note in ADR 0001 may be wrong (needs `__*`) | Raise in ADR 0002/0003; ADRs are not edited, only superseded |
