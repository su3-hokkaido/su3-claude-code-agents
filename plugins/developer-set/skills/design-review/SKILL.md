---
name: design-review
description: Review a design document or architecture proposal with developer-set agents. Use when the user runs /developer-set:design-review with a design doc path or a description.
argument-hint: <design doc path or description> [--parallel|--sequential]
disable-model-invocation: true
---

# Design review

Input: `$ARGUMENTS` (a path to a design document or ADR, or a description of the design). If it is empty, ask the Commander what to review, then stop.

You run this in the main session. The reviewers only read. Give each one the design and the relevant code paths.

## Order and concurrency

Run the steps strictly in the order below. Call one agent at a time, wait for its complete result, and only then call the next. Never start two agent calls in the same turn, and never start a step before the previous one has returned.

Concurrency is optional and off by default. It is allowed only if the arguments contain `--parallel`, or the plugin setting `allow_concurrency` is `true` (current value: `${user_config.allow_concurrency}`; anything other than `true` means off). `--sequential` in the arguments turns it off for this run. When it is allowed, the reviewers in step 2 (`sre`, `aire`, `qa`) may run at the same time because they do not depend on each other. Every other step still waits for all earlier steps.

Remove `--parallel` and `--sequential` from the arguments before you use the rest as the input.

1. **`developer-set:system-architect`**: restate the design in a few lines (so every reviewer works from the same understanding) and list its assumptions and open decisions.
2. Run these reviewers one after another (see Order and concurrency). Each returns findings ranked by severity (blocker, major, minor), each with evidence from the design or code:
   - **`developer-set:sre`**: operability, deployment, rollback, monitoring, capacity, failure modes.
   - **`developer-set:aire`**: only if the design includes AI models or agents. Safety, privacy, evals, permissions.
   - **`developer-set:qa`**: testability, acceptance criteria, quality gates.
3. **`developer-set:system-architect`** again: answer each blocker and major finding. Accept it and say how the design changes, or reject it with a reason.
4. **`developer-set:project-manager`**: summarize the review: verdict (approve, approve with changes, rework), required changes with owners, and open questions.

## Output

Write everything you show the Commander in the output language configured for this plugin: `${user_config.output_language}`. If that value is `auto`, empty, or not a language code, use the language of the Commander's message. Code, file paths and agent names stay as they are.

Show the Commander the verdict, the required changes and the open questions. Do not change the design document yourself. If the Commander wants the updates written, delegate that to `developer-set:system-architect`.
