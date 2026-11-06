---
name: tech-editorial-review
description: "Editorial review checklist for technical writing: structure, clarity, technical accuracy, terminology consistency, AI slop removal, and a standard review report. Use when reviewing a technical article, documentation or translation."
---

# Technical editorial review

For technical writing. Accuracy and terminology consistency come first, then clarity and structure.

## Review order

Work in this order. Do not polish sentences in a section you think should be cut.

1. **Purpose and audience.** Who is this for, what should they know or do afterwards, and does the text deliver it?
2. **Structure.** Order of sections, headings that say what is inside, a clear opening that states the point, a conclusion that adds something, and no repeated material.
3. **Clarity.** Ambiguous references (`it`, `this`, `それ`, `これ`), long sentences, buried main points, undefined terms, missing context or steps.
4. **Accuracy.** Facts, numbers, names, dates and links that look wrong or unsupported. Do not correct from memory. Mark them "verify".
5. **Language.** Typos, grammar, wrong words, inconsistent spelling, punctuation, unit and number formats.
6. **AI slop.** See below.

## AI slop

Flag text that sounds generated and says little. Typical patterns:

- Opening filler: `In today's fast-paced world`, `In the ever-evolving landscape of`, `Have you ever wondered`, `現代社会において`, `〜の時代です`.
- Throat-clearing and announcing: `It's important to note that`, `Let's dive in`, `In this article, we will explore`, `ここでは〜を見ていきましょう`, `〜について解説します` repeated in every section.
- Inflated or empty adjectives and verbs: `game-changer`, `seamless`, `robust`, `powerful`, `delve`, `leverage`, `unlock`, `革新的な`, `強力な`, `シームレスな`, with no evidence.
- Formulaic contrast and rhythm: `It's not just X, it's Y`, `Not only … but also …` used repeatedly, rhetorical questions that are answered at once, three-item lists everywhere, every paragraph ending in a punchy one-liner.
- Heavy em-dash use, emoji bullets and headings, bold on random phrases.
- Summaries that restate the text, conclusions such as `In conclusion` / `まとめると` that add nothing, vague closers (`I hope this helps`).
- Hedging and padding: `may potentially`, `various`, `a variety of`, `さまざまな`, `〜と言えるでしょう` throughout.
- Claims with no specifics: replace with a concrete number, example, name or delete.

For each hit, say what to do: cut it, or replace it with a specific fact the author knows. Do not invent the fact.

## Severity

- **Blocker**: wrong or unsupported claim, missing step that breaks the reader's task, confidential content, broken code.
- **Major**: unclear main point, structural problem, repeated slop pattern, inconsistent terminology.
- **Minor**: typo, single awkward sentence, style preference.

## Output format

```markdown
## Verdict
ready | revise | rework — one sentence why.

## Findings
| # | Severity | Location | Problem | Suggestion |
|---|---|---|---|---|
| 1 | major | "Section name", paragraph 2 | … | … |

## Verify before publishing
- Claims, versions, links or numbers that need a check, and who can check them.

## Strengths
- One or two things to keep.
```

Keep suggestions short and concrete. Quote the exact text. Do not rewrite the whole draft unless the Commander asks. Write "None" in a section that has nothing.

## Technical checks

- **Code and commands**: each example is complete enough to run, uses the right language tag, shows the expected output when it helps, and matches the text that describes it. Do not mark code as correct unless you ran it. Write "not run".
- **Versions and environments**: versions, OS, tool and library names are stated and consistent. Flag `latest` and unstated versions.
- **Claims**: performance numbers, benchmarks, security statements and comparisons have a source or a method. Otherwise mark them "verify".
- **Prerequisites and order**: steps can be followed in order by the stated audience. Missing prerequisites are a major problem.
- **Links and references**: each link has a clear label and a reason to exist. Flag links that you cannot confirm.
- **Confidentiality**: internal hostnames, account ids, customer names, tokens and unreleased plans must not appear. Treat any as a blocker.

## Terminology consistency

1. Build a term table from the text: term, variants used, the chosen form, where the variants occur.
2. Flag every variant that differs from the chosen form (`ユーザー`/`ユーザ`, `サーバー`/`サーバ`, `deploy`/`デプロイ`/`展開`).
3. Check that English product and API names use their official capitalization (`GitHub`, `PostgreSQL`, `Kubernetes`).
4. Check that the style (`です・ます` or `だ・である`) and the spacing rule between Japanese and Latin text do not change inside the article.
5. Follow the project's glossary if there is one. A glossary term beats your preference.

## Japanese technical writing

- Prefer short sentences. State the subject when a step has several actors.
- Avoid ra-nuki (`食べれる`) and i-nuki (`してる`) in prose. Report each hit with the corrected form.
- Avoid vague words that hide the actual condition (`適切に`, `いい感じに`, `よしなに`). Ask for the actual rule.
