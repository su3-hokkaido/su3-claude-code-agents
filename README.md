# su3-claude-code-agents

A Claude Code plugin marketplace, **`scrum-ai-ecosystem`**: subagents for the roles I work in as Product Owner, Developer, Scrum Master, Writer and more.

> **Status: for personal use, not yet proven in production.** All plugins are at 0.1.0 under their new `su3-` names. The only open TODO is the Claude Design integration for `su3-uiux-designer`. Tested with Claude Code 2.1.316.

## Plugins

Every plugin and agent name starts with `su3-`. Two plugins come in two variants: one **without hooks**, which can be listed in Anthropic's directory (the directory accepts command hooks only from Verified organizations), and one **`-with-guards`** that adds a `PreToolUse` guard hook and is distributed through this GitHub marketplace only. **Install one variant of a set, not both**: their agents and commands overlap.

| Plugin | For | Agents | Hooks |
|---|---|---|---|
| [`su3-developer-set`](plugins/su3-developer-set/README.md) | Developers and the delivery pipeline | `su3-project-manager`, `su3-system-architect`, `su3-app-developer`, `su3-sre`, `su3-aire`, `su3-qc`, `su3-qa` | None |
| [`su3-developer-set-with-guards`](plugins/su3-developer-set-with-guards/README.md) | The same, with a guard for data, infrastructure and version changes | the same names with `-with-guards` (`su3-sre-with-guards`, ...) | Bash guard |
| [`su3-product-owner-set`](plugins/su3-product-owner-set/README.md) | Product Owners | `su3-product-strategist`, `su3-market-researcher`, `su3-security-architect`, `su3-uiux-designer`, `su3-prototyping-agent`, `su3-backlog-manager` | None |
| [`su3-product-owner-set-with-guards`](plugins/su3-product-owner-set-with-guards/README.md) | The same, with a guard for tickets, sprints, versions and ADRs | the same names with `-with-guards` | Bash, Write, Edit and connector guard |
| [`su3-tech-writer-set`](plugins/su3-tech-writer-set/README.md) | Technical articles and blog posts | `su3-tech-content-scout`, `su3-tech-draft-writer`, `su3-tech-translator`, `su3-tech-editor-reviewer` | None |
| [`su3-general-writer-set`](plugins/su3-general-writer-set/README.md) | General-audience writing | `su3-general-drafter`, `su3-translator`, `su3-editor-reviewer` | None |

Each plugin is self-contained. The developer sets also ship three commands: `/su3-developer-set:sprint-plan`, `/su3-developer-set:design-review` and `/su3-developer-set:release-check` (with `-with-guards` in the plugin name for the guarded variant).

The old plugin names `developer-set`, `product-owner-set`, `tech-writer-set` and `general-writer-set` are gone. `marketplace.json` maps them to their successors (`renames`): `developer-set` and `product-owner-set` move to the `-with-guards` variants, because those kept the hooks; the writer sets move to their `su3-` names.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install su3-developer-set@scrum-ai-ecosystem
```

Or from your shell:

```text
claude plugin marketplace add su3-hokkaido/su3-claude-code-agents
claude plugin install su3-developer-set@scrum-ai-ecosystem
```

Update with `claude plugin update <plugin>@scrum-ai-ecosystem`. Auto-update is off by default for third-party marketplaces; turn it on in `/plugin` under Marketplaces. A plugin updates only when its `version` changes (see Versioning).

## Safety guards

Only the `-with-guards` plugins register a hook. It acts only inside that plugin's own subagents and never changes how you work in the main session. The plain variants have the same guardrails as agent instructions, but nothing enforces them: you are the only safeguard.

- **`su3-developer-set-with-guards`**: agents never change production data or live infrastructure on their own. Data changes need a dry-run first, live infrastructure changes and version upgrades ask you, and other irreversible commands ask you.
- **`su3-product-owner-set-with-guards`**: agents never delete or change tickets or sprints, never apply version changes, and must write an ADR before changing product or backlog documents. Existing ADRs are never edited.

The writer plugins only draft and review. They publish nothing. The hooks are text-pattern safety nets, not security boundaries. Keep production credentials out of the agents' environment and give connectors read-only credentials where you can. Details are in each plugin's README.

## Output language

Agent definitions are written in English, but the language agents reply in is configurable through each plugin's `output_language` option: `auto` (default, follows your input), `en`, `ja`, or any BCP-47 code. Translation agents always output in the requested target language. Change it with `/plugin configure <plugin>@scrum-ai-ecosystem` or `/<plugin>:set-language <code>`; it applies after a restart. The option is set per plugin and per user, not per project.

## Prerequisites

No MCP servers are bundled. Most agents need nothing beyond Claude Code. Connectors you set up yourself make some agents more useful:

| Plugin | Optional connectors |
|---|---|
| `su3-developer-set`, `su3-developer-set-with-guards` | Slack, Jira, Datadog, PagerDuty (for `su3-project-manager` and `su3-sre`) |
| `su3-product-owner-set`, `su3-product-owner-set-with-guards` | Slack, Jira, Gmail, Google Sheets, Backlog (for `su3-market-researcher`; read-only use is intended) |
| `su3-tech-writer-set`, `su3-general-writer-set` | None |

`jq` is needed only to run `scripts/validate.sh`. Some commands need recent Claude Code versions (`claude plugin configure` needs 2.1.285 or later).

## Versioning

Each plugin has its own SemVer `version` in its `plugin.json`. It is raised by hand for every release, because an unchanged `version` means users get no update. Only a plugin with changes gets a new version. Releases are marked with git tags named `{plugin}--v{version}` (for example `su3-developer-set--v0.1.0`). Changes are recorded in [`CHANGELOG.md`](CHANGELOG.md). The steps are in [`docs/release-checklist.md`](docs/release-checklist.md).

## Local testing

Validate everything (requires `jq`; also runs `claude plugin validate`):

```text
sh scripts/validate.sh
```

Load one plugin without installing it:

```text
claude --plugin-dir ./plugins/su3-developer-set
```

Or add the repository as a local marketplace, then install:

```text
claude plugin marketplace add ./
claude plugin install su3-developer-set@scrum-ai-ecosystem
```

A marketplace added from a local path loads each plugin's current source in place, so edits take effect at the next session start or `/reload-plugins` without changing `version`.

## Roadmap

- Refinement support
- Daily commit collection and analysis
- Team performance analysis
- Issue patrol
- Claude Design integration for `su3-uiux-designer`

## Repository docs

- [`CLAUDE.md`](CLAUDE.md): working rules for Claude Code in this repository
- [`docs/release-checklist.md`](docs/release-checklist.md): how to release
- [`docs/claude-code-prompt_scrum-ai-ecosystem.md`](docs/claude-code-prompt_scrum-ai-ecosystem.md): the original build brief

## License

[MIT](LICENSE)
