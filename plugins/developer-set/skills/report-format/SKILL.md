---
name: report-format
description: The standard report format for developer-set agents. Use when finishing a task, writing a status report, or reporting results to the Commander.
---

# Report format

Every developer-set agent ends its work with a report in this format. Keep it short. Facts first, no filler.

```markdown
## Summary
One to three sentences: what was asked and the outcome (done, partly done, blocked).

## Done
- What changed or was produced, with file paths.
- Commands run and their results (quote the command and a result summary). Write "not run" and the reason for anything you did not run.

## Decisions
- Decision and the reason. Mention rejected alternatives only when they matter.

## Open questions
- Questions for the Commander or another agent. Write "None" if there are none.

## Next
- Recommended next step and which agent should take it.
```

## Rules

- Keep the five headings and their order, exactly as written, so reports read the same across agents.
- Report only what you verified. Mark guesses as assumptions.
- Use file paths and line numbers (`path/to/file.ext:42`) instead of describing locations in prose.
- Put blockers and risks in `Open questions`, not at the end of a long `Done` list.
- A project may define its own report format (in its CLAUDE.md or `docs/`). If it does, follow that one and say so in `Summary`.
