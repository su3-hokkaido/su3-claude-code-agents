#!/bin/sh
# PreToolUse hook for the Bash tool.
#
# Policy: a developer-set subagent never changes production data or live
# infrastructure on its own, and never applies version upgrades without a human.
#
#   A. Data changes (SQL writes, migrations, data patches, bulk deletes)
#        - dry-run form (--dry-run, --check, SQL wrapped in ROLLBACK, ...) -> allowed
#        - real run with no matching dry-run earlier in this session   -> DENIED
#          (the agent must run the dry-run first and show the result)
#        - real run after a matching dry-run                            -> ASK the human
#   B. Live infrastructure changes (terraform apply, kubectl apply, helm
#      upgrade, cloud deletes, deploys)
#        - dry-run / plan form -> allowed;  real run -> ASK the human
#   C. Version upgrades (npm update, pip install -U, apt upgrade, ...)
#        - dry-run form -> allowed;  real run -> ASK the human
#   D. Other irreversible commands (force push, reset --hard, broad rm -rf,
#      pipe to shell, sudo, publish/release, ...) -> ASK the human
#
# "ASK" shows a permission prompt; in non-interactive runs it counts as a
# denial. Tools with no dry-run mode can never pass rule A: the Commander must
# run them personally.
#
# Dry runs are remembered as "<session> <key>" lines in the fixed file
# /tmp/developer-set-guard-dry-runs (a dry run in one session never unlocks another).
#
# Acts only inside developer-set subagents (agent_type "developer-set:..."), so
# it never changes how the Commander works in the main session.
# This is a text-pattern safety net, not a security boundary: a reworded
# command can slip past it. Needs no jq. POSIX sh; macOS and Linux.

INPUT=$(cat)

printf '%s' "$INPUT" | grep -Eq '"agent_type"[[:space:]]*:[[:space:]]*"developer-set:' || exit 0

# The command string (JSON-escaped). Fall back to the whole input.
CMD=$(printf '%s' "$INPUT" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1)
[ -n "$CMD" ] || CMD="$INPUT"

SESSION=$(printf '%s' "$INPUT" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -n 1)

has() {
  printf '%s' "$CMD" | grep -Eiq -- "$1"
}

# --- dry-run detection -------------------------------------------------------
# Flags that mean "show, do not change". SQL counts as a dry run only when a DB
# client runs it wrapped in a transaction that ends with ROLLBACK.
DRY_RE='(--dry-?run|--dry([[:space:]=]|"|$)|--check([[:space:]=]|"|$)|--noop|--what-if|--simulate|--plan-only|--diff-only|-dryRunOutput|--server-dry-run)'
DB_CLI='(^|[^a-z_-])(psql|mysql|mariadb|sqlite3|mongosh|mongo|redis-cli|cqlsh|clickhouse-client|sqlcmd|pg_restore)[[:space:]]'
SQL_ROLLBACK=';[[:space:]]*rollback([[:space:]]*;|[[:space:]"]|$)'
is_dry=0
if has "$DRY_RE"; then is_dry=1; fi
if has "$DB_CLI" && has "$SQL_ROLLBACK"; then is_dry=1; fi

PROD=""
has '(^|[^a-z])prod(uction)?([^a-z]|$)' && PROD=" (the command mentions production)"

ask() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"developer-set guard: '"$1"''"$PROD"'. Approve only after you have seen the dry-run or plan output."}}'
  exit 0
}

deny() {
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"developer-set guard: '"$1"''"$PROD"'. Run it first in dry-run form (for example --dry-run, or SQL wrapped in BEGIN ... ROLLBACK), show the Commander the result, then try again. If the tool has no dry-run mode, ask the Commander to run it themselves."}}'
  exit 0
}

# Key identifying "the same command without its dry-run markers".
norm_key() {
  printf '%s' "$CMD" |
    tr 'A-Z' 'a-z' |
    sed -E 's/--(dry-?run|dry|check|noop|what-if|simulate|plan-only|diff-only|server-dry-run)(=[^[:space:]]*)?//g; s/-dryrunoutput(=[^[:space:]]*)?//g; s/(^|[^a-z])(begin|rollback|commit)([^a-z]|$)/ /g' |
    tr -cd 'a-z0-9' |
    cksum | cut -d ' ' -f 1
}

# --- A. data changes ---------------------------------------------------------
SQL_WRITE='(update[[:space:]]+[a-z_."`]+[[:space:]]+set|insert[[:space:]]+into|delete[[:space:]]+from|alter[[:space:]]+(table|database)|drop[[:space:]]+(table|database|schema|index)|truncate|merge[[:space:]]+into|\.(update|insert|delete|drop|remove|replace)(one|many)?\(|flushall|flushdb|[[:space:]]del[[:space:]])'
SQL_FILE='([[:space:]]-f[[:space:]=]|--file|<[[:space:]]*[^[:space:]]+\.sql)'
MIGRATE='((rails|rake)[[:space:]]+db:(migrate|rollback|reset|drop|seed|schema:load)|prisma[[:space:]]+(migrate[[:space:]]+(deploy|dev|reset)|db[[:space:]]+(push|execute))|alembic[[:space:]]+(upgrade|downgrade)|flyway[[:space:]]+(migrate|clean|repair|undo)|liquibase[[:space:]]+(update|rollback)|knex[[:space:]]+migrate|manage\.py[[:space:]]+(migrate|flush|loaddata|sqlflush)|django-admin[[:space:]]+(migrate|flush|loaddata)|sequelize(-cli)?[[:space:]]+db:(migrate|seed)|typeorm[[:space:]]+migration:(run|revert)|dbmate[[:space:]]+(up|down|drop)|goose[[:space:]]+(up|down|reset)|(backfill|data[-_]?patch|fix[-_]?data))'
CLOUD_DATA='(aws[[:space:]]+(dynamodb[[:space:]]+(put-item|update-item|delete-item|batch-write-item|delete-table)|s3[[:space:]]+(rm|mv)|s3[[:space:]]+sync[^"|;&]*--delete|rds[[:space:]]+delete)|gsutil[[:space:]]+(rm|mv)|gcloud[[:space:]]+(sql|firestore|spanner|bigtable)[^"|;&]*(delete|import))'

data_change=0
if has "$DB_CLI" && { has "$SQL_WRITE" || has "$SQL_FILE"; }; then data_change=1; fi
has "$MIGRATE" && data_change=1
has "$CLOUD_DATA" && data_change=1

if [ "$data_change" -eq 1 ]; then
  KEY=$(norm_key)
  if [ "$is_dry" -eq 1 ]; then
    umask 077
    echo "${SESSION:-nosession} $KEY" >>/tmp/developer-set-guard-dry-runs
    exit 0
  fi
  if [ -f /tmp/developer-set-guard-dry-runs ] && grep -Fxq "${SESSION:-nosession} $KEY" /tmp/developer-set-guard-dry-runs; then
    ask "data change that ran as a dry-run earlier; this is the real run"
  fi
  deny "data change without a prior dry-run"
fi

# --- B. live infrastructure changes -------------------------------------------
INFRA='((terraform|tofu|terragrunt)[[:space:]]+(apply|destroy|import|taint|untaint|state[[:space:]]+(rm|mv|push)|force-unlock)|kubectl[[:space:]]+([^|;&"]*[[:space:]])?(apply|delete|replace|patch|scale|rollout|drain|cordon|uncordon|edit|create|set|annotate|label)([[:space:]]|"|$)|helm[[:space:]]+(install|upgrade|uninstall|rollback|delete)|pulumi[[:space:]]+(up|destroy|refresh)|ansible-playbook|docker[[:space:]]+(system|volume|image|container|network)[[:space:]]+prune|docker[[:space:]]+compose[[:space:]]+down[^"|;&]*-v|(aws|gcloud|az)[[:space:]][^"|;&]*(delete|terminate|destroy|remove|rb|modify|update|put-|create|deregister|stop-|reboot)|(cdk|sam|serverless|sls|firebase|flyctl|fly|heroku|wrangler|netlify|vercel)[[:space:]]+[^"|;&]*(deploy|destroy|publish|--prod)|git[[:space:]]+push[[:space:]]+heroku)'
if has "$INFRA"; then
  [ "$is_dry" -eq 1 ] && exit 0
  ask "live infrastructure change"
fi

# --- C. version upgrades -------------------------------------------------------
UPGRADE='((npm|pnpm)[[:space:]]+(update|upgrade|up|audit[[:space:]]+fix)|yarn[[:space:]]+(upgrade|up|upgrade-interactive)|(npm|pnpm|yarn)[[:space:]]+(install|add|i)[[:space:]][^"|;&]*@(latest|next)|(npx[[:space:]]+)?(npm-check-updates|ncu)[[:space:]][^"|;&]*-u|pip3?[[:space:]]+install[^"|;&]*([[:space:]]-U|--upgrade)|poetry[[:space:]]+(update|add)|uv[[:space:]]+(lock|sync|pip[[:space:]]+install)[^"|;&]*(--upgrade|-U)|cargo[[:space:]]+update|go[[:space:]]+get[^"|;&]*[[:space:]]-u|bundle[[:space:]]+update|composer[[:space:]]+(update|require)|(flutter|dart)[[:space:]]+pub[[:space:]]+(upgrade|downgrade)|gem[[:space:]]+update|brew[[:space:]]+(upgrade|update)|(apt|apt-get)[[:space:]]+(upgrade|dist-upgrade|full-upgrade|install)|(yum|dnf)[[:space:]]+(update|upgrade|install)|softwareupdate)'
if has "$UPGRADE"; then
  [ "$is_dry" -eq 1 ] && exit 0
  ask "version upgrade (it may be a minor or major change)"
fi

# --- D. other irreversible commands ---------------------------------------------
check() {
  if has "$2"; then
    ask "$1"
  fi
}

check "force push" 'git[[:space:]]+push[^"|;&]*([[:space:]]--force|[[:space:]]-[a-zA-Z]*f([[:space:]"]|$))'
check "git reset --hard" 'git[[:space:]]+reset[[:space:]]+[^"|;&]*--hard'
check "git clean -f" 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'
check "recursive delete of a broad path" 'rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)+(/|~|\\\$HOME|\$HOME|\*|\.|\.\.)(/?)([[:space:]"]|$)'
check "pipe to shell" '(curl|wg[e]t)[^"|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh)'
check "world-writable permissions" 'chmod[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*0?777'
check "sudo" '(^|[^a-zA-Z])sudo[[:space:]]'
check "publish or release" '(npm|yarn|pnpm)[[:space:]]+publish|gh[[:space:]]+(release|pr[[:space:]]+merge)|(cargo|twine)[[:space:]]+(publish|upload)'

exit 0
