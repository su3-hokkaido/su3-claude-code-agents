# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/). Each plugin has its own [SemVer](https://semver.org/) version, so each section is headed `<plugin> <version>`. Releases are tagged `<plugin>--v<version>`. A heading ending in `(unreleased)` gets its release date when the tag is made.

## Unreleased

Nothing yet.

## developer-set 0.1.0 (unreleased)

### Added
- Seven agents: `project-manager`, `system-architect`, `app-developer`, `sre`, `aire`, `qc`, `qa`, each with least-privilege tools and a guardrails section.
- Skills: `report-format`, `coding-conventions`, `definition-of-done`, `set-language`.
- Commands (as skills): `sprint-plan`, `design-review`, `release-check`. They call agents one at a time, in order. Independent steps can run at the same time with `--parallel` or the `allow_concurrency` option; `--sequential` turns it off for one run.
- `PreToolUse` Bash guard hook, active only inside developer-set subagents: data changes need a dry-run first, live infrastructure changes and version upgrades ask the user, other irreversible commands ask the user.
- `output_language` and `allow_concurrency` options.

## product-owner-set 0.1.0 (unreleased)

### Added
- Scaffold of six agents: `product-strategist`, `market-researcher`, `security-architect`, `uiux-designer`, `prototyping-agent`, `backlog-manager`. Each has its role, inputs and outputs, guardrails and TODOs.
- Skills: `product-adr`, `set-language`.
- `PreToolUse` guard hook, active only inside product-owner-set subagents: no ticket or sprint changes by agents (deletes and sprint writes are denied, other connector writes ask), no version changes, an ADR is required before product or backlog documents change, and ADRs are append-only.
- `output_language` option.

## tech-writer-set 0.1.0 (unreleased)

### Added
- Scaffold of four agents: `tech-content-scout`, `tech-draft-writer`, `tech-translator`, `tech-editor-reviewer`.
- Complete skills: `tech-translation-guidelines`, `tech-editorial-review`. Also `set-language`.
- `output_language` option.

## general-writer-set 0.1.0 (unreleased)

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
