---
name: product-adr
description: How to record a product decision as an ADR (architecture decision record style) with its history. Use before changing a roadmap, vision, priority or backlog document, or when a past decision is reversed or refined.
---

# Product ADR

Product decisions and their history must outlive the conversation. Before you write or change anything under `docs/product/` or `docs/backlog/`, write an ADR. The plugin's guard hook blocks those writes unless an ADR was written in the last 120 minutes.

## Where

`docs/adr/NNNN-short-title.md`, where `NNNN` is the next free four-digit number (look at the existing files). Create the file with Write. If the project already keeps ADRs elsewhere, tell the Commander and ask before using another place.

## Never rewrite history

An existing ADR is never edited, overwritten, renamed or removed. The hook blocks it. To change a decision, write a **new** ADR that says which ADR it supersedes and why. The only change to an old ADR, setting its status to `Superseded by NNNN`, is made by the Commander.

## Template

```markdown
# NNNN. Title in the form of the decision

- Status: Proposed | Accepted | Superseded by NNNN | Rejected
- Date: YYYY-MM-DD
- Deciders: who decided or will decide (the Commander approves)
- Supersedes: NNNN (or "none")

## Context

The situation and the problem. Include the history: what was decided or tried before, what changed since, and links to the evidence (tickets, research, data). Facts first, then your reading of them.

## Decision

What is decided, in one or two sentences. Use "we will ...".

## Alternatives considered

- Option, and why it was not chosen.

## Consequences

- What becomes easier, what becomes harder, what must follow (tickets to create, documents to update). Name the risks and how they will be noticed.
```

## Rules

- Status stays `Proposed` until the Commander approves. Never write `Accepted` on your own.
- One decision per ADR. Split a bundle.
- Name the evidence. A decision with no source is an assumption: say so.
- If you are changing a roadmap, priority order or backlog structure, the ADR says what it was before and what it is now, so the past can be reconstructed.
- After the ADR exists, write the roadmap or backlog document and link the ADR from it.
