---
name: editorial-review
description: "Editorial review checklist for general-audience writing: structure, clarity, polish, Japanese ra-nuki and i-nuki checks, AI slop removal, and a standard review report. Use when reviewing or polishing a draft or translation."
---

# Editorial review

For general-audience writing. Readability and natural expression come first.

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

## Japanese checks: ra-nuki and i-nuki

Check Japanese text for dropped-syllable colloquialisms. They are fine in casual dialogue or when the Commander wants a casual voice, and wrong in formal or neutral prose. Decide from the register, and say which you applied.

**ra-nuki (ら抜き言葉)**: the potential form of an ichidan (一段) or ka-hen (来る) verb loses `ら`.

| Wrong (ra-nuki) | Correct |
|---|---|
| 食べれる | 食べられる |
| 見れる | 見られる |
| 来れる | 来られる |
| 起きれる | 起きられる |
| 出れる | 出られる |
| 考えれる | 考えられる |
| 信じれる | 信じられる |

Not ra-nuki: godan verbs (`書ける`, `読める`, `行ける`) are correct as written. Do not flag them.

**i-nuki (い抜き言葉)**: `〜ている` loses `い`.

| Wrong (i-nuki) | Correct |
|---|---|
| してる | している |
| 見てる | 見ている |
| 書いてる | 書いている |
| 使ってる | 使っている |
| 思ってる | 思っている |

Also check, in the same pass: `〜ちゃう/じゃう`, `〜ていく → 〜てく`, `やっぱり`, `〜っていう` in formal prose, and mixed registers (`です・ます` with `だ・である`) within one text.

Report each hit with its location and the corrected form. Do not flag quoted speech.

## Naturalness (general readers)

- Cut jargon or explain it once. Replace noun-heavy phrases with verbs.
- Vary sentence length. Remove repeated sentence openings.
- Keep the author's voice. Do not flatten humor or warmth.
