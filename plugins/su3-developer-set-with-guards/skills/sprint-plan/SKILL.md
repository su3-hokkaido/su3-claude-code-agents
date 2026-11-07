---
name: sprint-plan
description: Plan a sprint with the su3-developer-set-with-guards agents. Use when the user runs /su3-developer-set-with-guards:sprint-plan with a sprint goal, a backlog file or a list of items.
argument-hint: <sprint goal, backlog path or item list> [--parallel|--sequential]
disable-model-invocation: true
---

# Sprint plan

Input: `$ARGUMENTS` (sprint goal, a path to a backlog, or a list of items). If it is empty, ask the Commander what the sprint goal and the backlog source are, then stop.

You run this in the main session and delegate to the agents below, in order. Pass each agent the original input and the previous agent's output.

## Order and concurrency

Run the steps strictly in the order below. Call one agent at a time, wait for its complete result, and only then call the next. Never start two agent calls in the same turn, and never start a step before the previous one has returned.

Concurrency is optional and off by default. It is allowed only if the arguments contain `--parallel`, or the plugin setting `allow_concurrency` is `true` (current value: `${user_config.allow_concurrency}`; anything other than `true` means off). `--sequential` in the arguments turns it off for this run. When it is allowed, steps 2 and 3 (`su3-system-architect-with-guards` and `su3-aire-with-guards`) may run at the same time because they do not depend on each other. Every other step still waits for all earlier steps.

Remove `--parallel` and `--sequential` from the arguments before you use the rest as the input.

1. **`su3-developer-set-with-guards:su3-project-manager-with-guards`**: break the input into tasks with owner, acceptance criterion, size and dependencies. Draft the sprint plan: goal, scope, capacity assumptions, risks.
2. **`su3-developer-set-with-guards:su3-system-architect-with-guards`**: only for items that need a design decision. Return a short feasibility note, design tasks and risks per item. Skip it when no item needs design.
3. **`su3-developer-set-with-guards:su3-aire-with-guards`**: only for items that touch AI models, prompts or agents. Return AI risks and the evals those items need. Skip otherwise.
4. **`su3-developer-set-with-guards:su3-qa-with-guards`**: check the plan against the definition of done. Return the gate criteria for the sprint and any task whose acceptance criterion is untestable.
5. **`su3-developer-set-with-guards:su3-project-manager-with-guards`** again: merge the notes into the final plan. Mark what was cut or deferred and why.

## Output

Write everything you show the Commander in the output language configured for this plugin: `${user_config.output_language}`. If that value is `auto`, empty, or not a language code, use the language of the Commander's message. Code, file paths and agent names stay as they are.

Show the Commander the final plan, then the open questions. Offer to save it (for example `docs/sprints/<name>.md`) and write the file only if the Commander agrees. Do not start any implementation task: the plan needs the Commander's approval first.
