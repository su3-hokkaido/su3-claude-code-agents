---
name: coding-conventions
description: Generic default coding conventions for su3-developer-set-with-guards agents (structure, naming, tests, errors, dependencies, security). Use when writing or reviewing code, designing a change, or checking a change against the project's conventions.
---

# Coding conventions (defaults)

These are generic defaults. **A project's own conventions win**: if the repository has a CLAUDE.md, a style guide, linter or formatter config, follow those and ignore any conflicting default below.

## Before you write

- Read the surrounding code and match its style, structure and naming.
- Use the project's formatter, linter and test runner. Do not introduce new tooling for a small task.

## Code

- Keep changes small and focused on one purpose. Do not mix refactoring with behavior changes.
- Names say what a thing is or does. Avoid abbreviations that the codebase does not already use.
- Prefer simple, explicit code over clever code. Remove dead code instead of commenting it out.
- Comments explain why, not what. Write them in English unless the project says otherwise.
- Handle errors at the right level. Do not swallow exceptions. Return or log errors with enough context to debug them.
- No hard-coded secrets, tokens, hosts or environment-specific values. Read them from configuration.

## Tests

- Every behavior change comes with a test that fails without the change.
- Tests are deterministic and independent. No real network, clock or randomness unless the test controls it.
- Never delete or weaken a test to make it pass.

## Dependencies and security

- Add a dependency only when it earns its cost. State its purpose and license in the report.
- Validate input at trust boundaries. Do not log personal data or secrets.
- Follow least privilege for file, network and cloud access.

## Changes and reviews

- One logical change per commit or PR. The description states what, why, how it was tested, and risks.
- Public interfaces, configuration and migrations are documented where the project documents them.
