#!/bin/sh
# Tests for the loop-state helper (plugins/su3-developer-set-with-guards/skills/project-implementation/loop-state.sh).
# Run by validate.sh. POSIX sh. Builds fixture unit directories from the examples of
# 20_formats_spec.md under a private temp directory; touches no repository file and runs no git.

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HELPER="$ROOT/plugins/su3-developer-set-with-guards/skills/project-implementation/loop-state.sh"
FAILS=0
TMPD=$(mktemp -d)
trap 'rm -r "$TMPD"' EXIT INT TERM
fail() { printf 'FAIL: %s\n' "$*" >&2; FAILS=$((FAILS + 1)); }

[ -f "$HELPER" ] || { echo "loop-state tests: helper not found"; exit 1; }

WORK="$TMPD/repo"
UNIT=docs/2026-11-12_001_fix_login_typo
OUT="$TMPD/out"          # outside the repository: saved reports and copies
mkdir -p "$WORK/$UNIT" "$OUT"
cd "$WORK" || exit 1

# ---- fixture: small-fix route, before step 3 ------------------------------------------------
write00() {
  cat >"$UNIT/00_request.md" <<'EOF'
# 00 Request: Fix the login typo

- Ticket: PROJ-12
- Unit: Ticket
- Created: 2026-11-12 09:10
- Created by: main session

## AsIs

The login page says "Pasword".

## ToBe

The login page says "Password".

## SoThat

Users are not confused.

## Acceptance Criteria

- AC-1: The label reads "Password".
- AC-2: No other text changes.

## References

None

## UI Design

None

## Source

### Prompt

~~~~text
Do my ticket PROJ-12.
## Not a heading
~~~~

### Snapshot

- Captured: 2026-11-12 09:10
- From: pasted in chat

~~~~text
PROJ-12 Fix typo
~~~~
EOF
}

# write01 <status> <retries> <last update event> <result3> <result4> <used>
write01() {
  cat >"$UNIT/01_project_plan.md" <<EOF
# 01 Project plan: Fix the login typo

- Directory: docs/2026-11-12_001_fix_login_typo/
- Request: 00_request.md
- Mode: unattended
- Policy: None (plugin defaults)

## Status

| Ticket | Status | Retries | Riskiest tier | Last update |
|---|---|---|---|---|
| PROJ-12 | $1 | $2 | T1 | 2026-11-12 09:30 $3 |

## Route

- Route: small-fix
- Reason: one label change.

| # | Ticket | Agent | Kind | Input files | Output file | Acceptance criterion | Tier | Sends back to | Result |
|---|---|---|---|---|---|---|---|---|---|
| 1 | PROJ-12 | project-manager | plan | 00_request.md | 01_project_plan.md | Route written | T0 | - | DONE |
| 2 | PROJ-12 | qa | criteria | 00_request.md, 01_project_plan.md | 01_project_plan.md | Every AC has a QC item | T0 | - | DONE |
| 3 | PROJ-12 | app-developer | author | 00_request.md, 01_project_plan.md | 03_development_output.md | Label fixed, gate output quoted | T1 | - | $4 |
| 4 | PROJ-12 | qc | verify | 01_project_plan.md, 03_development_output.md | 04_quality_report.md | All QC items PASS | T0 | 3 | $5 |
| 5 | PROJ-12 | project-manager | report | 01 to 04, 06 | 05_completion_report.md | 05 written | T0 | - | - |

## Budget

- Retry cap: 2
- Overrun: 150%
- Denial cap: 2
- Estimate: 6 agent calls
- Stop at: 9 agent calls
- Used: $6 agent calls

## Skipped

- 02_system_design.md: skipped: small fix, no design impact

## Quality criteria

### qa

- QC-1 (AC-1): label reads Password | check: grep -rn Password src/login
- QC-2 (AC-2): only the label changed | check: git diff --stat

STATUS: DONE
EOF
}

write06() {
  cat >"$UNIT/06_commander_actions.md" <<'EOF'
# 06 Commander actions: Fix the login typo

- Directory: docs/2026-11-12_001_fix_login_typo/
- Ticket: PROJ-12
- Note: commands, dry-run results and rollbacks below are agent-proposed; review them before running.

## Items

### A-001: Commit the change

- Status: OPEN
- Kind: GIT
- Tier: T2
- Tier reason: git writes are the Commander's
- Blocks: None
- Raised by: project-manager, from its report step 5
- Raised at: 2026-11-12 11:30
- Who may run: Commander
- Denied by guard: no
- Review flags: None
- Why: the loop never runs git writes.

Command:

```sh
git add src/login
git commit -m "Fix login typo (PROJ-12)"
```

Dry-run result:

```text
None
```

Rollback:

```sh
git revert <commit>
```

- Decision:
EOF
}

write03() {
  cat >"$UNIT/03_development_output.md" <<'EOF'
# 03 Development output: Fix the login typo

- Directory: docs/2026-11-12_001_fix_login_typo/
- Ticket: PROJ-12

## app-developer (attempt 1)

### Summary

Fixed the label.

### Done

- src/login/label.ts:3: label fixed.

### Gate output

```text
$ npm test
Tests: 5 passed, 5 total
```

### Hand-over

- Design mismatch: None
- Parked actions: None

### Decisions

- None

### Open questions

- None

### Next

- qc: verify QC-1 and QC-2.

STATUS: DONE
EOF
}

# run the helper; prints the whole output, sets RC
run() { OUTP=$(sh "$HELPER" "$@" 2>&1); RC=$?; }
verdict() { printf '%s\n' "$OUTP" | sed -n '$p'; }
expect() { # <label> <expected verdict line prefix>
  v=$(verdict)
  case "$v" in
    "$2"*) ;;
    *) fail "$1: expected '$2', got '$v' (rc=$RC)"; printf '%s\n' "$OUTP" | sed 's/^/    /' >&2 ;;
  esac
}

# ---- check-format -------------------------------------------------------------------------------
write00; write01 IN_PROGRESS 0 "step 2 DONE" - - 2; write06
run check-format "$UNIT"
expect "check-format on the valid fixture" "VERDICT: CONTINUE reason=format-ok"
[ "$RC" -eq 0 ] || fail "check-format valid: rc $RC"

# seeded-invalid copies: each must fail with a FORMAT line
seed() { # <label> <file> <sed script>
  cp "$UNIT/$2" "$OUT/save.md"
  sed -e "$3" "$OUT/save.md" >"$UNIT/$2"
  run check-format "$UNIT"
  case $(verdict) in "VERDICT: STOP reason=format-invalid"*) ;; *) fail "seeded invalid '$1' was accepted: $(verdict)" ;; esac
  [ "$RC" -eq 1 ] || fail "seeded invalid '$1': rc $RC"
  cp "$OUT/save.md" "$UNIT/$2"
}
seed "no acceptance criteria" 00_request.md 's/^- AC-[0-9]*:/- NOAC:/'
seed "heading order" 00_request.md 's/^## SoThat/## Why/'
seed "bad status value" 01_project_plan.md 's/| IN_PROGRESS |/| RUNNING |/'
seed "T2 step for an agent" 01_project_plan.md 's/| T1 | - | - |/| T2 | - | - |/'
seed "stop at arithmetic" 01_project_plan.md 's/^- Stop at: 9/- Stop at: 8/'
seed "missing qc coverage" 01_project_plan.md 's/^- QC-2 (AC-2)/- QC-2 (AC-9)/'
seed "item id not ascending" 06_commander_actions.md 's/^### A-001:/### A-000:/'
seed "missing field" 06_commander_actions.md '/^- Review flags:/d'
run check-format "$UNIT"
expect "fixture restored" "VERDICT: CONTINUE reason=format-ok"
# a snapshot with headings and a fence is not parsed as sections (fence-aware)
grep -q '## Not a heading' "$UNIT/00_request.md" || fail "fixture lost its fenced heading"

# ---- next: before a dispatch ------------------------------------------------------------------------
run next "$UNIT"
expect "next before step 3" "VERDICT: CONTINUE reason=next-step step=3 agent=app-developer attempt=1"
[ "$RC" -eq 0 ] || fail "next rc $RC"

# --save-before: copies 01 only on CONTINUE, only to an absolute path outside the repository
rm -f "$OUT/before.md"
run next "$UNIT" --save-before "$OUT/before.md"
expect "save-before" "VERDICT: CONTINUE"
cmp -s "$UNIT/01_project_plan.md" "$OUT/before.md" || fail "save-before: copy differs from 01"
run next "$UNIT" --save-before relative.md;  [ "$RC" -eq 2 ] && [ ! -e relative.md ] || fail "save-before relative path: rc $RC"
run next "$UNIT" --save-before "$WORK/inside.md"; [ "$RC" -eq 2 ] && [ ! -e "$WORK/inside.md" ] || fail "save-before inside repository: rc $RC"

# ---- budget, denial cap, parked ---------------------------------------------------------------------------
write01 IN_PROGRESS 0 "step 2 DONE" - - 9
run next "$UNIT";  expect "budget" "VERDICT: STOP reason=budget"
write01 PARKED 0 "parked: A-001" - - 2
run next "$UNIT";  expect "parked" "VERDICT: PARK"
write01 BLOCKED 0 "blocked by: PROJ-1" - - 2
run next "$UNIT";  expect "dependency" "VERDICT: PARK reason=dependency"
write01 IN_PROGRESS 0 "step 2 DONE" - - 2
# two items denied by the guard for step 3 reach the denial cap
cat >>"$UNIT/06_commander_actions.md" <<'EOF'

### A-002: Denied one

- Status: OPEN
- Kind: T2_ACTION
- Tier: T2
- Tier reason: reserved
- Blocks: 3
- Raised by: app-developer, from report of step 3 (attempt 1)
- Raised at: 2026-11-12 11:40
- Who may run: Commander
- Denied by guard: yes
- Review flags: None
- Why: x

Command:

```sh
terraform apply
```

Dry-run result:

```text
None
```

Rollback:

```sh
None
```

- Decision:

### A-003: Denied two

- Status: OPEN
- Kind: T2_ACTION
- Tier: T2
- Tier reason: reserved
- Blocks: 3
- Raised by: app-developer, from report of step 3 (attempt 2)
- Raised at: 2026-11-12 11:50
- Who may run: Commander
- Denied by guard: yes
- Review flags: None
- Why: x

Command:

```sh
terraform apply
```

Dry-run result:

```text
None
```

Rollback:

```sh
None
```

- Decision:
EOF
run next "$UNIT";  expect "denial cap" "VERDICT: STOP reason=denial-cap step=3"
write06

# ---- next: after a dispatch (--report) -----------------------------------------------------------------------------
write01 IN_PROGRESS 0 "step 2 DONE" - - 3
sh "$HELPER" next "$UNIT" --save-before "$OUT/before.md" >/dev/null 2>&1
# the agent did its work: 03 section, row 3 DONE, status VERIFY
write03
write01 VERIFY 0 "step 3 DONE" DONE - 3
printf 'Fixed the label.\n\nSTATUS: DONE\n' >"$OUT/report.txt"
run next "$UNIT" --step 3 --report "$OUT/report.txt" --before "$OUT/before.md"
expect "after step 3 DONE" "VERDICT: CONTINUE reason=next-step step=4 agent=qc attempt=1"

# STATUS normalization: decorated or wrong-role lines are invalid, plain variants are accepted
for body in '**STATUS: DONE**' '`STATUS: DONE`' 'STATUS: DONE.' 'STATUS: DONE and more' 'STATUS: PASS' 'STATUS: ok'; do
  printf 'done\n\n%s\n' "$body" >"$OUT/report.txt"
  run next "$UNIT" --step 3 --report "$OUT/report.txt"
  expect "invalid status '$body'" "VERDICT: STOP reason=invalid-status"
done
printf 'done\n' >"$OUT/report.txt"
run next "$UNIT" --step 3 --report "$OUT/report.txt"; expect "no status line" "VERDICT: STOP reason=invalid-status"
printf 'done\n\nstatus: done\n' >"$OUT/report.txt"
run next "$UNIT" --step 3 --report "$OUT/report.txt"; expect "lower-case status" "VERDICT: CONTINUE"
printf 'done\n\nSTATUS: DONE   \n\n' >"$OUT/report.txt"
run next "$UNIT" --step 3 --report "$OUT/report.txt"; expect "trailing spaces and blank lines" "VERDICT: CONTINUE"
# the report text never reaches a command line or the shell
printf '$(touch %s/marker); `touch %s/marker2`\n\nSTATUS: DONE\n' "$OUT" "$OUT" >"$OUT/report.txt"
run next "$UNIT" --step 3 --report "$OUT/report.txt"; expect "injection text in a report" "VERDICT: CONTINUE"
[ ! -e "$OUT/marker" ] && [ ! -e "$OUT/marker2" ] || fail "injection text was executed"

# an agent that did not update its row: conflicting artifacts
write01 IN_PROGRESS 0 "step 2 DONE" - - 3
printf 'done\n\nSTATUS: DONE\n' >"$OUT/report.txt"
run next "$UNIT" --step 3 --report "$OUT/report.txt" --before "$OUT/before.md"
expect "row not updated" "VERDICT: STOP reason=conflicting-artifacts"
# a changed line outside the step row and the status row
write01 VERIFY 0 "step 3 DONE" DONE - 3
sed 's/^- Retry cap: 2/- Retry cap: 1/' "$UNIT/01_project_plan.md" >"$OUT/x.md" && cp "$OUT/x.md" "$UNIT/01_project_plan.md"
run next "$UNIT" --step 3 --report "$OUT/report.txt" --before "$OUT/before.md"
expect "other line changed" "VERDICT: STOP reason=conflicting-artifacts"
# app-developer DONE without gate output
write01 VERIFY 0 "step 3 DONE" DONE - 3
sed 's/^\$ npm test/npm test/' "$UNIT/03_development_output.md" >"$OUT/x.md" && cp "$OUT/x.md" "$UNIT/03_development_output.md"
run next "$UNIT" --step 3 --report "$OUT/report.txt"
expect "no raw gate output" "VERDICT: STOP reason=conflicting-artifacts"
write03

# ---- qc FAIL and send-back ----------------------------------------------------------------------------------------------
write01 IN_PROGRESS 1 "step 4 FAIL retry 1" DONE FAIL 4
cat >"$UNIT/04_quality_report.md" <<'EOF'
# 04 Quality report: Fix the login typo

- Directory: docs/2026-11-12_001_fix_login_typo/
- Ticket: PROJ-12

## qc (attempt 1)

### Summary

FAIL: another text changed.

### Done

- `git diff --stat`: 2 files changed.

### Verification

| Criterion | Result | Evidence |
|---|---|---|
| QC-1 | PASS | `grep -rn Password src/login`: 1 match |
| QC-2 | FAIL | `git diff --stat`: 2 files changed |

### Decisions

- None

### Open questions

- None

### Next

- app-developer: fix QC-2.

STATUS: FAIL

## Send-back record

| # | Date | Verify step | Sent back to | Failed criteria | Reason | Rework result |
|---|---|---|---|---|---|---|
| 1 | 2026-11-12 10:42 | 4 | 3, app-developer | QC-2 | extra file changed | pending |
EOF
run next "$UNIT"
expect "send-back goes to step 3 attempt 2" "VERDICT: CONTINUE reason=next-step step=3 agent=app-developer attempt=2"
# the transcription check: the 04 section equals the saved qc report
sed -n '/^### Summary/,/^STATUS: FAIL/p' "$UNIT/04_quality_report.md" >"$OUT/qcreport.txt"
run next "$UNIT" --step 4 --report "$OUT/qcreport.txt"
expect "qc transcription equal" "VERDICT: CONTINUE reason=next-step step=3"
sed 's/another text changed/something else/' "$OUT/qcreport.txt" >"$OUT/qcreport2.txt"
run next "$UNIT" --step 4 --report "$OUT/qcreport2.txt"
expect "qc wording change is not compared" "VERDICT: CONTINUE reason=next-step step=3"
sed 's/| QC-2 | FAIL |/| QC-2 | PASS |/' "$OUT/qcreport.txt" >"$OUT/qcreport4.txt"
run next "$UNIT" --step 4 --report "$OUT/qcreport4.txt"
expect "qc changed result differs" "VERDICT: STOP reason=conflicting-artifacts"
sed '/^| QC-2 /d' "$OUT/qcreport.txt" >"$OUT/qcreport5.txt"
run next "$UNIT" --step 4 --report "$OUT/qcreport5.txt"
expect "qc missing row differs" "VERDICT: STOP reason=conflicting-artifacts"
# a saved report that starts with its own qc heading is compared without that line (found in the L01 pilot)
{ echo "## qc (attempt 1)"; echo; cat "$OUT/qcreport.txt"; } >"$OUT/qcreport3.txt"
run next "$UNIT" --step 4 --report "$OUT/qcreport3.txt"
expect "qc transcription equal with heading" "VERDICT: CONTINUE reason=next-step step=3"
run check-format "$UNIT"
[ "$RC" -le 1 ] || fail "check-format rc $RC on the send-back fixture"
# retry cap: a second FAIL with Retries already at the cap must have been parked by the writer; a pending FAIL beyond it stops
write01 IN_PROGRESS 3 "step 4 FAIL retry 3" DONE FAIL 6
run next "$UNIT"; expect "retries above the cap" "VERDICT: STOP reason=retry-cap"

# ---- finished unit ----------------------------------------------------------------------------------------------------------------
write01 DONE 0 "done" DONE PASS 6
sed 's/| - |$/| DONE |/' "$UNIT/01_project_plan.md" >"$OUT/x.md" && cp "$OUT/x.md" "$UNIT/01_project_plan.md"
rm -f "$UNIT/05_completion_report.md"
run next "$UNIT"; expect "all done but no 05" "VERDICT: STOP reason=conflicting-artifacts"
printf '# 05 Completion report\n' >"$UNIT/05_completion_report.md"
run next "$UNIT"; expect "all done with 05" "VERDICT: END reason=done"

# ---- usage errors and exit codes ---------------------------------------------------------------------------------------------
run next "$UNIT/does-not-exist"; [ "$RC" -eq 2 ] || fail "missing directory: rc $RC"
run bogus "$UNIT"; [ "$RC" -eq 2 ] || fail "unknown subcommand: rc $RC"
run next "$UNIT" --report "$OUT/none.txt" --step 3; [ "$RC" -eq 2 ] || fail "missing report file: rc $RC"

# ---- the helper never writes into the repository -------------------------------------------------------------------------------------
before=$(find . -type f | sort | xargs cksum | cksum)
sh "$HELPER" next "$UNIT" >/dev/null 2>&1
sh "$HELPER" check-format "$UNIT" >/dev/null 2>&1
after=$(find . -type f | sort | xargs cksum | cksum)
[ "$before" = "$after" ] || fail "the helper changed files inside the repository"

if [ "$FAILS" -gt 0 ]; then
  echo "loop-state tests: $FAILS failure(s)" >&2
  exit 1
fi
echo "loop-state tests: ok"
