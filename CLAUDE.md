# CLAUDE.md

## Project

A Claude Code **plugin marketplace** (`scrum-ai-ecosystem`) in a single monorepo, packaging subagents that support Scrum and the development pipeline. GitHub: `su3-hokkaido/su3-claude-code-agents`.

The full brief is `docs/claude-code-prompt_scrum-ai-ecosystem.md`. Read it before any design or implementation work. It is the source of truth for scope, design decisions, agent tables and phases.

## Roles

- **Commander** = the repository owner (the user). Report to and consult the Commander. Do not decide on their behalf.
- Talk to the Commander in **Japanese**. Write everything in the repository in **English** (see Language).

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
- **Output language is user-switchable** (`auto` default, `en`, `ja`, BCP-47). The `Output Language` block in every agent must be word-for-word identical across plugins. See brief, section 3.
- **No MCP servers for external SaaS** (Slack, Jira, etc.) are implemented or bundled. Document them as prerequisites in READMEs only.
- Agents must never perform destructive operations (production deploys, data deletion, `git push --force`) without Commander approval.
- Hook scripts: POSIX sh or Node, minimal dependencies, working on macOS and Linux.

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

`scripts/validate.sh` (once it exists) checks JSON syntax, required frontmatter, name uniqueness across plugins, and Output Language block consistency. Also run `claude plugin validate` if available. CI runs validation on every PR.
