#!/bin/sh
# PreToolUse hook for the Bash tool (su3-developer-set-with-guards only).
#
# A subagent of this plugin never changes production data or live infrastructure on
# its own, never reads production either, and never applies version upgrades or
# git writes without a human. Decision table: 21_guard_spec.md section 3.7 (same
# nine rows as 22_policy_file_spec.md 4.3):
#   1 secrets and writes to protected paths      -> deny (T3)
#   2 dry-run / plan form in dev or staging      -> allow (dry run recorded)
#   3 force push, policy forbid                  -> deny (T3)
#   4 T2 or target read in production / unknown  -> deny (T2-PROD), dry runs too
#   5 reserved, not on the allow-list, git write -> deny
#   6 data rule without a recorded dry run       -> deny
#   7 dev-only pass (without-approval, valid)    -> allow
#   8 after-approval                             -> ask (interactive) / deny (unattended)
#   9 anything else                              -> allow
#
# Acts only inside su3-developer-set-with-guards subagents (agent_type), so it never
# changes how the Commander works in the main session. This is a text-pattern safety
# net, not a security boundary: a reworded command can slip past it.
# POSIX sh; macOS and Linux; no jq. No -e and no -u: every path ends in exit 0.
#
# The only file this script writes is the fixed dry-run memory
# /tmp/developer-set-guard-dry-runs (one "<session> <key>" line per recorded dry run).

INPUT=$(cat)

printf '%s' "$INPUT" | grep -Eq '"agent_type"[[:space:]]*:[[:space:]]*"su3-developer-set-with-guards:' || exit 0

GC_DIR=$(dirname "$0")
LIB=$GC_DIR/guard-common.sh
if [ ! -r "$LIB" ]; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"developer-set guard: DENIED [T3-PROTECT] the guard library is missing. This is a policy decision, not an error. Tell the Commander that the plugin installation is damaged."}}'
  exit 0
fi
. "$LIB"

CMD=$(json_field command)
[ -n "$CMD" ] || CMD=$INPUT
SESSION=$(json_field session_id)
CWD=$(json_field cwd)

# N1: normalize the JSON-escaped text (newline -> separator, tab or CR -> space, escaped quote -> quote)
CMD=$(printf '%s' "$CMD" | sed -e 's/\\n/ ; /g; s/\\[tr]/ /g; s/\\"/"/g')

# --- prefilter ---------------------------------------------------------------
TRIGGERS='psql|mysql|mariadb|sqlite3|mongo|redis-cli|cqlsh|clickhouse|sqlcmd|pg_restore|pg_dump|rails|rake|prisma|alembic|flyway|liquibase|knex|manage\.py|django-admin|sequelize|typeorm|dbmate|goose|atlas|sqitch|diesel|sqlx|ecto|backfill|data.?patch|fix.?data|aws|gcloud|az |bq |gsutil|terraform|tofu|terragrunt|kubectl|helm|pulumi|ansible|docker|cdk|sam |serverless|sls |firebase|fly|heroku|wrangler|netlify|vercel|npm|pnpm|yarn|npx|ncu|pip|poetry|uv |cargo|go get|bundle|composer|pub |gem|brew|apt|yum|dnf|softwareupdate|gh |jira|acli|curl|wget|twine|mvn|gradle|dotnet|vsce|ovsx|ssh-keygen|openssl|vault|gpg|git|rm |chmod|sudo|printenv|env|export|/proc/|\.env|\.pem|\.key|\.p12|\.pfx|\.jks|\.keystore|\.tfstate|id_|\.ssh|\.aws|\.gnupg|\.kube|\.docker|\.netrc|\.pgpass|master\.key|credentials|docs/policy|\.claude/|su3-developer-set-with-guards|su3-developer-set/|loop-state|\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh|dash|ksh)|echo|printf|>'

# A command with no trigger word or no pattern hit can still match a project "cmd=" line
# (forbid or reserve, any environment, 21 s6). Only when a policy file exists and names one.
cmd_only_check() {
  GB_PFILE=${CLAUDE_PROJECT_DIR:-$CWD}/docs/policy/autonomy-policy.md
  [ -f "$GB_PFILE" ] && grep -Eq '^[[:space:]]*(forbid|reserve):[[:space:]]+cmd=' "$GB_PFILE" 2>/dev/null || exit 0
  ensure_h9
  classify_env
  GB_FB=$(pol_match FORBID)
  if [ -n "$GB_FB" ]; then
    RULE="policy line $GB_FB"; ENVLBL=
    deny T3-FORBID T3 'an action the project policy forbids' 'None inside the loop. Report the need under Open questions.' "$T3_HINT $ESC_HINT"
  fi
  GB_RS=$(pol_match RESERVE)
  if [ -n "$GB_RS" ]; then
    RULE="policy line $GB_RS"; ENVLBL=
    deny T2-RESERVED T2 "an action reserved for the Commander by $RULE" 'The Commander runs this. Put the exact command into your report as a Parked action block.' "$ESC_HINT"
  fi
  exit 0
}
# No trigger word: leave at once unless a policy "cmd=" line exists (then the later
# no-hit exit calls cmd_only_check; the helper functions are defined further down).
if ! printf '%s' "$CMD" | grep -Eiq -- "$TRIGGERS"; then
  GB_PFILE=${CLAUDE_PROJECT_DIR:-$CWD}/docs/policy/autonomy-policy.md
  [ -f "$GB_PFILE" ] && grep -Eq '^[[:space:]]*(forbid|reserve):[[:space:]]+cmd=' "$GB_PFILE" 2>/dev/null || exit 0
fi

has() { printf '%s' "$CMD" | grep -Eiq -- "$1"; }

# no_ops <text>: no shell operator (E1 test), after removing 2>&1 and >/dev/null forms
no_ops() {
  GB_S=$(printf '%s' "$1" | sed -E 's/2>&1//g; s/>[[:space:]]*\/dev\/null//g')
  printf '%s' "$GB_S" | grep -Eq '[;&|<>`]|\$\(' && return 1
  return 0
}

load_mode
POL_LOADED=
ensure_policy() {
  if [ -z "$POL_LOADED" ]; then load_policy nogit; POL_LOADED=1; fi
}
ensure_h9() { ensure_policy; policy_h9; }

# --- messages: keys ---------------------------------------------------------
ENVKEYS='data-write data-delete schema-migrate schema-contract infra-apply infra-destroy'
ORDER='data-write data-delete schema-migrate schema-contract infra-apply infra-destroy version publish credential'
PROD_BASE='The Commander runs actions in production or in an environment the command does not identify, dry runs and plans included. Prepare the exact command, the dry-run or plan command for the Commander to run, and the rollback.'
T3_HINT='This is never run by an agent and never approved inside the loop.'
PROD_HINT='Next: production, and any environment the command does not identify, is run by the Commander only, dry runs and plans included. Do not run this or its dry-run or plan form. Prepare the exact command, the dry-run or plan command for the Commander to run, and the rollback.'
READ_HINT='Next: reads in production, and in any environment the command does not identify, are run by the Commander only. Do not run this read and do not read the same data another way (no other client, script, tool or saved file). Put the read command and the result you need into a Parked action block with Dry-run result: No dry-run form: read-only query and Rollback: Not needed: read-only (Tier: T2, Tier reason: production read (M1), Who may run: Commander), and write the question the result answers under Open questions. The Commander runs it and hands the result over.'
DRY_CLI_HINT='Next: run the same statement once as BEGIN; <statement>; ROLLBACK; in one -c or -e argument with no COMMIT and no comments, and keep the raw output. The command must be only that one command: no && or ; or pipe outside the quotes, no redirect except 2>&1, and no $( or backticks anywhere (N1). Flags or comments such as --dry-run do not count. Then you may try the real command once; if it is denied, do not retry. SQL from a file (-f or <), a heredoc and sqlite3 have no dry-run form here. If you cannot do this, put the exact command, dry-run result and rollback in a Parked action block in your report and continue with other work.'
DRY_TOOL_HINT='Next: use the tools own dry-run or plan option if it has one, keep the raw output, then you may try the real command once; if it is denied, do not retry. If the tool has no such option, or it is still denied, put the exact command, dry-run result (No dry-run form: reason) and rollback in a Parked action block in your report and continue with other work.'
PARK_HINT='Nobody can answer a prompt in unattended mode, so this is not run now. Put a Parked action block in your report with Who may run: agent after approval (policy rule) and the exact command, dry-run result and rollback; it is run later in an interactive session.'

# key_text <key>: sets KWHAT and KALT (T2-PROD wording; spec 5.3)
key_text() {
  case $1 in
    data-delete) KWHAT='data-delete (physical delete in production or an environment the command does not identify)'
      KALT="$PROD_BASE Use a soft delete (a deleted_at or status column) in the expand, migrate, contract pattern; give the dry-run command (BEGIN; ...; ROLLBACK;) and the row-count query for the Commander to run." ;;
    data-write) KWHAT='data-write (data change in production or an environment the command does not identify)'
      KALT="$PROD_BASE Give the dry-run command (BEGIN; ...; ROLLBACK;) for the Commander to run, the query that counts the affected rows, and a restore plan." ;;
    schema-migrate) KWHAT='schema-migrate (migration in production or an environment the command does not identify)'
      KALT="$PROD_BASE Expand step only (additive, backward compatible), with the migration plan and a rollback script." ;;
    schema-contract) KWHAT='schema-contract (contract step: drop table, column or schema)'
      KALT='Park the contract step: it runs only after the expand and migrate steps are verified. Give the exact statement, a backup or restore plan, and the verification query.' ;;
    infra-apply) KWHAT='infra-apply (infrastructure change in production or an environment the command does not identify)'
      KALT="$PROD_BASE Give the terraform plan, kubectl diff or helm upgrade --dry-run command for the Commander to run, and the rollback." ;;
    infra-destroy) KWHAT='infra-destroy (infrastructure delete or destroy)'
      KALT='Give the terraform plan -destroy command or the list of resources, for the Commander to run, and how to recreate them.' ;;
    version) KWHAT='version upgrade (of unknown size)'
      KALT='Show npm outdated, pip list --outdated or the dry-run listing; treat an unknown size as a major upgrade.' ;;
    publish) KWHAT='publish (package publish, release or merge)'
      KALT='Run the dry-run form (for example npm publish --dry-run) and give the release notes; the Commander publishes.' ;;
    credential) KWHAT='credential-new (creating credentials)'
      KALT='Describe what is needed and why in your report; the Commander does it.' ;;
    *) KWHAT='an action reserved for the Commander'; KALT="$PROD_BASE" ;;
  esac
}

has_key() { case " $HITS " in *" $1 "*|*" $1:cli "*|*" $1:tool "*) return 0 ;; esac; return 1; }
has_cli() { case " $HITS " in *" $1:cli "*) return 0 ;; esac; return 1; }
add() { HITS="$HITS $1"; }

# --- secrets (3.8): row 1, never skipped ---------------------------------------
SECRET_TOK='(^|[[:space:]/"'"'"'=<>:~])(\.env(\.[a-z0-9_-]+)?|id_(rsa|dsa|ecdsa|ed25519)(\.pub)?|[a-z0-9_.-]+\.(pem|key|p12|pfx|jks|keystore)|[a-z0-9_.-]*\.tfstate(\.backup)?|\.netrc|\.pgpass|\.git-credentials|master\.key|\.ssh/[^[:space:]"]*|\.aws/(credentials|config)|\.gnupg/[^[:space:]"]*|\.kube/config|\.docker/config\.json)([[:space:]"'"'"';&|)`]|$)'
SECRET_ENVDUMP='((^|[;&|(`[:space:]])printenv([[:space:]]|$)|(^|[;&|(`])[[:space:]]*env[[:space:]]*($|[|;&>])|export[[:space:]]+-p|/proc/[^[:space:]]*/environ|(echo|printf)[^|;&]*\$\{?[A-Za-z0-9_]*(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|PRIVATE_?KEY|CREDENTIAL|ACCESS_?KEY)[A-Za-z0-9_]*)'
SAFE_HEAD='^[[:space:]]*(ls|stat|test|\[|file|basename|dirname|echo|printf|git[[:space:]]+(check-ignore|ls-files|status))([[:space:]]|$)'
CMD_L=$(printf '%s' "$CMD" | tr 'A-Z' 'a-z')
CMD_X=$(printf '%s' "$CMD_L" | sed -E 's/\.env\.(example|sample|template|dist|defaults)//g; s/id_(rsa|dsa|ecdsa|ed25519)\.pub//g')
SECRET_WHAT='reading or writing a secret (env file, key file, credentials, environment dump)'
SECRET_ALT='Refer to the value by its variable name, read .env.example for the list of variables, and report that the Commander must put the value in the environment.'
SECRET_HINT="$T3_HINT Do not read, print or copy secret values: refer to them by variable name. Next: do not retry or reach the same data another way. Finish the parts of your step that do not need it, continue with other work, and report one Parked action block with Tier: T3. End with STATUS: BLOCKED or STATUS: DONE. Do not write 06_commander_actions.md; the loop records it."
ENVLBL=na
if printf '%s' "$CMD_X" | grep -Eiq "$SECRET_ENVDUMP"; then
  deny T3-SECRET T3 "$SECRET_WHAT" "$SECRET_ALT" "$SECRET_HINT"
fi
if printf '%s' "$CMD_X" | grep -Eiq "$SECRET_TOK"; then
  if no_ops "$CMD" && has "$SAFE_HEAD"; then :; else
    deny T3-SECRET T3 "$SECRET_WHAT" "$SECRET_ALT" "$SECRET_HINT"
  fi
fi

# --- protected paths written from Bash (3.8): row 1 ------------------------------
WRITE_VERB='(>|>>|(^|[[:space:];&|])tee[[:space:]]|sed[[:space:]]+(-[a-zA-Z]*i)|perl[[:space:]]+-[a-zA-Z]*i|(^|[[:space:];&|])(mv|cp|rm|ln|install|chmod|chown|truncate|dd|touch|rsync|unlink|patch)[[:space:]]|git[[:space:]]+(checkout|restore|rm|mv|apply|stash))'
PROT_FIXED='docs/policy/|(^|[^a-z0-9])\.claude/(settings|hooks/)|su3-developer-set(-with-guards)?/([^/]+/)?(hooks|scripts|skills)/|loop-state\.sh|(^|[[:space:]/"'"'"'=])\.git/'
CMD_W=$(printf '%s' "$CMD" | sed -E 's/2>&1//g; s/>[[:space:]]*\/dev\/null//g')
if printf '%s' "$CMD_W" | grep -Eiq "$WRITE_VERB"; then
  PROT_HIT=0
  printf '%s' "$CMD_W" | grep -Eiq -- "$PROT_FIXED" && PROT_HIT=1
  if [ "$PROT_HIT" -eq 0 ]; then
    ensure_policy
    GB_PP=$(printf '%s\n' "$POLREC" | sed -n 's/^PROTECT \([^ ]*\) .*/\1/p')
    if [ -n "$GB_PP" ] && match_any "$CMD_W" "$GB_PP"; then PROT_HIT=1; fi
  fi
  if [ "$PROT_HIT" -eq 1 ]; then
    deny T3-PROTECT T3 'changing a guard-defining or protected file (policy, hooks, settings, .git/, plugin helper scripts and skills such as loop-state.sh, protected path)' 'Do not edit it. Describe the change you need under Open questions, or put the text in your report for the owner of the file; only the Commander edits the guard-defining files.' "$T3_HINT $ESC_HINT"
  fi
fi

# --- exemptions E1 and E2 ----------------------------------------------------------
E1=0; E2=0
if no_ops "$CMD" && has '^[[:space:]]*(echo|printf|cat|head|tail|wc|ls|grep|egrep|fgrep|rg|git[[:space:]]+(log|show|diff|status|grep))([[:space:]]|$)' && ! has '--pre|--output'; then E1=1; fi
if no_ops "$CMD" && has '^[[:space:]]*git[[:space:]]+(add|commit|checkout[[:space:]]+-b|switch[[:space:]]+-c|branch[[:space:]]+[^-[:space:]])'; then E2=1; fi

# --- patterns (3.3, 3.5, 3.6) -----------------------------------------------------
DB_CLI='(^|[^a-z_-])(psql|mysql|mariadb|sqlite3|mongosh|mongo|redis-cli|cqlsh|clickhouse-client|sqlcmd|pg_restore)([[:space:]"]|$)'
K_DATA_DELETE_SQL='delete[[:space:]]+from|truncate[[:space:]]|\.(delete|remove)(one|many)?\(|flushall|flushdb|[[:space:]]del[[:space:]]'
K_DATA_WRITE_SQL='update[[:space:]]+[a-z_."`]+[[:space:]]+set|insert[[:space:]]+into|merge[[:space:]]+into|replace[[:space:]]+into|\.(update|insert|replace)(one|many)?\(|\\copy|copy[[:space:]]+[a-z_."]+[[:space:]]+from'
K_CONTRACT_SQL='drop[[:space:]]+(table|database|schema|index|column|view|type|extension|constraint|trigger|function)|alter[[:space:]]+table[^;"]*[[:space:]]drop[[:space:]]|\.(drop|dropdatabase|dropcollection|dropindex)\('
K_MIGRATE_SQL='create[[:space:]]+(unique[[:space:]]+)?(table|index|schema|extension|type|view)|alter[[:space:]]+(table|database|schema|type|view)'
SQL_FILE='([[:space:]]-f[[:space:]=]|--file|<[[:space:]]*[^[:space:]]+\.sql)'
SQL_FLAG='[[:space:]](-c|--command|-e|--eval)[[:space:]=]'
K_MIG_UP='((rails|rake)[[:space:]]+db:migrate([[:space:]]|"|$)|prisma[[:space:]]+(migrate[[:space:]]+(deploy|dev)|db[[:space:]]+push)|alembic[[:space:]]+upgrade|flyway[[:space:]]+migrate|liquibase[[:space:]]+update|knex[[:space:]]+migrate(:latest|:up)?([[:space:]]|"|$)|manage\.py[[:space:]]+migrate|django-admin[[:space:]]+migrate|sequelize(-cli)?[[:space:]]+db:migrate([[:space:]]|"|$)|typeorm[[:space:]]+migration:run|dbmate[[:space:]]+(up|migrate)|goose[[:space:]]+up|atlas[[:space:]]+(migrate|schema)[[:space:]]+apply|sqitch[[:space:]]+deploy|diesel[[:space:]]+migration[[:space:]]+run|sqlx[[:space:]]+migrate[[:space:]]+run|ecto\.migrate)'
K_MIG_DOWN='((rails|rake)[[:space:]]+db:(rollback|reset|drop|schema:load|migrate:(reset|down))|prisma[[:space:]]+(migrate[[:space:]]+reset|db[[:space:]]+execute)|alembic[[:space:]]+downgrade|flyway[[:space:]]+(clean|undo|repair)|liquibase[[:space:]]+rollback|knex[[:space:]]+migrate:(rollback|down)|typeorm[[:space:]]+(migration:revert|schema:drop)|sequelize(-cli)?[[:space:]]+db:migrate:undo|dbmate[[:space:]]+(down|drop)|goose[[:space:]]+(down|reset)|atlas[[:space:]]+schema[[:space:]]+clean)'
K_DATA_WRITE_TOOL='((rails|rake)[[:space:]]+db:seed|prisma[[:space:]]+db[[:space:]]+seed|sequelize(-cli)?[[:space:]]+db:seed|manage\.py[[:space:]]+loaddata|django-admin[[:space:]]+loaddata|(backfill|data[-_]?patch|fix[-_]?data)|aws[[:space:]]+dynamodb[[:space:]]+(put-item|update-item)|gcloud[[:space:]]+(sql|firestore|spanner|bigtable)[^"|;&]*import)'
K_DATA_DELETE_TOOL='(manage\.py[[:space:]]+(flush|sqlflush)|django-admin[[:space:]]+flush|aws[[:space:]]+dynamodb[[:space:]]+(delete-item|batch-write-item)|aws[[:space:]]+s3[[:space:]]+(rm|mv)([[:space:]]|"|$)|aws[[:space:]]+s3[[:space:]]+sync[^"|;&]*--delete|aws[[:space:]]+s3api[[:space:]]+delete-objects?|gsutil[[:space:]]+(-m[[:space:]]+)?(rm|mv)([[:space:]]|"|$)|gcloud[[:space:]]+(firestore|spanner|bigtable)[^"|;&]*delete|az[[:space:]]+storage[[:space:]]+(blob|container)[[:space:]]+delete)'
K_CONTRACT_TOOL='aws[[:space:]]+dynamodb[[:space:]]+delete-table'
TF_PFX='(terraform|tofu|terragrunt)([[:space:]]+-[^[:space:]]+)*[[:space:]]+'
K_INFRA_DESTROY='('"$TF_PFX"'(destroy|apply[^"|;&]*-destroy)|kubectl[[:space:]]+([^|;&"]*[[:space:]])?delete([[:space:]]|"|$)|helm[[:space:]]+(uninstall|delete)|pulumi[[:space:]]+destroy|docker[[:space:]]+(system|volume|image|container|network)[[:space:]]+prune|docker[[:space:]]+compose[[:space:]]+down[^"|;&]*-v|aws[[:space:]]+rds[[:space:]]+delete|(fly|flyctl)[[:space:]]+(apps[[:space:]]+destroy|destroy)|(cdk|sls|serverless)[[:space:]]+(destroy|remove))'
K_INFRA_APPLY='('"$TF_PFX"'(apply|refresh|import|taint|untaint|state[[:space:]]+(rm|mv|push)|force-unlock)|kubectl[[:space:]]+([^|;&"]*[[:space:]])?(apply|replace|patch|scale|rollout|drain|cordon|uncordon|edit|create|set|annotate|label|expose|run)([[:space:]]|"|$)|helm[[:space:]]+(install|upgrade|rollback)|pulumi[[:space:]]+(up|refresh)|ansible-playbook|gh[[:space:]]+workflow[[:space:]]+run|(cdk|sam|serverless|sls|firebase|flyctl|fly|heroku|wrangler|netlify|vercel)[[:space:]]+[^"|;&]*(deploy|--prod)|git[[:space:]]+push[[:space:]]+heroku)'
K_INFRA_PLAN='('"$TF_PFX"'plan|kubectl[[:space:]]+([^|;&"]*[[:space:]])?diff([[:space:]]|"|$)|helm[[:space:]]+([^|;&"]*[[:space:]])?diff([[:space:]]|"|$)|pulumi[[:space:]]+preview|cdk[[:space:]]+diff([[:space:]]|"|$))'
K_CLOUD_DESTROY='(aws|gcloud|az)[[:space:]][^"|;&]*([[:space:]-](delete|terminate|destroy|remove|deregister)|[[:space:]]rb([[:space:]]|"|$))'
K_CLOUD_APPLY='(aws|gcloud|az)[[:space:]][^"|;&]*([[:space:]-](modify|update|create|stop|start|reboot|attach|associate|run-instances)|[[:space:]-]put-)'
K_UPGRADE='((npm|pnpm)[[:space:]]+(update|upgrade|up|audit[[:space:]]+fix)|yarn[[:space:]]+(upgrade|up|upgrade-interactive)|(npm|pnpm|yarn)[[:space:]]+(install|add|i)[[:space:]][^"|;&]*@(latest|next)|(npx[[:space:]]+)?(npm-check-updates|ncu)[[:space:]][^"|;&]*-u|pip3?[[:space:]]+install[^"|;&]*([[:space:]]-U|--upgrade)|poetry[[:space:]]+(update|add)|uv[[:space:]]+(lock|sync|pip[[:space:]]+install)[^"|;&]*(--upgrade|-U)|cargo[[:space:]]+update|go[[:space:]]+get[^"|;&]*[[:space:]]-u|bundle[[:space:]]+update|composer[[:space:]]+(update|require)|(flutter|dart)[[:space:]]+pub[[:space:]]+(upgrade|downgrade)|gem[[:space:]]+update|brew[[:space:]]+(upgrade|update)|(apt|apt-get)[[:space:]]+(upgrade|dist-upgrade|full-upgrade|install)|(yum|dnf)[[:space:]]+(update|upgrade|install)|softwareupdate)'
K_PUBLISH='((npm|yarn|pnpm)[[:space:]]+(publish|unpublish|deprecate|dist-tag)|gh[[:space:]]+(release[[:space:]]+(create|upload|delete|edit)|pr[[:space:]]+merge)|(cargo|twine)[[:space:]]+(publish|upload)|docker[[:space:]]+push|helm[[:space:]]+push|gem[[:space:]]+push|(poetry|uv)[[:space:]]+publish|mvn[[:space:]]+[^"|;&]*deploy|gradle[[:space:]]+[^"|;&]*publish|dotnet[[:space:]]+nuget[[:space:]]+push|(vsce|ovsx)[[:space:]]+publish)'
K_CRED='(aws[[:space:]]+iam[[:space:]]+(create-(access-key|user|role|login-profile)|attach-|put-(user|role|group)-policy)|gcloud[[:space:]]+iam[[:space:]]+service-accounts[[:space:]]+(create|keys[[:space:]]+create)|az[[:space:]]+ad[[:space:]]+sp[[:space:]]+create|gh[[:space:]]+(auth[[:space:]]+(login|token)|secret[[:space:]]+set)|ssh-keygen|openssl[[:space:]]+(genrsa|genpkey|req[[:space:]][^"|;&]*-newkey)|kubectl[[:space:]]+create[[:space:]]+(secret|token|serviceaccount)|vault[[:space:]]+(token[[:space:]]+create|(kv[[:space:]]+)?(put|write))|npm[[:space:]]+token[[:space:]]+create|gpg[[:space:]]+[^"|;&]*--(full-)?gen-key)'
GIT_PFX='git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+'
K_RESET_HARD="${GIT_PFX}"'reset[[:space:]]+[^"|;&]*--hard'
K_CLEAN_F="${GIT_PFX}"'clean[[:space:]]+-[a-zA-Z]*f'
K_RM_BROAD='rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)+(/|~|\$HOME|\*|\.{1,2})(/?)([[:space:]"]|$)'
K_PIPE_SH='\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh|dash|ksh)([[:space:]"]|$)'
K_CHMOD='chmod[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*0?777'
K_SUDO='(^|[^a-zA-Z])sudo[[:space:]]'
K_FORCE_PUSH="${GIT_PFX}"'push[^"|;&]*([[:space:]]--force|[[:space:]]--force-with-lease|[[:space:]]--force-if-includes|[[:space:]]--mirror|[[:space:]]-[a-zA-Z]*f([[:space:]"]|$)|[[:space:]]\+[^[:space:]]+)'
K_GIT_WRITE="${GIT_PFX}"'(add|commit|checkout|switch|restore|reset|rebase|merge|cherry-pick|revert|pull|push|stash|tag|branch|rm|mv|clean|am|apply|init|worktree|gc|filter-branch|update-ref|config|submodule|notes)([[:space:]"]|$)'
K_GIT_READONLY_SUB="${GIT_PFX}"'((stash[[:space:]]+(list|show))|(tag[[:space:]]+(-l|--list))|(branch[[:space:]]+(-a|-r|-l|--list|--show-current|-v|-vv|--contains))|(config[[:space:]]+(--get|--list|-l)))'
DUMP_CLI='(^|[^a-z_-])(pg_dump|pg_dumpall|mysqldump|mongodump|mongoexport)([[:space:]"]|$)'
KUBECTL_ANY='(^|[^a-z0-9_.-])kubectl([[:space:]]|$)'
HELM_PFX='helm([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+'
HELM_READ="(^|[^a-z0-9_.-])${HELM_PFX}(list|ls|status|get|history)([[:space:]\"]|\$)"
CLOUD_ANY='(^|[^a-z0-9_.-])(aws|gcloud|az|gsutil|bq)[[:space:]]'
TF_READ="(^|[^a-z0-9_.-])${TF_PFX}(show|output|state[[:space:]]+(list|show|pull))([[:space:]\"]|\$)"
K_TARGET_READ="(${DB_CLI}|${DUMP_CLI}|${KUBECTL_ANY}|${HELM_READ}|${CLOUD_ANY}|${TF_READ})"
READ_LOCAL='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*([^[:space:]]*/)?((psql|mysql|mariadb|sqlite3|mongosh|mongo|redis-cli|cqlsh|clickhouse-client|sqlcmd|pg_restore|pg_dump|pg_dumpall|mysqldump|mongodump|mongoexport|kubectl|helm|aws|gcloud|az|gsutil|bq|terraform|tofu|terragrunt)[[:space:]]+(--version|--help|-V)|kubectl[[:space:]]+(version[[:space:]]+--client|config[[:space:]]+(current-context|get-contexts|get-clusters|use-context)|completion|help|plugin[[:space:]]+list)|(aws|gcloud|az|gsutil|bq)[[:space:]]+(help|version)|aws[[:space:]]+configure[[:space:]]+(list|list-profiles)|gcloud[[:space:]]+config[[:space:]]+(list|get-value))([[:space:]"]|$)'
DRY_RE='(--dry-?run|--dry([[:space:]=]|$)|--check([[:space:]=]|$)|--noop|--what-if|--simulate|--plan-only|--diff-only|-dryRunOutput|--server-dry-run)'

# --- collect hits ------------------------------------------------------------------
HITS=''
PLAN_FORM=0
READ=0
if [ "$E2" -eq 1 ]; then
  has "$K_GIT_WRITE" && add git-write
elif [ "$E1" -eq 0 ]; then
  DB=0
  has "$DB_CLI" && DB=1
  if [ "$DB" -eq 1 ]; then
    has "$K_DATA_DELETE_SQL" && add data-delete:cli
    has "$K_DATA_WRITE_SQL" && add data-write:cli
    has "$K_CONTRACT_SQL" && add schema-contract:cli
    has "$K_MIGRATE_SQL" && add schema-migrate:cli
    has "$SQL_FILE" && add data-delete:cli
    has '(^|[^a-z_-])pg_restore([[:space:]"]|$)' && add data-write:cli
  fi
  has "$K_MIG_UP" && add schema-migrate:tool
  has "$K_MIG_DOWN" && add schema-contract:tool
  has "$K_DATA_WRITE_TOOL" && add data-write:tool
  has "$K_DATA_DELETE_TOOL" && add data-delete:tool
  has "$K_CONTRACT_TOOL" && add schema-contract:tool
  has "$K_INFRA_DESTROY" && add infra-destroy:tool
  has "$K_INFRA_APPLY" && add infra-apply:tool
  if has "$K_INFRA_PLAN"; then
    add infra-apply:tool
    PLAN_FORM=1
  fi
  if [ -z "$HITS" ] && ! has "$K_CRED"; then
    has "$K_CLOUD_DESTROY" && add infra-destroy:tool
    has "$K_CLOUD_APPLY" && add infra-apply:tool
  fi
  has "$K_UPGRADE" && add version
  has "$K_PUBLISH" && add publish
  has "$K_CRED" && add credential
  has "$K_RESET_HARD" && add fixed
  has "$K_CLEAN_F" && add fixed
  has "$K_RM_BROAD" && add fixed
  has "$K_PIPE_SH" && add fixed
  has "$K_CHMOD" && add fixed
  has "$K_SUDO" && add fixed
  if has "$K_FORCE_PUSH"; then add force-push; fi
  if { has "$K_GIT_WRITE" && ! has "$K_GIT_READONLY_SUB"; } ; then add git-write; fi
  if [ -z "$HITS" ] && has "$K_TARGET_READ"; then
    if is_simple "$CMD" && has "$READ_LOCAL"; then :; else READ=1; fi
  fi
else
  # E1: only the git rows below can still classify (none of them apply to a read-only carrier)
  :
fi

# --- policy, class ------------------------------------------------------------------
ensure_h9
classify_env
RULE='plugin default'

# policy matching for forbid and reserve (strict mode keeps both)
# pol_match <record kind> : sets RULE and succeeds when a FORBID or RESERVE record matches a hit
pol_match() {
  GB_K=$1
  GB_ROWS=$(printf '%s\n' "$POLREC" | grep "^$GB_K ")
  [ -n "$GB_ROWS" ] || return 1
  GB_CLS=$CLASS
  printf '%s\n' "$GB_ROWS" | while IFS=' ' read -r GB_W GB_ACT GB_SCOPE GB_LN; do
    case $GB_ACT in
      cmd=*) if printf '%s' "$CMD" | grep -Fiq -e "${GB_ACT#cmd=}"; then echo "$GB_LN"; break; fi ;;
      *)
        if has_key "$GB_ACT"; then
          GB_OK=0
          if [ "$GB_SCOPE" = any ]; then GB_OK=1; else
            case ",$GB_SCOPE," in
              *",$GB_CLS,"*) GB_OK=1 ;;
              *) case $GB_CLS in unknown) case ",$GB_SCOPE," in *",production,"*) GB_OK=1 ;; esac ;; esac ;;
            esac
          fi
          if [ "$GB_OK" -eq 1 ]; then echo "$GB_LN"; break; fi
        fi ;;
    esac
  done
}

# no pattern hit: only a project "cmd=" line can still match (pol_match is defined above)
[ -n "$HITS" ] || [ "$READ" -eq 1 ] || cmd_only_check

# dry-run memory helpers (fixed path)
MEM=/tmp/developer-set-guard-dry-runs
norm_key() {
  printf '%s' "$CMD" |
    tr 'A-Z' 'a-z' |
    sed -E 's/--(dry-?run|dry|check|noop|what-if|simulate|plan-only|diff-only|server-dry-run)(=[^[:space:]]*)?//g; s/-dryrunoutput(=[^[:space:]]*)?//g; s/(^|[^a-z])(begin|rollback|commit)([^a-z]|$)/ /g' |
    tr -cd 'a-z0-9' |
    cksum | cut -d ' ' -f 1
}
recorded() { [ -f "$MEM" ] && grep -Fxq "${SESSION:-nosession} $(norm_key)" "$MEM"; }

# --- dry-run / plan form (3.2) ---------------------------------------------------------
sql_dry_run() {
  GB_N=$(printf '%s' "$CMD" | grep -Eio "$SQL_FLAG" | wc -l | tr -d ' ')
  [ "$GB_N" -eq 1 ] || return 1
  has "$SQL_FILE" && return 1
  GB_P=$(printf '%s' "$CMD" | sed -nE "s/.*[[:space:]](-c|--command|-e|--eval)[[:space:]=]*[\"']([^\"']*)[\"'].*/\2/p")
  [ -n "$GB_P" ] || return 1
  printf '%s' "$GB_P" | grep -Eiq '^[[:space:]]*(begin|start[[:space:]]+transaction)([[:space:];]|$)' || return 1
  printf '%s' "$GB_P" | grep -Eiq ';[[:space:]]*rollback[[:space:]]*;?[[:space:]]*$' || return 1
  [ "$(printf '%s' "$GB_P" | grep -Eio '(^|[^a-z_])(begin|start[[:space:]]+transaction)([^a-z_]|$)' | wc -l | tr -d ' ')" -eq 1 ] || return 1
  [ "$(printf '%s' "$GB_P" | grep -Eio '(^|[^a-z_])rollback([^a-z_]|$)' | wc -l | tr -d ' ')" -eq 1 ] || return 1
  printf '%s' "$GB_P" | grep -Eiq -- '--|/\*|#|(^|[^a-z_])(commit|end|abort)([^a-z_]|$)' && return 1
  return 0
}

IS_DRY=0
if is_simple "$CMD"; then
  if has "$DB_CLI"; then
    sql_dry_run && IS_DRY=1
  else
    GB_NQ=$(printf '%s' "$CMD" | sed -E "s/\"[^\"]*\"/ /g; s/'[^']*'/ /g; s/(^|[[:space:]])#.*\$//")
    printf '%s' "$GB_NQ" | grep -Eiq -- "$DRY_RE" && IS_DRY=1
    has "${GIT_PFX}clean[[:space:]]+-[a-zA-Z]*n" && IS_DRY=1
  fi
  [ "$PLAN_FORM" -eq 1 ] && IS_DRY=1
fi

ENV_SCOPED_HIT=0
for GB_K in $ENVKEYS; do has_key "$GB_K" && ENV_SCOPED_HIT=1; done

# row 2
if [ "$IS_DRY" -eq 1 ]; then
  GB_OK=0
  case $CLASS in dev|staging) GB_OK=1 ;; esac
  if [ "$GB_OK" -eq 0 ] && [ "$ENV_SCOPED_HIT" -eq 0 ] && [ "$PRODMARK" -eq 0 ]; then GB_OK=1; fi
  if [ "$GB_OK" -eq 1 ]; then
    GB_REC=0
    for GB_K in data-write data-delete schema-migrate schema-contract; do has_key "$GB_K" && GB_REC=1; done
    if [ "$GB_REC" -eq 1 ]; then
      umask 077
      echo "${SESSION:-nosession} $(norm_key)" >>"$MEM"
    fi
    exit 0
  fi
fi

# row 3
if has_key force-push; then
  ENVLBL=na
  deny T3-FORCE-PUSH T3 'force push (rewrites remote history)' 'Push without force, or propose the force push as a GIT item for the Commander.' "$T3_HINT $ESC_HINT"
fi
GB_FB=$(pol_match FORBID)
if [ -n "$GB_FB" ]; then
  RULE="policy line $GB_FB"; ENVLBL=
  deny T3-FORBID T3 'an action the project policy forbids' 'None inside the loop. Report the need under Open questions.' "$T3_HINT $ESC_HINT"
fi

# row 4
case $CLASS in production|unknown) GB_P4=1 ;; *) GB_P4=0 ;; esac
if [ "$GB_P4" -eq 1 ]; then
  ENVLBL=$CLASS
  for GB_K in $ENVKEYS; do
    if has_key "$GB_K"; then
      key_text "$GB_K"
      deny T2-PROD T2 "$KWHAT" "$KALT" "$PROD_HINT $ESC_HINT"
    fi
  done
  if [ "$READ" -eq 1 ]; then
    deny T2-PROD T2 'target-read (read-only query against production or an environment the command does not identify: database client, dump, kubectl, helm, cloud CLI or infrastructure state read)' 'The Commander runs reads against production or an environment the command does not identify. Put the exact read command and the result you need into your report as a Parked action block (Dry-run result: No dry-run form: read-only query; Rollback: Not needed: read-only; Who may run: Commander); do not read it another way.' "$READ_HINT $ESC_HINT"
  fi
fi
if [ "$PRODMARK" -eq 1 ] && has_key version; then
  ENVLBL=production
  key_text version
  deny T2-PROD T2 "$KWHAT" "$KALT" "$PROD_HINT $ESC_HINT"
fi
ENVLBL=
if [ "$READ" -eq 1 ]; then
  GB_RS=$(pol_match RESERVE)
  if [ -n "$GB_RS" ]; then
    RULE="policy line $GB_RS"; ENVLBL=$CLASS
    deny T2-RESERVED T2 "target-read (reserved for the Commander by $RULE)" 'The Commander runs this read. Put the exact read command and the result you need into your report as a Parked action block.' "$ESC_HINT"
  fi
  exit 0
fi

# row 5
if has_key fixed; then
  ENVLBL=na
  deny T2-RESERVED T2 'reserved for the Commander by plugin default (rm of a broad path, pipe to a shell, world-writable chmod, sudo, git reset --hard or git clean -f)' 'Delete a specific path, use the narrowest permission, keep your changes for a commit proposal. Do not run downloaded or generated scripts; put the URL or file in a Parked action block.' "$ESC_HINT"
fi
for GB_K in publish credential; do
  if has_key "$GB_K"; then
    ENVLBL=na; key_text "$GB_K"
    deny T2-RESERVED T2 "$KWHAT" "$KALT" "$ESC_HINT"
  fi
done
if has_key git-write; then
  ENVLBL=na
  deny T2-GIT T2 'git write (commander-only; commit-after-approval is not implemented in this release)' 'Propose the exact commands as a GIT item in your report; do not run them.' "$ESC_HINT"
fi
GB_RS=$(pol_match RESERVE)
if [ -n "$GB_RS" ]; then
  RULE="policy line $GB_RS"
  GB_FIRST=
  for GB_K in $ORDER; do has_key "$GB_K" && { GB_FIRST=$GB_K; break; }; done
  key_text "${GB_FIRST:-x}"
  deny T2-RESERVED T2 "${GB_FIRST:-action} (reserved for the Commander by $RULE)" "$KALT" "$ESC_HINT"
fi
# env-scoped hits in dev or staging must be on a list for the class
for GB_K in $ENVKEYS; do
  has_key "$GB_K" || continue
  GB_LISTED=0
  case $GB_K in data-write|data-delete|schema-migrate) [ "$CLASS" = dev ] && wa_ok "$GB_K" && GB_LISTED=1 ;; esac
  [ "$GB_LISTED" -eq 0 ] && aa_ok "$GB_K" "$CLASS" && GB_LISTED=1
  if [ "$GB_LISTED" -eq 0 ]; then
    ENVLBL=$CLASS; key_text "$GB_K"
    deny T2-RESERVED T2 "$GB_K (reserved for the Commander by plugin default or the policy: not on the allow-list for this environment)" "$KALT" "$ESC_HINT"
  fi
done
if has_key version && ! aa_any_version; then
  ENVLBL=na; key_text version
  deny T2-RESERVED T2 'version upgrade (reserved for the Commander: no version key is on the allow-list)' "$KALT" "$ESC_HINT"
fi

# row 6: data rules need a recorded dry run (tool hits skip it under the dev-only level)
for GB_K in data-write data-delete schema-migrate schema-contract; do
  has_key "$GB_K" || continue
  GB_NEED=1
  if ! has_cli "$GB_K" && [ "$CLASS" = dev ]; then
    case $GB_K in data-write|data-delete|schema-migrate) wa_ok "$GB_K" && GB_NEED=0 ;; esac
  fi
  if [ "$GB_NEED" -eq 1 ] && ! recorded; then
    ENVLBL=$CLASS
    if has_cli "$GB_K"; then GB_H=$DRY_CLI_HINT; else GB_H=$DRY_TOOL_HINT; fi
    deny T2-DRYRUN-FIRST T2 "$GB_K (data change without a recorded dry run in this session)" 'Run the dry-run form first, keep the raw output, then try the real command once.' "$GB_H"
  fi
done

# rows 7 and 8: dev-only pass, then after-approval
GB_ASK=
for GB_K in $ENVKEYS; do
  has_key "$GB_K" || continue
  GB_PASS=0
  case $GB_K in data-write|data-delete|schema-migrate) [ "$CLASS" = dev ] && wa_ok "$GB_K" && GB_PASS=1 ;; esac
  [ "$GB_PASS" -eq 1 ] && continue
  [ -z "$GB_ASK" ] && GB_ASK=$GB_K
done
if [ -z "$GB_ASK" ] && has_key version; then GB_ASK=version; fi
if [ -n "$GB_ASK" ]; then
  if [ "$GB_ASK" = version ]; then ENVLBL=na; else ENVLBL=$CLASS; fi
  if [ "$MODE" = unattended ]; then
    key_text "$GB_ASK"
    deny T2-PARK T2 "$GB_ASK (allowed after approval, and nobody can approve in unattended mode)" "$KALT" "$PARK_HINT $ESC_HINT"
  fi
  ask "$GB_ASK (allowed after approval)"
fi

exit 0
