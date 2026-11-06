# Claude Code Prompt: Building the Scrum AI Ecosystem Marketplace

> This entire file is meant to be handed to Claude Code for execution.
> Items marked `<!-- TODO(Commander) -->` are to be filled in by me (the Commander) before handing it over.

---

## 0. Context for You (Claude Code)

You are an engineer well-versed in designing Claude Code plugins and marketplaces.
Package a set of subagents that support Scrum and the development pipeline into **a monorepo that can be published as a Claude Code Plugin Marketplace**.

### Working Rules

- **Before starting, verify the specs against the latest official documentation.** The specs described here reflect my understanding as of November 2026. Where they conflict with the official docs, follow the official docs and report the differences to me.
  - Plugins / Plugins reference / Plugin marketplaces / Subagents / Skills / Hooks / Slash commands
- **Stop and consult me (the Commander)** when:
  - You find something that is not possible under the spec, or that contradicts these instructions
  - Agent responsibilities overlap or conflict
  - A decision is needed on how to integrate with external services (Slack, Jira, etc.)
- At the end of each phase, briefly report "what was done / what was decided / open items," and wait for my OK before moving to the next phase.

---

## 1. Goal and Scope

### Goal
Create a marketplace repository containing four bundles (plugins) that can be added with `/plugin marketplace add <owner>/<repo>` and installed with `/plugin install <plugin>@scrum-ai-ecosystem`.

### In Scope
| Target | Extent |
|---|---|
| Whole repository | Skeleton, marketplace manifest, README, validation script, CI |
| `developer-set` | **Fully built** (agents / skills / commands / hooks at a production-usable level) |
| `product-owner-set` / `tech-writer-set` / `general-writer-set` | **Scaffold** (plugin.json, and for each agent the frontmatter plus a minimal body describing role, inputs/outputs, and TODOs) |
| Writer skills | Created separately inside each writer set (with full content, even at the scaffold stage) |

### Out of Scope
- Implementing or bundling MCP servers for external SaaS (Slack, Jira, Gmail, Datadog, PagerDuty, etc.). Only document the required integrations in the README as "prerequisite MCP servers / connectors."
- Gemini or Claude Design integration for the UI/UX designer (leave as TODO).

---

## 2. Design Decisions Aligned with the Current Spec

The following corrections have already been made to the original proposal. Follow these decisions.

1. **Agent files**: `agents/<name>.md` (do not use `.agent.md`). Frontmatter: `name`, `description`, `model`, `tools` (only what is needed).
2. **plugin.json**: Do not enumerate agents. Place `agents/`, `skills/`, `commands/`, and `hooks/` at the plugin root and let them be auto-discovered. Only `plugin.json` goes inside `.claude-plugin/`.
3. **Model selection**: Only `opus` / `sonnet` / `haiku` / `inherit` are allowed. Set the UI/UX designer to `opus` as well, and add a TODO in its body: "To be replaced with Claude Design integration in the future."
4. **Invocation**: There is no `/agent ...` command. Subagents are either delegated to automatically based on their `description`, or invoked explicitly by name. Provide entry points for standard flows as slash commands in `commands/` (e.g., `/developer-set:sprint-plan`).
5. **No sharing across plugins**: Do not share skills or agents across plugins. Each plugin must be self-contained: no `shared/` directory, no sync scripts, no inter-plugin dependencies. Duplicated content is acceptable.
   - To avoid name collisions, **prefix tech-writer-set agents and skills with `tech-`** (e.g., `tech-translator`, `tech-editorial-review`).
   - general-writer-set uses unprefixed names (`translator`, `editor-reviewer`, etc.).
   - The two writer sets may tailor similar roles to their audiences (tech emphasizes technical accuracy and terminology consistency; general emphasizes readability and natural expression).
6. **Authoring language**: Write all agent, skill, and command definition bodies, frontmatter, and code comments in **English**. The English README is canonical; provide `README.ja.md` alongside it.

---

## 3. Output Language Switching (Important)

Definitions are written in English, but **the language agents output must be switchable by the installing user**.

### Requirements
- Default is `auto` (respond in the same language as the user's input).
- A fixed language such as `en` / `ja` can be selected. Support at least `auto` / `en` / `ja`, and allow other languages via BCP-47 codes.
- Translation agents are an exception: they output in the requested target language, and only their explanations and review comments follow the configured language.
- Settings can exist at both user and project level; project settings take precedence.

### Implementation Approach (verify against the official spec, then propose the best option)
- **First choice**: If the current spec offers an official mechanism for plugins to declare user-configurable settings (e.g., plugin user configuration options), use it.
- **Fallback**: If no official mechanism exists, use the following setup:
  - Settings files: `.claude/scrum-ai.local.md` (project) and `~/.claude/scrum-ai.local.md` (user), with `output_language: auto|en|ja|...` in the frontmatter.
  - Also accept an override via the `SCRUM_AI_LANG` environment variable. Precedence: environment variable > project > user > auto.
  - Resolve the setting in a `SessionStart` hook and inject the output language into the context.
  - Include a common "Output Language" section in every agent's body. Since hook-injected context may not reach subagents, also instruct agents to read the settings file themselves and decide.
  - Provide a slash command `/<plugin>:set-language <code>` in each plugin. Whichever plugin it is run from, it writes to the same settings file.
- With either approach, each plugin carries its own language block, hook, and command so that it works standalone. Keep the settings file format and language resolution rules consistent across all plugins, and have `validate.sh` check that the Output Language block wording is identical across plugins.

---

## 4. Repository Structure (Target)

```text
scrum-agents-monorepo/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/                 # every plugin is self-contained (no cross-plugin sharing)
│   ├── product-owner-set/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/
│   │   │   ├── product-strategist.md
│   │   │   ├── market-researcher.md
│   │   │   ├── security-architect.md
│   │   │   ├── uiux-designer.md
│   │   │   ├── prototyping-agent.md
│   │   │   └── backlog-manager.md
│   │   └── README.md
│   ├── developer-set/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/
│   │   │   ├── project-manager.md
│   │   │   ├── system-architect.md
│   │   │   ├── app-developer.md
│   │   │   ├── sre.md
│   │   │   ├── aire.md
│   │   │   ├── qc.md
│   │   │   └── qa.md
│   │   ├── skills/        # e.g. coding-conventions, report-format, definition-of-done
│   │   ├── commands/      # e.g. sprint-plan.md, design-review.md, release-check.md
│   │   ├── hooks/hooks.json
│   │   └── README.md
│   ├── tech-writer-set/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/
│   │   │   ├── tech-content-scout.md
│   │   │   ├── tech-draft-writer.md
│   │   │   ├── tech-translator.md
│   │   │   └── tech-editor-reviewer.md
│   │   ├── skills/
│   │   │   ├── tech-translation-guidelines/SKILL.md
│   │   │   └── tech-editorial-review/SKILL.md   # typo/clarity/structure, terminology consistency, AI-slop removal
│   │   ├── commands/  (set-language.md)
│   │   ├── hooks/hooks.json                      # language resolution
│   │   └── README.md
│   └── general-writer-set/
│       ├── .claude-plugin/plugin.json
│       ├── agents/
│       │   ├── general-drafter.md
│       │   ├── translator.md
│       │   └── editor-reviewer.md
│       ├── skills/
│       │   ├── translation-guidelines/SKILL.md
│       │   └── editorial-review/SKILL.md        # polishing, JA ra-nuki/i-nuki checks, AI-slop removal
│       ├── commands/  (set-language.md)
│       ├── hooks/hooks.json                      # language resolution
│       └── README.md
├── scripts/
│   └── validate.sh         # JSON schema, frontmatter, name uniqueness, Output Language block consistency
├── .github/workflows/validate.yml
├── CHANGELOG.md
├── LICENSE                 <!-- TODO(Commander): license -->
├── README.md
└── README.ja.md
```

---

## 5. Marketplace / Plugin Manifests

### `.claude-plugin/marketplace.json`
- `name`: `scrum-ai-ecosystem`
- `owner`: <!-- TODO(Commander): name / email (a contact that is OK to publish in a public repo) -->
- `plugins[]`: the four plugins. `source` is a path relative to the repository root (`./plugins/<name>`).
- Add the metadata recommended by the current schema, such as `description` / `version` / `keywords` / `category`.
- Specify `$schema` if one is available.

### `plugins/*/.claude-plugin/plugin.json`
- Required: `name` (kebab-case)
- Recommended: `version` (SemVer, starting at 0.1.0), `description`, `author`, `homepage`, `repository`, `license`, `keywords`
- Place components in the default directories; do not use custom path settings.

GitHub repository: <!-- TODO(Commander): owner/repo (e.g., su3/scrum-agents) -->

---

## 6. Agent Definitions

### 6.1 Common Template for All Agents

```markdown
---
name: <kebab-case>
description: <When to delegate to this agent. Be specific; include trigger phrases. Use "PROACTIVELY" only where auto-delegation is desired.>
model: <opus|sonnet|haiku>
tools: <minimal set; omit only if all tools are truly needed>
---

# Role
# Responsibilities
# Inputs / Outputs   (artifacts, file paths, report format)
# Collaboration      (which agents it hands off to / receives from)
# Guardrails         (what it must NOT do; when to escalate to the Commander)
# Output Language    (identical wording in every agent across all plugins; see Section 3)
```

- Apply least privilege to `tools`. For example, review agents get only Read/Grep/Glob; implementation agents may get Edit/Write/Bash.
- No agent may perform destructive operations (production deploys, data deletion, `git push --force`, etc.) without the Commander's approval.

### 6.2 developer-set (Fully Built)

| name | model | Role | Main Deliverables |
|---|---|---|---|
| project-manager | opus | Overall coordinator. Breaks down and assigns tasks, manages progress, and maintains report formats and coding conventions | sprint plan, task assignments, status report |
| system-architect | opus | Turns backlog items into system designs and design documents | design doc, ADR |
| app-developer | sonnet | Implements web and mobile applications, working with the SRE | code changes, PR description |
| sre | sonnet | Environment setup, monitoring, maintenance, and incident response using Docker / Terraform / Datadog / PagerDuty, etc. | IaC, runbook, CI/CD config |
| aire | opus | Continuously ensures the safety and quality of AI model and agent operations across all environments, from Local to Prod | eval plan, AI risk checklist |
| qc | sonnet | Runs functional verification and resilience checks | test results, defect reports |
| qa | sonnet | Defines quality standards for the overall development process, working with the PM and QC | quality standards, DoD, process review |

As part of the full build, also provide:
- **skills**: `coding-conventions`, `report-format`, `definition-of-done` (write generic defaults, on the assumption that users will override them for their projects)
- **commands** (examples): `sprint-plan`, `design-review`, `release-check`. Each must specify which agents it delegates to and in what order.
- **hooks** (examples; judge whether each is needed and propose):
  - `SessionStart`: resolve the output language (Section 3)
  - `PreToolUse`: detect dangerous Bash commands and ask for confirmation
  - `SubagentStop`: lightly check that the report follows the report format
  - Write hook scripts in POSIX sh or Node with minimal external dependencies. They must work on macOS and Linux.

### 6.3 product-owner-set (Scaffold)

| name | model | Role |
|---|---|---|
| product-strategist | opus | Works alongside the PO on goal setting, roadmap, and product vision |
| market-researcher | opus | Collects and analyzes customer requests and bug reports from Slack / Jira / Gmail / Spreadsheet / Backlog, etc. (list prerequisite MCP servers in the README) |
| security-architect | opus | Investigates outdated dependencies, detects vulnerabilities, and proposes maintenance actions |
| uiux-designer | opus | Supports UI/UX design (TODO: Claude Design integration) |
| prototyping-agent | opus | Builds prototypes that feed into the backlog, working with uiux-designer |
| backlog-manager | opus | Cross-references the roadmap, market data, and vulnerability data, and drafts deduplication and reprioritization of the backlog |

Future extension candidates (just list them in the README Roadmap): refinement support, daily commit collection and analysis, team performance analysis, issue patrol.

### 6.4 tech-writer-set (Scaffold)

| name | model | Role |
|---|---|---|
| tech-content-scout | sonnet | Extracts reusable knowledge topics from Scrum activities, outputs, and the backlog |
| tech-draft-writer | opus | Drafts the structure and body of technical articles and blog posts from the collected topics |
| tech-translator | sonnet | Localizes between Japanese and English (uses the `tech-translation-guidelines` skill) |
| tech-editor-reviewer | sonnet | Reviews for typos, clarity, structure, and AI slop, and sends drafts back for revision (uses the `tech-editorial-review` skill) |

### 6.5 general-writer-set (Scaffold)

| name | model | Role |
|---|---|---|
| general-drafter | sonnet | Drafts general-audience content as instructed by the main session (the Commander) |
| translator | sonnet | Translates between Japanese and English (uses the `translation-guidelines` skill) |
| editor-reviewer | sonnet | Polishes text, checks Japanese ra-nuki/i-nuki (dropped-syllable colloquialisms), removes AI slop, and sends drafts back for revision (uses the `editorial-review` skill) |

> Note: Names of agents, skills, and commands must not collide even when all four plugins are installed at the same time. Have `validate.sh` check name uniqueness across all plugins. Items distinguished by the plugin namespace, such as `set-language`, may be excluded once you have confirmed that they do not collide under the current spec.

---

## 7. Quality and Validation

- `scripts/validate.sh` checks:
  - JSON syntax, plus schema validation where a schema exists
  - Required frontmatter fields in all agents and skills
  - Duplicate agent / skill `name`s across all plugins
  - Whether the Output Language block wording is identical across plugins
- Also use the official validation command (e.g., `claude plugin validate`) if one exists.
- Document local testing steps in the README:
  - Loading via `claude --plugin-dir ./plugins/developer-set`, etc.
  - `/plugin marketplace add ./` from a local path → `/plugin install`
- Run validate on every PR via GitHub Actions.

---

## 8. Work Phases (Report and Stop at the End of Each Phase)

1. **Spec review**: Read the official documentation and report differences from the decisions in Sections 2–3 (especially the output language configuration approach and how agent / skill / command namespaces work).
2. **Skeleton**: Directories, manifests, README outline, validate script, CI.
3. **Output language mechanism**: Settings file format, hook, `set-language` command, Output Language block. Build and verify it in developer-set first, then deploy the same content to the other plugins.
4. **Full build of developer-set**: agents, skills, commands, hooks.
5. **Scaffold the remaining three sets**: Write writer skills with full content inside each set.
6. **Validation**: Run validate, test local installation, and report the results.
7. **Release preparation**: CHANGELOG, versions, final README. **Do not push, tag, or publish until I instruct you to.**

---

## 9. Report Format

```markdown
## Phase N report
- Done:
- Decisions made (and why):
- Deviations from this prompt / official spec notes:
- Open questions for Commander:
- Next phase plan:
```
