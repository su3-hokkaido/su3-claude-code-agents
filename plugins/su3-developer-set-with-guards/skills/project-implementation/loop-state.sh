#!/bin/sh
# loop-state.sh - deterministic loop bookkeeping for the project-implementation skill.
#
# Usage:
#   sh loop-state.sh check-format <unit-dir>
#   sh loop-state.sh next <unit-dir> [--save-before <file>]
#   sh loop-state.sh next <unit-dir> --step <n> --report <file> [--before <file>]
#
# The last output line of `next` is always
#   VERDICT: <CONTINUE|PARK|STOP|END> reason=<token> [step=<n>] [agent=<role>] [attempt=<n>]
# Exit codes: 0 verdict printed, 1 check-format found problems, 2 usage or internal error.
#
# Safety rules (spec 20_formats_spec.md section 9.4):
#   - Files are read only as text, with awk, grep, sed and cut. File content is never
#     executed, never loaded as shell code and never placed into a command line.
#   - Nothing is written into the repository. The only write is the --save-before copy,
#     which must go to an absolute path outside the current directory tree.
#   - POSIX sh and POSIX awk only (also runs under mawk and gawk). No jq, no network.

usage() {
  echo "usage: loop-state.sh check-format <unit-dir>" >&2
  echo "       loop-state.sh next <unit-dir> [--save-before <file>]" >&2
  echo "       loop-state.sh next <unit-dir> --step <n> --report <file> [--before <file>]" >&2
  exit 2
}

[ $# -ge 2 ] || usage
CMD=$1
UNIT=$2
shift 2
UNIT=${UNIT%/}
[ -d "$UNIT" ] || { echo "loop-state: not a directory: $UNIT" >&2; exit 2; }

STEP=
REPORT=
BEFORE=
SAVE=
while [ $# -gt 0 ]; do
  case $1 in
    --step) [ $# -ge 2 ] || usage; STEP=$2; shift 2 ;;
    --report) [ $# -ge 2 ] || usage; REPORT=$2; shift 2 ;;
    --before) [ $# -ge 2 ] || usage; BEFORE=$2; shift 2 ;;
    --save-before) [ $# -ge 2 ] || usage; SAVE=$2; shift 2 ;;
    *) usage ;;
  esac
done

# ---------------------------------------------------------------------------
# Shared awk library (functions and constants)
# ---------------------------------------------------------------------------
LIB='
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function readfile(path, arr,    n, line, rc) {
  n = 0
  while ((rc = (getline line < path)) > 0) { sub(/\r$/, "", line); n++; arr[n] = line }
  close(path)
  if (rc < 0 && n == 0) return -1
  return n
}
function file_exists(path,    x, rc) { rc = (getline x < path); close(path); return rc >= 0 }
function cells(line, c,    n, p, i) {
  line = trim(line)
  n = split(line, p, "|")
  for (i = 2; i < n; i++) c[i - 1] = trim(p[i])
  return n - 2
}
function numfield(ln,    v) { v = ln; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t%].*$/, "", v); return v }
function numval(v) { return (v ~ /^[0-9]+$/) ? v + 0 : -2 }
function is_sep(ln,    t) { t = ln; gsub(/[|: \t-]/, "", t); return t == "" }
function is_complete(i) {
  if (r_res[i] == "DONE" || r_res[i] == "PASS" || r_res[i] == "SKIPPED") return 1
  if (r_kind[i] == "gate" && r_res[i] == "FAIL") return 1
  return 0
}
function sectioned(i) { return (r_kind[i] == "author" || r_kind[i] == "verify") && r_out[i] ~ /^0[234]_[a-z_]+\.md$/ }
function role_ok(s) { return s ~ /^(project-manager|system-architect|app-developer|qa|qc|sre|aire)$/ }

# Count sections "## <role> (attempt N)" in a unit file. A section is completed when its
# last non-empty line is a strict STATUS line. Sets sec_total and sec_done.
function secinfo(fname, role,    n, A, i, ln, inrole, last, pat) {
  sec_total = 0; sec_done = 0
  if (fname !~ /^0[1-6]_[a-z_]+\.md$/) return
  n = readfile(unit "/" fname, A)
  if (n <= 0) return
  pat = "^## " role " \\(attempt [0-9]+\\)$"
  inrole = 0; last = ""
  for (i = 1; i <= n; i++) {
    ln = A[i]
    if (ln ~ /^## /) {
      if (inrole) { sec_total++; if (last ~ STATRE) sec_done++ }
      inrole = 0; last = ""
      if (ln ~ pat) inrole = 1
      continue
    }
    if (inrole && trim(ln) != "") last = trim(ln)
  }
  if (inrole) { sec_total++; if (last ~ STATRE) sec_done++ }
}

# Load 01_project_plan.md into globals. Returns 0 when the file is missing.
function load01(    i, ln, sec, sub3, c, n, t, v) {
  nl = readfile(unit "/01_project_plan.md", L)
  if (nl < 0) return 0
  sec = ""; sub3 = ""; nh = 0; nr = 0; st_n = 0; nsk = 0; nqc = 0
  b_retry = -1; b_over = -1; b_den = -1; b_est = -1; b_stop = -1; b_used = -1; used_line = 0
  p_mode = "interactive"; p_mode_raw = ""; p_policy = ""; p_route = ""; p_route_line = 0
  hdr_status = ""; hdr_route = ""; qa_last = ""; qa_present = 0
  st_status = ""; st_retries_raw = ""; st_tier = ""; st_last = ""; st_line = 0; st_ticket = ""
  for (i = 1; i <= nl; i++) {
    ln = L[i]
    if (ln ~ /^## /) { sec = substr(ln, 4); sub3 = ""; nh++; H[nh] = sec; HL[nh] = i; continue }
    if (ln ~ /^### /) { sub3 = substr(ln, 5); if (sec == "Quality criteria" && sub3 == "qa") qa_present = 1; continue }
    if (sec == "") {
      if (ln ~ /^- Mode:/) {
        v = ln; sub(/^- Mode:/, "", v); p_mode_raw = trim(v); gsub(/[ \t\r]/, "", v)
        p_mode = (v == "unattended") ? "unattended" : "interactive"
      } else if (ln ~ /^- Policy:/) { v = ln; sub(/^- Policy:[ \t]*/, "", v); p_policy = trim(v) }
      continue
    }
    if (sec == "Status" || sec == "Route") {
      if (sec == "Route" && ln ~ /^- Route:/) { v = ln; sub(/^- Route:[ \t]*/, "", v); p_route = trim(v); p_route_line = i; continue }
      if (ln !~ /^[|]/) continue
      if (is_sep(ln)) continue
      n = cells(ln, c)
      if (sec == "Status") {
        if (c[1] == "Ticket") { hdr_status = trim(ln); continue }
        st_n++
        if (st_n == 1) { st_ticket = c[1]; st_status = c[2]; st_retries_raw = c[3]; st_tier = c[4]; st_last = c[5]; st_line = i }
      } else {
        if (c[1] == "#") { hdr_route = trim(ln); continue }
        nr++
        r_num[nr] = c[1]; r_ticket[nr] = c[2]; r_agent[nr] = c[3]; r_kind[nr] = c[4]; r_in[nr] = c[5]
        r_out[nr] = c[6]; r_tier[nr] = c[8]; r_sb[nr] = c[9]; r_res[nr] = c[10]; r_line[nr] = i; r_cells[nr] = n
      }
      continue
    }
    if (sec == "Budget") {
      if (ln ~ /^- Retry cap:/) b_retry = numval(numfield(ln))
      else if (ln ~ /^- Overrun:/) b_over = numval(numfield(ln))
      else if (ln ~ /^- Denial cap:/) b_den = numval(numfield(ln))
      else if (ln ~ /^- Estimate:/) b_est = numval(numfield(ln))
      else if (ln ~ /^- Stop at:/) b_stop = numval(numfield(ln))
      else if (ln ~ /^- Used:/) { b_used = numval(numfield(ln)); used_line = i }
      continue
    }
    if (sec == "Skipped") { if (ln ~ /^- /) { nsk++; SK[nsk] = substr(ln, 3) } continue }
    if (sec == "Quality criteria") {
      if (ln ~ /^- QC-/) { nqc++; QCL[nqc] = ln }
      if (sub3 == "qa" && trim(ln) != "") qa_last = trim(ln)
      continue
    }
  }
  st_retries = (st_retries_raw ~ /^[0-9]+$/) ? st_retries_raw + 0 : -1
  return 1
}

BEGIN {
  STATRE = "^STATUS: (DONE|PARTIAL|BLOCKED|NEEDS_HUMAN_INPUT|PASS|FAIL)$"
  unit = ENVIRON["LS_UNIT"]
}
'

# ---------------------------------------------------------------------------
# next
# ---------------------------------------------------------------------------
NEXT_PROG='
function chk(file, ln, msg) { info = info "CHECK: FAIL " file ":" ln " " msg "\n"; nchk++ }
function finish(v, reason, stp, agent, att,    line) {
  printf "%s", info
  line = "VERDICT: " v " reason=" reason
  if (stp != "") line = line " step=" stp
  if (agent != "") line = line " agent=" agent
  if (att != "") line = line " attempt=" att
  print line
  exit 0
}
function stop_conflict(stp, agent) { finish("STOP", "conflicting-artifacts", stp, agent, "") }

# 06 denial counts: items with "Denied by guard: yes" whose Raised by names "report of step N"
function load06(    n, A, i, ln, item, den_flag, den_step, m) {
  n = readfile(unit "/06_commander_actions.md", A)
  for (i = 0; i <= 99; i++) den[i] = 0
  if (n <= 0) return
  item = 0; den_flag = 0; den_step = ""
  for (i = 1; i <= n + 1; i++) {
    ln = (i <= n) ? A[i] : "### A-END: end"
    if (ln ~ /^### /) {
      if (item && den_flag && den_step != "" && den_step + 0 <= 99) den[den_step + 0]++
      item = (ln ~ /^### A-[0-9][0-9][0-9]: /); den_flag = 0; den_step = ""
      continue
    }
    if (!item) continue
    if (ln ~ /^- Denied by guard: yes[ \t]*$/) den_flag = 1
    else if (ln ~ /^- Raised by:/ && match(ln, /report of step [0-9]+/)) {
      m = substr(ln, RSTART + 15, RLENGTH - 15); den_step = m
    }
  }
}

function rework_next(s,    b, r, cs) {
  b = r_sb[s] + 0
  secinfo(r_out[s], r_agent[s]); cs = sec_done
  for (r = b; r < s; r++) {
    if (r_kind[r] != "author") continue
    secinfo(r_out[r], r_agent[r])
    if (sec_done <= cs) return r
  }
  return s
}

function decide(    i, s, res, nx, att, ab, rsn, cap, dcap) {
  cap = (b_retry >= 0) ? b_retry : 2
  dcap = (b_den >= 0) ? b_den : 2
  load06()
  for (i = 1; i <= nr; i++) {
    if (den[i] > 0) info = info "DENIALS: " i "=" den[i] "\n"
    if (sectioned(i)) { secinfo(r_out[i], r_agent[i]); if (sec_total > 0) info = info "ATTEMPTS: " i "=" sec_done "/" (sec_total - sec_done) "\n" }
  }
  if (nr == 0) {
    if (st_status == "PARKED") finish("PARK", "parked", "", "", "")
    finish("STOP", "unknown-situation", "", "", "")
  }
  for (i = 1; i <= nr; i++) if (den[i] >= dcap) finish("STOP", "denial-cap", i, r_agent[i], "")
  s = 0
  for (i = 1; i <= nr; i++) if (!is_complete(i)) { s = i; break }
  if (s == 0) {
    if (st_status == "DONE" && file_exists(unit "/05_completion_report.md")) finish("END", "done", "", "", "")
    chk("01_project_plan.md", st_line, "all steps complete but status is " st_status " or 05 is missing")
    stop_conflict("", "")
  }
  res = r_res[s]
  if (st_status == "DONE") { chk("01_project_plan.md", st_line, "status DONE with step " s " not complete"); stop_conflict(s, r_agent[s]) }
  if (st_status == "PARKED") {
    rsn = "parked"
    if (r_kind[s] == "human") rsn = "human-step"
    else if (res == "BLOCKED") rsn = "blocked"
    else if (res == "NEEDS_HUMAN_INPUT") rsn = "question"
    finish("PARK", rsn, s, r_agent[s], "")
  }
  if (st_status == "BLOCKED") finish("PARK", "dependency", s, r_agent[s], "")
  if (r_kind[s] == "human") finish("PARK", "human-step", s, r_agent[s], "")
  if (st_retries > cap) finish("STOP", "retry-cap", s, r_agent[s], "")
  nx = s
  if (res == "BLOCKED" || res == "NEEDS_HUMAN_INPUT") {
    if (st_last ~ /resumed/) nx = s
    else if (res == "NEEDS_HUMAN_INPUT" && p_mode == "interactive") finish("PARK", "question", s, r_agent[s], "")
    else { chk("01_project_plan.md", r_line[s], "step " s " is " res " but the status row is not PARKED"); stop_conflict(s, r_agent[s]) }
  } else if (res == "FAIL" || res == "PARTIAL") {
    if (r_kind[s] == "verify") {
      secinfo(r_out[s], r_agent[s])
      if (sec_done > cap) finish("STOP", "retry-cap", s, r_agent[s], "")
      nx = rework_next(s)
    } else nx = s
  }
  if (sectioned(nx)) {
    secinfo(r_out[nx], r_agent[nx])
    ab = sec_total - sec_done
    if (ab >= 2) finish("STOP", "unknown-situation", nx, r_agent[nx], "")
    att = sec_total + 1
  } else {
    att = 1
    if (nx == s && (res == "PARTIAL" || res == "BLOCKED" || res == "NEEDS_HUMAN_INPUT")) att = 2
  }
  if (b_used < 0 || b_stop < 0) finish("STOP", "unknown-situation", nx, r_agent[nx], "")
  if (b_used + 1 > b_stop) finish("STOP", "budget", nx, r_agent[nx], "")
  info = info "NEXT: " nx " " r_agent[nx] "\n"
  finish("CONTINUE", "next-step", nx, r_agent[nx], att)
}

# Normalize the STATUS line of the hand-back (spec 9.1). Sets norm_raw, norm_val, norm_valid.
function norm_status(file, s,    n, R, i, raw, up, kind, agent, okset) {
  n = readfile(file, R)
  raw = ""
  for (i = n; i >= 1; i--) { if (trim(R[i]) != "") { raw = R[i]; break } }
  sub(/[ \t\r]+$/, "", raw)
  up = toupper(raw)
  norm_raw = raw; norm_valid = 0; norm_val = "BLOCKED"
  if (up !~ STATRE) return
  norm_val = substr(up, 9)
  agent = r_agent[s]; kind = r_kind[s]
  if (agent == "qc" && (kind == "verify" || kind == "gate")) okset = "|PASS|FAIL|BLOCKED|NEEDS_HUMAN_INPUT|"
  else okset = "|DONE|PARTIAL|BLOCKED|NEEDS_HUMAN_INPUT|"
  if (index(okset, "|" norm_val "|") == 0) { norm_val = "BLOCKED"; return }
  norm_valid = 1
}

function names_step(s) {
  if (match(st_last, "step " s "( |$)")) return 1
  if (s + 1 <= nr && r_kind[s + 1] == "human" && match(st_last, "parked: step " (s + 1) "$")) return 1
  if (s >= nr && st_last ~ / done$/) return 1
  return 0
}

function before_retries(    n, B, i, ln, sec, c, t) {
  n = readfile(before, B)
  if (n < 0) return -1
  sec = ""
  for (i = 1; i <= n; i++) {
    ln = B[i]
    if (ln ~ /^## /) { sec = substr(ln, 4); continue }
    if (sec == "Status" && ln ~ /^[|]/ && !is_sep(ln)) {
      cells(ln, c)
      if (c[1] == "Ticket") continue
      return (c[3] ~ /^[0-9]+$/) ? c[3] + 0 : -1
    }
  }
  return -1
}

function bookkeep(s, val,    exp_res, exp_st, nk, cap, brt, at_cap, rl) {
  rl = r_line[s]
  cap = (b_retry >= 0) ? b_retry : 2
  brt = (before != "") ? before_retries() : -1
  exp_res = val; exp_st = ""
  if (val == "DONE" || val == "PASS") {
    if (s + 1 > nr) exp_st = "DONE"
    else { nk = r_kind[s + 1]; exp_st = (nk == "verify") ? "VERIFY" : ((nk == "human") ? "PARKED" : "IN_PROGRESS") }
    if (r_kind[s] == "verify" && st_retries != 0) chk("01_project_plan.md", st_line, "Retries not reset to 0 after verify step " s)
  } else if (val == "FAIL" || val == "PARTIAL") {
    if (brt >= 0) at_cap = (brt >= cap); else at_cap = (r_res[s] == "NEEDS_HUMAN_INPUT")
    if (at_cap) {
      exp_res = "NEEDS_HUMAN_INPUT"; exp_st = "PARKED"
      if (st_retries != cap) chk("01_project_plan.md", st_line, "Retries is " st_retries " at the retry cap, expected " cap)
    } else {
      exp_st = "IN_PROGRESS"
      if (brt >= 0 && st_retries != brt + 1) chk("01_project_plan.md", st_line, "Retries is " st_retries ", expected " (brt + 1))
    }
  } else if (val == "BLOCKED") exp_st = "PARKED"
  else if (val == "NEEDS_HUMAN_INPUT") { if (p_mode == "unattended") exp_st = "PARKED" }
  if (r_res[s] != exp_res) chk("01_project_plan.md", rl, "Result of step " s " is " r_res[s] ", expected " exp_res)
  if (exp_st != "" && st_status != exp_st) chk("01_project_plan.md", st_line, "Status is " st_status ", expected " exp_st)
  if (!names_step(s)) chk("01_project_plan.md", st_line, "Last update does not name step " s)
}

function before_check(s,    n, B, i, k) {
  k = r_kind[s]
  if (k != "author" && k != "verify" && k != "gate") return
  n = readfile(before, B)
  if (n < 0) { chk("01_project_plan.md", 0, "before copy unreadable"); return }
  if (n != nl) { chk("01_project_plan.md", 0, "line count changed since the before copy"); return }
  for (i = 1; i <= nl; i++) {
    if (B[i] == L[i]) continue
    if (i == used_line || i == r_line[s] || i == st_line) continue
    chk("01_project_plan.md", i, "line changed outside step " s " row and status row")
  }
}

function gate_output(    n, A, i, ln, last, j, ok, st) {
  n = readfile(unit "/03_development_output.md", A)
  last = 0
  for (i = 1; i <= n; i++) if (A[i] ~ /^## app-developer \(attempt [0-9]+\)$/) last = i
  if (last == 0) { chk("03_development_output.md", 0, "no app-developer section after DONE"); return }
  ok = 0; st = 0
  for (i = last + 1; i <= n; i++) {
    ln = A[i]
    if (ln ~ /^## /) break
    if (ln ~ /^### Gate output[ \t]*$/) { st = 1; continue }
    if (st == 1 && trim(ln) != "") {
      if (ln ~ /^(```|~~~)/) st = 2; else break
      continue
    }
    if (st == 2) { if (ln ~ /^[$] /) ok = 1; break }
  }
  if (!ok) chk("03_development_output.md", last, "app-developer DONE without a Gate output fence whose first line starts with a dollar sign")
}

function vrows(X, lo, hi, V,    i, ln, c, m, n, inv) {
  n = 0; inv = 0
  for (i = lo; i <= hi; i++) {
    ln = X[i]
    if (ln ~ /^### /) { inv = (ln ~ /^### Verification[ \t]*$/); continue }
    if (!inv || ln !~ /^[ \t]*\|/) continue
    m = split(ln, c, "|")
    if (m < 3) continue
    if (trim(c[3]) == "" || trim(c[3]) == "Result" || trim(c[3]) ~ /^:?-+:?$/) continue
    V[++n] = trim(c[2]) "|" trim(c[3])
  }
  return n
}

function qc_compare(s, val,    n, A, R, nrp, i, last, b0, b1, j, k, lastnb, V1, V2, n1, n2) {
  n = readfile(unit "/04_quality_report.md", A)
  last = 0
  for (i = 1; i <= n; i++) if (A[i] ~ /^## qc \(attempt [0-9]+\)$/) last = i
  if (last == 0) { chk("04_quality_report.md", 0, "no qc section was transcribed"); return }
  b0 = last + 1; b1 = n
  for (i = last + 1; i <= n; i++) if (A[i] ~ /^## /) { b1 = i - 1; break }
  nrp = readfile(report, R)
  n1 = vrows(A, b0, b1, V1)
  n2 = vrows(R, 1, nrp, V2)
  if (n1 != n2) { chk("04_quality_report.md", last, "qc section has " n1 " Verification rows, the saved report has " n2); return }
  for (i = 1; i <= n1; i++) if (V1[i] != V2[i]) { chk("04_quality_report.md", last, "qc Verification row " i " differs from the saved report: " V1[i] " against " V2[i]); return }
  lastnb = ""
  for (i = b1; i >= b0; i--) if (trim(A[i]) != "") { lastnb = trim(A[i]); break }
  if (lastnb != "STATUS: " val) chk("04_quality_report.md", b1, "qc section STATUS differs from the normalized STATUS " val)
}

function post_dispatch(    s) {
  s = step + 0
  if (step !~ /^[0-9]+$/ || s < 1 || s > nr) { chk("01_project_plan.md", 0, "step " step " is not a route row"); stop_conflict("", "") }
  norm_status(report, s)
  info = info "STATUS_RAW: " norm_raw "\n"
  info = info "STATUS: " norm_val "\n"
  if (!norm_valid) finish("STOP", "invalid-status", s, r_agent[s], "")
  nchk = 0
  bookkeep(s, norm_val)
  if (before != "") before_check(s)
  if (r_agent[s] == "app-developer" && r_kind[s] == "author" && norm_val == "DONE") gate_output()
  if (r_agent[s] == "qc" && r_kind[s] == "verify") qc_compare(s, norm_val)
  if (nchk > 0) stop_conflict(s, r_agent[s])
}

function main_next(    i) {
  step = ENVIRON["LS_STEP"]; report = ENVIRON["LS_REPORT"]; before = ENVIRON["LS_BEFORE"]
  info = ""; nchk = 0
  if (!load01()) { print "loop-state: cannot read 01_project_plan.md in " unit > "/dev/stderr"; exit 2 }
  info = info "MODE: " p_mode "\n"
  info = info "POLICY: " p_policy "\n"
  info = info "USED: " b_used "\n"
  info = info "STOP_AT: " b_stop "\n"
  info = info "RETRIES: " st_retries "\n"
  if (st_status !~ /^(TODO|IN_PROGRESS|VERIFY|DONE|PARKED|BLOCKED)$/) {
    chk("01_project_plan.md", st_line, "status value " st_status " is not allowed"); finish("STOP", "unknown-situation", "", "", "")
  }
  for (i = 1; i <= nr; i++) {
    if (r_num[i] != i) { chk("01_project_plan.md", r_line[i], "route numbering is not consecutive at row " i); stop_conflict("", "") }
    if (r_kind[i] !~ /^(plan|criteria|author|verify|gate|report|human)$/ || !(role_ok(r_agent[i]) || r_agent[i] == "Commander")) {
      chk("01_project_plan.md", r_line[i], "route row " i " has an unknown agent or kind"); finish("STOP", "unknown-situation", "", "", "")
    }
  }
  if (report != "") post_dispatch()
  decide()
}
BEGIN { main_next() }
'

# ---------------------------------------------------------------------------
# check-format
# ---------------------------------------------------------------------------
CHECK_PROG='
function ff(file, ln, rule) { print "FORMAT: FAIL " file ":" ln " " rule; fails++ }
function fw(file, ln, rule) { print "FORMAT: WARN " file ":" ln " " rule }

function fence_reset() { f_in = 0; f_ch = ""; f_len = 0 }
# 0 outside a fence, 1 on an opening or closing fence line, 2 inside a fence
function fence_line(ln,    k) {
  if (f_in) {
    if (ln ~ /^(```+|~~~+)[ \t]*$/ && substr(ln, 1, 1) == f_ch) {
      k = ln; gsub(/[ \t]/, "", k)
      if (length(k) >= f_len) { f_in = 0; return 1 }
    }
    return 2
  }
  if (ln ~ /^(```+|~~~+)/) { f_ch = substr(ln, 1, 1); k = ln; sub(/[^`~].*$/, "", k); f_len = length(k); f_in = 1; return 1 }
  return 0
}

# last non-empty line of lines a[from..to]
function lastnb(a, from, to,    i) { for (i = to; i >= from; i--) if (trim(a[i]) != "") return trim(a[i]); return "" }

# ---- 00_request.md ----
function check00(    F, n, i, ln, nsec, cur, fs, sub3, bodycnt, firstToBe, lastid, id, pc, tick, unitv, hasTicket, hasUnit, k, d, rest, past) {
  F = "00_request.md"
  n = readfile(unit "/00_request.md", A0)
  nac = 0
  if (n < 0) { ff(F, 0, "missing-file"); return }
  split("AsIs|ToBe|SoThat|Acceptance Criteria|References|UI Design|Source", EXP, "|")
  past = (have01 && st_status != "TODO" && st_status != "PARKED")
  fence_reset(); nsec = 0; cur = 0; sub3 = ""; lastid = 0; pc = 0; hasTicket = 0; hasUnit = 0
  for (i = 1; i <= 7; i++) bodycnt[i] = 0
  for (i = 1; i <= n; i++) {
    ln = A0[i]
    fs = fence_line(ln)
    if (fs == 1) { if (cur > 0) bodycnt[cur]++; continue }
    if (fs == 2) { if (cur == 7 && sub3 == "Prompt" && trim(ln) != "") pc++; if (cur > 0) bodycnt[cur]++; continue }
    if (ln ~ /^## /) {
      nsec++
      if (substr(ln, 4) != EXP[nsec]) ff(F, i, "heading-order: found " substr(ln, 4) " expected " EXP[nsec])
      cur = nsec; sub3 = ""
      continue
    }
    if (ln ~ /^### /) { sub3 = substr(ln, 5) }
    if (cur == 0) {
      if (ln ~ /^- Ticket: /) { hasTicket = 1; req_ticket = trim(substr(ln, 11)) }
      if (ln ~ /^- Unit: /) { hasUnit = 1; req_unit = trim(substr(ln, 9)); if (req_unit !~ /^(Ticket|Story|Epic|Release)$/) ff(F, i, "unit-value " req_unit) }
      continue
    }
    if (trim(ln) != "") {
      bodycnt[cur]++
      if (past && cur <= 6 && ln ~ /^TODO/) ff(F, i, "todo-in-required-section")
      if (cur == 2 && firstToBe == "") firstToBe = ln
      if (cur == 4 && ln ~ /^- AC-[0-9]+: [^ ]/) {
        id = ln; sub(/^- AC-/, "", id); sub(/:.*$/, "", id)
        nac++; ACS[nac] = "AC-" id
        if (id + 0 <= lastid) ff(F, i, "ac-ids-not-ascending-or-unique AC-" id)
        lastid = id + 0
      }
      if (cur == 5 && ln ~ /^- Covers: docs\//) {
        d = ln; sub(/^- Covers: /, "", d); sub(/[ \t].*$/, "", d); sub(/\/$/, "", d)
        if (!file_exists(d "/00_request.md")) ff(F, i, "covers-dir-missing " d)
        ncov++
      }
    }
  }
  if (!hasTicket) ff(F, 1, "missing - Ticket line")
  if (!hasUnit) ff(F, 1, "missing - Unit line")
  if (nsec != 7) ff(F, 0, "expected 7 level-2 headings, found " nsec)
  for (i = 1; i <= nsec && i <= 7; i++) if (bodycnt[i] == 0) ff(F, 0, "empty-section " EXP[i])
  if (firstToBe ~ /^TODO/) ff(F, 0, "todo-in-ToBe")
  if (nac == 0) ff(F, 0, "no-acceptance-criteria")
  if (pc == 0) ff(F, 0, "empty-or-missing-Prompt-block")
  if (req_unit == "Release" && ncov == 0) ff(F, 0, "release-unit-without-Covers")
}

# ---- 06_commander_actions.md ----
function fin_item(    k, req, nreq, i, who, kind, st, cmdv, dryv, rbv, txt) {
  if (!it_open) return
  split("Status|Kind|Tier|Tier reason|Blocks|Raised by|Raised at|Who may run|Denied by guard|Review flags|Why|Decision", req, "|")
  for (i = 1; i <= 12; i++) if (!(req[i] in fdseen)) ff(F6, it_line, "item " it_id " missing field " req[i])
  if (!lab["cmd"] || !lab["dry"] || !lab["rb"]) ff(F6, it_line, "item " it_id " missing Command, Dry-run result or Rollback block")
  st = fd["Status"]; kind = fd["Kind"]; who = fd["Who may run"]
  if (st !~ /^(OPEN|DONE|REJECTED)$/) ff(F6, it_line, "item " it_id " Status value " st)
  if (kind !~ /^(T2_ACTION|FORBIDDEN|UNVERIFIED|REQUEST_INCOMPLETE|QUESTION|STOP|RELEASE_STEP|GIT)$/) ff(F6, it_line, "item " it_id " Kind value " kind)
  if (fd["Tier"] !~ /^T[0-3]$/) ff(F6, it_line, "item " it_id " Tier value " fd["Tier"])
  if (fd["Denied by guard"] !~ /^(yes|no)$/) ff(F6, it_line, "item " it_id " Denied by guard value")
  cmdv = bl_first["cmd"]; dryv = bl_first["dry"]; rbv = bl_first["rb"]
  if (kind == "T2_ACTION") {
    if (cmdv == "" || cmdv == "None") ff(F6, it_line, "item " it_id " T2_ACTION without Command")
    if (rbv == "" || rbv == "None") ff(F6, it_line, "item " it_id " T2_ACTION without Rollback")
    if (who == "None" || who == "") ff(F6, it_line, "item " it_id " T2_ACTION without Who may run")
    if (dryv == "" || dryv == "None") ff(F6, it_line, "item " it_id " T2_ACTION without dry-run result")
  } else if (kind ~ /^(FORBIDDEN|UNVERIFIED|REQUEST_INCOMPLETE|QUESTION|STOP)$/) {
    if (fd["Why"] == "" || fd["Why"] == "None") ff(F6, it_line, "item " it_id " kind " kind " without Why")
  } else if (kind ~ /^(RELEASE_STEP|GIT)$/) {
    if (cmdv == "" || cmdv == "None") ff(F6, it_line, "item " it_id " kind " kind " without Command")
  }
  if (dryv ~ /^Commander dry run:/ && who != "Commander") ff(F6, it_line, "item " it_id " Commander dry run requires Who may run Commander")
  if ((st == "DONE" || st == "REJECTED") && fd["Decision"] == "" && !had_exec) ff(F6, it_line, "item " it_id " closed without Decision")
  txt = bl_all["cmd"] "\n" bl_all["rb"]
  if (fd["Review flags"] == "None" && (txt ~ /:\/\// || txt ~ /[|][ \t]*(sh|bash)([ \t]|$)/)) fw(F6, it_line, "item " it_id " has a URL or pipe to a shell but Review flags is None")
  if (st == "OPEN") { oi_n++; oi_id[oi_n] = it_id; oi_blocks[oi_n] = fd["Blocks"]; oi_kind[oi_n] = kind; open_ids = open_ids " " it_id }
  it_open = 0
}
function check06(    n, i, ln, inf, key, val, num, prevnum, hasnote, fs0) {
  F6 = "06_commander_actions.md"
  n = readfile(unit "/06_commander_actions.md", A6)
  oi_n = 0; open_ids = ""; has06 = (n >= 0)
  if (n < 0) return
  inf = 0; blk = ""; it_open = 0; prevnum = 0; hasnote = 0
  for (i = 1; i <= n; i++) {
    ln = A6[i]
    if (inf) {
      if (ln ~ /^```/) { inf = 0; blk = ""; continue }
      if (blk != "" && trim(ln) != "") { if (bl_first[blk] == "") bl_first[blk] = trim(ln); bl_all[blk] = bl_all[blk] "\n" ln }
      continue
    }
    if (ln ~ /^```/) { inf = 1; continue }
    if (ln ~ /^- Note:/) { hasnote = 1; continue }
    if (ln ~ /^### /) {
      fin_item()
      if (ln !~ /^### A-[0-9][0-9][0-9]: [^ ]/) { ff(F6, i, "item-heading"); continue }
      num = substr(ln, 7, 3) + 0
      if (num <= prevnum) ff(F6, i, "item-ids-not-ascending-or-unique")
      prevnum = num
      it_open = 1; it_id = substr(ln, 5, 5); it_line = i; blk = ""; had_exec = 0
      for (key in fd) delete fd[key]
      for (key in fdseen) delete fdseen[key]
      for (key in lab) delete lab[key]
      bl_first["cmd"] = ""; bl_first["dry"] = ""; bl_first["rb"] = ""
      bl_all["cmd"] = ""; bl_all["dry"] = ""; bl_all["rb"] = ""
      continue
    }
    if (!it_open) continue
    if (ln == "Command:") { blk = "cmd"; lab["cmd"] = 1; continue }
    if (ln == "Dry-run result:") { blk = "dry"; lab["dry"] = 1; continue }
    if (ln == "Rollback:") { blk = "rb"; lab["rb"] = 1; continue }
    if (ln ~ /^- Executed:/) had_exec = 1
    if (ln ~ /^- [A-Za-z][A-Za-z -]*:/) {
      key = substr(ln, 3); val = key; sub(/:.*$/, "", key); sub(/^[^:]*:[ \t]*/, "", val)
      fd[key] = trim(val); fdseen[key] = 1
    }
  }
  fin_item()
  if (!hasnote) ff(F6, 1, "missing - Note line")
}

# ---- 01_project_plan.md ----
function check01(    F, i, hs, ev, ts, mx, tn, key, seq, variants, nv, ok, v, s, cap, stopat, found, nexts, j, ac, k, qcs, a, na, pa) {
  F = "01_project_plan.md"
  have01 = load01()
  if (!have01) { ff(F, 0, "missing-file"); return }
  cap = (b_retry >= 0) ? b_retry : 2
  hs = ""
  for (i = 1; i <= nh; i++) hs = hs (i > 1 ? "|" : "") H[i]
  if (hs != "Status|Route|Budget|Skipped|Quality criteria" && hs != "Status|Skipped") ff(F, (nh > 0 ? HL[1] : 1), "heading-order: " hs)
  if (p_mode_raw != "interactive" && p_mode_raw != "unattended") ff(F, 1, "mode-line " p_mode_raw)
  if (p_policy != "docs/policy/autonomy-policy.md" && p_policy !~ /^docs\/policy\/autonomy-policy\.md \(degraded: .+\)$/ && p_policy != "None (plugin defaults)") ff(F, 1, "policy-line")
  if (hdr_status != "| Ticket | Status | Retries | Riskiest tier | Last update |") ff(F, 1, "status-table-header")
  if (st_n != 1) ff(F, 1, "status-table-needs-one-row")
  if (st_status !~ /^(TODO|IN_PROGRESS|VERIFY|DONE|PARKED|BLOCKED)$/) ff(F, st_line, "status-value " st_status)
  if (st_retries < 0 || st_retries > cap) ff(F, st_line, "retries-out-of-range " st_retries_raw)
  if (st_tier !~ /^T[0-2]$/) ff(F, st_line, "riskiest-tier " st_tier)
  ts = substr(st_last, 1, 16); ev = substr(st_last, 18)
  if (ts !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]$/ || substr(st_last, 17, 1) != " ") ff(F, st_line, "last-update-timestamp")
  else if (ev !~ /^(created|resumed|budget stop|done)$/ && ev !~ /^step [0-9]+ (DONE|PARTIAL|BLOCKED|NEEDS_HUMAN_INPUT|PASS|FAIL)( retry [0-9]+)?$/ && ev !~ /^parked: step [0-9]+$/ && ev !~ /^parked: A-[0-9][0-9][0-9](,A-[0-9][0-9][0-9])*$/ && ev !~ /^blocked by: .+$/ && ev !~ /^resumed: aborted step [0-9]+$/) ff(F, st_line, "last-update-event " ev)
  if (nh > 0 && hs == "Status|Skipped") return
  if (p_route !~ /^(docs-or-definition|small-fix|feature-design|data-change|infra-pipeline|release)$/) ff(F, p_route_line, "route-key " p_route)
  mx = -1
  for (i = 1; i <= nr; i++) {
    if (r_num[i] != i) ff(F, r_line[i], "route-numbering row " i)
    if (r_cells[i] != 10) ff(F, r_line[i], "route-row-needs-10-cells")
    if (!(role_ok(r_agent[i]) || r_agent[i] == "Commander")) ff(F, r_line[i], "route-agent " r_agent[i])
    if (r_kind[i] !~ /^(plan|criteria|author|verify|gate|report|human)$/) ff(F, r_line[i], "route-kind " r_kind[i])
    if (r_tier[i] !~ /^T[0-2]$/) ff(F, r_line[i], "route-tier " r_tier[i])
    else { tn = substr(r_tier[i], 2) + 0; if (tn > mx) mx = tn }
    if (r_tier[i] == "T2" && r_agent[i] != "Commander") ff(F, r_line[i], "t2-step-not-for-Commander")
    if (r_kind[i] == "human" && r_agent[i] != "Commander") ff(F, r_line[i], "human-step-agent")
    if (r_res[i] !~ /^(-|SKIPPED|PARKED|DONE|PARTIAL|BLOCKED|NEEDS_HUMAN_INPUT|PASS|FAIL)$/) ff(F, r_line[i], "route-result " r_res[i])
    if (r_kind[i] == "verify") {
      if (r_sb[i] !~ /^[0-9]+$/ || r_sb[i] + 0 >= i || r_kind[r_sb[i] + 0] != "author") ff(F, r_line[i], "sends-back-to-must-be-an-earlier-author-step")
    }
  }
  if (mx >= 0 && st_tier != "T" mx) ff(F, st_line, "riskiest-tier-is-not-the-maximum")
  # route sequence
  if (nr >= 3) {
    if (r_agent[1] "/" r_kind[1] != "project-manager/plan") ff(F, r_line[1], "route-prefix-step-1")
    if (r_agent[2] "/" r_kind[2] != "qa/criteria") ff(F, r_line[2], "route-prefix-step-2")
    if (r_agent[nr] "/" r_kind[nr] != "project-manager/report") ff(F, r_line[nr], "route-suffix-report-step")
    seq = ""
    for (i = 3; i < nr; i++) seq = seq (i > 3 ? " " : "") r_agent[i] "/" r_kind[i]
    ROUTES["docs-or-definition"] = "aire/author qa/verify"
    ROUTES["small-fix"] = "app-developer/author qc/verify"
    ROUTES["feature-design"] = "system-architect/author app-developer/author qc/verify;system-architect/author aire/author app-developer/author qc/verify"
    ROUTES["data-change"] = "system-architect/author app-developer/author sre/author qc/verify Commander/human"
    ROUTES["infra-pipeline"] = "sre/author qc/verify Commander/human"
    ROUTES["release"] = "qa/gate qc/gate sre/gate qa/gate;qa/gate qc/gate sre/gate aire/gate qa/gate"
    if (p_route in ROUTES) {
      nv = split(ROUTES[p_route], variants, ";"); ok = 0
      for (i = 1; i <= nv; i++) if (variants[i] == seq) ok = 1
      if (!ok) ff(F, p_route_line, "route-steps-do-not-match-route " p_route ": " seq)
    }
  }
  # skipped files
  for (k = 2; k <= 3; k++) {
    key = (k == 2) ? "02_system_design.md" : "03_development_output.md"
    found = 0
    for (i = 1; i <= nsk; i++) if (index(SK[i], key ": skipped:") == 1) found = 1
    if (file_exists(unit "/" key)) { if (found) ff(F, 1, "skipped-file-exists " key) }
    else {
      ok = found
      for (i = 1; i <= nr; i++) if (r_out[i] == key && !is_complete(i)) ok = 1
      if (!ok) ff(F, 1, "missing-file-without-skipped-line " key)
    }
  }
  # budget
  if (b_retry < 0 || b_retry > 2) ff(F, 1, "retry-cap-missing-or-looser-than-default")
  if (b_over < 0 || b_over > 150) ff(F, 1, "overrun-missing-or-looser-than-default")
  if (b_den < 0 || b_den > 2) ff(F, 1, "denial-cap-missing-or-looser-than-default")
  if (b_est < 0 || b_stop < 0 || b_used < 0) ff(F, 1, "estimate-stop-at-or-used-missing")
  else {
    if (b_over >= 0) { stopat = int((b_est * b_over + 99) / 100); if (b_stop != stopat) ff(F, 1, "stop-at-is-not-ceil-estimate-times-overrun " b_stop " expected " stopat) }
    if (b_used > b_stop && st_status != "PARKED" && st_status != "DONE") ff(F, used_line, "used-exceeds-stop-at")
  }
  # status vs route
  s = 0
  for (i = 1; i <= nr; i++) if (!is_complete(i)) { s = i; break }
  if (st_status == "DONE" && s != 0) ff(F, st_line, "status-DONE-with-step-not-complete " s)
  if (st_status == "VERIFY" && s != 0 && r_kind[s] != "verify") ff(F, st_line, "status-VERIFY-but-next-step-is-not-verify")
  if (st_status == "PARKED") {
    ok = 0
    if (ev ~ /^parked: A-[0-9][0-9][0-9]/) { v = substr(ev, 9, 5); for (i = 1; i <= oi_n; i++) if (oi_id[i] == v) ok = 1 }
    else if (ev ~ /^parked: step [0-9]+$/) { v = substr(ev, 14); for (i = 1; i <= oi_n; i++) if (oi_blocks[i] == v) ok = 1 }
    else if (ev == "budget stop") { for (i = 1; i <= oi_n; i++) if (oi_kind[i] == "STOP") ok = 1 }
    else ok = 1
    if (!ok) ff(F, st_line, "status-PARKED-without-a-matching-OPEN-item-in-06")
  }
  # quality criteria
  if (hs ~ /Quality criteria$/) {
    for (i = 1; i <= nr; i++) if (r_kind[i] == "criteria" && is_complete(i)) {
      for (j = 1; j <= nac; j++) {
        found = 0
        for (k = 1; k <= nqc; k++) {
          pa = QCL[k]; sub(/^- QC-[0-9]+ \(/, "", pa); sub(/\).*$/, "", pa)
          na = split(pa, a, /,[ ]*/)
          for (v = 1; v <= na; v++) if (a[v] == ACS[j]) found = 1
        }
        if (!found) ff(F, 1, "ac-without-qc-item " ACS[j])
      }
      if (qa_last !~ STATRE) ff(F, 1, "quality-criteria-qa-section-without-STATUS-line")
    }
  }
}

# ---- 02, 03, 04: section headings and STATUS lines ----
function check_sections(fname, hre,    n, A, i, ln, sec_start, name, last, qcsec, nfail, nsb, rows, vrow, capstop, cap, v, inv, hasrec, stv, s2) {
  n = readfile(unit "/" fname, A)
  if (n < 0) return
  sec_start = 0; hasrec = 0; nfail = 0; rows = 0; inv = 0
  for (i = 1; i <= n + 1; i++) {
    ln = (i <= n) ? A[i] : "## END"
    if (ln ~ /^## /) {
      if (sec_start > 0) {
        last = lastnb(A, sec_start + 1, i - 1)
        name = A[sec_start]
        if (name ~ /^## Send-back record$/) { }
        else if (last ~ STATRE) {
          stv = substr(last, 9)
          if ((stv == "PASS" || stv == "FAIL") && name !~ /^## qc / && name !~ /^## release-check qc /) ff(fname, sec_start, "PASS-or-FAIL-outside-a-qc-section")
          if (name ~ /^## qc \(/ && (stv == "DONE" || stv == "PARTIAL")) ff(fname, sec_start, "qc-section-ends-with-" stv)
          if (fname == "04_quality_report.md") {
            inv = 1
            if ((name ~ /^## qc \(/ && stv == "FAIL") || (name ~ /^## qa \(/ && stv == "PARTIAL")) nfail++
            if (name ~ /^## qc \(/ && stv == "PASS") {
              for (v = sec_start + 1; v < i; v++) if (A[v] ~ /^[|] QC-[0-9]+ [|] (FAIL|NOT_RUN) [|]/) ff(fname, v, "qc-PASS-with-a-FAIL-or-NOT_RUN-row")
            }
          }
        } else if (toupper(last) ~ /STATUS/) ff(fname, sec_start, "status-line-invalid " last)
        else fw(fname, sec_start, "section-without-STATUS-line (aborted attempt) " name)
      }
      if (ln == "## Send-back record") {
        hasrec = 1
        for (v = i + 1; v <= n && A[v] !~ /^## /; v++) if (A[v] ~ /^[|] [0-9]+ [|]/) rows++
      }
      sec_start = (i <= n) ? i : 0
      if (i <= n && ln !~ hre && ln != "## Send-back record") ff(fname, i, "section-heading " ln)
    }
  }
  if (fname == "04_quality_report.md" && inv) {
    if (!hasrec) ff(fname, 0, "missing-Send-back-record-section")
    cap = (b_retry >= 0) ? b_retry : 2
    capstop = 0
    for (i = 1; i <= nr; i++) if (r_kind[i] == "verify" && r_res[i] == "NEEDS_HUMAN_INPUT") capstop = 1
    if (hasrec && rows != nfail - capstop) ff(fname, 0, "send-back-rows " rows " do not match failed verify sections " nfail " (retry-cap stop " capstop ")")
    if (rows > cap) ff(fname, 0, "more-send-back-rows-than-retry-cap")
  }
}

# ---- 05_completion_report.md ----
function check05(    F, n, i, ln, hn, ids, k, m, rest, cnt, a, j, t, ok, res, openset) {
  F = "05_completion_report.md"
  n = readfile(unit "/05_completion_report.md", A5)
  if (n < 0) return
  split("Summary|Result|Commander actions|Acceptance criteria|Send-back summary|Done|Decisions|Open questions|Next", EXP5, "|")
  hn = 0; cnt = 0; res = ""; hasrec = 0; haslink = 0
  for (i = 1; i <= n; i++) {
    ln = A5[i]
    if (ln ~ /^## /) { hn++; if (substr(ln, 4) != EXP5[hn]) ff(F, i, "heading-order: found " substr(ln, 4) " expected " EXP5[hn]) }
    if (ln ~ /\]\(06_commander_actions\.md\)/) haslink = 1
    if (ln ~ /^- Result:/) { res = trim(substr(ln, 10)) }
    if (ln ~ /^- Recommendation:/) hasrec = 1
    if (ln ~ /^- Open:/) {
      rest = ln
      while (match(rest, /A-[0-9][0-9][0-9]/)) { cnt++; ids[cnt] = substr(rest, RSTART, 5); rest = substr(rest, RSTART + RLENGTH) }
    }
    if (ln ~ /^[|] AC-[0-9]+ [|]/) {
      m = split(ln, a, "|")
      if (trim(a[3]) == "YES" && trim(a[4]) !~ /04/) ff(F, i, "AC-YES-without-04-evidence")
      acrow[trim(a[2])] = 1
    }
  }
  if (hn != 9) ff(F, 0, "expected 9 level-2 headings, found " hn)
  if (!haslink) ff(F, 0, "missing-link-to-06_commander_actions.md")
  if (res !~ /^(DONE|PARKED|BLOCKED|NEEDS_HUMAN_INPUT)$/) ff(F, 0, "result-value " res)
  else if (have01) {
    if (st_status == "DONE" && res != "DONE") ff(F, 0, "result-disagrees-with-status")
    if (st_status == "BLOCKED" && res != "BLOCKED") ff(F, 0, "result-disagrees-with-status")
    if (st_status == "PARKED" && res != "PARKED" && res != "NEEDS_HUMAN_INPUT") ff(F, 0, "result-disagrees-with-status")
  }
  if (lastnb(A5, 1, n) !~ STATRE) ff(F, n, "missing-final-STATUS-line")
  if (hasrec && !is_release) ff(F, 0, "Recommendation-line-in-a-ticket-directory")
  if (!hasrec && is_release) ff(F, 0, "missing-Recommendation-line")
  for (j = 1; j <= nac; j++) if (!(ACS[j] in acrow)) ff(F, 0, "AC-missing-from-table " ACS[j])
  # Open: list equals the OPEN items of 06 (as sets)
  for (i = 1; i <= cnt; i++) for (j = i + 1; j <= cnt; j++) if (ids[j] < ids[i]) { t = ids[i]; ids[i] = ids[j]; ids[j] = t }
  openset = ""; for (i = 1; i <= cnt; i++) if (ids[i] != ids[i - 1]) openset = openset " " ids[i]
  ok = 1
  for (i = 1; i <= oi_n; i++) if (index(openset " ", " " oi_id[i] " ") == 0) ok = 0
  for (i = 1; i <= cnt; i++) if (index(open_ids " ", " " ids[i] " ") == 0) ok = 0
  if (!ok) ff(F, 0, "Open-list-differs-from-the-OPEN-items-of-06")
}

function main_check(    hasunit) {
  is_release = (unit ~ /_release_check$/)
  have01 = 0
  have01 = load01()
  check06()
  check00()
  check01()
  if (is_release && req_unit != "Release") ff("00_request.md", 0, "release_check-directory-needs-Unit-Release")
  if (!is_release && req_unit == "Release") ff("00_request.md", 0, "Release-unit-outside-a-release_check-directory")
  check_sections("02_system_design.md", "^## (system-architect|aire|sre) \\(attempt [1-5]\\)$")
  check_sections("03_development_output.md", "^## (app-developer|aire|sre) \\(attempt [1-5]\\)$")
  if (is_release) check_sections("04_quality_report.md", "^## release-check (qa|qc|sre|aire) \\(step [0-9]+\\)$")
  else check_sections("04_quality_report.md", "^## (qc|qa) \\(attempt [1-5]\\)$")
  check05()
  print "TICKET: " req_ticket
  print "FORMAT_COUNT: " (fails + 0)
}
BEGIN { main_check() }
'

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case $CMD in
  next)
    if [ -n "$REPORT" ] || [ -n "$STEP" ] || [ -n "$BEFORE" ]; then
      [ -n "$REPORT" ] && [ -n "$STEP" ] || usage
      [ -z "$SAVE" ] || usage
      case $STEP in ''|*[!0-9]*) usage ;; esac
      [ -f "$REPORT" ] || { echo "loop-state: report file not found: $REPORT" >&2; exit 2; }
      if [ -n "$BEFORE" ]; then
        [ -f "$BEFORE" ] || { echo "loop-state: before copy not found: $BEFORE" >&2; exit 2; }
      fi
    fi
    if [ -n "$SAVE" ]; then
      case $SAVE in
        /*) ;;
        *) echo "loop-state: --save-before needs an absolute path" >&2; exit 2 ;;
      esac
      case $SAVE in
        */../*|*/..|*/./*) echo "loop-state: --save-before path must not contain dot segments" >&2; exit 2 ;;
      esac
      HERE_P=$(pwd -P)
      HERE_L=$(pwd)
      case $SAVE in
        "$HERE_P"|"$HERE_P"/*|"$HERE_L"|"$HERE_L"/*)
          echo "loop-state: --save-before path must be outside the repository" >&2; exit 2 ;;
      esac
    fi
    OUT=$(LS_UNIT=$UNIT LS_STEP=$STEP LS_REPORT=$REPORT LS_BEFORE=$BEFORE awk "$LIB$NEXT_PROG")
    RC=$?
    [ "$RC" -eq 0 ] || exit 2
    [ -n "$OUT" ] || exit 2
    LAST=$(printf '%s\n' "$OUT" | sed -n '$p')
    case $LAST in
      "VERDICT: "*) ;;
      *) exit 2 ;;
    esac
    if [ -n "$SAVE" ]; then
      case $LAST in
        "VERDICT: CONTINUE "*)
          cat "$UNIT/01_project_plan.md" > "$SAVE" || exit 2
          ;;
      esac
    fi
    printf '%s\n' "$OUT"
    exit 0
    ;;
  check-format)
    [ -z "$STEP$REPORT$BEFORE$SAVE" ] || usage
    FAILS=0
    EXTRA=
    BASE=$(printf '%s\n' "$UNIT" | sed 's|^\./||')
    if [ -f "$UNIT/00_request.md" ]; then
      if ! printf '%s\n' "$BASE" | grep -Eq '^docs/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{3}_[a-z0-9]+(_[a-z0-9]+)*$'; then
        EXTRA="${EXTRA}FORMAT: FAIL $BASE:0 directory-name
"
        FAILS=$((FAILS + 1))
      else
        NAME=${BASE#docs/}
        DATE=${NAME%%_*}
        SLUG=${NAME#*_*_}
        YY=${DATE%%-*}; REST=${DATE#*-}; MM=${REST%%-*}; DD=${REST#*-}
        MM=${MM#0}; DD=${DD#0}
        DIM=31
        case $MM in
          4|6|9|11) DIM=30 ;;
          2) DIM=28
             if [ $((YY % 4)) -eq 0 ] && { [ $((YY % 100)) -ne 0 ] || [ $((YY % 400)) -eq 0 ]; }; then DIM=29; fi ;;
        esac
        if [ "$MM" -lt 1 ] || [ "$MM" -gt 12 ] || [ "$DD" -lt 1 ] || [ "$DD" -gt "$DIM" ]; then
          EXTRA="${EXTRA}FORMAT: FAIL $BASE:0 directory-date-not-a-calendar-date
"
          FAILS=$((FAILS + 1))
        fi
        if [ "${#SLUG}" -gt 50 ]; then
          EXTRA="${EXTRA}FORMAT: FAIL $BASE:0 directory-slug-longer-than-50
"
          FAILS=$((FAILS + 1))
        fi
      fi
    fi
    OUT=$(LS_UNIT=$UNIT awk "$LIB$CHECK_PROG")
    RC=$?
    [ "$RC" -eq 0 ] || exit 2
    CNT=$(printf '%s\n' "$OUT" | sed -n 's/^FORMAT_COUNT: //p')
    TICKET=$(printf '%s\n' "$OUT" | sed -n 's/^TICKET: //p')
    case $CNT in ''|*[!0-9]*) exit 2 ;; esac
    FAILS=$((FAILS + CNT))
    BODY=$(printf '%s\n' "$OUT" | grep -v '^FORMAT_COUNT: ' | grep -v '^TICKET: ')
    [ -z "$BODY" ] || printf '%s\n' "$BODY"
    [ -z "$EXTRA" ] || printf '%s' "$EXTRA"
    # duplicate ticket IDs across docs/*/00_request.md
    if [ -n "$TICKET" ] && [ "$TICKET" != "None" ]; then
      for F in docs/*/00_request.md; do
        [ -f "$F" ] || continue
        D=${F%/00_request.md}
        [ "$D" = "$BASE" ] && continue
        T=$(grep -m1 '^- Ticket: ' "$F" | sed 's/^- Ticket: //; s/[ \t\r]*$//')
        if [ "$T" = "$TICKET" ]; then
          echo "FORMAT: FAIL $BASE/00_request.md:0 duplicate-ticket-id $TICKET also in $D"
          FAILS=$((FAILS + 1))
        fi
      done
    fi
    if [ "$FAILS" -gt 0 ]; then
      echo "VERDICT: STOP reason=format-invalid count=$FAILS"
      exit 1
    fi
    echo "VERDICT: CONTINUE reason=format-ok"
    exit 0
    ;;
  *) usage ;;
esac
