---
name: release-check
description: Run a release readiness check with su3-developer-set-with-guards agents and produce a go or no-go recommendation. Use when the user runs /su3-developer-set-with-guards:release-check with a release scope, version or branch, or when project-implementation calls it at the end of a request.
argument-hint: <release scope, version or branch> [--parallel|--sequential]
---

# Release check

Input: `$ARGUMENTS` (the release scope, version or branch). If it is empty, ask the Commander what is being released, then stop.

You run this in the main session. This check never deploys, tags or publishes anything.

## Called or started alone

If the arguments name an existing unit directory (`docs/<YYYY-MM-DD>_<NNN>_<slug>/`, passed by `project-implementation` or another skill), its tickets' `05_completion_report.md` files are the evidence to collect, and the request is `00_request.md`. Read `- Mode:` and `- Policy:` from its `01_project_plan.md`; do not run the policy checks again and do not ask. Write nothing into the unit directory: return the result to the caller, which records it. Otherwise this skill was started alone: use the input as described above, and decide the mode from `${user_config.autonomy_mode}` (it is `unattended` only when the value, with all white space removed, is exactly `unattended`; anything else is `interactive`). In an unattended run never ask a question in chat. The agents never ask and never wait; they put questions under Open questions.

## Order and concurrency

Run the steps strictly in the order below. Call one agent at a time, wait for its complete result, and only then call the next. Never start two agent calls in the same turn, and never start a step before the previous one has returned.

Concurrency is optional and off by default. It is allowed only if the arguments contain `--parallel`, or the plugin setting `allow_concurrency` is `true` (current value: `${user_config.allow_concurrency}`; anything other than `true` means off). `--sequential` in the arguments turns it off for this run. When it is allowed, steps 2, 3 and 4 (`su3-qc-with-guards`, `su3-sre-with-guards` and `su3-aire-with-guards`) may run at the same time because they do not depend on each other. Every other step still waits for all earlier steps.

Remove `--parallel` and `--sequential` from the arguments before you use the rest as the input.

1. **`su3-developer-set-with-guards:su3-qa-with-guards`**: list the release criteria from the definition of done and collect the evidence each needs. Return the checklist with evidence status per item.
2. **`su3-developer-set-with-guards:su3-qc-with-guards`**: run the test suite and the resilience checks in the local or test environment. Return results as evidence (command and outcome) and any defects.
3. **`su3-developer-set-with-guards:su3-sre-with-guards`**: check release readiness: configuration, migrations, rollback path, monitoring and alerts, runbooks. Run read-only or plan-only commands against dev or staging only, never against production (the Commander runs those): list what you need under Open questions.
4. **`su3-developer-set-with-guards:su3-aire-with-guards`**: only if the release touches AI models, prompts or agents. Return the risk checklist status and eval results.
5. **`su3-developer-set-with-guards:su3-qa-with-guards`** again: apply the quality gate to the collected evidence. Return pass, conditional pass or fail with reasons.
6. **`su3-developer-set-with-guards:su3-project-manager-with-guards`**: write the recommendation: go, go with conditions, or no-go. Include the evidence summary, remaining risks, rollback plan and open questions.

## Output

Write everything you show the Commander in the output language configured for this plugin: `${user_config.output_language}`. If that value is `auto`, empty, or not a language code, use the language of the Commander's message. Code, file paths and agent names stay as they are.

Show the Commander the recommendation and the evidence behind it. The decision to release is the Commander's. Do not run any release, deploy, tag or publish command.

End your reply with exactly one line, plain, as its last line: `STATUS: DONE` (go), `STATUS: PARTIAL` (go with conditions) or `STATUS: BLOCKED` (no-go). No bold, backticks, quotes or period.
