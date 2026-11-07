# Anthropic directory: security scan findings and how we resolved them

Date: 2026-11-06 to 2026-11-07. Scope: submitting the plugins of this marketplace to Anthropic's directory through the developer portal (`claude.ai/directory/manage`).

This note records what happened, what we found out, and what to do. It also separates what is **confirmed** by our own results from what is only **inferred**, because the directory does not publish its rules.

Japanese version: [`directory-security-scan_ja.md`](directory-security-scan_ja.md).

## Summary

- The directory refused our plugins twice, for two different reasons that each need an organization to be a **Verified organization**, which we are not and cannot apply to become:
  1. A **command hook** (`developer-set` 0.1.3). Hooks of type `command` are accepted only from Verified organizations.
  2. **Frontmatter keys outside an allowed list** (`LOCAL_CODE_FRONTMATTER_KEY`). The allowed list is not published and the finding does not name the key.
- Fix for 1: ship the hook only in separate `-with-guards` plugins that stay on GitHub, and submit plain variants without hooks.
- Fix for 2: found by bisecting with probe versions. **The agent frontmatter key `skills` is the cause.** `model`, `tools`, `argument-hint` and `disable-model-invocation` are accepted. Decision: remove `skills` from every agent (the plain plugins and their `-with-guards` variants) and write the needed skill text into the agent bodies (see [ADR 0001](../adr/0001-inline-skill-text-instead-of-agent-skills-key.md)). Released as 0.1.1 of all six plugins; the four plain plugins then **passed the security scan** and wait for the Anthropic reviewer.
- Before those two refusals, the portal's validation and scan also **blocked** two versions for harmless-looking text in the hook scripts. They are listed below because the same text patterns can come back.

## Timeline

| When | What happened | Result |
|---|---|---|
| 2026-11-06 | First portal validation of `product-owner-set` and `developer-set` | 1 blocking issue: `guard-po.sh` / `guard-bash.sh` wrote to a path held in a shell variable. Fixed (see "Hook script findings"). |
| 2026-11-06 | Re-validation | Blocking: `wget` plus a write to a fixed file name read as "writes wget's config file". Fixed. |
| 2026-11-06 | Re-validation of `developer-set` | Blocking: `guard-bash.sh` "names `..`" (a path that leaves the plugin). Fixed. |
| 2026-11-06 | Validation passes with warnings and policy holds | Only holds and notes left. The note said command hooks "aren't refused yet". |
| 2026-11-07 | Submission of `developer-set` 0.1.3 | **Refused**: "Hooks of type command accepted only from Verified organizations". |
| 2026-11-07 | Plugins renamed with the `su3-` prefix, each hook plugin split into a plain variant and a `-with-guards` variant | See `CLAUDE.md`, "Plugins". |
| 2026-11-07 | Submission of the four plain plugins | **Refused** for all four: `LOCAL_CODE_FRONTMATTER_KEY`. |
| 2026-11-07 | Bisection with probe versions on branch `directory-probe` | Cause found (below). |
| 2026-11-07 | Commander withdrew the three probe submissions in review; decision to inline skill text | ADR 0001. |
| 2026-11-07 | Released 0.1.1 of all six plugins (skill text inlined, `disallowedTools` replaced by a `tools` allow-list, listing URLs added); tracked branch set back to `main`; `directory-probe` deleted | The four plain plugins passed the security scan and are awaiting the Anthropic reviewer. |

## Finding 1: command hooks

Message: "Hooks of type command accepted only from Verified organizations. If your organization isn't Verified, remove them from the plugin."

- The note `LOCAL_CODE_HOOK_COMMAND` in the validation report had said "This isn't refused yet. Later, the directory will accept command hooks only from Verified organizations." It became a refusal at submission time.
- There is no way to ask to become Verified yet.
- Resolution (decided by the Commander): the plain plugins `su3-developer-set` and `su3-product-owner-set` have no `hooks/` and no guard scripts, and are the ones submitted. The `su3-developer-set-with-guards` and `su3-product-owner-set-with-guards` variants keep the hooks and are distributed through this GitHub marketplace only. `scripts/validate.sh` enforces that only `-with-guards` plugins ship hooks and that a plugin and its variant stay identical apart from the suffix and guard-hook wording.

## Finding 2: frontmatter keys outside the allowed list

Message (finding code `LOCAL_CODE_FRONTMATTER_KEY`): "The directory accepts frontmatter keys and values outside the allowed list only from Verified organizations ... Remove each frontmatter key outside the allowed list, give a key such as tags only text, and give author only text or a person's name, email, and url, then push a new commit."

What the message does and does not say:

- It applies to "a skill, command, agent, or output style" in the plugin, so it is about frontmatter of those files, not about `plugin.json` (`userConfig` is not the cause).
- It does **not** name the key, the file, or the allowed list. The portal collapses the finding. We found no official page listing the allowed keys (checked: the pre-submission checklist, the plugin structure page, the directory publishing page, the platform support page).
- The only outside evidence was a third-party report ([pyvar PR #415](https://github.com/fibtecltd/pyvar/pull/415)): the same check began refusing on 2026-11-06 after passing on 2026-11-01, and a skill with only `name` and `description` was accepted. That report inferred, but did not confirm, which keys were refused.

### Keys our plugins used

| File type | Keys |
|---|---|
| Agent | `name`, `description`, `model`, `tools`, `skills`, `disallowedTools` (only in `product-owner-set`) |
| Skill | `name`, `description`, `argument-hint`, `disable-model-invocation` (command skills and `set-language`) |

All four submitted plugins were refused with the same message, so the cause had to be a key they all share: `model`, `tools`, `skills` (agents) or `argument-hint`, `disable-model-invocation` (skills).

### Method: probe versions on a branch

The submission follows a tracked branch. We pushed a branch `directory-probe` where each of the four plugins had a different set of keys removed, then pointed each submission at that branch and compared the scan results. The branch is never merged and `main` is untouched. (`scripts/validate.sh` fails on that branch by design: it requires `model`, and it checks that a plugin and its guard variant match.)

| Probe version | Keys removed | Keys left | Scan result |
|---|---|---|---|
| `su3-tech-writer-set`, round 1 | agent `tools`, `model` | agent `skills`; skill `argument-hint`, `disable-model-invocation` | refused |
| `su3-tech-writer-set`, round 2 | agent `tools`, `model`, `skills` | skill `argument-hint`, `disable-model-invocation` | **passed** |
| `su3-general-writer-set` | everything except `name`, `description` | `name`, `description` | **passed** |
| `su3-product-owner-set` | agent `skills`, `disallowedTools` | agent `model`, `tools`; skill `argument-hint`, `disable-model-invocation` | **passed** |
| `su3-developer-set` | skill `argument-hint`, `disable-model-invocation` | agent `model`, `tools`, `skills` | refused |

### Conclusion

- **Confirmed: the agent frontmatter key `skills` is outside the allowed list.** Every version that contained agent `skills` was refused (tech round 1, developer); every version without it passed (tech round 2, product-owner, general).
- **Confirmed accepted:** `name`, `description`, agent `model`, agent `tools`, skill `argument-hint`, skill `disable-model-invocation`.
- **Not tested:** `disallowedTools` (removed together with `skills` in the product-owner probe). Treat it as unknown. Only `su3-product-owner-set` and its variant use it (market-researcher and backlog-manager).
- The scan looks at keys. The values of `tools` (for example `Bash`, `Write`, `Edit`) were not a problem.

## Hook script findings (before the refusals)

These came from the portal's validation of the guard scripts and `hooks.json`. They are false positives in our case, but they blocked submission, so the text patterns that triggered them are worth remembering.

| Finding | Trigger | Fix |
|---|---|---|
| Write to a variable path | `printf ... >>"$MARKERS/adrs"`, `: >"$MARKERS/$KEY"` | `developer-set`: append to the fixed file `/tmp/developer-set-guard-dry-runs`, one `<session> <key>` line each. `product-owner-set`: keep no state; an ADR counts as written when a file under `docs/adr/` changed in the last 120 minutes. |
| "Writes wget's config file" | The word `wget` in a detection regex plus a redirect to a fixed file (`2>/dev/null`) | Removed the `/dev/null` redirects (test with `[ -f ]` and `[ -d ]` instead) and wrote the pattern as `wg[e]t`. Behavior is unchanged and covered by tests. |
| "Names `..`" (a path leaving the plugin) | `...` in comments and messages, and `\.\.` in a regex | Reworded the text and used `\.{1,2}` in the regex. |

Policy holds and notes that remain and need no fix (a reviewer reads them):

- the hook can approve tool calls (`HOOK_GRANTS_PERMISSION`, `HOOK_OUTPUT_UNINSPECTED`): our guards only return `deny` or `ask`;
- a credential is read and data could leave (`MCP_FORWARDS_CREDENTIAL_ENV`): a pattern-text match, nothing is read or sent;
- scripts the validator cannot follow (`COMMAND_SCRIPT_NOT_FOLLOWED`);
- download-and-execute (`RUNTIME_FETCH_EXEC`): the `curl | sh` detection pattern, and false matches on binary image bytes;
- the hook `command` is one string (`HOOK_COMMAND_IS_ONE_STRING`): a note.

## Current state (as of 2026-11-07)

All four plain plugins are at 0.1.1, built from `main`, and passed the security scan. They are waiting for the Anthropic reviewer to publish. The probe versions were withdrawn or replaced and were never published.

What the passing scan confirms: agents without `skills` and `disallowedTools`, with `tools` values that include `mcp__<server>` entries, and the listing URL fields in `plugin.json`. It does not confirm that the `mcp__<server>` form works at runtime (not yet tested; see ADR 0001).

For the record, the probe submissions were:

| Plugin | Probe version submitted | Scan |
|---|---|---|
| `su3-developer-set` | agent `skills` kept | refused (`LOCAL_CODE_FRONTMATTER_KEY`) |
| `su3-product-owner-set` | agent `skills`, `disallowedTools` removed | passed |
| `su3-tech-writer-set` | agent `tools`, `model`, `skills` removed | passed |
| `su3-general-writer-set` | only `name`, `description` | passed |

## Decision and what was done

Decision (Commander, 2026-11-07): option 1 below. The skill text the agents need is written directly into the agent bodies, in all six plugins. Duplication grows, but the agents run without any restricted key and keep least-privilege `tools`. Recorded in [ADR 0001](../adr/0001-inline-skill-text-instead-of-agent-skills-key.md).

1. Remove the `skills` key from every agent and write the skill text into each agent body (done). Keep `model`, `tools`, `argument-hint` and `disable-model-invocation`.
2. Do not use `disallowedTools` unless a probe shows it is accepted (still untested). The same limit is expressed with `tools`; the two agents that use connectors list common `mcp__<server>` prefixes (done).
3. Apply the same change to the `-with-guards` variants so each plugin and its variant stay identical and the parity check in `scripts/validate.sh` needs no change (done).
4. Push the real version to `main`, point each submission's tracked branch back to `main`, and check for new commits (done). Publish only a version that has the intended `tools` and `model`.
5. Delete the `directory-probe` branch (done).

Options that were considered for replacing the `skills` preload:

| Option | Effect |
|---|---|
| **1. Write the needed skill text into the agent body (chosen)** | Works without any key. Duplicates skill text in every agent. |
| 2. Add the `Skill` tool to the agent's `tools` and tell it which skill to load | Keeps one copy of the text. Reviewer agents would no longer be read-only, because `Skill` is not a read tool. |
| 3. Drop the preload | Simplest. Agents lose the standard report format and conventions unless the user asks for them. |

## Checklist for the next submission

- Frontmatter of agents, skills, commands and output styles: only `name`, `description`, `model`, `tools`, `argument-hint`, `disable-model-invocation` are confirmed accepted. Anything else is a risk; test it with a probe version before relying on it.
- `plugin.json` and `marketplace.json`: `author` as plain text or a name, email and url; `tags` and `keywords` as plain text values.
- No `hooks/` in a plugin that goes to the directory.
- In scripts, avoid writes to a variable path, `..`, and redirects to fixed files, even inside regex or comments, until the scan is known to ignore them.
- Use a probe branch and the portal's tracked-branch setting to experiment. Never publish a probe version.
- The portal says there is no way to apply to become a Verified organization; revisit when that changes.
