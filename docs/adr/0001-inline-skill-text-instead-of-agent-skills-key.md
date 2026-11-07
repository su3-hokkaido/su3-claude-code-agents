# 0001. Write skill text into agent bodies instead of using the agent `skills` key

- Status: Accepted
- Date: 2026-11-07
- Deciders: Commander (approved 2026-11-07)
- Supersedes: none

## Context

We submit the plain plugins (`su3-developer-set`, `su3-product-owner-set`, `su3-tech-writer-set`, `su3-general-writer-set`) to Anthropic's directory. All four were refused with `LOCAL_CODE_FRONTMATTER_KEY`: the directory accepts frontmatter keys outside an unpublished allowed list only from Verified organizations, and we are not Verified and cannot apply to become one.

Probe versions on the `directory-probe` branch showed which key is the cause (full write-up: `docs/knowledge/directory-security-scan_en.md`):

- Every version with the agent key `skills` was refused; every version without it passed.
- Accepted: `name`, `description`, agent `model`, agent `tools`, skill `argument-hint`, skill `disable-model-invocation`.
- Not tested: `disallowedTools` (only used by `su3-product-owner-set` agents `market-researcher` and `backlog-manager`).

Our agents used `skills` to preload shared skill text (for example report format, conventions, definition of done, editorial and translation guidelines, ADR rules). Without it those agents lose that text.

## Decision

We will remove the `skills` key from every agent in the directory-bound plugins and write the skill text those agents need directly into each agent body. Agents keep `model` and a least-privilege `tools` list, and `disallowedTools` is expressed with a `tools` allow-list instead. The same change is applied to the `-with-guards` variants, so each plugin and its variant stay identical apart from the suffix and guard-hook wording.

## Alternatives considered

- Add the `Skill` tool to each agent's `tools` and tell it which skill to load: keeps one copy of the text, but reviewer agents (Read, Grep, Glob only) would no longer be read-only, which breaks least privilege.
- Drop the preload: simplest, but agents lose the standard report format and conventions unless the user asks for them.
- Keep `skills` and wait to become a Verified organization: there is no way to apply, so the plugins could not be listed.

## Consequences

- Skill text is duplicated in every agent that needs it. Duplication is accepted (each plugin is self-contained anyway); the cost is keeping copies in step by hand.
- Agents run without any restricted key and keep least-privilege `tools`.
- The `-with-guards` variants get the same change (they are not submitted, but keeping them identical keeps the parity check in `scripts/validate.sh` unchanged). `disallowedTools` is replaced by a `tools` allow-list that names common connector servers with `mcp__` prefixes; connectors under other names must be added by hand. Whether the `mcp__<server>` prefix form is honored in agent `tools` was not verified.
- Standalone skills (for example `product-adr`, `report-format`) stay as skills for users and command skills. They are no longer the agents' only source of that text.
- Each affected plugin needs a version bump and a CHANGELOG entry, then a resubmission with the tracked branch set back to `main`.
- Risk: the directory may reject further keys later (including `disallowedTools`, if it were kept). It is noticed at the portal scan; test new keys with a probe branch first.
