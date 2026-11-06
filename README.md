# su3-claude-code-agents

A Claude Code plugin marketplace, **`scrum-ai-ecosystem`**: subagents for the roles I work in as Product Owner, Developer, Scrum Master, Writer and more.

> **Status: for personal use, not yet proven in production.** `developer-set` is at 0.1.0 and the other three at 0.2.0. `developer-set` is fully built. The other three plugins have their roles, guardrails, templates and writer skills written. The only open TODO is the Claude Design integration for `uiux-designer`. Tested with Claude Code 2.1.316.

## Plugins

| Plugin | For | Agents | Status |
|---|---|---|---|
| [`developer-set`](plugins/developer-set/README.md) | Developers and the delivery pipeline | `project-manager`, `system-architect`, `app-developer`, `sre`, `aire`, `qc`, `qa` | Built (0.1.0) |
| [`product-owner-set`](plugins/product-owner-set/README.md) | Product Owners | `product-strategist`, `market-researcher`, `security-architect`, `uiux-designer`, `prototyping-agent`, `backlog-manager` | 0.2.0 |
| [`tech-writer-set`](plugins/tech-writer-set/README.md) | Technical articles and blog posts | `tech-content-scout`, `tech-draft-writer`, `tech-translator`, `tech-editor-reviewer` | 0.2.0 |
| [`general-writer-set`](plugins/general-writer-set/README.md) | General-audience writing | `general-drafter`, `translator`, `editor-reviewer` | 0.2.0 |

Each plugin is self-contained: install only what you need, or all four together. Names do not collide. `developer-set` also ships three commands: `/developer-set:sprint-plan`, `/developer-set:design-review` and `/developer-set:release-check`.

## Installation

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install developer-set@scrum-ai-ecosystem
```

Or from your shell:

```text
claude plugin marketplace add su3-hokkaido/su3-claude-code-agents
claude plugin install developer-set@scrum-ai-ecosystem
```

Update with `claude plugin update <plugin>@scrum-ai-ecosystem`. Auto-update is off by default for third-party marketplaces; turn it on in `/plugin` under Marketplaces. A plugin updates only when its `version` changes (see Versioning).

## Safety guards

Two plugins register a hook that acts only inside their own subagents. It never changes how you work in the main session.

- **`developer-set`**: agents never change production data or live infrastructure on their own. Data changes need a dry-run first, live infrastructure changes and version upgrades ask you, and other irreversible commands ask you.
- **`product-owner-set`**: agents never delete or change tickets or sprints, never apply version changes, and must write an ADR before changing product or backlog documents. Existing ADRs are never edited.

The writer plugins only draft and review. They publish nothing. The hooks are text-pattern safety nets, not security boundaries. Keep production credentials out of the agents' environment and give connectors read-only credentials where you can. Details are in each plugin's README.

## Output language

Agent definitions are written in English, but the language agents reply in is configurable through each plugin's `output_language` option: `auto` (default, follows your input), `en`, `ja`, or any BCP-47 code. Translation agents always output in the requested target language. Change it with `/plugin configure <plugin>@scrum-ai-ecosystem` or `/<plugin>:set-language <code>`; it applies after a restart. The option is set per plugin and per user, not per project.

## Prerequisites

No MCP servers are bundled. Most agents need nothing beyond Claude Code. Connectors you set up yourself make some agents more useful:

| Plugin | Optional connectors |
|---|---|
| `developer-set` | Slack, Jira, Datadog, PagerDuty (for `project-manager` and `sre`) |
| `product-owner-set` | Slack, Jira, Gmail, Google Sheets, Backlog (for `market-researcher`; read-only use is intended) |
| `tech-writer-set`, `general-writer-set` | None |

`jq` is needed only to run `scripts/validate.sh`. Some commands need recent Claude Code versions (`claude plugin configure` needs 2.1.285 or later).

## Versioning

Each plugin has its own SemVer `version` in its `plugin.json`. It is raised by hand for every release, because an unchanged `version` means users get no update. Only a plugin with changes gets a new version. Releases are marked with git tags named `{plugin}--v{version}` (for example `developer-set--v0.1.0`). Changes are recorded in [`CHANGELOG.md`](CHANGELOG.md). The steps are in [`docs/release-checklist.md`](docs/release-checklist.md).

## Local testing

Validate everything (requires `jq`; also runs `claude plugin validate`):

```text
sh scripts/validate.sh
```

Load one plugin without installing it:

```text
claude --plugin-dir ./plugins/developer-set
```

Or add the repository as a local marketplace, then install:

```text
claude plugin marketplace add ./
claude plugin install developer-set@scrum-ai-ecosystem
```

A marketplace added from a local path loads each plugin's current source in place, so edits take effect at the next session start or `/reload-plugins` without changing `version`.

## Roadmap

- Refinement support
- Daily commit collection and analysis
- Team performance analysis
- Issue patrol
- Claude Design integration for `uiux-designer`

## Repository docs

- [`CLAUDE.md`](CLAUDE.md): working rules for Claude Code in this repository
- [`docs/release-checklist.md`](docs/release-checklist.md): how to release
- [`docs/claude-code-prompt_scrum-ai-ecosystem.md`](docs/claude-code-prompt_scrum-ai-ecosystem.md): the original build brief

## License

[MIT](LICENSE)
