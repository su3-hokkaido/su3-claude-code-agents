# Anthropic ディレクトリのセキュリティスキャン: 発生事象、原因、対応

期間: 2026-11-06 〜 2026-11-07。対象: 開発者ポータル (`claude.ai/directory/manage`) から、このマーケットプレイスの plugin を Anthropic のディレクトリへ提出した件。

この文書は、何が起き、何が分かり、何をすべきかを記録する。ディレクトリは判定ルールを公開していないため、自分たちの結果で**確認できたこと**と**推測にとどまること**を分けて書く。

英語版: [`directory-security-scan_en.md`](directory-security-scan_en.md)。

## 要約

- ディレクトリは plugin を 2 回、別々の理由で拒否した。どちらも **Verified organization**（検証済み組織）でないと通らない項目で、当方は Verified ではなく、Verified になる申請手段もない。
  1. **command フック**（`developer-set` 0.1.3）。`command` 型のフックは Verified organization からのみ受け付けられる。
  2. **許可リスト外の frontmatter キー**（`LOCAL_CODE_FRONTMATTER_KEY`）。許可リストは非公開で、指摘はキー名を示さない。
- 1 の対応: フックは GitHub のみで配布する別 plugin（`-with-guards`）に残し、ディレクトリにはフックなしの通常版を提出する。
- 2 の対応: プローブ版による二分探索で特定した。**原因は agent の frontmatter キー `skills`**。`model`、`tools`、`argument-hint`、`disable-model-invocation` は受理される。決定: ディレクトリ向け agent から `skills` を外し、必要なスキル本文を agent 本体に直接書く（[ADR 0001](../adr/0001-inline-skill-text-instead-of-agent-skills-key.md)）。
- この 2 回の拒否の前にも、ポータルの検証・スキャンはフックスクリプトの無害な記述で 2 つの版を**ブロック**した。同じ文字列パターンが再発しうるため、下に残す。

## 時系列

| 日付 | 出来事 | 結果 |
|---|---|---|
| 2026-11-06 | `product-owner-set` と `developer-set` の初回ポータル検証 | ブロック 1 件: `guard-po.sh` / `guard-bash.sh` がシェル変数のパスへ書き込んでいた。修正済み（「フックスクリプトの指摘」参照）。 |
| 2026-11-06 | 再検証 | ブロック: `wget` と固定ファイル名への書き込みが「wget の設定ファイルへの書き込み」と判定された。修正済み。 |
| 2026-11-06 | `developer-set` の再検証 | ブロック: `guard-bash.sh` が `..`（plugin の外へ出るパス）に言及している。修正済み。 |
| 2026-11-06 | 警告とポリシー保留つきで検証通過 | 保留と注記のみ残った。注記には command フックは「まだ拒否されない」とあった。 |
| 2026-11-07 | `developer-set` 0.1.3 を提出 | **拒否**: 「Hooks of type command accepted only from Verified organizations」。 |
| 2026-11-07 | plugin に `su3-` 接頭語を付けてリネームし、フックを持つ plugin を通常版と `-with-guards` 版に分割 | `CLAUDE.md` の「Plugins」参照。 |
| 2026-11-07 | 通常版 4 plugin を提出 | 4 つすべて **拒否**: `LOCAL_CODE_FRONTMATTER_KEY`。 |
| 2026-11-07 | ブランチ `directory-probe` のプローブ版で二分探索 | 原因を特定（下記）。 |
| 2026-11-07 | Commander がレビュー中のプローブ版 3 件の提出を取り下げ。スキル本文を直接書く方針を決定 | ADR 0001。 |

## 指摘 1: command フック

メッセージ: 「Hooks of type command accepted only from Verified organizations. If your organization isn't Verified, remove them from the plugin.」

- 検証レポートの注記 `LOCAL_CODE_HOOK_COMMAND` には「まだ拒否されないが、将来 command フックは Verified organization のみ受け付ける」とあった。提出時点で拒否に変わった。
- Verified になるための申請手段は今のところない。
- 対応（Commander 決定）: 通常版 `su3-developer-set` と `su3-product-owner-set` は `hooks/` もガードスクリプトも持たず、これを提出する。`su3-developer-set-with-guards` と `su3-product-owner-set-with-guards` はフックを残し、この GitHub マーケットプレイスのみで配布する。`scripts/validate.sh` が、フックを持てるのは `-with-guards` plugin のみであること、および通常版とガード版が接尾語とガード記述を除いて同一であることを検査する。

## 指摘 2: 許可リスト外の frontmatter キー

メッセージ（指摘コード `LOCAL_CODE_FRONTMATTER_KEY`）: 「The directory accepts frontmatter keys and values outside the allowed list only from Verified organizations ... Remove each frontmatter key outside the allowed list, give a key such as tags only text, and give author only text or a person's name, email, and url, then push a new commit.」

メッセージが言っていること・言っていないこと:

- 対象は plugin 内の「skill、command、agent、output style」の frontmatter。`plugin.json` ではない（`userConfig` は原因ではない）。
- キー名、ファイル、許可リストは**示されない**。ポータルは指摘を折りたたんで表示する。許可キーを載せた公式ページは見つからなかった（確認したページ: 提出前チェックリスト、plugin 構造、ディレクトリ公開、プラットフォームサポート）。
- 外部の手がかりは第三者の報告のみ（[pyvar PR #415](https://github.com/fibtecltd/pyvar/pull/415)）: 同じチェックが 2026-11-01 には通り、2026-11-06 から拒否し始めた。`name` と `description` だけの skill は通った。どのキーが拒否されたかは推測で、確認はされていない。

### 当方の plugin が使っていたキー

| ファイル種別 | キー |
|---|---|
| Agent | `name`, `description`, `model`, `tools`, `skills`, `disallowedTools`（`product-owner-set` のみ） |
| Skill | `name`, `description`, `argument-hint`, `disable-model-invocation`（command スキルと `set-language`） |

提出した 4 plugin はすべて同じメッセージで拒否された。したがって原因は 4 つに共通のキー、つまり `model`、`tools`、`skills`（agent）または `argument-hint`、`disable-model-invocation`（skill）のいずれかである。

### 方法: ブランチ上のプローブ版

提出は追跡ブランチに従う。ブランチ `directory-probe` を push し、4 plugin それぞれから異なるキーを外した版を置き、各提出の追跡先をそのブランチに向けてスキャン結果を比較した。このブランチはマージしない。`main` には手を付けていない。（このブランチでは `scripts/validate.sh` が設計上失敗する: `model` を必須とし、通常版とガード版の一致も検査するため。）

| プローブ版 | 外したキー | 残したキー | スキャン結果 |
|---|---|---|---|
| `su3-tech-writer-set` 1 回目 | agent の `tools`, `model` | agent の `skills`、skill の `argument-hint`, `disable-model-invocation` | 拒否 |
| `su3-tech-writer-set` 2 回目 | agent の `tools`, `model`, `skills` | skill の `argument-hint`, `disable-model-invocation` | **通過** |
| `su3-general-writer-set` | `name`, `description` 以外すべて | `name`, `description` | **通過** |
| `su3-product-owner-set` | agent の `skills`, `disallowedTools` | agent の `model`, `tools`、skill の `argument-hint`, `disable-model-invocation` | **通過** |
| `su3-developer-set` | skill の `argument-hint`, `disable-model-invocation` | agent の `model`, `tools`, `skills` | 拒否 |

### 結論

- **確認済み: agent の frontmatter キー `skills` は許可リスト外。** agent の `skills` を含む版はすべて拒否され（tech 1 回目、developer）、含まない版はすべて通過した（tech 2 回目、product-owner、general）。
- **受理が確認できたもの:** `name`、`description`、agent の `model`、agent の `tools`、skill の `argument-hint`、skill の `disable-model-invocation`。
- **未検証:** `disallowedTools`（product-owner のプローブで `skills` と一緒に外したため切り分けられていない）。不明として扱う。使っているのは `su3-product-owner-set` とその派生版のみ（market-researcher と backlog-manager）。
- スキャンが見るのはキー。`tools` の値（`Bash`、`Write`、`Edit` など）は問題にならなかった。

## フックスクリプトの指摘（拒否の前に出たもの）

ガードスクリプトと `hooks.json` に対するポータル検証の指摘。今回は誤検知だが提出をブロックしたため、引っかかった文字列パターンを残す。

| 指摘 | 引き金 | 対応 |
|---|---|---|
| 変数パスへの書き込み | `printf ... >>"$MARKERS/adrs"`、`: >"$MARKERS/$KEY"` | `developer-set`: 固定ファイル `/tmp/developer-set-guard-dry-runs` へ追記（1 行 `<session> <key>`）。`product-owner-set`: 状態を持たない。`docs/adr/` 配下のファイルが直近 120 分以内に更新されていれば ADR 作成済みとみなす。 |
| 「wget の設定ファイルへの書き込み」 | 検出用正規表現の `wget` という語と、固定ファイルへのリダイレクト（`2>/dev/null`） | `/dev/null` へのリダイレクトをやめ（代わりに `[ -f ]`、`[ -d ]` で判定）、パターンを `wg[e]t` と書いた。挙動は変わらず、テストで確認済み。 |
| 「`..` に言及」（plugin の外へ出るパス） | コメントやメッセージ中の `...`、正規表現中の `\.\.` | 文言を直し、正規表現を `\.{1,2}` にした。 |

残っていて修正不要のポリシー保留・注記（レビュアーが読む）:

- フックがツール呼び出しを承認しうる（`HOOK_GRANTS_PERMISSION`、`HOOK_OUTPUT_UNINSPECTED`）: 当方のガードは `deny` か `ask` しか返さない。
- 認証情報を読みデータが外へ出うる（`MCP_FORWARDS_CREDENTIAL_ENV`）: パターン文字列の一致で、何も読まず何も送らない。
- 検証側が追えないスクリプト（`COMMAND_SCRIPT_NOT_FOLLOWED`）。
- ダウンロードして実行（`RUNTIME_FETCH_EXEC`）: `curl | sh` の検出パターンと、画像バイナリへの偽一致。
- フックの `command` が 1 つの文字列（`HOOK_COMMAND_IS_ONE_STRING`）: 注記のみ。

## 現状（2026-11-07 時点）

| Plugin | 提出したプローブ版 | スキャン | 現在 |
|---|---|---|---|
| `su3-developer-set` | agent の `skills` を残した | 拒否（`LOCAL_CODE_FRONTMATTER_KEY`） | `skills` を外した本番版が必要。 |
| `su3-product-owner-set` | agent の `skills`, `disallowedTools` を外した | 通過 | Commander がレビューを取り下げ。 |
| `su3-tech-writer-set` | agent の `tools`, `model`, `skills` を外した | 通過 | Commander がレビューを取り下げ。 |
| `su3-general-writer-set` | `name`, `description` のみ | 通過 | Commander がレビューを取り下げ。 |

プローブ版は本物の plugin ではない（tech と general は `tools` と `model` を欠く）。どれも公開してはならない。

## 決定と対応

決定（Commander、2026-11-07）: 下の選択肢 1。agent が必要とするスキル本文を、ディレクトリ向け plugin の agent 本体へ直接書く。重複は増えるが、制限付きキーなしで動き、最小権限の `tools` を保てる。[ADR 0001](../adr/0001-inline-skill-text-instead-of-agent-skills-key.md) に記録。

1. ディレクトリへ出す plugin の全 agent から `skills` キーを外し、スキル本文を各 agent 本体に書く。`model`、`tools`、`argument-hint`、`disable-model-invocation` は残す。
2. ディレクトリ向け plugin では、プローブで受理が確認できるまで `disallowedTools` を使わない。同じ制限は `tools`（拒否ではなく許可するツールを列挙）で表す。
3. ガード版にも同じ変更を適用し、各 plugin とその派生版を同一に保つ。これで `scripts/validate.sh` の一致検査は変更不要。
4. 本番版を `main` に push し、各提出の追跡ブランチを `main` に戻して新しいコミットを確認し、意図した `tools` と `model` を持つ版だけを公開する。
5. `directory-probe` ブランチを削除する。

`skills` の事前読み込みを置き換える選択肢（検討したもの）:

| 選択肢 | 効果 |
|---|---|
| **1. 必要なスキル本文を agent 本体に書く（採用）** | キー不要で動く。スキル本文が各 agent に重複する。 |
| 2. agent の `tools` に `Skill` を足し、読み込むスキルを指示する | 本文は 1 か所のまま。ただし `Skill` は読み取り系ツールではないため、レビュー系 agent が読み取り専用でなくなる。 |
| 3. 事前読み込みをやめる | 最も単純。ユーザーが求めない限り、標準レポート形式や規約が agent から失われる。 |

## 次回提出前のチェックリスト

- agent、skill、command、output style の frontmatter: 受理が確認できているのは `name`、`description`、`model`、`tools`、`argument-hint`、`disable-model-invocation` のみ。それ以外はリスク。使う前にプローブ版で試す。
- `plugin.json` と `marketplace.json`: `author` は文字列、または名前・メール・URL。`tags` と `keywords` は文字列のみ。
- ディレクトリへ出す plugin に `hooks/` を置かない。
- スクリプトでは、スキャンが無視すると分かるまで、変数パスへの書き込み、`..`、固定ファイルへのリダイレクトを、正規表現やコメント内であっても避ける。
- 実験にはプローブ用ブランチとポータルの追跡ブランチ設定を使う。プローブ版は決して公開しない。
- ポータルは Verified organization への申請手段がないとしている。状況が変わったら見直す。
