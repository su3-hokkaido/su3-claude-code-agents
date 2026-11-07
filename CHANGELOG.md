# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/). Each plugin has its own [SemVer](https://semver.org/) version, so each section is headed `<plugin> <version>`. Releases are tagged `<plugin>--v<version>`. A heading ending in `(unreleased)` gets its release date when the tag is made.

## Unreleased

Nothing yet.

## su3-developer-set 0.1.0 (2026-11-07)

### Added
- New plugin, successor of `developer-set` without hooks, so it can be listed in Anthropic's directory (which refused the old plugin: command hooks are accepted only from Verified organizations). Same seven agents and skills, renamed with the `su3-` prefix (`su3-project-manager`, `su3-system-architect`, `su3-app-developer`, `su3-sre`, `su3-aire`, `su3-qc`, `su3-qa`). The guardrails are instructions only.

## su3-developer-set-with-guards 0.1.0 (2026-11-07)

### Added
- New plugin: `developer-set` 0.1.3 renamed, with the guard hook kept. Agents end with `-with-guards` (`su3-sre-with-guards`, ...). `developer-set` installs migrate to this plugin through `renames`. It is distributed through this GitHub marketplace only.

## su3-product-owner-set 0.1.0 (2026-11-07)

### Added
- New plugin, successor of `product-owner-set` without hooks, for the directory. Same six agents and skills, renamed with the `su3-` prefix. The guardrails are instructions only.

## su3-product-owner-set-with-guards 0.1.0 (2026-11-07)

### Added
- New plugin: `product-owner-set` 0.2.2 renamed, with the guard hook kept. `product-owner-set` installs migrate to this plugin through `renames`. It is distributed through this GitHub marketplace only.

## su3-tech-writer-set 0.1.0 (2026-11-07)

### Added
- New plugin: `tech-writer-set` 0.2.1 renamed with the `su3-` prefix (`su3-tech-content-scout`, `su3-tech-draft-writer`, `su3-tech-translator`, `su3-tech-editor-reviewer`). `tech-writer-set` installs migrate through `renames`.

## su3-general-writer-set 0.1.0 (2026-11-07)

### Added
- New plugin: `general-writer-set` 0.2.1 renamed with the `su3-` prefix (`su3-general-drafter`, `su3-translator`, `su3-editor-reviewer`). `general-writer-set` installs migrate through `renames`.

### Removed (all four old plugins)
- `developer-set`, `product-owner-set`, `tech-writer-set` and `general-writer-set` are no longer in the marketplace. Their last versions are `developer-set` 0.1.3, `product-owner-set` 0.2.2, `tech-writer-set` 0.2.1 and `general-writer-set` 0.2.1; their tags stay in git.

## developer-set 0.1.3 (2026-11-06)

### Fixed
- `guard-bash.sh` no longer contains the text `..` (comments and one message said `...`, and the broad-delete pattern spelled `\.\.`), because the directory scan read it as a path that leaves the plugin. The pattern is now `\.{1,2}`; behavior is unchanged and covered by new tests.

## developer-set 0.1.2 (2026-11-06)

### Fixed
- Guard script no longer redirects to `/dev/null`, and its `wget` pattern is written as `wg[e]t`, so the directory scan stops reading the pattern text as a program that writes to a config file. Behavior is unchanged and covered by new tests.

## product-owner-set 0.2.2 (2026-11-06)

### Fixed
- Guard script no longer redirects to `/dev/null`, and its `wget` pattern is written as `wg[e]t`, so the directory scan stops reading the pattern text as a program that writes to a config file. Behavior is unchanged and covered by new tests.

## developer-set 0.1.1 (2026-11-06)

### Fixed
- The guard keeps its dry-run memory in the fixed file `/tmp/developer-set-guard-dry-runs` (one `<session> <key>` line per dry run) instead of a per-session directory.
- Frontmatter `description` values that contain `: ` are now quoted, so strict YAML parsers read them correctly. `validate.sh` rejects unquoted values with `: ` or ` #`.

## product-owner-set 0.2.1 (2026-11-06)

### Fixed
- The guard no longer keeps state. An ADR counts as "written now" when it changed in the last 120 minutes; older ADRs cannot be edited.
- Frontmatter `description` values that contain `: ` are now quoted, so strict YAML parsers read them correctly. `validate.sh` rejects unquoted values with `: ` or ` #`.

## tech-writer-set 0.2.1 (2026-11-06)

### Fixed
- Frontmatter `description` values that contain `: ` are now quoted, so strict YAML parsers read them correctly. `validate.sh` rejects unquoted values with `: ` or ` #`.

## general-writer-set 0.2.1 (2026-11-06)

### Fixed
- Frontmatter `description` values that contain `: ` are now quoted, so strict YAML parsers read them correctly. `validate.sh` rejects unquoted values with `: ` or ` #`.

## product-owner-set 0.2.0 (2026-11-06)

### Changed
- Filled in the agent TODOs: OKR format and roadmap/vision templates (`product-strategist`), sources and theme taxonomy with report template (`market-researcher`), backlog sources, RICE prioritization and proposal template (`backlog-manager`), severity scale and proposal template (`security-architect`), default single-file HTML prototype stack (`prototyping-agent`), wireframe description format (`uiux-designer`). The Claude Design integration stays a TODO.

## tech-writer-set 0.2.0 (2026-11-06)

### Changed
- Filled in the agent TODOs: topic card and confidentiality checklist (`tech-content-scout`), article templates and default length and tone (`tech-draft-writer`), pre-publish checklist (`tech-editor-reviewer`), glossary convention (`tech-translator`).

## general-writer-set 0.2.0 (2026-11-06)

### Changed
- Filled in the agent TODOs: default templates (`general-drafter`), register presets with example fixes (`editor-reviewer`), name and term list convention (`translator`).

## developer-set 0.1.0 (2026-11-06)

### Added
- Seven agents: `project-manager`, `system-architect`, `app-developer`, `sre`, `aire`, `qc`, `qa`, each with least-privilege tools and a guardrails section.
- Skills: `report-format`, `coding-conventions`, `definition-of-done`, `set-language`.
- Commands (as skills): `sprint-plan`, `design-review`, `release-check`. They call agents one at a time, in order. Independent steps can run at the same time with `--parallel` or the `allow_concurrency` option; `--sequential` turns it off for one run.
- `PreToolUse` Bash guard hook, active only inside developer-set subagents: data changes need a dry-run first, live infrastructure changes and version upgrades ask the user, other irreversible commands ask the user.
- `output_language` and `allow_concurrency` options.

## product-owner-set 0.1.0 (2026-11-06)

### Added
- Scaffold of six agents: `product-strategist`, `market-researcher`, `security-architect`, `uiux-designer`, `prototyping-agent`, `backlog-manager`. Each has its role, inputs and outputs, guardrails and TODOs.
- Skills: `product-adr`, `set-language`.
- `PreToolUse` guard hook, active only inside product-owner-set subagents: no ticket or sprint changes by agents (deletes and sprint writes are denied, other connector writes ask), no version changes, an ADR is required before product or backlog documents change, and ADRs are append-only.
- `output_language` option.

## tech-writer-set 0.1.0 (2026-11-06)

### Added
- Scaffold of four agents: `tech-content-scout`, `tech-draft-writer`, `tech-translator`, `tech-editor-reviewer`.
- Complete skills: `tech-translation-guidelines`, `tech-editorial-review`. Also `set-language`.
- `output_language` option.

## general-writer-set 0.1.0 (2026-11-06)

### Added
- Scaffold of three agents: `general-drafter`, `translator`, `editor-reviewer`.
- Complete skills: `translation-guidelines`, `editorial-review` (with Japanese ra-nuki and i-nuki checks). Also `set-language`.
- `output_language` option.

## Repository (not versioned)

- Marketplace manifest `scrum-ai-ecosystem`.
- `scripts/validate.sh`: JSON, manifests, frontmatter, name uniqueness, Output Language block, `${user_config.*}` declarations, hook tests, version and changelog consistency, and `claude plugin validate`.
- `scripts/test-hooks.sh`: tests for both guard hooks.
- GitHub Actions workflow `validate.yml` and Dependabot configuration.
- Release checklist in `docs/release-checklist.md`.
