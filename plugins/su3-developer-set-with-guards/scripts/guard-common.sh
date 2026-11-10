# guard-common.sh - shared functions for guard-bash.sh and guard-edit.sh.
# Sourced by those two scripts, never run alone. POSIX sh, no -e and no -u.
#
# Provides: JSON field extraction, mode and policy loading (including the read-only
# commit-state check H9), environment classification, and deny / ask message building.
# Spec: docs/2026-11-09_01_human_on_loop_design_upgrade/21_guard_spec.md sections 5 and 6
#       and 22_policy_file_spec.md.
#
# This is a text-pattern safety net, not a security boundary.

# ---------------------------------------------------------------------------
# JSON helpers
# ---------------------------------------------------------------------------

# json_field <name>: first string value of "<name>" in $INPUT (still JSON-escaped).
json_field() {
  printf '%s' "$INPUT" | sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1
}

# json_out <decision> <reason>: print the hook decision. <reason> must hold no quote and no
# backslash except the two-character line break sequence.
json_out() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"'"$1"'","permissionDecisionReason":"'"$2"'"}}'
}

# ---------------------------------------------------------------------------
# Mode (spec 6.1, F5)
# ---------------------------------------------------------------------------
load_mode() {
  GC_M=$(printf '%s' "${CLAUDE_PLUGIN_OPTION_AUTONOMY_MODE-}" | tr -d '[:space:]')
  if [ "$GC_M" = "unattended" ]; then MODE=unattended; else MODE=interactive; fi
}

# ---------------------------------------------------------------------------
# Policy (spec 6.2, 6.3, 6.3.1; policy spec 22)
# ---------------------------------------------------------------------------

# One awk pass over the policy file (tabs already turned into spaces, CR removed).
# Prints one record per valid directive or problem; the last record is END <n>.
POLICY_AWK='
function bad(ln, why) { print "BAD " ln " " why; nbad++ }
function is_key(k) { return k ~ /^(data-write|data-delete|schema-migrate|schema-contract|infra-apply|infra-destroy|version-patch|version-minor|version-major|tracker-write|publish|spend|credential-new)$/ }
function env_scoped(k) { return k ~ /^(data-write|data-delete|schema-migrate|schema-contract|infra-apply|infra-destroy)$/ }
function loosenable(k) { return k !~ /^(publish|spend|credential-new)$/ }
function subset(s, allowed,    n, a, i) {
  n = split(s, a, ",")
  if (s == "") return 0
  for (i = 1; i <= n; i++) if (index("," allowed ",", "," a[i] ",") == 0) return 0
  return 1
}
BEGIN { inb = 0; blocks = 0; closed = 0; nbad = 0; ndir = 0; nver = 0; gitseen = 0; blines = 0 }
{
  line = $0
  if (!inb) {
    if (line == "```autonomy-policy") { blocks++; inb = 1; if (blocks > 1) bad(NR, "second policy block") }
    next
  }
  if (line == "```") { inb = 0; closed++; next }
  blines++
  if (blines == 201) bad(NR, "block longer than 200 lines")
  if (length(line) > 300) bad(NR, "line longer than 300 bytes")
  t = line; sub(/^ +/, "", t); sub(/ +$/, "", t)
  if (t == "" || substr(t, 1, 1) == "#") next
  if (line !~ /^(version|env|forbid|reserve|after-approval|without-approval|git|budget|protect): +[^ ]+( +[^ ]+)* *$/) { bad(NR, "malformed directive"); next }
  nf = split(t, f, / +/)
  kind = f[1]; sub(/:$/, "", kind)
  badf = 0
  for (i = 2; i <= nf; i++) if (f[i] !~ /^[A-Za-z0-9._\/:@=+,-]+$/) badf = 1
  if (badf) { bad(NR, "field has a character outside the allowed set"); next }
  ndir++
  if (ndir == 1 && kind != "version") bad(NR, "first directive must be version: 1")
  if (kind == "version") {
    nver++
    if (nver > 1) bad(NR, "version appears more than once")
    else if (nf != 2 || f[2] != "1") bad(NR, "version must be 1")
    else print "VERSION 1"
  } else if (kind == "env") {
    if (nf < 3 || f[2] !~ /^(dev|staging|production)$/) bad(NR, "env needs a class (dev, staging, production) and a pattern")
    else for (i = 3; i <= nf; i++) {
      if (length(f[i]) < 3 || length(f[i]) > 100 || index(f[i], ",") > 0) bad(NR, "env pattern must be 3 to 100 characters without a comma")
      else print "ENV " f[2] " " f[i]
    }
  } else if (kind == "forbid" || kind == "reserve") {
    act = f[2]; scope = (nf >= 3) ? f[3] : "any"
    if (nf > 3) bad(NR, kind ": too many fields")
    else if (act ~ /^cmd=/) {
      if (length(act) < 8) bad(NR, kind ": cmd= substring needs 4 or more characters")
      else if (scope != "any" && !subset(scope, "dev,staging,production")) bad(NR, kind ": scope")
      else print toupper(kind) " " act " " scope " " NR
    } else if (!is_key(act)) bad(NR, kind ": unknown action key")
    else if (scope != "any" && (!env_scoped(act) || !subset(scope, "dev,staging,production"))) bad(NR, kind ": scope")
    else print toupper(kind) " " act " " scope " " NR
  } else if (kind == "after-approval") {
    if (nf != 3) bad(NR, "after-approval needs an action key and a scope")
    else if (!is_key(f[2]) || !loosenable(f[2])) bad(NR, "after-approval: action key not allowed")
    else if (env_scoped(f[2]) && !subset(f[3], "dev,staging")) bad(NR, "after-approval: scope outside dev,staging")
    else if (!env_scoped(f[2]) && f[3] != "any") bad(NR, "after-approval: scope must be any for this key")
    else print "AA " f[2] " " f[3] " " NR
  } else if (kind == "without-approval") {
    if (nf == 3 && f[2] ~ /^(data-write|data-delete|schema-migrate)$/ && f[3] == "dev") print "WA " f[2] " " NR
    else bad(NR, "without-approval: key or scope not allowed")
  } else if (kind == "git") {
    gitseen++
    if (gitseen > 1) bad(NR, "git appears more than once")
    else if (nf != 2 || f[2] !~ /^(commander-only|commit-after-approval)$/) bad(NR, "git: value not allowed")
    else print "GIT " f[2]
  } else if (kind == "budget") {
    if (nf != 3 || f[3] !~ /^[0-9]+$/) bad(NR, "budget needs a key and an integer")
    else if (seenb[f[2]]) bad(NR, "budget key repeated")
    else if (f[2] == "retry-cap" && f[3] + 0 <= 2) { seenb[f[2]] = 1; print "BUDGET " f[2] " " f[3] + 0 }
    else if (f[2] == "overrun-percent" && f[3] + 0 >= 100 && f[3] + 0 <= 150) { seenb[f[2]] = 1; print "BUDGET " f[2] " " f[3] + 0 }
    else if (f[2] == "denial-cap" && f[3] + 0 >= 1 && f[3] + 0 <= 2) { seenb[f[2]] = 1; print "BUDGET " f[2] " " f[3] + 0 }
    else bad(NR, "budget: key or value out of range")
  } else if (kind == "protect") {
    if (nf != 2 || substr(f[2], 1, 1) == "/" || f[2] ~ /(^|\/)\.\.(\/|$)/ || length(f[2]) < 2) bad(NR, "protect: prefix must be repository-relative, at least 2 characters, no ..")
    else print "PROTECT " f[2] " " NR
  }
}
END {
  if (blocks == 0) bad(0, "no autonomy-policy block")
  else if (inb || closed < blocks) bad(0, "policy block is not closed")
  if (ndir == 0 && blocks > 0) bad(0, "policy block has no directive")
  print "END " nbad
}
'

# Built-in default records used when the policy file is missing (policy spec 2.5).
POLICY_DEFAULTS='AA data-write dev,staging 0
AA data-delete dev,staging 0
AA schema-migrate dev,staging 0
AA infra-apply dev,staging 0
AA version-patch any 0
AA version-minor any 0
AA tracker-write any 0
WA data-write 0
WA data-delete 0
WA schema-migrate 0'

# set_degraded <reason>
set_degraded() { POLICY_STATE=degraded; POLICY_REASON=$1; }

# h9_check: read-only commit-state check (spec 6.3.1). Called only for a valid policy.
h9_check() {
  GC_REL=docs/policy/autonomy-policy.md
  GC_PROBE=$( { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git config --global --list 2>/dev/null
                GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git config --system --list 2>/dev/null; } )
  if [ -n "$GC_PROBE" ]; then set_degraded 'policy commit state unknown'; return; fi
  GC_OUT=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -c core.fsmonitor=false -c core.attributesFile=/dev/null --no-optional-locks -C "$ROOT" status --porcelain --ignored -- "$GC_REL" 2>/dev/null)
  GC_RC=$?
  if [ "$GC_RC" -ne 0 ]; then set_degraded 'policy commit state unknown'; return; fi
  if [ -n "$GC_OUT" ]; then set_degraded 'uncommitted policy change'; return; fi
}

# load_policy [no-git]: sets POLICY_STATE (valid|missing|degraded), POLICY_REASON, POLREC
# (records usable by the hook: strict mode keeps only FORBID, RESERVE, PROTECT).
load_policy() {
  POLICY_STATE=missing; POLICY_REASON=; POLREC=
  GC_NOGIT=${1-}
  ROOT=${CLAUDE_PROJECT_DIR-}
  GC_FROMENV=1
  if [ -z "$ROOT" ]; then ROOT=${CWD-}; GC_FROMENV=0; fi
  if [ -z "$ROOT" ]; then set_degraded 'no project root'; return; fi
  GC_PF=$ROOT/docs/policy/autonomy-policy.md
  if [ -L "$ROOT/docs" ] || [ -L "$ROOT/docs/policy" ]; then set_degraded 'policy directory is a symlink'; return; fi
  if [ ! -e "$GC_PF" ] && [ ! -L "$GC_PF" ]; then
    if [ "$GC_FROMENV" -eq 1 ]; then POLICY_STATE=missing; POLREC=$POLICY_DEFAULTS
    else set_degraded 'policy file not found from cwd'; fi
    return
  fi
  if [ -L "$GC_PF" ] || [ ! -f "$GC_PF" ] || [ ! -r "$GC_PF" ]; then set_degraded 'policy file is a symlink or not readable'; return; fi
  GC_ALL=$(tr -d '\r' < "$GC_PF" | tr '\t' ' ' | awk "$POLICY_AWK" 2>/dev/null)
  GC_LAST=$(printf '%s\n' "$GC_ALL" | tail -n 1)
  if [ "$GC_LAST" = "END 0" ]; then
    POLICY_STATE=valid; POLREC=$GC_ALL
    if [ -z "$GC_NOGIT" ]; then h9_check; fi
  else
    case $GC_LAST in
      "END "*)
        GC_FIRSTBAD=$(printf '%s\n' "$GC_ALL" | sed -n 's/^BAD //p' | head -n 1)
        GC_LN=${GC_FIRSTBAD%% *}; GC_WHY=${GC_FIRSTBAD#* }
        set_degraded "line $GC_LN: $GC_WHY" ;;
      *) set_degraded 'parser failed' ;;
    esac
  fi
  if [ "$POLICY_STATE" = degraded ]; then
    POLREC=$(printf '%s\n' "$GC_ALL" | grep -E '^(FORBID|RESERVE|PROTECT) ')
  fi
}

# policy_h9: run the commit-state check once, after the policy was loaded without it.
policy_h9() {
  if [ "$POLICY_STATE" = valid ] && [ "${POL_H9-}" != done ]; then
    POL_H9=done
    h9_check
    if [ "$POLICY_STATE" = degraded ]; then POLREC=$(printf '%s\n' "$POLREC" | grep -E '^(FORBID|RESERVE|PROTECT) '); fi
  fi
}

# Lookups on POLREC (strict mode already removed the loosening records).
# aa_ok <key> <class>: an AA record lists the key for the class (scope any or a list).
aa_ok() {
  printf '%s\n' "$POLREC" | awk -v k="$1" -v c="$2" '$1 == "AA" && $2 == k { if ($3 == "any") { f = 1 } else { n = split($3, a, ","); for (i = 1; i <= n; i++) if (a[i] == c) f = 1 } } END { exit f ? 0 : 1 }'
}
# aa_any_version: any version-* key is on the allow-list.
aa_any_version() { printf '%s\n' "$POLREC" | grep -Eq '^AA version-(patch|minor|major) '; }
# wa_ok <key>: valid without-approval record (the caller checks class dev).
wa_ok() { printf '%s\n' "$POLREC" | grep -Eq "^WA $1 "; }
# policy_line <record-prefix> : line number text for messages
aa_line() { printf '%s\n' "$POLREC" | awk -v k="$1" '$1 == "AA" && $2 == k { print $4; exit }'; }

# match_any <text> <newline-separated fixed patterns>: succeeds when one pattern occurs in the text.
match_any() {
  GC_R=$(printf '%s\n' "$2" | while IFS= read -r GC_P; do
    if [ -n "$GC_P" ] && printf '%s' "$1" | grep -Fiq -e "$GC_P"; then echo y; break; fi
  done)
  [ -n "$GC_R" ]
}

# env_patterns <class>: the patterns of the ENV records of that class (valid state only).
env_patterns() { printf '%s\n' "$POLREC" | sed -n "s/^ENV $1 //p"; }

# ---------------------------------------------------------------------------
# Shape test and environment evidence (spec 2.3.1, 3.1, 3.1.1)
# ---------------------------------------------------------------------------

# is_simple <text>: succeeds only when the (normalized) text is ONE simple command.
is_simple() {
  printf '%s' "$1" | grep -Eq '\$\(|`' && return 1
  GC_S=$(printf '%s' "$1" | sed -E "s/2>&1//g; s/\"[^\"]*\"/ /g; s/'[^']*'/ /g")
  printf '%s' "$GC_S" | grep -Eq "[;&|<>\"']" && return 1
  return 0
}

HEAD_RE='^[ ]*((npx|bunx|pnpm|yarn|npm|bundle exec|poetry run|uv run|python3?( -m)?) +)?([^ ]*/)?(psql|mysql|mariadb|sqlite3|mongosh|mongo|redis-cli|cqlsh|clickhouse-client|sqlcmd|pg_restore|pg_dump|pg_dumpall|mysqldump|mongodump|mongoexport|terraform|tofu|terragrunt|kubectl|helm|pulumi|ansible-playbook|aws|gcloud|az|gsutil|bq|rails|rake|prisma|alembic|flyway|liquibase|knex|sequelize|sequelize-cli|typeorm|dbmate|goose|atlas|sqitch|diesel|sqlx|cdk|sam|serverless|sls|firebase|flyctl|fly|heroku|wrangler|netlify|vercel|manage\.py|django-admin|backfill[^ ]*|data[-_]?patch[^ ]*|fix[-_]?data[^ ]*)( |$)'

# Tokenizer and evidence selector. Prints the environment evidence, one token per line, or nothing.
EVID_AWK='
function push(t) { nt++; T[nt] = t }
BEGIN { re = ENVIRON["GC_HEAD_RE"] }
{
  s = $0; n = length(s); tok = ""; has = 0; inq = ""; nt = 0; stop = 0
  for (i = 1; i <= n && !stop; i++) {
    c = substr(s, i, 1)
    if (inq != "") { if (c == inq) inq = ""; else tok = tok c; continue }
    if (c == "\"" || c == "\047") { inq = c; has = 1; continue }
    if (c == " " || c == "\t") { if (has || tok != "") { push(tok); tok = ""; has = 0 } continue }
    if (c == "#" && tok == "" && !has) { stop = 1; continue }
    tok = tok c; has = 1
  }
  if (has || tok != "") push(tok)
  i = 1; ne = 0
  while (i <= nt && T[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { v = T[i]; sub(/^[^=]*=/, "", v); ev[++ne] = v; i++ }
  if (i > nt) exit
  body = ""
  for (j = i; j <= nt; j++) body = body (j > i ? " " : "") T[j]
  if (body !~ re) exit
  skip = 0; posdone = 0
  for (j = i + 1; j <= nt; j++) {
    t = T[j]
    if (skip) { skip = 0; continue }
    if (t ~ /^(-c|--command|-e|--eval|-f|--file)$/) { skip = 1; continue }
    if (t ~ /^(--command|--eval|--file)=/) continue
    if (t ~ /^(-h|--host|--url|--uri|--dbname|--context|--kube-context|--profile|--project|-var-file|--var-file|-w|--workspace)=/) { v = t; sub(/^[^=]*=/, "", v); ev[++ne] = v; continue }
    if (t ~ /^(-h|--host|--url|--uri|--dbname|--context|--kube-context|--profile|--project|-var-file|--var-file|-w|--workspace)$/) { if (j < nt) { ev[++ne] = T[j + 1]; j++ } continue }
    if (!posdone && t !~ /^-/ && (t ~ /^[$]/ || t ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\//)) { ev[++ne] = t; posdone = 1 }
  }
  for (k = 1; k <= ne; k++) print ev[k]
}
'

# env_evidence <text>: print the evidence tokens (empty unless the text is one simple command).
env_evidence() {
  is_simple "$1" || return 0
  printf '%s\n' "$1" | GC_HEAD_RE="$HEAD_RE" awk "$EVID_AWK" 2>/dev/null
}

# classify_env: sets CLASS (production|staging|dev|unknown). Production is full-text; dev and staging
# only from the evidence. In missing and degraded state no ENV record is used.
classify_env() {
  CLASS=unknown
  PRODMARK=0
  if printf '%s' "$CMD" | grep -Eiq '(^|[^a-z])prod(uction)?([^a-z]|$)'; then PRODMARK=1; fi
  if [ "$PRODMARK" -eq 0 ] && [ "$POLICY_STATE" = valid ]; then
    GC_PP=$(env_patterns production)
    if [ -n "$GC_PP" ] && match_any "$CMD" "$GC_PP"; then PRODMARK=1; fi
  fi
  if [ "$PRODMARK" -eq 1 ]; then CLASS=production; return; fi
  if [ "$POLICY_STATE" != valid ]; then return; fi
  GC_EV=$(env_evidence "$CMD")
  [ -n "$GC_EV" ] || return 0
  GC_SP=$(env_patterns staging)
  if [ -n "$GC_SP" ] && match_any "$GC_EV" "$GC_SP"; then CLASS=staging; return; fi
  GC_DP=$(env_patterns dev)
  if [ -n "$GC_DP" ] && match_any "$GC_EV" "$GC_DP"; then CLASS=dev; return; fi
}

# ---------------------------------------------------------------------------
# Messages (spec section 5)
# ---------------------------------------------------------------------------
ESC_HINT='Next: do not run this action again or reach the same effect another way (no rewording, variable, script, interpreter or other tool). Finish the parts of your step that do not need it and continue with other work. In your report add one Parked action block with the exact command, dry-run result and rollback, and quote this message under Denied by guard. End with STATUS: BLOCKED if your step needs the action, or STATUS: DONE if it is only a follow-up. Do not write 06_commander_actions.md; the loop records it.'

# policy_text: the Policy field text
policy_text() {
  case $POLICY_STATE in
    valid) POLTXT= ;;
    missing) POLTXT=' Policy: missing (plugin defaults).' ;;
    *) POLTXT=" Policy: degraded ($(printf '%s' "$POLICY_REASON" | tr -cd 'A-Za-z0-9._ :,/=+-' | cut -c 1-80); strict mode)." ;;
  esac
}

# env_text: the Environment field text
env_text() {
  case ${ENVLBL:-$CLASS} in
    production) ENVTXT=production ;;
    staging) ENVTXT=staging ;;
    dev) ENVTXT=dev ;;
    na) ENVTXT='not applicable' ;;
    *) ENVTXT='unknown (treated as production)' ;;
  esac
}

# deny <code> <tier> <what> <alt> <hint>
deny() {
  policy_text; env_text
  GC_MSG="developer-set guard: DENIED [$1] $3. This is a policy decision, not an error; the same action will be denied again.\\nTier: $2. Rule: ${RULE:-plugin default}. Environment: $ENVTXT (read from the command text). Mode: ${MODE:-interactive}.$POLTXT\\nSafe alternative: $4\\n$5"
  json_out deny "$GC_MSG"
  exit 0
}

# ask <what> : after-approval prompt (interactive only)
ask() {
  policy_text; env_text
  GC_MSG="developer-set guard: APPROVAL NEEDED [ASK-AA] $1.\\nTier: T2, allowed after approval by ${RULE:-plugin default}. Environment: $ENVTXT. Mode: interactive.$POLTXT\\nEnvironment was read from the command text only; check the target before approving. Approve only after you have seen the dry-run or plan output."
  json_out ask "$GC_MSG"
  exit 0
}
