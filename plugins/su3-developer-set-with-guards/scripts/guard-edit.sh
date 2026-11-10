#!/bin/sh
# PreToolUse hook for Edit, Write, MultiEdit, NotebookEdit and Read
# (su3-developer-set-with-guards only).
#
# Denies (never asks, in both modes) a su3-developer-set-with-guards subagent:
#   - reading or writing secret files (.env, key files, credentials, tfstate)
#   - writing guard-defining files: docs/policy/, .claude/settings*, .claude/hooks/, the
#     plugin hooks/, scripts/ and skills/ paths, loop-state.sh, .git/, and project
#     "protect" prefixes from the autonomy policy
#   - writing a run-directory file (docs/<date>_<NNN>_<slug>/) that the agent role does not own
# Read is only checked against the secret-file rule.
#
# Acts only inside su3-developer-set-with-guards subagents, so the Commander (main
# session) is never blocked. Text-pattern net, not a security boundary.
# Spec: 21_guard_spec.md section 4. POSIX sh; no -e and no -u; every path ends in exit 0.

INPUT=$(cat)

printf '%s' "$INPUT" | grep -Eq '"agent_type"[[:space:]]*:[[:space:]]*"su3-developer-set-with-guards:' || exit 0

GC_DIR=$(dirname "$0")
LIB=$GC_DIR/guard-common.sh
if [ ! -r "$LIB" ]; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"developer-set guard: DENIED [T3-PROTECT] the guard library is missing. This is a policy decision, not an error. Tell the Commander that the plugin installation is damaged."}}'
  exit 0
fi
. "$LIB"

TOOL=$(json_field tool_name)
P=$(json_field file_path)
[ -n "$P" ] || P=$(json_field notebook_path)
CWD=$(json_field cwd)
AT=$(json_field agent_type)
load_mode
ENVLBL=na

T3_HINT='This is never run by an agent and never approved inside the loop.'
PROT_WHAT='changing a guard-defining or protected file (policy, hooks, settings, .git/, plugin helper scripts and skills such as loop-state.sh, protected path), or writing a run-directory file that your role does not own (an unknown role owns none)'
PROT_ALT='Do not edit it. Describe the change you need under Open questions, or put the text in your report for the owner of the file; only the Commander edits the guard-defining files.'
SECRET_WHAT='reading or writing a secret (env file, key file, credentials, environment dump)'
SECRET_ALT='Refer to the value by its variable name, read .env.example for the list of variables, and report that the Commander must put the value in the environment.'
SECRET_HINT="$T3_HINT Do not read, print or copy secret values: refer to them by variable name. $ESC_HINT"

protect_deny() { deny T3-PROTECT T3 "$PROT_WHAT" "$PROT_ALT" "$T3_HINT $ESC_HINT"; }

# 4.1: no path, or a path with a backslash, is denied
if [ -z "$P" ]; then protect_deny; fi
case $P in *'\'*) protect_deny ;; esac

# 4.2: normalize
ROOT=${CLAUDE_PROJECT_DIR-}
[ -n "$ROOT" ] || ROOT=$CWD
case $P in
  /*) ;;
  *) if [ -n "$CWD" ]; then P=$CWD/$P; elif [ -n "$ROOT" ]; then P=$ROOT/$P; fi ;;
esac
P=$(printf '%s' "$P" | sed -E 's|/+|/|g')
GE_I=0
while printf '%s' "$P" | grep -Eq '/\./' && [ "$GE_I" -lt 40 ]; do
  P=$(printf '%s' "$P" | sed -E 's|/\./|/|')
  GE_I=$((GE_I + 1))
done
GE_I=0
while printf '%s' "$P" | grep -Eq '/[^/.][^/]*/\.\./' && [ "$GE_I" -lt 40 ]; do
  P=$(printf '%s' "$P" | sed -E 's|/[^/.][^/]*/\.\./|/|')
  GE_I=$((GE_I + 1))
done
if printf '%s' "$P" | grep -Eq '(^|/)\.\.(/|$)'; then protect_deny; fi
# resolve symlinks (macOS /var -> /private/var) on the deepest ancestor that exists, so a
# new file in a new directory still compares against the real project root
GE_HEAD=$P; GE_TAIL=
GE_I=0
while [ ! -d "$GE_HEAD" ] && [ "$GE_HEAD" != / ] && [ "$GE_HEAD" != . ] && [ "$GE_I" -lt 60 ]; do
  GE_TAIL=/$(basename "$GE_HEAD")$GE_TAIL
  GE_HEAD=$(dirname "$GE_HEAD")
  GE_I=$((GE_I + 1))
done
GE_D=$(cd "$GE_HEAD" 2>/dev/null && pwd -P)
if [ -n "$GE_D" ]; then
  [ "$GE_D" = / ] && GE_D=
  P=$GE_D$GE_TAIL
fi
RR=
if [ -n "$ROOT" ]; then RR=$(cd "$ROOT" 2>/dev/null && pwd -P); fi
REL=$P
if [ -n "$RR" ]; then
  case $P in "$RR"/*) REL=${P#"$RR"/} ;; esac
fi
RELL=$(printf '%s' "$REL" | tr 'A-Z' 'a-z')
PL=$(printf '%s' "$P" | tr 'A-Z' 'a-z')
BASE=$(basename "$PL")

# secret files (read and write)
SECRET_TOK='(^|[[:space:]/"'"'"'=<>:~])(\.env(\.[a-z0-9_-]+)?|id_(rsa|dsa|ecdsa|ed25519)(\.pub)?|[a-z0-9_.-]+\.(pem|key|p12|pfx|jks|keystore)|[a-z0-9_.-]*\.tfstate(\.backup)?|\.netrc|\.pgpass|\.git-credentials|master\.key|\.ssh/[^[:space:]"]*|\.aws/(credentials|config)|\.gnupg/[^[:space:]"]*|\.kube/config|\.docker/config\.json)([[:space:]"'"'"']|$)'
PX=$(printf '%s' "$PL" | sed -E 's/\.env\.(example|sample|template|dist|defaults)//g; s/id_(rsa|dsa|ecdsa|ed25519)\.pub//g')
if printf '%s' "$PX" | grep -Eiq "$SECRET_TOK"; then
  deny T3-SECRET T3 "$SECRET_WHAT" "$SECRET_ALT" "$SECRET_HINT"
fi

# Read: only the secret rule applies
[ "$TOOL" = Read ] && exit 0

# 4.3 protected paths (write tools)
if [ -n "$RR" ]; then
  case $RELL in docs/policy/*) protect_deny ;; esac
else
  case $PL in */docs/policy/*) protect_deny ;; esac
fi
case $PL in
  */.claude/settings*|*/.claude/hooks/*) protect_deny ;;
esac
if printf '%s' "$PL" | grep -Eiq 'su3-developer-set(-with-guards)?/([^/]+/)?(hooks|scripts|skills)/'; then protect_deny; fi
[ "$BASE" = loop-state.sh ] && protect_deny
case $RELL in .git/*) protect_deny ;; esac
case $PL in */.git/*) protect_deny ;; esac

load_policy nogit
GE_PP=$(printf '%s\n' "$POLREC" | sed -n 's/^PROTECT \([^ ]*\) .*/\1/p')
if [ -n "$GE_PP" ]; then
  GE_R=$(printf '%s\n' "$GE_PP" | while IFS= read -r GE_X; do
    GE_XL=$(printf '%s' "$GE_X" | tr 'A-Z' 'a-z')
    if [ "${RELL#"$GE_XL"}" != "$RELL" ]; then echo y; break; fi
  done)
  [ -n "$GE_R" ] && protect_deny
fi

# 4.4 run-directory ownership
if printf '%s' "$RELL" | grep -Eq '^docs/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9][0-9]_[^/]+/'; then
  GE_ROLE=$(printf '%s' "$AT" | tr 'A-Z' 'a-z' | sed -E 's/^su3-developer-set-with-guards://; s/^su3-//; s/-with-guards$//')
  case $GE_ROLE in
    project-manager|system-architect|app-developer|sre|aire|qa|qc) ;;
    *) protect_deny ;;
  esac
  [ "$GE_ROLE" = qc ] && protect_deny
  GE_F=$(printf '%s' "$RELL" | sed -E 's|^docs/[^/]+/||')
  GE_OK=0
  case $GE_F in
    00_request.md) GE_OK=0 ;;
    01_project_plan.md) case $GE_ROLE in project-manager|system-architect|app-developer|sre|aire|qa) GE_OK=1 ;; esac ;;
    02_system_design.md) case $GE_ROLE in system-architect|aire|sre) GE_OK=1 ;; esac ;;
    03_development_output.md) case $GE_ROLE in app-developer|aire|sre) GE_OK=1 ;; esac ;;
    04_quality_report.md) case $GE_ROLE in project-manager|qa) GE_OK=1 ;; esac ;;
    05_completion_report.md|06_commander_actions.md) [ "$GE_ROLE" = project-manager ] && GE_OK=1 ;;
    *) GE_OK=1 ;;
  esac
  [ "$GE_OK" -eq 1 ] || protect_deny
fi

exit 0
