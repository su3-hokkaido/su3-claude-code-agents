# create-pr — プルリクエスト作成

実装差分を PR にまとめるスキルです。**このマシンでは Claude は git の書き込み操作（add/commit/push/PR作成）を実行しません**。差分を要約し PR 本文を用意したうえで、実行コマンドをユーザーに提示します。

## 進め方

1. **差分を確認する（読み取りのみ）。**
   - `git status` / `git diff` / `git log --oneline main..HEAD` で変更内容とコミットを把握する。
2. **ブランチ命名を確認する。** `feature/内容の要約` になっているか（`CLAUDE.md` §3-3）。なっていなければユーザーに切り直しを提案する。
3. **PR 本文（日本語）を作成する。** 下記テンプレに沿ってドラフトする。関連する設計書（`.claude/documents/.../design.md`）があればリンクする。
4. **実行手順を提示する。** 未コミットの変更があれば、コミット/プッシュ/PR作成の各コマンドを提示し、**ユーザーに実行を依頼する**（Claude は実行しない）。

## PR 本文テンプレート

```markdown
## 概要
（何を・なぜ変更したか。1〜3行）

## 変更内容
- （主な変更を箇条書き）

## 動作確認
- （テスト結果・手動確認の内容。失敗は正直に記載）

## 影響範囲 / 注意点
- （レビュアーが見るべき点、破壊的変更の有無、要フォロー事項）

## 関連
- 設計書: .claude/documents/{...}/design.md
- 計画書: plan_20260703.md §X
```

## ユーザーに依頼するコマンド例

```bash
git switch -c feature/{要約}   # 未作成の場合
git add -A
git commit -m "{要約}"
git push -u origin feature/{要約}
gh pr create --base main --title "{要約}" --body-file <本文>
```

## 注意

- **Claude は上記 git/gh の書き込み系を実行しない。** 必ずユーザーに実行を依頼する。
- 本リポジトリには `.git-pr-release` があり、リリース PR 運用が存在し得る。通常の機能 PR とリリース PR を混同しない。
- force push・`git reset --hard`・`git rebase` は使わない（guard.sh でもブロック）。
- 絵文字は使わない。

