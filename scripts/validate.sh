#!/bin/sh
# Validates the marketplace and every plugin in it.
#
# Checks:
#   1. JSON syntax of marketplace.json, plugin.json and hooks.json
#   2. marketplace.json entries match plugin directories and plugin.json names
#   3. plugin.json declares the output_language userConfig option
#   4. Required frontmatter in agents and skills
#   5. Agent / skill names are unique across all plugins
#   6. The "Output Language" section of every agent equals scripts/output-language-block.md
#   6b. Versions: SemVer in plugin.json only, with a matching CHANGELOG heading
#   7. Repository rules (no commands/ directory, no shared/ directory)
#   7b. Hook scripts: syntax and scripts/test-hooks.sh
#   8. `claude plugin validate`, when the claude CLI is available
#
# Requires: sh, jq, awk. POSIX sh; works on macOS and Linux.
# Usage: scripts/validate.sh   (run from anywhere)

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

ERRORS=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

err() {
  echo "ERROR: $*" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo "WARN:  $*" >&2
}

info() {
  echo "$*"
}

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required" >&2
  exit 1
}

# Names that are namespaced by the plugin and may repeat across plugins.
ALLOWED_DUPLICATES="set-language"

# --- frontmatter helpers ----------------------------------------------------

# Prints the value of a top-level frontmatter key, or nothing.
fm_get() {
  awk -v key="$2" '
    NR == 1 { if ($0 != "---") exit; infm = 1; next }
    infm && $0 == "---" { exit }
    infm {
      i = index($0, ":")
      if (i > 0 && substr($0, 1, i - 1) == key) {
        v = substr($0, i + 1)
        sub(/^[ \t]+/, "", v)
        sub(/[ \t]+$/, "", v)
        print v
        exit
      }
    }
  ' "$1"
}

has_frontmatter() {
  [ "$(head -n 1 "$1")" = "---" ] && awk 'NR > 1 && $0 == "---" { found = 1; exit } END { exit !found }' "$1"
}

# Prints the "# Output Language" section (heading included) up to the next
# level-1 heading or EOF, with trailing blank lines removed.
output_language_block() {
  awk '
    /^```/ { fence = !fence }
    !fence && /^# / {
      if (inblock) exit
      if ($0 == "# Output Language") inblock = 1
    }
    inblock { print }
  ' "$1" | awk '{ lines[NR] = $0 } END { n = NR; while (n > 0 && lines[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }'
}

# --- 1. JSON syntax ---------------------------------------------------------

info "== JSON syntax"
JSON_FILES=$(find . -path ./.git -prune -o -type f \( -name 'marketplace.json' -o -name 'plugin.json' -o -name 'hooks.json' \) -print | sort)
for f in $JSON_FILES; do
  jq empty "$f" 2>/dev/null || err "$f: invalid JSON"
done

# --- 2. marketplace.json ----------------------------------------------------

info "== Marketplace"
MP=".claude-plugin/marketplace.json"
if [ ! -f "$MP" ]; then
  err "$MP is missing"
else
  [ "$(jq -r '.name // empty' "$MP")" = "su3-hokkaido-ai-ecosystem" ] || err "$MP: name must be su3-hokkaido-ai-ecosystem"
  [ -n "$(jq -r '.owner.name // empty' "$MP")" ] || err "$MP: owner.name is required"
  [ -n "$(jq -r '.description // empty' "$MP")" ] || warn "$MP: description is missing"

  jq -r '.plugins[] | [.name, .source] | @tsv' "$MP" 2>/dev/null | while IFS="$(printf '\t')" read -r pname psource; do
    case "$psource" in
      ./plugins/*) ;;
      *) echo "ERROR: $MP: plugin $pname: source must start with ./plugins/ (got $psource)" >&2; echo x >>"$TMP/errs"; continue ;;
    esac
    [ -d "$psource" ] || { echo "ERROR: $MP: plugin $pname: $psource does not exist" >&2; echo x >>"$TMP/errs"; continue; }
    manifest="$psource/.claude-plugin/plugin.json"
    [ -f "$manifest" ] || { echo "ERROR: $manifest is missing" >&2; echo x >>"$TMP/errs"; continue; }
    mname=$(jq -r '.name // empty' "$manifest")
    [ "$mname" = "$pname" ] || { echo "ERROR: $manifest: name '$mname' differs from marketplace entry '$pname'" >&2; echo x >>"$TMP/errs"; }
    [ "$(basename "$psource")" = "$pname" ] || { echo "ERROR: $psource: directory name differs from plugin name '$pname'" >&2; echo x >>"$TMP/errs"; }
  done
  # Subshell errors are counted through a marker file.
  if [ -f "$TMP/errs" ]; then
    ERRORS=$((ERRORS + $(wc -l <"$TMP/errs")))
    rm -f "$TMP/errs"
  fi

  # Every plugin directory must be listed.
  for d in plugins/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    jq -e --arg n "$n" '.plugins[] | select(.name == $n)' "$MP" >/dev/null 2>&1 || err "plugins/$n is not listed in $MP"
  done
fi

# --- 3. plugin.json ---------------------------------------------------------

info "== Plugin manifests"
for d in plugins/*/; do
  [ -d "$d" ] || continue
  p=$(basename "$d")
  m="plugins/$p/.claude-plugin/plugin.json"
  [ -f "$m" ] || { err "$m is missing"; continue; }
  case "$p" in
    *[!a-z0-9-]* | -* | *-) err "$m: plugin name '$p' must be kebab-case" ;;
  esac
  case "$p" in
    su3-*) ;;
    *) err "$m: plugin name '$p' must start with 'su3-'" ;;
  esac
  for key in version description author homepage repository license keywords; do
    jq -e --arg k "$key" 'has($k)' "$m" >/dev/null 2>&1 || warn "$m: recommended field '$key' is missing"
  done
  # Components must use default directories (no custom path keys).
  for key in agents skills commands hooks mcpServers; do
    jq -e --arg k "$key" 'has($k)' "$m" >/dev/null 2>&1 && err "$m: do not set '$key'; use the default directory"
  done
  jq -e '.userConfig.output_language.type == "string" and (.userConfig.output_language.default == "auto")' "$m" >/dev/null 2>&1 \
    || err "$m: userConfig.output_language must be a string option with default \"auto\""
  [ -f "plugins/$p/README.md" ] || err "plugins/$p/README.md is missing"
  [ -d "plugins/$p/commands" ] && err "plugins/$p/commands exists; use skills/ instead"
  [ -e "plugins/$p/CLAUDE.md" ] && err "plugins/$p/CLAUDE.md exists; it is not loaded by Claude Code"
done
# Every ${user_config.KEY} used in a plugin must be declared in its plugin.json.
for d in plugins/*/; do
  [ -d "$d" ] || continue
  p=$(basename "$d")
  m="plugins/$p/.claude-plugin/plugin.json"
  [ -f "$m" ] || continue
  grep -rhoE --include='*.md' --include='*.json' '\$\{user_config\.[A-Za-z0-9_]+\}' "plugins/$p" 2>/dev/null | sort -u | while read -r ref; do
    key=${ref#'${user_config.'}
    key=${key%'}'}
    jq -e --arg k "$key" '.userConfig | has($k)' "$m" >/dev/null 2>&1 || { echo "ERROR: plugins/$p uses $ref but $m does not declare it" >&2; echo x >>"$TMP/errs"; }
  done
done
if [ -f "$TMP/errs" ]; then
  ERRORS=$((ERRORS + $(wc -l <"$TMP/errs")))
  rm -f "$TMP/errs"
fi
# Versions: SemVer in plugin.json, none in marketplace.json, and a CHANGELOG heading for each.
CL="CHANGELOG.md"
[ -f "$CL" ] || err "$CL is missing"
for d in plugins/*/; do
  [ -d "$d" ] || continue
  p=$(basename "$d")
  m="plugins/$p/.claude-plugin/plugin.json"
  [ -f "$m" ] || continue
  v=$(jq -r '.version // empty' "$m")
  case "$v" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) err "$m: version '$v' must be set and look like MAJOR.MINOR.PATCH"; continue ;;
  esac
  case "$v" in
    *[!0-9.]*) err "$m: version '$v' must be plain MAJOR.MINOR.PATCH" ;;
  esac
  [ -f "$CL" ] && { grep -Eq "^## $p $v( \(.*\))?$" "$CL" || err "$CL has no heading '## $p $v' for the version in $m"; }
done
if [ -f "$MP" ]; then
  jq -e 'has("version") or ([.plugins[] | has("version")] | any)' "$MP" >/dev/null 2>&1 && err "$MP: do not set version in the marketplace file; plugin.json owns it"
fi
[ -d shared ] && err "shared/ must not exist (plugins are self-contained)"
[ -d plugins/shared ] && err "plugins/shared must not exist (plugins are self-contained)"

# --- 4. agent and skill frontmatter -----------------------------------------

info "== Agents and skills"
NAMES="$TMP/names"
: >"$NAMES"

# Frontmatter values that contain ": " or " #" must be quoted, or strict YAML
# parsers (such as the directory validator) reject or truncate them.
for f in plugins/*/agents/*.md plugins/*/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  bad=$(awk '
    NR == 1 { if ($0 != "---") exit; infm = 1; next }
    infm && $0 == "---" { exit }
    infm && /^[A-Za-z][A-Za-z0-9_-]*:[ \t]+/ {
      v = $0; sub(/^[A-Za-z][A-Za-z0-9_-]*:[ \t]+/, "", v)
      if (v !~ /^["\x27>|\[{]/ && (v ~ /: / || v ~ / #/ || v ~ /:$/)) { print NR; exit }
    }
  ' "$f")
  [ -z "$bad" ] || err "$f: line $bad of the frontmatter has an unquoted value containing ': ' or ' #'; put the whole value in double quotes"
done

for f in plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  p=$(echo "$f" | cut -d/ -f2)
  has_frontmatter "$f" || { err "$f: missing frontmatter"; continue; }
  name=$(fm_get "$f" name)
  desc=$(fm_get "$f" description)
  model=$(fm_get "$f" model)
  tools=$(fm_get "$f" tools)
  [ -n "$name" ] || err "$f: frontmatter 'name' is required"
  [ -n "$desc" ] || err "$f: frontmatter 'description' is required"
  [ -n "$model" ] || err "$f: frontmatter 'model' is required"
  case "$model" in
    opus | sonnet | haiku | inherit | "") ;;
    *) err "$f: model '$model' must be opus, sonnet, haiku or inherit" ;;
  esac
  [ -n "$tools" ] || warn "$f: 'tools' is not set (inherits all tools); apply least privilege"
  [ "$name" = "$(basename "$f" .md)" ] || err "$f: name '$name' must match the file name"
  case "$name" in
    su3-*) ;;
    *) err "$f: agent name '$name' must start with 'su3-'" ;;
  esac
  case "$p" in
    *-with-guards) case "$name" in *-with-guards) ;; *) err "$f: agents of a -with-guards plugin must end with '-with-guards' (got '$name')" ;; esac ;;
    *) case "$name" in *-with-guards) err "$f: only agents of a -with-guards plugin may end with '-with-guards'" ;; esac ;;
  esac
  for h in "# Role" "# Responsibilities" "# Inputs / Outputs" "# Collaboration" "# Guardrails" "# Output Language"; do
    grep -q "^$h" "$f" || err "$f: missing section '$h'"
  done
  printf '%s\tagent\t%s\t%s\n' "$name" "$p" "$f" >>"$NAMES"
done

for f in plugins/*/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  p=$(echo "$f" | cut -d/ -f2)
  has_frontmatter "$f" || { err "$f: missing frontmatter"; continue; }
  name=$(fm_get "$f" name)
  desc=$(fm_get "$f" description)
  [ -n "$name" ] || err "$f: frontmatter 'name' is required"
  [ -n "$desc" ] || err "$f: frontmatter 'description' is required"
  [ "$name" = "$(basename "$(dirname "$f")")" ] || err "$f: name '$name' must match the directory name"
  printf '%s\tskill\t%s\t%s\n' "$name" "$p" "$f" >>"$NAMES"
done

# --- 5. name uniqueness -----------------------------------------------------

info "== Name uniqueness"
cut -f1 "$NAMES" | sort | uniq -d | while read -r dup; do
  [ -n "$dup" ] || continue
  case " $ALLOWED_DUPLICATES " in
    *" $dup "*) continue ;;
  esac
  # A skill may repeat only as a base / -with-guards pair of one plugin (plugin names differ, so they do not collide).
  pairs_ok=$(awk -F'\t' -v n="$dup" '
    $1 == n { if ($2 != "skill") bad = 1; p = $3; if (p ~ /-with-guards$/) gd[p]++; sub(/-with-guards$/, "", p); c[p]++ }
    END { for (k in c) if (c[k] != 2) bad = 1; for (k in gd) if (gd[k] != 1) bad = 1; print bad ? "no" : "yes" }
  ' "$NAMES")
  [ "$pairs_ok" = "yes" ] && continue
  echo "ERROR: name '$dup' is used more than once:" >&2
  awk -F'\t' -v n="$dup" '$1 == n { print "         " $4 }' "$NAMES" >&2
  echo x >>"$TMP/errs"
done
if [ -f "$TMP/errs" ]; then
  ERRORS=$((ERRORS + $(wc -l <"$TMP/errs")))
  rm -f "$TMP/errs"
fi

# su3-tech-writer-set agents and skills must carry the tech- prefix (after su3- for agents).
awk -F'\t' '$3 == "su3-tech-writer-set" { print $1 "\t" $4 }' "$NAMES" | while IFS="$(printf '\t')" read -r n f; do
  case "$n" in
    tech-* | su3-tech-* | set-language) ;;
    *) echo "ERROR: $f: su3-tech-writer-set names must start with 'tech-' or 'su3-tech-' (got '$n')" >&2; echo x >>"$TMP/errs" ;;
  esac
done
if [ -f "$TMP/errs" ]; then
  ERRORS=$((ERRORS + $(wc -l <"$TMP/errs")))
  rm -f "$TMP/errs"
fi

# --- 5b. -with-guards variants ---------------------------------------------------

info "== Guard variants"
# Normalized text of a file: variant suffix removed and lines about the guard hook dropped,
# so a plugin and its -with-guards variant must agree on everything else.
norm_variant() {
  sed 's/-with-guards//g' "$1" | grep -viE 'hook|Nothing blocks' || true
}
# Files whose text differs on purpose between su3-developer-set (no helper script, loop rules written as text)
# and su3-developer-set-with-guards (loop-state.sh helper). Their helper handling is checked in section 6c.
variant_diverges() {
  case "$1" in
    plugins/su3-developer-set/agents/su3-project-manager.md) return 0 ;;
    plugins/su3-developer-set/skills/code-implementation/SKILL.md) return 0 ;;
    plugins/su3-developer-set/skills/project-implementation/SKILL.md) return 0 ;;
    plugins/su3-developer-set/skills/task-management/SKILL.md) return 0 ;;
  esac
  return 1
}
for g in plugins/*-with-guards; do
  [ -d "$g" ] || continue
  gp=$(basename "$g")
  bp=${gp%-with-guards}
  b="plugins/$bp"
  [ -d "$b" ] || { err "$g: base plugin $b does not exist"; continue; }
  [ -f "$g/hooks/hooks.json" ] || err "$g: a -with-guards plugin must have hooks/hooks.json"
  [ -d "$b/hooks" ] && err "$b: the base plugin must have no hooks/ directory (the hook belongs in $gp)"
  [ -d "$b/scripts" ] && err "$b: the base plugin must have no scripts/ directory (guard scripts belong in $gp)"
  # Same agents and skills, same content apart from the variant suffix and guard-hook wording.
  for f in "$b"/agents/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md)
    gf="$g/agents/${base}-with-guards.md"
    [ -f "$gf" ] || { err "$gf is missing (the base plugin has $f)"; continue; }
    # Intentional divergence: the plain variant has no loop-state.sh helper and states the loop rules as text.
    if variant_diverges "$f"; then continue; fi
    [ "$(norm_variant "$f")" = "$(norm_variant "$gf")" ] || err "$gf differs from $f beyond the variant suffix and guard-hook wording"
  done
  for gf in "$g"/agents/*.md; do
    [ -f "$gf" ] || continue
    base=$(basename "$gf" -with-guards.md)
    [ -f "$b/agents/$base.md" ] || err "$gf has no counterpart $b/agents/$base.md"
  done
  for f in "$b"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    sk=$(basename "$(dirname "$f")")
    gf="$g/skills/$sk/SKILL.md"
    [ -f "$gf" ] || { err "$gf is missing (the base plugin has $f)"; continue; }
    if variant_diverges "$f"; then continue; fi
    [ "$(norm_variant "$f")" = "$(norm_variant "$gf")" ] || err "$gf differs from $f beyond the variant suffix and guard-hook wording"
  done
  for gf in "$g"/skills/*/SKILL.md; do
    [ -f "$gf" ] || continue
    sk=$(basename "$(dirname "$gf")")
    [ -f "$b/skills/$sk/SKILL.md" ] || err "$gf has no counterpart in $b"
  done
done
# Only -with-guards plugins may ship hooks.
for d in plugins/*/; do
  [ -d "$d" ] || continue
  case "$d" in
    *-with-guards/) ;;
    *) [ -d "${d}hooks" ] && err "${d}hooks exists; only -with-guards plugins may ship hooks (the directory refuses command hooks)" ;;
  esac
done

# --- 6. Output Language block consistency -----------------------------------

info "== Output Language block"
CANON="scripts/output-language-block.md"
[ -f "$CANON" ] || err "$CANON is missing"
REF=$(awk '{ lines[NR] = $0 } END { n = NR; while (n > 0 && lines[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }' "$CANON" 2>/dev/null)
REF_FILE="$CANON"
for f in plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  block=$(output_language_block "$f")
  if [ -z "$block" ]; then
    err "$f: no '# Output Language' section"
    continue
  fi
  case "$block" in
    *'${user_config.output_language}'*) ;;
    *) err "$f: Output Language block must reference \${user_config.output_language}" ;;
  esac
  [ "$block" = "$REF" ] || err "$f: Output Language block differs from $REF_FILE"
done

# --- 6b. Autonomy rules block consistency (3b.1) ----------------------------

info "== Autonomy rules block"
ACANON="scripts/autonomy-rules-block.md"
[ -f "$ACANON" ] || err "$ACANON is missing"
# The canonical text for one variant: @plain / @guards lines kept for their variant only (prefix removed)
autonomy_canon() {
  awk -v v="$1" '
    /^@plain / { if (v == "plain") print substr($0, 8); next }
    /^@guards / { if (v == "guards") print substr($0, 9); next }
    { print }
  ' "$ACANON" | awk '{ lines[NR] = $0 } END { n = NR; while (n > 0 && lines[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }'
}
# The "# Autonomy rules" section of an agent, up to the next top-level heading, trailing blanks removed
autonomy_block() {
  awk '
    $0 == "# Autonomy rules" { inb = 1 }
    inb && $0 != "# Autonomy rules" && /^# / { inb = 0 }
    inb { lines[++n] = $0 }
    END { while (n > 0 && lines[n] ~ /^[ \t]*$/) n--; for (i = 1; i <= n; i++) print lines[i] }
  ' "$1"
}
if [ -f "$ACANON" ]; then
  APLAIN=$(autonomy_canon plain)
  AGUARD=$(autonomy_canon guards)
  for f in plugins/su3-developer-set/agents/*.md plugins/su3-developer-set-with-guards/agents/*.md; do
    [ -f "$f" ] || continue
    case "$f" in plugins/su3-developer-set-with-guards/*) want=$AGUARD ;; *) want=$APLAIN ;; esac
    got=$(autonomy_block "$f")
    if [ -z "$got" ]; then err "$f: no '# Autonomy rules' section"; continue; fi
    [ "$got" = "$want" ] || err "$f: Autonomy rules block differs from $ACANON"
    # the old "ask first, then wait" wording must be gone
    if grep -qiE 'ask first|run the real command only after the Commander approves|report what you need and wait' "$f"; then
      err "$f: old ask-and-wait guardrail wording is still present"
    fi
    # the block comes right before the Output Language block
    order=$(grep -E '^(# Autonomy rules|# Output Language)$' "$f" | tr '\n' '|')
    [ "$order" = "# Autonomy rules|# Output Language|" ] || err "$f: '# Autonomy rules' must come directly before '# Output Language'"
  done
fi

# --- 6c. Phase skills (3b): flags per ADR 0003, helper path form, STATUS rule ----

info "== Phase skills"
for d in plugins/su3-developer-set plugins/su3-developer-set-with-guards; do
  [ -d "$d/skills" ] || continue
  # ADR 0003: manual-only entry points keep the flag; phase skills called through the Skill tool must not carry it
  for sk in project-implementation sprint-plan; do
    f="$d/skills/$sk/SKILL.md"
    [ -f "$f" ] || { err "$f: missing"; continue; }
    grep -q '^disable-model-invocation: true$' "$f" || err "$f: must keep disable-model-invocation: true (ADR 0003 entry point)"
  done
  for sk in task-management code-implementation design-review release-check; do
    f="$d/skills/$sk/SKILL.md"
    [ -f "$f" ] || { err "$f: missing"; continue; }
    grep -q '^disable-model-invocation' "$f" && err "$f: must not carry disable-model-invocation (ADR 0003 phase skill)"
  done
  # helper path form (20 section 9.4 path rule): one copy, named through the skill directory
  for f in "$d"/skills/*/SKILL.md; do
    sk=$(basename "$(dirname "$f")")
    case $sk in project-implementation) allowed='${CLAUDE_SKILL_DIR}/loop-state.sh' ;; *) allowed='${CLAUDE_SKILL_DIR}/../project-implementation/loop-state.sh' ;; esac
    forms=$(grep -o '[^ `]*/loop-state\.sh' "$f" | sort -u)
    [ -n "$forms" ] || continue
    for form in $forms; do
      [ "$form" = "$allowed" ] || err "$f: helper path '$form' is not the path-rule form '$allowed'"
    done
    grep -qF "$allowed" "$f" || err "$f: names the helper but not in the path-rule form $allowed"
  done
  for sk in design-review release-check; do
    f="$d/skills/$sk/SKILL.md"
    [ -f "$f" ] && { grep -q 'STATUS: ' "$f" || err "$f: must end its reply with a STATUS line (3b.6)"; }
  done
  # the helper and the formats file live in project-implementation only
  # the helper ships only with -with-guards (the directory scan refuses shell scripts from non-Verified orgs)
  case "$d" in
    *-with-guards) [ -f "$d/skills/project-implementation/loop-state.sh" ] || err "$d: skills/project-implementation/loop-state.sh is missing" ;;
    *) [ -e "$d/skills/project-implementation/loop-state.sh" ] && err "$d: must not contain loop-state.sh (helper is -with-guards only)" ;;
  esac
  [ -f "$d/skills/project-implementation/formats.md" ] || err "$d: skills/project-implementation/formats.md is missing"
done

# --- 7b. hook scripts ---------------------------------------------------------

info "== Hook scripts"
if [ -f scripts/test-hooks.sh ]; then
  sh scripts/test-hooks.sh || err "hook tests failed"
fi
for f in plugins/*/scripts/*.sh scripts/*.sh; do
  [ -f "$f" ] || continue
  sh -n "$f" 2>/dev/null || err "$f: shell syntax error"
done

# --- 7c. autonomy (Phase 3a) ------------------------------------------------------
# Human-on-the-loop pieces of the developer-set plugins: the autonomy_mode option, files shared
# byte for byte by a plugin and its -with-guards variant (policy template), the loop-state helper
# (only in the -with-guards variant: the directory scan refuses shebang scripts in a plain plugin,
# LOCAL_CODE_FILE_TYPE, so the plain variant is text rules only), the loop-state helper rules (20_formats_spec.md 9.4) and the hook registration (21_guard_spec.md 1.3).
# Content checks of skills and agents (STATUS rule, autonomy block, phase-skill flags) belong to
# Phase 3b and are added there.

info "== Autonomy (developer-set)"
for p in su3-developer-set su3-developer-set-with-guards; do
  [ -d "plugins/$p" ] || continue
  m="plugins/$p/.claude-plugin/plugin.json"
  jq -e '.userConfig.autonomy_mode.type == "string" and (.userConfig.autonomy_mode.default == "interactive") and ((.userConfig.autonomy_mode | has("options")) | not)' "$m" >/dev/null 2>&1 \
    || err "$m: userConfig.autonomy_mode must be a string option with default \"interactive\" and no options key"
done
for g in plugins/su3-developer-set-with-guards; do
  [ -d "$g" ] || continue
  b=plugins/su3-developer-set
  [ -d "$b" ] || continue
  # Every non-SKILL.md file under skills/ exists in both variants and is byte-identical,
  # except the loop-state helper, which only the -with-guards variant ships.
  for f in $(cd "$b" && find skills -type f ! -name SKILL.md | sort); do
    [ -f "$g/$f" ] || { err "$g/$f is missing (the base plugin has $b/$f)"; continue; }
    cmp -s "$b/$f" "$g/$f" || err "$g/$f differs from $b/$f (shared files must be byte-identical)"
  done
  for f in $(cd "$g" && find skills -type f ! -name SKILL.md | sort); do
    [ "$f" = skills/project-implementation/loop-state.sh ] && continue
    [ -f "$b/$f" ] || err "$b/$f is missing (the guarded plugin has $g/$f)"
  done
  # Guard scripts and hook registration.
  for s in guard-bash.sh guard-edit.sh guard-common.sh; do
    [ -f "$g/scripts/$s" ] || err "$g/scripts/$s is missing"
  done
  h="$g/hooks/hooks.json"
  jq -e '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.onFailure == "block" and (.timeout | type == "number"))] | length == 1' "$h" >/dev/null 2>&1 \
    || err "$h: the Bash matcher needs one hook with onFailure \"block\" and a numeric timeout"
  jq -e '[.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit|NotebookEdit|Read") | .hooks[] | select(.onFailure == "block" and (.timeout | type == "number"))] | length == 1' "$h" >/dev/null 2>&1 \
    || err "$h: the file-tool matcher (Edit|Write|MultiEdit|NotebookEdit|Read) needs one hook with onFailure \"block\" and a numeric timeout"
  grep -q 'guard-edit.sh' "$h" || err "$h: guard-edit.sh is not registered"
done
# Plain plugins (no -with-guards suffix) ship only file types the directory scan accepts for
# non-Verified organizations: md, txt, json, yml/yaml, png, jpg/jpeg, gif, webp, ico. No shebang
# files, no shell scripts.
for d in plugins/*/; do
  p=$(basename "$d")
  case "$p" in *-with-guards) continue ;; esac
  for f in $(find "$d" -type f | sort); do
    case "$f" in
      *.md|*.txt|*.json|*.yml|*.yaml|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico) ;;
      *) err "$f: file type not accepted by the directory scan in a plain plugin (LOCAL_CODE_FILE_TYPE)" ;;
    esac
    case "$f" in *.sh) continue ;; esac
    [ "$(head -c 2 "$f" 2>/dev/null)" = '#!' ] && err "$f: starts with a shebang (LOCAL_CODE_FILE_TYPE)"
  done
done
# The loop-state helper: syntax, and no code from data (no eval, no sourcing; comment lines excluded).
for f in plugins/*/skills/project-implementation/loop-state.sh; do
  [ -f "$f" ] || continue
  sh -n "$f" 2>/dev/null || err "$f: shell syntax error"
  bad=$(grep -nE '(^|[^a-z_])(eval|source)([^a-z_]|$)|^[[:space:]]*\.[[:space:]]' "$f" | grep -vE '^[0-9]+:[[:space:]]*#' || true)
  [ -z "$bad" ] || err "$f: the helper must not use eval or source (no code from data): $bad"
done
if [ -f scripts/test-loop-state.sh ]; then
  sh scripts/test-loop-state.sh || err "loop-state helper tests failed"
fi

# --- 8. official validator --------------------------------------------------

info "== claude plugin validate"
if command -v claude >/dev/null 2>&1; then
  claude plugin validate . || err "claude plugin validate failed for the marketplace"
  for d in plugins/*/; do
    [ -d "$d" ] || continue
    claude plugin validate "$d" || err "claude plugin validate failed for $d"
  done
else
  warn "claude CLI not found; skipping official validation"
fi

echo
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS error(s)" >&2
  exit 1
fi
echo "OK"
