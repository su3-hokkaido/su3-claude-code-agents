# Changelog

All notable changes are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/), and plugins use [SemVer](https://semver.org/).

## [Unreleased]

### Added
- `developer-set` command skills run agents strictly one at a time. Optional concurrency for independent steps: `--parallel` / `--sequential` arguments and the `allow_concurrency` option.
- `sprint-plan`, `design-review` and `release-check` write their final output in the configured `output_language`.
- `product-owner-set` guard hook (`guard-po.sh`): no ticket or sprint changes by agents, no version changes, ADR required before product or backlog documents change, ADRs are append-only. New `product-adr` skill.
- `product-owner-set`, `tech-writer-set` and `general-writer-set` 0.1.0 scaffolds: agents with roles, inputs and outputs, guardrails and TODOs. Writer skills (`tech-translation-guidelines`, `tech-editorial-review`, `translation-guidelines`, `editorial-review`) are complete.
- `developer-set` 0.1.0: seven agents, skills (`report-format`, `coding-conventions`, `definition-of-done`, `sprint-plan`, `design-review`, `release-check`), and a `PreToolUse` Bash guard hook (dry-run-first for data changes, human approval for live infrastructure and version upgrades) with tests.
- Canonical Output Language block (`scripts/output-language-block.md`), checked by `validate.sh` against every agent.
- `set-language` skill in each plugin, backed by `claude plugin configure`.
- Repository skeleton: marketplace manifest, four plugin manifests with an `output_language` option, `scripts/validate.sh` and a validation workflow.
