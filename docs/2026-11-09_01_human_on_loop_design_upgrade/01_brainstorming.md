# 01. Brainstorming: human-on-the-loop design upgrade

- Date: 2026-11-09
- Status: Draft for the Commander's review
- Scope: `su3-developer-set` and `su3-developer-set-with-guards` first. Other plugins are out of scope until this design is approved.
- Source article: https://zenn.dev/su3_hokkaido/articles/2026-07-27_gen_subagents_with_fable (summarized in section 2)

## 1. Goal and background

### Goal

Build a **loop-engineering** setup based on **human-on-the-loop** (HOTL): the AI agents complete a whole pipeline (plan, design, implement, verify, release check, report) by themselves, and the Commander supervises the loop, sets its rules, and intervenes only at defined points.

### Why

| Mode | Problem |
|---|---|
| Human-in-the-loop (HITL) | The human approves every step. Development speed does not go up. |
| Fully out of the loop | Agents may decide dangerous operations alone (physical data deletion, one-shot migrations, live infrastructure changes). |
| **Human-on-the-loop (target)** | The human defines the rules and the stop conditions, watches the loop, and decides only what the rules reserve for a human. |

The key point: **safety must come from structure (rules, hooks, file-based evidence, independent verification), not from a human clicking "approve" on each step.** The human moves from approver of every step to designer and supervisor of the loop.

### Examples of rules the loop must enforce by itself

- No physical delete (`DELETE FROM table`, `TRUNCATE`, `DROP`) on production data. Use logical delete (a deleted flag or timestamp) or an archive table, and let a human run the real delete.
- No one-shot migration. Use the **expand / migrate / contract** pattern: create the new table, keep old and new in sync (dual write or a sync job), switch reads to the new table (old table read-only), verify, and only then retire the old table in a later, separately approved step.
- Data changes are dry-run first (already enforced by the guard hook).
- Live infrastructure changes and version upgrades need a human (already enforced by the guard hook).

## 2. Ideas taken from the Zenn article

| # | Idea in the article | Take it? | How it applies here |
|---|---|---|---|
| A1 | Split roles: designer and implementer are different agents, so ambiguity is not resolved in the implementer's favor. | Already done | Our agents are already split by role. |
| A2 | **PjM is the brain, the main session is the hands.** The PM outputs a *dispatch plan* (which role, in which order, with which input). The main session runs it. Nested subagent calls are not used. | Already done, make it explicit | `project-manager` has no `Agent` tool and returns assignments (CLAUDE.md). Formalize the dispatch plan as a file with a fixed format so the top-level skill can run it mechanically. |
| A3 | **File-based handoff** under one directory per project run, with numbered files (`00_request.md`, `20_project_plan.md`, ...; our version is in 5.4). Gives context separation, resumability, auditability. | **Adopt** | Core of the loop: state lives in files, not in the conversation. A new run directory convention and a status file per run. See section 5. |
| A4 | Common agent body format: Role, Responsibilities, Inputs/Outputs, Collaboration, Escalation, Style. | Partly done | Our template has Role, Responsibilities, Inputs/Outputs, Collaboration, Guardrails, Output Language. Add explicit `STATUS` values and escalation criteria to Guardrails (not a new section, to keep the validator stable). |
| A5 | **Structural quality**: the developer runs the quality gate and reports raw output; QA does **not** trust the report and re-runs the checks independently; QA is read-only on code; FAIL sends the work back. | **Adopt** | `qc` is the independent verifier. Make "do not trust the author's report, re-run" an explicit rule, and make QC's FAIL a machine-readable result the loop can act on. |
| A6 | **Retry cap**: at most 2 send-backs, then escalate to the human (prevents infinite loops). | **Adopt** | Mandatory exit condition for every loop. Add a budget (retries, and optionally an estimate overrun) to the loop contract. |
| A7 | **Human gates**: Gate 1 (plan approval), Gate 2 (completion approval), plus an any-time `STATUS: NEEDS_HUMAN_INPUT` stop. | **Adopt and shrink** | See section 4: for HOTL, Gate 1 is replaced by approving the Sprint Backlog plus the autonomy policy once; Gate 2 becomes review of a digest; stops are by rule. |
| A8 | Shared escalation criteria: strategy decisions, irreversible operations (delete, billing, publish), new paid services or credentials, estimate over 150%, QA send-backs over 2, conflicting artifacts. | **Adopt** | Becomes the "reserved for a human" list of the autonomy policy (section 4). |
| A9 | Guardrails layered on top of the existing ones (CLAUDE.md, PreToolUse hook, settings deny list); agent definitions never loosen them. | Already done | Keep. HOTL leans on this layer more, so it is extended (section 6). |
| A10 | Project-specific facts (commands, conventions) live in `CLAUDE.md` / `.claude/rules/`, not in agent definitions. | Already done | Keep. The quality-gate commands are read from the project. |
| A11 | Models: Opus for judgment and design, Sonnet for execution. | Check | Review model per agent. Not a goal of this project unless a cost problem shows up. |
| A12 | Short pipelines for small changes (00 -> 20 -> 50 -> 60 -> 90). | **Adopt** | The user's note that `code-implementation` calls agents "as needed" is the same idea. Implement as *route selection* by change type (section 5.3). |
| A13 | Not adopted: Product Manager, Designer, EM Support roles (they are covered by the `su3-product-owner-set` plugins or are out of scope). | No | Out of scope. |
| A14 | The author states the setup is **not yet proven in real projects**. | Note | We plan a pilot with measured results before declaring success (project plan, phase 5). |

## 3. Current state (as read from the repository on 2026-11-09)

### Agents (all exist in `su3-developer-set-with-guards`)

`project-manager`, `system-architect`, `app-developer`, `qa`, `qc`, `sre`, `aire`.

### Skills in `su3-developer-set` and `-with-guards`

| Skill | Kind | State |
|---|---|---|
| `coding-conventions`, `definition-of-done` | Rules / framework | Exist. Text is also inlined into agent bodies (ADR 0001). |
| `report-format` | Format | Exists. Inlined into agents. |
| `sprint-plan`, `design-review`, `release-check` | Phase command skills | Exist. Main-session skills, strict order, optional concurrency. |
| `set-language` | Utility | Exists. |
| `task-management`, `code-implementation`, `project-implementation` | Phase / top-level skills | **Do not exist yet** (the user's `[ ]` items). |

### Safety layer

- `guard-bash.sh` (`PreToolUse`, Bash only, acts only inside `-with-guards` subagents): data changes need a dry-run, then ask the human; live infrastructure and version upgrades ask the human; plan and dry-run forms pass.
- It is a text-pattern safety net, not a security boundary.

### Constraints that shape the design (from CLAUDE.md and ADR 0001)

1. **Only `-with-guards` plugins may ship hooks** (directory refuses command hooks from non-Verified organizations). The plain variants rely on text rules only.
2. **No new agent frontmatter keys** beyond `name`, `description`, `model`, `tools` (the directory scan refuses unknown keys). Skill keys known to pass: `argument-hint`, `disable-model-invocation`.
3. **`project-manager` has no `Agent` tool.** Orchestration happens in the main session via skills.
4. **Plugins are self-contained.** No shared files between plugins. Duplication is accepted.
5. Plain and `-with-guards` variants must stay identical apart from the suffix and guard wording (`validate.sh` checks it).
6. `ask` from a hook counts as a denial in non-interactive runs. **A loop that must not block on a human cannot rely on `ask`.** See section 6.
7. `SessionStart` context may not reach subagents, so do not rely on it.

## 4. Core design: autonomy policy and human touchpoints

### 4.1 Risk tiers

Every action an agent can take falls into one of four tiers. The tier decides who decides.

| Tier | Meaning | Examples | Who decides |
|---|---|---|---|
| **T0 Free** | Local, reversible, no external effect | Edit code and docs in the workspace, run tests, read-only queries, dry-runs and plans | Agent alone |
| **T1 Guarded** | Reversible with a defined safe pattern | Schema change using expand/migrate/contract, soft delete, adding a dependency (no upgrade), changing CI config | Agent, only by following the safe pattern; QC verifies |
| **T2 Reserved** | Hard to reverse or outward-facing | Contract step (drop old table), physical delete, production data change, live infrastructure apply, version upgrade, publish, spending money, new credentials | **Human**. The agent prepares everything (plan, dry-run output, rollback) and *parks* the item. |
| **T3 Forbidden** | Never, not even with approval inside the loop | `git push --force`, reading secrets, loosening a guard, editing its own guard hook | Denied by hook and by text rule |

HOTL means T0 and T1 run unattended, T2 is parked for the human, T3 cannot happen.

### 4.2 Park and continue, instead of block and wait

Today a T2 action triggers `ask`, which stops the agent until the human answers. In HOTL the loop should instead:

1. Write an **escalation record** (what, why, the exact command, dry-run result, rollback) in `06_commander_actions.md` of the ticket's document directory.
2. Mark the ticket `PARKED` and continue with other tickets that do not depend on it.
3. Link `06_commander_actions.md` from `05_completion_report.md` and list parked items first.

The human then approves or rejects in batch, on their own schedule. (Open question Q3: how the parked action is executed after approval.)

### 4.3 Human touchpoints (replacing "approve every step")

| Touchpoint | When | What the human does |
|---|---|---|
| **P0 Policy and Backlog approval** | Once per sprint / run, before the loop starts (replaces Gate 1) | Approves the Sprint Backlog and, if needed, edits the autonomy policy for this run (budget, allowed tiers, stop rules). |
| **P1 Watch** | During the loop, optional | Reads the run's status file and logs. No action required. |
| **P2 Interrupt** | Any time the rules fire | Loop stops on: retry cap exceeded, estimate overrun, conflicting artifacts, T2 on the critical path, a guard denial that repeats, unknown situation. Outcome `NEEDS_HUMAN_INPUT`. |
| **P3 Digest review** | End of run (replaces Gate 2) | Reads one digest (done, parked, failed, evidence). Decides on parked T2 items, release go / no-go, and git operations (git stays with the Commander). |

## 5. Proposed structure

### 5.1 Skill hierarchy

```
project-implementation        (top-level: runs the loop over a Sprint Backlog)
 └─ for each ticket / epic:
     task-management          (PM: plan, progress, risk, quality, delivery for one unit of work)
      ├─ design-review       (system-architect: design or review)   [when needed]
      ├─ code-implementation  (developer + QC loop, with aire/sre as needed)
      ├─ release-check        (QA/QC/SRE/AIRE evidence, go / no-go recommendation)
      └─ report-format        (digest and per-ticket reports)
```

Rules/frameworks consulted by all: `coding-conventions`, `definition-of-done`, plus two proposed additions:

- **`autonomy-policy`** (new): the risk tiers, reserved list, stop rules, retry cap and budget defaults (section 4). Single source of truth for "what may the loop do alone".
- **`safe-data-change`** (new): the expand / migrate / contract recipe, soft-delete rule, dry-run evidence required, rollback template. Agents and the policy refer to it.

### 5.2 Responsibilities of the three new skills

- **`task-management`**: input is one unit (Story, Epic, Feature or Ticket). It adapts to the unit size, asks `project-manager` for a plan, and emits a **dispatch plan** (file) listing steps: agent, input files, expected output file, acceptance criterion, tier of the riskiest action. It tracks status and updates the run's status file. It does not execute the steps itself.
- **`code-implementation`**: executes the implementation part of a dispatch plan. Selects only the agents the change type needs (route table in 5.3). Runs the implement -> independent verify -> fix loop with the retry cap.
- **`project-implementation`**: top-level. Reads the approved Sprint Backlog, creates the run directory, calls `task-management` per item, then `design-review` -> `code-implementation` -> `release-check` -> `report-format`, honoring the stop rules and parking T2 items. Stops with a digest.

Because skills run in the main session and agents cannot spawn agents, **the main session is the loop runner**; the PM supplies the plan and the files carry the state (idea A2, A3).

### 5.3 Route selection ("call agents as needed")

| Change type | Route (agents involved) |
|---|---|
| Docs / `CLAUDE.md` / agent or skill definition change | `aire` (review) -> (optional) `qa` |
| Small code fix | `app-developer` -> `qc` |
| Feature with design impact | `system-architect` -> `app-developer` -> `qc` (-> `aire` if AI involved) |
| Data model / migration | `system-architect` (safe-data-change plan) -> `app-developer` (expand step only) -> `qc` -> `sre` (rollback, monitoring); contract step is T2 |
| Infrastructure / pipeline | `sre` -> `qc` (plan-only) ; apply is T2 |
| Release | `release-check` |

The route is chosen by `task-management` and written into the dispatch plan, so it is visible and reviewable.

### 5.4 Document directory and files (file-based state, from A3)

*Revised 2026-11-09 by the Commander (replaces the earlier `docs/runs/` draft).*

**One directory per unit of work** (one Ticket, Story or Epic, the unit `task-management` handles): `docs/yyyy-mm-dd_NNN_{title}/`, where `NNN` is a 3-digit sequence number (example: `docs/2026-11-09_001_apply_human_on_loop_design_system`). The agent picks `NNN` by counting the directories of the same date. A run over several tickets creates several directories. Tracked in git; the Commander commits. (This brainstorming directory, `..._01_...`, predates the rule and stays as is.)

| File | Writer | Content |
|---|---|---|
| `00_request.md` | Commander (or drafted from the prompt and a URL snapshot by the main session) | AsIs, ToBe, SoThat, Acceptance Criteria, References, UI Design: written in the file or pointed to. If missing or incomplete, an agent creates the file from the template and asks the Commander to complete it. |
| `01_project_plan.md` | `project-manager`, `qa` | Status table at the top (`TODO / IN_PROGRESS / VERIFY / DONE / PARKED / BLOCKED`, retry counters, budget used), route, ordered steps with tier and acceptance criteria, quality criteria, "skipped: reason" lines. |
| `02_system_design.md` | `system-architect`; `aire`, `sre` as needed | Design, interfaces, data model, safe-change plan, links to ADRs. |
| `03_development_output.md` | `app-developer`; `aire`, `sre` as needed | Implementation output, raw gate output, verification done, hand-over notes. |
| `04_quality_report.md` | `qc` (release-check evidence goes here too) | Independent verification results, hand-over notes, and a record of every send-back and rework. |
| `05_completion_report.md` | `project-manager` | Final report to the Commander, including a summary of send-backs and the final result. Links to `06_commander_actions.md`. |
| `06_commander_actions.md` | `project-manager` with related agents | What the agents were forbidden or unable to do or verify, open confirmations, parked T2 actions (command, dry-run result, rollback), release steps, proposed commit commands. |

Rules:

- **Sections per writer.** Files 01 to 04 have several writers, so each agent edits only its own section (heading with the agent name). Only `project-manager` edits the status table. Steps run in order, so writes do not collide.
- **Skipped files.** A file a route does not need is not created (example: no `02_system_design.md` for a small fix); `01_project_plan.md` records "skipped: reason". Numbers never change.
- **Missing `00_request.md` fields.** In interactive mode the Commander is asked; in unattended mode the ticket is parked with a note in `06_commander_actions.md` and the loop continues with other tickets.
- **Writers do not write elsewhere.** ADRs stay in `docs/adr/`, the project policy file stays in its own location, sprint plans in `docs/sprints/`.
- Documents are written in the configured output language (`output_language`).

Replaces the earlier `10_dispatch_plan.md`, `80_escalations/`, `90_digest.md`, `status.md`.

### 5.5 Agent changes (small, no new frontmatter keys)

- Every agent ends with an explicit `STATUS:` line in its report: `DONE`, `PARTIAL`, `BLOCKED`, `NEEDS_HUMAN_INPUT`, or (QC only) `PASS` / `FAIL`. This makes the loop mechanical.
- `qc`: "Do not trust the author's report. Re-run the gate yourself." Verdict is evidence-based. (A5)
- `app-developer`: reports raw gate output; on design vs reality mismatch, records it and stops instead of redesigning (from the article).
- `project-manager`: produces the dispatch plan format; tags each step with the riskiest tier.
- Guardrails of every agent point to `autonomy-policy` for the tiers (text duplicated into the body, per ADR 0001).

## 6. Enforcement: making the policy real

Text rules guide agents; **hooks enforce**. HOTL depends on enforcement because no human watches each command.

1. **Extend `guard-bash.sh` (only in `-with-guards`)** with T2/T3 patterns that today are not covered or only ask:
   - `DELETE FROM` / `TRUNCATE` / `DROP TABLE|DATABASE|SCHEMA` against anything (not only production): deny, and print the safe-pattern hint ("use soft delete / expand-migrate-contract, park for the human").
   - Existing `ask` cases (live infrastructure, upgrades): in HOTL mode they should become **deny + escalation hint** (so the loop parks instead of blocking). Whether to switch by a plugin option or by an environment value is Q4.
2. **A guard for file writes** (`PreToolUse` for `Edit|Write`, `-with-guards` only): deny edits to the guard scripts, `hooks/`, `.claude/settings*.json` and secrets files by agents (T3: an agent must not loosen its own guard). Check feasibility first.
3. **Plain variants** cannot ship hooks, so they carry the text policy only. Document this difference in the README so users know that autonomy is safe only with the `-with-guards` variant or their own hooks/settings deny rules.
4. Keep the existing rule that guards act only for agents of the same plugin (`agent_type` prefix).
5. Guard test coverage: extend `scripts/test-hooks.sh` with cases for every new pattern and for the "must still pass" read-only and dry-run forms.

Reminder from CLAUDE.md: the guard is a text-pattern safety net. Deny rules in `settings.json` and database-side permissions (a read/write role that has no `DELETE` grant) are the real boundary. The documentation should recommend them for any project that runs the loop unattended.

## 7. Risks and open design problems

| # | Risk / problem | Mitigation idea |
|---|---|---|
| R1 | Infinite or runaway loops, cost explosion | Retry cap (2), per-run budget (steps, time, estimate overrun 150%), stop rule fires `NEEDS_HUMAN_INPUT`. |
| R2 | Agents work around a guard by rewording a command | Deny list for T3, escalation hint in the denial message, QC checks the command history in the report, and the guard is documented as a net, not a wall. |
| R3 | Author and verifier share blind spots | QC re-runs independently; consider a different model for QC; spot-check by the Commander at P3. |
| R4 | State in files drifts from reality | Each agent edits only its own section; the status table is edited only by `project-manager`. |
| R5 | A skill calling other skills may not work as assumed (main session invoking `Skill` from inside a skill) | Verify against the official docs and with a test run in phase 1. Fall back to a single top-level skill that contains the loop text and refers to the phase skills by name. |
| R6 | Directory scan rejects new keys or hooks | No new frontmatter keys. Hooks stay in `-with-guards` only. Test with a probe branch when in doubt (ADR 0001). |
| R7 | Duplication between base and guards plugins and between agents grows | Accepted by design. `validate.sh` parity check extended to the new skills. |
| R8 | Output language: new skills run in the main session | Each new command skill carries its own `${user_config.output_language}` line (CLAUDE.md). |
| R9 | Parked items pile up and the human becomes the bottleneck again | Batch review at P3 with a prepared command and rollback per item; track the parked ratio as a metric. |
| R10 | Article's setup is unproven in practice | Pilot with a small real project and measure (plan phase 5). |

## 8. Open questions for the Commander

- **Q1. Scope of tiers.** Do you agree with the four tiers (T0 to T3) and with putting "contract step of a migration" and "any physical delete" in T2? Anything else to reserve (for example, dependency additions, CI changes)?
- **Q2. Gate 1 replacement.** Is "approve the Sprint Backlog once (P0), no per-ticket plan approval" acceptable?
- **Q3. Executing parked T2 items.** After you approve a parked item, who runs it: you (copy the prepared command), or an agent with a one-time permission? The first is safer and simpler; the second is faster.
- **Q4. HOTL mode switch.** Should converting `ask` to `deny + park` be a plugin option (for example `autonomy_mode`: `interactive` / `unattended`, default `interactive`), or a separate variant? A new option adds a `userConfig` key (allowed, like `allow_concurrency`).
- **Q5. Run directory.** Path `docs/runs/...` (consistent with `docs/sprints/`) and commit it, or keep it local and gitignored? The article keeps it under `.claude/documents/`.
- **Q6. Naming.** Use the skill names you listed (`task-management`, `project-implementation`, `code-implementation`) as they are? Same names in the plain and `-with-guards` plugins is allowed by the name rule (pair).
- **Q7. Other plugins.** Should the product-owner, tech-writer and general-writer sets get the same loop later, or stay manual?
- **Q8. Model assignment.** Keep the current models, or set QC to a different model than the developer to reduce shared blind spots?
- **Q9. Git.** Keep git write operations fully with the Commander (assumed), so the loop ends with a digest and a ready list of commit commands?

## 9. Summary of decisions proposed

1. Adopt from the article: file-based state, dispatch plan by PM, independent QC re-run, retry cap, shared escalation criteria, short routes.
2. Replace per-step human approval with **risk tiers + park-and-continue + four human touchpoints**.
3. Add skills `task-management`, `code-implementation`, `project-implementation`, plus rule skills `autonomy-policy` and `safe-data-change`.
4. Add `STATUS:` lines to every agent report so the loop is mechanical.
5. Enforce T2/T3 with the hook in `-with-guards`; document that plain variants rely on text rules.
6. Verify skill-to-skill invocation and any new hook behavior first (phase 1), and run a pilot before release.

## 10. Commander's answers (2026-11-09)

The full decision log is in `02_project_plan.md`, section 8. Key effects on this design:

- **Project policy file (Q1, Q3, Q9).** Tier details are not hard-coded in the plugin only. The target repository holds a separate policy file (forbidden actions, confirm-required actions, actions the agent may run after approval and in which environments, rules and rationale, git handling). The repository's `CLAUDE.md` references it by import, and agents and skills check for it when they are called. The plugin ships defaults and a template.
- **Defaults for "agent may run after approval" (Q3):** dev/staging infrastructure apply, dev/staging DB data change and delete, patch/minor version updates. Everything else stays with the Commander.
- **Input and team model (Q2).** The Commander writes Epic / Story / Ticket md files and names the targets; the input is the whole Sprint Backlog. Work is split by scope like a multi-person scrum team. Q10 (decided): the team members are humans, each running the loop on their own scope; see below.
- **Mode (Q4):** `autonomy_mode` plugin option. **Document directory (Q5, revised):** `docs/yyyy-mm-dd_NNN_{title}/` per ticket / story / epic, files `00`–`06` (section 5.4), tracked in git. **Names (Q6):** as proposed. **Scope (Q7):** developer-set pair only; the product-owner redesign is a separate project. **Models (Q8):** unchanged, evaluate in the pilot. **Git (Q9):** selected in the policy file, default Commander-only.
- **Scope and team model (Q10).** Each human engineer (A, B, C) runs `project-implementation` / `code-implementation` on their own tickets (for example 1-3, 4-8, 10-12) in their own session. No cross-scope concurrency or conflict handling is built into the plugin. **No scope arguments** (withdrawn): the member names the target tickets in natural language in the prompt, and `project-manager` reads them and expands them into work for the other agents. Agents run on each member's local machine, and no mapping to Notion or Jira formats is built. The ticket source can be an md file or a URL (Notion, Jira, Confluence, Nulab Backlog); by default the main session reads it through the user's own connector and saves a snapshot as `00_request.md` for `project-manager` (least-privilege tools; to be verified). The third-party QA person (D) works with a separate skill/agent set (formatter, test run, edge cases, production-like data, resilience tests), planned as a separate project.
