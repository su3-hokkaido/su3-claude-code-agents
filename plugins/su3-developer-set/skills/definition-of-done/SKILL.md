---
name: definition-of-done
description: Generic default definition of done and quality-gate checklist for su3-developer-set agents. Use when deciding whether work is done, running a quality gate, or preparing a release check.
---

# Definition of done (defaults)

Generic defaults. **A project's own definition of done wins**: if the repository defines one (CLAUDE.md, `docs/`, PR template), use it and say so.

Owner: `su3-qa`. `su3-qc` verifies against it. `su3-project-manager` uses it in plans. Nobody else changes it.

## A task is done when

1. **Requirement**: the acceptance criterion is met and the behavior was checked, not assumed.
2. **Code**: follows the project's conventions. The change is small and reviewed (or self-reviewed with notes if no reviewer exists).
3. **Tests**: new and changed behavior has tests. The full existing suite passes. Results are quoted in the report.
4. **Quality checks**: build, lint, format and type checks pass.
5. **Security and privacy**: no secrets or personal data added. New dependencies have a stated purpose and an acceptable license.
6. **AI changes** (if the change touches a model, prompt or agent): `su3-aire`'s risk checklist has no failing item and the eval plan ran or its gap is accepted by the Commander.
7. **Operations**: configuration, migrations, monitoring and rollback are described when the change needs them. `su3-sre` has seen infrastructure changes.
8. **Docs**: user-facing or developer-facing documentation is updated when behavior changed.
9. **Report**: the author wrote a report in the `report-format` format, with open questions listed.

## Quality gate result

- **Pass**: every applicable item is met, with evidence.
- **Conditional pass**: minor gaps, each with an owner and a follow-up. The Commander agrees.
- **Fail**: any applicable item is unmet or lacks evidence. Say which, and who should fix it.

"Not run" is not "passed". Missing evidence means the item is unmet.
