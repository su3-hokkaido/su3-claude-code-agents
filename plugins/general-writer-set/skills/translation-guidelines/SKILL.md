---
name: translation-guidelines
description: "Guidelines for translating general-audience text between Japanese and English: meaning, tone, natural phrasing, consistency, formatting. Use when translating or reviewing a Japanese-English or English-Japanese translation."
---

# Translation guidelines

For general-audience text. Readability and natural expression come first.

## Principles

1. **Meaning first.** Translate what the text means for the reader, not word by word. Keep every fact, number, condition and caveat. Do not add, omit or soften anything.
2. **Natural target language.** The result should read as if it had been written in the target language. Restructure sentences when the source structure is unnatural in the target.
3. **Consistent terms.** Use one translation per term throughout. Follow the glossary if one is given. Otherwise build a short term table as you go and report it.
4. **Same register.** Match the formality and tone of the source and what the target reader expects.
5. **Do not fix silently.** If the source looks wrong, ambiguous or inconsistent, translate it as written and raise a note.

## Japanese to English

- Japanese often drops subjects and objects. Supply them from context. Choose the subject that the context supports, and note it when unsure.
- Split long Japanese sentences. Put the main point first.
- Turn nominalized and passive Japanese into active English verbs when the meaning stays the same.
- Convert politeness levels to an appropriate English tone, not to stiff phrases. Do not translate honorifics (`さん`, `様`) into titles unless the context needs it. Keep `-san` only when the text is about Japanese culture.
- Convert Japanese date and number formats (`2026年11月6日`, `万`, `億`) to the target convention and say so in notes when the conversion could be misread.
- Names: use the form the person or company uses in English. Otherwise use Hepburn romanization, given name first, unless the source's context requires otherwise.

## English to Japanese

- Choose one style for the whole text and keep it: です・ます調 (default for readers) or だ・である調 (documents, reports). Follow the source's formality and the Commander's instruction.
- Avoid literal calques: `it is important to note that`, `in order to`, unnecessary `this`, `that`, `あなた`, `私たち`. Drop pronouns the Japanese does not need.
- Break long English sentences into shorter Japanese ones. Put the verb last and keep modifiers close to what they modify.
- Avoid stacking `〜の〜の〜`. Avoid overusing passive `〜される` and `〜することができる`. Prefer `〜できる`.
- Use full-width punctuation `、。` for prose. Keep half-width digits and Latin letters. Follow the project's rule on spaces between Japanese and Latin text, and be consistent.
- Katakana: long vowel marks follow the project's rule. If there is none, use the `ー` form for words ending in -er, -or, -ar (`ユーザー`, `サーバー`) consistently.

## Preserve

- Markdown structure, headings, lists, tables, front matter keys, link targets and anchors.
- Placeholders and variables such as `{name}`, `%s`, `${VAR}`, and HTML or XML tags.
- Numbers, units and currencies. Convert only when asked, and show both when converting.
- Quoted text and proper names, unless the source gives an official translation.

## Process

1. Read the whole text first. Identify the audience, purpose, register and recurring terms.
2. Translate paragraph by paragraph.
3. Re-read the translation alone, as the target reader. Fix anything that sounds translated.
4. Compare with the source: numbers, names, conditions, negations and every list item.

## Output

1. The translation, in the same file format as the source.
2. **Translator notes** (in the configured output language): term table, choices where the meaning could go two ways, suspected problems in the source, and anything left untranslated on purpose. Write "None" when there are none.

## Emphasis for general readers

- Prefer plain words over jargon. If a term must stay technical, explain it once.
- Keep the voice of the writer: humor, warmth and rhythm matter as much as accuracy.
- Adapt idioms and cultural references to equivalents the target reader knows, and note each adaptation.
