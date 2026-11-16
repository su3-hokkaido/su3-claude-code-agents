# create-pr — Create a pull request

This skill packages an implementation diff into a PR. **On this machine Claude does not run git write operations (add/commit/push/PR creation).** Summarize the diff, prepare the PR body, then give the user the commands to run.

## Steps

1. **Review the diff (read-only).**
   - Use `git status`, `git diff` and `git log --oneline main..HEAD` to understand the changes and commits.
2. **Check the branch name.** It should be `feature/<summary>` (`CLAUDE.md` §3-3). If not, suggest that the user recreate the branch.
3. **Write the PR body in Japanese.** Draft it from the template below. Link the related design document (`.claude/documents/.../design.md`) if there is one.
4. **Present the commands.** If there are uncommitted changes, present the commit, push and PR-creation commands and **ask the user to run them** (Claude does not run them).

## PR body template

The PR body is written in Japanese, so keep the headings below as they are.

```markdown
## 概要
(What changed and why. 1-3 lines, in Japanese)

## 変更内容
- (Main changes as bullets)

## 動作確認
- (Test results and manual checks. Report failures honestly)

## 影響範囲 / 注意点
- (What reviewers should look at, whether there are breaking changes, follow-ups needed)

## 関連
- 設計書: .claude/documents/{...}/design.md
- 計画書: plan_20260703.md §X
```

## Example commands to ask the user to run

```bash
git switch -c feature/{summary}   # if the branch does not exist yet
git add -A
git commit -m "{summary}"
git push -u origin feature/{summary}
gh pr create --base main --title "{summary}" --body-file <body file>
```

## Notes

- **Claude does not run the git/gh write commands above.** Always ask the user to run them.
- The repository has a `.git-pr-release` file, so a release-PR workflow may exist. Do not confuse a normal feature PR with a release PR.
- Do not use force push, `git reset --hard` or `git rebase` (guard.sh also blocks them).
- Do not use emoji.
