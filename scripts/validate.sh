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
  [ "$(jq -r '.name // empty' "$MP")" = "scrum-ai-ecosystem" ] || err "$MP: name must be scrum-ai-ecosystem"
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

for f in plugins/*/agents/*.md; do
  [ -f "$f" ] || continue
  p=$(echo "$f" | cut -d/ -f2)
  has_frontmatter "$f" || { err "$f: missing frontmatter"; continue; }
  name=$(fm_get "$f" name)
  desc=$(fm_get "$f" description)
  model=$(fm_get "$f" model)
  tools=$(fm_get "$f" tools)
  [ -n "$tools" ] || tools=$(fm_get "$f" disallowedTools)
  [ -n "$name" ] || err "$f: frontmatter 'name' is required"
  [ -n "$desc" ] || err "$f: frontmatter 'description' is required"
  [ -n "$model" ] || err "$f: frontmatter 'model' is required"
  case "$model" in
    opus | sonnet | haiku | inherit | "") ;;
    *) err "$f: model '$model' must be opus, sonnet, haiku or inherit" ;;
  esac
  [ -n "$tools" ] || warn "$f: 'tools' is not set (inherits all tools); apply least privilege"
  [ "$name" = "$(basename "$f" .md)" ] || err "$f: name '$name' must match the file name"
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
  echo "ERROR: name '$dup' is used more than once:" >&2
  awk -F'\t' -v n="$dup" '$1 == n { print "         " $4 }' "$NAMES" >&2
  echo x >>"$TMP/errs"
done
if [ -f "$TMP/errs" ]; then
  ERRORS=$((ERRORS + $(wc -l <"$TMP/errs")))
  rm -f "$TMP/errs"
fi

# tech-writer-set agents and skills must carry the tech- prefix.
awk -F'\t' '$3 == "tech-writer-set" { print $1 "\t" $4 }' "$NAMES" | while IFS="$(printf '\t')" read -r n f; do
  case "$n" in
    tech-* | set-language) ;;
    *) echo "ERROR: $f: tech-writer-set names must start with 'tech-' (got '$n')" >&2; echo x >>"$TMP/errs" ;;
  esac
done
if [ -f "$TMP/errs" ]; then
  ERRORS=$((ERRORS + $(wc -l <"$TMP/errs")))
  rm -f "$TMP/errs"
fi

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

# --- 7b. hook scripts ---------------------------------------------------------

info "== Hook scripts"
if [ -f scripts/test-hooks.sh ]; then
  sh scripts/test-hooks.sh || err "hook tests failed"
fi
for f in plugins/*/scripts/*.sh scripts/*.sh; do
  [ -f "$f" ] || continue
  sh -n "$f" 2>/dev/null || err "$f: shell syntax error"
done

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
