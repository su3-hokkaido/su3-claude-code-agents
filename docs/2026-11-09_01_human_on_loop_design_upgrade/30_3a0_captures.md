# 30. Phase 3a.0: assumption captures

- Date: 2026-11-10
- Claude Code: 2.1.319; git 2.56.0; macOS
- Method: throwaway plugin `spike` and a logging hook in the session scratchpad, `claude -p` runs, read-only git probes. Nothing under `plugins/` was changed. No git command that changes state was run (K2: the git fixture tests are run by the Commander).
- Rule: each result below is observed once on this machine; "not verified" items are listed at the end with the owner.

## Results

| # | Assumption (source) | Result | Effect on the specs |
|---|---|---|---|
| 1 | `tool_input` field names (21 s11 assumptions, G3a-8) | `Read`: `file_path`. `Edit`: `file_path`, `old_string`, `new_string`, `replace_all`. `NotebookEdit`: `notebook_path`, `cell_id`, `new_source`. `Grep`: `pattern`, `output_mode` (no path unless the agent gives one). **`MultiEdit` does not exist** in this version: the model said it has no such tool and ToolSearch did not find one. | The edit guard reads `file_path` for `Edit`/`Write`/`Read` and `notebook_path` for `NotebookEdit`. Keep `MultiEdit` in the matcher (harmless if absent) but do not write test rows that need a real `MultiEdit` call; mark the `MultiEdit` rows "synthetic input only". |
| 2 | `agent_type` form per role | `su3-developer-set-with-guards:su3-qc-with-guards` seen for a real role (`spike:worker` for the spike). The seven role names in the Agent tool list all follow `<plugin>:<agent-name>`. Main session: no `agent_type` field. | The prefix test `su3-developer-set-with-guards:` is correct. The role used for run-directory ownership is the part after the colon with the `su3-` prefix and `-with-guards` suffix removed (21 s4.4); only `qc` was observed live, the other six are taken from the agent names. |
| 3 | Plugin cache layout (`PLUGIN_PROT`, 21 s11 Q10) | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` (example: `cache/su3-hokkaido-ai-ecosystem/su3-developer-set-with-guards/0.1.1/`), with the plugin files (`agents/`, `hooks/`, ...) directly under the version directory. Several versions can coexist. | `PLUGIN_PROT` with the optional version segment matches this layout. Q10 is answered. |
| 4 | `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM` (H9a, 22 D23) | With both set to `/dev/null`: global config entries 3 -> 0, system entries 0. The H9 command with `-c core.attributesFile=/dev/null` returned empty output rc=0 for the tracked `CLAUDE.md` and `?? <path>` rc=0 for the untracked ADR file. | H9a variables work on git 2.56.0. The documented minimum is git 2.32 (variables introduced there; not checked against the git docs in this session): the guard's probe (`config --global --list` must print nothing) makes an older git `degraded` rather than unsafe. |
| 5 | `${CLAUDE_SKILL_DIR}` expansion in skill text (Y-2) | Works under `--plugin-dir`: a skill printed its own directory, a skill called through the Skill tool printed the callee's directory, and `${CLAUDE_SKILL_DIR}/../pathprobe` resolved to the sibling skill directory (`ls` listed its `SKILL.md`). `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PROJECT_DIR}` were in the same probe but the run output only reported the directory listings, so their expanded values were not captured. | The Y-2 rule (`${CLAUDE_SKILL_DIR}/../project-implementation/loop-state.sh` from other skills) works in `--plugin-dir` mode. `${CLAUDE_PLUGIN_ROOT}` stays the documented fallback, unconfirmed. |
| 6 | `${CLAUDE_SKILL_DIR}` in an installed (marketplace) plugin | **Not verified.** Needs an installed build. | Commander action (see below). Phase 4 S16 covers it too. |
| 7 | Clean filter in `~/.gitconfig` stopped by the H9a variables (N4) | **Not verified.** Needs a throwaway git repository (`git init`), which Claude Code may not run (K2). | Commander runs fixture H10 / FG7 when the test script exists (3a.6). |

## Open points for the Commander

1. **Installed-mode check (row 6).** To verify `${CLAUDE_SKILL_DIR}` and the saved `autonomy_mode` value in an installed plugin, a test build must be installed from the local marketplace. This needs the three new pieces of 3a (template, helper, `userConfig` option) to exist first, so it is requested at the end of 3a (task 3a.7), not now.
2. Nothing in this capture contradicts the decided design.

## What 3a.1 onwards may rely on

- Field names: `file_path`, `notebook_path` (row 1). No real `MultiEdit`.
- `agent_type` prefix and role derivation (row 2).
- Cache path with a version segment (row 3).
- `GIT_CONFIG_*` neutralization on git 2.56.0 (row 4).
- `${CLAUDE_SKILL_DIR}` with sibling-relative paths in `--plugin-dir` mode (row 5).
