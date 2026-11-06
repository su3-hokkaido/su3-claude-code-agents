# CLAUDE.md

## Project

A Claude Code **plugin marketplace** (`scrum-ai-ecosystem`) in a single monorepo, packaging subagents that support Scrum and the development pipeline. GitHub: `su3-hokkaido/su3-claude-code-agents`.

The full brief is `docs/claude-code-prompt_scrum-ai-ecosystem.md`. Read it before any design or implementation work. It is the source of truth for scope, design decisions, agent tables and phases.

## Roles

- **Commander** = the repository owner (the user). Report to and consult the Commander. Do not decide on their behalf.
- Use **English** for everything by default: talking to the Commander and everything written in the repository (see Language). The only repository exception is `README.ja.md`. If the Commander asks for another language in a session, follow that for the session only.

## Plugins

| Plugin | Status |
|---|---|
| `developer-set` | Full build |
| `product-owner-set` | Scaffold |
| `tech-writer-set` | Scaffold (writer skills written in full) |
| `general-writer-set` | Scaffold (writer skills written in full) |

Target layout: `.claude-plugin/marketplace.json`, `plugins/<name>/` (each with `.claude-plugin/plugin.json`, `agents/`, `skills/`, `commands/`, `hooks/`, `README.md`), `scripts/validate.sh`, `.github/workflows/validate.yml`, `CHANGELOG.md`. Details are in the brief, section 4.

## Hard rules

- **Each plugin is self-contained.** No shared skills or agents, no `shared/` directory, no sync scripts, no inter-plugin dependencies. Duplication is fine.
- **Names must not collide** when all four plugins are installed. `tech-writer-set` agents and skills use the `tech-` prefix. `general-writer-set` uses no prefix.
- **Agent files** are `agents/<name>.md` with frontmatter `name`, `description`, `model` (`opus|sonnet|haiku|inherit`), and a minimal `tools`. Use least privilege: review agents get only Read/Grep/Glob.
- **`plugin.json`** does not list components. Put `agents/`, `skills/`, `commands/`, `hooks/` at the plugin root for auto-discovery. Only `plugin.json` goes in `.claude-plugin/`.
- **Output language is user-switchable** (`auto` default, `en`, `ja`, BCP-47). The `Output Language` block in every agent must be word-for-word identical across plugins and must reference `${user_config.output_language}`. See brief, section 3 and "Decisions from Phase 1" below.
- **No MCP servers for external SaaS** (Slack, Jira, etc.) are implemented or bundled. Document them as prerequisites in READMEs only.
- Agents must never perform destructive operations (production deploys, data deletion, `git push --force`) without Commander approval.
- Hook scripts: POSIX sh or Node, minimal dependencies, working on macOS and Linux.

## Decisions from Phase 1 (override the brief)

Verified against the official docs on 2026-11-06 and approved by the Commander.

- **Output language uses the official `userConfig` mechanism only.** Each plugin declares `userConfig.output_language` (string, default `auto`) in `plugin.json`. Agent bodies embed it as `${user_config.output_language}`. Users change it with `/plugin configure <plugin>@scrum-ai-ecosystem`.
  - Not built: `.claude/scrum-ai.local.md`, `SCRUM_AI_LANG`, a language-resolving `SessionStart` hook. Therefore no project-level override and no sharing of the value across plugins.
  - Do not use `options` on the field (needs Claude Code v2.1.271+, and BCP-47 is free-form).
- **Slash entry points are skills, not `commands/`.** `commands/` is the legacy format. Write `sprint-plan`, `design-review`, `release-check`, `set-language` as `skills/<name>/SKILL.md` (use `disable-model-invocation: true` for manual-only ones). They still run as `/<plugin>:<name>`. `validate.sh` rejects a `commands/` directory.
- **Canonical Output Language block**: `scripts/output-language-block.md`. Paste it verbatim at the end of every agent as the last section. `validate.sh` fails any agent whose block differs. Change the wording only in that file, then update every agent.
- **Command skills run in the main session**, which does not carry the plugin's agent text. Each command skill (`sprint-plan`, `design-review`, `release-check`) therefore has its own `${user_config.output_language}` line in its Output section. Keep it when editing them.
- **Command skills run steps strictly in order** (Commander's rule): one agent at a time, wait for the result, then the next. Concurrency is optional: `--parallel` in the arguments or the `allow_concurrency` option (boolean, default false) allows only the independent steps named in each skill; `--sequential` forces it off. Verified with `--plugin-dir` by comparing agent start and finish times; the boolean option's expansion in an installed plugin is not verified. `validate.sh` fails any `${user_config.KEY}` that `plugin.json` does not declare.
- **Versioning**: each plugin's `version` is set explicitly in its own `plugin.json` (SemVer) and raised by hand for every release, because an unchanged `version` means users get no update. Plugins are versioned independently: only a plugin with changes gets a new version. `marketplace.json` carries no `version`. Releases are marked with git tags only, one per plugin, named `{name}--v{version}` (made with `claude plugin tag`, the Commander runs it). No GitHub Releases. Record every release in `CHANGELOG.md` (heading `## <plugin> <version>`, checked by `validate.sh`). The release steps are in `docs/release-checklist.md`; Claude Code prepares the files and never tags or pushes.
- **`set-language` skill** exists in all four plugins. It runs `claude plugin configure <plugin>@scrum-ai-ecosystem --values-stdin` (Claude Code v2.1.285+; the value applies after a restart).
- **`${user_config.*}` expansion (verified in Phase 3)**: it works in skill and agent text for a marketplace-installed plugin once a value is saved. Until then (no `--plugin-dir` expansion, and `default` is not applied to an unset option) the literal `${user_config.output_language}` stays in the text. The block therefore treats an unexpanded, empty or non-language value as `auto`. Do not remove that fallback sentence. A saved value applies even to a new session started right after `claude plugin configure`.
- **developer-set hooks**: only a `PreToolUse` Bash guard (`plugins/developer-set/scripts/guard-bash.sh`). Agents never change production data or live infrastructure alone. Data changes need a dry-run first (real run without one is denied, after one it asks the human); live-infrastructure changes and version upgrades ask the human; plan and dry-run forms pass. Acts only for `agent_type` starting with `developer-set:`. Tested by `scripts/test-hooks.sh`. It is a text-pattern safety net, not a security boundary. The Commander does not want hooks for writer or report work: reports are drafts and the Commander publishes.
- **product-owner-set hook**: `plugins/product-owner-set/scripts/guard-po.sh`, acting only for `agent_type` starting with `product-owner-set:`. Agents never delete or change tickets or sprints (delete and any sprint write are denied, other connector writes ask), never apply version changes (denied), and must write an ADR under `docs/adr/` before changing `docs/product/` or `docs/backlog/`. Existing ADRs are never edited or overwritten. The `product-adr` skill explains how to write one. Tested by `scripts/test-hooks.sh`.
- **No `SubagentStop` report check**: it fires and can return `block`, but Claude Code logs `Stop hook block discarded (turn ended by tool result, no model re-invoke)` for a subagent that ends by handing back its result, so it has no effect. Do not re-add it without re-testing.
- **`project-manager` has no `Agent` tool.** It returns assignments; the main session or the skills (`sprint-plan`, `design-review`, `release-check`) dispatch agents.
- Plugin-provided agents ignore `hooks`, `mcpServers`, `permissionMode` and `initialPrompt` in frontmatter. Put hooks in `hooks/hooks.json`.
- `version` goes in `plugin.json` only (it wins over the marketplace entry).
- Whether `SessionStart` context reaches subagents is undocumented. Do not rely on it.

## Language

- Agent, skill and command definitions (frontmatter and body), code comments, `CLAUDE.md`, `CHANGELOG.md`: **English**.
- `README.md` is canonical in English. `README.ja.md` mirrors it. Update both together.

## Workflow

- Work in the phases defined in the brief, section 8. At the end of each phase, report using the format in section 9 and **wait for the Commander's OK**.
- Before relying on any plugin, marketplace, subagent, skill or hook behavior, **verify it against the latest official Claude Code docs**. If the docs differ from the brief, follow the docs and report the difference.
- Stop and ask the Commander when: something is impossible or contradicts the brief, agent responsibilities overlap, or an external-service integration needs a decision.

## Git

Git operations that change state are prohibited (see the global rules and `.claude/settings.json`). Read-only commands (`status`, `diff`, `log`, `show`, `ls-files`) are fine. When a commit, push, tag or branch is needed, tell the Commander the exact commands and let them run them. **Do not push, tag or publish until instructed.**

## Validation

Run `sh scripts/validate.sh` before reporting a phase as done. It checks JSON syntax, marketplace/plugin consistency, the `output_language` option, required frontmatter and sections, name uniqueness across plugins, Output Language block consistency, and then runs `claude plugin validate`. Requires `jq`. CI (`.github/workflows/validate.yml`) runs it on every PR and push to main.
