# su3-claude-code-agents

A Claude Code plugin marketplace, **`scrum-ai-ecosystem`**: subagents for the roles I work in as Product Owner, Developer, Scrum Master, Writer and more.

> **Status: early development.** All four plugins exist: `developer-set` is built, the other three are scaffolds. Items marked *Planned* do not exist yet.

## Plugins

| Plugin | For | Agents | Status |
|---|---|---|---|
| `developer-set` | Developers and the delivery pipeline | `project-manager`, `system-architect`, `app-developer`, `sre`, `aire`, `qc`, `qa` | Built (v0.1.0) |
| `product-owner-set` | Product Owners | `product-strategist`, `market-researcher`, `security-architect`, `uiux-designer`, `prototyping-agent`, `backlog-manager` | Scaffold (v0.1.0) |
| `tech-writer-set` | Technical articles and blog posts | `tech-content-scout`, `tech-draft-writer`, `tech-translator`, `tech-editor-reviewer` | Scaffold (v0.1.0) |
| `general-writer-set` | General-audience writing | `general-drafter`, `translator`, `editor-reviewer` | Scaffold (v0.1.0) |

Each plugin is self-contained. Install only what you need, or all four together without name collisions.

## Installation

*Planned. These commands work once the marketplace manifest is published.*

```text
/plugin marketplace add su3-hokkaido/su3-claude-code-agents
/plugin install developer-set@scrum-ai-ecosystem
```

## Output language

Agent definitions are written in English, but the language agents reply in is configurable through each plugin's `output_language` option: `auto` (default, follows your input), `en`, `ja`, or any BCP-47 code. Translation agents always output in the requested target language. Change it with `/plugin configure <plugin>@scrum-ai-ecosystem`. The option is set per plugin and per user, not per project. *Applies once the agents exist.*

## Prerequisites

The plugins do not bundle MCP servers. Some agents work better with connectors you set up yourself, such as Slack, Jira, Gmail, Backlog, Datadog or PagerDuty. Each plugin's README will list its prerequisites. *Planned.*

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

## Roadmap

- Refinement support
- Daily commit collection and analysis
- Team performance analysis
- Issue patrol
- Claude Design integration for `uiux-designer`

## Repository docs

- [`CLAUDE.md`](CLAUDE.md): working rules for Claude Code in this repository
- [`docs/claude-code-prompt_scrum-ai-ecosystem.md`](docs/claude-code-prompt_scrum-ai-ecosystem.md): the full build brief

## License

[MIT](LICENSE)
