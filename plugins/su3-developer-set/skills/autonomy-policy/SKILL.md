---
name: autonomy-policy
description: How the project autonomy policy file works - states, who may create it, what the checks at the start of a run are, and where the template is. Use when starting or resuming an implementation run, when the policy file is missing or invalid, or when asked how much the agents may do alone.
---

# Autonomy policy

The project's policy file is `docs/policy/autonomy-policy.md`. It holds a human part and one fenced `autonomy-policy` block. It can only make the plugin's defaults stricter, plus the narrow loosenings the template lists. This skill is for the **main session**; agents follow the autonomy rules in their own text and never create or edit the file.

## Risk tiers

| Tier | Meaning | Who |
|---|---|---|
| T0 Free | Read, local edits, tests in a local or test environment | agent alone |
| T1 Guarded | Allowed by the policy for a declared dev or staging environment, with a dry run first | agent, within the policy |
| T2 Reserved | Data, schema, infrastructure, versions, git, publishing, trackers, money, credentials | Commander, or an agent for an approved item |
| T3 Forbidden | Secrets, force push, anything the policy forbids | nobody inside the loop |

Production, and any environment the command does not identify, is the Commander's, dry runs, plans and reads included.

## States

| State | Meaning | What happens |
|---|---|---|
| valid | The file exists and its block parses | The policy applies. Record `- Policy: docs/policy/autonomy-policy.md` in the unit's plan |
| missing | No file | Plugin defaults apply (they equal the template, with no environments). Say so |
| degraded | Unreadable, a symlink, no block, two blocks, a bad line, or uncommitted changes | Strict mode: every loosening line is ignored, `forbid`, `reserve` and `protect` lines still apply. Report the reason and line number; do not fix the file |

## Checks at the start (main session)

Run these once at the start of an implementation run; a phase skill started alone runs them itself.

1. **Presence**: does the file exist as a regular file?
2. **Import**: does the root `CLAUDE.md` (or `.claude/CLAUDE.md`) contain a line that is exactly `@docs/policy/autonomy-policy.md`, outside code blocks? If not, say so. In an interactive session offer to add it, after asking.
3. **Validation**: check the block against the rules in the template's comments; report each failure with its line number, and report uncommitted policy changes as a warning.
4. **Record**: write the state into each unit's plan `- Policy:` line, and hand the effective budgets (`retry-cap`, `overrun-percent`, `denial-cap`) to the project manager.

## Creating the file

Only the main session creates it, only in an interactive session, only after the Commander says yes, and only by copying `autonomy-policy.template.md` (in this skill's directory, next to this file) to `docs/policy/autonomy-policy.md` unchanged. Show the import snippet `@docs/policy/autonomy-policy.md` and add it to `CLAUDE.md` only if the Commander agrees. In an unattended run, continue with the defaults and record a question item for the Commander instead of creating anything.

## Approved items

In an unattended run the loop does not dispatch an item whose `Who may run` is "agent after approval", even when its `Decision` says approved; the final message lists such items as ready to run in an interactive session. In an interactive run the main session may dispatch the item and names its `A-NNN` in the dispatch prompt; where a guard hook exists its permission prompt is the binding approval.
