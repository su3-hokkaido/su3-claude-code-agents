#!/bin/sh
# PreToolUse hook for product-owner-set subagents (Bash, Write, Edit and MCP tools).
#
# Policy: these agents analyze and propose. They never change tickets or
# sprints in an external tracker on their own, and decisions leave a record.
#
#   1. Connector (MCP) tools, judged by the verb in the tool name:
#        delete / remove / archive ...           -> DENIED
#        any write on a sprint (name or input)   -> DENIED (an active or past
#                                                   sprint cannot be restored,
#                                                   and the state is not
#                                                   visible to this hook)
#        other writes (create, update, edit,
#        transition, assign, comment, send ...)  -> ASK the human
#        reads (get, list, search, ...)          -> allowed
#   2. Bash: tracker commands (gh issue/project, jira, acli, curl -X ...) follow
#      the same rules. Version changes (npm update, --fix, pip install -U ...)
#      are DENIED: these agents only propose them. Installing packages asks.
#   3. Decision records: a write to docs/product/ or docs/backlog/ is DENIED
#      until an ADR under docs/adr/ was written in the last 120 minutes (the
#      hook keeps no state; it judges by the file's modification time). An older ADR
#      is history: overwriting or editing it, and removing ADR files, are
#      DENIED. Record a change as a new ADR that supersedes the old one.
#
# "ASK" shows a permission prompt; in non-interactive runs it counts as a
# denial. Acts only inside product-owner-set subagents (agent_type
# "su3-product-owner-set-with-guards:..."). This is a text-pattern safety net, not a security
# boundary. Needs no jq. POSIX sh; macOS and Linux.

INPUT=$(cat)

printf '%s' "$INPUT" | grep -Eq '"agent_type"[[:space:]]*:[[:space:]]*"su3-product-owner-set-with-guards:' || exit 0

json_field() {
  printf '%s' "$INPUT" | sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1
}

TOOL=$(json_field tool_name)
CWD=$(json_field cwd)

reply() {
  # $1 decision, $2 reason
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"'"$1"'","permissionDecisionReason":"product-owner-set guard: '"$2"'"}}'
  exit 0
}

deny() { reply deny "$1"; }
ask() { reply ask "$1"; }

# --- verb classification ------------------------------------------------------
# Splits camelCase and separators into _-joined lowercase tokens.
tokens() {
  printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9]+/_/g'
}

DELETE_VERBS='(delete|remove|archive|purge|destroy|trash|drop|discard|erase|wipe)'
WRITE_VERBS='(create|update|edit|modify|patch|put|transition|assign|comment|add|move|rank|reorder|send|post|reply|write|link|unlink|merge|close|reopen|resolve|upload|publish|schedule|react|invite|start|complete|cancel|estimate|label|tag|set|clone|import)'

# classify <name-tokens> -> prints delete|write|read
classify() {
  if printf '%s' "$1" | grep -Eq "(^|_)${DELETE_VERBS}(_|\$)"; then
    echo delete
  elif printf '%s' "$1" | grep -Eq "(^|_)${WRITE_VERBS}(_|\$)"; then
    echo write
  else
    echo read
  fi
}

mentions_sprint() {
  printf '%s' "$1" | grep -Eiq 'sprint'
}

# --- 1. connector (MCP) tools ----------------------------------------------------
case "$TOOL" in
  mcp__*)
    NAME=${TOOL##*__}
    KIND=$(classify "$(tokens "$NAME")")
    case "$KIND" in
      delete) deny "the tool $NAME deletes data in an external service. Draft the deletion as a proposal and let the Commander do it." ;;
      write)
        if mentions_sprint "$TOOL $INPUT"; then
          deny "the tool $NAME changes a sprint or its backlog. An active or past sprint cannot be restored. Draft the change as a proposal and let the Commander apply it."
        fi
        ask "the tool $NAME changes data in an external service. Approve only if you want this exact change."
        ;;
    esac
    exit 0
    ;;
esac

# --- 2. Bash ---------------------------------------------------------------------
if [ "$TOOL" = "Bash" ]; then
  CMD=$(json_field command)
  [ -n "$CMD" ] || CMD="$INPUT"
  has() { printf '%s' "$CMD" | grep -Eiq -- "$1"; }

  # Removing or moving ADR files.
  if has '(^|[^a-z])(rm|mv|unlink|git[[:space:]]+rm)[[:space:]][^"|;&]*docs/adr'; then
    deny "ADR files are history. Do not remove or move them; add a new ADR that supersedes the old one."
  fi

  TRACKER='(gh[[:space:]]+(issue|project|pr)[[:space:]]+(delete|close|reopen|edit|create|transfer|comment|lock|unlock|pin|unpin|move|item-[a-z]+)|gh[[:space:]]+api[^"|;&]*(-X|--method)[[:space:]]*(DELETE|PUT|PATCH|POST)|(jira|acli|backlog|linear|clickup)[[:space:]][^"|;&]*(delete|remove|edit|update|move|transition|assign|create|close|comment)|(curl|wg[e]t|http|https|xh)[[:space:]][^"|;&]*(-X|--request|--method)[[:space:]]*=?[[:space:]]*(DELETE|PUT|PATCH|POST))'
  if has "$TRACKER"; then
    if has '(delete|remove)'; then
      deny "this command deletes data in an external service. Draft the deletion as a proposal and let the Commander do it."
    fi
    if has 'sprint'; then
      deny "this command changes a sprint or its backlog. An active or past sprint cannot be restored. Draft the change as a proposal and let the Commander apply it."
    fi
    ask "this command changes data in an external service. Approve only if you want this exact change."
  fi

  UPGRADE='((npm|pnpm)[[:space:]]+(update|upgrade|up|audit[[:space:]]+fix)|yarn[[:space:]]+(upgrade|up)|pip3?[[:space:]]+install[^"|;&]*([[:space:]]-U|--upgrade)|poetry[[:space:]]+update|uv[[:space:]]+(lock|sync|pip[[:space:]]+install)[^"|;&]*(--upgrade|-U)|cargo[[:space:]]+update|go[[:space:]]+get[^"|;&]*[[:space:]]-u|bundle[[:space:]]+update|composer[[:space:]]+update|(flutter|dart)[[:space:]]+pub[[:space:]]+(upgrade|downgrade)|gem[[:space:]]+update|brew[[:space:]]+(upgrade|update)|(apt|apt-get)[[:space:]]+(upgrade|dist-upgrade|full-upgrade)|(yum|dnf)[[:space:]]+(update|upgrade)|softwareupdate|[[:space:]]--fix([[:space:]]|"|$)|[[:space:]]--force([[:space:]]|"|$))'
  if has "$UPGRADE"; then
    deny "this agent proposes version changes and never applies them. List what would change (npm outdated, npm audit, pip list --outdated) and put the proposal in your report."
  fi

  INSTALL='((npm|pnpm|yarn)[[:space:]]+(install|i|add)|pip3?[[:space:]]+install|poetry[[:space:]]+add|uv[[:space:]]+(add|pip)|cargo[[:space:]]+add|go[[:space:]]+get|bundle[[:space:]]+install|composer[[:space:]]+(require|install)|(flutter|dart)[[:space:]]+pub[[:space:]]+(add|get)|gem[[:space:]]+install|brew[[:space:]]+install|(apt|apt-get)[[:space:]]+install|(yum|dnf)[[:space:]]+install)'
  if has "$INSTALL"; then
    ask "this installs packages. Approve only for the dependencies the task needs, and only if the list is what you expect."
  fi
  exit 0
fi

# --- 3. decision records (Write / Edit) ----------------------------------------------
case "$TOOL" in
  Write | Edit | MultiEdit)
    FILE=$(json_field file_path)
    [ -n "$FILE" ] || exit 0
    case "$FILE" in
      /*) ABS="$FILE" ;;
      *) ABS="${CWD:-.}/$FILE" ;;
    esac

    if printf '%s' "$ABS" | grep -Eq '(^|/)docs/adr/[^/]+\.md$'; then
      if [ "$TOOL" = "Write" ] && [ -e "$ABS" ]; then
        deny "$FILE already exists. An ADR is history and is never overwritten. Add a new ADR that supersedes it."
      fi
      if [ "$TOOL" != "Write" ] && [ -z "$(find "$ABS" -mmin -120)" ]; then
        deny "$FILE is an older ADR. An ADR is history and is never edited. Add a new ADR that supersedes it."
      fi
      exit 0
    fi

    if printf '%s' "$ABS" | grep -Eq '(^|/)docs/(product|backlog)/'; then
      if [ ! -d "${CWD:-.}/docs/adr" ] || [ -z "$(find "${CWD:-.}/docs/adr" -name '*.md' -mmin -120)" ]; then
        deny "write the ADR first. Record this decision and its history as docs/adr/NNNN-title.md (context, what came before, decision, alternatives, consequences, which ADR it supersedes), then retry this write."
      fi
    fi
    ;;
esac

exit 0
