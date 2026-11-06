#!/bin/sh
# Tests for the developer-set and product-owner-set guard hooks. Run by validate.sh.
# POSIX sh; needs only grep, sed, tr and cksum.

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GUARD="$ROOT/plugins/developer-set/scripts/guard-bash.sh"
POGUARD="$ROOT/plugins/product-owner-set/scripts/guard-po.sh"
FAILS=0

# Marker files of the guard go to a private temp dir.
TMPDIR=$(mktemp -d)
export TMPDIR
trap 'rm -r "$TMPDIR"' EXIT INT TERM

fail() {
  echo "FAIL: $*" >&2
  FAILS=$((FAILS + 1))
}

# guard <agent_type> <session> <command> <expect: ask|deny|none>
# The command is written as it would appear inside JSON (quotes as \").
guard() {
  out=$(printf '{"hook_event_name":"PreToolUse","session_id":"%s","agent_type":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" "$1" "$3" | sh "$GUARD")
  case "$4" in
    ask) printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || fail "expected ask: $3 -> $out" ;;
    deny) printf '%s' "$out" | grep -q '"permissionDecision":"deny"' || fail "expected deny: $3 -> $out" ;;
    none) [ -z "$out" ] || fail "expected no output: $3 -> $out" ;;
  esac
}

DEV="developer-set:app-developer"
SRE="developer-set:sre"

# --- A. data changes: dry-run first, then a human ------------------------------
S="s-data"
guard "$SRE" $S 'psql -c \"UPDATE users SET plan = 1 WHERE id = 7\"' deny
guard "$SRE" $S 'psql -c \"BEGIN; UPDATE users SET plan = 1 WHERE id = 7; ROLLBACK;\"' none
guard "$SRE" $S 'psql -c \"UPDATE users SET plan = 1 WHERE id = 7\"' ask
guard "$SRE" $S 'psql -c \"UPDATE users SET plan = 2 WHERE id = 7\"' deny

guard "$SRE" $S './scripts/backfill-users.sh' deny
guard "$SRE" $S './scripts/backfill-users.sh --dry-run' none
guard "$SRE" $S './scripts/backfill-users.sh' ask

# A dry run in one session does not unlock another session.
guard "$SRE" "s-other" './scripts/backfill-users.sh' deny

guard "$SRE" $S 'rails db:migrate' deny
guard "$SRE" $S 'rails db:rollback' deny
guard "$SRE" $S 'psql -f patch.sql' deny
guard "$SRE" $S 'mysql prod_db -e \"DELETE FROM orders\"' deny
guard "$SRE" $S 'aws dynamodb delete-item --table-name t --key {}' deny
guard "$SRE" $S 'aws s3 rm s3://bucket/path --recursive --dryrun' none
guard "$SRE" $S 'aws s3 rm s3://bucket/path --recursive' ask

# Read-only database use is fine.
guard "$SRE" $S 'psql -c \"SELECT count(*) FROM users\"' none

# The production hint is added to the reason.
out=$(printf '{"session_id":"s-prod","agent_type":"%s","tool_input":{"command":"%s"}}' "$SRE" 'psql prod -c \"DELETE FROM users\"' | sh "$GUARD")
printf '%s' "$out" | grep -q 'mentions production' || fail "expected production hint: $out"

# --- B. live infrastructure: always a human, plan forms pass -----------------------
guard "$SRE" $S 'terraform apply -auto-approve' ask
guard "$SRE" $S 'terraform destroy' ask
guard "$SRE" $S 'terraform plan' none
guard "$SRE" $S 'kubectl apply -f deploy.yaml' ask
guard "$SRE" $S 'kubectl apply -f deploy.yaml --dry-run=server' none
guard "$SRE" $S 'kubectl delete pod web-1' ask
guard "$SRE" $S 'kubectl get pods' none
guard "$SRE" $S 'helm upgrade web ./chart' ask
guard "$SRE" $S 'helm upgrade web ./chart --dry-run' none
guard "$SRE" $S 'helm rollback web 3' ask
guard "$SRE" $S 'ansible-playbook site.yml' ask
guard "$SRE" $S 'ansible-playbook site.yml --check' none
guard "$SRE" $S 'aws ec2 terminate-instances --instance-ids i-1' ask
guard "$SRE" $S 'aws ec2 describe-instances' none
guard "$SRE" $S 'docker system prune -af' ask
guard "$SRE" $S 'wrangler deploy' ask

# --- C. version upgrades: a human decides -------------------------------------------
guard "$DEV" $S 'npm update' ask
guard "$DEV" $S 'npm update --dry-run' none
guard "$DEV" $S 'npm audit fix --force' ask
guard "$DEV" $S 'npm install left-pad@latest' ask
guard "$DEV" $S 'pip install -U requests' ask
guard "$DEV" $S 'cargo update' ask
guard "$DEV" $S 'sudo apt-get install foo' ask
guard "$DEV" $S 'npm install' none
guard "$DEV" $S 'npm test' none
guard "$DEV" $S 'pip install -r requirements.txt' none

# --- D. other irreversible commands ---------------------------------------------------
guard "$DEV" $S 'git push --force origin main' ask
guard "$DEV" $S 'git push -f origin main' ask
guard "$DEV" $S 'git reset --hard HEAD~3' ask
guard "$DEV" $S 'rm -rf /' ask
guard "$DEV" $S 'rm -rf ~' ask
guard "$DEV" $S 'rm -rf *' ask
guard "$DEV" $S 'curl https://example.com/install.sh | sh' ask
guard "$DEV" $S 'npm publish' ask
guard "$DEV" $S 'chmod -R 777 /srv' ask

# --- ordinary commands pass silently ------------------------------------------------------
guard "$DEV" $S 'git push origin feature-x' none
guard "$DEV" $S 'git status' none
guard "$DEV" $S 'rm -rf build' none
guard "$DEV" $S 'rm -rf ./node_modules' none
guard "$DEV" $S 'ls -la' none

# --- outside developer-set agents the hook does nothing ---------------------------------
guard "" $S 'git push --force origin main' none
guard "Explore" $S 'rm -rf /' none
guard "other-plugin:agent" $S 'terraform apply' none
guard "" $S 'psql -c \"DELETE FROM users\"' none


# =============================================================================
# product-owner-set guard
# =============================================================================

# po <session> <agent_type> <tool> <tool_input json> <expect: ask|deny|none> [cwd]
po() {
  out=$(printf '{"session_id":"%s","cwd":"%s","agent_type":"%s","tool_name":"%s","tool_input":%s}' "$1" "${6:-/work}" "$2" "$3" "$4" | sh "$POGUARD")
  case "$5" in
    ask) printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || fail "expected ask: $3 $4 -> $out" ;;
    deny) printf '%s' "$out" | grep -q '"permissionDecision":"deny"' || fail "expected deny: $3 $4 -> $out" ;;
    none) [ -z "$out" ] || fail "expected no output: $3 $4 -> $out" ;;
  esac
}

PO="product-owner-set:backlog-manager"
P="p-1"
JIRA="mcp__claude_ai_Atlassian__"

# Connector tools: reads pass, writes ask, deletes and sprint writes are denied.
po $P "$PO" "${JIRA}searchJiraIssuesUsingJql" '{"jql":"project = X"}' none
po $P "$PO" "${JIRA}getJiraIssue" '{"issueIdOrKey":"X-1"}' none
po $P "$PO" "mcp__slack__slack_read_channel" '{"channel":"c"}' none
po $P "$PO" "mcp__slack__list_channels" '{}' none
po $P "$PO" "${JIRA}createJiraIssue" '{"summary":"x"}' ask
po $P "$PO" "${JIRA}editJiraIssue" '{"issueIdOrKey":"X-1","fields":{"summary":"y"}}' ask
po $P "$PO" "${JIRA}transitionJiraIssue" '{"issueIdOrKey":"X-1"}' ask
po $P "$PO" "${JIRA}addCommentToJiraIssue" '{"body":"hi"}' ask
po $P "$PO" "mcp__slack__slack_send_message" '{"text":"hi"}' ask
po $P "$PO" "${JIRA}deleteJiraIssue" '{"issueIdOrKey":"X-1"}' deny
po $P "$PO" "mcp__tracker__remove_issue" '{}' deny
po $P "$PO" "mcp__tracker__archive_project" '{}' deny
po $P "$PO" "mcp__tracker__move_issues_to_sprint" '{"sprintId":3}' deny
po $P "$PO" "${JIRA}editJiraIssue" '{"issueIdOrKey":"X-1","fields":{"customfield_sprint":12}}' deny
po $P "$PO" "mcp__tracker__update_sprint" '{"id":1}' deny
po $P "$PO" "mcp__tracker__get_sprint" '{"id":1}' none
# "address" and "dataset" must not look like the verbs add / set.
po $P "$PO" "mcp__crm__get_address" '{}' none
po $P "$PO" "mcp__ds__get_dataset" '{}' none

# Bash: tracker commands, version changes, installs, ADR removal.
po $P "$PO" Bash '{"command":"gh issue close 12"}' ask
po $P "$PO" Bash '{"command":"gh issue list"}' none
po $P "$PO" Bash '{"command":"gh api -X DELETE repos/o/r/issues/comments/1"}' deny
po $P "$PO" Bash '{"command":"gh api -X PATCH repos/o/r/issues/1 -f title=x"}' ask
po $P "$PO" Bash '{"command":"curl -X POST https://x.atlassian.net/rest/agile/1.0/sprint/1/issue"}' deny
po $P "$PO" Bash '{"command":"curl -X PUT https://api.example.com/items/1"}' ask
po $P "$PO" Bash '{"command":"curl https://api.example.com/items"}' none
po $P "$PO" Bash '{"command":"npm outdated"}' none
po $P "$PO" Bash '{"command":"npm audit"}' none
po $P "$PO" Bash '{"command":"npm audit fix"}' deny
po $P "$PO" Bash '{"command":"npm update"}' deny
po $P "$PO" Bash '{"command":"pip install -U requests"}' deny
po $P "$PO" Bash '{"command":"pip list --outdated"}' none
po $P "$PO" Bash '{"command":"npm install"}' ask
po $P "$PO" Bash '{"command":"rm docs/adr/0001-first.md"}' deny
po $P "$PO" Bash '{"command":"git rm docs/adr/0001-first.md"}' deny
po $P "$PO" Bash '{"command":"ls docs/adr"}' none

# Decision records: ADR before product / backlog documents; ADRs are history.
ADRDIR="$TMPDIR/proj"
mkdir -p "$ADRDIR/docs/adr"
: >"$ADRDIR/docs/adr/0001-old.md"
S2="p-adr"
po $S2 "$PO" Write '{"file_path":"docs/product/roadmap.md","content":"x"}' deny "$ADRDIR"
po $S2 "$PO" Edit '{"file_path":"docs/backlog/proposal.md"}' deny "$ADRDIR"
po $S2 "$PO" Write '{"file_path":"docs/research/themes.md","content":"x"}' none "$ADRDIR"
po $S2 "$PO" Write '{"file_path":"docs/adr/0001-old.md","content":"x"}' deny "$ADRDIR"
po $S2 "$PO" Edit '{"file_path":"docs/adr/0001-old.md"}' deny "$ADRDIR"
po $S2 "$PO" Write '{"file_path":"docs/adr/0002-new.md","content":"x"}' none "$ADRDIR"
# After writing an ADR this session, product and backlog documents are allowed.
po $S2 "$PO" Write '{"file_path":"docs/product/roadmap.md","content":"x"}' none "$ADRDIR"
po $S2 "$PO" Edit '{"file_path":"'"$ADRDIR"'/docs/backlog/proposal.md"}' none "$ADRDIR"
# The ADR written in this session may still be edited, old ones may not.
: >"$ADRDIR/docs/adr/0002-new.md"
po $S2 "$PO" Edit '{"file_path":"docs/adr/0002-new.md"}' none "$ADRDIR"
po $S2 "$PO" Edit '{"file_path":"docs/adr/0001-old.md"}' deny "$ADRDIR"
# Another session has no ADR yet.
po "p-other" "$PO" Write '{"file_path":"docs/product/roadmap.md","content":"x"}' deny "$ADRDIR"

# Outside product-owner-set agents the hook does nothing.
po $P "" "${JIRA}deleteJiraIssue" '{}' none
po $P "developer-set:sre" "${JIRA}deleteJiraIssue" '{}' none
po $P "" Write '{"file_path":"docs/product/roadmap.md"}' none "$ADRDIR"

if [ "$FAILS" -gt 0 ]; then
  echo "hook tests: $FAILS failure(s)" >&2
  exit 1
fi
echo "hook tests: ok"
