---
name: set-language
description: Set the language developer-set agents reply in (auto, en, ja, or a BCP-47 code). Use when the user runs /developer-set:set-language.
argument-hint: <auto|en|ja|BCP-47 code> [all]
disable-model-invocation: true
---

# Set output language

Change the `output_language` option of the `developer-set` plugin.

Current value: `${user_config.output_language}` (an unexpanded placeholder, an empty value, or `auto` all mean "same language as the user's input").

Arguments: `$ARGUMENTS`

## Steps

1. Read the first argument as the language code. If it is missing, ask the Commander which language they want and stop.
2. Accept only `auto` or a BCP-47 code: a 2 to 3 letter language, optionally followed by hyphen-separated subtags (`en`, `ja`, `fr`, `zh-CN`, `pt-BR`). Reject anything else and say why.
3. Save it by running the command below in Bash. The user approves the command, so do not work around a refusal.

   ```sh
   printf '{"output_language":"<code>"}' | claude plugin configure developer-set@scrum-ai-ecosystem --values-stdin
   ```

4. If the second argument is `all`, also run `claude plugin list` and repeat step 3 for every other installed plugin whose id ends with `@scrum-ai-ecosystem`. Each plugin keeps its own setting.
5. Report the result in one or two lines. Tell the Commander that the new value applies after Claude Code restarts. If the command fails, show its error. `claude plugin configure` needs Claude Code v2.1.285 or later. The Commander can also run `/plugin configure developer-set@scrum-ai-ecosystem` to edit it in a dialog.

## Guardrails

- Change only `output_language`. Never edit settings files by hand.
- Do not guess a code from a language name. Ask if the argument is ambiguous.
