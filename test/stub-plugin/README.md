# Stub plugin for loop tests

Builds a throwaway plugin that has the real `su3-developer-set-with-guards` skills (including the `loop-state.sh` helper, which the plain plugin does not ship) and stub agents (`su3-<role>-with-guards`) with fixed hand-backs.

    sh test/stub-plugin/build.sh "$TMPDIR/stub-set"
    mkdir -p "$TMPDIR/proj/.stub" && cd "$TMPDIR/proj"
    printf 'attempt 1: FAIL\n' > .stub/qc.txt      # L01: qc always FAIL
    claude --plugin-dir "$TMPDIR/stub-set" -p "/su3-developer-set-with-guards:project-implementation ..."

Status: pilots L01, L03a, L03b, L03d, L04, L05, L06, L07, L10, L12 and L13 have run and passed; L09 accepted at helper level (`-p` cannot show the ask and answer, and cannot save reports outside the project dir unless that dir is added with `--add-dir`); L03c accepted by the Commander (the skill stopped at S1 without running `check-format`). The other scenarios of L01 to L13 (`docs/2026-11-09_01_human_on_loop_design_upgrade/23_qa_review.md`) are run in Phase 4.
It is not a plugin of the marketplace and `validate.sh` does not check it.
